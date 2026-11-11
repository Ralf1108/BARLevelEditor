function widget:GetInfo() return { name = "zz ren50", desc = "test only: the turret angle of the Mauser (armmart)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren50.lua: the player becomes a Mauser, looks along its nose and then behind it; "coneOut" and the screenshots show the hint "TURN THE VEHICLE".
local function log(...) Spring.Echo("[zzren50] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|armmart") end
	if f == 130 or f == 190 then
		if f == 190 then R.yaw = (R.yaw + 180) % 360 end
		log("f", f, "yaw", tostring(R.yaw), "coneOut", tostring(R.coneOut))
	end
	if f == 150 or f == 210 then
		log("f", f, "yaw", tostring(R.yaw), "coneOut", tostring(R.coneOut))
		Spring.SendCommands("screenshot png")
	end
	if f == 220 then Spring.SendCommands("quitforce") end
end
