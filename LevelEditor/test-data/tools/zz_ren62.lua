function widget:GetInfo() return { name = "zz ren62", desc = "test only: a weapon fires only when it is loaded and the button is down", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren62.lua: a Behemoth, its D-gun (right button, reload 4 s), aimed at the ground: shot 1 (a short click on a loaded weapon fires); then (A) a click with about 3 s of
-- reload left and (B) a click with a few frames of reload left must not fire later on their own; (C) the button held through the end of the reload fires, (D) a short click on the loaded weapon fires. "[zzren62]" logs the reload frame.
local function log(...) Spring.Echo("[zzren62] " .. table.concat({ ... }, " ")) end
local function rf(R) return R.unit and Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame") or 0 end
local ready1
function widget:GameFrame(f)
	local R = WG.renegade
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 90, -12 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|corjugg") end
	if f == 120 then R.fire = 2 end
	if f == 123 then R.fire = 0; log("1 short click on the loaded weapon: reloadFrame", tostring(rf(R)), "frame", f) end
	if f == 150 then R.fire = 2 end
	if f == 153 then R.fire = 0 end
	if f == 200 then log("A (a click with 3 s left: held, not fired): reloadFrame", tostring(rf(R))) end
	local r = tonumber(rf(R)) or 0
	if f > 200 and f < 400 and not R.b and r > f and r < 500000 and r - f < 10 then R.b = f; R.fire = 2 end
	if R.b and f == R.b + 3 then R.fire = 0 end
	if R.b and f == R.b + 40 then log("B (a click with a few frames left: held, not fired): reloadFrame", tostring(rf(R)), "frame", f) end
	if R.b and f == R.b + 50 then R.fire = 2 end -- C: held from now on, the weapon is loaded and fires at once
	if R.b and f == R.b + 70 then log("C (held: fired): reloadFrame", tostring(rf(R)), "frame", f); R.fire = 0 end
	if R.b and f == R.b + 120 then R.fire = 2 end
	if R.b and f == R.b + 123 then R.fire = 0 end
	if R.b and f == R.b + 150 then log("D (short click: fired again): reloadFrame", tostring(rf(R)), "frame", f); Spring.SendCommands("quitforce") end
	if f == 900 then Spring.SendCommands("quitforce") end
end
