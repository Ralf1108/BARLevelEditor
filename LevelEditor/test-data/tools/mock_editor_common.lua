-- Mock test of parts of shared/editor_common.lua outside the game (run by mock_test.py with Lua 5.1): the rows and rectangles dragged with Shift (Shift+Alt),
-- the footprint of a unit and the undo history of the points of a page. Everything of the Spring API that loading the file needs is a dummy.
-- REPO (set by mock_test.py): the folder of the repository. check(cond, text), ok(text): see mock_test.py.

local function dummy() return setmetatable({}, { __index = function() return function() end end }) end
local alt = false
local rules = {}
local sent = {}
Spring = setmetatable({
	GetModKeyState = function() return alt, false, false, false end,
	GetGameRulesParam = function(k) return rules[k] end,
	GetConfigFloat = function(_, d) return d end,
	GetConfigInt = function(_, d) return d end,
	GetViewGeometry = function() return 1920, 1080 end,
}, { __index = function() return function() end end })
VFS = { ZIP_FIRST = 1, Include = function(path) return dofile(REPO .. "/shared/" .. path:match("([^/]+)$")) end, LoadFile = function() return nil end }
gl, GL, CMD, CMDTYPE = dummy(), dummy(), dummy(), dummy()
UnitDefs, UnitDefNames, FeatureDefs, FeatureDefNames, WeaponDefs = {}, {}, {}, {}, {}
Game = { armorTypes = {}, mapSizeX = 8192, mapSizeZ = 8192 }
WG, widgetHandler = {}, dummy()

local M = dofile(REPO .. "/shared/editor_common.lua")

-- ---------------------------------------------------------------- the footprint of a unit
do
	local ud = { xsize = 4, zsize = 6 }
	local fx, fz = M.unitFootprint(ud, 0)
	check(fx == 32 and fz == 48, "footprint facing south: 32 x 48 (" .. fx .. " x " .. fz .. ")")
	fx, fz = M.unitFootprint(ud, 1)
	check(fx == 48 and fz == 32, "footprint facing east: swapped (" .. fx .. " x " .. fz .. ")")
	fx, fz = M.unitFootprint({}, 2)
	check(fx == 32 and fz == 32, "footprint without sizes: 32 x 32")
	ok("unitFootprint")
end

-- ---------------------------------------------------------------- a row (Shift) and a rectangle (Shift+Alt)
do
	alt = false
	local pts = M.dragStamp(32, 32, 100, 100, 300, 100, 0, 2000)
	check(#pts == 7, "row of 200 Elmo with 32 Elmo pieces: 7 positions (" .. #pts .. ")")
	check(pts[1].x == 100 and pts[2].x == 132 and pts[7].x == 292, "row: steps of the footprint")
	pts = M.dragStamp(32, 32, 100, 100, 300, 100, 2, 2000)
	check(#pts == 4 and pts[2].x == 164, "row with spacing 2: steps of 32 + 32 Elmo (" .. #pts .. ")")
	alt = true
	pts = M.dragStamp(32, 32, 100, 100, 200, 200, 0, 2000)
	check(#pts == 16, "rectangle 100 x 100 with 32 Elmo pieces: 4 x 4 (" .. #pts .. ")")
	pts = M.dragStamp(32, 32, 100, 100, 1000, 1000, 0, 100)
	check(#pts <= 100, "rectangle limited to maxN (" .. #pts .. ")")
	pts = M.dragStamp(32, 32, 100, 100, 50, 50, 0, 2000)
	check(pts[2].x == 68, "rectangle dragged to the upper left goes that way")
	alt = false
	pts = M.dragStamp(20, 20, 0, 0, 50, 0, 0, 2000, function(v) return math.floor(v / 16 + 0.5) * 16 end)
	check(pts[2].x == 16 and pts[3].x == 48, "row snapped to the grid of 16 (" .. pts[2].x .. ", " .. pts[3].x .. ")")
	ok("dragStamp")
end

-- ---------------------------------------------------------------- the undo history of the points of a page
do
	local state = "a"
	local steps, applied = 0, nil
	local h = M.newPointHistory({ tag = "pts", state = function() return state end, apply = function(s) applied = s end, default = "-",
		step = function() steps = steps + 1 end, led = function(msg) sent[#sent + 1] = msg end })
	h.commit("a")
	check(steps == 0 and #sent == 0, "commit without a change: no step")
	state = "b"
	h.commit("a")
	check(steps == 1 and sent[1] == "led|pts|a|b", "commit of a change: one step and the message (" .. tostring(sent[1]) .. ")")
	state = "c"
	h.note("b")
	check(steps == 1 and sent[2] == "led|pts|b|c", "note: the message in the open step")
	h.poll()
	check(applied == nil, "poll: the first call only remembers the counter")
	rules.led_pts_n, rules.led_pts = 1, "x"
	h.poll()
	check(applied == "x", "poll after an undo: the state of the gadget is taken over (" .. tostring(applied) .. ")")
	applied = nil
	h.poll()
	check(applied == nil, "poll without a new undo: nothing")
	ok("newPointHistory")
end
