function widget:GetInfo() return { name = "zz ren27", desc = "test only: Renegade aircraft takes off once and never lands by itself", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren27.lua: the Roughneck (armbrawl) stands on the ground; W for 0.7 s; then nothing for 12 s. Logs the height: it must rise to 400 once and stay there (no landing, no climbing on). Lines "[zzren27]".
local function log(...) Spring.Echo("[zzren27] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 270, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbrawl") end
	if f == 140 then R.keys = 1 end
	if f == 160 then R.keys = 0 end
	if f >= 120 and f % 30 == 0 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("f", f, "keys", R.keys, "height", string.format("%.0f", y - Spring.GetGroundHeight(x, z)))
	end
	if f == 640 then Spring.SendCommands("quitforce") end
end
