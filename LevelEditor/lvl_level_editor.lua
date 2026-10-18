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

-- Content of the help board: { section, { { key, explanation }, ... } }
local HELP_SECTIONS = {
	{ "Menu (right)", {
		{ "Header", "Two main menus: Place (Recent, Units, Features, Blueprints) and Generate (Units, Maze)." },
		{ "Button column at the far right", "V collapse, O settings (grid, unit limit, levels), I scenario info, ? this help, D delete in a rectangle." },
		{ "Click", "Arm a blueprint, unit or feature. Left click on the map places it, right click ends." },
		{ "Mouse over a tile", "Large rotating 3D view (unit, blueprint, feature, favorite). Features: the list shows only pictures, below it the code name, metal, energy and description." },
		{ "Search field", "At the top of Place: one search over Recent, Units, Features and Blueprints at once (words of the description or the code). The tabs show the number of matches. Enter = done, Esc or X = clear." },
		{ "Blueprint tile", "Drag = sort, x = delete (click twice), double click on the name = rename, Create = save the selection." },
		{ "Recent", "Recently chosen blueprints and recently placed units." },
		{ "O", "Grid size, unit limit (written into the level for the scenario), columns and rows, below them the level list with load and save (second click confirms)." },
		{ "I", "Scenario info: title, author, briefing, roles and tech (T1/T2/T3) per team, AI, win condition, resources, grace period, ID. Click a field and type; written with the level when you save it." },
	} },
	{ "Buttons left of the menu", {
		{ "0, 1, 2 ...", "Team for new units and blueprints. With a selection: assigns the selection to this team." },
		{ "N", "Toggle: new units are neutral (flag, the team stays)." },
		{ "G", "Gaia team: belongs to no player, an enemy to everyone." },
		{ "L  R  S", "Only with a selection: rotate 90 degrees left, 90 degrees right, mirror left-right." },
	} },
	{ "Placing (mouse on the map)", {
		{ "[  ]", "Rotate (south, east, north, west), also for blueprints." },
		{ "Shift + drag", "Place a row. With Shift+Alt a rectangle." },
		{ "Shift+Mouse wheel, Alt+Z / X", "Spacing between the units of a row or rectangle." },
		{ "Generate", "Generate tab: choose faction, type (several possible: units, buildings, turrets, air, ships), tech T1-T3 and count (input field), press the Generate button and drag the area (Area: rectangle, or a circle from its center outwards); random units appear in it for the chosen team. Ctrl+Z undoes them. The Maze sub-tab builds a random maze in a dragged rectangle." },
		{ "D", "Delete in a rectangle: key D (or the D button at the far right), then drag a rectangle; everything in it (units, wrecks, features) is deleted. Ctrl+Z undoes it." },
		{ "M", "Maze: the key cycles through dragon teeth, walls, off (also the Maze sub-tab of the Generate tab). Then drag a rectangle or circle; a random maze appears in it (entrance top left, exit bottom right). Right click or arming something else ends the mode, Ctrl+Z undoes it." },
	} },
	{ "Editing the selection", {
		{ "Ctrl + click / rectangle", "Select units of any team, enemies too (red frames)." },
		{ "Alt + drag", "On a selected unit: move the selection (grid steps)." },
		{ "Arrow keys", "Move the selection by one grid step (up = north). Without a selection they move the camera." },
		{ "Del", "Delete (the selection, otherwise the unit, wreck or feature under the cursor)." },
		{ "Ctrl+B", "Blow up, wrecks remain." },
		{ "Ctrl+C / X / V", "Copy / cut / paste." },
		{ "Ctrl+D", "Create the builders of all factions at the cursor." },
	} },
	{ "Undo and saving", {
		{ "Ctrl+Z / Ctrl+Y", "Undo / redo the last action: place, blueprint, paste, delete, blow up, move, rotate, mirror, team, features (a row counts as one step)." },
		{ "Ctrl+S", "Save the level (under the current name, otherwise as a new level_001 ...)." },
	} },
	{ "Start menu (console)", {
		{ "0  1  2  3", "0 continue the last state, 1 new level (search a map), 2 load a level, 3 build a scenario package (ZIP) from a level." },
	} },
	{ "Chat commands", {
		{ "/led_clear", "Clear the whole map (units; undo with Ctrl+Z). Level files: Ctrl+S and the settings (O)." },
		{ "/led_ghost", "Diagnose or switch the 3D preview of the placing ghost." },
		{ "/led_help", "Detailed help in the chat, with a topic, e.g. /led_help features." },
	} },
}
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

local function mouseGround()
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3]
	end
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
	if not canEdit() then
		say("Cheat mode is off: please type /cheat")
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
	if not canEdit() then
		say("Cheat mode is off: please type /cheat")
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
-- (version, title, author, summary, briefing, roles, ai, win, metal, energy, sid). Unknown fields are kept.
local Json = Json or VFS.Include("common/luaUtilities/json.lua")
local SCENARIO_VERSION = 2 -- 2 = adds: grace (grace period in minutes)
local scenario = nil -- Info of the loaded scenario or one created in the game
local scenarioDirty = false -- changed in the game: when saving, this state is written instead of the block from the file
local currentLevel = nil -- Name of the level loaded or saved last

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
		if Spring.GetUnitRulesParam(id, "ledbuilder") ~= 1 then
			local x, y, z = Spring.GetUnitPosition(id)
			local ud = UnitDefs[Spring.GetUnitDefID(id)]
			-- Gaia units additionally carry gaia = true (the Gaia number depends on the team count)
			lines[#lines + 1] = string.format(
				"\t\t{ name = '%s', x = %d, y = %d, z = %d, rot = %d, team = %d, neutral = %s%s },",
				ud.name, x, y, z, Spring.GetUnitHeading(id), t, tostring(Spring.GetUnitNeutral(id)),
				t == gaia and ", gaia = true" or ""
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
	block = block or keptScenario
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
	if not canEdit() then
		say("Cheat mode is off: please type /cheat")
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
	if not canEdit() then
		say("Cheat mode is off: please type /cheat")
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
			"\t\t{ name = '%s', dx = %d, dz = %d, h = %d, rot = %d, team = %d, neutral = %s },",
			u.name, math.floor(u.x - cx + 0.5), math.floor(u.z - cz + 0.5), math.floor(u.y - Spring.GetGroundHeight(u.x, u.z) + 0.5),
			Spring.GetUnitHeading(u.id), Spring.GetUnitTeam(u.id), tostring(Spring.GetUnitNeutral(u.id))
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
local scConfirm = false -- Save button is waiting for the second click
local collapsed = false -- Menu collapsed: only the small button V stays visible
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
	kinds = { units = true }, -- chosen types (multiple choice)
	edit = nil, -- count input field: text while typing
	tech = { [1] = true, [2] = false, [3] = false },
	count = 100,
}
local GEN_KINDS = { { "units", "Units" }, { "buildings", "Buildings" }, { "turrets", "Turrets" }, { "air", "Air" }, { "ships", "Ships" } }
local delMode = false -- Delete rectangle (button/key D)
local delDrag = nil -- { x, z }: start point of the delete rectangle
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

-- Puts a blueprint unit list with center (cx, cz) into the load queue
-- A blueprint (or the clipboard) is placed as one undo step; noStep = true for rows of several blueprints
-- (there the step is already in front). The units go through the queue with the extra "1" (remember).
local function placeBlueprintUnits(units, cx, cz, teamOverride, label, k, noStep)
	local n = 0
	k = k or 0
	if not noStep then
		ledStep()
	end
	for _, u in ipairs(units) do
		local odx, odz = rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, k)
		local x, z = cx + odx, cz + odz
		local rot = ((tonumber(u.rot) or 0) + 16384 * k + 32768) % 65536 - 32768
		local y = Spring.GetGroundHeight(x, z) + (tonumber(u.h) or 0)
		placeQueue[#placeQueue + 1] = string.format("led|load|%s|%d|%d|%d|%d|%s|%d|1", tostring(u.name), teamOverride or team,
			math.floor(x + 0.5), math.floor(z + 0.5), math.floor(rot + 0.5), neutralOn and "1" or "0", math.floor(y + 0.5))
		n = n + 1
	end
	say(string.format("Placing blueprint '%s': %d units%s", label, n, teamOverride and (" for team " .. teamOverride) or ""))
end

local function blueprintLoad(name, teamOverride)
	local entry
	for _, bp in ipairs(BP_LIST) do
		if bp.name == name then
			entry = bp
		end
	end
	local units, err
	if entry then
		units = entry.units
	else
		local text = Shared.fileText(BPDIR .. name .. ".lua")
		if text then
			units, err = Shared.parseBlueprint(text)
		else
			err = "not found"
		end
	end
	if not units then
		say("Blueprint not found or invalid: " .. BPDIR .. name .. ".lua" .. (err and (" (" .. tostring(err) .. ")") or ""))
		return
	end
	local cx, cz = mouseGround()
	if not cx then
		say("The mouse must be over the map")
		return
	end
	placeBlueprintUnits(units, cx, cz, teamOverride, name, bpRot)
end

local function bpCurrent()
	return BP_LIST[bpGrid.selected]
end

local function bpEnsureList()
	if #BP_LIST == 0 then
		bpScan()
	end
	return #BP_LIST > 0
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

-- Cycle the selection (dir = 1 next, -1 previous)
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
		}
	end
	say(string.format("%d units copied. Paste at the cursor with Ctrl+V.", #clipboard))
	return true
end

local function pasteUnits()
	if not canEdit() then
		say("Cheat mode is off: please type /cheat")
		return true
	end
	if #clipboard == 0 then
		say("The clipboard is empty. Copy with Ctrl+C first.")
		return true
	end
	local cx, cz = mouseGround()
	if not cx then
		say("The mouse must be over the map")
		return true
	end
	placeBlueprintUnits(clipboard, cx, cz, nil, "Copy")
	return true
end

-- Ctrl+D: create the builders of all factions (as at the start) again at the mouse pointer, for the current team
local function spawnBuildersHere()
	if not canEdit() then
		say("Cheat mode is off: please type /cheat")
		return true
	end
	local x, z = mouseGround()
	if not x then
		say("The mouse must be over the map")
		return true
	end
	Spring.SendLuaRulesMsg(string.format("led|builders|%d|%d|%d", x, z, team))
	say("Builders of all factions are being created at the cursor (team " .. team .. ")")
	return true
end

local function bpDelete(name)
	bpGrid:deleteByName(name)
end

local function bpRename(old, new)
	return bpGrid:commitRename(old, new)
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
	scenario.version = math.max(SCENARIO_VERSION, tonumber(scenario.version) or 0)
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
	scConfirm = false
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
	local function row(title, items, kind)
		labels[#labels + 1] = { text = title, x = rect.x1 + m.PAD, y = y - 30 * S, size = 25 * S, head = true }
		y = y - 36 * S
		local gap = 4 * S
		local n = #items
		local w = (rect.x2 - rect.x1 - 2 * m.PAD - gap * (n - 1)) / n
		for i, it in ipairs(items) do
			local bx = rect.x1 + m.PAD + (i - 1) * (w + gap)
			rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = it.kind or kind, value = it.value, label = it.label, active = it.active, icon = it.icon, fs = 24 * S }
		end
		y = y - m.HB - 10 * S
	end
	-- Sub-tabs: Units | Maze
	do
		local gap = 4 * S
		local w = (rect.x2 - rect.x1 - 2 * m.PAD - gap) / 2
		for i, it in ipairs({ { "units", "Units" }, { "maze", "Maze" } }) do
			local bx = rect.x1 + m.PAD + (i - 1) * (w + gap)
			rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = "gensub", value = it[1], label = it[2], active = gen.sub == it[1], fs = 24 * S }
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
			label = armed and ("Generate: drag " .. what .. " (right click ends)") or "Generate", active = armed, fs = 28 * S }
		y = y - m.HB * 1.3 - m.PAD
		return rects, labels, rect.top - y
	end
	if gen.sub == "maze" then
		factionRow()
		row("Maze material", {
			{ value = 1, label = "Dragon teeth", active = gen.mazeSel == 1 },
			{ value = 2, label = "Walls", active = gen.mazeSel == 2 },
		}, "genmaze")
		labels[#labels + 1] = { text = "Random maze, corridors 64 Elmo wide.", x = rect.x1 + m.PAD, y = y - 22 * S, size = 21 * S }
		labels[#labels + 1] = { text = "Entrance top left, exit bottom right (rectangle).", x = rect.x1 + m.PAD, y = y - 48 * S, size = 21 * S }
		y = y - 60 * S
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
	if optionsOpen or scenarioOpen or gen.open then
		return 1
	end
	-- Place menu: Place/Generate row, search, sub-tabs, then the rows of the chosen sub-tab
	if menuMode == "units" then
		return 3 + (uGrid:filterRowCount() - 1)
	elseif menuMode == "features" then
		return 3 + (fGrid:filterRowCount() - 1)
	elseif menuMode == "fav" then
		return 3
	end
	return 3 + 1 -- blueprints: Create
end

-- List of the saved levels (LevelEditor/*.lua, without internal files with _ except the autosave _last)
local function scanLevels()
	levelList = {}
	local files = (VFS and VFS.DirList and VFS.DirList(OUTDIR, "*.lua", VFS.RAW)) or {}
	for _, path in ipairs(files) do
		local name = path:match("([^/\\]+)%.lua$")
		if name and (name:sub(1, 1) ~= "_" or name == "_last") then
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

local function panelRect()
	local m = Shared.m
	local vsx, vsy = Spring.GetViewGeometry()
	if collapsed then
		-- collapsed: only room for the button V in the upper right corner of the menu
		return vsx - (m.HB + 2 * m.PAD), vsy * 0.88 - (m.HB + 8), vsx, vsy * 0.88
	end
	local cw, ch
	if scenarioOpen then
		cw, ch = 0, scenarioHeight()
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
	local top = vsy * 0.88
	local hh = 4 + headerRowCount() * (m.HB + 3) + 2
	local bottom = math.max((optionsOpen or scenarioOpen or gen.open) and vsy * 0.05 or vsy * 0.12, top - hh - ch)
	local colW = m.HB + 2 * m.PAD -- far right: button column V, O, I, ?
	return vsx - colW - pw, bottom, vsx - colW, top -- x1, bottom, x2, top
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
		local top = y1 - 4
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
			{ "place", "Place", "Place: choose units, features and blueprints from the lists and place them on the map" },
			{ "gen", "Generate", "Generate: random units in a rectangle or circle, or a maze" },
		}
		local bw = (x2 - m.PAD - (x1 + m.PAD) - 3) / 2
		for i, it in ipairs(tops) do
			local bx = x1 + m.PAD + (i - 1) * (bw + 3)
			rects[#rects + 1] = { x1 = bx, x2 = bx + bw, y0 = top - m.HB, y1 = top, kind = "top", value = it[1], label = it[2], fs = 26 * S,
				active = (it[1] == "gen") and gen.open or (it[1] == "place" and not optionsOpen and not scenarioOpen and not gen.open), tip = it[3] }
		end
		rects[#rects + 1] = { x1 = ix1, x2 = ix2, y0 = iy1 - m.HB, y1 = iy1, side = true, kind = "info", value = "info", label = "I", active = scenarioOpen,
			tip = "Scenario: edit title, briefing, roles and rules for building a scenario" }
		rects[#rects + 1] = { x1 = hx1, x2 = hx2, y0 = hy1 - m.HB, y1 = hy1, side = true, kind = "help", value = "help", label = "?", active = helpOpen,
			tip = "Help: show the keys and controls on the screen" }
		rects[#rects + 1] = { x1 = dx1, x2 = dx2, y0 = dy1 - m.HB, y1 = dy1, side = true, kind = "del", value = "del", label = "D", active = delMode,
			tip = "Delete (key D): drag a rectangle on the map, everything in it is deleted (units, wrecks, features)" }
		rects[#rects + 1] = { x1 = gx1, x2 = gx2, y0 = gy1 - m.HB, y1 = gy1, side = true, kind = "gear", value = "gear", label = "O", active = optionsOpen,
			tip = "Settings: columns and rows, plus level management (load / save)" }
	end
	local hh = 4 + headerRowCount() * (m.HB + 3) + 2
	if not optionsOpen and not scenarioOpen and not gen.open then
		local rowTop = y1 - 4 - (m.HB + 3)
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
	local total = #ids + #edits
	local bh = math.max(12, math.min(m.HB, math.floor((y1 - vsy * 0.05) / total) - 3))
	local bx2 = x1 - 4
	local bx1 = bx2 - m.HB
	local i = 0
	for _, e in ipairs(edits) do
		local top = y1 - i * (bh + 3)
		out[#out + 1] = { x1 = bx1, x2 = bx2, y0 = top - bh, y1 = top, edit = e.edit, label = e.label, tip = e.tip }
		i = i + 1
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
		if r.edit then
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
		gl.Text(r.edit and r.label or (r.gaia and "G" or tostring(r.team)), (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2 - 10 * S, 27 * S, "co")
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
			if r.edit then
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
	y = y - gap
	rects[#rects + 1] = { x1 = rect.x1 + m.PAD, x2 = rect.x2 - m.PAD, y0 = y - rh, y1 = y, kind = "save" }
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
		else
			local name = currentLevel and currentLevel:sub(1, 1) ~= "_" and currentLevel or nil
			local label = scConfirm and "Sure?" or (name and ("Save level: " .. name) or "Save as a new level")
			Shared.drawButtons({ { x1 = r.x1, x2 = r.x2, y0 = r.y0, y1 = r.y1, label = label, fs = fs, active = scConfirm or nil,
				tip = "Writes the map and scenario info into the level (second click confirms)" } }, fs, r.y1 - r.y0)
			r.tipRect = true
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

-- Save level: under the current name, otherwise as a new level_NNN (Ctrl+S and button on the scenario page)
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
				scConfirm = false
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
			elseif scConfirm then
				scConfirm = false
				saveCurrentLevel()
			else
				scConfirm = true
			end
			return true
		end
	end
	scenarioFinish(true)
	scConfirm = false
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
	local rect = contentRect()
	if scenarioOpen then
		drawScenario(rect, mx, my)
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

-- For tests without the game: position of the buttons and the content area
function widget:DebugLayout()
	rescale()
	return (headerRects()), contentRect(), teamRects(), levelRects(contentRect()), scenarioRects(contentRect()), (genLayout(contentRect()))
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
		delToggle()
		return
	end
	genFinish(true)
	if r.kind == "search" then
		searchFocus(true)
		return
	elseif r.kind == "searchclear" then
		searchSet("")
		return
	end
	searchFocus(false)
	if r.kind == "top" then
		if (r.value == "gen") ~= gen.open then
			genToggle()
		end
		return
	end
	if r.kind ~= "create" then
		gen.open, gen.armed, gen.drag = false, false, nil
	end
	uGrid:setFocus(false)
	fGrid:setFocus(false)
	bpGrid:setFocus(false)
	scenarioFinish(true)
	scConfirm = false
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
-- The tiles are 16 Elmo (footprint of the unit), a corridor is MAZE_PATH tiles wide.
local MAZE_PATH = 4
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
	local pitch = MAZE_PATH + 1
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

delToggle = function()
	delMode = not delMode
	delDrag = nil
	if delMode then
		gen.armed, gen.drag = false, nil
		mazeKind, mazeDrag = nil, nil
		armedUnit, armedFeature = false, false
		stampDrag = nil
		bpGrid:setArmed(false)
		say("Delete: drag a rectangle with the left mouse button held down, everything in it is deleted. D or right click ends, Ctrl+Z undoes it.")
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
		say("Rectangle too small, at least " .. (2 * (MAZE_PATH + 1) + 1) * 16 .. " Elmo in both directions")
		return
	end
	local walls = Shared.mazeWalls(lay.cols, lay.rows, MAZE_PATH)
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
			if tr.edit then
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
	bpGrid.confirmDel = nil
	if armedFeature then
		if button == 1 then
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and canEdit() then
				local _, _, _, shift = Spring.GetModKeyState()
				if shift then
					stampDrag = { x = pos[1], z = pos[3], feat = true } -- row/rectangle: all are placed on release
				else
					local rot = (facing * 16384 + 32768) % 65536 - 32768
					ledStep()
					led(string.format("led|feature|%s|%d|%d|%d", armedFeature, math.floor(pos[1]), math.floor(pos[3]), rot))
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
					ledStep()
					led(string.format("led|place|%s|%d|%d|%d|%d|%d", unitName, team, snap(pos[1]), snap(pos[3]), facing, neutralOn and 1 or 0))
					placed()
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
	if Shared.scrollbarRelease() then
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
			led(string.format("led|clearrect|%d|%d|%d|%d", math.min(d.x, pos[1]), math.min(d.z, pos[3]), math.max(d.x, pos[1]), math.max(d.z, pos[3])))
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
			for _, p in ipairs(list) do
				led(string.format("led|feature|%s|%d|%d|%d", armedFeature, p.x, p.z, rot))
			end
			say(string.format("%d x %s placed", #list, armedFeature))
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
			for _, p in ipairs(list) do
				placeQueue[#placeQueue + 1] = string.format("led|place|%s|%d|%d|%d|%d|%d", unitName, team, p.x, p.z, facing, neutralOn and 1 or 0)
			end
			placed()
			say(string.format("%d x %s placed", #list, unitName))
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
	-- Delete: red frame while dragging
	if delDrag then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			local x1, x2 = math.min(delDrag.x, pos[1]), math.max(delDrag.x, pos[1])
			local z1, z2 = math.min(delDrag.z, pos[3]), math.max(delDrag.z, pos[3])
			gl.LineWidth(3)
			gl.DepthTest(false)
			gl.Color(1, 0.2, 0.2, 1)
			gl.BeginEnd(GL.LINE_LOOP, function()
				gl.Vertex(x1, Spring.GetGroundHeight(x1, z1) + 6, z1)
				gl.Vertex(x2, Spring.GetGroundHeight(x2, z1) + 6, z1)
				gl.Vertex(x2, Spring.GetGroundHeight(x2, z2) + 6, z2)
				gl.Vertex(x1, Spring.GetGroundHeight(x1, z2) + 6, z2)
			end)
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
	if gen.armed and (armedUnit or armedFeature or bpGrid.armed) then
		gen.armed, gen.drag = false, nil
	end
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
		Spring.SendLuaRulesMsg(string.format("led|load|%s|%d|%d|%d|%d|%s|%d",
			tostring(u.name), u.gaia and Spring.GetGaiaTeamID() or tonumber(u.team) or 0, tonumber(u.x) or 0, tonumber(u.z) or 0, tonumber(u.rot) or 0,
			(u.neutral == true or u.neutral == "true") and "1" or "0", tonumber(u.y) or -1))
		end
		if #loadQueue == 0 then
			say("Loading done.")
		end
	end
end

-- Layered help: /led_help shows the short version and the topics, /led_help <topic> the details
local HELP_TOPICS = {
	{
		names = { "start", "start" },
		lines = {
			"START: desktop shortcut 'BAR Level Editor'. Key 0 = continue the last state, key 1 = new level (search a map), key 2 = load a saved level, key 3 = build a scenario package (ZIP) from a level. You change the scenario info in the game with the I button.",
			"No /cheat is needed in the game. Placing, building, saving and loading work right away. Everything is free and finished instantly.",
			"Legion, the extra pack and release candidates are on. You start the normal multiplayer game through 'Beyond All Reason'.",
		},
	},
	{
		names = { "keys", "keys" },
		lines = {
			"KEYS (point the mouse at the map):",
			"[ and ] rotate the chosen unit or blueprint (south, east, north, west). You save a selection as a blueprint with Create in the blueprint menu, rename it with a double click.",
			"Del deletes and Ctrl+B blows up (wreck stays): works on the selection, without one on the unit, wreck or feature under the cursor. Ctrl+C copies, Ctrl+X cuts, Ctrl+V pastes, Ctrl+D creates the builders of all factions at the cursor.",
			"Ctrl+Z undoes the last action (also delete, blow up, move, rotate, team and features), Ctrl+Y redoes it. Ctrl+S saves the level.",
			"Arrow keys move the selection by one grid step (up = north), Alt + drag moves it with the mouse. Shift + drag places a row, Shift+Alt + drag a rectangle, Shift+Mouse wheel changes the spacing.",
			"CHOOSING ENEMIES: BAR only lets you select your own units. Ctrl + left click (or dragging a rectangle) selects units of EVERY team (red frames); then delete, blow up, assign to a team, copy or save as a blueprint. A normal selection replaces it.",
		},
	},
	{
		names = { "place", "unit", "unit" },
		lines = {
			"PLACING: click a unit in the Units menu, left click on the map places it, right click ends. Choose the team with the buttons left of the menu.",
			"Team 0 = you (Armada), team 1 = enemy (Cortex). The grid is set in the settings (button O). The spacing of rows changes with Shift+Mouse wheel or Alt+Z / X.",
			"Air units appear in the air and stay in flight mode. Ships need water.",
		},
	},
	{
		names = { "units", "group", "generate", "buildings", "turrets", "air", "ships" },
		lines = {
			"GENERATE: the G tab (Generate) fills a rectangle or a circle with random units, buildings, turrets, air or ships. Choose team, faction, type(s), tech levels and the count, then Generate and drag the area.",
			"Without a faction the team's faction is used (arm, cor or leg can be chosen). At most 2000 pieces; buildings and turrets stand on free building spots, units on passable ground.",
			"Enemies fight on their own within range. Air units appear in the air in flight mode.",
		},
	},
	{
		names = { "blueprint", "blueprints", "layout" },
		lines = {
			"BLUEPRINT: select units or buildings, then Create in the blueprint menu saves the layout (folder LevelEditor/blueprints).",
			"A click on a tile chooses it; left click on the map places it with the saved teams, or for the team chosen on the left.",
			"MENU: the Blueprints button at the top of the menu shows the tiles with preview pictures. Click a tile, then left click on the map places, right click ends, the mouse wheel scrolls.",
			"UNITS MENU: click 'Units' at the top of the menu. Then choose faction, group (buildings, air, vehicles, bots, hover, ships) and tech (T1-T3), click a unit, left click on the map places it (blue outline), right click ends, [ and ] rotate. You choose the team with the buttons left of the menu.",
			"SORTING: drag a tile with the mouse and drop it elsewhere. DELETING: small x at the top right, click twice (trash: blueprints/_trash). RENAMING: double click on the name, Enter.",
			"Air units keep their height, landed air units stay landed. The layout is not checked for passability.",
			"PREVIEW: when you move the mouse over a tile, a large rotating 3D view of the blueprint appears (all units in place).",
		},
	},
	{
		names = { "save", "load", "save", "load", "last" },
		lines = {
			"SAVING: Ctrl+S writes the level to LevelEditor/levels/<name>.lua: all units (position, height, team) and all features (wrecks, trees, rocks).",
			"LOADING: the level list in the settings (button O) clears the map (except the builder rows) and sets the level up again. Features are replaced if the file contains any. /led_clear clears units only.",
			"Ctrl+S saves the level under the current name, otherwise as a new level_001, level_002 ...",
			"AUTOSAVE: the editor saves every 2 minutes and when you leave, as _last. At the next start key 0 ('Continue the last state') brings it back.",
			"Air units in the air are loaded in the air, air units on the ground landed. The file states which game options (e.g. extra pack) must be on in the main game.",
		},
	},
	{
		names = { "team", "teams", "assign" },
		lines = {
			"TEAM: a click on a team button gives the selected units to that team (0 = you, 1 = enemy).",
			"The chosen team also applies to new units and to the Generate tab.",
		},
	},
	{
		names = { "edit", "edit", "move", "rotate", "mirror" },
		lines = {
			"EDITING THE SELECTION: when units are selected, three buttons appear on the left above the team buttons: L = rotate 90 degrees left, R = right, S = mirror left-right (around the center of the selection). The selection is kept.",
			"MOVING: with the arrow keys the selection moves by one grid step. Or hold Alt, click a selected unit, drag, release. It moves in grid steps (green preview).",
			"TEAM: a click on a team button assigns the selected units to that team. N = neutral (toggle), G = Gaia team. A tooltip appears when you hover over the buttons.",
			"SELECTION INFO: at the top center you see the count, types and cost of the selection. Ctrl+Z undoes, Ctrl+Y redoes.",
		},
	},
	{
		names = { "features", "feature", "trees", "rocks", "wrecks" },
		lines = {
			"FEATURES: Place menu, tab 'Features'. Trees, rocks, wrecks and the rest. The list shows only preview pictures; when you hover over one, a large rotating 3D view appears, and below the menu the code name, metal, energy and (if any) the description.",
			"Click a feature, left click places it, right click ends, Del deletes the feature under the cursor.",
			"The rotation follows the facing ([ and ] rotate). Features are saved in the level with Ctrl+S.",
		},
	},
	{
		names = { "search", "favorites", "levels" },
		lines = {
			"SEARCH: the Place menu has one search field at the top for Units, Features and Blueprints together. Click and type words of the description or the code; the tabs Recent, Units, Features and Blueprints show how many match and list the matches (across all factions, groups and tech levels). Enter ends the input, Esc or the X button next to it clears the search.",
			"FAVORITES: recently chosen blueprints and recently placed units, click to use them again (stored in LuaUI/Config/LevelEditorRecent.lua).",
			"LEVELS: 'O' opens the settings, below them the list of saved levels. Loading and saving need a second click as confirmation, 'Save as new' creates level_001, level_002 ...",
		},
	},
	{
		names = { "scenario", "scenario", "info", "i" },
		lines = {
			"SCENARIO: the I button (button column at the far right) opens the scenario info: title, author, summary, briefing (Shift+Enter = new line), role of each team (player, ally, enemy), tech per team, AI behavior, win condition, start metal and energy, grace period (m:ss) and ID.",
			"TECH: per team, switch T1, T2 and T3 on or off individually (default all on). An enemy with only T1 can only build tier 1 units and buildings.",
			"The info is saved with the level (Ctrl+S or the Save button on this page). You build the playable package in the start menu with key 3: choose a level, a folder and a ZIP are created in LevelEditor/scenario/scenarios.",
		},
	},
	{
		names = { "build", "builder" },
		lines = {
			"BUILDING: at the start only the commander stands there. With Ctrl+D you create all mobile builders of every faction at the cursor (markers ARMADA, CORTEX, LEGION), grouped by kind.",
			"With them you build factories and buildings as in the normal game: free and finished instantly. The builders stand on passable spots. They are only tools and are not saved in the level.",
		},
	},
}

local function help(_, _, args)
	local topic = args and args[1] and tostring(args[1]):lower()
	if topic then
		for _, t in ipairs(HELP_TOPICS) do
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
			delToggle()
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
			setSpacing(spacing + ((key == 122) and 1 or -1))
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
		local w = words and words[1]
		setSpacing(spacing + ((w == "dec") and -1 or 1))
	end
	return false -- BAR should get it as well
end

function widget:Initialize()
	WG.LevelEditorWidget = widget -- for tests in the game
	if WG.BluePrinterWidget then
		-- the BluePrinter has the same interface; do not show it twice
		widgetHandler:RemoveWidget(WG.BluePrinterWidget)
		WG.BluePrinterWidget = nil
	end
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
		local ok, err = pcall(Shared.drawHelp, "Level Editor - Help", HELP_SECTIONS)
		if not ok then
			helpOpen = false
			say("Help board disabled: " .. tostring(err))
		end
	end
end
