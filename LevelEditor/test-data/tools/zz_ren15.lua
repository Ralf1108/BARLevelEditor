function widget:GetInfo() return { name = "zz ren15", desc = "test only: Renegade the turret follows the view without firing, facing arrow", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren15.lua: the view turns round without a button: the barrel direction (GetUnitWeaponVectors) follows it, the weapon
-- does not fire (its reloadFrame is held); then a click: the weapon fires (reloadFrame normal). A picture shows the green arrow and the barrel line. Lines "[zzren15]".
local function log(...) Spring.Echo("[zzren15] " .. table.concat({ ... }, " ")) end
local R
local function dir() local v = { Spring.GetUnitWeaponVectors(R.unit, 1) } return string.format("%.2f %.2f %.2f", v[4] or 0, v[5] or 0, v[6] or 0) end
local function rf() return Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame") or 0 end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, -5 end
	if f == 120 then log("looking at yaw 180: barrel", dir(), "reloadFrame", rf(), "unit facing", string.format("%.2f %.2f", select(1, Spring.GetUnitDirection(R.unit)), select(3, Spring.GetUnitDirection(R.unit)))) end
	if f == 130 then R.yaw = 90 end
	if f == 170 then log("looking at yaw 90 (+x): barrel", dir(), "reloadFrame", rf()) end
	if f == 180 then R.yaw = 180 end
	if f == 220 then log("looking at yaw 180 again: barrel", dir(), "reloadFrame", rf())end
	if f == 230 then R.fire = 1 end
	if f == 236 then log("fire", tostring(R.fire), "sent", tostring(R.sent), "menu", tostring(R.menu), "on", tostring(R.on)) end
	if f == 242 then R.fire = 0 end
	if f == 280 or f == 330 or f == 380 then log("after the click: frame", f, "reloadFrame", rf(), "barrel", dir()) end
	if f == 390 then R.yaw, R.pitch = 0, -25 end
	if f == 410 then Spring.SendCommands("screenshot png") end
	if f == 450 then log("later: reloadFrame", rf(), "(1000000 = held again)") end
	if f == 470 then Spring.SendCommands("quitforce") end
end
