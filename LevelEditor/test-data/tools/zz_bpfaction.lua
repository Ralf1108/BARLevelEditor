function widget:GetInfo() return { name = "zz bpfaction", desc = "test only: BluePrinter turns a blueprint into the faction of the builders", layer = 1000000, enabled = true } end
-- Test widget of bp_test.ps1 -Widget zz_bpfaction.lua (player and commander of Cortex): queues a blueprint of Armada buildings with the faction switch
-- on and off and looks at the names of the plans. Logs "[zzar]" lines (OK / FAIL), ends with quitforce.
local lines = {}
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	lines[#lines + 1] = "[zzar] " .. table.concat(t, " ")
end
local function check(ok, what) log(ok and "OK" or "FAIL", what) end
local function W() return WG.BluePrinterWidget end
local function names()
	local out = {}
	for _, p in ipairs(W():DebugState().plans) do out[#out + 1] = p.name end
	table.sort(out)
	return table.concat(out, ",")
end
local steps = {}
local bx, bz
steps[60] = function()
	local own = Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}
	local x, _, z = Spring.GetUnitPosition(own[1])
	bx, bz = x + 250, z + 250
	log("commander", UnitDefs[Spring.GetUnitDefID(own[1])].name)
	Spring.SelectUnitArray({ own[1] })
end
steps[90] = function()
	W():DebugSetAdapt(true)
	W():DebugAddBlueprint({
		{ name = "armsolar", dx = 0, dz = 0, rot = 0 },
		{ name = "armwin", dx = 160, dz = 0, rot = 0 },
		{ name = "armmex", dx = 320, dz = 0, rot = 0 },
		{ name = "corsolar", dx = 0, dz = 160, rot = 0 },
	}, bx, bz)
	local s = names()
	log("plans with the switch ON: " .. s)
	check(not s:find("arm", 1, true), "no Armada building is left in the queue")
	check(s:find("corsolar", 1, true) and s:find("corwin", 1, true), "armsolar and armwin became corsolar and corwin")
end
steps[120] = function()
	W():DebugSetAdapt(false)
	W():DebugAddBlueprint({ { name = "armsolar", dx = 0, dz = 640, rot = 0 } }, bx, bz)
	check(names():find("armsolar", 1, true) ~= nil, "with the switch OFF the blueprint stays as it is: " .. names())
	W():DebugSetAdapt(true)
end
steps[150] = function()
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
