function widget:GetInfo() return { name = "zz ren74", desc = "test only: Renegade bomber ceiling and the bomb sight colour", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren74.lua: the player becomes a Stormbringer (armthund, attack altitude 165), climbs (W and Space held) and logs the height above
-- the ground, the attack altitude and the state of the bomb sight (green / yellow / red); screenshots at about the attack altitude and at the ceiling. Lines "[zzren74]".
local function log(...) Spring.Echo("[zzren74] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 0, 10 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armthund") end
	if f == 140 then R.keys = 1 + 16 end
	if f >= 140 and f % 20 == 0 and f <= 1000 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local h = y - Spring.GetGroundHeight(x, z)
		local at = tonumber(Spring.GetUnitRulesParam(R.unit, "renAttackAlt"))
		local st = at and (h <= at and "green" or (h <= at * 1.15 and "yellow" or "red")) or "none"
		log("f", f, "above ground", string.format("%.0f", h), "attack", tostring(at), "sight", st)
		if st == "green" and not R.s1 and f > 300 then R.s1 = true; Spring.SendCommands("screenshot") end
		if st == "red" and not R.s2 and f > 300 then R.s2 = true; Spring.SendCommands("screenshot") end
	end
	if f == 700 then Spring.SendCommands("screenshot") end
	if f == 1020 then Spring.SendCommands("quitforce") end
end
