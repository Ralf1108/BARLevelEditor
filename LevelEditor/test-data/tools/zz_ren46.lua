function widget:GetInfo() return { name = "zz ren46", desc = "test only: the AUTO row of the anti-nuke launchers", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren46.lua: the player becomes one anti-nuke unit after the other, "renAuto" and "renPics" are logged ("[zzren46]"), a picture is taken of the first and the third.
local function log(...) Spring.Echo("[zzren46] " .. table.concat({ ... }, " ")) end
local R
local list = { "armamd", "armcarry", "corfmd", "legavantinuke", "armscab", "armmerl" }
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f >= 70 and (f - 70) % 50 == 0 then
		local i = (f - 70) / 50 + 1
		if list[i] then Spring.SendLuaRulesMsg("ren|unit|" .. list[i]) end
	end
	if f >= 120 and (f - 120) % 50 == 0 then
		local i = (f - 120) / 50 + 1
		if list[i] then
			log(list[i], "unit", tostring(R.unit), "auto", tostring(R.unit and Spring.GetUnitRulesParam(R.unit, "renAuto")), "pics", tostring(R.unit and Spring.GetUnitRulesParam(R.unit, "renPics")))
			if i == 1 or i == 3 then Spring.SendCommands("screenshot png") end
		end
	end
	if f == 120 + 50 * #list then Spring.SendCommands("quitforce") end
end
