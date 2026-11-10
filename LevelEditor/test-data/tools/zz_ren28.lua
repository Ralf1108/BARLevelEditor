function widget:GetInfo() return { name = "zz ren28", desc = "test only: Renegade aircraft lands when the lower key is held at the bottom", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren28.lua: the Roughneck takes off (W), then Ctrl (keys 32) is held until it is down and 2 s more: it must land; then W again: it must take off again. Lines "[zzren28]".
local function log(...) Spring.Echo("[zzren28] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 270, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbrawl") end
	if f == 140 then R.keys = 1 end
	if f == 160 then R.keys = 0 end
	if f == 330 then R.keys = 32 end
	if f == 700 then R.keys = 0 end
	if f == 780 then R.keys = 1 end
	if f == 800 then R.keys = 0 end
	if f >= 120 and f % 30 == 0 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("f", f, "keys", R.keys, "height", string.format("%.0f", y - Spring.GetGroundHeight(x, z)))
	end
	if f == 1000 then Spring.SendCommands("quitforce") end
end
