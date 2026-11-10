function widget:GetInfo() return { name = "zz ren20", desc = "test only: Renegade gunship: how steep can it fire down", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren20.lua: turns into the Roughneck (armbrawl), takes off, then looks in the direction it faces with the pitch from -15 to -75 degrees (every 20 frames) with the left button held; logs per step whether the weapon has a target and fired. Lines "[zzren20]".
local function ts(a) return tostring(a) end
local function log(...) Spring.Echo("[zzren20] " .. table.concat({ ... }, " ")) end
local R, lastRf
local function rf() return Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame") or 0 end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbrawl") end
	if f == 150 then R.keys = 1 end
	if f == 185 then R.keys = 0 end
	if f == 230 then R.fire = 1; lastRf = rf() end
	if f >= 230 and f < 230 + 20 * 7 and (f - 230) % 20 == 0 then
		local k = (f - 230) / 20
		R.pitch = -15 - 10 * k
	end
	if f >= 240 and f < 230 + 20 * 7 + 20 and f % 20 == 10 then
		local _, y, _ = Spring.GetUnitPosition(R.unit)
		local tt = Spring.GetUnitWeaponTarget(R.unit, 1)
		local r = rf()
		log("pitch", string.format("%.0f", R.pitch), "height", string.format("%.0f", y), "shot", R.shot and string.format("%s %.0f", R.shot.kind, R.shot.udist or -1) or "-", "target type", ts(tt), "reloadFrame", r, "fired since last", ts(r ~= lastRf))
		lastRf = r
	end
	if f == 400 then R.fire = 0; Spring.SendCommands("quitforce") end
end
