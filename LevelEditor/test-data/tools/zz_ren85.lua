function widget:GetInfo() return { name = "zz ren85", desc = "test only: the distance of the third person camera", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren85.lua: third person view, a picture of a Pawn (T1), a Bull (T2) and a Juggernaut (T3); lines "[zzren85]" with the camera distance.
local R
local list = { "armpw", "armbull", "corkorg" }
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 3; R.third = true end
	for i, name in ipairs(list) do
		local t0 = 100 + (i - 1) * 140
		if f == t0 then Spring.SendLuaRulesMsg("ren|unit|" .. name) end
		if f == t0 + 100 then
			local u = R.unit
			local cx, cy, cz = Spring.GetCameraPosition()
			local x, y, z = Spring.GetUnitPosition(u)
			Spring.Echo(string.format("[zzren85] %s radius %.0f camera distance %.0f", name, Spring.GetUnitRadius(u), math.sqrt((cx - x) ^ 2 + (cy - y) ^ 2 + (cz - z) ^ 2)))
			Spring.SendCommands("screenshot png")
		end
	end
	if f == 580 then Spring.SendCommands("quitforce") end
end
