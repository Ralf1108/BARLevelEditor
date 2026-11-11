function widget:GetInfo() return { name = "zz ren62", desc = "test only: a click on a weapon that is still reloading for more than a second is forgotten", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren62.lua: a Behemoth, its D-gun (right button, reload 4 s): (A) a click with about 3 s of reload left must not fire later, (B) a click with
-- less than a second left fires when the reload is over. "[zzren62]" logs the reload frame of the D-gun (1000000 = held and not fired again).
local function log(...) Spring.Echo("[zzren62] " .. table.concat({ ... }, " ")) end
local function rf(R) return R.unit and Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame") or 0 end
function widget:GameFrame(f)
	local R = WG.renegade
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 90, -12 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|corjugg") end
	if f == 120 then R.fire = 2 end
	if f == 124 then R.fire = 0; log("first shot: reloadFrame", tostring(rf(R)), "at frame", f) end
	if f == 150 then R.fire = 2 end    -- A: about 3 s of reload left
	if f == 153 then R.fire = 0 end
	if f == 290 then log("A (must be held, not fired again): reloadFrame", tostring(rf(R))) end
	if f == 300 then R.fire = 2 end   -- a new shot
	if f == 304 then R.fire = 0; log("second shot: reloadFrame", tostring(rf(R)), "at frame", f) end
	local r2 = tonumber(rf(R)) or 0
	if f > 310 and f < 600 and not R.bDone and r2 - f < 20 and r2 > f then R.fire = 2; R.bAt = f; R.bDone = true; log("B press at", f, "reloadFrame", r2) end
	if R.bAt and f == R.bAt + 3 then R.fire = 0 end
	if R.bAt and f == R.bAt + 60 then log("B (must have fired again): reloadFrame", tostring(rf(R)), "frame", f); Spring.SendCommands("quitforce") end
	if f == 700 then Spring.SendCommands("quitforce") end
end
