function widget:GetInfo() return { name = "zz aim", desc = "test only: Evolution with and without auto-aim", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest [-NoAim] -Widget zz_aim.lua (one instance): an enemy unit is created 120 Elmo from the own unit (game message
-- evo|test|3, game rule evoTestSpy); the own unit stands still, so only auto-aim can shoot it. Logs fire state and health of the enemy at frame 90 and 450
-- (auto-aim on: it dies or is damaged; off: unchanged), then orders Attack and logs the health again at frame 900. Speed 10. Ends at frame 960.
local function log(...) Spring.Echo("[zzaim] " .. table.concat({ ... }, " ")) end
local function mine() return Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoUnit") end
local function report(f)
	local spy = Spring.GetGameRulesParam("evoTestSpy") or 0
	local hp, max = Spring.GetUnitHealth(spy)
	local fs = select(1, Spring.GetUnitStates(mine() or -1, false))
	log("frame", f, "firestate", tostring(fs), "enemy", tostring(spy), "health", tostring(hp), "of", tostring(max))
end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10") end
	if f == 60 then Spring.SendLuaRulesMsg("evo|test|3") end
	if f == 90 or f == 450 or f == 900 then report(f) end
	if f == 460 then
		local spy = Spring.GetGameRulesParam("evoTestSpy") or 0
		if mine() and spy > 0 then log("ordering Attack"); Spring.GiveOrderToUnit(mine(), CMD.ATTACK, { spy }, 0) end
	end
	if f == 960 then Spring.SendCommands("quitforce") end
end
