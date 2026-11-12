function widget:GetInfo() return { name = "zz ren80", desc = "test only: Renegade jump mode (Q into a unit and out of it)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenJump -Widget zz_ren80.lua: the game starts as the normal game (the commander is not replaced), the test jumps into the commander (the message that the
-- key Q sends over a unit), looks at the state, jumps out, and jumps into a second unit. Lines "[zzren80]".
local function log(...) Spring.Echo("[zzren80] " .. table.concat({ ... }, " ")) end
local R
local function state(tag)
	local u = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit")
	local cs = Spring.GetCameraState()
	log(tag, "R.on", tostring(R and R.on), "renUnit", tostring(u), "camera", tostring(cs and cs.name), "firestate", u and u > 0 and tostring(select(1, Spring.GetUnitStates(u, false))) or "-", "my units", #Spring.GetTeamUnits(Spring.GetMyTeamID()))
end
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	local mine = Spring.GetTeamUnits(Spring.GetMyTeamID())
	if f == 60 then state("start (normal game)") end
	if f == 70 then R.target = mine[1]; Spring.SendLuaRulesMsg("ren|possess|" .. mine[1]) end
	if f == 130 then state("after the jump in") end
	if f == 200 then Spring.SendLuaRulesMsg("ren|release") end
	if f == 260 then state("after the jump out") end
	if f == 280 then Spring.SendLuaRulesMsg("ren|possess|" .. mine[#mine]) end
	if f == 340 then state("second jump in") end
	if f == 360 then Spring.SendLuaRulesMsg("ren|release") end
	if f == 420 then state("second jump out") end
	if f == 430 then Spring.SendCommands("quitforce") end
end
