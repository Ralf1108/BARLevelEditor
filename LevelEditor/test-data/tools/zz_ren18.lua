function widget:GetInfo() return { name = "zz ren18", desc = "test only: Renegade bomber: the bombs fall at once", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren18.lua: turns into the Thunder (armthund), flies forward, holds the left button for 1 s and logs the frames from the press to the first bomb. Lines "[zzren18]".
local function log(...) Spring.Echo("[zzren18] " .. table.concat({ ... }, " ")) end
local R, rf0, pressAt, firstAt
local function rf() return Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame") or 0 end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armthund") end
	if f == 140 then R.keys = 1 end
	if f == 380 then
		local _, y = Spring.GetUnitPosition(R.unit)
		local vx, vy, vz = Spring.GetUnitVelocity(R.unit)
		rf0 = rf(); pressAt = f; R.fire = 1
		log("press at", f, "height", string.format("%.0f", y), "speed", string.format("%.1f", math.sqrt(vx * vx + vz * vz)), "weapon type", WeaponDefs[UnitDefs[Spring.GetUnitDefID(R.unit)].weapons[1].weaponDef].type, "reloadFrame", rf0)
	end
	if f >= 140 and f % 20 == 0 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local vx, vy, vz = Spring.GetUnitVelocity(R.unit)
		local pr = Spring.GetProjectilesInRectangle(x - 600, z - 600, x + 600, z + 600) or {}
		local tt, tg = Spring.GetUnitWeaponTarget(R.unit, 1)
		log("f", f, "y", string.format("%.0f", y), "v", string.format("%.1f %.1f %.1f", vx, vy, vz), "projectiles", #pr, "target type", tostring(tt), tostring(type(tg) == "table" and string.format("%.0f %.0f %.0f", tg[1], tg[2], tg[3]) or tg), "reloadFrame", rf(), "keys", R.keys)
	end
	if pressAt and not firstAt and f > pressAt and rf() ~= rf0 then firstAt = f; log("first bomb after", f - pressAt, "frames") end
	if f == 460 then R.fire = 0; R.keys = 0; log("done; first bomb", tostring(firstAt and (firstAt - pressAt) or "none")); Spring.SendCommands("quitforce") end
end
