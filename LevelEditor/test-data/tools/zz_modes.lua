function widget:GetInfo() return { name = "zz modes", desc = "test only: Tower Defense, Capture the Flag and Reclaim the Fame with the alliances of page T", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_modes.lua: loads the test levels td_test, ctf_test and rtf_test, puts the two teams into one alliance (or
-- not), starts every game mode and logs "[zzar]" lines (state, scores, the Tower Defense payload). One step per game frame number; ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local tm, saveLevel, loadLevel, td
local function ok(cond) return cond and "OK" or "WRONG" end

local steps = {}
steps[40] = function()
	tm, saveLevel, loadLevel, td = W():DebugTeams()
	loadLevel(nil, nil, { "ctf_test" })
	log("load ctf_test")
end
-- ---------------------------------------------------------------- Capture the Flag, both teams in one alliance
steps[300] = function()
	tm.setGroup(0, 3)
	tm.setGroup(1, 3)
	W():DebugCtf().toggle()
	log("ctf started")
end
-- a reclaim order on a flag is refused (AllowCommand of ctf_game.lua, registered for RECLAIM, CAPTURE, LOAD_UNITS, SELFD only)
local reclaimer
steps[360] = function()
	local flag = tonumber(tostring(Spring.GetGameRulesParam("ctfFlagIds") or ""):match("^(%d+):"))
	for _, id in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}) do
		local ud = UnitDefs[Spring.GetUnitDefID(id)]
		if ud and ud.canReclaim and id ~= flag then reclaimer = id break end
	end
	log("reclaim a flag: flag", tostring(flag), "unit", tostring(reclaimer))
	if flag and reclaimer then Spring.GiveOrderToUnit(reclaimer, CMD.RECLAIM, { flag }, 0) end
end
steps[390] = function()
	local cmd = reclaimer and Spring.GetUnitCurrentCommand(reclaimer)
	log("reclaim order on a flag refused:", tostring(cmd), ok(reclaimer ~= nil and cmd ~= CMD.RECLAIM))
end
steps[420] = function()
	log("ctfState:", tostring(Spring.GetGameRulesParam("ctfState")), "alliances:", tostring(Spring.GetGameRulesParam("ctfTeams")),
		ok(Spring.GetGameRulesParam("ctfState") == "running" and tostring(Spring.GetGameRulesParam("ctfTeams")) == "103"))
	W():DebugCtf().toggle() -- stop
end
-- ---------------------------------------------------------------- Reclaim the Fame, two enemy teams
steps[560] = function()
	loadLevel(nil, nil, { "rtf_test" })
	log("load rtf_test")
end
steps[800] = function()
	tm.setGroup(0, 0)
	tm.setGroup(1, 0)
	W():DebugRtf().toggle()
	log("rtf started")
end
steps[920] = function()
	log("rtfState:", tostring(Spring.GetGameRulesParam("rtfState")), "score keys:", tostring(Spring.GetGameRulesParam("rtfScore0")), tostring(Spring.GetGameRulesParam("rtfScore1")),
		ok(Spring.GetGameRulesParam("rtfState") == "running" and Spring.GetGameRulesParam("rtfScore0") ~= nil and Spring.GetGameRulesParam("rtfScore1") ~= nil and Spring.GetGameRulesParam("rtfScore2") == nil))
	W():DebugRtf().toggle() -- stop
end
-- ---------------------------------------------------------------- Tower Defense: team 0 human, team 1 AI (the spawner), team 2 a second human in the alliance of team 0
steps[1060] = function()
	loadLevel(nil, nil, { "td_test" })
	log("load td_test")
end
steps[1300] = function()
	tm.setGroup(0, 2)
	tm.setGroup(2, 2)
	tm.data[3].ai = "" -- team 2 is a human
	local payload, err = td.payload()
	log("td payload begins:", payload and payload:sub(1, 12) or tostring(err), "(enemy;player)", ok(payload and payload:match("^1;0;") ~= nil))
	td.toggle()
	log("td started")
end
-- build orders while Tower Defense runs (AllowCommand of td_waves.lua, registered for build orders only): a factory is refused, a tower passes
local builder
local function builderOrder(name)
	local x, y, z = Spring.GetUnitPosition(builder)
	Spring.GiveOrderToUnit(builder, -UnitDefNames[name].id, { x - 300, y, z, 0 }, 0)
end
steps[1330] = function()
	Spring.SendLuaRulesMsg("led|place|armck|" .. Spring.GetMyTeamID() .. "|7500|5700|0")
end
steps[1360] = function()
	for _, id in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}) do
		if UnitDefs[Spring.GetUnitDefID(id)].name == "armck" then builder = id end
	end
	log("builder placed:", tostring(builder), ok(builder ~= nil))
	if builder then builderOrder("armlab") end
end
steps[1375] = function()
	local cmd = builder and Spring.GetUnitCurrentCommand(builder)
	log("factory refused:", tostring(cmd), ok(builder ~= nil and cmd ~= -UnitDefNames.armlab.id))
	if builder then builderOrder("armllt") end
end
steps[1390] = function()
	local cmd = builder and Spring.GetUnitCurrentCommand(builder)
	log("tower passes:", tostring(cmd), ok(builder ~= nil and cmd == -UnitDefNames.armllt.id))
end
steps[1420] = function()
	log("tdState:", tostring(Spring.GetGameRulesParam("tdState")), ok(Spring.GetGameRulesParam("tdState") == "running"))
	td.toggle() -- stop
end
steps[1560] = function()
	log("END")
	Spring.SendCommands("quitforce")
end

local done = {}
function widget:Update()
	local f0 = Spring.GetGameFrame()
	local keys = {}
	for k in pairs(steps) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		if k <= f0 and not done[k] then
			done[k] = true
			local ok2, err = pcall(steps[k])
			if not ok2 then log("TEST ERROR at", k, tostring(err)) end
			break
		end
	end
end
