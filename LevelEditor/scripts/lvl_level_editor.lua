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

-- The Level Editor: place, generate, delete, undo and save units and features, the pages of the game modes; works in the editor game
-- (game option leveleditor=1, no /cheat needed) together with the gadget unit_level_editor.lua.
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
-- BAR only lets you select your own units; the editor switches on the god mode (godmode 3), so the normal selection of the game takes
-- units of EVERY team; delete, blow up, assign team, copy and blueprints use it.
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
	return Spring.GetSelectedUnits()
end
local isBpArmed = function() return false end -- set below, as soon as 'bpGrid.armed' is known
local FACING_NAME = Shared.FACING_NAME
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
local td = { open = false, edit = nil, pick = nil, mode = nil, pts = {}, stroke = nil, wall = 1, scroll = 0, data = nil } -- Tower Defense page (button TD): LevelEditor/scripts/led_td.lua fills in its functions below; data = section towerdefense of the level file
local rst -- restrictions of the level (what the player may not build): LevelEditor/scripts/led_restrictions.lua, created below (data = section restrictions of the level file)
local ctf -- Capture the Flag page (button CF): LevelEditor/scripts/led_ctf.lua, created below (data = section capture of the level file)
local rtf -- Reclaim the Fame page (button RF): LevelEditor/scripts/led_rtf.lua, created below (data = section reclaim of the level file)
local ar -- Arena page (button A): LevelEditor/scripts/led_arena.lua, created below (data = section arena of the level file)

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
	local scavOrRaptor = false -- a Scavenger or Raptor unit: the level needs the game option forceallunits
	for _, id in ipairs(Spring.GetAllUnits()) do
		local t = Spring.GetUnitTeam(id)
		-- not part of the level: the builders of Ctrl+D (ledbuilder) and the units of a running game (led_nosave: waves, flags, collection points)
		if Spring.GetUnitRulesParam(id, "ledbuilder") ~= 1 and Spring.GetUnitRulesParam(id, "led_nosave") ~= 1 then
			local x, y, z = Spring.GetUnitPosition(id)
			local ud = UnitDefs[Spring.GetUnitDefID(id)]
			scavOrRaptor = scavOrRaptor or ud.name:sub(-5) == "_scav" or ud.name:sub(1, 7) == "raptor_"
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
	-- the whole text is built first and written in one go (Shared.writeFile: a temporary file that replaces the old one), so an error
	-- on the way never leaves a half written level
	local out = { "-- Level Editor: saved for scenariooptions.unitloadout and featureloadout\n" }
	local function w(s)
		out[#out + 1] = s
	end
	-- Game options that must be on in the main game so the placed units exist there
	local needed = {}
	local mo = Spring.GetModOptions()
	for _, key in ipairs({ "experimentallegionfaction", "experimentalextraunits", "releasecandidates" }) do
		local v = mo[key]
		if v == "1" or v == 1 or v == true then
			needed[#needed + 1] = key .. ' = "1"'
		end
	end
	-- Scavenger and Raptor units (the *_scav copies, raptor_*) exist only with forceallunits: the level asks for it only when it holds such a unit
	if scavOrRaptor then
		needed[#needed + 1] = 'forceallunits = "1"'
	end
	w(string.format("return {\n\tmap = %q,\n", Game.mapName))
	-- Map size in Elmo: the scenario builder needs it for the grace period (start boxes as a fraction of the map)
	w(string.format("\tmapsize = { %d, %d },\n", Game.mapSizeX or 0, Game.mapSizeZ or 0))
	w(string.format("\tunitlimit = %d,\n", cfg.v.unitLimit))
	if block then
		w(block .. "\n")
	end
	if td.data then
		w("\ttowerdefense = " .. td.lua(td.data, "\t") .. ",\n")
	end
	if ctf.data then
		w("\tcapture = " .. ctf.lua() .. ",\n")
	end
	if rtf.data then
		w("\treclaim = " .. rtf.lua() .. ",\n")
	end
	if ar.data then
		w("\tarena = " .. ar.lua() .. ",\n")
	end
	if not rst.empty() then
		w("\trestrictions = " .. rst.lua() .. ",\n")
	end
	w("\t-- to be enabled in the main game (game options), otherwise some units are missing:\n")
	w("\trequiredmodoptions = { " .. table.concat(needed, ", ") .. " },\n\tunitloadout = {\n")
	w(table.concat(lines, "\n"))
	w("\n\t},\n\tfeatureloadout = {\n")
	w(table.concat(flines, "\n"))
	w("\n\t},\n}\n")
	local ok, err = Shared.writeFile(OUTDIR .. name .. ".lua", table.concat(out))
	if not ok then
		if not quiet then
			say("Saving failed: " .. tostring(err))
		end
		return nil
	end
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

-- Load: reads LevelEditor/<name>.lua, clears the map (except the builder rows) and places the saved units
-- in small packets per update, so nothing overflows with large levels.
local loadQueue = {}
local LOAD_PER_UPDATE = 50

-- Reads the text of a level file and returns the table (or nil, error text); the file runs in an empty environment (Shared.loadData)
function widget:ParseLevel(text)
	local data, err = Shared.loadData(text)
	if type(data) ~= "table" or type(data.unitloadout) ~= "table" then
		return nil, err or "not a valid level file"
	end
	return data
end

-- A section of the level file reduced to the fields of the defaults (and the listed extra fields): nil when it is no table
local function knownFields(t, defaults, extra)
	if type(t) ~= "table" then
		return nil
	end
	local out = {}
	for k, v in pairs(defaults) do
		if t[k] ~= nil then
			out[k] = t[k]
		else
			out[k] = v
		end
	end
	for _, k in ipairs(extra or {}) do
		out[k] = t[k]
	end
	return out
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
	-- own sections of the level file: only the fields the editor knows are taken over (nothing old is kept and saved again)
	td.data = knownFields(data.towerdefense, td.new(), { "spawn", "goal" })
	ctf.data = knownFields(data.capture, ctf.new())
	rtf.data = knownFields(data.reclaim, rtf.new())
	ar.data = knownFields(data.arena, ar.new(), { "point" })
	ar.fix()
	rst.load(data.restrictions)
	td.scroll = 0
	cfg.v.unitLimit = tonumber(data.unitlimit) or 32000 -- the unit limit belongs to the level (used by the scenario builder); not written into the settings
	cfg:sync()
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

-- Reads the text of a blueprint file (testable without the game)
function widget:ParseBlueprint(text)
	return Shared.parseBlueprint(text)
end

---------------------------------------------------------------- Blueprint management: list, selection, tile menu
-- Library (files), tile grid, unit catalog, settings and 3D preview come from editor_common.lua
cfg = Shared.newConfig("LuaUI/Config/LevelEditorUI.lua", "Level Editor: display (columns/rows in the menu), grid and unit limit",
	{ bpCols = 3, bpRows = 4, uCols = 3, uRows = 4, grid = 16, unitLimit = 32000 },
	{ bpCols = { 1, 6 }, bpRows = { 1, 8 }, uCols = { 1, 6 }, uRows = { 1, 8 }, grid = { 1, 64 }, unitLimit = { 500, 32000 } })
cfg.steps.grid = { 1, 4, 8, 16, 32, 64 } -- grid size in Elmo (1 = free)
cfg.steps.unitLimit = { 500, 1000, 2000, 4000, 8000, 16000, 32000 } -- unit limit written into the level for the scenario
cfg.transient.unitLimit = true -- it belongs to the level (saved in the level file), not to the settings: a new level starts with 32000
local lib = Shared.newLibrary({ dirs = { BPDIR }, say = say, writeIndex = true })
-- Create: the selected units as a new blueprint, with team, neutral flag and the indestructible flag (lib.linesFromUnits and lib:write of the shared library)
local function blueprintSave(name)
	local lines = lib.linesFromUnits(selectedUnits(), { withTeam = true, withFlags = true })
	if not lines then
		say("No unit selected. Select units first, then press Create in the blueprint menu")
		return
	end
	local ok, err = lib:write(name, lines, "Level Editor Blueprint: positions relative to the center of the selection (dx, dz), h = height above ground")
	if not ok then
		say("Saving failed: " .. tostring(err) .. " (folder LevelEditorBlueprints missing? run install_editor.bat again)")
		return
	end
	say(string.format("Blueprint '%s' saved: %d units (%s%s.lua)", name, #lines, BPDIR, name))
	widget:BlueprintSaved(name)
end
local BP_LIST = lib.list -- { name, units, count, thumb, dir }
local ghost = Shared.newGhost({ owner = "Level Editor", say = say, wg = function() return WG end })
local menuOpen = false
local menuMode = "units" -- "bp" = blueprints, "units" = all units (faction / group / tech), "features" = trees/rocks/wrecks, "fav" = recently used
local optionsOpen = false
local scenarioOpen = false -- Scenario info (button I) or AI page (button AI)
local scenarioPage = "info" -- what the scenario panel shows: "info" (title, roles, ...) or "ai" (AI per team)
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
-- The faction of the maze: the one of the Generate page, Armada for the Scavengers and Raptors (no walls of their own)
function gen.mazeFaction()
	return (gen.faction == "cor" or gen.faction == "leg") and gen.faction or "arm"
end
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
local uGrid = Shared.newUnits({ cfg = cfg, ownText = ownText, restrict = {
	-- the X marks of the Place menu write the restrictions of the level (rst, led_restrictions.lua, created below)
	isBanned = function(name) return rst.isBanned(name) end,
	setBanned = function(names, on) rst.setBanned(names, on) end,
	allBanned = function(names) return rst.allBanned(names) end,
} })
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
-- AI per team (button AI): value in scenario.teamai[team]; "default" = the global AI behavior of the scenario. The scenario builder and
-- the start of the editor write it into the start script ([ai] section, or LuaAI= in the team for the Lua AIs).
local TeamAi = { count = 11, -- teams 0 to 10; one table, because a Lua function may hold only 200 local variables (this file is close to it)
	list = { "default", "NullAI", "BARb", "CircuitAI", "CircuitAI easy", "SimpleAI", "SimpleDefenderAI", "SimpleConstructorAI", "ScavengersAI", "RaptorsAI" },
	txt = {
		default = "Default", NullAI = "NullAI (does nothing)", BARb = "BARb (expands, attacks)", CircuitAI = "CircuitAI",
		["CircuitAI easy"] = "CircuitAI easy", SimpleAI = "SimpleAI (easy)", SimpleDefenderAI = "SimpleDefenderAI (easy, defends)",
		SimpleConstructorAI = "SimpleConstructorAI (easy, builds)", ScavengersAI = "Scavengers (infinite game)", RaptorsAI = "Raptors (defence)",
	},
	next = {},
}
TeamAi.tip = {
	"Default: this team gets the AI of the scenario",
	"(page I, 'AI behavior': BARb or NullAI; the player team",
	"gets none; Tower Defense, Capture the Flag and",
	"Reclaim the Fame always NullAI).",
	"Any other choice applies to this team only.",
}
TeamAi.tipTeam1 = {
	"Default: in the scenario the AI of 'AI behavior' (page I);",
	"when the editor starts the level: NullAI, it does nothing.",
	"The editor knows only teams 0 and 1, so at the editor",
	"start only the entry of team 1 counts.",
}
for i, k in ipairs(TeamAi.list) do TeamAi.next[k] = TeamAi.list[i % #TeamAi.list + 1] end
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
	if scenarioPage == "ai" then
		local rows = {}
		for t = 0, TeamAi.count - 1 do
			rows[#rows + 1] = { id = "teamai", team = t, label = "AI team " .. t, kind = "cycle" }
		end
		return rows
	end
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
	elseif row.id == "teamai" then
		local v = type(sc.teamai) == "table" and sc.teamai[tostring(row.team)]
		return TeamAi.txt[v] and v or "default"
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
	elseif row.id == "teamai" then
		if type(scenario.teamai) ~= "table" then
			scenario.teamai = {}
		end
		scenario.teamai[tostring(row.team)] = (value ~= "default") and value or nil
		if next(scenario.teamai) == nil then
			scenario.teamai = nil
		end
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
		genshape = "Press, then drag the area on the map: the units (or the maze) appear in it for the chosen team. A rectangle, or a circle dragged from its center outwards. Press again or right click to end, Ctrl+Z undoes it.",
		genmaze = "Material of the maze walls: dragon teeth or walls",
		genmazew = "Width of the corridors of the maze in Elmo",
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
	-- all five factions for units; the maze only for the three that have dragon teeth and walls of their own
	local function factionRow(maze)
		local items = {}
		local chosen = maze and gen.mazeFaction() or gen.faction
		for _, f in ipairs(Shared.FACTIONS) do
			if not maze or f[1] == "arm" or f[1] == "cor" or f[1] == "leg" then
				items[#items + 1] = { value = f[1], label = f[2], active = chosen == f[1], icon = Shared.FACTION_ICONS[f[1]] }
			end
		end
		row("Faction", items, "genfac")
	end
	-- Bottom of both sub-tabs: Area (rectangle / circle: pressing one starts the generating, there is no extra button)
	local function bottom()
		local armed = gen.sub == "maze" and mazeKind ~= nil or gen.sub ~= "maze" and gen.armed
		row(armed and "Drag the area on the map (right click ends)" or "Generate in an area (circle: drag from the center outwards)", {
			{ value = "rect", label = "Rectangle", active = armed and gen.shape == "rect" },
			{ value = "circle", label = "Circle", active = armed and gen.shape == "circle" },
		}, "genshape")
		return rects, labels, rect.top - y
	end
	if gen.sub == "maze" then
		factionRow(true)
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
	if optionsOpen or scenarioOpen or gen.open or td.open or ctf.open or rtf.open or ar.open then
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
	elseif ar.open then
		cw, ch = math.floor(780 * S), ar.height() -- wider than the other pages: the table of the armies needs the room
	elseif ctf.open then
		cw, ch = 0, ctf.height()
	elseif rtf.open then
		cw, ch = 0, rtf.height()
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
	local bottom = math.max((optionsOpen or scenarioOpen or gen.open or td.open or ctf.open or rtf.open or ar.open) and vsy * 0.05 or vsy * 0.12, top - hh - ch)
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
		local function sideTop(k) if k >= 4 then k = k + 1 end return y1 - (k - 1) * (m.HB + 3) end -- slot 4 is the AI button
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
				active = (it[1] == "gen") and gen.open or (it[1] == "place" and not optionsOpen and not scenarioOpen and not gen.open and not td.open and not ctf.open and not rtf.open and not ar.open), tip = it[3] }
		end
		rects[#rects + 1] = { x1 = ix1, x2 = ix2, y0 = iy1 - m.HB, y1 = iy1, side = true, kind = "info", value = "info", label = "I", active = scenarioOpen and scenarioPage == "info",
			tip = "Scenario: edit title, briefing, roles and rules for building a scenario" }
		rects[#rects + 1] = { x1 = sx1, x2 = sx2, y0 = y1 - 3 * (m.HB + 3) - m.HB, y1 = y1 - 3 * (m.HB + 3), side = true, kind = "ai", value = "ai", label = "AI", active = scenarioOpen and scenarioPage == "ai",
			tip = "AI: choose the AI for every team (teams 0 to 10).\nIt is written into the level and takes effect at the next start of the scenario; a running game cannot change it." }
		rects[#rects + 1] = { x1 = hx1, x2 = hx2, y0 = hy1 - m.HB, y1 = hy1, side = true, kind = "help", value = "help", label = "?", active = helpOpen,
			tip = "Help: show the keys and controls on the screen" }
		rects[#rects + 1] = { x1 = sx1, x2 = sx2, y0 = sideTop(8) - m.HB, y1 = sideTop(8), side = true, kind = "ar", value = "ar", label = "A", active = ar.open,
			tip = "Arena: armies of several teams stand around the Arena Point and fight there (radius, budget, units of every army, Generate, Start)" }
		rects[#rects + 1] = { x1 = sx1, x2 = sx2, y0 = sideTop(9) - m.HB, y1 = sideTop(9), side = true, kind = "td", value = "td", label = "TD", active = td.open,
			tint = td.cfg().enabled and (td.open and { 0.3, 0.75, 0.4 } or { 0.15, 0.6, 0.2 }) or nil, -- green: Tower Defense is on for this level
			tip = "Tower Defense: enemy waves walk a path to a goal (spawn point, goal, path, waves)" }
		rects[#rects + 1] = { x1 = sx1, x2 = sx2, y0 = sideTop(10) - m.HB, y1 = sideTop(10), side = true, kind = "ctf", value = "ctf", label = "CF", active = ctf.open,
			tint = ctf.cfg().enabled and (ctf.open and { 0.3, 0.75, 0.4 } or { 0.15, 0.6, 0.2 }) or nil, -- green: Capture the Flag is on for this level
			tip = "Capture the Flag: flags lie on the map, units carry them to the collection point of their team and earn metal (flag points, collection points, income)" }
		rects[#rects + 1] = { x1 = sx1, x2 = sx2, y0 = sideTop(11) - m.HB, y1 = sideTop(11), side = true, kind = "rtf", value = "rtf", label = "RF", active = rtf.open,
			tint = rtf.cfg().enabled and (rtf.open and { 0.3, 0.75, 0.4 } or { 0.15, 0.6, 0.2 }) or nil, -- green: Reclaim the Fame is on for this level
			tip = "Reclaim the Fame: construction units earn points by reclaiming the crystals on the map; the first team at the score limit wins (crystals, factors, score limit, rate)" }
		local areas = {
			{ "line", "XL", "XL (experimental): carpet attack along a line.\nSelect bombers, artillery, rocket launchers or nukes,\npress XL, then drag a line on the map.\nEach unit gets a piece of it." },
			{ "rect", "XR", "XR (experimental): attack a rectangle.\nSelect bombers, artillery, rocket launchers or nukes,\npress XR, then drag a rectangle.\nThe units spread over the whole area." },
			{ "circle", "XC", "XC (experimental): attack a circle.\nSelect bombers, artillery, rocket launchers or nukes,\npress XC, then drag a circle from the center outwards.\nThe units spread over it." },
		}
		for k, a in ipairs(areas) do
			local top = sideTop(12 + k)
			rects[#rects + 1] = { x1 = dx1, x2 = dx2, y0 = top - m.HB, y1 = top, side = true, kind = "area", value = a[1], label = a[2],
				active = (area ~= nil and area:armed() and area:mode() == a[1]), tip = a[3] }
		end
		-- Indestructible / destructible: rectangle, the buildings in it
		local fixes = {
			{ "fix", "FX", "FX: make buildings indestructible.\nPress FX, then drag a rectangle on the map:\nthe buildings in it can no longer be damaged.\nCtrl+Z undoes it." },
			{ "unfix", "FD", "FD: make buildings destructible again.\nPress FD, then drag a rectangle on the map:\nthe buildings in it can be damaged again.\nCtrl+Z undoes it." },
		}
		for k, f in ipairs(fixes) do
			local top = sideTop(16 + k)
			rects[#rects + 1] = { x1 = dx1, x2 = dx2, y0 = top - m.HB, y1 = top, side = true, kind = "del", value = f[1], label = f[2], active = (delMode == f[1]), tip = f[3] }
		end
		rects[#rects + 1] = { x1 = gx1, x2 = gx2, y0 = gy1 - m.HB, y1 = gy1, side = true, kind = "gear", value = "gear", label = "O", active = optionsOpen,
			tip = "Settings: columns and rows, plus level management (load / save)" }
	end
	local hh = titleH() + 4 + headerRowCount() * (m.HB + 3) + 2
	if not optionsOpen and not scenarioOpen and not gen.open and not td.open and not ctf.open and not rtf.open and not ar.open then
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
					"Limit: " .. (Spring.GetTeamMaxUnits(r.team) or 500) .. " units (the other teams have far more),",
					"use N (neutral) for many neutral units.",
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
	elseif row.id == "teamai" then
		v = TeamAi.txt[scenarioValue(row)]
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
	gl.Text(scenarioPage == "ai" and "AI per team (from the next start)" or "Scenario (written with the level when saving)", rect.x1 + m.PAD, rect.top - 30 * S, 22 * S, "o")
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
	if scenarioPage == "ai" then
		gl.Text("Click a team: the next AI. Saved with the level (Save).", rect.x1 + m.PAD, last.y0 - 22 * S, 17 * S, "o")
		gl.Text("Applies at the next start of the scenario or the editor (team 1).", rect.x1 + m.PAD, last.y0 - 42 * S, 17 * S, "o")
		-- Tooltip left of the panel for the row under the mouse pointer
		for _, r in ipairs(rects) do
			if r.row and mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				local lines = r.row.team == 1 and TeamAi.tipTeam1 or TeamAi.tip
				local fsT, lh = 18 * S, 22 * S
				local w = 0
				for _, l in ipairs(lines) do
					w = math.max(w, (tonumber(gl.GetTextWidth(l)) or 0) * fsT)
				end
				local bx2 = rect.x1 - 6 * S
				local by1 = r.y1
				gl.Color(0, 0, 0, 0.88)
				gl.Rect(bx2 - w - 16 * S, by1 - #lines * lh - 10 * S, bx2, by1)
				gl.Color(1, 1, 1, 1)
				for i, l in ipairs(lines) do
					gl.Text(l, bx2 - w - 8 * S, by1 - 6 * S - i * lh + 4 * S, fsT, "o")
				end
			end
		end
	else
		gl.Text("Click a field to type: Enter done, Esc cancel,", rect.x1 + m.PAD, last.y0 - 22 * S, 17 * S, "o")
		gl.Text("Shift+Enter = new line in the briefing. Scenario package: start menu key 3.", rect.x1 + m.PAD, last.y0 - 42 * S, 17 * S, "o")
	end
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
					local nxt = (row.id == "role" and ROLE_NEXT or row.id == "ai" and AI_NEXT or row.id == "teamai" and TeamAi.next or WIN_NEXT)[cur] or cur
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
	gl.Text(ar.open and "Level Editor - Arena" or rtf.open and "Level Editor - Reclaim the Fame" or ctf.open and "Level Editor - Capture the Flag" or ((td.open or td.cfg().enabled) and "Level Editor - Tower Defense" or "Level Editor"), x1 + 8 * S, y1 - 34 * S, 28 * S, "o")
	local rect = contentRect()
	if scenarioOpen then
		drawScenario(rect, mx, my)
		return
	end
	if td.open then
		td.draw(rect)
		return
	end
	if ar.open then
		ar.draw(rect)
		return
	end
	if ctf.open then
		ctf.draw(rect)
		return
	end
	if rtf.open then
		rtf.draw(rect)
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
-- For tests: the restrictions and the unit list of the Place menu
function widget:DebugRestrictions()
	return rst, uGrid
end

-- For tests: the Capture the Flag page
function widget:DebugCtf()
	return ctf
end

-- For tests: the Reclaim the Fame page
function widget:DebugRtf()
	return rtf
end

-- Orders for selected units of other teams: the engine only sends orders for the own units, so the command menu and the right click are
-- forwarded to the gadget (led|order|cmdID|options|params|ids); the own units of the selection get their order from the engine as usual
function widget:CommandNotify(cmdID, params, options)
	local mine = Spring.GetMyTeamID()
	local ids = {}
	for _, id in ipairs(Spring.GetSelectedUnits()) do
		if Spring.GetUnitTeam(id) ~= mine then
			ids[#ids + 1] = id
		end
	end
	if #ids == 0 or not canEdit() then
		return false
	end
	local p = {}
	for i = 1, #params do
		p[i] = tostring(params[i])
	end
	Spring.SendLuaRulesMsg(string.format("led|order|%d|%d|%s|%s", cmdID, options and options.coded or 0, #p > 0 and table.concat(p, ",") or "-", table.concat(ids, ",")))
	return false
end

-- For tests without the game: position of the buttons and the content area
function widget:DebugLayout()
	rescale()
	return (headerRects()), contentRect(), teamRects(), levelRects(contentRect()), scenarioRects(contentRect()), (genLayout(contentRect())), (td.layout(contentRect())), (ctf.layout(contentRect())), (rtf.layout(contentRect()))
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
		local tdWas = td.open or ctf.open or rtf.open or ar.open
		ar.finish(true)
		td.open, ctf.open, rtf.open, ar.open = false, false, false, false
		local pageWas = scenarioOpen or optionsOpen
		scenarioFinish(true)
		scenarioOpen, optionsOpen = false, false -- the scenario, AI and settings pages give way to Place and Generate
		if (tdWas or pageWas) and r.value == "place" then
			return
		end
		if (r.value == "gen") ~= gen.open then
			genToggle()
		end
		return
	end
	local tdWas, ctfWas, rtfWas, arWas = td.open, ctf.open, rtf.open, ar.open
	ctf.finish(true)
	rtf.finish(true)
	ar.finish(true)
	if r.kind ~= "create" then
		gen.open, gen.armed, gen.drag = false, false, nil
		td.open, ctf.open, rtf.open, ar.open = false, false, false, false
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
	if r.kind == "rtf" then
		bpGrid:resetEdit()
		bpGrid:setArmed(false)
		armedUnit = false
		armedFeature = false
		scenarioOpen, optionsOpen = false, false
		rtf.open = not rtfWas
		bpGrid.scroll, uGrid.scroll = 0, 0
		return
	end
	if r.kind == "ar" then
		bpGrid:resetEdit()
		bpGrid:setArmed(false)
		armedUnit = false
		armedFeature = false
		scenarioOpen, optionsOpen = false, false
		ar.open = not arWas
		bpGrid.scroll, uGrid.scroll = 0, 0
		return
	end
	if r.kind == "info" then
		bpGrid:resetEdit()
		bpGrid:setArmed(false)
		armedUnit = false
		armedFeature = false
		scenarioOpen = not (scenarioOpen and scenarioPage == "info")
		scenarioPage = "info"
		optionsOpen = false
		scTeamsAt = -10
		bpGrid.scroll, uGrid.scroll = 0, 0
		return
	end
	if r.kind == "ai" then
		bpGrid:resetEdit()
		bpGrid:setArmed(false)
		armedUnit = false
		armedFeature = false
		scenarioOpen = not (scenarioOpen and scenarioPage == "ai")
		scenarioPage = "ai"
		optionsOpen = false
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
	local fac = gen.mazeFaction() -- same faction as on the Generate page (each faction has its own dragon teeth and walls)
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

-- A shape button of the Generate page: draws the units (or the maze, in the Maze tab) in the area dragged on the map; the same shape again ends it
function gen.arm(shape)
	local armed = gen.sub == "maze" and mazeKind ~= nil or gen.sub ~= "maze" and gen.armed
	local same = armed and gen.shape == shape
	gen.shape = shape
	if same then
		if gen.sub == "maze" then
			mazeSetKind(nil)
		else
			gen.armed, gen.drag = false, nil
		end
	elseif gen.sub == "maze" then
		mazeSetKind(gen.mazeSel)
	else
		gen.armed, gen.drag = true, nil
		armedUnit, armedFeature = false, false
		bpGrid:setArmed(false)
		mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
		say("Generate: drag " .. (shape == "circle" and "a circle from its center" or "a rectangle") .. " with the left mouse button held down, right click ends.")
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

-- Ends every editor mode (stamp, delete, maze, generate, area attack, picking of the Tower Defense and Capture the Flag points) and every drag;
-- called when a Tower Defense or Capture the Flag test starts, so that no mode swallows the clicks of the game
function gen.disarmAll()
	mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
	gen.armed, gen.drag = false, nil
	armedUnit, armedFeature = false, false
	stampDrag, moveDrag = nil, nil
	bpGrid:setArmed(false)
	area:disarm()
	td.endPick()
	ctf.endPick()
	ar.endPick()
end

-- Restrictions of the level (LevelEditor/scripts/led_restrictions.lua)
rst = VFS.Include("luaui/Include/led_restrictions.lua", nil, VFS.ZIP_FIRST)({
	serialize = function(v) return td.lua(v, "\t") end,
})

-- Capture the Flag page (LevelEditor/scripts/led_ctf.lua): gets the services of the widget
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
		ar.endPick()
	end,
	disarmAll = function() gen.disarmAll() end,
	restrictStart = function() rst.start() end,
	restrictStop = function() rst.stop() end,
	-- Tower Defense and Reclaim the Fame off when Capture the Flag is switched on (only one game mode)
	excludeOthers = function()
		if td.data and td.data.enabled then
			td.data.enabled = false
			say("Tower Defense switched off: Tower Defense and Capture the Flag exclude each other.")
		end
		if rtf.data and rtf.data.enabled then
			rtf.data.enabled = false
			say("Reclaim the Fame switched off: only one game mode can be on.")
		end
	end,
	step = function() ledStep() end,
	led = function(msg) led(msg) end,
	beforePlay = function() saveLevel("_beforeplay", true) end,
	afterPlay = function()
		local current = currentLevel
		load_level(nil, nil, { "_beforeplay" })
		currentLevel = current
	end,
})

-- Reclaim the Fame page (LevelEditor/scripts/led_rtf.lua): gets the services of the widget
rtf = VFS.Include("luaui/Include/led_rtf.lua", nil, VFS.ZIP_FIRST)({
	Shared = Shared,
	cfg = cfg,
	S = function() return S end,
	say = function(text) say(text) end,
	canEdit = function() return canEdit() end,
	serialize = function(v) return td.lua(v, "\t") end,
	armedFeature = function() return armedFeature end,
	-- arms the placing of a feature (like a click on its tile in the Features list)
	armFeature = function(name)
		mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
		gen.armed, gen.drag = false, nil
		stampDrag = nil
		area:disarm()
		td.endPick()
		ctf.endPick()
		armedFeature = name
		armedUnit = false
		bpGrid:setArmed(false)
		say("Feature: " .. name .. ". Left click places, right click ends, Del deletes.")
	end,
	disarmAll = function() gen.disarmAll() end,
	restrictStart = function() rst.start() end,
	restrictStop = function() rst.stop() end,
	-- Tower Defense and Capture the Flag off when Reclaim the Fame is switched on (only one game mode)
	excludeOthers = function()
		if td.data and td.data.enabled then
			td.data.enabled = false
			say("Tower Defense switched off: only one game mode can be on.")
		end
		if ctf.data and ctf.data.enabled then
			ctf.data.enabled = false
			say("Capture the Flag switched off: only one game mode can be on.")
		end
	end,
	beforePlay = function() saveLevel("_beforeplay", true) end,
	afterPlay = function()
		local current = currentLevel
		load_level(nil, nil, { "_beforeplay" })
		currentLevel = current
	end,
})

-- Arena page (LevelEditor/scripts/led_arena.lua): gets the services of the widget
ar = VFS.Include("luaui/Include/led_arena.lua", nil, VFS.ZIP_FIRST)({
	Shared = Shared,
	cfg = cfg,
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
		ctf.endPick()
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

-- Tower Defense page (LevelEditor/scripts/led_td.lua): the functions of td, with the services of the widget
VFS.Include("luaui/Include/led_td.lua", nil, VFS.ZIP_FIRST)(td, {
	S = function() return S end,
	team = function() return team end,
	grid = function() return grid end,
	neutralOn = function() return neutralOn end,
	armedUnit = function() return armedUnit end,
	armedFeature = function() return armedFeature end,
	unitName = function() return unitName end,
	currentLevel = function() return currentLevel end,
	scenario = function() return scenario end,
	placeQueue = function() return placeQueue end,
	stampDrag = function() return stampDrag end,
	mazeKind = function() return mazeKind end,
	mazeDrag = function() return mazeDrag end,
	delMode = function() return delMode end,
	delDrag = function() return delDrag end,
	Shared = Shared,
	bpGrid = bpGrid,
	uGrid = uGrid,
	gen = gen,
	MAZE_KINDS = MAZE_KINDS,
	MAZE_MAX_WALLS = MAZE_MAX_WALLS,
	canEdit = canEdit,
	led = led,
	ledStep = ledStep,
	load_level = load_level,
	makeRoom = makeRoom,
	mazeUnitName = mazeUnitName,
	notePlaced = notePlaced,
	placed = placed,
	saveLevel = saveLevel,
	say = say,
	scenarioValue = scenarioValue,
	scenarioTeams = scenarioTeams,
	contentRect = contentRect,
	ctf = ctf,
	rtf = rtf,
	rst = rst,
	armUnit = function(name)
		mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
		gen.armed, gen.drag = false, nil
		area:disarm()
		stampDrag = nil
		bpGrid:setArmed(false)
		unitName = name
		armedUnit = true
		armedFeature = false
	end,
	disarmModes = function()
		mazeKind, mazeDrag, delMode, delDrag = nil, nil, false, nil
		gen.armed, gen.drag = false, nil
		armedUnit, armedFeature = false, false
		stampDrag = nil
		bpGrid:setArmed(false)
		area:disarm()
	end,
	restoreBeforePlay = function()
		local current = currentLevel
		load_level(nil, nil, { "_beforeplay" })
		currentLevel = current
	end,
})

-- Ends every stamp, delete, maze, generate and area-attack mode and every drag in progress (selection frame,
-- Alt + drag move); without an active mode a right click clears the selection; returns true if it did something (a field of gen: the file is close to the limit of 200 locals)
function gen.cancelModes()
	local was = armedUnit or armedFeature or bpGrid.armed or gen.armed or gen.drag or delMode or delDrag
		or mazeKind or mazeDrag or stampDrag or moveDrag or area:armed() or td.pick or ctf.pick or ar.pick
	if not was then
		return false -- the right click is the order of the game for the selected units (a left click on the ground clears the selection)
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
	if ar.pick then
		ar.endPick()
	end
	stampDrag, moveDrag = nil, nil
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
		local hrects = (headerRects())
		for i = #hrects, 1, -1 do -- the last one lies on top (the X in a filter button)
			local r = hrects[i]
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
		if rtf.open then
			return rtf.press(rect, mx, my)
		end
		if ar.open then
			return ar.press(rect, mx, my)
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
						gen.arm(gr.value)
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
			local xi = uGrid:xAt(rect, mx, my)
			if xi then
				rst.toggle(uGrid:list()[xi].name) -- the X of a symbol: forbid it for the player in the game, or allow it again
				return true
			end
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
	if button == 1 and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen and not td.pick and not ctf.pick and not ar.pick then
		local alt, ctrl, _, shift = Spring.GetModKeyState()
		local i = alt and not ctrl and not shift and td.dragAt()
		if i and canEdit() then
			td.wpDrag, td.wpBefore = i, td.routeState() -- the waypoint follows the mouse while the button is held (td.sample)
			return true
		end
	end
	if button == 1 and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen and not td.pick and not ctf.pick and not ar.pick then
		local alt, ctrl, _, shift = Spring.GetModKeyState()
		if alt and not ctrl and not shift and ctf.grab() then
			return true -- the point follows the mouse while the button is held (ctf.sample)
		end
		if alt and not ctrl and ar.grab(shift) then
			return true -- the Arena Point follows the mouse while the button is held (ar.sample)
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
	if ar.pick and not inPanel(mx, my) and not teamAt(mx, my) and not sideAt(mx, my) and not helpOpen then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and canEdit() then
				ar.click(pos[1], pos[3])
			end
			return true
		elseif button == 3 then
			ar.cancel()
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
	if bpGrid.drag then
		bpGrid:move(contentRect(), mx, my)
	end
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
	ar.endDrag()
	td.sdrag = nil
	paint = nil
	if td.stroke then
		td.pts, td.stroke = td.stroke, nil
		td.finishDraw()
		return
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
	if rtf.edit then
		return rtf.text(utf8char)
	end
	if ar.edit then
		return ar.text(utf8char)
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
	if ctf.open or rtf.open or ar.open then
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
	ar.drawWorld()
end

-- Autosave: every 2 minutes and when leaving, as "_last" (to continue at the next start)
local AUTOSAVE_SECONDS = 120
local lastAutosave = 0
local autosave

function widget:Update()
	-- Cheat mode and god mode for all teams (once, in the editor game): units of every team can be selected like your own, the command menu
	-- appears for them; the orders for units of other teams go through widget:CommandNotify and the gadget
	if not gen.godAsked and Spring.GetGameFrame() > 5 then
		gen.godAsked = true
		local opt = Spring.GetModOptions().leveleditor
		if opt == "1" or opt == 1 or opt == true then
			if not Spring.IsCheatingEnabled() then
				Spring.SendCommands("cheat 1")
			end
			Spring.SendCommands("godmode 3")
		end
	end
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
	if ar.pick and (not ar.open or armedUnit or armedFeature or bpGrid.armed or delMode or mazeKind or gen.armed or area:armed()) then
		ar.endPick()
	end
	td.sample()
	ctf.sample()
	ar.sample()
	paintSample()
	td.pollRoute()
	ctf.poll()
	ar.poll()
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
			Spring.SelectUnitArray(ids)
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
	td.open, ctf.open, rtf.open, ar.open = false, false, false, false
	bpGrid:scrollTo(contentRect(), bpGrid.selected)
	return true
end

local ctrlEdit -- Ctrl+C/V/X/Z/Y (defined below)

local ARROW_STEP = { [273] = { 0, -1 }, [274] = { 0, 1 }, [275] = { 1, 0 }, [276] = { -1, 0 } } -- up, down, right, left

function widget:KeyPress(key, mods, isRepeat)
	if helpOpen and key == 27 then
		helpOpen = false -- Esc closes the help board
		return true
	end
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
	if rtf.edit then
		return rtf.key(key)
	end
	if ar.edit then
		return ar.key(key)
	end
	if key == 127 and (td.deleteWaypoint() or ctf.deleteAt() or ar.deleteAt()) then
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

-- the line about the selection (count, the most frequent types, cost): made again only when the selection changes (or once a second)
local selectionLine
do
	local key, text, frame = nil, nil, -100
	selectionLine = function(sel)
		local n = Spring.GetGameFrame()
		local k = #sel .. ":" .. tostring(sel[1]) .. ":" .. tostring(sel[#sel])
		if k == key and n - frame < 30 then
			return text
		end
		key, frame = k, n
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
		text = string.format("Selection: %d units (%s)   Metal %d   Energy %d", #sel, table.concat(parts, ", "), metal, energy)
		return text
	end
end

function widget:DrawScreen()
	rescale()
	local vsx, vsy = Spring.GetViewGeometry()
	td.hud(vsx, vsy)
	gl.Color(1, 1, 1, 1)
	gl.Text(
		string.format("Level Editor  |  %s  |  Team %d  |  Grid %d  |  %s", unitName, team, grid, FACING_NAME[facing]),
		vsx * 0.5, vsy - 24 * S, 14 * S, "co"
	)
	local bp = bpCurrent()
	if bp then
		gl.Text(string.format("Blueprint: %s (%d/%d)%s", bp.name, bpGrid.selected, #BP_LIST, bpGrid.armed and "  - stamp mode" or ""), vsx * 0.5, vsy - 44 * S, 12 * S, "co")
	end
	-- Selection: count, types and cost
	local sel = selectedUnits()
	if #sel > 0 then
		gl.Color(1, 0.8, 0.6, 1)
		gl.Text(selectionLine(sel), vsx * 0.5, vsy - 66 * S, 14 * S, "co")
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
