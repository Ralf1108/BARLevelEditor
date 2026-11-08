function widget:GetInfo() return { name = "zz cmdbuttons", desc = "test only: the buttons Area / Split / Focus Attack in the command menu", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_cmdbuttons.lua: selects own units, looks for the three custom commands in the command menu of the game, presses each
-- (Spring.SetActiveCommand on an ICON command runs it at once: widget:CommandNotify), checks the mode of the area attack and takes a screenshot of the menu.
-- Logs "[zzar]" lines (OK / FAIL), ends with quitforce.
local lines = {}
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	lines[#lines + 1] = "[zzar] " .. table.concat(t, " ")
end
local function W() return WG.LevelEditorWidget end
local function check(ok, what) log(ok and "OK" or "FAIL", what) end
local function index(id)
	for i, d in ipairs(Spring.GetActiveCmdDescs() or {}) do
		if d.id == id then return i, d end
	end
end
local CMD_BASE = 43020
local steps = {}
steps[40] = function()
end
steps[60] = function()
	for i, name in ipairs({ "Area Attack", "Split Attack", "Focus Attack" }) do
		local idx, d = index(CMD_BASE + i)
		check(idx ~= nil, "command menu has " .. name .. (d and (" (action " .. tostring(d.action) .. ")") or ""))
	end
	Spring.SendCommands("screenshot png")
end
for i, mode in ipairs({ "circle", "split", "focus" }) do
	steps[80 + i * 20] = function()
		local idx = index(CMD_BASE + i)
		if idx then Spring.SetActiveCommand(idx, 1, true, false, false, false, false, false) end
	end
	steps[90 + i * 20] = function()
		local armed, m = W():DebugArea()
		check(armed == true and m == mode, "button " .. i .. " arms the mode " .. mode .. ": " .. tostring(armed) .. " " .. tostring(m))
		W():KeyPress(27, {}, false)
	end
end
-- the gadget registers its AllowCommand only for the three buttons: other orders still pass
local mover
steps[160] = function()
	mover = (Spring.GetSelectedUnits() or {})[1] or (Spring.GetTeamUnits(Spring.GetMyTeamID()) or {})[1]
	if mover then
		local x, y, z = Spring.GetUnitPosition(mover)
		Spring.GiveOrderToUnit(mover, CMD.MOVE, { x + 300, y, z + 300 }, 0)
	end
end
steps[175] = function()
	local cmd = mover and Spring.GetUnitCurrentCommand(mover)
	check(cmd == CMD.MOVE, "a move order passes AllowCommand: " .. tostring(cmd))
end
steps[180] = function()
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
		if not ok then log("TEST ERROR at " .. k .. ": " .. tostring(err)) end
	end
end
