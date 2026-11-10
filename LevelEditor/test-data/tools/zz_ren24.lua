function widget:GetInfo() return { name = "zz ren24", desc = "test only: Renegade gunship attack state while firing", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren24.lua: the Roughneck hovers, the view points 35 degrees down toward the ground ahead; the left button is held for 3 s. Logs the body pitch (direction y), the weapon target, the position and whether it fired. Lines "[zzren24]".
local function ts(a) return tostring(a) end
local function log(...) Spring.Echo("[zzren24] " .. table.concat({ ... }, " ")) end
local R, rf0
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbrawl") end
	if f == 150 then R.keys = 1 end
	if f == 200 then R.keys = 0 end
	if f == 240 then R.pitch = -35; rf0 = Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame") end
	if f == 260 then R.fire = 1 end
	if f >= 240 and f <= 480 and f % 20 == 0 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local dy = select(2, Spring.GetUnitDirection(R.unit))
		local tt = Spring.GetUnitWeaponTarget(R.unit, 1)
		local cmd = Spring.GetUnitCommands(R.unit, 1)
		log("f", f, "fire", R.fire, "height", string.format("%.0f", y - Spring.GetGroundHeight(x, z)), "body direction y", string.format("%.2f", dy), "weapon target type", ts(tt), "first command", ts(cmd and cmd[1] and cmd[1].id), "reloadFrame", Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame"), "shot", R.shot and string.format("%s %.0f", R.shot.kind, R.shot.udist or -1) or "-")
	end
	if f == 380 then R.fire = 0 end
	if f == 500 then Spring.SendCommands("quitforce") end
end
