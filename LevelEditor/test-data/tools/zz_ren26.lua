function widget:GetInfo() return { name = "zz ren26", desc = "test only: Renegade gunship flying backward", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren26.lua: the Roughneck (armbrawl) takes off, then S (backward) and A (to the side) are held with the view fixed at yaw 90; logs the way the nose points (direction) and the way it moves (velocity). Lines "[zzren26]".
local function log(...) Spring.Echo("[zzren26] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 270, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbrawl") end
	if f == 150 then R.keys = 16 end
	if f == 190 then R.keys = 4 end -- S
	if f == 310 then R.keys = 2 end -- A
	if f >= 150 and f % 20 == 0 and R.unit then
		local dx, _, dz = Spring.GetUnitDirection(R.unit)
		local vx, _, vz = Spring.GetUnitVelocity(R.unit)
		log("f", f, "keys", R.keys, "nose", string.format("%.2f %.2f", dx, dz), "velocity", string.format("%.1f %.1f", vx, vz), "(view yaw 270 looks along -x)")
	end
	if f == 430 then Spring.SendCommands("quitforce") end
end
