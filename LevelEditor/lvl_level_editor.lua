function widget:GetInfo()
	return {
		name = "Level Editor",
		desc = "Place units on the map with the mouse, delete them and save the level as a scenario unit loadout",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false,
	}
end

-- Stage 1: place, delete, undo and save units. Needs /cheat and the gadget unit_level_editor.
-- Saved to LevelEditor/<name>.lua in the game's write folder (a junction to the levels folder lives there).

local Echo = Spring.Echo
-- Shared code (blueprint library, tile grid, unit catalog, 3D preview) lives in editor_common.lua
local Shared = VFS.Include("luaui/Include/editor_common.lua", nil, VFS.ZIP_FIRST)
assert(Shared, "editor_common.lua missing (run install_editor.bat again)")
local rotateOffset = Shared.rotateOffset
local S = 1 -- UI scale from the BAR settings (slider "Interface > UI size")
local unitName = "armcom"
local team = 0
local writeOn = true -- Button W: placing overwrites what is in the way (off: nothing is placed on occupied spots)
local neutralOn = false -- Button N: newly placed units are neutral
local grid = 16
local cfg -- settings (columns, rows, grid, unit limit), created below
local facing = 0
local bpRot = 0 -- Quarter turns of the blueprint stamp
local spacing = 0 -- Spacing when dragging rows/rectangles (in 16 Elmo steps, like "buildspacing")
local stampDrag = nil -- { x, z }: start point while a row/rectangle is dragged with Shift
local placeQueue = {} -- Messages "led|place|..." for dragged rows, sent in packets
-- All actions run in order through the queue (otherwise e.g. a delete overtakes the units of a row).
-- "led|step" before every action tells the gadget what belongs to one undo step.
local function led(msg)
	if #placeQueue > 0 then
		placeQueue[#placeQueue + 1] = msg
	else
		Spring.SendLuaRulesMsg(msg)
	end
end
local function ledStep()
	led("led|step")
end
-- BAR only lets you select your own units. With Ctrl + left click (or dragging a rectangle) the editor selects
-- units of EVERY team in a selection of its own; delete, blow up, assign team, copy and blueprints use it.
local foreignSel = {}
local selBox = nil -- { x, y, cx, cy }: rectangle that is being dragged right now
local armedFeature = false -- Stamp mode for a feature (tree, rock, wreck)
local moveDrag = nil -- { x, z }: start point while the selection is moved with Alt + drag
local pendingNew = false -- an edit (rotate, mirror, move) is under way, the new IDs are expected
local lastNewN = nil
local levelList = {} -- Names of the saved levels (options menu)
local levelScroll = 0
local levelConfirm = nil -- { kind, name }: button is waiting for the second click
local MAX_LEVEL_ROWS = 8
local helpOpen = false -- Help board on the screen

-- Texts of the help board and of /led_help (data only, own file)
local HELP = VFS.Include("luaui/Include/led_help_texts.lua", nil, VFS.ZIP_FIRST)
assert(HELP, "led_help_texts.lua missing (run install_editor.bat again)")

local recent = Shared.newRecent("LuaUI/Config/LevelEditorRecent.lua", 24)

-- common after every placement: note the unit as recently used (undo is managed by the gadget)
local function placed()
	recent:add("unit", unitName)
end

local function selectedUnits()
	local sel = Spring.GetSelectedUnits()
	if #sel > 0 then
		return sel
	end
	local out = {}
	for _, id in ipairs(foreignSel) do
		if Spring.ValidUnitID(id) then
			out[#out + 1] = id
		end
	end
	return out
end
local isBpArmed = function() return false end -- set below, as soon as 'bpGrid.armed' is known
local FACING_NAME = { [0] = "South", [1] = "East", [2] = "North", [3] = "West" }
local OUTDIR = "LevelEditor/"

local function say(s)
	Echo("[Level Editor] " .. s)
end

-- in editor mode (game option leveleditor=1) no /cheat is needed
local function canEdit()
	if Spring.IsCheatingEnabled() then
		return true
	end
	local v = Spring.GetModOptions().leveleditor
	return v == "1" or v == 1 or v == true
end

-- canEdit with the message for the user (editing needs the editor game or /cheat)
local function editAllowed()
	if canEdit() then
		return true
	end
	say("Cheat mode is off: please type /cheat")
	return false
end

local function mouseGround()
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3]
	end
end

-- Like mouseGround, but says so when the pointer is not over the map
local function mouseOnMap()
	local x, z = mouseGround()
	if not x then
		say("The mouse must be over the map")
	end
	return x, z
end

local function snap(v)
	if grid <= 1 then
		return math.floor(v + 0.5)
	end
	return math.floor(v / grid + 0.5) * grid
end

-- Send the selected units to the gadget (in packets); returns true if something was selected
local function sendSelected(cmd)
	local sel = selectedUnits()
	if #sel == 0 then
		return false
	end
	ledStep()
	for i = 1, #sel, 40 do
		local chunk = {}
		for j = i, math.min(i + 39, #sel) do
			chunk[#chunk + 1] = sel[j]
		end
		led("led|" .. cmd .. "|" .. table.concat(chunk, ","))
	end
	return true
end

-- Delete: the selected units; without a selection the nearest unit at the mouse pointer
local function delete()
	if sendSelected("deleteids") then
		return true
	end
	local x, z = mouseGround()
	if x then
		ledStep()
		led(string.format("led|delete|%d|%d|%d", x, z, 64))
	end
	return true
end

-- Blow up: the selected units; without a selection the nearest unit at the mouse pointer
local function boom()
	if sendSelected("boomids") then
		return true
	end
	local x, z = mouseGround()
	if x then
		ledStep()
		led(string.format("led|boom|%d|%d|%d", x, z, 80))
	end
	return true
end

-- Assign the selected units to another team (click on a team button)
local function assign(_, _, args)
	if not editAllowed() then
		return true
	end
	local t = args and tonumber(args[1])
	if not t or not Spring.GetTeamInfo(t) then
		say("That team does not exist (team 0 = you, 1 = enemy)")
		return true
	end
	local sel = selectedUnits()
	if #sel == 0 then
		say("No unit selected")
		return true
	end
	-- send in packets so the message does not get too long
	ledStep()
	for i = 1, #sel, 40 do
		local chunk = {}
		for j = i, math.min(i + 39, #sel) do
			chunk[#chunk + 1] = sel[j]
		end
		led("led|assign|" .. t .. "|" .. table.concat(chunk, ","))
	end
	say(string.format("%d units sent to team %d", #sel, t))
	return true
end

local function undo()
	if #placeQueue > 0 then
		placeQueue = {} -- discard units of a dragged row that were not sent yet
		return true
	end
	Spring.SendLuaRulesMsg("led|undo|1") -- one step = one action (the gadget keeps the history)
	return true
end

-- Redo: takes back the undo of the last action
local function redo()
	Spring.SendLuaRulesMsg("led|redo|1")
	return true
end

-- Rotate the selection (l / r by 90 degrees) or mirror it (m, left-right); the units are set up again, the selection stays
local function editSelected(mode)
	if not editAllowed() then
		return true
	end
	local sel = selectedUnits()
	if #sel == 0 then
		say("No unit selected")
		return true
	end
	local ids = {}
	for i = 1, math.min(#sel, 2000) do
		ids[i] = sel[i]
	end
	if #sel > 2000 then
		say("At most 2000 units per operation")
	end
	pendingNew = true
	ledStep()
	led("led|xform|" .. mode .. "|" .. table.concat(ids, ","))
	return true
end

-- Rotate by 90 degrees: blueprint stamp, otherwise the unit
local function rotateBy(dir)
	if isBpArmed() then
		bpRot = (bpRot + dir) % 4
		say("Blueprint rotated: " .. FACING_NAME[bpRot])
	else
		facing = (facing + dir) % 4
		say("Facing: " .. FACING_NAME[facing])
	end
	return true
end

-- Scenario info (from the scenario maker): block "scenario = [==[ ... ]==]," in the level file. The editor does not
-- touch it, but reads it before overwriting and writes it back unchanged.
local keptScenario = nil -- Block of the level loaded last (also applies when saving under a new name)
local function scenarioBlockOf(text)
	return text and text:match("\n(\tscenario = %[==%[.-%]==%],)[ \t\r]*\n") or nil
end

-- Edit the scenario info in the game (button I in the menu): table with the same fields as the scenario maker
-- (title, author, summary, briefing, roles, ai, win, metal, energy, grace, sid).
local Json = Json or VFS.Include("common/luaUtilities/json.lua")
local scenario = nil -- Info of the loaded scenario or one created in the game
local scenarioDirty = false -- changed in the game: when saving, this state is written instead of the block from the file
local currentLevel = nil -- Name of the level loaded or saved last
local td = { open = false, edit = nil, pick = nil, mode = nil, pts = {}, stroke = nil, wall = 1, scroll = 0, data = nil } -- Tower Defense page (button TD); data = section towerdefense of the level file
local ctf -- Capture the Flag page (button CF): LevelEditor/led_ctf.lua, created below (data = section capture of the level file)

local function decodeBlock(block)
	local body = block and block:match("%[==%[(.*)%]==%]")
	if not body then
		return nil
	end
	local ok, data = pcall(Json.decode, body)
	if ok and type(data) == "table" then
		return data
	end
end

local function encodeBlock(data)
	local ok, body = pcall(Json.encode, data)
	if not ok or type(body) ~= "string" then
		return nil
	end
	return "\tscenario = [==[" .. (body:gsub("%]==%]", "] ==]")) .. "]==],"
end

-- Writes the level (units and features) to LevelEditor/<name>.lua. quiet = no chat message (autosave).
-- Returns the number of saved units (nil on error).
local function saveLevel(name, quiet)
	local gaia = Spring.GetGaiaTeamID()
	local lines, count = {}, 0
	for _, id in ipairs(Spring.GetAllUnits()) do
		local t = Spring.GetUnitTeam(id)
		-- the builder rows from the start (the gadget marks them) are not part of the level
		if Spring.GetUnitRulesParam(id, "ledbuilder") ~= 1 and Spring.GetUnitRulesParam(id, "tdwave") ~= 1 then
			local x, y, z = Spring.GetUnitPosition(id)
			local ud = UnitDefs[Spring.GetUnitDefID(id)]
			-- Gaia units additionally carry gaia = true (the Gaia number depends on the team count)
			lines[#lines + 1] = string.format(
				"\t\t{ name = '%s', x = %d, y = %d, z = %d, rot = %d, team = %d, neutral = %s%s%s },",
				ud.name, x, y, z, Spring.GetUnitHeading(id), t, tostring(Spring.GetUnitNeutral(id)),
				t == gaia and ", gaia = true" or "",
				Spring.GetUnitRulesParam(id, "indestructible") == 1 and ", indestructible = true" or ""
			)
			count = count + 1
		end
	end
	table.sort(lines)
	-- Features: wrecks, trees, rocks ...
	local flines = {}
	for _, fid in ipairs(Spring.GetAllFeatures()) do
		local fdef = FeatureDefs[Spring.GetFeatureDefID(fid)]
		local fx, fy, fz = Spring.GetFeaturePosition(fid)
		if fdef and fx then
			-- Wrecks that can be resurrected carry the unit (resurrectas)
			local res = Spring.GetFeatureResurrect(fid)
			flines[#flines + 1] = string.format("\t\t{ name = '%s', x = %d, y = %d, z = %d, rot = %d%s },",
				fdef.name, fx, fy, fz, Spring.GetFeatureHeading(fid) or 0,
				(type(res) == "string" and res ~= "") and (", resurrectas = '" .. res .. "'") or "")
		end
	end
	table.sort(flines)
	local block = scenarioDirty and scenario and encodeBlock(scenario) or nil
	if not block then
		local old = io.open(OUTDIR .. name .. ".lua", "r")
		if old then
			block = scenarioBlockOf("\n" .. old:read("*a") .. "\n")
			old:close()
		end
	end
	if not block and keptScenario then
		block = keptScenario
		if name:sub(1, 1) ~= "_" then
			-- a level of its own, made from another one (Save as new): title and ID of the other level would build its scenario into
			-- the folder of the other one, so they come from the name of this level
			local sc = decodeBlock(keptScenario)
			if sc then
				sc.title = (name:gsub("_", " "):gsub("^%l", string.upper))
				sc.sid = (name:lower():gsub("[^a-z0-9]", ""))
				block = encodeBlock(sc) or block
			end
		end
	end
	local f, err = io.open(OUTDIR .. name .. ".lua", "w")
	if not f then
		if not quiet then
			say("Saving failed: " .. tostring(err))
		end
		return nil
	end
	f:write("-- Level Editor: saved for scenariooptions.unitloadout and featureloadout\n")
	-- Game options that must be on in the main game so the placed units exist there
	local needed = {}
	local mo = Spring.GetModOptions()
	for _, key in ipairs({ "experimentallegionfaction", "experimentalextraunits", "releasecandidates" }) do
		local v = mo[key]
		if v == "1" or v == 1 or v == true then
			needed[#needed + 1] = key .. ' = "1"'
		end
	end
	f:write("return {\n\tmap = \"" .. Game.mapName .. "\",\n")
	-- Map size in Elmo: the scenario builder needs it for the grace period (start boxes as a fraction of the map)
	f:write(string.format("\tmapsize = { %d, %d },\n", Game.mapSizeX or 0, Game.mapSizeZ or 0))
	f:write(string.format("\tunitlimit = %d,\n", cfg.v.unitLimit))
	if block then
		f:write(block .. "\n")
	end
	if td.data then
		f:write("\ttowerdefense = " .. td.lua(td.data, "\t") .. ",\n")
	end
	if ctf.data then
		f:write("\tcapture = " .. ctf.lua() .. ",\n")
	end
	f:write("\t-- to be enabled in the main game (game options), otherwise some units are missing:\n")
	f:write("\trequiredmodoptions = { " .. table.concat(needed, ", ") .. " },\n\tunitloadout = {\n")
	f:write(table.concat(lines, "\n"))
	f:write("\n\t},\n\tfeatureloadout = {\n")
	f:write(table.concat(flines, "\n"))
	f:write("\n\t},\n}\n")
	f:close()
	if not quiet then
		say(string.format("%d units and %d features saved in %s%s.lua", count, #flines, OUTDIR, name))
		if name:sub(1, 1) ~= "_" then
			currentLevel = name
		end
		if count == 0 then
			say("Note: 0 units saved. Are all units visible?")
		end
	end
	return count
end

local function save(_, _, args)
	local name = (args and args[1]) or "level"
	name = name:gsub("[^%w_%-]", "_")
	saveLevel(name, false)
	return true
end

-- Load: reads LevelEditor/<name>.lua, clears the map (except the builder rows) and places the saved units
-- in small packets per update, so nothing overflows with large levels.
local loadQueue = {}
local LOAD_PER_UPDATE = 50

-- Reads the text of a level file and returns the table (or nil, error text)
function widget:ParseLevel(text)
	local chunk, err = (loadstring or load)(text)
	if not chunk then
		return nil, err
	end
	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" or type(data.unitloadout) ~= "table" then
		return nil, "not a valid level file"
	end
	return data
end

local function load_level(_, _, args)
	if not editAllowed() then
		return true
	end
	local name = ((args and args[1]) or "level"):gsub("[^%w_%-]", "_")
	local f = io.open(OUTDIR .. name .. ".lua", "r")
	if not f then
		say("Level not found: " .. OUTDIR .. name .. ".lua")
		return true
	end
	local text = f:read("*a")
	f:close()
	local data, err = widget:ParseLevel(text)
	keptScenario = scenarioBlockOf("\n" .. text .. "\n")
	scenario = decodeBlock(keptScenario)
	scenarioDirty = false
	currentLevel = name
	if not data then
		say("Loading failed: " .. tostring(err))
		return true
	end
	td.data = type(data.towerdefense) == "table" and data.towerdefense or nil -- own section of the level file
	ctf.data = type(data.capture) == "table" and data.capture or nil
	td.scroll = 0
	if tonumber(data.unitlimit) then
		cfg.v.unitLimit = tonumber(data.unitlimit) -- the unit limit belongs to the level (used by the scenario builder)
		cfg:sync()
		cfg:save()
	end
	if data.map and data.map ~= Game.mapName then
		say("Warning: the level was saved on map " .. tostring(data.map) .. " but the current map is " .. Game.mapName)
	end
	Spring.SendLuaRulesMsg("led|clear")
	loadQueue = {}
	for _, u in ipairs(data.unitloadout) do
		loadQueue[#loadQueue + 1] = u
	end
	local nFeatures = 0
	-- Replace features only if the file contains any (old files without featureloadout leave the map unchanged)
	if type(data.featureloadout) == "table" then
		Spring.SendLuaRulesMsg("led|clearfeatures")
		for _, ft in ipairs(data.featureloadout) do
			loadQueue[#loadQueue + 1] = { feature = true, name = ft.name, x = ft.x, z = ft.z, rot = ft.rot }
			nFeatures = nFeatures + 1
		end
	end
	say(string.format("Loading %s: %d units, %d features ...", name, #data.unitloadout, nFeatures))
	return true
end

local function clear_all()
	if not editAllowed() then
		return true
	end
	loadQueue = {}
	Spring.SendLuaRulesMsg("led|clear")
	say("Map cleared (the builder rows stay)")
	return true
end

-- Blueprints: Create saves the selected units as a layout (positions relative to the center),
-- clicking a tile places it again centered at the mouse pointer. Files: LevelEditorBlueprints/<name>.lua
local BPDIR = "LevelEditorBlueprints/"

local function blueprintSave(name)
	local sel = selectedUnits()
	if #sel == 0 then
		say("No unit selected. Select units first, then press Create in the blueprint menu")
		return
	end
	local minX, maxX, minZ, maxZ
	local list = {}
	for _, id in ipairs(sel) do
		local x, y, z = Spring.GetUnitPosition(id)
		local udef = UnitDefs[Spring.GetUnitDefID(id)]
		if x and udef then
			list[#list + 1] = { id = id, x = x, y = y, z = z, name = udef.name }
			minX, maxX = math.min(minX or x, x), math.max(maxX or x, x)
			minZ, maxZ = math.min(minZ or z, z), math.max(maxZ or z, z)
		end
	end
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local lines = {}
	for _, u in ipairs(list) do
		lines[#lines + 1] = string.format(
			"\t\t{ name = '%s', dx = %d, dz = %d, h = %d, rot = %d, team = %d, neutral = %s%s },",
			u.name, math.floor(u.x - cx + 0.5), math.floor(u.z - cz + 0.5), math.floor(u.y - Spring.GetGroundHeight(u.x, u.z) + 0.5),
			Spring.GetUnitHeading(u.id), Spring.GetUnitTeam(u.id), tostring(Spring.GetUnitNeutral(u.id)),
			Spring.GetUnitRulesParam(u.id, "indestructible") == 1 and ", indestructible = true" or ""
		)
	end
	table.sort(lines)
	local f, err = io.open(BPDIR .. name .. ".lua", "w")
	if not f then
		say("Saving failed: " .. tostring(err) .. " (folder LevelEditorBlueprints missing? run install_editor.bat again)")
		return
	end
	f:write("-- Level Editor Blueprint: positions relative to the center of the selection (dx, dz), h = height above ground\n")
	f:write("return {\n\tblueprint = {\n" .. table.concat(lines, "\n") .. "\n\t},\n}\n")
	f:close()
	say(string.format("Blueprint '%s' saved: %d units (%s%s.lua)", name, #lines, BPDIR, name))
	widget:BlueprintSaved(name)
end

-- Reads the text of a blueprint file (testable without the game)
function widget:ParseBlueprint(text)
	local chunk, err = (loadstring or load)(text)
	if not chunk then
		return nil, err
	end
	local ok, data = pcall(chunk)
	if not ok or type(data) ~= "table" or type(data.blueprint) ~= "table" then
		return nil, "not a valid blueprint file"
	end
	return data.blueprint
end

---------------------------------------------------------------- Blueprint management: list, selection, tile menu
-- Library (files), tile grid, unit catalog, settings and 3D preview come from editor_common.lua
cfg = Shared.newConfig("LuaUI/Config/LevelEditorUI.lua", "Level Editor: display (columns/rows in the menu), grid and unit limit",
	{ bpCols = 3, bpRows = 4, uCols = 3, uRows = 4, grid = 16, unitLimit = 32000 },
	{ bpCols = { 1, 6 }, bpRows = { 1, 8 }, uCols = { 1, 6 }, uRows = { 1, 8 }, grid = { 1, 64 }, unitLimit = { 500, 32000 } })
cfg.steps.grid = { 1, 4, 8, 16, 32, 64 } -- grid size in Elmo (1 = free)
cfg.steps.unitLimit = { 500, 1000, 2000, 4000, 8000, 16000, 32000 } -- unit limit written into the level for the scenario
local lib = Shared.newLibrary({ dirs = { BPDIR }, say = say, writeIndex = true })
local BP_LIST = lib.list -- { name, units, count, thumb, dir }
local ghost = Shared.newGhost({ owner = "Level Editor", say = say, wg = function() return WG end })
local menuOpen = false
local menuMode = "units" -- "bp" = blueprints, "units" = all units (faction / group / tech), "features" = trees/rocks/wrecks, "fav" = recently used
local optionsOpen = false
local scenarioOpen = false -- Scenario info (button I)
local scEdit = nil -- { row, buf }: text field being edited right now
local collapsed = false -- Menu collapsed: only the small button V stays visible
local panelMover = Shared.newPanelMover() -- the title row moves the menu
local mazeKind = nil -- Maze mode: nil = off, otherwise index into MAZE_KINDS
-- Generate page (button G): faction, type, tech, count; then drag an area, the units appear in it.
-- All state lives in one table (a Lua function may only reference 60 outer variables).
local gen = {
	open = false,
	armed = false, -- area mode on
	drag = nil, -- { x, z }: start point of the area
	faction = "arm",
	shape = "rect", -- area to drag: "rect" (rectangle) or "circle" (from the center outwards)
	sub = "units", -- sub-tab: "units" or "maze"
	mazeSel = 1, -- chosen maze material (1 = dragon teeth, 2 = walls)
	mazePath = 4, -- corridor width of the maze in tiles of 16 Elmo
	kinds = { units = true }, -- chosen types (multiple choice)
	edit = nil, -- count input field: text while typing
	tech = { [1] = true, [2] = false, [3] = false },
	count = 100,
}
local GEN_KINDS = { { "units", "Units" }, { "buildings", "Buildings" }, { "turrets", "Turrets" }, { "air", "Air" }, { "ships", "Ships" } }
local delMode = false -- Delete: false or the shape "rect" | "circle" | "line" (buttons DR, DC, DL, key D = rectangle)
local delDrag = nil -- { x, z }: start point of the delete shape
local area -- area attacks (XL, XR, XC) from the shared code, created below
local DEL_HALF_WIDTH = 40 -- half the width of the corridor that the delete line removes (Elmo)
local delToggle -- defined below
local mazeCycle -- Advance the maze mode (defined below)
local armedUnit = false -- Stamp mode for a single unit (left click places unitName)
local gridHooks = {}
local bpGrid = Shared.newGrid({
	lib = lib, cfg = cfg, unitWord = "Units",
	ownText = function(on)
		if on then
			widgetHandler:OwnText()
		else
			widgetHandler:DisownText()
		end
	end,
	onArm = function(on)
		if on then
			armedUnit = false
		end
	end,
	onSelect = function(i, moved) gridHooks.select(i, moved) end,
})
local function ownText(on)
	if on then
		widgetHandler:OwnText()
	else
		widgetHandler:DisownText()
	end
end
local uGrid = Shared.newUnits({ cfg = cfg, ownText = ownText })
local fGrid = Shared.newFeatures({ cfg = cfg, ownText = ownText })
local fav = Shared.newFav({ cfg = cfg, recent = recent, lib = lib })
local optionsUI = Shared.newOptions(cfg, {
	{ title = "Blueprints", keys = { { "bpCols", "Columns" }, { "bpRows", "Rows" } } },
	{ title = "Units", keys = { { "uCols", "Columns" }, { "uRows", "Rows" } } },
	{ title = "Placing", keys = { { "grid", "Grid (1 = free)" }, { "unitLimit", "Unit limit (scenario)" } } },
})
isBpArmed = function() return bpGrid.armed and not armedUnit end

-- Re-read the list; the selection stays if the blueprint is still there
local function bpScan()
	local keep = lib.list[bpGrid.selected] and lib.list[bpGrid.selected].name
	lib:scan()
	bpGrid.selected = keep and lib:index(keep) or 0
	if bpGrid.selected == 0 and #lib.list > 0 then
		bpGrid.selected = 1
	end
	bpGrid.scroll = 0
end

-- after saving: add to the index file and refresh the list
function widget:BlueprintSaved(name)
	bpScan()
	lib:saveOrder() -- also writes the index file
	local i = lib:index(name)
	if i then
		bpGrid.selected = i
	end
end

-- Half width / depth (Elmo) of what is placed: footprint of a unit at a facing, radius of a feature; nil for aircraft (they fly over everything)
local function halfSize(name, face, isFeature)
	if isFeature then
		local fd = FeatureDefNames[name]
		local rad = math.max(8, (fd and fd.radius) or 16)
		return rad, rad
	end
	local ud = UnitDefNames[name]
	if not ud or ud.canFly then
		return nil
	end
	local fx, fz = (ud.xsize or 4) * 8, (ud.zsize or 4) * 8
	if (face or 0) % 2 == 1 then
		fx, fz = fz, fx
	end
	return fx / 2, fz / 2
end

local recentPlaced = {} -- { x, z, hx, hz, feature, t }: placed a moment ago, not a unit yet

local function notePlaced(name, x, z, face, isFeature)
	local hx, hz = halfSize(name, face, isFeature)
	if hx then
		recentPlaced[#recentPlaced + 1] = { x = x, z = z, hx = hx, hz = hz, feature = isFeature or false, t = os.clock() }
	end
end

-- What stands in the way of a unit of this type at (x, z) (ground units and features overlapping its footprint) is added to found;
-- things placed a moment ago (the same blueprint or stroke) are left alone
local function collectBlockers(name, x, z, face, found, isFeature)
	local hx, hz = halfSize(name, face, isFeature)
	if not hx then
		return
	end
	local now = os.clock()
	local reach = 160
	for _, id in ipairs(Spring.GetUnitsInRectangle(x - hx - reach, z - hz - reach, x + hx + reach, z + hz + reach)) do
		local ud = UnitDefs[Spring.GetUnitDefID(id)]
		local ux, _, uz = Spring.GetUnitPosition(id)
		if ud and not ud.canFly and ux then
			local ufx, ufz = (ud.xsize or 4) * 8, (ud.zsize or 4) * 8
			if Shared.headingToFacing(Spring.GetUnitHeading(id) or 0) % 2 == 1 then
				ufx, ufz = ufz, ufx
			end
			if math.abs(ux - x) < hx + ufx / 2 - 1 and math.abs(uz - z) < hz + ufz / 2 - 1 then
				local mine = false
				for _, q in ipairs(recentPlaced) do
					if now - q.t < 2 and math.abs(q.x - ux) < 4 and math.abs(q.z - uz) < 4 then
						mine = true
					end
				end
				if not mine then
					found.units[id] = true
				end
			end
		end
	end
	for _, fid in ipairs(Spring.GetFeaturesInRectangle(x - hx - reach, z - hz - reach, x + hx + reach, z + hz + reach)) do
		local fdef = FeatureDefs[Spring.GetFeatureDefID(fid)]
		local fx, _, fz = Spring.GetFeaturePosition(fid)
		local rad = math.max(8, (fdef and fdef.radius) or 16)
		if fx and math.abs(fx - x) < hx + rad - 1 and math.abs(fz - z) < hz + rad - 1 then
			found.features[fid] = true
		end
	end
end

-- True when something is already there: the footprint would overlap another unit (also one placed a moment ago); a feature also
-- overlaps other features. Units may stand on features (they crush them).
local function blocked(name, x, z, face, isFeature)
	local hx, hz = halfSize(name, face, isFeature)
	if not hx then
		return false
	end
	local now = os.clock()
	for i = #recentPlaced, 1, -1 do
		local q = recentPlaced[i]
		if now - q.t > 2 then
			table.remove(recentPlaced, i)
		elseif (isFeature or not q.feature) and math.abs(q.x - x) < hx + q.hx - 1 and math.abs(q.z - z) < hz + q.hz - 1 then
			return true
		end
	end
	local reach = 160
	for _, id in ipairs(Spring.GetUnitsInRectangle(x - hx - reach, z - hz - reach, x + hx + reach, z + hz + reach)) do
		local ud = UnitDefs[Spring.GetUnitDefID(id)]
		if ud and not ud.canFly then
			local ux, _, uz = Spring.GetUnitPosition(id)
			local ufx, ufz = (ud.xsize or 4) * 8, (ud.zsize or 4) * 8
			if Shared.headingToFacing(Spring.GetUnitHeading(id) or 0) % 2 == 1 then
				ufx, ufz = ufz, ufx
			end
			if ux and math.abs(ux - x) < hx + ufx / 2 - 1 and math.abs(uz - z) < hz + ufz / 2 - 1 then
				return true
			end
		end
	end
	if isFeature then
		for _, fid in ipairs(Spring.GetFeaturesInRectangle(x - hx - reach, z - hz - reach, x + hx + reach, z + hz + reach)) do
			local fdef = FeatureDefs[Spring.GetFeatureDefID(fid)]
			local fx, _, fz = Spring.GetFeaturePosition(fid)
			local rad = math.max(8, (fdef and fdef.radius) or 16)
			if fx and math.abs(fx - x) < hx + rad - 1 and math.abs(fz - z) < hz + rad - 1 then
				return true
			end
		end
	end
	return false
end

-- Makes room for something at (x, z): with W on what is in the way is deleted (true), with W off the spot must be free
-- (false when it is occupied)
local function makeRoom(name, x, z, face, isFeature)
	if not writeOn then
		return not blocked(name, x, z, face, isFeature)
	end
	local found = { units = {}, features = {} }
	collectBlockers(name, x, z, face, found, isFeature)
	local ids = {}
	for id in pairs(found.units) do
		ids[#ids + 1] = "u" .. id
	end
	for fid in pairs(found.features) do
		ids[#ids + 1] = "f" .. fid
	end
	if #ids > 0 then
		led("led|clearids|" .. table.concat(ids, ",", 1, math.min(#ids, 100)))
	end
	return true
end

-- Deletes what collectBlockers found (the same undo step as the placing that follows)
local function clearBlockers(found)
	local ids = {}
	for id in pairs(found.units) do
		ids[#ids + 1] = "u" .. id
	end
	for fid in pairs(found.features) do
		ids[#ids + 1] = "f" .. fid
	end
	for i = 1, #ids, 100 do
		led("led|clearids|" .. table.concat(ids, ",", i, math.min(#ids, i + 99)))
	end
end

-- Puts a blueprint unit list with center (cx, cz) into the load queue
-- A blueprint (or the clipboard) is placed as one undo step; noStep = true for rows of several blueprints
-- (there the step is already in front). The units go through the queue with the extra "1" (remember).
local function placeBlueprintUnits(units, cx, cz, teamOverride, label, k, noStep)
	local n = 0
	k = k or 0
	if not noStep then
		ledStep()
	end
	local found = { units = {}, features = {} } -- W on: what stands in the way is deleted first
	local skip = {} -- W off: occupied spots are left out
	for i, u in ipairs(units) do
		local odx, odz = rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, k)
		local rot = ((tonumber(u.rot) or 0) + 16384 * k + 32768) % 65536 - 32768
		if writeOn then
			collectBlockers(tostring(u.name), cx + odx, cz + odz, Shared.headingToFacing(rot), found)
		else
			skip[i] = blocked(tostring(u.name), cx + odx, cz + odz, Shared.headingToFacing(rot))
		end
	end
	clearBlockers(found)
	local skipped = 0
	for i, u in ipairs(units) do
		if skip[i] then
			skipped = skipped + 1
		else
			local odx, odz = rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, k)
			local x, z = cx + odx, cz + odz
			local rot = ((tonumber(u.rot) or 0) + 16384 * k + 32768) % 65536 - 32768
			notePlaced(tostring(u.name), x, z, Shared.headingToFacing(rot))
			local y = Spring.GetGroundHeight(x, z) + (tonumber(u.h) or 0)
			placeQueue[#placeQueue + 1] = string.format("led|load|%s|%d|%d|%d|%d|%s|%d|1%s", tostring(u.name), teamOverride or team,
				math.floor(x + 0.5), math.floor(z + 0.5), math.floor(rot + 0.5), neutralOn and "1" or "0", math.floor(y + 0.5),
				u.indestructible == true and "|1" or "")
			n = n + 1
		end
	end
	say(string.format("Placing blueprint '%s': %d units%s%s", label, n, teamOverride and (" for team " .. teamOverride) or "",
		skipped > 0 and (" (" .. skipped .. " occupied spots left out, switch W on to write over them)") or ""))
end

local function bpCurrent()
	return BP_LIST[bpGrid.selected]
end

local function bpSay()
	local bp = bpCurrent()
	if bp then
		say(string.format("Blueprint %d/%d: %s (%d units)", bpGrid.selected, #BP_LIST, bp.name, bp.count))
	end
end

gridHooks.select = function(i)
	local bp = lib.list[i or bpGrid.selected]
	if bp then
		recent:add("bp", bp.name)
	end
	bpSay()
end

-- Copy/paste: Ctrl+C remembers the selected units (without a selection the one at the mouse pointer),
-- Ctrl+V sets them up again centered at the mouse pointer (with team, rotation and height)
local clipboard = {}

local function copyUnits()
	local ids = {}
	for _, id in ipairs(selectedUnits()) do
		ids[#ids + 1] = id
	end
	if #ids == 0 then
		local x, z = mouseGround()
		if x then
			local best, bestD = nil, 1e9
			for _, id in ipairs(Spring.GetUnitsInCylinder(x, z, 80)) do
				local ux, _, uz = Spring.GetUnitPosition(id)
				local d = (ux - x) ^ 2 + (uz - z) ^ 2
				if d < bestD and Spring.GetUnitTeam(id) ~= Spring.GetGaiaTeamID() then
					best, bestD = id, d
				end
			end
			if best then
				ids[1] = best
			end
		end
	end
	local list, minX, maxX, minZ, maxZ = {}, nil, nil, nil, nil
	for _, id in ipairs(ids) do
		local x, y, z = Spring.GetUnitPosition(id)
		local defID = Spring.GetUnitDefID(id)
		if x and defID then
			list[#list + 1] = { id = id, x = x, y = y, z = z, name = UnitDefs[defID].name }
			minX, maxX = math.min(minX or x, x), math.max(maxX or x, x)
			minZ, maxZ = math.min(minZ or z, z), math.max(maxZ or z, z)
		end
	end
	if #list == 0 then
		say("Nothing to copy: select units first or hold the mouse over a unit.")
		return true
	end
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	clipboard = {}
	for _, u in ipairs(list) do
		clipboard[#clipboard + 1] = {
			name = u.name,
			dx = u.x - cx,
			dz = u.z - cz,
			h = u.y - Spring.GetGroundHeight(u.x, u.z),
			rot = Spring.GetUnitHeading(u.id),
			team = Spring.GetUnitTeam(u.id),
			neutral = Spring.GetUnitNeutral(u.id),
			indestructible = Spring.GetUnitRulesParam(u.id, "indestructible") == 1,
		}
	end
	say(string.format("%d units copied. Paste at the cursor with Ctrl+V.", #clipboard))
	return true
end

local function pasteUnits()
	if not editAllowed() then
		return true
	end
	if #clipboard == 0 then
		say("The clipboard is empty. Copy with Ctrl+C first.")
		return true
	end
	local cx, cz = mouseOnMap()
	if not cx then
		return true
	end
	placeBlueprintUnits(clipboard, cx, cz, nil, "Copy")
	return true
end

-- Ctrl+D: create the builders of all factions (as at the start) again at the mouse pointer, for the current team
local function spawnBuildersHere()
	if not editAllowed() then
		return true
	end
	local x, z = mouseOnMap()
	if not x then
		return true
	end
	Spring.SendLuaRulesMsg(string.format("led|builders|%d|%d|%d", x, z, team))
	say("Builders of all factions are being created at the cursor (team " .. team .. ")")
	return true
end

-- Menu geometry: bar at the right edge. Content (grid, units, settings) comes from editor_common.lua.
local function rescale()
	S = Shared.rescale()
end

-- ---------------------------------------------------------------- Scenario info (button I)
local ROLE_TXT = { s = "Player", v = "Allied AI", e = "Enemy (AI)" }
local ROLE_NEXT = { s = "v", v = "e", e = "s" }
local AI_NEXT = { BARb = "NullAI", NullAI = "BARb" }
local AI_TXT = { BARb = "BARb (expands, attacks)", NullAI = "NullAI (does nothing)" }
local WIN_NEXT = { com = "killall", killall = "neverend", neverend = "com" }
local WIN_TXT = { com = "Commanders", killall = "All units", neverend = "No end" }

-- Teams that have units in the level (without Gaia and the editor's builders); re-read every 2 s, not every frame
local scTeams, scTeamsAt = { 0 }, -10
local function scenarioTeams()
	local now = os.clock()
	if now - scTeamsAt > 2 then
		scTeamsAt = now
		local gaia = Spring.GetGaiaTeamID()
		local seen, list = {}, {}
		for _, id in ipairs(Spring.GetAllUnits()) do
			local t = Spring.GetUnitTeam(id)
			if t ~= gaia and not seen[t] and Spring.GetUnitRulesParam(id, "ledbuilder") ~= 1 then
				seen[t] = true
				list[#list + 1] = t
			end
		end
		table.sort(list)
		if #list == 0 then
			list[1] = 0
		end
		scTeams = list
	end
	return scTeams
end

local function scenarioRows()
	local rows = {
		{ id = "title", label = "Title", kind = "text", max = 80 },
		{ id = "author", label = "Author", kind = "text", max = 60 },
		{ id = "summary", label = "Summary", kind = "text", max = 200 },
		{ id = "briefing", label = "Briefing", kind = "text", max = 800, multi = true },
	}
	for _, t in ipairs(scenarioTeams()) do
		rows[#rows + 1] = { id = "role", team = t, label = "Role team " .. t, kind = "cycle" }
	end
	for _, t in ipairs(scenarioTeams()) do
		rows[#rows + 1] = { id = "tiers", team = t, label = "Tech team " .. t, kind = "tiers" }
	end
	rows[#rows + 1] = { id = "ai", label = "AI behavior", kind = "cycle" }
	rows[#rows + 1] = { id = "win", label = "Win condition", kind = "cycle" }
	rows[#rows + 1] = { id = "metal", label = "Start metal", kind = "num", max = 6 }
	rows[#rows + 1] = { id = "energy", label = "Start energy", kind = "num", max = 6 }
	rows[#rows + 1] = { id = "grace", label = "Grace period (min:sec)", kind = "time", max = 6 }
	rows[#rows + 1] = { id = "sid", label = "ID", kind = "id", max = 24 }
	return rows
end

-- current value of a field (text), with the defaults of the scenario maker
local function scenarioValue(row)
	local sc = scenario or {}
	if row.id == "role" then
		local r = sc.roles and sc.roles[tostring(row.team)]
		if not r then
			r = (row.team == scenarioTeams()[1]) and "s" or "e"
		end
		return r
	elseif row.id == "tiers" then
		local t = sc.tiers and sc.tiers[tostring(row.team)]
		return type(t) == "string" and t or "123"
	elseif row.id == "ai" then
		return sc.ai or "BARb"
	elseif row.id == "win" then
		return sc.win or "com"
	elseif row.id == "grace" then
		local g = tonumber(sc.grace) or 0
		if g <= 0 then
			return "0"
		end
		local total = math.floor(g * 60 + 0.5)
		return string.format("%d:%02d", math.floor(total / 60), total % 60)
	elseif row.id == "metal" or row.id == "energy" then
		return tostring(sc[row.id] or 1000)
	end
	local v = sc[row.id]
	return type(v) == "string" and v or ""
end

local function scenarioSet(row, value)
	scenario = scenario or {}
	if row.id == "role" then
		if type(scenario.roles) ~= "table" then
			scenario.roles = {}
		end
		for _, t in ipairs(scenarioTeams()) do -- on the first change keep all roles
			local r = scenarioValue({ id = "role", team = t })
			scenario.roles[tostring(t)] = scenario.roles[tostring(t)] or r
		end
		scenario.roles[tostring(row.team)] = value
	elseif row.id == "tiers" then
		if type(scenario.tiers) ~= "table" then
			scenario.tiers = {}
		end
		scenario.tiers[tostring(row.team)] = value
	elseif row.kind == "num" then
		scenario[row.id] = tonumber(value) or 0
	elseif row.kind == "time" then
		-- "2:30" (minutes:seconds), "2,5" or "3" -> minutes as a number
		local m, sec = value:match("^(%d+):(%d%d?)$")
		local minutes = m and (tonumber(m) + math.min(59, tonumber(sec)) / 60) or tonumber((value:gsub(",", "."))) or 0
		scenario[row.id] = math.max(0, math.min(120, math.floor(minutes * 60 + 0.5) / 60))
	elseif value == "" then
		scenario[row.id] = nil
	else
		scenario[row.id] = value
	end
	scenarioDirty = true
end

local function scenarioRowH()
	return Shared.m.HB * 0.85
end

local function scenarioHeight()
	return 44 * S + (#scenarioRows() + 2) * (scenarioRowH() + 5 * S) + Shared.m.PAD
end

-- Generate page: buttons and labels; rect.top is the top edge, the third value is the height
local function genLayout(rect)
	local m = Shared.m
	local rects, labels = {}, {}
	local y = rect.top - m.PAD
	local TIPS = {
		genfac = "Faction of the generated units",
		genkind = "Type of the generated units: several can be on at once",
		gentech = "Tech level: several can be on at once, none chosen means all",
		gencount = "Total number of units (1-2000). Click, type a number, Enter accepts",
		genshape = "Shape of the area: a rectangle, or a circle dragged from its center outwards",
		genmaze = "Material of the maze walls: dragon teeth or walls",
		genmazew = "Width of the corridors of the maze in Elmo",
		gengo = "Press, then drag the area on the map: the units (or the maze) appear in it for the chosen team. Right click ends, Ctrl+Z undoes it.",
	}
	local function row(title, items, kind)
		labels[#labels + 1] = { text = title, x = rect.x1 + m.PAD, y = y - 30 * S, size = 25 * S, head = true }
		y = y - 36 * S
		local gap = 4 * S
		local n = #items
		local w = (rect.x2 - rect.x1 - 2 * m.PAD - gap * (n - 1)) / n
		for i, it in ipairs(items) do
			local bx = rect.x1 + m.PAD + (i - 1) * (w + gap)
			rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = it.kind or kind, value = it.value, label = it.label, active = it.active, icon = it.icon, fs = 24 * S,
				tip = it.tip or TIPS[it.kind or kind] }
		end
		y = y - m.HB - 10 * S
	end
	-- Sub-tabs: Units | Maze
	do
		local gap = 4 * S
		local w = (rect.x2 - rect.x1 - 2 * m.PAD - gap) / 2
		for i, it in ipairs({ { "units", "Units" }, { "maze", "Maze" } }) do
			local bx = rect.x1 + m.PAD + (i - 1) * (w + gap)
			rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = "gensub", value = it[1], label = it[2], active = gen.sub == it[1], fs = 24 * S,
				tip = it[1] == "units" and "Generate random units in an area" or "Build a random maze in an area (entrance top left, exit bottom right)" }
		end
		y = y - m.HB - 12 * S
	end
	local function factionRow()
		row("Faction", {
			{ value = "arm", label = "Armada", active = gen.faction == "arm", icon = Shared.FACTION_ICONS["arm"] },
			{ value = "cor", label = "Cortex", active = gen.faction == "cor", icon = Shared.FACTION_ICONS["cor"] },
			{ value = "leg", label = "Legion", active = gen.faction == "leg", icon = Shared.FACTION_ICONS["leg"] },
		}, "genfac")
	end
	-- Bottom of both sub-tabs: team line, Area (rectangle / circle) and the Generate button
	local function bottom()
		labels[#labels + 1] = { text = "Team " .. team .. (neutralOn and ", neutral" or "") .. "  (number buttons on the left; N = neutral)", x = rect.x1 + m.PAD, y = y - 26 * S, size = 22 * S }
		y = y - 40 * S
		row("Area (circle: drag from the center outwards)", {
			{ value = "rect", label = "Rectangle", active = gen.shape == "rect" },
			{ value = "circle", label = "Circle", active = gen.shape == "circle" },
		}, "genshape")
		local armed = gen.sub == "maze" and mazeKind ~= nil or gen.sub ~= "maze" and gen.armed
		local what = gen.shape == "circle" and "a circle" or "a rectangle"
		rects[#rects + 1] = { x1 = rect.x1 + m.PAD, x2 = rect.x2 - m.PAD, y0 = y - m.HB * 1.3, y1 = y, kind = "gengo", value = "go",
			label = armed and ("Generate: drag " .. what .. " (right click ends)") or "Generate", active = armed, fs = 28 * S, tip = TIPS.gengo }
		y = y - m.HB * 1.3 - m.PAD
		return rects, labels, rect.top - y
	end
	if gen.sub == "maze" then
		factionRow()
		row("Maze material", {
			{ value = 1, label = "Dragon teeth", active = gen.mazeSel == 1 },
			{ value = 2, label = "Walls", active = gen.mazeSel == 2 },
		}, "genmaze")
		local widths = {}
		for _, t in ipairs({ 2, 4, 8, 10, 12 }) do -- the same widths as the corridors of Tower Defense
			widths[#widths + 1] = { value = t, label = tostring(t * 16), active = gen.mazePath == t }
		end
		row("Corridor width (Elmo)", widths, "genmazew")
		labels[#labels + 1] = { text = "Random maze: entrance top left, exit bottom right.", x = rect.x1 + m.PAD, y = y - 22 * S, size = 21 * S }
		y = y - 34 * S
		return bottom()
	end
	factionRow()
	local kinds = {}
	for _, k in ipairs(GEN_KINDS) do
		kinds[#kinds + 1] = { value = k[1], label = k[2], active = gen.kinds[k[1]] == true }
	end
	row("Type (multiple choice)", kinds, "genkind")
	row("Tech level (none chosen = all)", {
		{ value = 1, label = "T1", active = gen.tech[1] },
		{ value = 2, label = "T2", active = gen.tech[2] },
		{ value = 3, label = "T3", active = gen.tech[3] },
	}, "gentech")
	row("Total count (1-2000, type a number)", {
		{ value = 0, label = gen.edit and (gen.edit .. "_") or tostring(gen.count), kind = "gencount", active = gen.edit ~= nil },
	}, "gencount")
	return bottom()
end

-- End the count input field (accept: take the value, otherwise discard)
local function genFinish(accept)
	if not gen.edit then
		return
	end
	local v = tonumber(gen.edit)
	gen.edit = nil
	widgetHandler:DisownText()
	if accept and v then
		gen.count = math.max(1, math.min(2000, math.floor(v)))
	end
end

local function genHeight()
	local _, _, h = genLayout({ x1 = 0, x2 = math.floor(560 * S), top = 0 })
	return h
end

-- One search for Units, Features and Blueprints (field at the top of the Place menu)
local search = { query = "", focus = false }

local function searchFocus(on)
	on = on and true or false
	if search.focus ~= on then
		search.focus = on
		ownText(on)
	end
end

local function searchSet(q)
	search.query = q
	uGrid.query, fGrid.query, bpGrid.query, fav.query = q, q, q, q
	uGrid.scroll, fGrid.scroll, bpGrid.scroll = 0, 0, 0
end

local function searchRects(x1, x2, top, hb)
	local pad = Shared.m.PAD
	local label = search.query
	if search.focus then
		label = label .. "|"
	elseif label == "" then
		label = "Search units, features and blueprints ..."
	end
	local tint = search.query ~= "" and { 0.75, 0.3, 0.28 } or nil -- reddish while a search text is active
	return {
		{ x1 = x1 + pad, x2 = x2 - pad - hb - 3, y0 = top - hb, y1 = top, kind = "search", value = "search", label = label, active = search.focus, tint = tint,
			tip = "Search in recent items, units, features and blueprints at once: type words of the description or the code.\nThe tabs below show how many match (the field is reddish while a text is in it; category buttons do nothing visible until you clear it). Enter = done, Esc = clear." },
		{ x1 = x2 - pad - hb, x2 = x2 - pad, y0 = top - hb, y1 = top, kind = "searchclear", value = "searchclear", label = "X", tint = tint, tip = "Clear search" },
	}
end

local function headerRowCount() -- Rows of the header
	if optionsOpen or scenarioOpen or gen.open or td.open or ctf.open then
		return 0
	end
	-- Place menu: search, sub-tabs, then the rows of the chosen sub-tab
	if menuMode == "units" then
		return 2 + (uGrid:filterRowCount() - 1)
	elseif menuMode == "features" then
		return 2 + (fGrid:filterRowCount() - 1)
	elseif menuMode == "fav" then
		return 2
	end
	return 2 + 1 -- blueprints: Create
end

-- List of the saved levels (LevelEditor/*.lua, without internal files with _ except the autosave _last)
local function scanLevels()
	levelList = {}
	local files = (VFS and VFS.DirList and VFS.DirList(OUTDIR, "*.lua", VFS.RAW)) or {}
	for _, path in ipairs(files) do
		local name = path:match("([^/\\]+)%.lua$")
		if name and (name:sub(1, 1) ~= "_" or name == "_last" or name == "_beforeplay") then
			levelList[#levelList + 1] = name
		end
	end
	table.sort(levelList)
	levelScroll = 0
end

local function levelsHeight()
	local m = Shared.m
	local rows = math.min(#levelList, MAX_LEVEL_ROWS)
	return 40 * S + (m.HB + 10 * S) * (rows + 1) + m.PAD
end

-- Title row "Level Editor" above the Place / Generate buttons
local function titleH()
	return 44 * S
end

local function basePanelRect()
	local m = Shared.m
	local vsx, vsy = Spring.GetViewGeometry()
	if collapsed then
		-- collapsed: only room for the button V in the upper right corner of the menu
		return vsx - (m.HB + 2 * m.PAD), vsy * 0.94 - (m.HB + 8), vsx, vsy * 0.94
	end
	local cw, ch
	if scenarioOpen then
		cw, ch = 0, scenarioHeight()
	elseif td.open then
		cw, ch = math.floor(780 * S), td.height() -- wider than the other pages: the wave table needs the room
	elseif ctf.open then
		cw, ch = 0, ctf.height()
	elseif gen.open then
		cw, ch = 0, genHeight()
	elseif optionsOpen then
		cw, ch = optionsUI:width(), optionsUI:height() + levelsHeight()
	elseif menuMode == "units" or menuMode == "features" or menuMode == "fav" then
		cw, ch = uGrid:size()
	else
		cw, ch = bpGrid:size()
	end
	local pw = math.min(math.max(cw, math.floor(560 * S)), vsx * 0.5) -- room for the buttons at the top
	local top = vsy * 0.94 -- top edge of the menu: 94 % of the screen height
	local hh = titleH() + 4 + headerRowCount() * (m.HB + 3) + 2
	local bottom = math.max((optionsOpen or scenarioOpen or gen.open or td.open or ctf.open) and vsy * 0.05 or vsy * 0.12, top - hh - ch)
	local colW = m.HB + 2 * m.PAD -- far right: button column V, O, I, ?
	return vsx - colW - pw, bottom, vsx - colW, top -- x1, bottom, x2, top
end

-- The menu where it is now: its place at the right edge, moved by dragging the title row
local function panelRect()
	local x1, y0, x2, y1 = basePanelRect()
	local m = Shared.m
	if collapsed then
		return panelMover:place(x1, y0, x2, y1, 0, 0, 40 * S)
	end
	return panelMover:place(x1, y0, x2, y1, 2 * m.HB + 12, m.HB + 2 * m.PAD, 40 * S) -- room for the team strip left and the button column right
end

-- Header: row 0 = mode and settings, below it Create (blueprints) or faction, group, tech (units)
local function headerRects()
	local m = Shared.m
	local x1, _, x2, y1 = panelRect()
	local rects = {}
	if collapsed then
		local top = y1 - 4
		rects[1] = { x1 = x2 - m.PAD - m.HB, x2 = x2 - m.PAD, y0 = top - m.HB, y1 = top, kind = "collapse", value = "collapse", label = "V", active = true }
		return rects, 4 + (m.HB + 3) + 2
	end
	do
		local top = y1 - 4 - titleH()
		-- Button column at the far right next to the menu: V, below it O, I and at the very bottom ?
		local sx1 = x2 + m.PAD
		local sx2 = sx1 + m.HB
		local function sideTop(k) return y1 - (k - 1) * (m.HB + 3) end
		rects[#rects + 1] = { x1 = sx1, x2 = sx2, y0 = sideTop(1) - m.HB, y1 = sideTop(1), kind = "collapse", value = "collapse", label = "V", active = false, side = true, tip = "Collapse or expand the menu" }
		local gx1, gx2, gy1 = sx1, sx2, sideTop(2)
		local ix1, ix2, iy1 = sx1, sx2, sideTop(3)
		local hx1, hx2, hy1 = sx1, sx2, sideTop(4)
		local dx1, dx2, dy1 = sx1, sx2, sideTop(5)
		local tops = {
			{ "place", "P", "Place (P): choose units, features and blueprints from the lists and place them on the map" },
			{ "gen", "G", "Generate (G): random units in a rectangle or circle, or a maze" },
		}
		for i, it in ipairs(tops) do
			rects[#rects + 1] = { x1 = sx1, x2 = sx2, y0 = sideTop(5 + i) - m.HB, y1 = sideTop(5 + i), side = true, kind = "top", value = it[1], label = it[2],
				active = (it[1] == "gen") and gen.open or (it[1] == "place" and not optionsOpen and not scenarioOpen and not gen.open and not td.open and not ctf.open), tip = it[3] }
		end
		rects[#rects + 1] = { x1 = ix1, x2 = ix2, y0 = iy1 - m.HB, y1 = iy1, side = true, kind = "info", value = "info", label = "I", active = scenarioOpen,
			tip = "Scenario: edit title, briefing, roles and rules for building a scenario" }
		rects[#rects + 1] = { x1 = hx1, x2 = hx2, y0 = hy1 - m.HB, y1 = hy1, side = true, kind = "help", value = "help", label = "?", active = helpOpen,
			tip = "Help: show the keys and controls on the screen" }
		rects[#rects + 1] = { x1 = sx1, x2 = sx2, y0 = sideTop(8) - m.HB, y1 = sideTop(8), side = true, kind = "td", value = "td", label = "TD", active = td.open,
			tint = td.cfg().enabled and (td.open and { 0.3, 0.75, 0.4 } or { 0.15, 0.6, 0.2 }) or nil, -- green: Tower Defense is on for this level
			tip = "Tower Defense: enemy waves walk a path to a goal (spawn point, goal, path, waves)" }
		rects[#rects + 1] = { x1 = sx1, x2 = sx2, y0 = sideTop(9) - m.HB, y1 = sideTop(9), side = true, kind = "ctf", value = "ctf", label = "CF", active = ctf.open,
			tint = ctf.cfg().enabled and (ctf.open and { 0.3, 0.75, 0.4 } or { 0.15, 0.6, 0.2 }) or nil, -- green: Capture the Flag is on for this level
			tip = "Capture the Flag: flags lie on the map, units carry them to the collection point of their team and earn metal (flag points, collection points, income)" }
		local areas = {
			{ "line", "XL", "XL (experimental): carpet attack along a line.\nSelect bombers, artillery, rocket launchers or nukes,\npress XL, then drag a line on the map.\nEach unit gets a piece of it." },
			{ "rect", "XR", "XR (experimental): attack a rectangle.\nSelect bombers, artillery, rocket launchers or nukes,\npress XR, then drag a rectangle.\nThe units spread over the whole area." },
			{ "circle", "XC", "XC (experimental): attack a circle.\nSelect bombers, artillery, rocket launchers or nukes,\npress XC, then drag a circle from the center outwards.\nThe units spread over it." },
		}
		for k, a in ipairs(areas) do
			local top = sideTop(10 + k)
			rects[#rects + 1] = { x1 = dx1, x2 = dx2, y0 = top - m.HB, y1 = top, side = true, kind = "area", value = a[1], label = a[2],
				active = (area ~= nil and area:armed() and area:mode() == a[1]), tip = a[3] }
		end
		-- Indestructible / destructible: rectangle, the buildings in it
		local fixes = {
			{ "fix", "FX", "FX: make buildings indestructible.\nPress FX, then drag a rectangle on the map:\nthe buildings in it can no longer be damaged.\nCtrl+Z undoes it." },
			{ "unfix", "FD", "FD: make buildings destructible again.\nPress FD, then drag a rectangle on the map:\nthe buildings in it can be damaged again.\nCtrl+Z undoes it." },
		}
		for k, f in ipairs(fixes) do
			local top = sideTop(14 + k)
			rects[#rects + 1] = { x1 = dx1, x2 = dx2, y0 = top - m.HB, y1 = top, side = true, kind = "del", value = f[1], label = f[2], active = (delMode == f[1]), tip = f[3] }
		end
		rects[#rects + 1] = { x1 = gx1, x2 = gx2, y0 = gy1 - m.HB, y1 = gy1, side = true, kind = "gear", value = "gear", label = "O", active = optionsOpen,
			tip = "Settings: columns and rows, plus level management (load / save)" }
	end
	local hh = titleH() + 4 + headerRowCount() * (m.HB + 3) + 2
	if not optionsOpen and not scenarioOpen and not gen.open and not td.open and not ctf.open then
		local rowTop = y1 - 4 - titleH()
		for _, r in ipairs(searchRects(x1, x2, rowTop, m.HB)) do
			rects[#rects + 1] = r
		end
		-- Sub-tabs; while searching they show the number of matches
		local subTop = rowTop - (m.HB + 3)
		local function count(grid)
			return search.query ~= "" and (" " .. (grid.matchCount and grid:matchCount() or #grid:list())) or ""
		end
		local subs = {
			{ "fav", "Recent" .. count(fav), "Recent: recently chosen blueprints and recently placed units" },
			{ "units", "Units" .. count(uGrid), "Units: all units of the game (faction, group, tech)" },
			{ "features", "Features" .. count(fGrid), "Features: place trees, rocks and wrecks" },
			{ "bp", "Blueprints" .. count(bpGrid), "Blueprints: place saved groups of units" },
		}
		local sw = (x2 - m.PAD - (x1 + m.PAD) - 3 * (#subs - 1)) / #subs
		for i, it in ipairs(subs) do
			local bx = x1 + m.PAD + (i - 1) * (sw + 3)
			rects[#rects + 1] = { x1 = bx, x2 = bx + sw, y0 = subTop - m.HB, y1 = subTop, kind = "mode", value = it[1], label = it[2], fs = 22 * S,
				active = it[1] == menuMode, tip = it[3] }
		end
		if menuMode == "bp" then
			local ct = subTop - (m.HB + 3)
			rects[#rects + 1] = { x1 = x1 + m.PAD, x2 = x2 - m.PAD, y0 = ct - m.HB, y1 = ct, kind = "create", value = "create", label = "Create",
				tip = "Saves the selected units as a new blueprint" }
		elseif menuMode == "units" or menuMode == "features" then
			-- the grid builds its own search row first: it lands on the sub-tab row and is dropped
			for _, r in ipairs((menuMode == "units" and uGrid or fGrid):filterRects(x1, x2, subTop, m.HB)) do
				if r.kind ~= "search" and r.kind ~= "searchclear" then
					rects[#rects + 1] = r
				end
			end
		end
	end
	return rects, hh
end

-- Content area below the header
local function contentRect()
	local x1, y0, x2, y1 = panelRect()
	local _, hh = headerRects()
	return { x1 = x1, y0 = y0, x2 = x2, top = y1 - hh }
end

local function inPanel(mx, my)
	if not menuOpen then
		return false
	end
	local x1, y0, x2, y1 = panelRect()
	return mx >= x1 and mx <= x2 and my >= y0 and my <= y1
end

-- Team strip left of the menu: vertical buttons with the team number, the chosen team (team) is highlighted
local function teamRects()
	local out = {}
	if not menuOpen or collapsed then
		return out
	end
	local m = Shared.m
	local x1, _, _, y1 = panelRect()
	local _, vsy = Spring.GetViewGeometry()
	local gaia = Spring.GetGaiaTeamID and Spring.GetGaiaTeamID()
	local ids = {}
	for _, t in ipairs(Spring.GetTeamList() or {}) do
		if t ~= gaia then
			ids[#ids + 1] = t
		end
	end
	table.sort(ids)
	if #ids == 0 then
		return out
	end
	table.insert(ids, 1, "N") -- very top: neutral
	local hasGaia = gaia and Spring.GetTeamInfo(gaia)
	if hasGaia then
		ids[#ids + 1] = gaia -- very bottom: G (Gaia team)
	end
	-- Edit buttons above the teams, only when units are selected
	local edits = {}
	if #selectedUnits() > 0 then
		edits = {
			{ edit = "l", label = "L", tip = "Rotate the selection 90 degrees left\n(around the center of the selection)" },
			{ edit = "r", label = "R", tip = "Rotate the selection 90 degrees right\n(around the center of the selection)" },
			{ edit = "m", label = "S", tip = "Mirror the selection left-right\n(at the center of the selection)" },
		}
	end
	local dels = {
		{ del = "line", label = "DL", tip = "Delete line: drag a line, everything within " .. DEL_HALF_WIDTH .. " Elmo of it is deleted (units, wrecks, features). Ctrl+Z undoes it." },
		{ del = "rect", label = "DR", tip = "Delete rectangle (key D): drag a rectangle on the map, everything in it is deleted (units, wrecks, features). Ctrl+Z undoes it." },
		{ del = "circle", label = "DC", tip = "Delete circle: drag a circle from its center, everything in it is deleted (units, wrecks, features). Ctrl+Z undoes it." },
	}
	local total = #ids + #edits + 2 + #dels + 1 + (#edits > 0 and 1 or 0)
	local bh = math.max(12, math.min(m.HB, math.floor((y1 - vsy * 0.05) / total) - 3))
	local bx2 = x1 - 4
	local bx1 = bx2 - m.HB
	-- very top: W (write over what is in the way), then a free slot
	out[#out + 1] = { x1 = bx1, x2 = bx2, y0 = y1 - bh, y1 = y1, write = true, label = "W" }
	local i = 2
	for _, d in ipairs(dels) do
		local top = y1 - i * (bh + 3)
		out[#out + 1] = { x1 = bx1, x2 = bx2, y0 = top - bh, y1 = top, del = d.del, label = d.label, tip = d.tip }
		i = i + 1
	end
	i = i + 1 -- free slot
	for _, e in ipairs(edits) do
		local top = y1 - i * (bh + 3)
		out[#out + 1] = { x1 = bx1, x2 = bx2, y0 = top - bh, y1 = top, edit = e.edit, label = e.label, tip = e.tip }
		i = i + 1
	end
	if #edits > 0 then
		i = i + 1 -- free slot
	end
	for _, t in ipairs(ids) do
		local top = y1 - i * (bh + 3)
		out[#out + 1] = { x1 = bx1, x2 = bx2, y0 = top - bh, y1 = top, team = t, gaia = (hasGaia and t == gaia) or nil }
		i = i + 1
	end
	return out
end

local function teamAt(mx, my)
	for _, r in ipairs(teamRects()) do
		if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
			return r
		end
	end
end

local function drawTeamStrip()
	for _, r in ipairs(teamRects()) do
		local sel
		local cr, cg, cb = 0.75, 0.75, 0.75
		if r.write then
			sel = writeOn
			cr, cg, cb = 0.2, 0.85, 0.3
			if not writeOn then
				cr, cg, cb = 0.75, 0.75, 0.75
			end
		elseif r.del then
			sel = delMode == r.del
			cr, cg, cb = 1, 0.35, 0.3
		elseif r.edit then
			sel = false
			cr, cg, cb = 0.35, 0.55, 1
		elseif r.team == "N" then
			sel = neutralOn
		else
			sel = (r.team == team)
			cr, cg, cb = Shared.teamColor(r.team)
		end
		gl.Color(0, 0, 0, 0.65)
		gl.Rect(r.x1, r.y0, r.x2, r.y1)
		gl.Color(cr, cg, cb, sel and 0.95 or 0.35)
		gl.Rect(r.x1 + 3, r.y0 + 3, r.x2 - 3, r.y1 - 3)
		if sel then
			gl.Color(1, 1, 1, 1)
			gl.LineWidth(3)
			gl.BeginEnd(GL.LINE_LOOP, function()
				gl.Vertex(r.x1, r.y0)
				gl.Vertex(r.x2, r.y0)
				gl.Vertex(r.x2, r.y1)
				gl.Vertex(r.x1, r.y1)
			end)
			gl.LineWidth(1)
		end
		gl.Color(1, 1, 1, sel and 1 or 0.8)
		gl.Text((r.edit or r.write or r.del) and r.label or (r.gaia and "G" or tostring(r.team)), (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2 - 10 * S, 27 * S, "co")
		if r.team and r.team ~= "N" then
			-- Number of units of this team left of the button
			gl.Color(1, 1, 1, sel and 1 or 0.75)
			gl.Text(tostring(Spring.GetTeamUnitCount(r.team) or 0), r.x1 - 6 * S, (r.y0 + r.y1) / 2 - 8 * S, 22 * S, "ro")
		end
	end
	gl.Color(1, 1, 1, 1)
	-- Tooltip left of the button under the mouse pointer
	local mx, my = Spring.GetMouseState()
	for _, r in ipairs(teamRects()) do
		if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
			local lines
			if r.write then
				lines = {
					"W = Write (on by default)",
					"On: whatever you place overwrites what is",
					"in the way (units, walls, blueprints ...).",
					"Off: nothing is placed on an occupied spot",
					"(a blueprint only partly). Generate always",
					"looks for another free spot.",
				}
			elseif r.edit or r.del then
				lines = {}
				for l in r.tip:gmatch("[^\n]+") do
					lines[#lines + 1] = l
				end
			elseif r.team == "N" then
				lines = {
					"N = Neutral (toggle)",
					"New units stay in the chosen team",
					"but get the neutral flag: enemies",
					"do not shoot at them on their own.",
				}
			elseif r.gaia then
				lines = {
					"G = Gaia team (nature)",
					"Belongs to no player, nobody controls it.",
					"An enemy to everyone, gets shot at,",
					"unless N (neutral) is on as well.",
				}
			else
				local _, _, _, _, _, ally = Spring.GetTeamInfo(r.team)
				lines = {
					"Team " .. r.team .. (ally and (" (alliance " .. ally .. ")") or ""),
					"New units and blueprints",
					"belong to this team.",
					"Units: " .. (Spring.GetTeamUnitCount(r.team) or 0) .. " of " .. (Spring.GetTeamMaxUnits(r.team) or "?"),
				}
			end
			local fs = 20 * S
			local w = 0
			for _, l in ipairs(lines) do
				w = math.max(w, gl.GetTextWidth(l) * fs)
			end
			local tx2 = r.x1 - 8 * S
			local tx1 = tx2 - w - 16 * S
			local th = #lines * (fs + 4 * S) + 10 * S
			local ty1 = r.y1
			gl.Color(0, 0, 0, 0.85)
			gl.Rect(tx1, ty1 - th, tx2, ty1)
			gl.Color(1, 1, 1, 1)
			for i, l in ipairs(lines) do
				gl.Text(l, tx1 + 8 * S, ty1 - 5 * S - i * (fs + 4 * S) + 4 * S, fs, "o")
			end
			break
		end
	end
	gl.Color(1, 1, 1, 1)
end

-- Level management in the options menu: row "New level" and per level the buttons Load and Save
local function levelRects(rect)
	local m = Shared.m
	local rects = {}
	local rowH = m.HB + 10 * S
	local y = rect.top - optionsUI:height() - 40 * S
	local bx2 = rect.x2 - m.PAD
	local function confirmLabel(kind, name, text)
		if levelConfirm and levelConfirm.kind == kind and levelConfirm.name == name then
			return "Sure?"
		end
		return text
	end
	rects[#rects + 1] = { x1 = bx2 - 330 * S, x2 = bx2, y0 = y - m.HB, y1 = y, kind = "new", label = "Save as new", fs = 22 * S,
		tip = "Saves the map as a new level (name level_001, level_002 ...)" }
	y = y - rowH
	for i = 1, math.min(MAX_LEVEL_ROWS, #levelList - levelScroll) do
		local name = levelList[levelScroll + i]
		rects[#rects + 1] = { x1 = bx2 - 330 * S, x2 = bx2 - 180 * S, y0 = y - m.HB, y1 = y, kind = "load", name = name,
			label = confirmLabel("load", name, "Load"), fs = 22 * S, active = (levelConfirm and levelConfirm.kind == "load" and levelConfirm.name == name) or nil,
			tip = "Load level: replaces everything on the map\n(second click confirms)" }
		rects[#rects + 1] = { x1 = bx2 - 175 * S, x2 = bx2, y0 = y - m.HB, y1 = y, kind = "save", name = name,
			label = confirmLabel("save", name, "Save"), fs = 22 * S, active = (levelConfirm and levelConfirm.kind == "save" and levelConfirm.name == name) or nil,
			tip = "Writes the current state into this level\n(overwrites, second click confirms)" }
		rects[#rects].rowName = name
		y = y - rowH
	end
	return rects
end

local function drawLevels(rect, mx, my)
	local m = Shared.m
	local rowH = m.HB + 10 * S
	local y = rect.top - optionsUI:height()
	gl.Color(0.5, 0.8, 1, 1)
	gl.Text("Levels", rect.x1 + m.PAD, y - 32 * S, 27 * S, "o")
	local rects = levelRects(rect)
	Shared.drawButtons(rects, 22 * S, m.HB)
	gl.Color(1, 1, 1, 1)
	local ty = y - 40 * S - rowH
	for i = 1, math.min(MAX_LEVEL_ROWS, #levelList - levelScroll) do
		gl.Text(levelList[levelScroll + i], rect.x1 + m.PAD * 3, ty - m.HB + (m.HB - 27 * S) / 2 + 3 * S, 27 * S, "o")
		ty = ty - rowH
	end
	if #levelList == 0 then
		gl.Text("no levels saved yet", rect.x1 + m.PAD * 3, y - 40 * S - rowH, 22 * S, "o")
	elseif #levelList > MAX_LEVEL_ROWS then
		gl.Text(string.format("%d-%d of %d (mouse wheel scrolls)", levelScroll + 1, math.min(#levelList, levelScroll + MAX_LEVEL_ROWS), #levelList),
			rect.x1 + m.PAD * 3, y - 40 * S - rowH * (MAX_LEVEL_ROWS + 1) - 28 * S, 20 * S, "o")
	end
	Shared.drawTip(rects, mx, my)
end

local function levelPress(rect, mx, my)
	for _, r in ipairs(levelRects(rect)) do
		if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
			if r.kind == "new" then
				local n = 1
				local taken = {}
				for _, nm in ipairs(levelList) do
					taken[nm] = true
				end
				while taken[string.format("level_%03d", n)] do
					n = n + 1
				end
				saveLevel(string.format("level_%03d", n), false)
				scanLevels()
			elseif levelConfirm and levelConfirm.kind == r.kind and levelConfirm.name == r.name then
				levelConfirm = nil
				if r.kind == "load" then
					load_level(nil, nil, { r.name })
				else
					saveLevel(r.name, false)
					scanLevels()
				end
			else
				levelConfirm = { kind = r.kind, name = r.name }
			end
			return true
		end
	end
	levelConfirm = nil
	return false
end

-- Rows and button of the scenario page (button I)
local function scenarioRects(rect)
	local m = Shared.m
	local rh = scenarioRowH()
	local gap = 5 * S
	local rects = {}
	local y = rect.top - 40 * S
	local vx1 = rect.x1 + (rect.x2 - rect.x1) * 0.36
	for _, row in ipairs(scenarioRows()) do
		rects[#rects + 1] = { x1 = vx1, x2 = rect.x2 - m.PAD, y0 = y - rh, y1 = y, row = row, labelX = rect.x1 + m.PAD }
		y = y - rh - gap
	end
	return rects
end

local function dropLastChar(t)
	return (t:gsub("[%z\1-\127\194-\244][\128-\191]*$", "", 1))
end

local function dropFirstChar(t)
	return (t:gsub("^[%z\1-\127\194-\244][\128-\191]*", "", 1))
end

local function scenarioDisplay(row)
	local v
	if scEdit and scEdit.row.id == row.id and scEdit.row.team == row.team then
		v = scEdit.buf
	elseif row.id == "role" then
		v = ROLE_TXT[scenarioValue(row)]
	elseif row.id == "ai" then
		v = AI_TXT[scenarioValue(row)] or scenarioValue(row)
	elseif row.id == "win" then
		v = WIN_TXT[scenarioValue(row)] or scenarioValue(row)
	else
		v = scenarioValue(row)
	end
	return (v:gsub("\n", " / "))
end

local function drawScenario(rect, mx, my)
	local m = Shared.m
	gl.Color(0.5, 0.8, 1, 1)
	gl.Text("Scenario (written with the level when saving)", rect.x1 + m.PAD, rect.top - 30 * S, 22 * S, "o")
	local rects = scenarioRects(rect)
	local fs = 22 * S
	for _, r in ipairs(rects) do
		if r.row and r.row.kind == "tiers" then
			gl.Color(1, 1, 1, 0.9)
			gl.Text(r.row.label, r.labelX, r.y0 + (r.y1 - r.y0 - fs) / 2 + 3 * S, fs, "o")
			local cur = scenarioValue(r.row)
			local w = (r.x2 - r.x1) / 3
			for i = 1, 3 do
				local on = cur:find(tostring(i), 1, true) ~= nil
				local bx = r.x1 + (i - 1) * w
				if on then
					gl.Color(0.2, 0.55, 0.25, 0.95)
				else
					gl.Color(0.35, 0.12, 0.12, 0.95)
				end
				gl.Rect(bx + 1, r.y0, bx + w - 1, r.y1)
				gl.Color(1, 1, 1, on and 1 or 0.5)
				gl.Text("T" .. i .. (on and "" or " off"), bx + w / 2, r.y0 + (r.y1 - r.y0 - fs) / 2 + 3 * S, fs, "oc")
			end
		elseif r.row then
			local editing = scEdit and scEdit.row.id == r.row.id and scEdit.row.team == r.row.team
			gl.Color(1, 1, 1, 0.9)
			gl.Text(r.row.label, r.labelX, r.y0 + (r.y1 - r.y0 - fs) / 2 + 3 * S, fs, "o")
			if editing then
				gl.Color(0.25, 0.5, 1, 0.85)
			elseif r.row.kind == "cycle" then
				gl.Color(0.2, 0.2, 0.2, 0.9)
			else
				gl.Color(0.08, 0.08, 0.08, 0.95)
			end
			gl.Rect(r.x1, r.y0, r.x2, r.y1)
			local text = scenarioDisplay(r.row)
			local avail = (r.x2 - r.x1) - 12 * S
			if editing then
				text = text .. "_"
				while text ~= "" and (tonumber(gl.GetTextWidth(text)) or 0) * fs > avail do
					text = dropFirstChar(text) -- while typing the end stays visible
				end
			else
				local cut = false
				while text ~= "" and (tonumber(gl.GetTextWidth(text .. (cut and "..." or ""))) or 0) * fs > avail do
					text = dropLastChar(text)
					cut = true
				end
				if cut then
					text = text .. "..."
				end
			end
			gl.Color(1, 1, 1, 1)
			gl.Text(text, r.x1 + 6 * S, r.y0 + (r.y1 - r.y0 - fs) / 2 + 3 * S, fs, "o")
		end
	end
	gl.Color(0.7, 0.7, 0.7, 1)
	local last = rects[#rects]
	gl.Text("Click a field to type: Enter done, Esc cancel,", rect.x1 + m.PAD, last.y0 - 22 * S, 17 * S, "o")
	gl.Text("Shift+Enter = new line in the briefing. Scenario package: start menu key 3.", rect.x1 + m.PAD, last.y0 - 42 * S, 17 * S, "o")
	gl.Color(1, 1, 1, 1)
end

local function scenarioFinish(accept)
	local e = scEdit
	if not e then
		return
	end
	scEdit = nil
	widgetHandler:DisownText()
	if accept then
		local v = e.buf
		if e.row.kind == "id" then
			v = v:lower():gsub("[^a-z0-9]", "")
		end
		if v ~= scenarioValue(e.row) then
			scenarioSet(e.row, v)
		end
	end
end

-- Save level: under the current name, otherwise as a new level_NNN (Ctrl+S)
local function saveCurrentLevel()
	local name = currentLevel and currentLevel:sub(1, 1) ~= "_" and currentLevel or nil
	if not name then
		local n = 1
		local taken = {}
		scanLevels()
		for _, nm in ipairs(levelList) do
			taken[nm] = true
		end
		while taken[string.format("level_%03d", n)] do
			n = n + 1
		end
		name = string.format("level_%03d", n)
	end
	saveLevel(name, false)
	scanLevels()
	return true
end

local function scenarioPress(rect, mx, my)
	for _, r in ipairs(scenarioRects(rect)) do
		if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
			scenarioFinish(true)
			if r.row then
				local row = r.row
				if row.kind == "tiers" then
					local i = math.max(1, math.min(3, math.floor((mx - r.x1) / ((r.x2 - r.x1) / 3)) + 1))
					local cur, out = scenarioValue(row), ""
					for k = 1, 3 do
						if (k == i) ~= (cur:find(tostring(k), 1, true) ~= nil) then
							out = out .. k
						end
					end
					scenarioSet(row, out)
				elseif row.kind == "cycle" then
					local cur = scenarioValue(row)
					local nxt = (row.id == "role" and ROLE_NEXT or row.id == "ai" and AI_NEXT or WIN_NEXT)[cur] or cur
					scenarioSet(row, nxt)
				else
					scEdit = { row = row, buf = scenarioValue(row) }
					widgetHandler:OwnText()
				end
			end
			return true
		end
	end
	scenarioFinish(true)
	return true
end

-- Keys while a field is being edited: Enter done, Esc cancel, Backspace deletes
local function scenarioKey(key, mods)
	if key == 13 or key == 271 then
		if mods and mods.shift and scEdit.row.multi then
			if #scEdit.buf < scEdit.row.max then
				scEdit.buf = scEdit.buf .. "\n"
			end
		else
			scenarioFinish(true)
		end
	elseif key == 27 then
		scenarioFinish(false)
	elseif key == 8 then
		scEdit.buf = dropLastChar(scEdit.buf)
	end
	return true
end

local function scenarioText(ch)
	local e = scEdit
	if not e or not ch or ch == "" or ch:byte(1) < 32 then
		return false
	end
	if e.row.kind == "num" then
		if not ch:match("^%d$") or #e.buf >= e.row.max then
			return true
		end
	elseif e.row.kind == "time" then
		if not ch:match("^[%d:.,]$") or #e.buf >= e.row.max then
			return true
		end
	elseif e.row.kind == "id" then
		ch = ch:lower()
		if not ch:match("^[a-z0-9]$") or #e.buf >= e.row.max then
			return true
		end
	elseif #e.buf + #ch > e.row.max then
		return true
	end
	e.buf = e.buf .. ch
	return true
end

local function drawMenuBody()
	local x1, y0, x2, y1 = panelRect()
	local mx, my = Spring.GetMouseState()
	drawTeamStrip()
	gl.Color(0, 0, 0, 0.65)
	gl.Rect(x1, y0, x2, y1)
	Shared.drawButtons((headerRects()), 27 * S, Shared.m.HB)
	if collapsed then
		return
	end
	gl.Color(1, 1, 1, 1)
	-- with Tower Defense on (tick box) or its page open the title says so
	gl.Text(ctf.open and "Level Editor - Capture the Flag" or ((td.open or td.cfg().enabled) and "Level Editor - Tower Defense" or "Level Editor"), x1 + 8 * S, y1 - 34 * S, 28 * S, "o")
	local rect = contentRect()
	if scenarioOpen then
		drawScenario(rect, mx, my)
		return
	end
	if td.open then
		td.draw(rect)
		return
	end
	if ctf.open then
		ctf.draw(rect)
		return
	end
	if gen.open then
		local rects, labels = genLayout(rect)
		Shared.drawButtons(rects, 24 * S, Shared.m.HB)
		for _, l in ipairs(labels) do
			if l.head then
				gl.Color(0.5, 0.8, 1, 1)
			else
				gl.Color(1, 1, 1, 1)
			end
			gl.Text(l.text, l.x, l.y, l.size, "o")
		end
		gl.Color(1, 1, 1, 1)
		return
	end
	if optionsOpen then
		optionsUI:draw(rect, mx, my)
		drawLevels(rect, mx, my)
		return
	end
	if menuMode == "features" then
		fGrid:draw(rect, mx, my, armedFeature or nil, inPanel(mx, my))
		gl.Color(1, 1, 1, 1)
		gl.Text(armedFeature and "Left click places, right click ends, Del deletes" or "Click a feature, then place it on the map",
			(x1 + x2) / 2, y1 + 8 * S, 24 * S, "co")
		if armedFeature then
			gl.Text("Shift = row, Shift+Alt = rectangle, Shift+Mouse wheel = spacing (" .. spacing .. ")", (x1 + x2) / 2, y1 + 8 * S + 30 * S, 20 * S, "co")
		end
		return
	end
	if menuMode == "fav" then
		fav:draw(rect, mx, my, inPanel(mx, my))
		gl.Color(1, 1, 1, 1)
		gl.Text("Click to use a blueprint or unit again", (x1 + x2) / 2, y1 + 8 * S, 24 * S, "co")
		return
	end
	if menuMode == "units" then
		uGrid:draw(rect, mx, my, armedUnit and unitName or nil, nil, inPanel(mx, my))
		-- Hint above the menu (as with the blueprints)
		gl.Color(1, 1, 1, 1)
		local uhint = armedUnit and "Left click places, right click ends, [ and ] rotate" or "Click a unit, then place it on the map"
		gl.Text(uhint, (x1 + x2) / 2, y1 + 8 * S, 24 * S, "co")
		if armedUnit then
			gl.Text("Shift = row, Shift+Alt = rectangle, Shift+Mouse wheel = spacing (" .. spacing .. ")", (x1 + x2) / 2, y1 + 8 * S + 30 * S, 20 * S, "co")
		end
		return
	end
	bpGrid:draw(rect, mx, my, inPanel(mx, my))
	gl.Color(1, 1, 1, 1)
	local hint = bpGrid.armed and "Left click places, right click ends" or "Click a tile, drag = sort"
	gl.Text(hint, (x1 + x2) / 2, y1 + 8 * S, 24 * S, "co")
	if bpGrid.armed then
		gl.Text("Shift = row, Shift+Alt = rectangle, Shift+Mouse wheel = spacing (" .. spacing .. ")", (x1 + x2) / 2, y1 + 8 * S + 30 * S, 20 * S, "co")
	end
end

local function drawMenu()
	drawMenuBody()
	if not collapsed or true then
		local mx, my = Spring.GetMouseState()
		Shared.drawTip((headerRects()), mx, my)
	end
end

-- Row (Shift) or rectangle (Shift+Alt) from the start point to the mouse pointer, snapped to the grid
local function stampList(ud, pos)
	local alt = Spring.GetModKeyState()
	local raw = Shared.stampPositions(ud, facing, stampDrag.x, stampDrag.z, pos[1], pos[3], alt, spacing, 2000)
	local out = {}
	for _, p in ipairs(raw) do
		out[#out + 1] = { x = snap(p.x), z = snap(p.z) }
	end
	return out
end

local function setSpacing(v)
	spacing = Shared.clampSpacing(v)
	say("Spacing: " .. spacing)
end

-- Centers of the blueprint copies (row/rectangle) from the start point to pos; blueprint hull plus spacing
local function bpStampList(bp, pos)
	local alt = Spring.GetModKeyState()
	local fx, fz = Shared.blueprintExtent(bp.units, bpRot)
	local raw = Shared.stampPositionsSized(fx, fz, stampDrag.x, stampDrag.z, pos[1], pos[3], alt, spacing, 100)
	local out = {}
	for _, p in ipairs(raw) do
		out[#out + 1] = { x = snap(p.x), z = snap(p.z) }
	end
	return out
end

-- Positions of the feature copies (row/rectangle) from the start point to pos; size from the feature's radius plus spacing
local function featStampList(name, pos)
	local alt = Spring.GetModKeyState()
	local fd = FeatureDefNames[name]
	local size = math.max(32, 2 * ((fd and fd.radius) or 16))
	local raw = Shared.stampPositionsSized(size, size, stampDrag.x, stampDrag.z, pos[1], pos[3], alt, spacing, 2000)
	local out = {}
	for _, p in ipairs(raw) do
		out[#out + 1] = { x = snap(p.x), z = snap(p.z) }
	end
	return out
end

-- Menu input
function widget:SelectionChanged(sel)
	if sel and #sel > 0 then
		foreignSel = {} -- a normal selection replaces the editor selection
	end
end

-- For tests: the Capture the Flag page
function widget:DebugCtf()
	return ctf
end

-- For tests without the game: position of the buttons and the content area
function widget:DebugLayout()
	rescale()
	return (headerRects()), contentRect(), teamRects(), levelRects(contentRect()), scenarioRects(contentRect()), (genLayout(contentRect())), (td.layout(contentRect())), (ctf.layout(contentRect()))
end

-- Button of the column left of the team strip (V, O, I, ?) under the mouse pointer
local function sideAt(mx, my)
	if not menuOpen or collapsed then
		return nil
	end
	for _, r in ipairs((headerRects())) do
		if r.side and mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
			return r
		end
	end
end

function widget:IsAbove(mx, my)
	rescale()
	return inPanel(mx, my) or teamAt(mx, my) ~= nil or sideAt(mx, my) ~= nil
end

area = Shared.newAreaAttack({
	say = say,
	mouseGround = function()
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			return pos[1], pos[3]
		end
	end,
	inPanel = function(mx, my) return widget:IsAbove(mx, my) end,
	onArm = function()
		-- ends the other modes that use the left mouse button on the map
		armedUnit, armedFeature, stampDrag = false, false, nil
		bpGrid:setArmed(false)
		gen.armed, gen.drag = false, nil
		mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
	end,
})

local genToggle -- Open/close the Generate page (defined below)
local bpQuickSave -- defined below

-- Switch mode / faction / group / tech / settings
local function applyHeader0(r)
	if r.kind == "collapse" then
		collapsed = not collapsed
		bpGrid:resetEdit()
		return
	end
	if r.kind == "help" then
		helpOpen = true
		return
	end
	if r.kind == "del" then
		delToggle(r.value)
		return
	end
	if r.kind == "area" then
		area:toggle(r.value)
		return
	end
	genFinish(true)
	td.finish(true)
	if r.kind == "search" then
		searchFocus(true)
		return
	elseif r.kind == "searchclear" then
		searchSet("")
		return
	end
	searchFocus(false)
	if r.kind == "top" then
		local tdWas = td.open or ctf.open
		td.open, ctf.open = false, false
		if tdWas and r.value == "place" then
			return
		end
		if (r.value == "gen") ~= gen.open then
			genToggle()
		end
		return
	end
	local tdWas, ctfWas = td.open, ctf.open
	ctf.finish(true)
	if r.kind ~= "create" then
		gen.open, gen.armed, gen.drag = false, false, nil
		td.open, ctf.open = false, false
	end
	uGrid:setFocus(false)
	fGrid:setFocus(false)
	bpGrid:setFocus(false)
	scenarioFinish(true)
	if r.kind == "td" then
		bpGrid:resetEdit()
		bpGrid:setArmed(false)
		armedUnit = false
		armedFeature = false
		scenarioOpen, optionsOpen = false, false
		td.open = not tdWas
		td.scroll = 0
		bpGrid.scroll, uGrid.scroll = 0, 0
		return
	end
	if r.kind == "ctf" then
		bpGrid:resetEdit()
		bpGrid:setArmed(false)
		armedUnit = false
		armedFeature = false
		scenarioOpen, optionsOpen = false, false
		ctf.open = not ctfWas
		bpGrid.scroll, uGrid.scroll = 0, 0
		return
	end
	if r.kind == "info" then
		bpGrid:resetEdit()
		bpGrid:setArmed(false)
		armedUnit = false
		armedFeature = false
		scenarioOpen = not scenarioOpen
		optionsOpen = false
		scTeamsAt = -10
		bpGrid.scroll, uGrid.scroll = 0, 0
		return
	end
	if r.kind == "gear" then
		bpGrid:resetEdit()
		bpGrid:setArmed(false)
		armedUnit = false
		armedFeature = false
		scenarioOpen = false
		optionsOpen = not optionsOpen
		levelConfirm = nil
		if optionsOpen then
			scanLevels()
		end
		bpGrid.scroll, uGrid.scroll = 0, 0
		return
	end
	if r.kind == "mode" then
		optionsOpen = false
		scenarioOpen = false
	end
	if r.kind == "create" then
		bpGrid:resetEdit()
		bpGrid:setArmed(false)
		bpQuickSave()
		return
	elseif r.kind == "mode" then
		if menuMode ~= r.value then
			bpGrid:resetEdit()
			menuMode = r.value
			bpGrid:setArmed(false)
			armedUnit = false
			armedFeature = false
		end
	elseif menuMode == "features" and fGrid:applyFilter(r) then
		return
	elseif menuMode == "bp" and bpGrid:applyFilter(r) then
		return
	elseif menuMode == "units" and uGrid:applyFilter(r) then
		return
	end
	bpGrid.scroll, uGrid.scroll = 0, 0
end

local function applyHeader(r)
	applyHeader0(r)
	-- a filter click (faction, group, tech, feature kind) ends the search: the grids then show their category again
	if uGrid.query ~= search.query or fGrid.query ~= search.query then
		searchSet("")
	end
end

-- Maze (key M): drag a rectangle, a random maze of dragon teeth or walls appears in it.
-- The tiles are 16 Elmo (footprint of the unit), a corridor is gen.mazePath tiles wide.
local MAZE_MAX_WALLS = 12000
local MAZE_KINDS = {
	{ suffix = "drag", label = "Dragon teeth" },
	{ suffix = "fort", label = "Walls" },
}
local mazeDrag = nil -- { x, z }: start point of the rectangle

local function mazeUnitName(kind)
	local fac = gen.faction -- same faction as on the Generate page (each faction has its own dragon teeth and walls)
	local name = fac .. (kind.suffix == "fort" and (fac == "leg" and "forti" or "fort") or "drag")
	return UnitDefNames[name] and name or nil
end

-- Maze grid for a rectangle from the start point to (x, z): origin, cells and extent
local function mazeLayout(x0, z0, x1, z1)
	local ax, az = snap(math.min(x0, x1)), snap(math.min(z0, z1))
	local bx, bz = snap(math.max(x0, x1)), snap(math.max(z0, z1))
	local tilesX, tilesZ = math.floor((bx - ax) / 16) + 1, math.floor((bz - az) / 16) + 1
	local pitch = gen.mazePath + 1
	local cols, rows = math.floor((tilesX - 1) / pitch), math.floor((tilesZ - 1) / pitch)
	-- capped so tens of thousands of units do not appear (walls are about a third of the tiles)
	while (cols * pitch + 1) * (rows * pitch + 1) > MAZE_MAX_WALLS * 3 and (cols > 1 or rows > 1) do
		if cols >= rows then
			cols = cols - 1
		else
			rows = rows - 1
		end
	end
	return { x = ax, z = az, cols = cols, rows = rows, w = cols * pitch + 1, h = rows * pitch + 1 }
end

local function mazeSetKind(k)
	mazeKind = k
	mazeDrag = nil
	if k then
		gen.mazeSel = k
		delMode, delDrag = false, nil
		gen.armed, gen.drag = false, nil
		armedUnit, armedFeature = false, false
		stampDrag = nil
		bpGrid:setArmed(false)
		say("Maze of " .. MAZE_KINDS[k].label .. ": drag " .. (gen.shape == "circle" and "a circle from its center" or "a rectangle") .. " with the left mouse button held down. M switches, right click ends.")
	else
		say("Maze mode ended")
	end
end

delToggle = function(shape)
	if delMode and (shape == nil or shape == delMode) then
		delMode = false
	else
		delMode = shape or "rect"
	end
	delDrag = nil
	if delMode then
		gen.armed, gen.drag = false, nil
		mazeKind, mazeDrag = nil, nil
		armedUnit, armedFeature = false, false
		stampDrag = nil
		bpGrid:setArmed(false)
		local what = { rect = "a rectangle", circle = "a circle from its center", line = "a line (a corridor of " .. (2 * DEL_HALF_WIDTH) .. " Elmo)", fix = "a rectangle", unfix = "a rectangle" }
		if delMode == "fix" or delMode == "unfix" then
			say("Drag " .. what[delMode] .. " with the left mouse button held down, the buildings in it become " .. (delMode == "fix" and "indestructible" or "destructible again") .. ". The button or right click ends, Ctrl+Z undoes it.")
		else
			say("Delete: drag " .. what[delMode] .. " with the left mouse button held down, everything in it is deleted. The button, D or right click ends, Ctrl+Z undoes it.")
		end
	else
		say("Delete mode ended")
	end
end

genToggle = function()
	genFinish(true)
	gen.open = not gen.open
	gen.armed, gen.drag = false, nil
	optionsOpen, scenarioOpen = false, false
	armedUnit, armedFeature = false, false
	bpGrid:setArmed(false)
	mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
	bpGrid.scroll, uGrid.scroll = 0, 0
end

mazeCycle = function()
	local k = (mazeKind or 0) + 1
	mazeSetKind(k <= #MAZE_KINDS and k or nil)
end

local function mazeBuild(lay, circ)
	local kind = MAZE_KINDS[mazeKind]
	local name = mazeUnitName(kind)
	if not name then
		say("This faction has no " .. kind.label .. " in this game")
		return
	end
	if lay.cols < 2 or lay.rows < 2 then
		say("Rectangle too small, at least " .. (2 * (gen.mazePath + 1) + 1) * 16 .. " Elmo in both directions")
		return
	end
	local walls = Shared.mazeWalls(lay.cols, lay.rows, gen.mazePath)
	if circ then
		local inside = {}
		for _, w in ipairs(walls) do
			local dx, dz = lay.x + w[1] * 16 - circ.x, lay.z + w[2] * 16 - circ.z
			if dx * dx + dz * dz <= circ.r * circ.r then
				inside[#inside + 1] = w
			end
		end
		walls = inside
	end
	ledStep()
	for _, t in ipairs(walls) do
		placeQueue[#placeQueue + 1] = string.format("led|place|%s|%d|%d|%d|%d|%d", name, team, lay.x + t[1] * 16, lay.z + t[2] * 16, 0, neutralOn and 1 or 0)
	end
	say(string.format("Maze: %d x %d cells, %d x %s (entrance top left, exit bottom right)", lay.cols, lay.rows, #walls, name))
end

-- ---------------------------------------------------------------- Tower Defense (button TD)
-- Waves of enemies walk from the spawn point along a path to the goal; the walls of the path are built here, the waves
-- themselves by the gadget td_waves.lua. The settings (td.data) are saved in their own section towerdefense of the level file.
-- Everything is a field of td: the file is close to the limit of 200 locals.
td.FAC = { "arm", "cor", "leg" }
td.FAC_TXT = { arm = "Armada", cor = "Cortex", leg = "Legion" }
td.MAX_WAVES = 30
td.VISIBLE = 8 -- rows of the wave table shown at once (mouse wheel scrolls)
td.tfac, td.ttech = "arm", 1 -- tower list of the page: faction and tech level shown
td.tcat = "tower" -- category of the list: tower | economy | radar
td.tscroll, td.TROWS = 0, 4 -- first row shown, rows shown at most (mouse wheel scrolls)
td.GOAL_RADIUS = 120 -- as in td_waves.lua: an enemy this close to the goal got through
function td.new()
	return { enabled = false, width = 8, leaks = 10, economy = true, fog = true, waypoints = {}, banned = {}, bannedTech = {}, waves = { { fac = "arm", kind = "vb", tech = "1", count = 10, gap = 0, hp = 100 } } }
end
td.DEFAULT = td.new()

-- Settings (td.data = section towerdefense of the level): without write the stored ones or the defaults (never
-- changed by the caller); with write they are created
function td.cfg(write)
	if type(td.data) == "table" then
		return td.data
	end
	if not write then
		return td.DEFAULT
	end
	td.data = td.new()
	return td.data
end

-- Lua text of a table of numbers, strings and booleans (arrays and records), for the level file
function td.lua(v, indent)
	local kind = type(v)
	if kind == "number" then
		return v == math.floor(v) and string.format("%d", v) or tostring(v)
	elseif kind == "boolean" then
		return tostring(v)
	elseif kind == "string" then
		return string.format("%q", v)
	elseif kind ~= "table" then
		return "nil"
	end
	local inner = indent .. "\t"
	local parts = {}
	if next(v) == nil or v[1] ~= nil then
		local flat = true
		for _, e in ipairs(v) do
			if type(e) == "table" then
				flat = false
			end
		end
		for _, e in ipairs(v) do
			parts[#parts + 1] = td.lua(e, inner)
		end
		if flat then
			return "{ " .. table.concat(parts, ", ") .. (#parts > 0 and " }" or "}")
		end
		return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. ",\n" .. indent .. "}"
	end
	local keys = {}
	for k in pairs(v) do
		keys[#keys + 1] = tostring(k)
	end
	table.sort(keys)
	for _, k in ipairs(keys) do
		parts[#parts + 1] = k .. " = " .. td.lua(v[k], inner)
	end
	return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. ",\n" .. indent .. "}"
end

function td.height()
	local _, _, h = td.layout({ x1 = 0, x2 = math.floor(780 * S), top = 0 })
	return h
end

function td.resize(n)
	local c = td.cfg(true)
	n = math.max(1, math.min(td.MAX_WAVES, n))
	while #c.waves < n do
		local last = c.waves[#c.waves]
		c.waves[#c.waves + 1] = { fac = td.chosen(last, "fac"), kind = td.chosen(last, "kind"), tech = td.chosen(last, "tech"), count = last.count, gap = math.max(last.gap, 10), hp = last.hp }
	end
	while #c.waves > n do
		c.waves[#c.waves] = nil
	end
	td.scroll = math.max(0, math.min(td.scroll, #c.waves - td.VISIBLE))
end

-- Selection of a wave row as short strings: fac "armcor", tech "12", kind "vb" (v = vehicles, b = bots, h = hovercraft).
td.CHOICES = {
	fac = { "arm", "cor", "leg" },
	tech = { "1", "2", "3" },
	kind = { "v", "b", "h" },
}
function td.chosen(w, field)
	local s = tostring(w[field] or "")
	if s == "" then
		s = field == "fac" and "arm" or (field == "kind" and "vb" or "1")
	end
	local out = {}
	for _, v in ipairs(td.CHOICES[field]) do
		if s:find(v, 1, true) then
			out[#out + 1] = v
		end
	end
	if #out == 0 then
		out[1] = td.CHOICES[field][1]
	end
	return table.concat(out)
end

-- Toggles one choice; at least one stays on
function td.toggleChoice(w, field, v)
	local cur = td.chosen(w, field)
	local on = cur:find(v, 1, true) ~= nil
	if on and #cur == #v then
		return
	end
	local out = {}
	for _, c in ipairs(td.CHOICES[field]) do
		if (c == v) ~= (cur:find(c, 1, true) ~= nil) then
			out[#out + 1] = c
		end
	end
	w[field] = table.concat(out)
end

-- Categories of the list: Towers, with "Towers + economy" also Economy, with fog of war also Radars
function td.cats()
	local c = td.cfg()
	local out = { { "tower", "Towers" } }
	if c.economy ~= false then
		out[#out + 1] = { "economy", "Economy" }
	end
	if c.fog ~= false then
		out[#out + 1] = { "radar", "Radars" }
	end
	local ok = false
	for _, e in ipairs(out) do
		ok = ok or e[1] == td.tcat
	end
	if not ok then
		td.tcat = "tower"
	end
	return out
end

-- Structures of the page for a faction, tech level and category (land only)
function td.turrets(fac, tech, cat)
	if not td.tcache then
		local cache = Shared.buildUnitCache()
		td.tcache = {}
		for _, f in ipairs(td.FAC) do
			td.tcache[f] = { {}, {}, {} }
			for t = 1, 3 do
				local buckets = { tower = {}, economy = {}, radar = {} }
				for _, e in ipairs(cache[f].buildings[t]) do
					local cls = e.rank < 100 and Shared.buildClass(UnitDefs[e.id])
					if cls then
						buckets[cls][#buckets[cls] + 1] = { name = e.name, id = e.id, class = cls }
					end
				end
				for _, cls in ipairs({ "tower", "economy", "radar" }) do
					for _, e in ipairs(buckets[cls]) do
						local list = td.tcache[f][t]
						list[#list + 1] = e
					end
				end
			end
		end
	end
	local out = {}
	for _, e in ipairs(td.tcache[fac][tech]) do
		if e.class == cat then
			out[#out + 1] = e
		end
	end
	return out
end

-- Route state as text for the undo history: "sx,sz;gx,gz;x,z/x,z" ("-" for nothing)
function td.routeState()
	local c = td.cfg()
	local function pt(p)
		return p and string.format("%d,%d", p[1], p[2]) or "-"
	end
	local w = {}
	for _, p in ipairs(c.waypoints or {}) do
		w[#w + 1] = pt(p)
	end
	return pt(c.spawn) .. ";" .. pt(c.goal) .. ";" .. (#w > 0 and table.concat(w, "/") or "-")
end

function td.applyRoute(state)
	local c = td.cfg(true)
	local function pt(s)
		local x, z = tostring(s):match("^(-?%d+),(-?%d+)$")
		return x and { tonumber(x), tonumber(z) } or nil
	end
	local sp, gl_, wp = state:match("^([^;]*);([^;]*);(.*)$")
	c.spawn, c.goal, c.waypoints = pt(sp), pt(gl_), {}
	for s in tostring(wp):gmatch("[^/]+") do
		c.waypoints[#c.waypoints + 1] = pt(s)
	end
end

-- Notes a change of the route as a step of the undo history (before = td.routeState() from before the change)
function td.commit(before)
	local after = td.routeState()
	if after ~= before then
		ledStep()
		led("led|tdroute|" .. before .. "|" .. after)
	end
end

-- Undo / redo from the gadget: take over the new state
function td.pollRoute()
	local n = Spring.GetGameRulesParam("led_tdroute_n")
	if td.routeSeen == nil then
		td.routeSeen = n or 0
	elseif n and n ~= td.routeSeen then
		td.routeSeen = n
		td.applyRoute(Spring.GetGameRulesParam("led_tdroute") or "-;-;-")
	end
end

-- A new waypoint (x, z) goes into the route: onto a drawn line between two points of it (spawn point, waypoints, goal) it is
-- inserted there, otherwise behind the nearest point of the route (spawn point or waypoint)
function td.addWaypoint(x, z)
	local c = td.cfg(true)
	c.waypoints = c.waypoints or {}
	local wps = c.waypoints
	local pts = {} -- { x, z, index in wps (spawn point 0, goal behind the last one) }
	if c.spawn then
		pts[#pts + 1] = { c.spawn[1], c.spawn[2], 0 }
	end
	for i, p in ipairs(wps) do
		pts[#pts + 1] = { p[1], p[2], i }
	end
	if c.goal then
		pts[#pts + 1] = { c.goal[1], c.goal[2], #wps + 1 }
	end
	local at, bestD = nil, 48 ^ 2 -- on the line: within 48 Elmo
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len2 = dx * dx + dz * dz
		if len2 > 0 then
			local u = ((x - a[1]) * dx + (z - a[2]) * dz) / len2
			if u > 0 and u < 1 then
				local d = (x - a[1] - dx * u) ^ 2 + (z - a[2] - dz * u) ^ 2
				if d < bestD then
					at, bestD = a[3] + 1, d
				end
			end
		end
	end
	if not at then
		local nd = 1e18
		at = #wps + 1
		for _, q in ipairs(pts) do
			if q[3] <= #wps then
				local d = (x - q[1]) ^ 2 + (z - q[2]) ^ 2
				if d < nd then
					nd, at = d, q[3] + 1
				end
			end
		end
	end
	table.insert(wps, at, { math.floor(x), math.floor(z) })
	return #wps
end

-- Route of the enemies between spawn point and goal: the waypoints in their order
function td.route()
	return td.cfg().waypoints or {}
end

-- Index of the waypoint under the mouse pointer (or nil)
function td.waypointAt()
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if not pos then
		return nil
	end
	local best, bd = nil, 64 ^ 2
	for i, p in ipairs(td.cfg().waypoints or {}) do
		local d = (p[1] - pos[1]) ^ 2 + (p[2] - pos[3]) ^ 2
		if d < bd then
			best, bd = i, d
		end
	end
	return best
end

-- What Alt + drag grabs under the mouse pointer: the index of a waypoint, "spawn" or "goal" (or nil)
function td.dragAt()
	local i = td.waypointAt()
	if i then
		return i
	end
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	local c = td.cfg()
	if pos then
		for _, k in ipairs({ "spawn", "goal" }) do
			local p, r = c[k], k == "spawn" and 64 or td.GOAL_RADIUS
			if p and (p[1] - pos[1]) ^ 2 + (p[2] - pos[3]) ^ 2 <= r ^ 2 then
				return k
			end
		end
	end
	return nil
end

-- Del over a waypoint removes it; true when there was one
function td.deleteWaypoint()
	local i = td.open and td.waypointAt()
	if not i then
		return false
	end
	local before = td.routeState()
	table.remove(td.cfg(true).waypoints, i)
	td.commit(before)
	say("Waypoint removed")
	return true
end

-- Arms placing a tower (or other structure) of the page: like a click in the unit list of the Place tab
function td.armUnit(name)
	td.endPick()
	mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
	gen.armed, gen.drag = false, nil
	area:disarm()
	stampDrag = nil
	bpGrid:setArmed(false)
	unitName = name
	armedUnit = true
	armedFeature = false
	say("Unit: " .. name .. ". Left click on the map places, right click ends.")
end

function td.techBanned(t)
	for _, v in ipairs(td.cfg().bannedTech or {}) do
		if v == t then
			return true
		end
	end
	return false
end

-- Forbid all structures of a tech level for the player in the game, or allow them again
function td.toggleTech(t)
	local c = td.cfg(true)
	c.bannedTech = c.bannedTech or {}
	for i, v in ipairs(c.bannedTech) do
		if v == t then
			table.remove(c.bannedTech, i)
			return
		end
	end
	c.bannedTech[#c.bannedTech + 1] = t
	table.sort(c.bannedTech)
end

function td.isBanned(name)
	for _, n in ipairs(td.cfg().banned or {}) do
		if n == name then
			return true
		end
	end
	return false
end

-- Forbid a tower for the player in the game (the editor can always place it) or allow it again
function td.toggleBan(name)
	local c = td.cfg(true)
	c.banned = c.banned or {}
	for i, n in ipairs(c.banned) do
		if n == name then
			table.remove(c.banned, i)
			return
		end
	end
	c.banned[#c.banned + 1] = name
	table.sort(c.banned)
end

function td.layout(rect)
	local m = Shared.m
	local c = td.cfg()
	local rects, labels = {}, {}
	local x1, x2 = rect.x1 + m.PAD, rect.x2 - m.PAD
	local y = rect.top - m.PAD
	local gap = 4 * S
	local function line(items)
		local total = 0
		for _, it in ipairs(items) do
			total = total + (it.w or 1)
		end
		local avail, bx = x2 - x1 - gap * (#items - 1), x1
		for _, it in ipairs(items) do
			local w = avail * (it.w or 1) / total
			rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = it.kind, value = it.value, label = it.label, active = it.active,
				fs = it.fs or 22 * S, row = it.row, field = it.field, tint = it.tint, icon = it.icon, tip = it.tip }
			bx = bx + w + gap
		end
		y = y - m.HB - 6 * S
	end
	local function head(text)
		labels[#labels + 1] = { text = text, x = x1, y = y - 26 * S, size = 22 * S, head = true }
		y = y - 32 * S
	end
	local function editing(field, row)
		return td.edit ~= nil and td.edit.field == field and td.edit.row == row
	end
	local function num(field, row, value)
		return editing(field, row) and (td.edit.buf .. "_") or tostring(value)
	end
	line({ { kind = "tdon", label = (c.enabled and "[x] " or "[ ] ") .. "Tower Defense", active = c.enabled, tint = c.enabled and { 0.15, 0.6, 0.2 } or nil,
		tip = "Switch Tower Defense on or off for this level (saved in the level file, section towerdefense)" } })
	-- Walls: material and single pieces; Corridor: walls on both sides of a line (Line, Free) and its width; Route: spawn point, waypoints, goal
	head("Walls")
	line({
		{ kind = "tdmat", value = 1, label = "Teeth", active = td.wall == 1, tip = "Corridor of dragon teeth" },
		{ kind = "tdmat", value = 2, label = "Walls", active = td.wall == 2, tip = "Corridor of walls" },
	})
	line({
		{ kind = "tddraw", field = "corridor", value = "single", label = "Single", active = td.pick == "corridor" and td.mode == "single",
			tip = "Place single wall pieces (indestructible): every click on the map places one piece of the chosen material; hold the mouse button and move it to place a piece in every grid cell. The mode stays on, right click ends it. Ctrl+Z undoes the last click or stroke." },
	})
	head("Corridor (walls on both sides)")
	line({
		{ kind = "tddraw", field = "corridor", value = "line", label = "Line", active = td.pick == "corridor" and td.mode == "line",
			tip = "Build a corridor: click the points on the map, right click builds the walls (indestructible). The mode stays on for the next corridor, right click again ends it. Ctrl+Z undoes it." },
		{ kind = "tddraw", field = "corridor", value = "free", label = "Free", active = td.pick == "corridor" and td.mode == "free",
			tip = "Build a corridor: hold the left mouse button and draw any line, the walls appear when you let go (indestructible). The mode stays on, right click ends it." },
	})
	head("Corridor width (Elmo)")
	local widths = {}
	for _, t in ipairs({ 2, 4, 8, 10, 12 }) do
		widths[#widths + 1] = { kind = "tdwidth", value = t, label = tostring(t * 16), active = c.width == t,
			tip = "Width of the corridor in Elmo (the free space between the walls)" }
	end
	line(widths)
	head("Route (spawn point, waypoints, goal)")
	line({
		{ kind = "tdspawn", label = "Spawn", active = td.pick == "spawn", w = 4,
			tip = "Spawn point of the enemies: click, then click the place on the map" },
		{ kind = "tdspawnx", label = "X", tip = "Delete the spawn point", w = 1 },
		{ kind = "tdwaypoint", label = "Waypoint", active = td.pick == "waypoint", w = 4,
			tip = "Place waypoints: every click on the map adds one (right click ends).\nMove a waypoint: Alt + hold the left mouse button over it and drag.\nRemove one: mouse over it, press Del." },
		{ kind = "tdwaypointx", label = "X", tip = "Delete ALL waypoints.\nA single waypoint: move the mouse over it on the map and press Del.", w = 1 },
		{ kind = "tdgoal", label = "Goal", active = td.pick == "goal", w = 4,
			tip = "Goal: click, then click the place on the map. Enemies that get within 120 Elmo of it are through." },
		{ kind = "tdgoalx", label = "X", tip = "Delete the goal", w = 1 },
	})
	head("Enemies allowed through (more = you lose)")
	line({
		{ kind = "tdminus", value = "leaks", label = "-", tip = "One less enemy allowed through" },
		{ kind = "tdedit", field = "leaks", label = num("leaks", nil, c.leaks), active = editing("leaks"), w = 2,
			tip = "How many enemies may reach the goal before you lose. Click, type a number, Enter accepts" },
		{ kind = "tdplus", value = "leaks", label = "+", tip = "One more enemy allowed through" },
	})
	y = y - 4 * S
	labels[#labels + 1] = { line = true, x1 = x1, x2 = x2, y = y }
	y = y - 10 * S
	head("Waves")
	line({
		{ kind = "tdminus", value = "nwaves", label = "-", tip = "One wave less (the last one is removed)" },
		{ kind = "tdedit", field = "nwaves", label = num("nwaves", nil, #c.waves), active = editing("nwaves"), w = 2,
			tip = "Number of waves. Click, type a number, Enter accepts" },
		{ kind = "tdplus", value = "nwaves", label = "+", tip = "One wave more (a copy of the last one)" },
	})
	-- Table: one row per wave: number, factions, tech levels, types, count, gap, health
	local W = { 0.5, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.55, 0.55, 0.55, 0.9, 0.9, 0.9 }
	local total = 0
	for _, w in ipairs(W) do
		total = total + w
	end
	local avail, cx = x2 - x1 - gap * (#W - 1), {}
	local acc = 0
	for i, w in ipairs(W) do
		cx[i] = x1 + acc / total * avail + gap * (i - 1)
		acc = acc + w
	end
	for _, h in ipairs({ { 1, "#" }, { 2, "Faction" }, { 5, "Tech" }, { 8, "Type" }, { 11, "Count" }, { 12, "Gap s" }, { 13, "HP %" } }) do
		labels[#labels + 1] = { text = h[2], x = cx[h[1]] + 3 * S, y = y - 20 * S, size = 18 * S, head = true }
	end
	y = y - 26 * S
	local TYPE_TIP = { v = "V: vehicles (tanks)", b = "B: bots", h = "H: hovercraft" }
	for k, v in pairs(TYPE_TIP) do
		TYPE_TIP[k] = v .. " (several can be on at once, one always stays on)"
	end
	local last = math.min(#c.waves, td.scroll + td.VISIBLE)
	for i = td.scroll + 1, last do
		local w = c.waves[i]
		local items = { { kind = "tdnone", label = tostring(i), w = W[1], tint = { 0.15, 0.3, 0.5 }, tip = "Wave " .. i } }
		local facs, techs, kinds = td.chosen(w, "fac"), td.chosen(w, "tech"), td.chosen(w, "kind")
		for k, f in ipairs(td.CHOICES.fac) do
			items[#items + 1] = { kind = "tdtog", row = i, field = "fac", value = f, label = "", icon = Shared.FACTION_ICONS[f], active = facs:find(f, 1, true) ~= nil,
				w = W[1 + k], tip = td.FAC_TXT[f] .. " (several can be on at once, one always stays on)" }
		end
		for k, t in ipairs(td.CHOICES.tech) do
			items[#items + 1] = { kind = "tdtog", row = i, field = "tech", value = t, label = "T" .. t, active = techs:find(t, 1, true) ~= nil, w = W[4 + k], fs = 18 * S,
			tip = "T" .. t .. ": tech level " .. t .. " units (several can be on at once, one always stays on)" }
		end
		for k, v in ipairs(td.CHOICES.kind) do
			items[#items + 1] = { kind = "tdtog", row = i, field = "kind", value = v, label = v:upper(), active = kinds:find(v, 1, true) ~= nil, w = W[7 + k], tip = TYPE_TIP[v] }
		end
		items[#items + 1] = { kind = "tdcell", row = i, field = "count", label = num("count", i, w.count), active = editing("count", i), w = W[11], tip = "Number of enemies in this wave. Click, type a number, Enter accepts" }
		items[#items + 1] = { kind = "tdcell", row = i, field = "gap", label = num("gap", i, w.gap), active = editing("gap", i), w = W[12], tip = "Gap: seconds after the previous wave (wave 1: after the start). 0 = at once. Click, type a number, Enter accepts" }
		items[#items + 1] = { kind = "tdcell", row = i, field = "hp", label = num("hp", i, w.hp), active = editing("hp", i), w = W[13], tip = "Strength of the enemies in percent: 100 = normal, 200 = double health" }
		line(items)
	end
	if #c.waves > td.VISIBLE then
		labels[#labels + 1] = { text = string.format("Waves %d-%d of %d (mouse wheel scrolls)", td.scroll + 1, last, #c.waves), x = x1, y = y - 18 * S, size = 17 * S }
		y = y - 24 * S
	end
	y = y - 6 * S
	labels[#labels + 1] = { line = true, x1 = x1, x2 = x2, y = y }
	y = y - 10 * S
	head("Restrictions")
	local economy, fog = c.economy ~= false, c.fog ~= false
	line({
		{ kind = "tdeconomy", label = (economy and "[x] " or "[ ] ") .. "Economy", active = economy,
			tip = "On: the player can also build economy structures (metal extractors, solar, wind and other power plants, storage, converters); the list below shows them too, so you can forbid single ones. Off: towers only. Towers can always be built." },
		{ kind = "tdfog", label = (fog and "[x] " or "[ ] ") .. "Fog of war", active = fog,
			tip = "On: fog of war in the game, the player can build radars (they are in the list below). Off: no radars, the whole map is visible. The editor always shows the whole map." },
	})
	local facs = {}
	for _, f in ipairs(td.FAC) do
		facs[#facs + 1] = { kind = "tdfac", value = f, label = td.FAC_TXT[f], icon = Shared.FACTION_ICONS[f], active = td.tfac == f,
			tip = "Show the towers of " .. td.FAC_TXT[f] }
	end
	line(facs)
	local cats = {}
	for _, ct in ipairs(td.cats()) do
		cats[#cats + 1] = { kind = "tdcat", value = ct[1], label = ct[2], active = td.tcat == ct[1], tip = "Show the " .. ct[2]:lower() .. " of the list" }
	end
	line(cats)
	local techs = {}
	for t = 1, 3 do
		if #td.turrets(td.tfac, t, td.tcat) > 0 then
			techs[#techs + 1] = { kind = "tdtech", value = t, label = "T" .. t, active = td.ttech == t, tip = "Show the tech level " .. t .. " towers" }
		end
	end
	if #techs > 0 and #td.turrets(td.tfac, td.ttech, td.tcat) == 0 then
		td.ttech = techs[1].value
	end
	line(techs)
	local base = #rects - #techs
	for i = 1, #techs do
		local rt = rects[base + i]
		local xs = (rt.y1 - rt.y0) * 0.7
		local tb = td.techBanned(rt.value)
		if tb then
			rt.tint = { 0.4, 0.12, 0.12 }
		end
		rects[#rects + 1] = { x1 = rt.x2 - xs - 4 * S, x2 = rt.x2 - 4 * S, y0 = (rt.y0 + rt.y1) / 2 - xs / 2, y1 = (rt.y0 + rt.y1) / 2 + xs / 2, kind = "tdtechx",
			value = rt.value, label = "", banned = tb,
			tip = tb and ("Tech level " .. rt.value .. " is forbidden: no structure of it can be built in the game. Click to allow it again.") or
				("Click: the player can build no structure of tech level " .. rt.value .. " (towers and economy) in the game.") }
	end
	local list = td.turrets(td.tfac, td.ttech, td.tcat)
	local cols, gapT = 8, 4 * S
	local tw = (x2 - x1 - gapT * (cols - 1)) / cols
	local rows = math.ceil(#list / cols)
	local shown = math.min(rows, td.TROWS)
	td.tscroll = math.max(0, math.min(td.tscroll, rows - shown))
	for i = td.tscroll * cols + 1, math.min(#list, (td.tscroll + shown) * cols) do
		local e = list[i]
		local col, row = (i - 1) % cols, math.floor((i - 1) / cols) - td.tscroll
		local tx, ty = x1 + col * (tw + gapT), y - row * (tw + gapT)
		local banned = td.isBanned(e.name)
		rects[#rects + 1] = { x1 = tx, x2 = tx + tw, y0 = ty - tw, y1 = ty, kind = "tdtile", value = e.name, id = e.id, label = "",
			banned = banned or td.techBanned(td.ttech), armed = armedUnit and unitName == e.name }
		local xs = tw * 0.36
		rects[#rects + 1] = { x1 = tx + tw - xs, x2 = tx + tw, y0 = ty - xs, y1 = ty, kind = "tdban", value = e.name, id = e.id, label = "", banned = banned,
			tip = banned and "Forbidden: the player cannot build this in the game. Click to allow it again." or
				"Click: the player cannot build this in the game (in the editor you can always place it)." }
	end
	y = y - shown * (tw + gapT) - 8 * S
	if rows > shown then
		labels[#labels + 1] = { text = string.format("Rows %d-%d of %d (mouse wheel scrolls)", td.tscroll + 1, td.tscroll + shown, rows), x = x1, y = y - 14 * S, size = 17 * S }
		y = y - 22 * S
	end
	y = y - 4 * S
	-- very bottom: the button that starts the test (red message above it: what is missing)
	local state = Spring.GetGameRulesParam("tdState") or ""
	local running = state == "running"
	if td.notice and os.clock() < td.notice.untilT then
		labels[#labels + 1] = { text = td.notice.text, x = x1, y = y - 20 * S, size = 19 * S, color = { 1, 0.4, 0.35 } }
	end
	y = y - 26 * S
	line({ { kind = "tdplay", label = running and "Stop" or (state ~= "" and "Reset" or "Start test"), active = running, fs = 26 * S,
		tint = running and { 0.8, 0.15, 0.15 } or { 0.15, 0.6, 0.2 }, -- red while running, green otherwise
		tip = "Start test: runs the waves in the editor (the state before is saved as _beforeplay). Stop / Reset ends it and brings that state back." } })
	y = y - m.PAD
	return rects, labels, rect.top - y
end

-- Tower tiles: the picture, a red X in the upper right corner (button), a big red X over a forbidden tower; the 3D model and
-- the data of the tower under the mouse pointer as in the unit list
function td.drawTiles(rect, tiles)
	local mx, my = Spring.GetMouseState()
	local hover
	for _, r in ipairs(tiles) do
		if r.kind == "tdtile" then
			local over = mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1
			if r.armed then
				gl.Color(0.25, 0.5, 1, 0.8)
				gl.Rect(r.x1 - 3, r.y0 - 3, r.x2 + 3, r.y1 + 3)
			end
			if over then
				hover = r
				gl.Color(1, 1, 1, 0.35)
				gl.Rect(r.x1 - 2, r.y0 - 2, r.x2 + 2, r.y1 + 2)
			end
			gl.Color(1, 1, 1, r.banned and 0.35 or 1)
			gl.Texture("#" .. r.id)
			gl.TexRect(r.x1, r.y0, r.x2, r.y1)
			gl.Texture(false)
			if r.banned then
				gl.Color(1, 0.1, 0.1, 1)
				gl.LineWidth(5 * S)
				gl.BeginEnd(GL.LINES, function()
					gl.Vertex(r.x1 + 4 * S, r.y0 + 4 * S)
					gl.Vertex(r.x2 - 4 * S, r.y1 - 4 * S)
					gl.Vertex(r.x1 + 4 * S, r.y1 - 4 * S)
					gl.Vertex(r.x2 - 4 * S, r.y0 + 4 * S)
				end)
				gl.LineWidth(1)
			end
		end
	end
	for _, r in ipairs(tiles) do
		if r.kind == "tdban" or r.kind == "tdtechx" then
			if r.kind == "tdtechx" and r.banned then
				gl.Color(0.8, 0.1, 0.1, 0.95)
			else
				gl.Color(0, 0, 0, 0.75)
			end
			gl.Rect(r.x1, r.y0, r.x2, r.y1)
			gl.Color(1, 0.15, 0.15, 1)
			gl.LineWidth(3 * S)
			local g = (r.x2 - r.x1) * 0.22
			gl.BeginEnd(GL.LINES, function()
				gl.Vertex(r.x1 + g, r.y0 + g)
				gl.Vertex(r.x2 - g, r.y1 - g)
				gl.Vertex(r.x1 + g, r.y1 - g)
				gl.Vertex(r.x2 - g, r.y0 + g)
			end)
			gl.LineWidth(1)
		end
	end
	gl.Color(1, 1, 1, 1)
	if hover then
		local size = Shared.PREVIEW_SIZE * S
		local px, py = Shared.previewPos(rect, hover.y0, hover.y1 - hover.y0, size)
		pcall(Shared.drawUnitPreview, hover.id, px, py, size)
		gl.Color(1, 1, 1, 1)
		local ud = UnitDefs[hover.id]
		local cx = (rect.x1 + rect.x2) / 2
		gl.Text(string.format("%s (%s)%s", ud.translatedHumanName or ud.humanName or hover.value, hover.value, hover.banned and "  - forbidden" or ""), cx, rect.y0 - 40 * S, 29 * S, "co")
		gl.Text(string.format("Metal %d   Energy %d", ud.metalCost or 0, ud.energyCost or 0), cx, rect.y0 - 78 * S, 26 * S, "co")
	end
end

function td.draw(rect)
	local rects, labels = td.layout(rect)
	local buttons, tiles = {}, {}
	for _, r in ipairs(rects) do
		if r.kind == "tdtile" or r.kind == "tdban" or r.kind == "tdtechx" then
			tiles[#tiles + 1] = r
		else
			buttons[#buttons + 1] = r
		end
	end
	Shared.drawButtons(buttons, 22 * S, Shared.m.HB)
	td.drawTiles(rect, tiles)
	for _, r in ipairs(rects) do
		if r.kind == "tdspawn" or r.kind == "tdgoal" then
			local cr, cg, cb = 0.3, 1, 0.4
			if r.kind == "tdgoal" then
				cr, cg, cb = 1, 0.35, 0.3
			end
			local mx0, my0, rad = r.x1 + 18 * S, (r.y0 + r.y1) / 2, (r.y1 - r.y0) * 0.26
			gl.Color(cr, cg, cb, 1)
			gl.BeginEnd(GL.TRIANGLE_FAN, function()
				gl.Vertex(mx0, my0)
				for k = 0, 24 do
					local a = k / 24 * 2 * math.pi
					gl.Vertex(mx0 + math.cos(a) * rad, my0 + math.sin(a) * rad)
				end
			end)
		end
	end
	for _, l in ipairs(labels) do
		if l.line then
			gl.Color(0.3, 0.85, 0.4, 1)
			gl.Rect(l.x1, l.y - 3 * S, l.x2, l.y)
		elseif l.color then
			gl.Color(l.color[1], l.color[2], l.color[3], 1)
		elseif l.head then
			gl.Color(0.5, 0.8, 1, 1)
		else
			gl.Color(0.8, 0.8, 0.8, 1)
		end
		if l.text then
			gl.Text(l.text, l.x, l.y, l.size, "o")
		end
	end
	gl.Color(1, 1, 1, 1)
	local mx, my = Spring.GetMouseState()
	Shared.drawTip(rects, mx, my)
end

-- Ends the entry in a number field (accept: take the value)
function td.finish(accept)
	local e = td.edit
	if not e then
		return
	end
	td.edit = nil
	widgetHandler:DisownText()
	local v = tonumber(e.buf)
	if not accept or not v then
		return
	end
	v = math.floor(v)
	if e.field == "nwaves" then
		td.resize(v)
	elseif e.field == "leaks" then
		td.cfg(true).leaks = math.max(0, math.min(999, v))
	else
		local w = td.cfg(true).waves[e.row]
		if w then
			local limits = { count = { 1, 200 }, gap = { 0, 3600 }, hp = { 10, 5000 } }
			w[e.field] = math.max(limits[e.field][1], math.min(limits[e.field][2], v))
		end
	end
end

function td.key(key)
	if key == 13 or key == 271 then
		td.finish(true)
	elseif key == 27 then
		td.finish(false)
	elseif key == 8 then
		td.edit.buf = td.edit.buf:sub(1, -2)
	end
	return true
end

function td.text(ch)
	if ch and ch:match("^%d$") and #td.edit.buf < 5 then
		td.edit.buf = td.edit.buf .. ch
	end
	return true
end

function td.wheel(up)
	local mx, my = Spring.GetMouseState()
	local top, bottom, count = -1e9, 1e9, 0
	for _, r in ipairs((td.layout(contentRect()))) do
		if r.kind == "tdtile" then
			top, bottom, count = math.max(top, r.y1), math.min(bottom, r.y0), count + 1
		end
	end
	if count > 0 and my >= bottom and my <= top then
		local rows = math.ceil(#td.turrets(td.tfac, td.ttech, td.tcat) / 8)
		td.tscroll = math.max(0, math.min(math.max(0, rows - td.TROWS), td.tscroll + (up and -1 or 1)))
		return
	end
	local n = #td.cfg().waves
	td.scroll = math.max(0, math.min(math.max(0, n - td.VISIBLE), td.scroll + (up and -1 or 1)))
end

-- Payload for the gadget (see td_waves.lua)
function td.payload()
	local c = td.cfg()
	if not (c.spawn and c.goal) then
		return nil, "Cannot start the test: " .. (not c.spawn and not c.goal and "spawn point and goal are missing." or (not c.spawn and "the spawn point is missing." or "the goal is missing."))
	end
	local player, enemy
	for _, t in ipairs(scenarioTeams()) do
		local role = scenarioValue({ id = "role", team = t })
		if role == "s" and not player then
			player = t
		elseif role == "e" and not enemy then
			enemy = t
		end
	end
	player = player or 0
	enemy = enemy or (player == 0 and 1 or 0)
	local path, waves = {}, {}
	for _, p in ipairs(td.route()) do
		path[#path + 1] = string.format("%d,%d", p[1], p[2])
	end
	for _, w in ipairs(c.waves) do
		waves[#waves + 1] = string.format("%s,%s,%s,%d,%d,%d", td.chosen(w, "fac"), td.chosen(w, "kind"), td.chosen(w, "tech"), w.count, w.gap, w.hp)
	end
	return table.concat({ enemy, player, c.spawn[1], c.spawn[2], c.goal[1], c.goal[2], c.leaks, #path > 0 and table.concat(path, "/") or "-", table.concat(waves, "/"), #(c.banned or {}) > 0 and table.concat(c.banned, ",") or "-",
		#(c.bannedTech or {}) > 0 and table.concat(c.bannedTech, ",") or "-", c.economy ~= false and "economy" or "towers", c.fog ~= false and "1" or "0",
		math.floor(scenario and tonumber(scenario.metal) or 1000), math.floor(scenario and tonumber(scenario.energy) or 1000) }, ";")
end

-- Ends the pick mode (spawn point, goal, corridor, route)
function td.endPick()
	td.pick, td.pts, td.stroke = nil, {}, nil
end

-- Arms picking on the map: "spawn" or "goal" (one click), or drawing: kind "corridor" (builds the walls on both sides of
-- the drawn line) or "route" (only the way the enemies walk), mode "line" (click points) or "free" (hold the mouse button
-- and drag); the same button again ends it
function td.startPick(kind, mode)
	td.finish(true)
	local same = td.pick == kind and td.mode == mode
	mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
	gen.armed, gen.drag = false, nil
	armedUnit, armedFeature = false, false
	stampDrag = nil
	bpGrid:setArmed(false)
	area:disarm()
	td.endPick()
	if same then
		say("Tower Defense: mode ended")
		return
	end
	td.pick, td.mode = kind, mode
	local what = kind == "corridor" and "the corridor (walls on both sides)" or "the route of the enemies"
	if mode == "single" then
		say("Click on the map: every click places one wall piece (indestructible). Right click ends, Ctrl+Z undoes.")
	elseif mode == "line" then
		say("Click the points of " .. what .. " on the map (start first), right click finishes (Ctrl+Z undoes).")
	elseif mode == "free" then
		say("Draw " .. what .. " with the left mouse button held down.")
	elseif kind == "waypoint" then
		say("Click the waypoints on the map, right click ends. Del over a waypoint removes it.")
	else
		say((kind == "spawn" and "Spawn point" or "Goal") .. ": click the place on the map, right click cancels.")
	end
end

-- Right click in the pick mode: a drawn line is finished (the corridor is built, undo with Ctrl+Z), otherwise the mode ends
function td.cancel()
	if (td.pick == "corridor" or td.pick == "route") and td.mode == "line" and #td.pts >= 2 then
		td.finishDraw()
		return
	end
	td.endPick()
	say("Tower Defense: mode ended")
end

-- Left click on the map in the pick mode
function td.click(x, z)
	local before = td.routeState()
	if td.pick == "waypoint" then
		local n = td.addWaypoint(x, z)
		td.commit(before)
		say(string.format("Waypoint placed (%d). Click for more, right click ends, Del over a waypoint removes it, Alt + drag moves it.", n))
		return
	end
	if td.pick == "corridor" and td.mode == "single" then
		td.startSingle(x, z)
		td.sdrag = nil -- a click only
		return
	end
	if td.pick == "corridor" or td.pick == "route" then
		td.pts[#td.pts + 1] = { math.floor(x), math.floor(z) }
		say(string.format("%d points. Right click finishes.", #td.pts))
		return
	end
	local c = td.cfg(true)
	c[td.pick] = { math.floor(x), math.floor(z) }
	td.commit(before)
	say(string.format("%s set at %d, %d", td.pick == "spawn" and "Spawn point" or "Goal", x, z))
	td.endPick()
end

-- Points of a hand-drawn line: take a point when the mouse moved far enough (called every frame while drawing)
-- Single wall pieces: a press places one piece (one undo step for the whole press); while the mouse button is held every grid
-- cell the pointer passes gets a piece (td.sample)
-- One wall piece at (x, z); what stands in the way is deleted
function td.wallCell(name, x, z)
	if not makeRoom(name, x, z, 0) then
		return
	end
	notePlaced(name, x, z, 0)
	placeQueue[#placeQueue + 1] = string.format("led|place|%s|%d|%d|%d|%d|%d|1", name, team, x, z, 0, neutralOn and 1 or 0)
end

function td.startSingle(x, z)
	local name = mazeUnitName(MAZE_KINDS[td.wall])
	if not name then
		say("This faction has no " .. MAZE_KINDS[td.wall].label .. " in this game")
		return
	end
	ledStep()
	local gx, gz = math.floor(x / 16 + 0.5), math.floor(z / 16 + 0.5)
	td.sdrag = { name = name, gx = gx, gz = gz, seen = { [gx * 100003 + gz] = true } }
	td.wallCell(name, gx * 16, gz * 16)
end

-- Ends the moving of a waypoint: one undo step
function td.endWpDrag()
	if td.wpDrag then
		td.wpDrag = nil
		td.commit(td.wpBefore)
	end
end

function td.sample()
	if td.sdrag then
		local d = td.sdrag
		local mx, my, left = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if not left then
			td.sdrag = nil
		elseif pos then
			local nx, nz = math.floor(pos[1] / 16 + 0.5), math.floor(pos[3] / 16 + 0.5)
			local steps = math.max(math.abs(nx - d.gx), math.abs(nz - d.gz))
			for k = 1, steps do -- also the cells in between when the mouse moved fast
				local cx, cz = math.floor(d.gx + (nx - d.gx) * k / steps + 0.5), math.floor(d.gz + (nz - d.gz) * k / steps + 0.5)
				local key = cx * 100003 + cz
				if not d.seen[key] then
					d.seen[key] = true
					td.wallCell(d.name, cx * 16, cz * 16)
				end
			end
			d.gx, d.gz = nx, nz
		end
		return
	end
	if td.wpDrag then
		local mx, my, left = Spring.GetMouseState()
		local c = td.cfg()
		local holder = type(td.wpDrag) == "number" and c.waypoints or c -- waypoints[i] or c.spawn / c.goal
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if not left or not (holder and holder[td.wpDrag]) then
			td.endWpDrag()
		elseif pos then
			holder[td.wpDrag] = { math.floor(pos[1]), math.floor(pos[3]) }
		end
		return
	end
	local s = td.stroke
	if not s then
		return
	end
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	local last = s[#s]
	if pos and (pos[1] - last[1]) ^ 2 + (pos[3] - last[2]) ^ 2 >= 48 ^ 2 then
		s[#s + 1] = { math.floor(pos[1]), math.floor(pos[3]) }
	end
end

-- Fewer points for the same line (Douglas-Peucker): a hand-drawn line has far too many
function td.simplify(p, tol)
	if #p <= 2 then
		return p
	end
	local best, at = 0, 0
	local a, b = p[1], p[#p]
	local dx, dz = b[1] - a[1], b[2] - a[2]
	local len = math.sqrt(dx * dx + dz * dz)
	for i = 2, #p - 1 do
		local d = len > 0 and math.abs((p[i][1] - a[1]) * dz - (p[i][2] - a[2]) * dx) / len or math.sqrt((p[i][1] - a[1]) ^ 2 + (p[i][2] - a[2]) ^ 2)
		if d > best then
			best, at = d, i
		end
	end
	if best <= tol then
		return { a, b }
	end
	local left, right = {}, {}
	for i = 1, at do
		left[#left + 1] = p[i]
	end
	for i = at, #p do
		right[#right + 1] = p[i]
	end
	left, right = td.simplify(left, tol), td.simplify(right, tol)
	for i = 2, #right do
		left[#left + 1] = right[i]
	end
	return left
end

-- Distance of a point to the polyline of points p
function td.distToPath(px, pz, p)
	local best = math.huge
	for i = 1, #p - 1 do
		local ax, az, bx, bz = p[i][1], p[i][2], p[i + 1][1], p[i + 1][2]
		local dx, dz = bx - ax, bz - az
		local len2 = dx * dx + dz * dz
		local t = len2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / len2)) or 0
		best = math.min(best, math.sqrt((px - ax - t * dx) ^ 2 + (pz - az - t * dz) ^ 2))
	end
	return best
end

-- Wall pieces left and right of the path: every 8 Elmo along the offset lines, not inside the corridor of another section;
-- on the outer side of every bend an arc around the corner point closes the gap between the two offset lines
function td.wallSpots(p, width)
	local clear = width * 16 / 2 -- half of the free corridor
	local off = clear + 8 -- middle of the wall piece
	local spots, seen = {}, {}
	local function add(x, z)
		local wx, wz = math.floor(x / 16 + 0.5) * 16, math.floor(z / 16 + 0.5) * 16
		local key = wx * 100003 + wz
		if not seen[key] then
			seen[key] = true
			if td.distToPath(wx, wz, p) >= clear - 6 then
				spots[#spots + 1] = { wx, wz }
			end
		end
	end
	for i = 1, #p - 1 do
		local ax, az, bx, bz = p[i][1], p[i][2], p[i + 1][1], p[i + 1][2]
		local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		if len > 0 then
			local dx, dz = (bx - ax) / len, (bz - az) / len
			for s0 = 0, len + 8, 8 do
				local s = math.min(s0, len)
				for _, side in ipairs({ 1, -1 }) do
					add(ax + dx * s - dz * off * side, az + dz * s + dx * off * side)
				end
			end
		end
	end
	for i = 2, #p - 1 do
		local ax, az, bx, bz, cx, cz = p[i - 1][1], p[i - 1][2], p[i][1], p[i][2], p[i + 1][1], p[i + 1][2]
		local l1, l2 = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2), math.sqrt((cx - bx) ^ 2 + (cz - bz) ^ 2)
		if l1 > 0 and l2 > 0 then
			local d1x, d1z, d2x, d2z = (bx - ax) / l1, (bz - az) / l1, (cx - bx) / l2, (cz - bz) / l2
			local side = (d1x * d2z - d1z * d2x) > 0 and -1 or 1 -- the outer side of the bend
			local a1, a2 = math.atan2(d1x * side, -d1z * side), math.atan2(d2x * side, -d2z * side)
			local diff = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
			local n = math.max(1, math.ceil(math.abs(diff) * off / 8))
			for k = 0, n do
				local a = a1 + diff * k / n
				add(bx + math.cos(a) * off, bz + math.sin(a) * off)
			end
		end
	end
	return spots
end

-- Builds the walls on both sides of the line p (one undo step). The wall pieces are indestructible: enemies of higher tech
-- levels would shoot a way through otherwise. Returns true when it built something.
function td.buildWalls(p)
	if not canEdit() then
		return false
	end
	local name = mazeUnitName(MAZE_KINDS[td.wall])
	if not name then
		say("This faction has no " .. MAZE_KINDS[td.wall].label .. " in this game")
		return false
	end
	local c = td.cfg(true)
	local spots = td.wallSpots(p, c.width)
	if #spots > MAZE_MAX_WALLS then
		say("The corridor is too long (more than " .. MAZE_MAX_WALLS .. " wall pieces)")
		return false
	end
	ledStep()
	local made = 0
	for _, s in ipairs(spots) do
		if makeRoom(name, s[1], s[2], 0) then -- W on: what stands in the way is deleted, W off: occupied spots are left out
			notePlaced(name, s[1], s[2], 0)
			placeQueue[#placeQueue + 1] = string.format("led|place|%s|%d|%d|%d|%d|%d|1", name, team, s[1], s[2], 0, neutralOn and 1 or 0)
			made = made + 1
		end
	end
	say(string.format("Corridor: %d indestructible wall pieces (%s)%s. Ctrl+Z undoes it.", made, name, made < #spots and (", " .. (#spots - made) .. " occupied spots left out") or ""))
	return true
end

-- The drawn line (td.pts) is finished: the corridor mode builds the walls and stays on, the route mode takes the line as the route of the
-- enemies and its ends as spawn point and goal
function td.finishDraw()
	local p = td.simplify(td.pts, 24)
	if #p < 2 then
		say("Click at least two points first.")
		return
	end
	if td.pick == "corridor" then
		td.buildWalls(p)
		td.pts, td.stroke = {}, nil -- the mode stays on: the next corridor can be drawn right away (right click ends it)
		return
	end
	td.endPick()
end

function td.press(rect, mx, my)
	local hit
	for _, r in ipairs((td.layout(rect))) do
		if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
			hit = r
		end
	end
	td.finish(true)
	if not hit then
		return true
	end
	local k = hit.kind
	if k == "tdon" then
		local c = td.cfg(true)
		c.enabled = not c.enabled
	elseif k == "tdmat" then
		td.wall = hit.value
	elseif k == "tddraw" then
		td.startPick(hit.field, hit.value)
	elseif k == "tdspawn" then
		td.startPick("spawn")
	elseif k == "tdgoal" then
		td.startPick("goal")
	elseif k == "tdspawnx" or k == "tdgoalx" then
		local before = td.routeState()
		td.cfg(true)[k == "tdspawnx" and "spawn" or "goal"] = nil
		td.commit(before)
	elseif k == "tdwidth" then
		td.cfg(true).width = hit.value
	elseif k == "tdminus" or k == "tdplus" then
		local d = k == "tdplus" and 1 or -1
		if hit.value == "nwaves" then
			td.resize(#td.cfg().waves + d)
		else
			local c = td.cfg(true)
			c.leaks = math.max(0, math.min(999, c.leaks + d))
		end
	elseif k == "tdedit" then
		td.edit = { field = hit.field, buf = "" }
		widgetHandler:OwnText()
	elseif k == "tdtog" then
		td.toggleChoice(td.cfg(true).waves[hit.row], hit.field, hit.value)
	elseif k == "tdcell" then
		td.edit = { field = hit.field, row = hit.row, buf = "" }
		widgetHandler:OwnText()
	elseif k == "tdplay" then
		td.toggle()
	elseif k == "tdfac" then
		td.tfac, td.tscroll = hit.value, 0
	elseif k == "tdtech" then
		td.ttech, td.tscroll = hit.value, 0
	elseif k == "tdcat" then
		td.tcat, td.tscroll = hit.value, 0
	elseif k == "tdtile" then
		td.armUnit(hit.value)
	elseif k == "tdwaypoint" then
		td.startPick("waypoint")
	elseif k == "tdwaypointx" then
		local before = td.routeState()
		td.cfg(true).waypoints = {}
		td.commit(before)
	elseif k == "tdfog" then
		local c = td.cfg(true)
		c.fog, td.tscroll = not (c.fog ~= false), 0
	elseif k == "tdban" then
		td.toggleBan(hit.value)
	elseif k == "tdtechx" then
		td.toggleTech(hit.value)
	elseif k == "tdeconomy" then
		local c = td.cfg(true)
		c.economy, td.tscroll = not (c.economy ~= false), 0
	end
	return true
end

-- Play / Stop (button at the bottom of the TD page): runs the waves in the editor; the state before is saved as _beforeplay and comes back on Stop
function td.toggle()
	local state = Spring.GetGameRulesParam("tdState")
	if state and state ~= "" then
		-- running, won or lost: stop and bring the state before Play back (destroyed towers, wave units)
		Spring.SendLuaRulesMsg("tdw|stop")
		local current = currentLevel
		load_level(nil, nil, { "_beforeplay" })
		currentLevel = current
		say("Stopped: the state before Play is back.")
		return
	end
	local payload, err = td.payload()
	if not payload then
		say(err)
		td.notice = { text = err, untilT = os.clock() + 6 }
		return
	end
	gen.disarmAll()
	saveLevel("_beforeplay", true)
	Spring.SendLuaRulesMsg("tdw|start|" .. payload)
	say("Test started: the state before is saved as _beforeplay; Stop brings it back.")
end

-- Markers in the world (also with the page closed): spawn point (green), goal (red), path and the points being clicked
function td.drawWorld()
	local c = td.cfg()
	if not td.open and not c.spawn and not c.goal and #(c.waypoints or {}) == 0 then
		return -- the markers stay visible with the page closed, so nothing stays hidden
	end
	gl.DepthTest(false)
	gl.LineWidth(3)
	local function circle(p, r, cr, cg, cb)
		gl.Color(cr, cg, cb, 1)
		gl.BeginEnd(GL.LINE_LOOP, function()
			for i = 0, 31 do
				local a = i / 32 * 2 * math.pi
				local x, z = p[1] + math.cos(a) * r, p[2] + math.sin(a) * r
				gl.Vertex(x, Spring.GetGroundHeight(x, z) + 8, z)
			end
		end)
	end
	local function polyline(list, cr, cg, cb, extra)
		gl.Color(cr, cg, cb, 1)
		gl.BeginEnd(GL.LINE_STRIP, function()
			for _, q in ipairs(list) do
				gl.Vertex(q[1], Spring.GetGroundHeight(q[1], q[2]) + 8, q[2])
			end
			if extra then
				gl.Vertex(extra[1], extra[2] + 8, extra[3])
			end
		end)
	end
	if c.spawn then
		circle(c.spawn, 48, 0.3, 1, 0.4)
	end
	if c.goal then
		circle(c.goal, td.GOAL_RADIUS, 1, 0.35, 0.3)
	end
	local route = td.route()
	if c.spawn and c.goal then
		local list = { c.spawn }
		for _, p in ipairs(route) do
			list[#list + 1] = p
		end
		list[#list + 1] = c.goal
		polyline(list, 1, 0.9, 0.3) -- only to look at: the way of the enemies
	end
	local hot = td.open and td.waypointAt() or nil
	for i, p in ipairs(c.waypoints or {}) do
		circle(p, i == hot and 44 or 28, i == hot and 1 or 1, i == hot and 0.3 or 0.9, i == hot and 0.3 or 0.3)
	end
	if (td.pick == "corridor" or td.pick == "route") and td.mode == "line" and #td.pts > 0 then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		polyline(td.pts, 0.4, 0.9, 1, pos)
	end
	if td.stroke and #td.stroke > 1 then
		polyline(td.stroke, 0.4, 0.9, 1)
	end
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

-- Status of the running test (from the gadget) at the top of the screen
function td.hud(vsx, vsy)
	local state = Spring.GetGameRulesParam("tdState")
	if not state or state == "" then
		return
	end
	local text
	if state == "won" then
		text = "TOWER DEFENSE: LEVEL WON"
	elseif state == "lost" then
		text = "TOWER DEFENSE: LEVEL LOST"
	else
		text = string.format("Tower Defense  wave %d/%d  enemies %d  killed %d  through %d/%d",
			Spring.GetGameRulesParam("tdWave") or 0, Spring.GetGameRulesParam("tdWaves") or 0, Spring.GetGameRulesParam("tdAlive") or 0,
			Spring.GetGameRulesParam("tdKilled") or 0, Spring.GetGameRulesParam("tdLeaks") or 0, Spring.GetGameRulesParam("tdMaxLeaks") or 0)
	end
	gl.Color(1, 0.9, 0.4, 1)
	gl.Text(text, vsx * 0.5, vsy - 70 * S, 22 * S, "co")
	gl.Color(1, 1, 1, 1)
end

-- Ends every editor mode (stamp, delete, maze, generate, area attack, picking of the Tower Defense and Capture the Flag points) and every drag;
-- called when a Tower Defense or Capture the Flag test starts, so that no mode swallows the clicks of the game
function gen.disarmAll()
	mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
	gen.armed, gen.drag = false, nil
	armedUnit, armedFeature = false, false
	stampDrag, moveDrag, selBox = nil, nil, nil
	bpGrid:setArmed(false)
	area:disarm()
	td.endPick()
	ctf.endPick()
end

-- Capture the Flag page (LevelEditor/led_ctf.lua): gets the services of the widget
ctf = VFS.Include("luaui/Include/led_ctf.lua", nil, VFS.ZIP_FIRST)({
	Shared = Shared,
	S = function() return S end,
	say = function(text) say(text) end,
	canEdit = function() return canEdit() end,
	team = function() return team end,
	serialize = function(v) return td.lua(v, "\t") end,
	disarm = function()
		mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
		gen.armed, gen.drag = false, nil
		armedUnit, armedFeature = false, false
		stampDrag = nil
		bpGrid:setArmed(false)
		area:disarm()
		td.endPick()
	end,
	disarmAll = function() gen.disarmAll() end,
	step = function() ledStep() end,
	led = function(msg) led(msg) end,
	beforePlay = function() saveLevel("_beforeplay", true) end,
	afterPlay = function()
		local current = currentLevel
		load_level(nil, nil, { "_beforeplay" })
		currentLevel = current
	end,
})

-- Ends every stamp, delete, maze, generate and area-attack mode and every drag in progress (selection frame,
-- Alt + drag move); without an active mode a right click clears the selection; returns true if it did something (a field of gen: the file is close to the limit of 200 locals)
function gen.cancelModes()
	local was = armedUnit or armedFeature or bpGrid.armed or gen.armed or gen.drag or delMode or delDrag
		or mazeKind or mazeDrag or stampDrag or moveDrag or selBox or area:armed() or td.pick or ctf.pick
	if not was then
		local ctfState, tdState = Spring.GetGameRulesParam("ctfState"), Spring.GetGameRulesParam("tdState")
		if (ctfState and ctfState ~= "") or (tdState and tdState ~= "") then
			return false -- a test is running: the right click gives the move order to the selected units
		end
		if #selectedUnits() > 0 then
			foreignSel = {}
			Spring.SelectUnitArray({})
			say("Selection cleared")
			return true
		end
		return false
	end
	armedUnit, armedFeature = false, false
	bpGrid:setArmed(false)
	gen.armed, gen.drag = false, nil
	delMode, delDrag = false, nil
	mazeKind, mazeDrag = nil, nil
	if td.pick then
		td.cancel()
	end
	if ctf.pick then
		ctf.endPick()
	end
	stampDrag, moveDrag, selBox = nil, nil, nil
	area:disarm()
	say("Mode ended")
	return true
end

-- Placing units and features by hand: no overlap, and painting (hold the left mouse button and move) ---------------------------
local paint = nil -- { kind, x, z, sx, sz }: the last point of the stroke while the left mouse button is held down

-- Places the armed unit or feature at (x, z): with W on over what is in the way, with W off only on a free spot; true when it was placed
local function paintPlace(kind, x, z)
	local isF = kind == "feature"
	local name = isF and armedFeature or unitName
	local face = isF and 0 or facing
	if isF then
		x, z = math.floor(x), math.floor(z)
	else
		x, z = snap(x), snap(z)
	end
	if not makeRoom(name, x, z, face, isF) then
		return false
	end
	if isF then
		led(string.format("led|feature|%s|%d|%d|%d", name, x, z, (facing * 16384 + 32768) % 65536 - 32768))
	else
		led(string.format("led|place|%s|%d|%d|%d|%d|%d", name, team, x, z, facing, neutralOn and 1 or 0))
	end
	notePlaced(name, x, z, face, isF)
	return true
end

-- Left mouse button pressed with an armed unit or feature: one is placed, more while the mouse moves (one undo step for the stroke)
local function paintStart(kind, pos)
	ledStep()
	local hx, hz = halfSize(kind == "feature" and armedFeature or unitName, facing, kind == "feature")
	local gap = spacing * 16
	paint = { kind = kind, x = pos[1], z = pos[3], sx = math.max(16, (hx or 8) * 2 + gap), sz = math.max(16, (hz or 8) * 2 + gap) }
	if paintPlace(kind, pos[1], pos[3]) then
		if kind == "unit" then
			placed()
		end
	else
		say("Occupied: there is already something here (switch W on to write over it)")
	end
end

-- While the button is held: the next one is placed as soon as the pointer is a whole footprint (plus spacing) away from the last
local function paintSample()
	if not paint then
		return
	end
	local mx, my, left = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if not left then
		paint = nil
		return
	end
	if not pos then
		return
	end
	local d = paint
	Shared.paintChain(d, pos[1], pos[3], function(px, pz)
		paintPlace(d.kind, px, pz)
	end)
end

-- A click inside the menu panel: header buttons, the pages (settings, scenario, Generate, Tower Defense) and the lists of the Place menu;
-- always handled (true)
local function panelPress(mx, my, button)
	if not collapsed and my >= select(4, panelRect()) - 4 - titleH() then
		-- title row: drag = move the menu, right click = back to its place
		if button == 1 then
			panelMover:press(mx, my)
		elseif button == 3 then
			panelMover:reset()
		end
		return true
	end
	if button == 1 then
		for _, r in ipairs((headerRects())) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				applyHeader(r)
				return true
			end
		end
		if collapsed then
			return true
		end
		local rect = contentRect()
		if scenarioOpen then
			return scenarioPress(rect, mx, my)
		end
		if td.open then
			return td.press(rect, mx, my)
		end
		if ctf.open then
			return ctf.press(rect, mx, my)
		end
		if gen.open then
			local hit
			for _, gr in ipairs((genLayout(rect))) do
				if mx >= gr.x1 and mx <= gr.x2 and my >= gr.y0 and my <= gr.y1 then
					hit = gr
				end
			end
			if gen.edit and (not hit or hit.kind ~= "gencount") then
				genFinish(true)
			end
			for _, gr in ipairs((genLayout(rect))) do
				if mx >= gr.x1 and mx <= gr.x2 and my >= gr.y0 and my <= gr.y1 then
					if gr.kind == "genfac" then
						gen.faction = gr.value
					elseif gr.kind == "genshape" then
						gen.shape = gr.value
					elseif gr.kind == "genkind" then
						gen.kinds[gr.value] = not gen.kinds[gr.value] or nil
					elseif gr.kind == "gentech" then
						gen.tech[gr.value] = not gen.tech[gr.value]
					elseif gr.kind == "gencount" then
						if not gen.edit then
							gen.edit = ""
							widgetHandler:OwnText()
						end
					elseif gr.kind == "gensub" then
						if gen.sub ~= gr.value then
							genFinish(true)
							gen.sub = gr.value
							gen.armed, gen.drag = false, nil
							mazeKind, mazeDrag = nil, nil
						end
					elseif gr.kind == "genmaze" then
						gen.mazeSel = gr.value
						if mazeKind then
							mazeSetKind(gr.value)
						end
					elseif gr.kind == "genmazew" then
						gen.mazePath = gr.value
					elseif gr.kind == "gengo" and gen.sub == "maze" then
						mazeSetKind(not mazeKind and gen.mazeSel or nil)
					elseif gr.kind == "gengo" then
						gen.armed = not gen.armed
						gen.drag = nil
						if gen.armed then
							armedUnit, armedFeature = false, false
							bpGrid:setArmed(false)
							mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
							say("Generate: drag a rectangle with the left mouse button held down, right click ends.")
						end
					end
					break
				end
			end
			return true
		end
		if optionsOpen then
			if optionsUI:press(rect, mx, my) then
				grid = cfg.v.grid
				bpGrid.scroll, uGrid.scroll = 0, 0
			else
				levelPress(rect, mx, my)
			end
			return true
		end
		local sbGrid = (menuMode == "units" and uGrid) or (menuMode == "features" and fGrid) or (menuMode == "bp" and bpGrid) or nil
		if sbGrid and Shared.scrollbarPress(sbGrid, rect, mx, my) then
			return true
		end
		uGrid:setFocus(false)
		fGrid:setFocus(false)
		searchFocus(false)
		if menuMode == "units" then
			local ui = uGrid:at(rect, mx, my)
			if ui then
				local u = uGrid:list()[ui]
				unitName = u.name
				armedUnit = true
				armedFeature = false
				bpGrid:setArmed(false)
				say("Unit: " .. u.name .. ". Left click on the map places, right click ends.")
			end
			return true
		end
		if menuMode == "features" then
			local fi = fGrid:at(rect, mx, my)
			if fi then
				armedFeature = fGrid:list()[fi].name
				armedUnit = false
				bpGrid:setArmed(false)
				say("Feature: " .. armedFeature .. ". Left click places, right click ends, Del deletes.")
			end
			return true
		end
		if menuMode == "fav" then
			local kind, name = fav:press(rect, mx, my)
			if kind == "unit" then
				unitName = name
				armedUnit = true
				armedFeature = false
				bpGrid:setArmed(false)
				say("Unit: " .. name)
			elseif kind == "bp" then
				local i = lib:index(name)
				if i then
					bpGrid.selected = i
					armedUnit = false
					armedFeature = false
					bpGrid:setArmed(true)
					recent:add("bp", name)
					say("Blueprint: " .. name .. ". Left click on the map places, right click ends.")
				end
			end
			return true
		end
		bpGrid:press(rect, mx, my)
	end
	return true
end

function widget:MousePress(mx, my, button)
	rescale()
	if gen.edit and not inPanel(mx, my) then
		genFinish(true)
	end
	if gen.armed and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and canEdit() then
				gen.drag = { x = pos[1], z = pos[3] }
			end
			return true
		elseif button == 3 then
			gen.armed, gen.drag = false, nil
			say("Generate rectangle ended")
			return true
		end
	end
	if area:armed() and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen then
		if area:press(button) then
			return true
		end
	end
	if button == 1 and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen and not td.pick and not ctf.pick then
		local alt, ctrl, _, shift = Spring.GetModKeyState()
		local i = alt and not ctrl and not shift and td.dragAt()
		if i and canEdit() then
			td.wpDrag, td.wpBefore = i, td.routeState() -- the waypoint follows the mouse while the button is held (td.sample)
			return true
		end
	end
	if button == 1 and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen and not td.pick and not ctf.pick then
		local alt, ctrl, _, shift = Spring.GetModKeyState()
		if alt and not ctrl and not shift and ctf.grab() then
			return true -- the point follows the mouse while the button is held (ctf.sample)
		end
	end
	if td.pick and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and canEdit() then
				if td.mode == "free" then
					td.stroke = { { math.floor(pos[1]), math.floor(pos[3]) } } -- drawing: the points follow the mouse (td.sample)
				elseif td.mode == "single" then
					td.startSingle(pos[1], pos[3]) -- one piece, more while the mouse button stays down
				else
					td.click(pos[1], pos[3])
				end
			end
			return true
		elseif button == 3 then
			td.cancel()
			return true
		end
	end
	if ctf.pick and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and canEdit() then
				ctf.click(pos[1], pos[3])
			end
			return true
		elseif button == 3 then
			ctf.cancel()
			return true
		end
	end
	if delMode and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and canEdit() then
				delDrag = { x = pos[1], z = pos[3] }
			end
			return true
		elseif button == 3 then
			delToggle()
			return true
		end
	end
	if mazeKind and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and canEdit() then
				mazeDrag = { x = pos[1], z = pos[3] }
			end
			return true
		elseif button == 3 then
			mazeSetKind(nil)
			return true
		end
	end
	if button == 3 and not helpOpen and gen.cancelModes() then
		return true -- right click anywhere (also over the menu and the buttons) returns to the default mode
	end
	if helpOpen then
		helpOpen = false -- every click closes the help board
		return true
	end
	local sr = sideAt(mx, my)
	if sr then
		if button == 1 then
			applyHeader(sr)
		end
		return true
	end
	local tr = teamAt(mx, my)
	if tr then
		if button == 1 then
			local tm = tr.team
			if tr.write then
				writeOn = not writeOn
				say(writeOn and "Write: on (placing overwrites what is in the way)" or "Write: off (nothing is placed on occupied spots)")
			elseif tr.del then
				delToggle(tr.del)
			elseif tr.edit then
				editSelected(tr.edit)
			elseif tm == "N" then
				neutralOn = not neutralOn
				say(neutralOn and "Neutral: on (new units are neutral)" or "Neutral: off")
			else
				team = tm
				say("Team: " .. tm)
				if #selectedUnits() > 0 then
					assign(nil, nil, { tostring(tm) }) -- selected units change team
				end
			end
		end
		return true
	end
	if (button == 4 or button == 5) and (armedUnit or armedFeature or bpGrid.armed) then
		-- Mouse side buttons with Shift: spacing as in BAR when building
		local _, _, _, shift = Spring.GetModKeyState()
		if shift then
			setSpacing(spacing + ((button == 4) and 1 or -1))
			if widgetHandler.DisownMouse then
				widgetHandler:DisownMouse()
			end
			return true
		end
	end
	if button == 1 and not inPanel(mx, my) and not armedUnit and not bpGrid.armed and not armedFeature then
		local alt, ctrl, _, shift = Spring.GetModKeyState()
		if alt and not ctrl and not shift then
			-- Alt + drag on a selected unit: move the selection
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos then
				for _, id in ipairs(selectedUnits()) do
					local ux, _, uz = Spring.GetUnitPosition(id)
					if ux and (ux - pos[1]) ^ 2 + (uz - pos[3]) ^ 2 <= 48 ^ 2 then
						moveDrag = { x = pos[1], z = pos[3] }
						return true
					end
				end
			end
		elseif ctrl and not alt and not shift then
			-- Ctrl + click or rectangle: select units of every team (also foreign ones)
			selBox = { x = mx, y = my, cx = mx, cy = my }
			return true
		end
	end
	if inPanel(mx, my) then
		return panelPress(mx, my, button)
	end
	bpGrid.confirmDel = nil
	if armedFeature then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and canEdit() then
				local _, _, _, shift = Spring.GetModKeyState()
				if shift then
					stampDrag = { x = pos[1], z = pos[3], feat = true } -- row/rectangle: all are placed on release
				else
					paintStart("feature", pos)
				end
			end
			return true
		elseif button == 3 then
			stampDrag = nil
			armedFeature = false
			say("Feature stamp ended")
			return true
		end
	end
	if armedUnit then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and canEdit() then
				local _, _, _, shift = Spring.GetModKeyState()
				if shift then
					stampDrag = { x = pos[1], z = pos[3] } -- row/rectangle: all are placed on release
				else
					paintStart("unit", pos)
				end
			end
			return true
		elseif button == 3 then
			armedUnit = false
			stampDrag = nil
			say("Unit stamp ended")
			return true
		end
	end
	if bpGrid.armed then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			local bp = bpCurrent()
			if pos and bp and canEdit() then
				local _, _, _, shift = Spring.GetModKeyState()
				if shift then
					stampDrag = { x = snap(pos[1]), z = snap(pos[3]), bp = true } -- Row/rectangle of blueprints
				else
					placeBlueprintUnits(bp.units, pos[1], pos[3], nil, bp.name, bpRot)
				end
			end
			return true
		elseif button == 3 then
			stampDrag = nil
			bpGrid:setArmed(false)
			say("Blueprint stamp ended")
			return true
		end
	end
	return false
end

function widget:MouseMove(mx, my, dx, dy, button)
	rescale()
	if panelMover:move(mx, my) then
		return
	end
	if Shared.scrollbarMove(mx, my) then
		return
	end
	if selBox then
		selBox.cx, selBox.cy = mx, my
	end
	if bpGrid.drag then
		bpGrid:move(contentRect(), mx, my)
	end
end

-- Select units of every team in the rectangle or under the mouse pointer
local function finishSelBox(mx, my)
	local b = selBox
	selBox = nil
	local ids = {}
	if math.abs(mx - b.x) < 6 and math.abs(my - b.y) < 6 then
		local kind, id = Spring.TraceScreenRay(mx, my)
		if kind == "unit" and id then
			ids[1] = id
		else
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos then
				local best, bestD
				for _, u in ipairs(Spring.GetUnitsInCylinder(pos[1], pos[3], 80, -1) or {}) do
					local ux, _, uz = Spring.GetUnitPosition(u)
					if ux then
						local d = (ux - pos[1]) ^ 2 + (uz - pos[3]) ^ 2
						if not bestD or d < bestD then
							best, bestD = u, d
						end
					end
				end
				if best then
					ids[1] = best
				end
			end
		end
	else
		ids = Spring.GetUnitsInScreenRectangle(math.min(mx, b.x), math.max(my, b.y), math.max(mx, b.x), math.min(my, b.y), -1) or {}
	end
	foreignSel = ids
	pcall(Spring.SelectUnitArray, {}) -- the normal selection is cleared, the editor selection applies
	say(#ids .. " units selected (any team)")
end

function widget:MouseRelease(mx, my, button)
	if panelMover:release() then
		return
	end
	if Shared.scrollbarRelease() then
		return
	end
	area:release()
	td.endWpDrag()
	ctf.endDrag()
	td.sdrag = nil
	paint = nil
	if td.stroke then
		td.pts, td.stroke = td.stroke, nil
		td.finishDraw()
		return
	end
	if selBox then
		finishSelBox(mx, my)
	end
	if moveDrag then
		local d = moveDrag
		moveDrag = nil
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos and canEdit() then
			local dx = math.floor((pos[1] - d.x) / grid + 0.5) * grid
			local dz = math.floor((pos[3] - d.z) / grid + 0.5) * grid
			local sel = selectedUnits()
			if (dx ~= 0 or dz ~= 0) and #sel > 0 then
				local ids = {}
				for i = 1, math.min(#sel, 2000) do
					ids[i] = sel[i]
				end
				pendingNew = true
				ledStep()
				led(string.format("led|move|%d|%d|%s", dx, dz, table.concat(ids, ",")))
			end
		end
	end
	bpGrid:release()
	if gen.drag then
		local d = gen.drag
		gen.drag = nil
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos and gen.armed and canEdit() and button == 1 then
			local techs = {}
			for t = 1, 3 do
				if gen.tech[t] then
					techs[#techs + 1] = t
				end
			end
			local kinds = {}
			for _, k in ipairs(GEN_KINDS) do
				if gen.kinds[k[1]] then
					kinds[#kinds + 1] = k[1]
				end
			end
			if #kinds == 0 then
				say("No type chosen")
			else
				ledStep()
				for i, kind in ipairs(kinds) do
					-- the total is split over the chosen types, the remainder goes to the first ones
					local n = math.floor(gen.count / #kinds) + ((i <= gen.count % #kinds) and 1 or 0)
					if n > 0 and gen.shape == "circle" then
						-- circle: the press point is the center, the distance to the release point the radius
						local radius = math.floor(math.sqrt((pos[1] - d.x) ^ 2 + (pos[3] - d.z) ^ 2))
						led(string.format("led|generate|%d|%d|%d|%d|%d|%s|%s|%s|%d", team, d.x, d.z, n, radius, #techs > 0 and table.concat(techs, ",") or "-",
							gen.faction, kind, neutralOn and 1 or 0))
					elseif n > 0 then
						led(string.format("led|generaterect|%d|%d|%d|%d|%d|%d|%s|%s|%s|%d", team, math.min(d.x, pos[1]), math.min(d.z, pos[3]), math.max(d.x, pos[1]),
							math.max(d.z, pos[3]), n, #techs > 0 and table.concat(techs, ",") or "-", gen.faction, kind, neutralOn and 1 or 0))
					end
				end
			end
		end
	end
	if delDrag then
		local d = delDrag
		delDrag = nil
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos and delMode and canEdit() and button == 1 then
			ledStep()
			if delMode == "circle" then
				led(string.format("led|clearcircle|%d|%d|%d", d.x, d.z, math.sqrt((pos[1] - d.x) ^ 2 + (pos[3] - d.z) ^ 2)))
			elseif delMode == "line" then
				led(string.format("led|clearline|%d|%d|%d|%d|%d", d.x, d.z, pos[1], pos[3], DEL_HALF_WIDTH))
			elseif delMode == "fix" or delMode == "unfix" then
				led(string.format("led|fix|%d|%d|%d|%d|%d", math.min(d.x, pos[1]), math.min(d.z, pos[3]), math.max(d.x, pos[1]), math.max(d.z, pos[3]),
					delMode == "fix" and 1 or 0))
			else
				led(string.format("led|clearrect|%d|%d|%d|%d", math.min(d.x, pos[1]), math.min(d.z, pos[3]), math.max(d.x, pos[1]), math.max(d.z, pos[3])))
			end
		end
	end
	if mazeDrag then
		local d = mazeDrag
		mazeDrag = nil
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos and mazeKind and canEdit() and button == 1 then
			if gen.shape == "circle" then
				local r = math.sqrt((pos[1] - d.x) ^ 2 + (pos[3] - d.z) ^ 2)
				mazeBuild(mazeLayout(d.x - r, d.z - r, d.x + r, d.z + r), { x = d.x, z = d.z, r = r })
			else
				mazeBuild(mazeLayout(d.x, d.z, pos[1], pos[3]))
			end
		end
	end
	if stampDrag then
		local drag0 = stampDrag
		stampDrag = nil
		local ud = UnitDefNames[unitName]
		local mx2, my2 = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx2, my2, true)
		local bp = drag0.bp and bpCurrent()
		if drag0.feat and armedFeature and pos and canEdit() then
			stampDrag = drag0
			local list = featStampList(armedFeature, pos)
			stampDrag = nil
			local rot = (facing * 16384 + 32768) % 65536 - 32768
			ledStep()
			local n = 0
			for _, p in ipairs(list) do
				if makeRoom(armedFeature, p.x, p.z, 0, true) then
					led(string.format("led|feature|%s|%d|%d|%d", armedFeature, p.x, p.z, rot))
					notePlaced(armedFeature, p.x, p.z, 0, true)
					n = n + 1
				end
			end
			say(string.format("%d x %s placed%s", n, armedFeature, n < #list and (" (" .. (#list - n) .. " occupied)") or ""))
		elseif bp and pos and canEdit() then
			stampDrag = drag0
			local list = bpStampList(bp, pos)
			stampDrag = nil
			ledStep()
			for _, p in ipairs(list) do
				placeBlueprintUnits(bp.units, p.x, p.z, nil, bp.name, bpRot, true)
			end
			say(string.format("%d x blueprint '%s' placed", #list, bp.name))
		elseif ud and pos and canEdit() and not drag0.bp and not drag0.feat then
			stampDrag = drag0 -- stampList needs the start point
			local list = stampList(ud, pos)
			stampDrag = nil
			ledStep()
			local n = 0
			for _, p in ipairs(list) do
				if makeRoom(unitName, p.x, p.z, facing) then
					placeQueue[#placeQueue + 1] = string.format("led|place|%s|%d|%d|%d|%d|%d", unitName, team, p.x, p.z, facing, neutralOn and 1 or 0)
					notePlaced(unitName, p.x, p.z, facing)
					n = n + 1
				end
			end
			placed()
			say(string.format("%d x %s placed%s", n, unitName, n < #list and (" (" .. (#list - n) .. " occupied)") or ""))
		end
	end
end

-- Text input while renaming (only active while renaming)
function widget:TextInput(utf8char)
	if gen.edit then
		if utf8char and utf8char:match("^%d$") and #gen.edit < 4 then
			gen.edit = gen.edit .. utf8char
		end
		return true
	end
	if search.focus then
		if utf8char and #utf8char == 1 and utf8char:match("[%w_%- ]") and #search.query < 30 then
			searchSet(search.query .. utf8char)
		end
		return true
	end
	if td.edit then
		return td.text(utf8char)
	end
	if ctf.edit then
		return ctf.text(utf8char)
	end
	if scEdit then
		return scenarioText(utf8char)
	end
	return bpGrid:textInput(utf8char) or uGrid:textInput(utf8char) or fGrid:textInput(utf8char)
end

function widget:MouseWheel(up, value)
	rescale()
	local mx0, my0 = Spring.GetMouseState()
	if (armedUnit or armedFeature or bpGrid.armed) and not inPanel(mx0, my0) then
		local _, _, _, shift = Spring.GetModKeyState()
		if shift then
			setSpacing(spacing + (up and 1 or -1)) -- Shift + mouse wheel: spacing
			return true
		end
	end
	if not menuOpen or collapsed then
		return false
	end
	local mx, my = Spring.GetMouseState()
	if not inPanel(mx, my) then
		return false
	end
	if scenarioOpen then
		return true
	end
	if td.open then
		td.wheel(up)
		return true
	end
	if ctf.open then
		return true
	end
	if optionsOpen then
		local mxw, myw = Spring.GetMouseState()
		local rw = contentRect()
		if myw < rw.top - optionsUI:height() then
			levelScroll = math.max(0, math.min(math.max(0, #levelList - MAX_LEVEL_ROWS), levelScroll + (up and -1 or 1)))
		end
		return true
	end
	if menuMode == "units" then
		uGrid:wheel(contentRect(), up)
	elseif menuMode == "features" then
		fGrid:wheel(contentRect(), up)
	elseif menuMode == "fav" then
		fav:wheel(contentRect(), up)
	else
		bpGrid:wheel(contentRect(), up)
	end
	return true
end

-- Preview at the mouse pointer in stamp mode: outlines of the units in team color
local function drawWorldInner()
	rescale()
	if armedFeature then
		local mx, my = Spring.GetMouseState()
		if not inPanel(mx, my) then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos then
				local y = Spring.GetGroundHeight(pos[1], pos[3]) + 6
				gl.LineWidth(2.5)
				gl.DepthTest(false)
				gl.Color(0.3, 1, 0.4, 1)
				local centers = { { x = pos[1], z = pos[3] } }
				if stampDrag and stampDrag.feat then
					centers = featStampList(armedFeature, pos)
				end
				for _, c in ipairs(centers) do
					local cy = Spring.GetGroundHeight(c.x, c.z) + 6
					gl.BeginEnd(GL.LINE_LOOP, function()
						for a = 0, 15 do
							local ang = a / 16 * 2 * math.pi
							gl.Vertex(c.x + math.cos(ang) * 24, cy, c.z + math.sin(ang) * 24)
						end
					end)
				end
				gl.LineWidth(1)
				gl.Color(1, 1, 1, 1)
			end
		end
		return
	end
	if armedUnit then
		local mx, my = Spring.GetMouseState()
		if inPanel(mx, my) then
			return
		end
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		local ud = UnitDefNames[unitName]
		if not pos or not ud then
			return
		end
		local ok, err = pcall(function()
			if stampDrag then
				-- Row/rectangle: frame and models for all positions
				local list = stampList(ud, pos)
				local hx, hz = (ud.xsize or 4) * 4, (ud.zsize or 4) * 4
				if facing % 2 == 1 then
					hx, hz = hz, hx
				end
				gl.LineWidth(2.5)
				gl.DepthTest(false)
				gl.Color(0.3, 0.6, 1, 1)
				for i, p in ipairs(list) do
					local y = Spring.GetGroundHeight(p.x, p.z) + 6
					gl.BeginEnd(GL.LINE_LOOP, function()
						gl.Vertex(p.x - hx, y, p.z - hz)
						gl.Vertex(p.x + hx, y, p.z - hz)
						gl.Vertex(p.x + hx, y, p.z + hz)
						gl.Vertex(p.x - hx, y, p.z + hz)
					end)
					if i <= ghost.max then
						ghost:draw("s" .. i, ud.id, team, p.x, Spring.GetGroundHeight(p.x, p.z), p.z, facing * (math.pi / 2))
					end
				end
				gl.LineWidth(1)
				gl.Color(1, 1, 1, 1)
				return
			end
			local x, z = snap(pos[1]), snap(pos[3])
			ghost:draw("u", ud.id, team, x, Spring.GetGroundHeight(x, z), z, facing * (math.pi / 2))
			local hx, hz = (ud.xsize or 4) * 4, (ud.zsize or 4) * 4
			if facing % 2 == 1 then
				hx, hz = hz, hx
			end
			local y = Spring.GetGroundHeight(x, z) + 6
			gl.LineWidth(2.5)
			gl.DepthTest(false)
			gl.Color(0.3, 0.6, 1, 1)
			gl.BeginEnd(GL.LINE_LOOP, function()
				gl.Vertex(x - hx, y, z - hz)
				gl.Vertex(x + hx, y, z - hz)
				gl.Vertex(x + hx, y, z + hz)
				gl.Vertex(x - hx, y, z + hz)
			end)
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 1)
		end)
		if not ok then
			armedUnit = false
			say("Outline disabled: " .. tostring(err))
		end
		return
	end
	if not bpGrid.armed then
		return
	end
	local bp = bpCurrent()
	if not bp then
		return
	end
	local mx, my = Spring.GetMouseState()
	if inPanel(mx, my) then
		return
	end
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if not pos then
		return
	end
	local ok, err = pcall(function()
		gl.LineWidth(2)
		gl.DepthTest(false)
		-- Centers: one entry at the mouse pointer, while dragging (Shift) all copies of the row/rectangle
		local centers = { { x = pos[1], z = pos[3] } }
		if stampDrag and stampDrag.bp then
			centers = bpStampList(bp, pos)
		end
		local stride = math.max(1, math.floor(#bp.units * #centers / 800))
		for _, ctr in ipairs(centers) do
			for i = 1, #bp.units, stride do
				local u = bp.units[i]
				local ud = UnitDefNames[u.name]
				local r = math.max((ud and ud.radius) or 16, 10)
				local odx, odz = rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, bpRot)
				local x, z = ctr.x + odx, ctr.z + odz
				local y = Spring.GetGroundHeight(x, z) + 6 + (tonumber(u.h) or 0)
				local cr, cg, cb = Shared.teamColor(team)
				gl.Color(cr, cg, cb, 0.9)
				gl.BeginEnd(GL.LINE_LOOP, function()
					gl.Vertex(x - r, y, z - r)
					gl.Vertex(x + r, y, z - r)
					gl.Vertex(x + r, y, z + r)
					gl.Vertex(x - r, y, z + r)
				end)
			end
		end
		gl.DepthTest(true)
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
		-- 3D models (for large blueprints only the ghost.max units closest to the center)
		if not bp.near then
			bp.near = {}
			for i, u in ipairs(bp.units) do
				bp.near[i] = i
			end
			table.sort(bp.near, function(a, b)
				local ua, ub = bp.units[a], bp.units[b]
				local da = (tonumber(ua.dx) or 0) ^ 2 + (tonumber(ua.dz) or 0) ^ 2
				local db = (tonumber(ub.dx) or 0) ^ 2 + (tonumber(ub.dz) or 0) ^ 2
				return da < db
			end)
		end
		local budget = ghost.max
		for c, ctr in ipairs(centers) do
			for k = 1, #bp.near do
				if budget <= 0 then
					break
				end
				local i = bp.near[k]
				local u = bp.units[i]
				local ud = UnitDefNames[u.name]
				if ud then
					local odx, odz = rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, bpRot)
					local x, z = ctr.x + odx, ctr.z + odz
					local y = Spring.GetGroundHeight(x, z) + (tonumber(u.h) or 0)
					ghost:draw("b" .. c .. "_" .. i, ud.id, team, x, y, z, (tonumber(u.rot) or 0) * math.pi / 32768 + bpRot * math.pi / 2)
					budget = budget - 1
				end
			end
		end
	end)
	if not ok then
		bpGrid.armed = false
		say("Preview disabled: " .. tostring(err))
	end
end

function widget:DrawWorld()
	drawWorldInner()
	ghost:endFrame()
	local okArea, errArea = pcall(area.draw, area)
	if not okArea then
		area:disarm()
		say("Area attack preview disabled: " .. tostring(errArea))
	end
	-- Generate: yellow frame while dragging
	if gen.drag then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			local x1, x2 = math.min(gen.drag.x, pos[1]), math.max(gen.drag.x, pos[1])
			local z1, z2 = math.min(gen.drag.z, pos[3]), math.max(gen.drag.z, pos[3])
			gl.LineWidth(3)
			gl.DepthTest(false)
			gl.Color(1, 0.9, 0.2, 1)
			if gen.shape == "circle" then
				local radius = math.max(30, math.sqrt((pos[1] - gen.drag.x) ^ 2 + (pos[3] - gen.drag.z) ^ 2))
				gl.BeginEnd(GL.LINE_LOOP, function()
					for i = 0, 47 do
						local a = i / 48 * 2 * math.pi
						local cx, cz = gen.drag.x + math.cos(a) * radius, gen.drag.z + math.sin(a) * radius
						gl.Vertex(cx, Spring.GetGroundHeight(cx, cz) + 6, cz)
					end
				end)
			else
				gl.BeginEnd(GL.LINE_LOOP, function()
					gl.Vertex(x1, Spring.GetGroundHeight(x1, z1) + 6, z1)
					gl.Vertex(x2, Spring.GetGroundHeight(x2, z1) + 6, z1)
					gl.Vertex(x2, Spring.GetGroundHeight(x2, z2) + 6, z2)
					gl.Vertex(x1, Spring.GetGroundHeight(x1, z2) + 6, z2)
				end)
			end
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 1)
		end
	end
	-- Delete: red shape while dragging (rectangle, circle or line with its corridor)
	if delDrag then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			local ax, az = delDrag.x, delDrag.z
			local function v(x, z)
				gl.Vertex(x, Spring.GetGroundHeight(x, z) + 6, z)
			end
			gl.LineWidth(3)
			gl.DepthTest(false)
			gl.Color(1, 0.2, 0.2, 1)
			if delMode == "circle" then
				local r = math.sqrt((pos[1] - ax) ^ 2 + (pos[3] - az) ^ 2)
				gl.BeginEnd(GL.LINE_LOOP, function()
					for k = 0, 47 do
						v(ax + r * math.cos(k * math.pi / 24), az + r * math.sin(k * math.pi / 24))
					end
				end)
			elseif delMode == "line" then
				local dx, dz = pos[1] - ax, pos[3] - az
				local len = math.sqrt(dx * dx + dz * dz)
				local nx, nz = 0, 0
				if len > 0 then
					nx, nz = -dz / len * DEL_HALF_WIDTH, dx / len * DEL_HALF_WIDTH
				end
				gl.BeginEnd(GL.LINES, function()
					v(ax, az)
					v(pos[1], pos[3])
				end)
				gl.BeginEnd(GL.LINE_LOOP, function()
					v(ax + nx, az + nz)
					v(pos[1] + nx, pos[3] + nz)
					v(pos[1] - nx, pos[3] - nz)
					v(ax - nx, az - nz)
				end)
			else
				local x1, x2 = math.min(ax, pos[1]), math.max(ax, pos[1])
				local z1, z2 = math.min(az, pos[3]), math.max(az, pos[3])
				gl.BeginEnd(GL.LINE_LOOP, function()
					v(x1, z1)
					v(x2, z1)
					v(x2, z2)
					v(x1, z2)
				end)
			end
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 1)
		end
	end
	-- Maze: frame of the actual extent while dragging
	if mazeDrag then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			local circle = gen.shape == "circle"
			local cr = circle and math.sqrt((pos[1] - mazeDrag.x) ^ 2 + (pos[3] - mazeDrag.z) ^ 2) or 0
			local lay = circle and mazeLayout(mazeDrag.x - cr, mazeDrag.z - cr, mazeDrag.x + cr, mazeDrag.z + cr) or mazeLayout(mazeDrag.x, mazeDrag.z, pos[1], pos[3])
			local ok = lay.cols >= 2 and lay.rows >= 2
			local x1, z1 = lay.x - 8, lay.z - 8
			local x2, z2 = lay.x + (lay.w - 1) * 16 + 8, lay.z + (lay.h - 1) * 16 + 8
			if not ok then
				x2, z2 = math.max(x2, snap(pos[1])), math.max(z2, snap(pos[3]))
			end
			local y = Spring.GetGroundHeight(lay.x, lay.z) + 6
			gl.LineWidth(3)
			gl.DepthTest(false)
			if ok then
				gl.Color(0.3, 1, 0.4, 1)
			else
				gl.Color(1, 0.4, 0.3, 1)
			end
			gl.BeginEnd(GL.LINE_LOOP, function()
				if circle then
					for i = 0, 47 do
						local a = i / 48 * 2 * math.pi
						local cx, cz = mazeDrag.x + math.cos(a) * cr, mazeDrag.z + math.sin(a) * cr
						gl.Vertex(cx, Spring.GetGroundHeight(cx, cz) + 6, cz)
					end
				else
					gl.Vertex(x1, y, z1)
					gl.Vertex(x2, y, z1)
					gl.Vertex(x2, y, z2)
					gl.Vertex(x1, y, z2)
				end
			end)
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 1)
		end
	end
	-- Selection is being moved: frame at the target
	if moveDrag then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			local dx = math.floor((pos[1] - moveDrag.x) / grid + 0.5) * grid
			local dz = math.floor((pos[3] - moveDrag.z) / grid + 0.5) * grid
			gl.LineWidth(2.5)
			gl.DepthTest(false)
			gl.Color(0.3, 1, 0.4, 1)
			for _, id in ipairs(selectedUnits()) do
				local x, _, z = Spring.GetUnitPosition(id)
				local ud = UnitDefs[Spring.GetUnitDefID(id)]
				if x and ud then
					local r = math.max((ud.xsize or 4) * 4, 12)
					local nx, nz = x + dx, z + dz
					local y = Spring.GetGroundHeight(nx, nz) + 6
					gl.BeginEnd(GL.LINE_LOOP, function()
						gl.Vertex(nx - r, y, nz - r)
						gl.Vertex(nx + r, y, nz - r)
						gl.Vertex(nx + r, y, nz + r)
						gl.Vertex(nx - r, y, nz + r)
					end)
				end
			end
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 1)
		end
	end
	td.drawWorld()
	ctf.drawWorld()
	-- Editor selection (also foreign units): red frame around every unit
	if #foreignSel > 0 and #Spring.GetSelectedUnits() == 0 then
		gl.LineWidth(2.5)
		gl.DepthTest(false)
		gl.Color(1, 0.35, 0.35, 1)
		for _, id in ipairs(foreignSel) do
			if Spring.ValidUnitID(id) then
				local x, y, z = Spring.GetUnitPosition(id)
				local ud = UnitDefs[Spring.GetUnitDefID(id)]
				if x and ud then
					local r = math.max((ud.xsize or 4) * 4, 12)
					gl.BeginEnd(GL.LINE_LOOP, function()
						gl.Vertex(x - r, y + 6, z - r)
						gl.Vertex(x + r, y + 6, z - r)
						gl.Vertex(x + r, y + 6, z + r)
						gl.Vertex(x - r, y + 6, z + r)
					end)
				end
			end
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
	end
end

-- Autosave: every 2 minutes and when leaving, as "_last" (to continue at the next start)
local AUTOSAVE_SECONDS = 120
local lastAutosave = 0
local autosave

function widget:Update()
	-- When something else is armed (unit, blueprint, feature), the maze mode ends
	if mazeKind and (armedUnit or armedFeature or bpGrid.armed) then
		mazeSetKind(nil)
	end
	if delMode and (armedUnit or armedFeature or bpGrid.armed) then
		delToggle()
	end
	if area:armed() and (armedUnit or armedFeature or bpGrid.armed or delMode or mazeKind or gen.armed) then
		area:disarm()
	end
	if gen.armed and (armedUnit or armedFeature or bpGrid.armed) then
		gen.armed, gen.drag = false, nil
	end
	if td.pick and (armedUnit or armedFeature or bpGrid.armed or delMode or mazeKind or gen.armed or area:armed()) then
		td.endPick()
	end
	if ctf.pick and (not ctf.open or armedUnit or armedFeature or bpGrid.armed or delMode or mazeKind or gen.armed or area:armed()) then
		ctf.endPick()
	end
	td.sample()
	ctf.sample()
	paintSample()
	td.pollRoute()
	ctf.poll()
	-- Result of rotate/mirror/move: the newly placed units stay selected
	local nn = Spring.GetGameRulesParam("led_newids_n")
	if nn ~= lastNewN then
		lastNewN = nn
		if pendingNew then
			pendingNew = false
			local ids = {}
			for idStr in tostring(Spring.GetGameRulesParam("led_newids") or ""):gmatch("%d+") do
				ids[#ids + 1] = tonumber(idStr)
			end
			foreignSel = ids
			pcall(Spring.SelectUnitArray, {})
		end
	end
	for _ = 1, LOAD_PER_UPDATE do
		local m = table.remove(placeQueue, 1)
		if not m then
			break
		end
		Spring.SendLuaRulesMsg(m)
	end
	if #loadQueue == 0 then
		local now = Spring.GetGameSeconds()
		if now - lastAutosave >= AUTOSAVE_SECONDS then
			lastAutosave = now
			autosave()
		end
		return
	end
	for _ = 1, LOAD_PER_UPDATE do
		local u = table.remove(loadQueue, 1)
		if not u then
			break
		end
		if u.feature then
			Spring.SendLuaRulesMsg(string.format("led|loadfeature|%s|%d|%d|%d", tostring(u.name), tonumber(u.x) or 0, tonumber(u.z) or 0, tonumber(u.rot) or 0))
		else
		Spring.SendLuaRulesMsg(string.format("led|load|%s|%d|%d|%d|%d|%s|%d%s",
			tostring(u.name), u.gaia and Spring.GetGaiaTeamID() or tonumber(u.team) or 0, tonumber(u.x) or 0, tonumber(u.z) or 0, tonumber(u.rot) or 0,
			(u.neutral == true or u.neutral == "true") and "1" or "0", tonumber(u.y) or -1,
			u.indestructible == true and "|0|1" or ""))
		end
		if #loadQueue == 0 then
			say("Loading done.")
		end
	end
end

local function help(_, _, args)
	local topic = args and args[1] and tostring(args[1]):lower()
	if topic then
		for _, t in ipairs(HELP.topics) do
			for _, n in ipairs(t.names) do
				if n == topic then
					for _, line in ipairs(t.lines) do
						say(line)
					end
					return true
				end
			end
		end
		say("Topic '" .. topic .. "' does not exist.")
	end
	say("LEVEL EDITOR  |  Del delete, Ctrl+B blow up, Ctrl+C/X/V copy/cut/paste, Ctrl+Z/Y undo/redo, Ctrl+S save, Ctrl+D builders, arrows move, [ ] rotate")
	say("Commands: /led_clear  /led_ghost  /led_help   (levels, grid and unit limit: button O; save: Ctrl+S)")
	say("More help: /led_help start | keys | place | units | blueprint | save | team | features | scenario | build")
	return true
end

-- Create button: save the selection right away as a blueprint with a running number (bp_001, bp_002 ...); rename by double click in the menu
function bpQuickSave()
	rescale()
	if #selectedUnits() == 0 then
		say("No unit selected. Select first.")
		return true
	end
	bpScan()
	blueprintSave(lib:nextName()) -- BlueprintSaved re-reads the list and selects the new blueprint
	-- Keep the menu open and scroll the new tile into view
	menuOpen = true
	menuMode = "bp"
	optionsOpen = false
	scenarioOpen = false
	td.open, ctf.open = false, false
	bpGrid:scrollTo(contentRect(), bpGrid.selected)
	return true
end

local ctrlEdit -- Ctrl+C/V/X/Z/Y (defined below)

local ARROW_STEP = { [273] = { 0, -1 }, [274] = { 0, 1 }, [275] = { 1, 0 }, [276] = { -1, 0 } } -- up, down, right, left

function widget:KeyPress(key, mods, isRepeat)
	if gen.edit then
		if key == 13 or key == 271 then
			genFinish(true)
		elseif key == 27 then
			genFinish(false)
		elseif key == 8 then
			gen.edit = gen.edit:sub(1, -2)
		end
		return true
	end
	if td.edit then
		return td.key(key)
	end
	if ctf.edit then
		return ctf.key(key)
	end
	if key == 127 and (td.deleteWaypoint() or ctf.deleteAt()) then
		return true
	end
	if (td.pick == "corridor" or td.pick == "route") and td.mode == "line" and (key == 13 or key == 271) then
		td.finishDraw()
		return true
	end
	if scEdit then
		return scenarioKey(key, mods)
	end
	if search.focus then
		if key == 13 or key == 271 then
			searchFocus(false)
		elseif key == 27 then
			searchSet("")
			searchFocus(false)
		elseif key == 8 then
			searchSet(search.query:sub(1, -2))
		end
		return true
	end
	if bpGrid.editing or bpGrid.focus then
		return bpGrid:key(key)
	end
	if uGrid.focus then
		return uGrid:key(key)
	end
	if fGrid.focus then
		return fGrid:key(key)
	end
	if mods.ctrl and not mods.alt and ctrlEdit then
		return ctrlEdit(key, mods.shift, isRepeat)
	end
	if key == 100 and not mods.ctrl and not mods.alt and not mods.shift and not helpOpen then
		-- D: delete rectangle on/off
		if not isRepeat then
			delToggle("rect")
		end
		return true
	end
	if key == 109 and not mods.ctrl and not mods.alt and not mods.shift and not helpOpen then
		-- M: cycle the maze mode (off, dragon teeth, walls, off)
		if not isRepeat then
			mazeCycle()
		end
		return true
	end
	local arrow = ARROW_STEP[key]
	if arrow and not mods.ctrl and not mods.alt and not mods.shift and not helpOpen then
		-- Arrow keys: move selected units by one grid step (up = north); without a selection the camera stays
		local sel = selectedUnits()
		if #sel == 0 then
			return false
		end
		if canEdit() then
			local ids = {}
			for i = 1, math.min(#sel, 2000) do
				ids[i] = sel[i]
			end
			pendingNew = true
			ledStep()
			led(string.format("led|move|%d|%d|%s", arrow[1] * grid, arrow[2] * grid, table.concat(ids, ",")))
		end
		return true
	end
	if key == 127 and not mods.ctrl and not mods.alt then
		-- Del: delete the selection, otherwise the unit, wreck or feature at the mouse pointer (not over the menu)
		local mx, my = Spring.GetMouseState()
		rescale()
		if helpOpen or inPanel(mx, my) or teamAt(mx, my) or sideAt(mx, my) then
			return false
		end
		if not isRepeat then
			delete()
		end
		return true
	end
	return false
end

local ACTIONS = {
	led_ghost = function(_, _, args)
		say(ghost:command(args and args[1], "led_ghost"))
		return true
	end,
	led_clear = clear_all,
	led_help = help,
	led_helpbox = function()
		helpOpen = not helpOpen
		return true
	end,
}

-- Autoload: start_level_editor.bat writes the name of the level to LevelEditor/_autoload.txt; after the game starts it is loaded.
local pendingAutoload = nil

local function readAutoload()
	local f = io.open(OUTDIR .. "_autoload.txt", "r")
	if not f then
		return
	end
	local name = (f:read("*a") or ""):gsub("%s+", "")
	f:close()
	if name ~= "" then
		pendingAutoload = name
		-- Delete the note so a later start does not load again
		local w = io.open(OUTDIR .. "_autoload.txt", "w")
		if w then
			w:close()
		end
	end
end

function widget:GameFrame(n)
	pcall(area.step, area, n)
	if pendingAutoload and n >= 20 then
		local name = pendingAutoload
		pendingAutoload = nil
		load_level(nil, nil, { name })
	end
end

-- BAR uses Z X C V / A S D F etc. (with "Any+") for the build menu. If a builder or factory is selected, the
-- build menu eats Ctrl+C/V/X/Z/S before our keys get a chance. This handler sits (widget layer -1) in front of the
-- build menu and takes over these keys when Ctrl is held.

-- Ctrl + C / V / X / Z / Y (without Alt): copy, paste, cut, undo, redo (Y or Shift+Z), blow up (B).
-- Returns true if the key was consumed.
ctrlEdit = function(key, shift, isRepeat)
	local act
	if key == 99 and not shift then
		act = copyUnits
	elseif key == 118 and not shift then
		act = pasteUnits
	elseif key == 120 and not shift then
		act = function()
			copyUnits()
			return delete()
		end
	elseif key == 115 and not shift then
		act = saveCurrentLevel
	elseif key == 122 and not shift then
		act = undo
	elseif key == 100 and not shift then
		act = spawnBuildersHere
	elseif key == 121 and not shift then
		act = redo
	elseif key == 98 and not shift then
		act = boom -- Ctrl+B: blow up (wrecks remain)
	else
		return false
	end
	if not isRepeat then
		act()
	end
	return true
end

local function gridKeyHook(_, _, _, _, isRepeat, release, _, key)
	if release then
		return false
	end
	local alt, ctrl, _, shift = Spring.GetModKeyState()
	-- Alt+Z / Alt+X (also with Shift): build spacing when dragging; the build menu otherwise eats these keys when a builder is selected
	if (armedUnit or armedFeature or bpGrid.armed) and alt and not ctrl and (key == 122 or key == 120) then
		if not isRepeat then
			setSpacing(Shared.spacingFromKey(spacing, key))
		end
		return true
	end
	if ctrl and not alt then
		return ctrlEdit(key, shift, isRepeat)
	end
	return false
end

-- BAR key for build rotation ("buildfacing inc|dec", normally [ and ]): rotates the stamp while one is armed
local function buildFacingAction(_, _, words)
	if armedUnit or armedFeature or bpGrid.armed then
		local w = words and words[1]
		rotateBy((w == "dec") and 3 or 1)
	end
	return false -- BAR should get it as well
end

-- BAR key for the build spacing ("buildspacing inc|dec"): works with an armed unit stamp
local function buildSpacingAction(_, _, words)
	if armedUnit or armedFeature or bpGrid.armed then
		setSpacing(Shared.spacingFromWords(spacing, words))
	end
	return false -- BAR should get it as well
end

function widget:Initialize()
	WG.LevelEditorWidget = widget -- for tests in the game
	-- The BluePrinter removes itself in the Level Editor (mod option leveleditor). Removing it from here also removed
	-- the Level Editor itself (checked in the game), so this widget leaves it alone.
	cfg:load()
	grid = cfg.v.grid
	recent:load()
	lastNewN = Spring.GetGameRulesParam("led_newids_n")
	widgetHandler:AddAction("buildspacing", buildSpacingAction, nil, "p")
	widgetHandler:AddAction("buildfacing", buildFacingAction, nil, "p")
	readAutoload()
	widgetHandler.actionHandler:AddAction(widget, "gridmenu_key", gridKeyHook, nil, "pR")
	for name, fn in pairs(ACTIONS) do
		widgetHandler:AddAction(name, fn, nil, "t")
	end
	-- The menu is visible from the start, the Units tab first
	pcall(bpScan)
	menuOpen = true
	say("ready. /led_help shows the controls.")
end

-- Autosave on leaving (autosave is declared before widget:Update and set here)
autosave = function()
	if not canEdit() or #loadQueue > 0 or pendingAutoload or Spring.GetGameFrame() < 100 then
		return
	end
	saveLevel("_last", true)
end

function widget:Shutdown()
	WG.LevelEditorWidget = nil
	widgetHandler:RemoveAction("buildfacing")
	widgetHandler:RemoveAction("buildspacing")
	autosave()
	Shared.freeThumbs()
	ghost:stop()
	for name in pairs(ACTIONS) do
		widgetHandler:RemoveAction(name)
	end
end

function widget:DrawScreen()
	rescale()
	if selBox then
		gl.Color(1, 0.35, 0.35, 0.25)
		gl.Rect(selBox.x, selBox.y, selBox.cx, selBox.cy)
		gl.Color(1, 0.35, 0.35, 1)
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(selBox.x, selBox.y)
			gl.Vertex(selBox.cx, selBox.y)
			gl.Vertex(selBox.cx, selBox.cy)
			gl.Vertex(selBox.x, selBox.cy)
		end)
		gl.Color(1, 1, 1, 1)
	end
	local vsx, vsy = Spring.GetViewGeometry()
	td.hud(vsx, vsy)
	gl.Color(1, 1, 1, 1)
	gl.Text(
		string.format("Level Editor  |  %s  |  Team %d  |  Raster %d  |  %s", unitName, team, grid, FACING_NAME[facing]),
		vsx * 0.5, vsy - 24 * S, 14 * S, "co"
	)
	local bp = bpCurrent()
	if bp then
		gl.Text(string.format("Blueprint: %s (%d/%d)%s", bp.name, bpGrid.selected, #BP_LIST, bpGrid.armed and "  - stamp mode" or ""), vsx * 0.5, vsy - 44 * S, 12 * S, "co")
	end
	-- Selection: count, types and cost
	local sel = selectedUnits()
	if #sel > 0 then
		local counts, order, metal, energy = {}, {}, 0, 0
		for _, id in ipairs(sel) do
			local ud = UnitDefs[Spring.GetUnitDefID(id)]
			if ud then
				if not counts[ud.name] then
					counts[ud.name] = 0
					order[#order + 1] = ud.name
				end
				counts[ud.name] = counts[ud.name] + 1
				metal = metal + (ud.metalCost or 0)
				energy = energy + (ud.energyCost or 0)
			end
		end
		table.sort(order, function(a, b)
			if counts[a] ~= counts[b] then
				return counts[a] > counts[b]
			end
			return a < b
		end)
		local parts = {}
		for i = 1, math.min(4, #order) do
			parts[#parts + 1] = counts[order[i]] .. "x " .. order[i]
		end
		if #order > 4 then
			parts[#parts + 1] = "+" .. (#order - 4) .. " types"
		end
		gl.Color(1, 0.8, 0.6, 1)
		gl.Text(string.format("Selection: %d units (%s)   Metal %d   Energy %d", #sel, table.concat(parts, ", "), metal, energy),
			vsx * 0.5, vsy - 66 * S, 14 * S, "co")
		gl.Color(1, 1, 1, 1)
	end
	if menuOpen then
		local ok, err = pcall(drawMenu)
		if not ok then
			menuOpen = false
			bpGrid.armed = false
			gl.Scissor(false)
			say("Blueprint menu disabled: " .. tostring(err))
		end
	end
	if helpOpen then
		local ok, err = pcall(Shared.drawHelp, "Level Editor - Help", HELP.sections)
		if not ok then
			helpOpen = false
			say("Help board disabled: " .. tostring(err))
		end
	end
end

function widget:GetConfigData()
	return { panel = panelMover:save() }
end

function widget:SetConfigData(data)
	if type(data) == "table" then
		panelMover:load(data.panel)
	end
end
