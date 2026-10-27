function widget:GetInfo()
	return {
		name = "BluePrinter",
		desc = "Plan buildings from saved blueprints in advance; idle builders nearby build the plans on their own",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end

-- BluePrinter: queue blueprints (files of the Level Editor) as build plans on the map.
-- Idle own builders nearby automatically get build orders for the queued buildings.
-- Everything runs through normal build orders: cost and build time as usual, no cheat needed.
--
-- Usage: click a blueprint in the list, queue it with a left click on the map (several times possible),
-- right click ends. Rotate: [ and ] or Alt + mouse wheel. Chat: /bp_menu (auto-build and radius: buttons in the menu)
-- /bp_rotate /bp_undo /bp_clear /bp_com /bp_side left|right

local Echo = Spring.Echo
-- Folder with blueprint files (<name>.lua). BAR allows user widgets to read under LuaUI/ and write only under LuaUI/Config/,
-- so both folders (via a junction from the installer) live there.
local BPDIRS = { "LuaUI/Config/BluePrinter/", "LuaUI/Config/LevelEditorBlueprints/" }
-- Shared code (blueprint library, tile grid, unit catalog, 3D preview) lives in editor_common.lua
local Shared = VFS.Include("LuaUI/Include/editor_common.lua", nil, VFS.RAW_FIRST)
assert(Shared, "editor_common.lua missing (run install_blueprinter.bat again)")
local rotateOffset, headingToFacing, FACING_NAME = Shared.rotateOffset, Shared.headingToFacing, Shared.FACING_NAME

local function say(t)
	Echo("[BluePrinter] " .. t)
end

---------------------------------------------------------------- State
local menuOpen = true
local side = "right" -- "left" | "right"
local autoBuild = true
local autoBuildStopped = false -- an error in the build routine switched auto-build off for this game only (the saved setting stays on)
local radius = 1000 -- builders react to plans within this radius (Elmo)
local useCommander = true -- commanders should build too
local rot = 0 -- 0 south, 1 east, 2 north, 3 west
local optionsOpen = false
local collapsed = false -- Menu collapsed: only the small button V stays visible
local panelMover = Shared.newPanelMover() -- the title row moves the menu
local menuMode = "bp" -- "bp" = blueprints, "units" = single buildings from the catalog
local armedUnit = nil -- Name of the building in stamp mode (left click queues it)
local helpOpen = false -- Help board on the screen

-- Content of the help board: { section, { { key, explanation }, ... } }
local HELP_SECTIONS = {
	{ "Menu", {
		{ "Blueprints / Buildings", "Switch between saved blueprints and single buildings from the catalog." },
		{ "Title row", "Drag the title \"BluePrinter\" with the left mouse button: the whole menu (with the button column) moves. Right click on the title: back to its place. The position is remembered." },
		{ "Click", "Arm a blueprint or building. Left click on the map queues it, right click ends." },
		{ "Search field", "In the building catalog and above the blueprint tiles: type words of the description or the code, the list filters at once. A scrollbar sits at the right edge of the lists. Enter = done, Esc = clear the search (sorting is off while searching)." },
		{ "Blueprint tile", "Drag = sort, x = delete (click twice), double click on the name = rename." },
		{ "V  /  O  /  ?", "Buttons next to the menu: collapse the menu / set columns and rows / this help." },
		{ "A  /  Q  /  C", "Auto-build on or off / Queue order (builders take the lowest number first) / commander helps build yes or no (light blue = on)." },
	} },
	{ "Building", {
		{ "Auto-build (A)", "Idle builders work through the queued plans on their own (even without a selection)." },
		{ "Radius - number +", "How far builders look for plans (200 to 6000). Click the number to type one." },
		{ "Commander (C)", "On = the commander helps build, off = only other builders. With an enemy near the commander stops building and fights." },
		{ "Undo / Clear all", "Undo the last step / remove all plans." },
		{ "Plans in the world", "Frame, 3D ghost and number per plan. Blue open, yellow in progress, red blocked." },
		{ "Right click on a plan", "With builders selected: they build exactly this plan now (a plan of a blueprint: the whole blueprint copy). Shift = add it to their queue." },
		{ "Line Remaining", "Metal, energy and estimated build time of all open plans." },
		{ "Select plans", "Click a plan: selects that building. Double click: the whole blueprint copy it belongs to (so you can remove it together). Shift+click: add or remove. Ctrl+drag: a rectangle. A click on the ground clears the selection." },
		{ "Selected plans", "Del removes them from the queue, [ and ] rotate them (not the ones being built), Page up / Page down move them one place in the queue, Home / End to the front / back. Undo takes each of these back." },
		{ "Queue order (Q)", "Off: idle builders take the nearest plan. On: they take the open plan with the lowest number first." },
	} },
	{ "Queueing (mouse on the map)", {
		{ "[  ]  or Alt+Mouse wheel", "Rotate (south, east, north, west)." },
		{ "Shift + drag", "Queue a row. With Shift+Alt a rectangle." },
		{ "Shift+Mouse wheel, Alt+Z / X", "Spacing between the buildings." },
		{ "Ctrl+Alt+P", "Save the selected buildings as a new blueprint." },
	} },
	{ "Area attack (experimental)", {
		{ "XL  /  XR  /  XC", "Buttons next to the menu. Select bombers, artillery, rocket launchers or nukes first, press XL (line), XR (rectangle) or XC (circle), then drag the shape on the map. For the circle drag from the center outwards." },
		{ "Procedure", "Each unit gets its own target in the shape. Bombers first form up side by side, then all attack at the same moment as a front; artillery and rockets fire at their target. Right click cancels. Ctrl+Alt+K = XL." },
	} },
	{ "Chat commands", {
		{ "/bp_menu", "Menu on or off." },
		{ "/bp_rotate  /bp_undo  /bp_clear", "Rotate, undo, clear all." },
		{ "/bp_carpet [line|rect|circle]  /bp_spacing", "Area attack, spacing." },
	} },
}
local area -- area attacks (XL, XR, XC), created below from the shared code
local spacing = 0 -- Spacing when dragging rows/rectangles (in 16 Elmo steps, like "buildspacing")
local stampDrag = nil -- { x, z }: start point while a row/rectangle is dragged with Shift
local paint = nil -- { ud, f, batch, x, z, sx, sz }: the last point of a stroke while the left mouse button is held down (painting)
local buildable = nil -- { [unitDefID] = true }: what the own builders can build right now (nil = unknown)
local factionAuto = true -- Choose the faction by the own builders until you click one yourself
local sites = {} -- { def, name, x, y, z, f, batch, done, blocked, claim, claimFrame, tries }
local batchCounter = 0
local batchReplaced = {} -- [batch] = { { site, index } }: plans that a blueprint was placed on top of; they left the queue and Undo brings them back
local groupCounter = 0 -- every queued blueprint (one copy) gets its own group number: a click on a plan selects the whole group
local queueOrder = false -- Queue order (button in the title row): builders take the open plan with the lowest number instead of the nearest
local selected = {} -- [site] = true: the selected plans (click, Ctrl + drag)
local lastClick = nil -- { site, t }: the last click on a plan (a second click on it within 0.4 s is a double click)
local selBox = nil -- { x, z, hit, shift }: start point while a selection rectangle is dragged with Ctrl
local opStack = {} -- steps that Undo takes back besides queueing: remove, rotate, order (each with the highest open batch at that time)
local doneCount = 0
local passNo = 0
local checkCursor = 1
local S = 1 -- UI scale
local PASS_FRAMES = 30

local function rescale()
	S = Shared.rescale()
end

-- Library (files), grid, settings and 3D preview come from editor_common.lua
local cfg = Shared.newConfig("LuaUI/Config/BluePrinterUI.lua", "BluePrinter: display (columns/rows in the menu)",
	{ bpCols = 3, bpRows = 4, uCols = 3, uRows = 4 },
	{ bpCols = { 1, 6 }, bpRows = { 1, 8 }, uCols = { 1, 6 }, uRows = { 1, 8 } })
local lib = Shared.newLibrary({ dirs = BPDIRS, say = say, buildingsOnly = true })
local LIST = lib.list -- { name, units, count, thumb, dir }
local ghost = Shared.newGhost({ owner = "BluePrinter", say = say, wg = function() return WG end })
local gridHooks = {}
local bpGrid = Shared.newGrid({
	lib = lib, cfg = cfg, unitWord = "Buildings", searchLabel = "Search Blueprints",
	ownText = function(on)
		if on then
			widgetHandler:OwnText()
		else
			widgetHandler:DisownText()
		end
	end,
	onArm = function(on)
		if on then
			armedUnit = nil
			if area then
				area:disarm()
			end
		end
	end,
	onSelect = function(i, moved) gridHooks.select(i, moved) end,
})
area = Shared.newAreaAttack({
	say = say,
	mouseGround = function()
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if pos then
			return pos[1], pos[3]
		end
	end,
	inPanel = function(mx, my) return widget.IsAbove and widget:IsAbove(mx, my) end,
	onArm = function()
		armedUnit = nil
		bpGrid:setArmed(false)
	end,
})
local function canBuildNow(id)
	return buildable == nil or buildable[id] == true
end
-- A faction gets a button only if the own builders can build a building of it (before any builder exists all three are offered)
local uGrid
local function factionBuildable(f)
	if buildable == nil or not uGrid or not uGrid.cache then
		return true
	end
	for tl = 1, 3 do
		for _, e in ipairs(uGrid.cache[f].buildings[tl]) do
			if buildable[e.id] then
				return true
			end
		end
	end
	return false
end
uGrid = Shared.newUnits({ cfg = cfg, groups = { "buildings" }, factions = { "arm", "cor", "leg" }, -- no Scavengers or Raptors: their units exist only with forceallunits
	factionUsable = factionBuildable, canUse = canBuildNow, searchLabel = "Search Buildings",
	ownText = function(on)
		if on then
			widgetHandler:OwnText()
		else
			widgetHandler:DisownText()
		end
	end })
local optionsUI = Shared.newOptions(cfg, {
	{ title = "Blueprints", keys = { { "bpCols", "Columns" }, { "bpRows", "Rows" } } },
	{ title = "Buildings", keys = { { "uCols", "Columns" }, { "uRows", "Rows" } } },
})

-- Re-read the list; the selection stays if the blueprint is still there
local function scanBlueprints()
	local keep = LIST[bpGrid.selected] and LIST[bpGrid.selected].name
	lib:scan()
	bpGrid.selected = keep and lib:index(keep) or 0
	if bpGrid.selected == 0 and #LIST > 0 then
		bpGrid.selected = 1
	end
	if bpGrid.armed and not LIST[bpGrid.selected] then
		bpGrid.armed = false
	end
	bpGrid.scroll = 0
end

gridHooks.select = function(i, moved)
	if not moved and LIST[i] then
		say("Blueprint '" .. LIST[i].name .. "': left click = queue, right click = end")
	end
end

---------------------------------------------------------------- Plans
local function snap16(v)
	return math.floor(v / 16 + 0.5) * 16
end

local function buildPos(ud, x, z, f)
	local y = Spring.GetGroundHeight(x, z)
	if Spring.Pos2BuildPos then
		local bx, by, bz = Spring.Pos2BuildPos(ud.id, x, y, z, f)
		if bx then
			return bx, by, bz
		end
	end
	return x, y, z
end

local function testBuild(ud, x, y, z, f)
	if Spring.TestBuildOrder then
		return Spring.TestBuildOrder(ud.id, x, y, z, f)
	end
	return 3
end

local function siteExists(def, x, z)
	for _, s in ipairs(sites) do
		if not s.done and s.def == def and math.abs(s.x - x) < 4 and math.abs(s.z - z) < 4 then
			return true
		end
	end
	return false
end

-- Footprints: half sizes of a building with its facing
local function footHalf(def, f)
	local ud = UnitDefs[def]
	local hx, hz = (ud.xsize or 4) * 4, (ud.zsize or 4) * 4
	if f % 2 == 1 then
		hx, hz = hz, hx
	end
	return hx, hz
end

-- Does another building (not the one this plan is for) stand on the spot of the plan? Then the plan makes no sense any more.
local function buildingOn(s)
	if s.done or testBuild(UnitDefs[s.def], s.x, s.y, s.z, s.f) ~= 0 then
		return false
	end
	local hx, hz = footHalf(s.def, s.f)
	for _, uid in ipairs(Spring.GetUnitsInCylinder(s.x, s.z, math.max(hx, hz) + 24) or {}) do
		local ud = UnitDefs[Spring.GetUnitDefID(uid)]
		if ud and (ud.isBuilding or not ud.canMove) then
			local ux, _, uz = Spring.GetUnitPosition(uid)
			local ox, oz = footHalf(ud.id, 0)
			local own = ud.id == s.def and math.abs(ux - s.x) < 24 and math.abs(uz - s.z) < 24
			if not own and math.abs(ux - s.x) < hx + ox - 2 and math.abs(uz - s.z) < hz + oz - 2 then
				return true
			end
		end
	end
	return false
end

-- A plan goes away (Undo, remove, Clear all): the builder that had it drops its build order (the rest of its queue stays), and a building that
-- was already started is reclaimed (otherwise it stays as a half-built building without a plan)
local function dropPlan(s)
	local bid = s.claim
	if bid and Spring.ValidUnitID(bid) then
		local ok, cmds = pcall(Spring.GetUnitCommands, bid, 40)
		if ok and type(cmds) == "table" then
			for _, c in ipairs(cmds) do
				local pr = c.params or {}
				if c.id == -s.def and pr[1] and pr[3] and math.abs(pr[1] - s.x) < 8 and math.abs(pr[3] - s.z) < 8 then
					Spring.GiveOrderToUnit(bid, CMD.REMOVE, { c.tag }, {})
					break
				end
			end
		end
	end
	for _, uid in ipairs(Spring.GetUnitsInCylinder(s.x, s.z, 24, Spring.GetMyTeamID()) or {}) do
		if Spring.GetUnitDefID(uid) == s.def and Spring.GetUnitIsBeingBuilt(uid) then
			if bid and Spring.ValidUnitID(bid) then
				Spring.GiveOrderToUnit(bid, CMD.RECLAIM, { uid }, {}) -- its other orders are dropped; unclaimed plans are handed out again
			end
			break
		end
	end
	s.claim = nil
end

-- Queue a blueprint (units) with center (cx, cz) and k quarter turns; returns the number of new plans
-- Open plans whose footprint lies under the given one
local function plansUnder(def, x, z, f)
	local out = {}
	local hx, hz = footHalf(def, f)
	for _, s in ipairs(sites) do
		if not s.done then
			local ox, oz = footHalf(s.def, s.f)
			if math.abs(s.x - x) < hx + ox - 2 and math.abs(s.z - z) < hz + oz - 2 then
				out[#out + 1] = s
			end
		end
	end
	return out
end

-- A new plan of the step "batch" lies on open plans: they leave the queue (their builders stop); Undo of the step brings them back. Returns how many.
local function replaceBelow(def, x, z, f, batch)
	local n = 0
	for _, s in ipairs(plansUnder(def, x, z, f)) do
		for idx, o in ipairs(sites) do
			if o == s then
				table.remove(sites, idx)
				batchReplaced[batch] = batchReplaced[batch] or {}
				table.insert(batchReplaced[batch], { site = s, index = idx })
				dropPlan(s)
				selected[s] = nil
				n = n + 1
				break
			end
		end
	end
	return n
end

-- Queue a blueprint copy as ONE step. A building of the blueprint that would lie on a real building or on bad ground is left out (counted as blocked),
-- the others are placed. Plans that lie below its buildings are replaced: they leave the queue (their builders stop) and the new ones come on top;
-- Undo brings them back. Returns new, skipped, blocked (left out), replaced.
local function addPlan(units, cx, cz, k)
	batchCounter = batchCounter + 1
	groupCounter = groupCounter + 1
	local n, skipped, blocked = 0, 0, 0
	local list, under = {}, {}
	for _, u in ipairs(units) do
		local ud = UnitDefNames[u.name]
		if ud and (ud.isBuilding or not ud.canMove) then
			local dx, dz = rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, k)
			local f = (headingToFacing(u.rot) + k) % 4
			local x, y, z = buildPos(ud, cx + dx, cz + dz, f)
			if siteExists(ud.id, x, z) then
				skipped = skipped + 1 -- the same building is planned there already
			elseif testBuild(ud, x, y, z, f) == 0 then
				blocked = blocked + 1
			else
				list[#list + 1] = { def = ud.id, name = ud.name, x = x, y = y, z = z, f = f, batch = batchCounter, tries = 0, grp = groupCounter }
				for _, s in ipairs(plansUnder(ud.id, x, z, f)) do
					under[s] = true
				end
			end
		end
	end
	local removed = {}
	for idx = #sites, 1, -1 do -- downwards, so that every index is valid when it is taken out; Undo puts them back in the opposite order
		local s = sites[idx]
		if under[s] then
			removed[#removed + 1] = { site = s, index = idx }
			table.remove(sites, idx)
			dropPlan(s)
			selected[s] = nil
		end
	end
	if #removed > 0 then
		batchReplaced[batchCounter] = removed
	end
	for _, s in ipairs(list) do
		sites[#sites + 1] = s
		n = n + 1
	end
	return n, skipped, blocked, #removed
end

local function pendingCount()
	local n = 0
	for _, s in ipairs(sites) do
		if not s.done then
			n = n + 1
		end
	end
	return n
end

-- highest batch number of the open plans (0 = none): marks when an operation happened, so that Undo takes back the newest step first
local function highestOpenBatch()
	local last = 0
	for _, s in ipairs(sites) do
		if not s.done and s.batch > last then
			last = s.batch
		end
	end
	return last
end

local function pushOp(op)
	op.mark = highestOpenBatch()
	opStack[#opStack + 1] = op
	if #opStack > 60 then
		table.remove(opStack, 1)
	end
end

-- queue order as it was: the plans of `before` that still exist in that order, new ones at the end
local function restoreOrder(before)
	local now, placed, out = {}, {}, {}
	for _, s in ipairs(sites) do
		now[s] = true
	end
	for _, s in ipairs(before) do
		if now[s] then
			out[#out + 1] = s
			placed[s] = true
		end
	end
	for _, s in ipairs(sites) do
		if not placed[s] then
			out[#out + 1] = s
		end
	end
	sites = out
end

local function undoOp(op)
	if op.kind == "remove" then
		for _, it in ipairs(op.items) do
			table.insert(sites, math.min(it.index, #sites + 1), it.site)
		end
		say(#op.items .. " plans are back in the queue")
	elseif op.kind == "rotate" then
		for _, it in ipairs(op.items) do
			local s = it.site
			s.x, s.y, s.z, s.f, s.blocked = it.x, it.y, it.z, it.f, nil
		end
		say("Rotation undone")
	elseif op.kind == "order" then
		restoreOrder(op.before)
		say("Order undone")
	end
end

local function undoLast()
	local last = highestOpenBatch()
	local top = opStack[#opStack]
	if top and top.mark >= last then
		opStack[#opStack] = nil
		undoOp(top)
		return
	end
	if last == 0 then
		say("Nothing to undo")
		return
	end
	local out, removed = {}, 0
	for _, s in ipairs(sites) do
		if s.batch == last and not s.done then
			removed = removed + 1
			dropPlan(s)
		else
			out[#out + 1] = s
		end
	end
	sites = out
	local back = batchReplaced[last]
	if back then
		local gone = 0
		batchReplaced[last] = nil
		for i = #back, 1, -1 do
			local it = back[i]
			if buildingOn(it.site) then
				gone = gone + 1 -- a building was built there in the meantime
			else
				table.insert(sites, math.min(it.index, #sites + 1), it.site)
			end
		end
		say(removed .. " plans undone, " .. (#back - gone) .. " plans below are back in the queue" .. (gone > 0 and (", " .. gone .. " dropped: a building stands there") or ""))
		return
	end
	say(removed .. " plans undone")
end

local function clearPlans()
	local n = pendingCount()
	for _, s in ipairs(sites) do
		if not s.done then
			dropPlan(s)
		end
	end
	sites = {}
	selected, opStack, batchReplaced = {}, {}, {}
	checkCursor = 1
	say(n .. " plans deleted")
end

---------------------------------------------------------------- Builders
local builderCache = {} -- defID -> { can = {defID=true} } or false
local function builderInfo(defID)
	local c = builderCache[defID]
	if c ~= nil then
		return c
	end
	local ud = UnitDefs[defID]
	c = false
	if ud and ud.isBuilder and ud.canMove and not ud.isFactory and ud.buildOptions and #ud.buildOptions > 0 then
		local can = {}
		for _, id in ipairs(ud.buildOptions) do
			can[id] = true
		end
		c = { can = can, commander = (ud.customParams and (ud.customParams.iscommander ~= nil)) or false }
	end
	builderCache[defID] = c
	return c
end

local function commandCount(id)
	if Spring.GetUnitCommandCount then
		return Spring.GetUnitCommandCount(id) or 0
	end
	local c = Spring.GetUnitCommands(id, 0)
	if type(c) == "table" then
		return #c
	end
	return c or 0
end

local function dist2(x1, z1, x2, z2)
	local dx, dz = x1 - x2, z1 - z2
	return dx * dx + dz * dz
end

-- Detect finished buildings (all around, only part of the plans per pass)
local function checkDone(maxChecks)
	local team = Spring.GetMyTeamID()
	local n = #sites
	if n == 0 then
		return
	end
	local gone
	for _ = 1, math.min(maxChecks, n) do
		if checkCursor > n then
			checkCursor = 1
		end
		local s = sites[checkCursor]
		checkCursor = checkCursor + 1
		if s and not s.done and not s.claim and buildingOn(s) then
			gone = gone or {}
			gone[s] = true
		elseif s and not s.done then
			local ids = Spring.GetUnitsInCylinder(s.x, s.z, 24, team) or {}
			for _, uid in ipairs(ids) do
				if Spring.GetUnitDefID(uid) == s.def then
					local ux, _, uz = Spring.GetUnitPosition(uid)
					if ux and math.abs(ux - s.x) < 24 and math.abs(uz - s.z) < 24 then
						local being = Spring.GetUnitIsBeingBuilt(uid)
						if not being then
							s.done = true
							doneCount = doneCount + 1
						end
						break
					end
				end
			end
		end
	end
	if gone then
		local keep, k = {}, 0
		for _, s in ipairs(sites) do
			if gone[s] then
				selected[s] = nil
				k = k + 1
			else
				keep[#keep + 1] = s
			end
		end
		sites = keep
		say(k .. " plans removed: a building stands there")
	end
end

local function siteStatus(s)
	if s.blocked and s.blocked > passNo then
		return "blocked"
	elseif s.claim then
		return "claimed"
	end
	return "pending"
end

-- Queue: sum of the open plans (metal, energy, build effort) and the build power of the own builders; every 30 frames
local queueStats = { metal = 0, energy = 0, speed = 0, buildTime = 0 }

local function updateQueueStats()
	local m, e, bt = 0, 0, 0
	for _, s in ipairs(sites) do
		if not s.done then
			local ud = UnitDefs[s.def]
			if ud then
				m, e, bt = m + (ud.metalCost or 0), e + (ud.energyCost or 0), bt + (ud.buildTime or 0)
			end
		end
	end
	local speed = 0
	if bt > 0 then
		for _, bid in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}) do
			local defID = Spring.GetUnitDefID(bid)
			local info = defID and builderInfo(defID)
			if info and (useCommander or not info.commander) and not Spring.GetUnitIsBeingBuilt(bid) then
				speed = speed + (UnitDefs[defID].buildSpeed or 0)
			end
		end
	end
	queueStats = { metal = m, energy = e, speed = speed, buildTime = bt }
end

local function fmtTime(sec)
	sec = math.floor(sec + 0.5)
	if sec >= 3600 then
		return string.format("%d:%02d h", math.floor(sec / 3600), math.floor(sec % 3600 / 60))
	end
	return string.format("%d:%02d min", math.floor(sec / 60), sec % 60)
end

-- An enemy unit that we can see near the commander: it fights instead of building (its weapons only fire at what is within reach)
local ENEMY_NEAR = 750
local function enemyNear(bid)
	local x, _, z = Spring.GetUnitPosition(bid)
	if not x then
		return false
	end
	local list = Spring.GetUnitsInCylinder(x, z, ENEMY_NEAR, Spring.ENEMY_UNITS)
	return list ~= nil and #list > 0
end

local function giveBuild(bid, s, queued)
	Spring.GiveOrderToUnit(bid, -s.def, { s.x, s.y, s.z, s.f }, queued and { "shift" } or {})
end

local function workPass(frame)
	passNo = passNo + 1
	checkDone(30)
	-- Clean up claims
	for _, s in ipairs(sites) do
		if s.claim then
			if not Spring.ValidUnitID(s.claim) or Spring.GetUnitIsDead(s.claim) then
				s.claim = nil
			elseif frame - (s.claimFrame or 0) > 90 and commandCount(s.claim) == 0 then
				s.claim = nil
			end
		end
	end
	local team = Spring.GetMyTeamID()
	-- the commander stops building when an enemy comes near: it fights, and other builders take over its plans
	for _, bid in ipairs(Spring.GetTeamUnits(team) or {}) do
		local info = builderInfo(Spring.GetUnitDefID(bid))
		if info and info.commander and commandCount(bid) > 0 and enemyNear(bid) then
			local mine = false
			for _, s in ipairs(sites) do
				if s.claim == bid and not s.done then
					s.claim = nil
					mine = true
				end
			end
			if mine then
				Spring.GiveOrderToUnit(bid, CMD.STOP, {}, {})
			end
		end
	end
	if not autoBuild or pendingCount() == 0 then
		return
	end
	local assigned = 0
	for _, bid in ipairs(Spring.GetTeamUnits(team) or {}) do
		if assigned >= 12 then
			break
		end
		local info = builderInfo(Spring.GetUnitDefID(bid))
		if info and (useCommander or not info.commander) and commandCount(bid) == 0 and not Spring.GetUnitIsBeingBuilt(bid) and not (info.commander and enemyNear(bid)) then
			local bx, _, bz = Spring.GetUnitPosition(bid)
			if bx then
				local r2 = radius * radius
				local best, bestD
				local assist, assistD
				for _, s in ipairs(sites) do
					if not s.done and info.can[s.def] and not (s.blocked and s.blocked > passNo) then
						local d = dist2(bx, bz, s.x, s.z)
						if d <= r2 then
							if not s.claim then
								if queueOrder then
									if not best then
										best, bestD = s, d -- the first free plan of the queue
									end
								elseif not bestD or d < bestD then
									best, bestD = s, d
								end
							elseif not assistD or d < assistD then
								assist, assistD = s, d
							end
						end
					end
				end
				if best then
					-- queue a small chain of neighbors behind it
					local chain = { best }
					local last = best
					for _ = 1, 3 do
						local nxt, nd
						for _, s in ipairs(sites) do
							if not s.done and not s.claim and info.can[s.def] and not (s.blocked and s.blocked > passNo) then
								local inChain = false
								for _, c in ipairs(chain) do
									if c == s then
										inChain = true
									end
								end
								if not inChain then
									if queueOrder then
										if not nxt and dist2(bx, bz, s.x, s.z) <= r2 then
											nxt = s -- the next free plan of the queue
										end
									else
										local d = dist2(last.x, last.z, s.x, s.z)
										if d <= 300 * 300 and (not nd or d < nd) then
											nxt, nd = s, d
										end
									end
								end
							end
						end
						if not nxt then
							break
						end
						chain[#chain + 1] = nxt
						last = nxt
					end
					local gave = 0
					for _, s in ipairs(chain) do
						local ud = UnitDefs[s.def]
						if testBuild(ud, s.x, s.y, s.z, s.f) == 0 then
							s.blocked = passNo + 10 -- Spot taken or not buildable: try again later
						else
							s.tries = s.tries + 1
							if s.tries > 8 then
								s.blocked = passNo + 40
								s.tries = 0
							end
							giveBuild(bid, s, gave > 0)
							gave = gave + 1
							s.claim = bid
							s.claimFrame = frame
						end
					end
					assigned = assigned + 1
				elseif assist then
					giveBuild(bid, assist, false)
					assigned = assigned + 1
				end
			end
		end
	end
end

-- Queue a single building (stamp mode of the building view); false if one is already planned there
local function addSingle(ud, x, z, f, batch)
	local bx, by, bz = buildPos(ud, x, z, f)
	if siteExists(ud.id, bx, bz) then
		return false, "exists"
	end
	if testBuild(ud, bx, by, bz, f) == 0 then
		return false, "blocked"
	end
	if not batch then
		batchCounter = batchCounter + 1
	end
	replaceBelow(ud.id, bx, bz, f, batch or batchCounter)
	sites[#sites + 1] = { def = ud.id, name = ud.name, x = bx, y = by, z = bz, f = f, batch = batch or batchCounter, tries = 0 }
	return true
end

-- Queue several buildings (row/rectangle) as ONE step; returns the number of new plans
local function addMany(ud, list, f)
	batchCounter = batchCounter + 1
	local n, blocked = 0, 0
	for _, p in ipairs(list) do
		local bx, by, bz = buildPos(ud, p.x, p.z, f)
		if not siteExists(ud.id, bx, bz) then
			if testBuild(ud, bx, by, bz, f) ~= 0 then
				replaceBelow(ud.id, bx, bz, f, batchCounter)
				sites[#sites + 1] = { def = ud.id, name = ud.name, x = bx, y = by, z = bz, f = f, batch = batchCounter, tries = 0 }
				n = n + 1
			else
				blocked = blocked + 1
			end
		end
	end
	return n, blocked
end

local function setSpacing(v)
	spacing = Shared.clampSpacing(v)
	say("Spacing: " .. spacing)
end

-- Row (Shift) or rectangle (Shift+Alt) from the start point to (x, z)
local function stampList(ud, x, z)
	local alt = Spring.GetModKeyState()
	return Shared.stampPositions(ud, rot % 4, stampDrag.x, stampDrag.z, x, z, alt, spacing, 2000)
end

-- Centers of the blueprint copies (row/rectangle) from the start point to (x, z); blueprint hull plus spacing
local function bpStampList(bp, x, z)
	local alt = Spring.GetModKeyState()
	local fx, fz = Shared.blueprintExtent(bp.units, rot)
	local raw = Shared.stampPositionsSized(fx, fz, stampDrag.x, stampDrag.z, x, z, alt, spacing, 100)
	local out = {}
	for _, p in ipairs(raw) do
		out[#out + 1] = { x = snap16(p.x), z = snap16(p.z) }
	end
	return out
end

-- What the own builders can build right now (for the display) and which faction they have
local function refreshBuildable()
	local set, any, prefix = {}, false, nil
	for _, id in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}) do
		local defID = Spring.GetUnitDefID(id)
		local info = builderInfo(defID)
		if info then
			any = true
			for def in pairs(info.can) do
				set[def] = true
			end
			prefix = prefix or UnitDefs[defID].name:sub(1, 3)
		end
	end
	buildable = any and set or nil
	if factionAuto and (prefix == "arm" or prefix == "cor" or prefix == "leg") then
		uGrid.faction = prefix
	end
end

---------------------------------------------------------------- Interface
-- Header: title, 5 button rows and the status lines; below it the content (grid or settings) from editor_common.lua
local function headHeight()
	return 8 * S + 52 * S + 4 * (Shared.m.HB + 4 * S) + 60 * S
end

local function filterHeight() -- Faction/tech buttons above the building grid
	return uGrid:filterRowCount() * (Shared.m.HB + 3) + 4 * S
end

local function bpFilterHeight() -- search row above the blueprint tiles
	return bpGrid:filterRowCount() * (Shared.m.HB + 3) + 4 * S
end

local function basePanelRect()
	local vsx, vsy = Spring.GetViewGeometry()
	local colW = Shared.m.HB + 2 * Shared.m.PAD -- button column V, O, ? at the screen edge, next to the menu
	if collapsed then
		local cx1 = (side == "right") and (vsx - colW) or 0
		return cx1, vsy * 0.90 - colW, cx1 + colW, vsy * 0.90
	end
	local cw, ch
	local minBottom = vsy * 0.05
	if optionsOpen then
		cw, ch = optionsUI:width(), optionsUI:height()
	elseif menuMode == "units" then
		cw, ch = uGrid:size()
		ch = ch + filterHeight()
		minBottom = vsy * 0.20 -- below the panel are name, description and cost (clear of the BAR info boxes at the bottom right, as in the Level Editor)
	else
		cw, ch = bpGrid:size()
		ch = ch + bpFilterHeight()
		minBottom = vsy * 0.20 -- below the panel are name and cost of the blueprint
	end
	local pw = math.min(math.max(math.floor(600 * S), cw), vsx * 0.6) -- wide enough for the status lines
	local x1 = (side == "right") and (vsx - colW - pw) or colW
	local top = vsy * 0.90
	local bottom = math.max(minBottom, top - headHeight() - ch)
	return x1, bottom, x1 + pw, top
end

-- The menu where it is now: its place at the screen edge, moved by dragging the title row
local function panelRect()
	local x1, y0, x2, y1 = basePanelRect()
	local colW = Shared.m.HB + 2 * Shared.m.PAD
	if collapsed then
		return panelMover:place(x1, y0, x2, y1, 0, 0, 40 * S)
	end
	return panelMover:place(x1, y0, x2, y1, colW, colW, 40 * S) -- the button column sits next to the menu on one side
end

-- Left edge of the button column V, O, ?: next to the menu (on its outer side)
local function columnX(x1, x2)
	local colW = Shared.m.HB + 2 * Shared.m.PAD
	if collapsed then
		return x1
	end
	return (side == "right") and x2 or (x1 - colW)
end

local function inPanel(mx, my)
	if not menuOpen then
		return false
	end
	local x1, y0, x2, y1 = panelRect()
	if mx >= x1 and mx <= x2 and my >= y0 and my <= y1 then
		return true
	end
	-- the button column next to the menu
	local m = Shared.m
	local colW = m.HB + 2 * m.PAD
	local cx1 = columnX(x1, x2)
	return mx >= cx1 and mx <= cx1 + colW and my <= y1 and my >= y1 - 10 * (m.HB + 3) - m.PAD
end

-- Radius input field: typing digits, Enter accepts, Esc cancels, a click elsewhere accepts
local radiusEdit = nil -- { text = "" } while typing
local RADIUS_MIN, RADIUS_MAX, RADIUS_STEP = 200, 6000, 200
local function radiusEnd(accept)
	if not radiusEdit then
		return
	end
	local v = accept and tonumber(radiusEdit.text)
	if v then
		radius = math.max(RADIUS_MIN, math.min(RADIUS_MAX, math.floor(v)))
	end
	radiusEdit = nil
	widgetHandler:DisownText()
end

local TIPS = {
	queue = "Queue order (Q): off = idle builders take the nearest plan (as before).\nOn = they take the open plan with the lowest number first.\Change the order of selected plans with Page up, Page down, Home and End.",	collapse = "V: collapse or expand the menu",
	gear = "O: settings, columns and rows",
	help = "?: show the keys and controls on the screen",
	modebp = "Blueprints: saved groups of buildings",
	modeunits = "Buildings: single buildings from the catalog",
	auto = "Auto-build (A): idle builders work through the\nqueued plans on their own",
	undo = "Undo the last step",
	clear = "Delete all queued plans",
	radmin = "Reduce the builders' search radius",
	radplus = "Increase the builders' search radius",
	radfield = "Search radius of the builders in Elmo (200 to 6000):\nclick, type a number, Enter accepts, Esc cancels",
	com = "Commander (C): the commander helps build too\n(otherwise only other builders do)",
	create = "Saves the selected buildings\nas a new blueprint",
	areal = "XL (experimental): carpet attack along a line.\nSelect bombers, artillery, rocket launchers or\nnukes, press XL, then drag a line on the map.\nEach unit gets a piece of it.",
	arear = "XR (experimental): attack a rectangle.\nSelect bombers, artillery, rocket launchers or\nnukes, press XR, then drag a rectangle.\nThe units spread over the whole area.",
	areac = "XC (experimental): attack a circle.\nSelect bombers, artillery, rocket launchers or\nnukes, press XC, then drag a circle from the\ncenter outwards. The units spread over it.",
}

-- Open and in-progress plans
local function planCounts()
	local open, claimed = 0, 0
	for _, s in ipairs(sites) do
		if not s.done then
			open = open + 1
			if s.claim then
				claimed = claimed + 1
			end
		end
	end
	return open, claimed
end

local radLabel -- position of the text "Radius" (drawn next to the radius buttons)
local function layout()
	local x1, y0, x2, y1 = panelRect()
	local m = Shared.m
	local pad = m.PAD
	local rh = m.HB -- button height as in the Level Editor
	local btns = {}
	local y = y1 - pad - 52 * S -- below the title
	-- button column at the screen edge next to the menu (as in the Level Editor): V (collapse/expand), O (settings), ? (help)
	local sx1 = columnX(x1, x2) + pad
	local function colBtn(k, id, label, on, tip)
		local t = y1 - (k - 1) * (m.HB + 3)
		btns[#btns + 1] = { id = id, label = label, x1 = sx1, x2 = sx1 + m.HB, y0 = t - m.HB, y1 = t, on = on, active = on, tip = tip or TIPS[id] }
	end
	colBtn(1, "collapse", "V", collapsed)
	-- Create (blueprint from the selection) at the top right of the title row, left of the button column
	btns[#btns + 1] = { id = "create", label = "Create Blueprint", x1 = x2 - pad - 260 * S, x2 = x2 - pad, y0 = y1 - pad - 46 * S, y1 = y1 - pad, tip = TIPS.create }
	if collapsed then
		return { btns = btns, info = y, rect = { x1 = x1, y0 = y0, x2 = x2, top = y } }
	end
	colBtn(2, "gear", "O", optionsOpen)
	colBtn(3, "help", "?", helpOpen)
	colBtn(4, "auto", "A", autoBuild, TIPS.auto .. "\nNow: " .. (autoBuild and "ON" or "OFF"))
	colBtn(8, "areal", "XL", area:armed() and area:mode() == "line") -- one button gap above: these are experimental
	colBtn(9, "arear", "XR", area:armed() and area:mode() == "rect")
	colBtn(10, "areac", "XC", area:armed() and area:mode() == "circle")
	colBtn(5, "queue", "Q", queueOrder, TIPS.queue .. "\nNow: " .. (queueOrder and "ON" or "OFF"))
	colBtn(6, "com", "C", useCommander, TIPS.com .. "\nNow: " .. (useCommander and "YES" or "NO"))
	local function row2(a, b)
		local w = (x2 - x1 - 2 * pad - 4 * S) / 2
		local top = y
		y = y - rh - 4 * S
		if not b then
			btns[#btns + 1] = { id = a[1], label = a[2], x1 = x1 + pad, x2 = x2 - pad, y0 = top - rh, y1 = top, on = a[3], active = a[3] }
			return
		end
		btns[#btns + 1] = { id = a[1], label = a[2], x1 = x1 + pad, x2 = x1 + pad + w, y0 = top - rh, y1 = top, on = a[3], active = a[3] }
		btns[#btns + 1] = { id = b[1], label = b[2], x1 = x1 + pad + w + 4 * S, x2 = x2 - pad, y0 = top - rh, y1 = top, on = b[3], active = b[3] }
	end
	-- status row above the mode buttons: label and number for Open, In progress and Done
	local statusLabels, statusBoxes = {}, {}
	do
		local open, claimed = planCounts()
		local items = { { "Open", open }, { "In progress", claimed }, { "Done", doneCount } }
		local top = y
		y = y - rh - 4 * S
		local gap, pairGap, boxW = 4 * S, 12 * S, 74 * S
		local w = x2 - x1 - 2 * pad
		local pw = (w - 2 * pairGap) / 3
		for i, it in ipairs(items) do
			local px = x1 + pad + (i - 1) * (pw + pairGap)
			local lw = pw - boxW - gap
			statusLabels[#statusLabels + 1] = { text = it[1], x = px + lw / 2, y0 = top - rh, w = lw }
			statusBoxes[#statusBoxes + 1] = { x1 = px + lw + gap, x2 = px + pw, y0 = top - rh, y1 = top, label = tostring(it[2]) }
		end
	end
	row2({ "modebp", "Blueprints", menuMode == "bp" }, { "modeunits", "Buildings", menuMode == "units" })
	row2({ "undo", "Undo" }, { "clear", "Clear all" })
	-- radius row: label, -, input field (shows the current value), +
	do
		local top = y
		y = y - rh - 4 * S
		local w = x2 - x1 - 2 * pad
		local gap = 4 * S
		local lw, bw = w * 0.30, w * 0.17
		local fw = w - lw - 2 * bw - 3 * gap
		local bx = x1 + pad
		radLabel = { x = bx + lw / 2, y0 = top - rh }
		bx = bx + lw + gap
		btns[#btns + 1] = { id = "radmin", label = "-", x1 = bx, x2 = bx + bw, y0 = top - rh, y1 = top }
		bx = bx + bw + gap
		btns[#btns + 1] = { id = "radfield", label = radiusEdit and (radiusEdit.text .. "|") or tostring(radius), x1 = bx, x2 = bx + fw, y0 = top - rh, y1 = top,
			on = radiusEdit ~= nil, active = radiusEdit ~= nil }
		bx = bx + fw + gap
		btns[#btns + 1] = { id = "radplus", label = "+", x1 = bx, x2 = bx + bw, y0 = top - rh, y1 = top }
	end
	local info = y
	y = y - 60 * S
	local L = { btns = btns, info = info, radLabel = radLabel, statusLabels = statusLabels, statusBoxes = statusBoxes, rect = { x1 = x1, y0 = y0, x2 = x2, top = y } }
	for _, b in ipairs(btns) do
		b.tip = b.tip or TIPS[b.id]
	end
	if menuMode == "units" and not optionsOpen then
		L.filters = uGrid:filterRects(x1, x2, y - 4 * S, Shared.m.HB)
		L.urect = { x1 = x1, y0 = y0, x2 = x2, top = y - filterHeight() }
	end
	if menuMode == "bp" and not optionsOpen then
		L.filters = bpGrid:filterRects(x1, x2, y - 4 * S, Shared.m.HB)
		L.rect = { x1 = x1, y0 = y0, x2 = x2, top = y - bpFilterHeight() }
	end
	return L
end

local function pressButton(id)
	if id == "auto" then
		autoBuild = not autoBuild
		autoBuildStopped = false
	elseif id == "undo" then
		undoLast()
	elseif id == "clear" then
		clearPlans()
	elseif id == "radmin" then
		radius = math.max(RADIUS_MIN, radius - RADIUS_STEP)
	elseif id == "radplus" then
		radius = math.min(RADIUS_MAX, radius + RADIUS_STEP)
	elseif id == "radfield" then
		bpGrid:resetEdit()
		bpGrid:setFocus(false)
		uGrid:setFocus(false)
		radiusEdit = { text = "" }
		widgetHandler:OwnText()
	elseif id == "com" then
		useCommander = not useCommander
	elseif id == "queue" then
		queueOrder = not queueOrder
		say("Queue order " .. (queueOrder and "on: builders take the open plan with the lowest number" or "off: builders take the nearest plan"))
	elseif id == "help" then
		helpOpen = true
	elseif id == "areal" then
		area:toggle("line")
	elseif id == "arear" then
		area:toggle("rect")
	elseif id == "areac" then
		area:toggle("circle")
	elseif id == "create" then
		widget:CreateBlueprint()
	elseif id == "collapse" then
		collapsed = not collapsed
		bpGrid:resetEdit()
		uGrid:setFocus(false)
	elseif id == "gear" then
		uGrid:setFocus(false)
		optionsOpen = not optionsOpen
		bpGrid.scroll = 0
		bpGrid:setArmed(false)
		armedUnit = nil
	elseif id == "modebp" or id == "modeunits" then
		menuMode = (id == "modebp") and "bp" or "units"
		optionsOpen = false
		bpGrid:resetEdit()
		bpGrid:setFocus(false)
		bpGrid:setArmed(false)
		armedUnit = nil
		bpGrid.scroll, uGrid.scroll = 0, 0
	end
end

local function mouseGround()
	local mx, my = Spring.GetMouseState()
	local _, pos = Spring.TraceScreenRay(mx, my, true)
	if pos then
		return pos[1], pos[3]
	end
end

local function halfSize(ud, f)
	local hx, hz = (ud.xsize or 4) * 4, (ud.zsize or 4) * 4
	if f % 2 == 1 then
		hx, hz = hz, hx
	end
	return hx, hz
end

-- Right click on a plan with builders selected: they build exactly this plan (Shift = behind their queue).
-- Returns true if the click was used.
local function assignToPlan(mx, my)
	local gx, gz = mouseGround()
	if not gx then
		return false
	end
	local plan, planD
	for _, s in ipairs(sites) do
		local ud = not s.done and UnitDefs[s.def]
		if ud then
			local hx, hz = halfSize(ud, s.f)
			if math.abs(gx - s.x) <= hx + 8 and math.abs(gz - s.z) <= hz + 8 then
				local d = dist2(gx, gz, s.x, s.z)
				if not planD or d < planD then
					plan, planD = s, d
				end
			end
		end
	end
	if not plan then
		return false
	end
	local builders, anyBuilder = {}, false
	for _, id in ipairs(Spring.GetSelectedUnits() or {}) do
		local info = builderInfo(Spring.GetUnitDefID(id))
		if info then
			anyBuilder = true
			if info.can[plan.def] then
				builders[#builders + 1] = id
			end
		end
	end
	if #builders == 0 then
		if anyBuilder then
			say("The selected builders cannot build " .. plan.name)
			return true
		end
		return false -- no builder selected: the click keeps its normal meaning
	end
	-- a plan of a blueprint copy: the builders build the whole copy, one after the other (a single building: just it)
	local targets = { plan }
	if plan.grp then
		targets = {}
		for _, o in ipairs(sites) do
			if o.grp == plan.grp and not o.done then
				targets[#targets + 1] = o
			end
		end
	elseif testBuild(UnitDefs[plan.def], plan.x, plan.y, plan.z, plan.f) == 0 then
		say("The spot of this plan is blocked right now")
		return true
	end
	local _, _, _, shift = Spring.GetModKeyState()
	local frame = Spring.GetGameFrame()
	local sent = 0
	for n, id in ipairs(builders) do
		local info = builderInfo(Spring.GetUnitDefID(id))
		local first = not shift
		for _, o in ipairs(targets) do
			if info.can[o.def] and (not plan.grp or testBuild(UnitDefs[o.def], o.x, o.y, o.z, o.f) ~= 0) then
				giveBuild(id, o, not first)
				first = false
				if n == 1 then
					sent = sent + 1
					o.claim, o.claimFrame, o.blocked = id, frame, nil
				end
			end
		end
	end
	if sent == 0 then
		say("Nothing of it can be built right now")
		return true
	end
	say(string.format("%d builder%s build %s%s", #builders, #builders == 1 and "" or "s", plan.grp and (sent .. " plans of this blueprint") or plan.name, shift and " (queued)" or ""))
	return true
end

---------------------------------------------------------------- Selecting plans
-- the open plan under the ground point (footprint plus a little), the nearest center first
local function planAt(gx, gz)
	local plan, planD
	for _, s in ipairs(sites) do
		local ud = not s.done and UnitDefs[s.def]
		if ud then
			local hx, hz = halfSize(ud, s.f)
			if math.abs(gx - s.x) <= hx + 8 and math.abs(gz - s.z) <= hz + 8 then
				local d = dist2(gx, gz, s.x, s.z)
				if not planD or d < planD then
					plan, planD = s, d
				end
			end
		end
	end
	return plan
end

local function selCount()
	local n = 0
	for _, s in ipairs(sites) do
		if selected[s] and not s.done then
			n = n + 1
		end
	end
	return n
end

-- single = only this building, otherwise the whole blueprint copy it belongs to; add = Shift (toggles; force = select, do not toggle off)
local function selectPlan(s, single, add, force)
	local group = { s }
	if not single and s.grp then
		group = {}
		for _, o in ipairs(sites) do
			if o.grp == s.grp and not o.done then
				group[#group + 1] = o
			end
		end
	end
	if not add then
		selected = {}
	end
	local allIn = true
	for _, o in ipairs(group) do
		allIn = allIn and selected[o] == true
	end
	for _, o in ipairs(group) do
		selected[o] = (force or not (add and allIn)) or nil
	end
	say(selCount() .. " plans selected (Del = remove, [ ] = rotate, Page up/down, Home/End = order)")
end

local function selectRect(x0, z0, x1, z1, add)
	if not add then
		selected = {}
	end
	local lx, hx, lz, hz = math.min(x0, x1), math.max(x0, x1), math.min(z0, z1), math.max(z0, z1)
	for _, s in ipairs(sites) do
		if not s.done and s.x >= lx and s.x <= hx and s.z >= lz and s.z <= hz then
			selected[s] = true
		end
	end
	say(selCount() .. " plans selected")
end

local function removeSelected()
	local items, keep = {}, {}
	for i, s in ipairs(sites) do
		if selected[s] and not s.done then
			items[#items + 1] = { site = s, index = i }
		else
			keep[#keep + 1] = s
		end
	end
	if #items == 0 then
		return false
	end
	for _, it in ipairs(items) do
		dropPlan(it.site)
	end
	pushOp({ kind = "remove", items = items })
	sites = keep
	selected = {}
	say(#items .. " plans removed from the queue (Undo brings them back)")
	return true
end

-- k quarter turns around the center of the selection; only plans that are not being built
local function rotateSelected(k)
	local list = {}
	local lx, hx, lz, hz
	for _, s in ipairs(sites) do
		if selected[s] and not s.done then
			list[#list + 1] = s
			lx, hx = math.min(lx or s.x, s.x), math.max(hx or s.x, s.x)
			lz, hz = math.min(lz or s.z, s.z), math.max(hz or s.z, s.z)
		end
	end
	if #list == 0 then
		return false
	end
	local cx, cz = (lx + hx) / 2, (lz + hz) / 2
	local items = {}
	for _, s in ipairs(list) do
		if not s.claim then
			items[#items + 1] = { site = s, x = s.x, y = s.y, z = s.z, f = s.f }
		end
	end
	if #items == 0 then
		say("Plans that are being built cannot be rotated")
		return true
	end
	pushOp({ kind = "rotate", items = items })
	for _, it in ipairs(items) do
		local s = it.site
		local dx, dz = rotateOffset(s.x - cx, s.z - cz, k % 4)
		local f = (s.f + k) % 4
		local x, y, z = buildPos(UnitDefs[s.def], cx + dx, cz + dz, f)
		s.x, s.y, s.z, s.f, s.blocked, s.tries = x, y, z, f, nil, 0
	end
	say(#items .. " plans rotated" .. (#items < #list and (" (" .. (#list - #items) .. " being built: not rotated)") or ""))
	return true
end

-- mode: "up" / "down" one place, "front" / "back" to the start / end of the queue (the numbers in the world follow)
local function orderSelected(mode)
	local open, done, before = {}, {}, {}
	for i, s in ipairs(sites) do
		before[i] = s
		if s.done then
			done[#done + 1] = s
		else
			open[#open + 1] = s
		end
	end
	local any = false
	for _, s in ipairs(open) do
		any = any or selected[s] == true
	end
	if not any then
		return false
	end
	local n = #open
	if mode == "front" or mode == "back" then
		local sel, rest = {}, {}
		for _, s in ipairs(open) do
			if selected[s] then
				sel[#sel + 1] = s
			else
				rest[#rest + 1] = s
			end
		end
		open = {}
		for _, s in ipairs(mode == "front" and sel or rest) do
			open[#open + 1] = s
		end
		for _, s in ipairs(mode == "front" and rest or sel) do
			open[#open + 1] = s
		end
	elseif mode == "up" then
		for i = 2, n do
			if selected[open[i]] and not selected[open[i - 1]] then
				open[i], open[i - 1] = open[i - 1], open[i]
			end
		end
	else
		for i = n - 1, 1, -1 do
			if selected[open[i]] and not selected[open[i + 1]] then
				open[i], open[i + 1] = open[i + 1], open[i]
			end
		end
	end
	local out = {}
	for _, s in ipairs(done) do
		out[#out + 1] = s
	end
	for _, s in ipairs(open) do
		out[#out + 1] = s
	end
	local changed = false
	for i, s in ipairs(out) do
		changed = changed or before[i] ~= s
	end
	if changed then
		pushOp({ kind = "order", before = before })
		sites = out
		local first = #done
		for i, s in ipairs(out) do
			if selected[s] and not s.done then
				first = i - #done
				break
			end
		end
		say("Queue order changed: the selection now starts at number " .. first)
	end
	return true
end

-- Left click with nothing armed: on a plan = select it (Ctrl: only that building; Shift: add); Ctrl + drag = rectangle. Returns true if used.
local function selectPress(mx, my)
	local anyOpen = false
	for _, s in ipairs(sites) do
		if not s.done then
			anyOpen = true
			break
		end
	end
	if not anyOpen then
		selected = {}
		return false
	end
	local what = Spring.TraceScreenRay(mx, my)
	if what == "unit" then
		return false -- a click on a unit stays the game's
	end
	local gx, gz = mouseGround()
	if not gx then
		return false
	end
	local _, ctrl, _, shift = Spring.GetModKeyState()
	local hit = planAt(gx, gz)
	if ctrl then
		selBox = { x = gx, z = gz, hit = hit, shift = shift }
		return true
	end
	if hit then
		-- one click: this building; a double click: the whole blueprint copy it belongs to
		local now = os.clock()
		local dbl = lastClick and lastClick.site == hit and now - lastClick.t < 0.4
		lastClick = { site = hit, t = now }
		if dbl and hit.grp then
			lastClick = nil
			selectPlan(hit, false, shift, true)
		else
			selectPlan(hit, true, shift)
		end
		return true
	end
	if not shift then
		selected = {}
	end
	return false
end

function widget:IsAbove(mx, my)
	rescale()
	return inPanel(mx, my)
end

function widget:MousePress(mx, my, button)
	rescale()
	if helpOpen then
		helpOpen = false -- every click closes the help board
		return true
	end
	if (button == 4 or button == 5) and (armedUnit or bpGrid.armed) then
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
	if radiusEdit and not inPanel(mx, my) then
		radiusEnd(true)
	end
	if inPanel(mx, my) then
		local _, _, _, top = panelRect()
		local inTitle = not collapsed and my >= top - Shared.m.PAD - 52 * S
		if button ~= 1 then
			if button == 3 and inTitle then
				panelMover:reset() -- right click on the title: the menu goes back to its place
			end
			return true
		end
		local L = layout()
		for _, b in ipairs(L.btns) do
			if mx >= b.x1 and mx <= b.x2 and my >= b.y0 and my <= b.y1 then
				if b.id ~= "radfield" then
					radiusEnd(true)
				end
				if bpGrid.editing then
					local e = bpGrid.editing
					bpGrid:resetEdit()
					bpGrid:commitRename(e.name, e.text)
				end
				pressButton(b.id)
				return true
			end
		end
		radiusEnd(true)
		if collapsed then
			return true
		end
		if inTitle and mx >= L.rect.x1 and mx <= L.rect.x2 then
			panelMover:press(mx, my) -- drag the title row: the menu moves
			return true
		end
		if optionsOpen then
			if optionsUI:press(L.rect, mx, my) then
				bpGrid.scroll = 0
			end
			return true
		end
		if menuMode == "units" then
			if Shared.scrollbarPress(uGrid, L.urect, mx, my) then
				return true
			end
			for _, r in ipairs(L.filters or {}) do
				if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
					if r.kind == "faction" then
						factionAuto = false
					end
					uGrid:applyFilter(r)
					return true
				end
			end
			uGrid:setFocus(false)
			local ui = uGrid:at(L.urect, mx, my)
			if ui then
				local e = uGrid:list()[ui]
				armedUnit = e.name
				area:disarm()
				bpGrid:setArmed(false)
				say("Building '" .. e.name .. "': left click = queue, right click = end")
			end
			return true
		end
		if Shared.scrollbarPress(bpGrid, L.rect, mx, my) then
			return true
		end
		for _, r in ipairs(L.filters or {}) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				bpGrid:applyFilter(r)
				return true
			end
		end
		if my > L.rect.top or my < L.rect.y0 then
			bpGrid.confirmDel = nil
			bpGrid:setFocus(false)
			return true
		end
		bpGrid:press(L.rect, mx, my)
		return true
	end
	if button == 3 and not area:armed() and not armedUnit and not bpGrid.armed and assignToPlan(mx, my) then
		return true
	end
	if button == 1 and not area:armed() and not armedUnit and not bpGrid.armed and selectPress(mx, my) then
		return true
	end
	if area:press(button) then
		return true
	end
	if armedUnit then
		if button == 3 then
			armedUnit = nil
			stampDrag = nil
			return true
		end
		if button == 1 then
			local ud = UnitDefNames[armedUnit]
			local gx, gz = mouseGround()
			if ud and gx then
				local _, _, _, shift = Spring.GetModKeyState()
				if shift then
					stampDrag = { x = gx, z = gz } -- row/rectangle: all are queued on release
				else
					-- one plan; while the button is held more follow after every footprint of mouse movement (one step for undo)
					local f = rot % 4
					batchCounter = batchCounter + 1
					local hx, hz = halfSize(ud, f)
					local gap = spacing * 16
					paint = { ud = ud, f = f, batch = batchCounter, x = gx, z = gz, sx = math.max(16, hx * 2 + gap), sz = math.max(16, hz * 2 + gap) }
					local added, why = addSingle(ud, gx, gz, f, paint.batch)
					if not added then
						say(why == "blocked" and "Not queued: a building or the ground is in the way" or "There is already a plan there")
					end
				end
			end
			return true
		end
	end
	if bpGrid.armed then
		if button == 3 then
			bpGrid:setArmed(false)
			stampDrag = nil
			return true
		end
		if button == 1 then
			local bp = LIST[bpGrid.selected]
			local gx, gz = mouseGround()
			local _, _, _, shift = Spring.GetModKeyState()
			if bp and gx and shift then
				stampDrag = { x = snap16(gx), z = snap16(gz), bp = true } -- Row/rectangle of blueprints
			elseif bp and gx then
				local n, skipped, blocked, replaced = addPlan(bp.units, snap16(gx), snap16(gz), rot)
				say(string.format("%d plans queued%s%s%s", n, skipped > 0 and (" (" .. skipped .. " already present)") or "",
					blocked > 0 and (", " .. blocked .. " left out: a building or bad ground in the way") or "",
					replaced > 0 and (", " .. replaced .. " plans below replaced (Undo brings them back)") or ""))
			end
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
		bpGrid:move(layout().rect, mx, my)
	end
end

function widget:MouseRelease(mx, my, button)
	if panelMover:release() then
		return
	end
	if selBox then
		local b = selBox
		selBox = nil
		local gx, gz = mouseGround()
		if gx then
			if math.abs(gx - b.x) < 24 and math.abs(gz - b.z) < 24 then
				if b.hit then
					selectPlan(b.hit, true, b.shift)
				elseif not b.shift then
					selected = {}
				end
			else
				selectRect(b.x, b.z, gx, gz, b.shift)
			end
		end
		return
	end
	if Shared.scrollbarRelease() then
		return
	end
	bpGrid:release()
	area:release()
	paint = nil
	if stampDrag then
		local ud = armedUnit and UnitDefNames[armedUnit]
		local gx, gz = mouseGround()
		local bp = stampDrag.bp and LIST[bpGrid.selected]
		if bp and gx then
			local total, copies, leftOut, replacedAll = 0, 0, 0, 0
			batchCounter = batchCounter + 1
			local keep = batchCounter
			for _, c in ipairs(bpStampList(bp, gx, gz)) do
				local n, _, blocked, replaced = addPlan(bp.units, c.x, c.z, rot)
				total, copies, replacedAll, leftOut = total + n, copies + 1, replacedAll + replaced, leftOut + blocked
			end
			-- all copies as one step for undo
			for _, s in ipairs(sites) do
				if s.batch > keep then
					s.batch = keep
				end
			end
			-- the plans replaced by any copy come back together with the whole step
			local later = {}
			for b in pairs(batchReplaced) do
				if b > keep then
					later[#later + 1] = b
				end
			end
			for _, b in ipairs(later) do
				batchReplaced[keep] = batchReplaced[keep] or {}
				for _, it in ipairs(batchReplaced[b]) do
					table.insert(batchReplaced[keep], it)
				end
				batchReplaced[b] = nil
			end
			batchCounter = keep
			say(string.format("%d plans queued (%d x blueprint)%s%s", total, copies, leftOut > 0 and (", " .. leftOut .. " left out: a building or bad ground in the way") or "",
				replacedAll > 0 and (", " .. replacedAll .. " plans below replaced") or ""))
		elseif ud and gx and not stampDrag.bp then
			local n, blocked = addMany(ud, stampList(ud, gx, gz), rot % 4)
			say(string.format("%d plans queued%s", n, blocked > 0 and (", " .. blocked .. " skipped: a building or bad ground in the way") or ""))
		end
		stampDrag = nil
	end
end

-- Text input while renaming (only active while renaming)
function widget:TextInput(utf8char)
	if radiusEdit then
		if utf8char:match("^%d$") and #radiusEdit.text < 5 then
			radiusEdit.text = radiusEdit.text .. utf8char
		end
		return true
	end
	return bpGrid:textInput(utf8char) or uGrid:textInput(utf8char)
end

function widget:KeyPress(key)
	if radiusEdit then
		if key == 13 or key == 271 then
			radiusEnd(true)
		elseif key == 27 then
			radiusEnd(false)
		elseif key == 8 then
			radiusEdit.text = radiusEdit.text:sub(1, -2)
		end
		return true
	end
	if not (uGrid.focus or bpGrid.focus or bpGrid.editing) and selCount() > 0 then
		-- selected plans: Del removes, [ ] rotate, Page up / Page down / Home / End change the queue order
		if key == 127 then
			return removeSelected()
		elseif (key == 91 or key == 93) and not armedUnit and not bpGrid.armed then
			return rotateSelected(key == 93 and 1 or 3)
		elseif key == 280 then
			return orderSelected("up")
		elseif key == 281 then
			return orderSelected("down")
		elseif key == 278 then
			return orderSelected("front")
		elseif key == 279 then
			return orderSelected("back")
		end
	end
	if uGrid.focus then
		return uGrid:key(key)
	end
	return bpGrid:key(key)
end

function widget:MouseWheel(up, value)
	rescale()
	local mx, my = Spring.GetMouseState()
	if (armedUnit or bpGrid.armed) and not inPanel(mx, my) then
		local _, _, _, shift = Spring.GetModKeyState()
		if shift then
			setSpacing(spacing + (up and 1 or -1)) -- Shift + mouse wheel: spacing
			return true
		end
	end
	if inPanel(mx, my) then
		if optionsOpen or collapsed then
			return true
		end
		if menuMode == "units" then
			uGrid:wheel(layout().urect, up)
		else
			bpGrid:wheel(layout().rect, up)
		end
		return true
	end
	if bpGrid.armed or armedUnit then
		local alt = Spring.GetModKeyState()
		if alt then
			rot = (rot + (up and 1 or 3)) % 4
			return true
		end
	end
	return false
end

local function outline(s, hx, hz, y, r, g, b, a)
	gl.Color(r, g, b, a)
	gl.BeginEnd(GL.LINE_LOOP, function()
		gl.Vertex(s.x - hx, y, s.z - hz)
		gl.Vertex(s.x + hx, y, s.z - hz)
		gl.Vertex(s.x + hx, y, s.z + hz)
		gl.Vertex(s.x - hx, y, s.z + hz)
	end)
end

-- 3D ghosts of the open plans (the ghost.max closest to the mouse pointer when there are more)
local ghostSeq = 0 -- every plan gets its own key (tostring of a table is the same for all tables in the engine)
local function drawPlanGhosts()
	local open = {}
	for _, s in ipairs(sites) do
		if not s.done then
			open[#open + 1] = s
		end
	end
	if #open > ghost.max then
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		local cx, cz = pos and pos[1] or open[1].x, pos and pos[3] or open[1].z
		table.sort(open, function(a, b)
			return dist2(cx, cz, a.x, a.z) < dist2(cx, cz, b.x, b.z)
		end)
	end
	local team = Spring.GetMyTeamID()
	for i = 1, math.min(#open, ghost.max) do
		local s = open[i]
		if not s.gid then
			ghostSeq = ghostSeq + 1
			s.gid = ghostSeq
		end
		ghost:draw("p" .. s.gid, s.def, team, s.x, s.y, s.z, s.f * (math.pi / 2))
	end
end

local function drawWorldInner()
	if #sites == 0 and not bpGrid.armed and not armedUnit then
		return
	end
	rescale()
	local ok, err = pcall(function()
		gl.DepthTest(false)
		gl.LineWidth(2)
		for _, s in ipairs(sites) do
			if not s.done then
				local ud = UnitDefs[s.def]
				if ud then
					local hx, hz = halfSize(ud, s.f)
					local st = siteStatus(s)
					local y = Spring.GetGroundHeight(s.x, s.z) + 4
					if st == "blocked" then
						outline(s, hx, hz, y, 1, 0.3, 0.3, 0.9)
					elseif st == "claimed" then
						outline(s, hx, hz, y, 1, 0.9, 0.2, 0.95)
					else
						outline(s, hx, hz, y, 0.3, 0.6, 1, 0.95)
					end
					if selected[s] then
						gl.LineWidth(4)
						outline(s, hx + 5, hz + 5, y + 1, 1, 1, 1, 1)
						gl.LineWidth(2)
					end
				end
			end
		end
		drawPlanGhosts()
		if selBox then
			local gx, gz = mouseGround()
			if gx then
				local cx, cz = (selBox.x + gx) / 2, (selBox.z + gz) / 2
				outline({ x = cx, z = cz }, math.abs(gx - selBox.x) / 2, math.abs(gz - selBox.z) / 2, Spring.GetGroundHeight(cx, cz) + 8, 1, 1, 1, 0.9)
			end
		end
		-- single building at the mouse pointer: green/red frame and the 3D model
		local ud1 = armedUnit and UnitDefNames[armedUnit]
		if ud1 and stampDrag then
			local mx, my = Spring.GetMouseState()
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos then
				local f = rot % 4
				local hx, hz = halfSize(ud1, f)
				local team = Spring.GetMyTeamID()
				for i, p in ipairs(stampList(ud1, pos[1], pos[3])) do
					local x, y, z = buildPos(ud1, p.x, p.z, f)
					local free = testBuild(ud1, x, y, z, f) ~= 0
					if free then
						outline({ x = x, z = z }, hx, hz, y + 4, 0.3, 1, 0.4, 0.9)
					else
						outline({ x = x, z = z }, hx, hz, y + 4, 1, 0.3, 0.3, 0.9)
					end
					if i <= ghost.max then
						ghost:draw("s" .. i, ud1.id, team, x, y, z, f * (math.pi / 2))
					end
				end
			end
		elseif ud1 then
			local mx, my = Spring.GetMouseState()
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and not inPanel(mx, my) then
				local f = rot % 4
				local x, y, z = buildPos(ud1, pos[1], pos[3], f)
				local hx, hz = halfSize(ud1, f)
				local free = testBuild(ud1, x, y, z, f) ~= 0
				if free then
					outline({ x = x, z = z }, hx, hz, y + 4, 0.3, 1, 0.4, 0.9)
				else
					outline({ x = x, z = z }, hx, hz, y + 4, 1, 0.3, 0.3, 0.9)
				end
				ghost:draw("u", ud1.id, Spring.GetMyTeamID(), x, y, z, f * (math.pi / 2))
			end
		end
		local bp = bpGrid.armed and LIST[bpGrid.selected] or nil
		if bp then
			local mx, my = Spring.GetMouseState()
			if not inPanel(mx, my) then
				local _, pos = Spring.TraceScreenRay(mx, my, true)
				if pos then
					-- Centers: one entry at the mouse pointer, while dragging (Shift) all copies
					local centers = { { x = snap16(pos[1]), z = snap16(pos[3]) } }
					if stampDrag and stampDrag.bp then
						centers = bpStampList(bp, pos[1], pos[3])
					end
					local budget = 500 -- no more frames are drawn
					for _, ctr in ipairs(centers) do
						for _, u in ipairs(bp.units) do
							local ud = UnitDefNames[u.name]
							if budget > 0 and ud and (ud.isBuilding or not ud.canMove) then
								budget = budget - 1
								local dx, dz = rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, rot)
								local f = (headingToFacing(u.rot) + rot) % 4
								local x, y, z = buildPos(ud, ctr.x + dx, ctr.z + dz, f)
								local hx, hz = halfSize(ud, f)
								local free = testBuild(ud, x, y, z, f) ~= 0
								local fake = { x = x, z = z }
								if free then
									outline(fake, hx, hz, y + 4, 0.3, 1, 0.4, 0.9)
								else
									outline(fake, hx, hz, y + 4, 1, 0.3, 0.3, 0.9)
								end
							end
						end
					end
				end
			end
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
		-- 3D models (for large blueprints only the ghost.max buildings closest to the center)
		if bp then
			local mx, my = Spring.GetMouseState()
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if pos and not inPanel(mx, my) then
				if not bp.near then
					bp.near = {}
					for i in ipairs(bp.units) do
						bp.near[i] = i
					end
					table.sort(bp.near, function(a, b)
						local ua, ub = bp.units[a], bp.units[b]
						local da = (tonumber(ua.dx) or 0) ^ 2 + (tonumber(ua.dz) or 0) ^ 2
						local db = (tonumber(ub.dx) or 0) ^ 2 + (tonumber(ub.dz) or 0) ^ 2
						return da < db
					end)
				end
				local centers = { { x = snap16(pos[1]), z = snap16(pos[3]) } }
				if stampDrag and stampDrag.bp then
					centers = bpStampList(bp, pos[1], pos[3])
				end
				local team = Spring.GetMyTeamID()
				local shown = 0
				for c, ctr in ipairs(centers) do
					for _, i in ipairs(bp.near) do
						if shown >= ghost.max then
							break
						end
						local u = bp.units[i]
						local ud = UnitDefNames[u.name]
						if ud and (ud.isBuilding or not ud.canMove) then
							local dx, dz = rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, rot)
							local f = (headingToFacing(u.rot) + rot) % 4
							local x, y, z = buildPos(ud, ctr.x + dx, ctr.z + dz, f)
							ghost:draw("b" .. c .. "_" .. i, ud.id, team, x, y, z, f * (math.pi / 2))
							shown = shown + 1
						end
					end
				end
			end
		end
	end)
	if not ok then
		bpGrid:setArmed(false)
		armedUnit = nil
		say("Preview disabled: " .. tostring(err))
	end
end

function widget:DrawWorld()
	drawWorldInner()
	ghost:endFrame()
	local ok, err = pcall(area.draw, area)
	if not ok then
		area:disarm()
		say("Area attack preview disabled: " .. tostring(err))
	end
end

-- Numbers of the open plans in the world: order of the queue, color by status
local function drawSiteNumbers()
	local n = 0
	for _, s in ipairs(sites) do
		if not s.done then
			n = n + 1
			if n > 250 then
				break
			end
			local sx, sy = Spring.WorldToScreenCoords(s.x, s.y + 20, s.z)
			if sx and sy then
				local st = siteStatus(s)
				if selected[s] then
					gl.Color(1, 1, 1, 1)
				elseif st == "blocked" then
					gl.Color(1, 0.4, 0.4, 1)
				elseif st == "claimed" then
					gl.Color(1, 0.9, 0.3, 1)
				else
					gl.Color(0.6, 0.8, 1, 1)
				end
				gl.Text(tostring(n), sx, sy, 16 * S, "co")
			end
		end
	end
	gl.Color(1, 1, 1, 1)
end

-- Preview of an armed blueprint: the order in which its buildings will be built, 1 to n for every copy (placed, they get the next numbers of the queue)
local function drawPreviewNumbers()
	local bp = bpGrid.armed and LIST[bpGrid.selected] or nil
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
	local centers = { { x = snap16(pos[1]), z = snap16(pos[3]) } }
	if stampDrag and stampDrag.bp then
		centers = bpStampList(bp, pos[1], pos[3])
	end
	local budget = 500
	gl.Color(1, 1, 0.55, 1)
	for _, ctr in ipairs(centers) do
		local n = 0
		for _, u in ipairs(bp.units) do
			local ud = UnitDefNames[u.name]
			if ud and (ud.isBuilding or not ud.canMove) then
				n = n + 1
				if budget > 0 then
					budget = budget - 1
					local dx, dz = rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, rot)
					local f = (headingToFacing(u.rot) + rot) % 4
					local x, y, z = buildPos(ud, ctr.x + dx, ctr.z + dz, f)
					local sx, sy = Spring.WorldToScreenCoords(x, y + 20, z)
					if sx and sy then
						gl.Text(tostring(n), sx, sy, 16 * S, "co")
					end
				end
			end
		end
	end
	gl.Color(1, 1, 1, 1)
end

local function drawScreenBody()
	rescale()
	if #sites > 0 then
		pcall(drawSiteNumbers)
	end
	pcall(drawPreviewNumbers)
	if not menuOpen then
		return
	end
	local x1, y0, x2, y1 = panelRect()
	local L = layout()
	local mx, my = Spring.GetMouseState()
	gl.Color(0, 0, 0, 0.7)
	gl.Rect(x1, y0, x2, y1)
	gl.Color(1, 1, 1, 1)
	if not collapsed then
		gl.Text("BluePrinter", x1 + 8 * S, y1 - 36 * S, 28 * S, "o")
	end
	Shared.drawButtons(L.btns, 26 * S, Shared.m.HB) -- same look as the Level Editor
	if L.radLabel then
		gl.Color(1, 1, 1, 1)
		gl.Text("Radius", L.radLabel.x, L.radLabel.y0 + (Shared.m.HB - 26 * S) / 2 + 3 * S, 26 * S, "co")
	end
	if collapsed then
		gl.Color(1, 1, 1, 1)
		return
	end
	gl.Color(1, 1, 1, 1)
	Shared.drawButtons(L.statusBoxes, 26 * S, Shared.m.HB)
	for _, t in ipairs(L.statusLabels) do
		local fs = 26 * S
		local tw = (tonumber(gl.GetTextWidth(t.text)) or 0) * fs
		if tw > t.w and tw > 0 then
			fs = fs * t.w / tw -- shrink until it fits
		end
		gl.Color(1, 1, 1, 1)
		gl.Text(t.text, t.x, t.y0 + (Shared.m.HB - fs) / 2 + 3 * S, fs, "co")
	end
	local open = planCounts()
	local armed = bpGrid.armed or armedUnit
	if armed then
		gl.Text("Left click = queue", x1 + 8 * S, L.info - 22 * S, 18 * S, "o")
	end
	if open > 0 then
		local q = queueStats
		local t = (q.speed > 0) and ("ca. " .. fmtTime(q.buildTime / q.speed)) or "no builders"
		gl.Text(string.format("Remaining: metal %d, energy %d, build time %s", q.metal, q.energy, t), x1 + 8 * S, L.info - (armed and 48 or 22) * S, 18 * S, "o")
	end
	if optionsOpen then
		optionsUI:draw(L.rect, mx, my)
	elseif menuMode == "units" then
		Shared.drawButtons(L.filters, 22 * S, Shared.m.HB)
		uGrid:draw(L.urect, mx, my, armedUnit, nil, inPanel(mx, my))
		-- Hint above the menu
		gl.Color(1, 1, 1, 1)
		gl.Text(armedUnit and "Left click queues, right click ends, [ and ] rotate" or "Click a building, then on the map",
			(x1 + x2) / 2, y1 + 8 * S, 24 * S, "co")
		if armedUnit then
			gl.Text("Shift = row, Shift+Alt = rectangle, Shift+Mouse wheel = spacing (" .. spacing .. ")", (x1 + x2) / 2, y1 + 8 * S + 30 * S, 20 * S, "co")
		end
	else
		Shared.drawButtons(L.filters, 22 * S, Shared.m.HB)
		bpGrid:draw(L.rect, mx, my, inPanel(mx, my))
		if bpGrid.armed then
			gl.Color(1, 1, 1, 1)
			gl.Text("Shift = row, Shift+Alt = rectangle, Shift+Mouse wheel = spacing (" .. spacing .. ")", (x1 + x2) / 2, y1 + 8 * S + 30 * S, 20 * S, "co")
		end
		if #LIST == 0 then
			gl.Text("No blueprints found", x1 + 8 * S, L.rect.top - 24 * S, 14 * S, "o")
		end
	end
	gl.Color(1, 1, 1, 1)
	if not Shared.drawTip(L.btns, mx, my) and L.filters and not optionsOpen then
		Shared.drawTip(L.filters, mx, my)
	end
end

-- For tests in the game: position of the buttons and the queue numbers
-- For tests: queues blueprint number i of the list at the position (x, z) like a click on the map
function widget:DebugPlan(i, x, z)
	local bp = LIST[i]
	return bp and addPlan(bp.units, snap16(x), snap16(z), rot) or 0
end

-- For tests: the grids of the blueprint view and the buildings view
function widget:DebugGrids()
	return bpGrid, uGrid
end

function widget:DebugLayout()
	rescale()
	return layout(), queueStats, #sites
end

function widget:DrawScreen()
	drawScreenBody()
	-- the help board comes last, so it lies above the menu
	if helpOpen then
		local ok, err = pcall(Shared.drawHelp, "BluePrinter - Help", HELP_SECTIONS)
		if not ok then
			helpOpen = false
			say("Help board disabled: " .. tostring(err))
		end
	end
end

-- Painting: while the left mouse button is held a plan is added after every footprint of mouse movement; blocked spots are left out
function widget:Update()
	if not paint then
		return
	end
	local mx, my, left = Spring.GetMouseState()
	if not left then
		paint = nil
		return
	end
	local gx, gz = mouseGround()
	if gx then
		local d = paint
		Shared.paintChain(d, gx, gz, function(px, pz)
			local bx, by, bz = buildPos(d.ud, px, pz, d.f)
			if testBuild(d.ud, bx, by, bz, d.f) ~= 0 then
				addSingle(d.ud, px, pz, d.f, d.batch)
			end
		end)
	end
end

function widget:GameFrame(n)
	pcall(area.step, area, n)
	if n % 60 == 1 and not Spring.GetSpectatingState() then
		pcall(refreshBuildable)
	end
	if n % 30 == 7 then
		pcall(updateQueueStats)
	end
	if n % PASS_FRAMES ~= 0 then
		return
	end
	local spec = Spring.GetSpectatingState()
	if spec then
		return
	end
	local ok, err = pcall(workPass, n)
	if not ok then
		say("Error in the build routine: " .. tostring(err) .. " - auto-build is off for this game (button A switches it on again)")
		autoBuildStopped = autoBuildStopped or autoBuild
		autoBuild = false
	end
end

---------------------------------------------------------------- Commands, saving
local ACTIONS = {
	bp_menu = function()
		menuOpen = not menuOpen
		return true
	end,
	bp_rotate = function()
		rot = (rot + 1) % 4
		say("Facing: " .. FACING_NAME[rot])
		return true
	end,
	bp_undo = function()
		undoLast()
		return true
	end,
	bp_clear = function()
		clearPlans()
		return true
	end,
	bp_com = function()
		useCommander = not useCommander
		say("Commanders help build: " .. (useCommander and "yes" or "no"))
		return true
	end,
	bp_side = function(_, _, words)
		local w = words and words[1]
		if w == "left" then
			side = "left"
		elseif w == "right" then
			side = "right"
		else
			side = (side == "left") and "right" or "left"
		end
		return true
	end,
	bp_ghost = function(_, _, words)
		say(ghost:command(words and words[1], "bp_ghost"))
		return true
	end,
	bp_create = function()
		widget:CreateBlueprint()
		return true
	end,
	bp_mode = function(_, _, words)
		local w = words and words[1]
		if w == "bp" then
			pressButton("modebp")
		elseif w == "units" then
			pressButton("modeunits")
		else
			say("Mode: " .. ((menuMode == "units") and "units" or "bp") .. "  (/bp_mode bp | units)")
		end
		return true
	end,
	bp_carpet = function(_, _, words)
		local w = words and words[1]
		return area:toggle((w == "rect" or w == "circle" or w == "line") and w or nil)
	end,
	bp_helpbox = function()
		helpOpen = not helpOpen
		return true
	end,
	bp_spacing = function(_, _, words)
		local a = words and words[1]
		if a == "+" then
			setSpacing(spacing + 1)
		elseif a == "-" then
			setSpacing(spacing - 1)
		elseif tonumber(a) then
			setSpacing(tonumber(a))
		else
			say("Spacing: " .. spacing .. "  (/bp_spacing <n> | + | -)")
		end
		return true
	end,
	bp_scan = function()
		scanBlueprints()
		say(#LIST .. " blueprints found")
		return true
	end,
}

-- Save the selection (buildings only) as a new blueprint: BluePrinter/bp_001.lua etc.
function widget:CreateBlueprint()
	local lines = lib.linesFromUnits(Spring.GetSelectedUnits() or {}, { onlyBuildings = true })
	if not lines then
		say("No buildings selected: select buildings first, then press the button")
		return
	end
	scanBlueprints()
	local name = lib:nextName()
	local ok, err = lib:write(name, lines, "BluePrinter blueprint: positions relative to the center of the selection (dx, dz), h = height above ground")
	if not ok then
		say("Saving failed: " .. tostring(err) .. " (run install_blueprinter.bat again)")
		return
	end
	scanBlueprints()
	local i = lib:index(name)
	if i then
		bpGrid.selected = i
		bpGrid:setArmed(true)
		optionsOpen = false
		local rect = layout().rect
		bpGrid:scrollTo(rect, i)
	end
	say(string.format("Blueprint '%s' saved: %d buildings", name, #lines))
end

-- BAR key for build rotation ("buildfacing inc|dec", normally [ and ]): rotates the blueprint stamp
local function buildFacingAction(_, _, words)
	if bpGrid.armed or armedUnit then
		local w = words and words[1]
		rot = (rot + ((w == "dec") and 3 or 1)) % 4
		say("Blueprint rotated: " .. FACING_NAME[rot])
	end
	return false -- BAR should get it as well
end

-- BAR key for the build spacing ("buildspacing inc|dec"): works with an armed building stamp
local function buildSpacingAction(_, _, words)
	if armedUnit or bpGrid.armed then
		setSpacing(Shared.spacingFromWords(spacing, words))
	end
	return false -- BAR should get it as well
end

-- Alt+Z / Alt+X (also with Shift): build spacing when dragging. The BAR build menu (gridmenu_key) eats these keys
-- when a builder is selected; this handler sits in front of it.
local function gridKeyHook(_, _, _, _, isRepeat, release, _, key)
	if release or not (armedUnit or bpGrid.armed) then
		return false
	end
	local alt, ctrl = Spring.GetModKeyState()
	if alt and not ctrl and (key == 122 or key == 120) then
		if not isRepeat then
			setSpacing(Shared.spacingFromKey(spacing, key))
		end
		return true
	end
	return false
end

function widget:Initialize()
	local modOptions = Spring.GetModOptions and Spring.GetModOptions() or {}
	if WG.LevelEditorWidget or modOptions.leveleditor == "1" then
		-- the Level Editor brings the same interface; two of them at the same time get in each other's way. The
		-- BluePrinter removes itself (user widgets load before the Level Editor, so the mod option is the reliable sign)
		widgetHandler:RemoveWidget(widget)
		return
	end
	WG.BluePrinterWidget = widget -- for tests in the game
	if Spring.GetSpectatingState() then
		-- as a spectator the widget is pointless
		widgetHandler:RemoveWidget(widget)
		return
	end
	rescale()
	cfg:load()
	widgetHandler:AddAction("buildfacing", buildFacingAction, nil, "p")
	widgetHandler:AddAction("buildspacing", buildSpacingAction, nil, "p")
	if widgetHandler.actionHandler then
		widgetHandler.actionHandler:AddAction(widget, "gridmenu_key", gridKeyHook, nil, "pR")
	end
	pcall(scanBlueprints)
	for name, fn in pairs(ACTIONS) do
		widgetHandler:AddAction(name, fn, nil, "t")
	end
	Spring.SendCommands("bind Ctrl+Alt+p bp_create")
	Spring.SendCommands("bind Ctrl+Alt+k bp_carpet")
	say(#LIST .. " blueprints. Chat: /bp_menu shows or hides the menu")
end

-- for tests in the game: queue plans without the mouse (a building, or the units of a blueprint { name, dx, dz, rot } as one group)
function widget:DebugAdd(name, x, z, f)
	local ud = UnitDefNames[name]
	return ud and addSingle(ud, x, z, f or 0) or false
end

function widget:DebugAddBlueprint(units, x, z)
	batchCounter = batchCounter + 1
	return addPlan(units, x, z, 0)
end

function widget:DebugMode(mode)
	menuMode = mode
	bpGrid.scroll, uGrid.scroll = 0, 0
end

function widget:DebugSetAuto(on)
	autoBuild = on and true or false
end

function widget:DebugSetQueue(on)
	queueOrder = on and true or false
end

-- for tests in the game: the plans in queue order
function widget:DebugState()
	local mi, ei = Shared.stableIncome()
	local out = { queueOrder = queueOrder, selected = selCount(), ops = #opStack, plans = {}, metalIncome = mi, energyIncome = ei }
	for _, s in ipairs(sites) do
		if not s.done then
			out.plans[#out.plans + 1] = { name = s.name, x = s.x, z = s.z, f = s.f, sel = selected[s] == true, grp = s.grp, claim = s.claim, blocked = (s.blocked or 0) > passNo }
		end
	end
	return out
end

function widget:Shutdown()
	WG.BluePrinterWidget = nil
	widgetHandler:RemoveAction("buildfacing")
	widgetHandler:RemoveAction("buildspacing")
	ghost:stop()
	for name in pairs(ACTIONS) do
		widgetHandler:RemoveAction(name)
	end
	Spring.SendCommands("unbind Ctrl+Alt+p bp_create")
	Spring.SendCommands("unbind Ctrl+Alt+k bp_carpet")
end

function widget:GetConfigData()
	local saved = {}
	for _, s in ipairs(sites) do
		if not s.done then
			saved[#saved + 1] = { s.name, s.x, s.z, s.f }
		end
	end
	return {
		side = side, autoBuild = autoBuild or autoBuildStopped, queueOrder = queueOrder, radius = radius, useCommander = useCommander, menuOpen = menuOpen, rot = rot, panel = panelMover:save(),
		map = Game and Game.mapName, game = Game and Game.gameID, plans = saved,
	}
end

function widget:SetConfigData(data)
	if type(data) ~= "table" then
		return
	end
	side = (data.side == "left") and "left" or "right"
	if data.autoBuild ~= nil then
		autoBuild = data.autoBuild and true or false
	end
	radius = math.max(RADIUS_MIN, math.min(RADIUS_MAX, tonumber(data.radius) or radius))
	if data.queueOrder ~= nil then
		queueOrder = data.queueOrder and true or false
	end
	if data.useCommander ~= nil then
		useCommander = data.useCommander and true or false
	end
	if data.menuOpen ~= nil then
		menuOpen = data.menuOpen and true or false
	end
	rot = tonumber(data.rot) or 0
	panelMover:load(data.panel)
	-- only take over remembered plans of the same match (a reload of the widget or a rejoin), not of an earlier match on the same map
	if type(data.plans) == "table" and data.game and Game and data.game == Game.gameID and data.map == Game.mapName then
		batchCounter = batchCounter + 1
		for _, p in ipairs(data.plans) do
			local ud = UnitDefNames[p[1]]
			if ud then
				local y = Spring.GetGroundHeight(p[2], p[3])
				sites[#sites + 1] = { def = ud.id, name = ud.name, x = p[2], y = y, z = p[3], f = tonumber(p[4]) or 0, batch = batchCounter, tries = 0 }
			end
		end
	end
end
