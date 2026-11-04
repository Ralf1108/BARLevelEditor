function widget:GetInfo() return { name = "zz cycle", desc = "test only: Ctrl + mouse wheel chooses the blueprint (grid:cycle)", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_cycle.lua: puts three blueprints into the list (in memory only), cycles with grid:cycle (what Ctrl + mouse wheel calls):
-- the first call picks the first (wheel down) or the last (wheel up), then next / previous, round at the ends, the grid is armed; with a search filter only the
-- shown ones count. Logs "[zzar]" lines (OK / FAIL), ends with quitforce.
local lines = {}
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	lines[#lines + 1] = "[zzar] " .. table.concat(t, " ")
end
local function check(ok, what) log(ok and "OK" or "FAIL", what) end
local steps = {}
steps[40] = function()
	local grid, lib = WG.LevelEditorWidget:DebugGrid()
	local saved = lib.list
	lib.list = {
		{ name = "zz_alpha", description = "alpha", items = {} },
		{ name = "zz_beta", description = "beta", items = {} },
		{ name = "zz_gamma", description = "gamma", items = {} },
	}
	grid.selected, grid.query = 0, ""
	grid:setArmed(false)
	local function name() return lib.list[grid.selected] and lib.list[grid.selected].name end
	check(grid:cycle(nil, false) and name() == "zz_alpha", "wheel down from nothing: the first, " .. tostring(name()))
	check(grid.armed == true, "the blueprint is armed")
	grid:cycle(nil, false)
	check(name() == "zz_beta", "wheel down: the next, " .. tostring(name()))
	grid:cycle(nil, false)
	grid:cycle(nil, false)
	check(name() == "zz_alpha", "wheel down at the end goes round to the first, " .. tostring(name()))
	grid:cycle(nil, true)
	check(name() == "zz_gamma", "wheel up at the start goes round to the last, " .. tostring(name()))
	grid.selected = 0
	grid:cycle(nil, true)
	check(name() == "zz_gamma", "wheel up from nothing: the last, " .. tostring(name()))
	grid.query = "beta"
	grid:cycle(nil, false)
	check(name() == "zz_beta", "with the search 'beta' only that one counts, " .. tostring(name()))
	grid.query = ""
	grid:setArmed(false)
	lib.list = saved
	grid.selected = 1
	log("DONE")
	for _, l in ipairs(lines) do Spring.Echo(l) end
	Spring.SendCommands("quitforce")
end
local keys = {}
for k in pairs(steps) do keys[#keys + 1] = k end
table.sort(keys)
local nextKey = 1
function widget:Update()
	local k = keys[nextKey]
	if k and k <= Spring.GetGameFrame() then
		nextKey = nextKey + 1
		local ok, err = pcall(steps[k])
		if not ok then log("TEST ERROR at " .. k .. ": " .. tostring(err)); for _, l in ipairs(lines) do Spring.Echo(l) end; Spring.SendCommands("quitforce") end
	end
end
