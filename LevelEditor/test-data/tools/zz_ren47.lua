function widget:GetInfo() return { name = "zz ren47", desc = "test only: the new panel (Juggernaut, Prevailer, a bomber)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren47.lua: the player becomes a Juggernaut, an Ambassador and a Tsunami one after the other, a picture is taken of each.
local list = { "corjugg", "armamb", "corshad" }
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 180, 0; R.debug = true end
	for i, name in ipairs(list) do
		if f == 70 + (i - 1) * 90 then Spring.SendLuaRulesMsg("ren|unit|" .. name) end
		if f == 140 + (i - 1) * 90 then Spring.SendCommands("screenshot png") end
	end
	if f == 140 + 90 * #list then Spring.SendCommands("quitforce") end
end
