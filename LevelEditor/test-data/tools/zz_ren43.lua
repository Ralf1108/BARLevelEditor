function widget:GetInfo() return { name = "zz ren43", desc = "test only: picture of a weapon in the panel", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren43.lua: the player becomes a Titan (armbanth, the lasers have a picture), after 3 s a picture of the screen is taken (screenshot png). Lines "[zzren43]".
local function log(...) Spring.Echo("[zzren43] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbanth") end
	if f == 180 and R.unit then
		log("renPics", tostring(Spring.GetUnitRulesParam(R.unit, "renPics")), "file", tostring(VFS.FileExists("LuaUI/Images/renegade/weapons/weapon_laser-heavy.png")))
		Spring.SendCommands("screenshot png")
	end
	if f == 210 then Spring.SendCommands("quitforce") end
end
