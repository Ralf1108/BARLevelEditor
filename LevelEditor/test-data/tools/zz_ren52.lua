function widget:GetInfo() return { name = "zz ren52", desc = "test only: the Mauser fires at the sky (arc weapons)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren52.lua: the player becomes a Mauser (armmart), looks at the sky (pitch up) and fires; logs R.hit, R.skyShot and the reload frame of its weapon ("[zzren52]"), takes a picture.
local UNIT = "armmart" -- (armmart: the Mauser)
local function log(...) Spring.Echo("[zzren52] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|" .. UNIT) end
	if f == 90 then R.pitch = 12 end
	if f == 100 then log("ground pitch", tostring(R.pitch), "hit", tostring(R.hit and R.hit.kind), "udist", tostring(R.hit and math.floor(R.hit.udist)), "sky", tostring(R.skyShot)); Spring.SendCommands("screenshot png") end
	if f == 110 then R.pitch = 12 end -- (positive looks up)
	if f == 125 then log("pitch", tostring(R.pitch), "hit", tostring(R.hit and R.hit.kind), "sky", tostring(R.skyShot and string.format("%d,%d d=%d", R.skyShot.x, R.skyShot.z, R.skyShot.udist)), "coneOut", tostring(R.coneOut)); end
	if f == 140 then log("pitch", tostring(R.pitch), "hit", tostring(R.hit and R.hit.kind), "sky", tostring(R.skyShot and string.format("%d,%d d=%d", R.skyShot.x, R.skyShot.z, R.skyShot.udist)), "coneOut", tostring(R.coneOut)); R.fire = 1 end
	if f == 142 then local u = R.unit; log("reloadFrame", tostring(Spring.GetUnitWeaponState(u, 1, "reloadFrame")), "frame", f) end
	if f >= 143 and f <= 200 and f % 6 == 0 then
		for _, id in ipairs(Spring.GetVisibleProjectiles(-1, true, false, true) or {}) do local x, y, z = Spring.GetProjectilePosition(id); log("proj", f, math.floor(x or 0), math.floor(y or 0), math.floor(z or 0)) end
	end
	if f == 150 then Spring.SendCommands("screenshot png") end
	if f == 160 then R.fire = 0; log("reloadFrame", tostring(Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame")), "frame", f) end
	if f == 205 then Spring.SendCommands("quitforce") end
end
