function widget:GetInfo() return { name = "zz ren89", desc = "test only: a hurt unit reclaims wrecks and heals (green plus signs and +N)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren89.lua: frame 100 the unit is hurt to 30 % and wrecks appear ahead (ren|test|6); logs the health each 30 frames, screenshots at 150 and 160.
local R
function widget:GameFrame(f)
	R = WG.renegade
	if not R or not R.unit then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 155 then R.third = true end
	if f == 100 then Spring.SendLuaRulesMsg("ren|test|6") end
	if f >= 100 and f % 30 == 0 then Spring.Echo(string.format("[zzren89] f %d health %.0f", f, (Spring.GetUnitHealth(R.unit)) or -1)) end
	if f == 152 or f == 162 then Spring.SendCommands("screenshot png") end
	if f == 300 then Spring.SendCommands("quitforce") end
end
