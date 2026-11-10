function widget:GetInfo() return { name = "zz ren21", desc = "test only: Renegade gunship: height with Space / Ctrl", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren21.lua: turns into the Roughneck (armbrawl), takes off, holds Ctrl (keys 32) for 3 s, then Space (keys 16) for 3 s; logs the height above the ground. Lines "[zzren21]".
local function log(...) Spring.Echo("[zzren21] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbrawl") end
	if f == 150 then R.keys = 1 end
	if f == 200 then R.keys = 32 end
	if f == 290 then R.keys = 16 end
	if f == 380 then R.keys = 0 end
	if f >= 150 and f % 30 == 0 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("f", f, "keys", R.keys, "height above ground", string.format("%.0f", y - Spring.GetGroundHeight(x, z)))
	end
	if f == 450 then Spring.SendCommands("quitforce") end
end
