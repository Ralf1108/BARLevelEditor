function widget:GetInfo() return { name = "zz ren45", desc = "test only: weapon pictures of plasma, cannon, missile, starburst, salvo and torpedo units", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren45.lua: the player becomes one unit after the other, "renPics" is logged ("[zzren45]"), a picture is taken of the Ambassador (starburst) and the Marauder.
local function log(...) Spring.Echo("[zzren45] " .. table.concat({ ... }, " ")) end
local R
local list = { "armmerl", "armrock", "armstump", "armbull", "corbuzz", "armroy", "corthud", "armmart" }
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f >= 70 and (f - 70) % 40 == 0 then
		local i = (f - 70) / 40 + 1
		if list[i] then Spring.SendLuaRulesMsg("ren|unit|" .. list[i]) end
	end
	if f >= 100 and (f - 100) % 40 == 0 then
		local i = (f - 100) / 40 + 1
		if list[i] and R.unit then
			log(list[i], tostring(Spring.GetUnitRulesParam(R.unit, "renPics")))
			if i == 1 or i == 3 then Spring.SendCommands("screenshot png") end
		end
	end
	if f == 100 + 40 * #list then Spring.SendCommands("quitforce") end
end
