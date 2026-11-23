function widget:GetInfo() return { name = "zz ren11", desc = "test only: Renegade ground and air weapons of the Titan (starburst on the middle button, laser on the right one): lock at aircraft, aim at the ground", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren11.lua: turns into an anti-air turret (armbanth), an enemy gunship hovers ahead; the crosshair points a few degrees beside it
-- (inside the orange circle): the lock, then fire with the middle button (weapon 3); a second gunship for the right button (weapon 2): the laser gets the aircraft as its
-- target and the aircraft loses health (the starburst takes the point where the aircraft is: the engine refuses the unit); then the view turns away: no lock, the weapons take the ground. OK / WRONG lines "[zzren11]" (zz_ren13.lua is part of it).
local function log(...) Spring.Echo("[zzren11] " .. table.concat({ ... }, " ")) end
local R
local function ok(c) return c and "OK" or "WRONG" end
-- one gunship for one button: it appears at frame s (ren|test|3), the view goes 3 degrees beside it, the lock is checked at s + 280, then the button is
-- held for 40 frames: the weapon must take the aircraft as its target at some frame, the aircraft must lose health. point = true (the starburst: the
-- engine refuses an aircraft as its target): the weapon must take the point where the aircraft is (at most 150 away), the health is only logged
local ROUNDS = { { s = 140, button = 4, weapon = 3, name = "middle button (starburst)", point = true }, { s = 500, button = 2, weapon = 2, name = "right button (laser)" } }
local END = 840 -- the view turns away from here on
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbanth") end
	if f == 135 then log("unit", UnitDefs[Spring.GetUnitDefID(R.unit)].name, "slots", tostring(Spring.GetUnitRulesParam(R.unit, "renSlots")), "aa", tostring(Spring.GetUnitRulesParam(R.unit, "renAA"))) end
	for _, r in ipairs(ROUNDS) do
		if f == r.s then R.yaw, R.pitch = 90, 0; Spring.SendLuaRulesMsg("ren|test|3") end
		if f == r.s + 40 then
			for _, id in ipairs(Spring.GetTeamUnits(1)) do
				if UnitDefs[Spring.GetUnitDefID(id)].canFly and not Spring.GetUnitIsDead(id) and (Spring.GetUnitHealth(id) or 0) > 0 then r.plane = id end
			end
			log(r.name, "gunship", tostring(r.plane), "health", r.plane and string.format("%.0f", (Spring.GetUnitHealth(r.plane))) or "?")
			if r.plane then
				local px, py, pz = Spring.GetUnitViewPosition(R.unit)
				py = py + Spring.GetUnitHeight(R.unit) * 0.85
				local x, y, z = Spring.GetUnitPosition(r.plane)
				R.yaw = math.deg(math.atan2(x - px, z - pz)) % 360 + 3 -- 3 degrees beside it
				R.pitch = math.deg(math.atan2(y - py, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2))) - 3
			end
		end
		if f == r.s + 280 then
			log(r.name, "circle", tostring(R.aaCircle and math.floor(R.aaCircle)), "lock", tostring(R.aaTarget), "plane", tostring(r.plane), ok(r.plane ~= nil and R.aaTarget == r.plane))
			if r.button == 4 then Spring.SendCommands("screenshot png") end
			r.hp0 = r.plane and Spring.GetUnitHealth(r.plane)
			R.fire = r.button
		end
		if f > r.s + 280 and f <= r.s + 320 then
			local kind, _, t = Spring.GetUnitWeaponTarget(R.unit, r.weapon)
			if kind == 1 and t == r.plane and not r.point then r.aimed = true end
			if kind == 2 and r.point and r.plane and type(t) == "table" then
				local x, y, z = Spring.GetUnitPosition(r.plane)
				if x and (t[1] - x) ^ 2 + (t[2] - y) ^ 2 + (t[3] - z) ^ 2 < 150 * 150 then r.aimed = true end
			end
		end
		if f == r.s + 320 then
			R.fire = 0
			local hp = r.plane and Spring.ValidUnitID(r.plane) and Spring.GetUnitHealth(r.plane) or nil
			log(r.name, "weapon", r.weapon, r.point and "had the point of the aircraft as its target" or "had the aircraft as its target", tostring(r.aimed), ok(r.aimed))
			log(r.name, "plane health", tostring(r.hp0 and math.floor(r.hp0)), "->", hp and string.format("%.0f", hp) or "destroyed", r.point and "" or ok(r.hp0 ~= nil and (hp == nil or hp < r.hp0)))
		end
	end
	if f == END then R.yaw = (R.yaw + 60) % 360 end
	if f == END + 10 then R.pitch = -8 end
	if f == END + 20 then log("looking away: lock", tostring(R.aaTarget), "hy", tostring(Spring.GetUnitRulesParam(R.unit, "renHY")), ok(R.aaTarget == nil)); R.fire = 4 end
	if f == END + 40 then local kind = Spring.GetUnitWeaponTarget(R.unit, 3); log("middle button at the ground (no lock): weapon 3 target type", tostring(kind), ok(kind ~= 1)); R.fire = 2 end
	if f == END + 60 then local kind = Spring.GetUnitWeaponTarget(R.unit, 2); log("right button at the ground (no lock): weapon 2 target type", tostring(kind), ok(kind ~= 1)); R.fire = 0 end
	if f == END + 100 then Spring.SendCommands("quitforce") end
end
