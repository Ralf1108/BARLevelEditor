function widget:GetInfo() return { name = "zz ren77", desc = "test only: Laser Tiger fires at the ground out of range", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren77.lua: the player becomes a Laser Tiger (corgatreap, ground-only beam laser, range 620), looks along +x at a point on the
-- ground about 900 Elmo away (out of range, "red"), holds the left button and logs what the crosshair hits, its colour, and the "SetUnitTarget refused" lines of the gadget; then at 400
-- (in range, green). Lines "[zzren77]".
local function log(...) Spring.Echo("[zzren77] " .. table.concat({ ... }, " ")) end
local R
local function aimAt(dist)
	local ux, uy, uz = Spring.GetUnitPosition(R.unit)
	local eye = uy + Spring.GetUnitHeight(R.unit) * 0.85
	local tx, tz = ux + dist, uz
	R.yaw = 90
	R.pitch = math.deg(math.atan2(Spring.GetGroundHeight(tx, tz) - eye, dist))
end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|corgatreap") end
	if f >= 120 and f < 480 and R.unit then
		-- the pitch is searched: out of range (a ground point 800 - 1500 away) for frames 120 - 300, in range (300 - 500) after that
		local lo, hi = 800, 1500
		if f >= 300 then lo, hi = 300, 500 end
		R.yaw = 90
		local d = R.hit and R.hit.kind == "ground" and R.hit.udist or nil
		if not d or d < lo then R.pitch = math.min(60, R.pitch + 0.15) elseif d > hi then R.pitch = math.max(-60, R.pitch - 0.15) end
		R.fire = f >= 140 and 1 or 0
	end
	if f >= 120 and f % 30 == 0 and f < 500 and R.hit then
		local rf = Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame")
		log("f", f, "hit", R.hit.kind, "dist", string.format("%.0f", R.hit.udist), "colour", tostring(R.best), "reloadFrame", tostring(rf), "pitch", string.format("%.1f", R.pitch))
	end
	if f >= 120 and f % 15 == 0 and f < 480 and R.hit and R.unit then
		-- the point the gadget aims at (shortened to the range along the line to the hit) and the same point put on the ground: does the weapon accept them?
		local ux, uy, uz = Spring.GetUnitPosition(R.unit, true)
		local h = R.hit
		local dx, dy, dz = h.x - ux, h.y - uy, h.z - uz
		local d = math.sqrt(dx * dx + dy * dy + dz * dz)
		local r = 620 - 8
		local k = d > r and r / d or 1
		local x, y, z = ux + dx * k, uy + dy * k, uz + dz * k
		local g = Spring.GetGroundHeight(x, z)
		local a1 = Spring.GetUnitWeaponTestTarget and Spring.GetUnitWeaponTestTarget(R.unit, 1, x, y, z)
		local a2 = Spring.GetUnitWeaponTestTarget and Spring.GetUnitWeaponTestTarget(R.unit, 1, x, g, z)
		local l1 = Spring.GetUnitWeaponHaveFreeLineOfFire and Spring.GetUnitWeaponHaveFreeLineOfFire(R.unit, 1, x, y, z)
		local l2 = Spring.GetUnitWeaponHaveFreeLineOfFire and Spring.GetUnitWeaponHaveFreeLineOfFire(R.unit, 1, x, g, z)
		log("f", f, "hit dist", string.format("%.0f", d), "point height over ground", string.format("%.0f", y - g), "accepted mid-air", tostring(a1), "line free", tostring(l1), "accepted on ground", tostring(a2), "line free", tostring(l2))
	end
	if f == 500 then Spring.SendCommands("quitforce") end
end
