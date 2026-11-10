function widget:GetInfo() return { name = "zz ren17", desc = "test only: Renegade Calamity: continuous fire", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren17.lua: turns into the Calamity (corbuzz), an enemy Pawn stands 150 Elmo ahead (hook 1); the left button is held for 6 s. Lines "[zzren17]".
local function ts(a) return tostring(a) end
local function log(...) Spring.Echo("[zzren17] " .. table.concat({ ... }, " ")) end
local ONON = true
local R, enemy, shots, lastRf = nil, nil, 0, 0
local function rf() return Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame") or 0 end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|corbuzz") end
	if f == 141 then
		local wd = WeaponDefs[UnitDefNames.corbuzz.weapons[1].weaponDef]
		local keys = {}
		for _, k in ipairs({ "type", "range", "reload", "stockpile", "energyCost", "metalCost", "commandfire", "manualFire", "turret", "tolerance", "minRange", "projectilespeed", "flightTime", "highTrajectory", "cylinderTargeting", "avoidFriendly", "waterWeapon", "dynDamageExp", "tracks", "sweepFire", "burst", "salvoSize", "burstRate", "onlyTargets", "noGroundTargets" }) do keys[#keys + 1] = k .. "=" .. tostring(wd[k]) end
		log("corbuzz weapon", table.concat(keys, " "))
		local ud = UnitDefNames.corbuzz
		log("unit", "canMove", tostring(ud.canMove), "isBuilding", tostring(ud.isBuilding), "stockpile?", tostring(ud.weapons[1].onlyTargetCategory), "mainDir", tostring(ud.weapons[1].mainDirX), tostring(ud.weapons[1].mainDirY), tostring(ud.weapons[1].mainDirZ), "maxAngleDif", tostring(ud.weapons[1].maxAngleDif))
	end
	if f == 140 then log("slots", tostring(Spring.GetUnitRulesParam(R.unit, "renSlots"))); Spring.SendLuaRulesMsg("ren|test|1") end
	if f == 170 then
		for _, id in ipairs(Spring.GetTeamUnits(1)) do if UnitDefs[Spring.GetUnitDefID(id)].name == "armpw" then enemy = id end end
		local px, py, pz = Spring.GetUnitViewPosition(R.unit)
		py = py + Spring.GetUnitHeight(R.unit) * 0.85
		if enemy then
			local x, y, z = Spring.GetUnitPosition(enemy, true)
			R.yaw = math.deg(math.atan2(x - px, z - pz)) % 360
			R.pitch = math.deg(math.atan2(y - py, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)))
		end
		R.pitch = -4 -- (far ground ahead, ~1400 Elmo: the enemy 150 ahead is not the target)
		log("enemy", tostring(enemy), "unit", tostring(R.unit))
		lastRf = rf()
	end
	if f == 160 then log("CMD.TRAJECTORY", tostring(CMD.TRAJECTORY), "ONOFF", tostring(CMD.ONOFF)); Spring.GiveOrderToUnit(R.unit, CMD.TRAJECTORY or 120, { 1 }, 0) end
	if f == 200 then R.fire = 1 end
	if f >= 200 and f <= 440 then
		local r = rf()
		if r ~= lastRf then if r < 500000 then shots = shots + 1 end; lastRf = r end
		if f % 40 == 0 and R.shot then
			local u, s = R.unit, R.shot
			log("probe aimReady", ts(Spring.GetUnitWeaponState(u, 1, "aimReady")), "canFire", ts(Spring.GetUnitWeaponCanFire and Spring.GetUnitWeaponCanFire(u, 1)),
				"freeLine", ts(Spring.GetUnitWeaponHaveFreeLineOfFire and Spring.GetUnitWeaponHaveFreeLineOfFire(u, 1, s.x, s.y, s.z)),
				"testTarget", ts(Spring.GetUnitWeaponTestTarget and Spring.GetUnitWeaponTestTarget(u, 1, s.x, s.y, s.z)),
				"testRange", ts(Spring.GetUnitWeaponTestRange and Spring.GetUnitWeaponTestRange(u, 1, s.x, s.y, s.z)),
				"active", ts(Spring.GetUnitStates(u) and Spring.GetUnitStates(u).active), "activateWhenBuilt", ts(UnitDefs[Spring.GetUnitDefID(u)].activateWhenBuilt), "fireState", ts(Spring.GetUnitStates(u) and Spring.GetUnitStates(u).firestate), "trajectory", ts(Spring.GetUnitStates(u) and Spring.GetUnitStates(u).trajectory),
				"buildProgress", ts((select(5, Spring.GetUnitHealth(u)))), "stunned", ts((Spring.GetUnitIsStunned(u))))
		end
		if f % 20 == 0 then
			local ttype, tgt = Spring.GetUnitWeaponTarget(R.unit, 1)
			local _, _, _, dx, dy, dz = Spring.GetUnitWeaponVectors(R.unit, 1)
			log("f", f, "reloadFrame", r, "shots", shots, "targetType", tostring(ttype), "dir", dx and string.format("%.2f %.2f %.2f", dx, dy, dz) or "-", "fire", R.fire, "enemy", enemy and string.format("%.0f", (Spring.GetUnitHealth(enemy) or -1)) or "?", "shot", R.shot and string.format("%.0f %.0f", R.shot.udist or -1, R.shot.y) or "-", "energy", string.format("%.0f", (Spring.GetTeamResources(0, "energy"))))
		end
	end
	if f == 440 then R.fire = 0 end
	if f == 460 then log("shots in 8 s", shots); Spring.SendCommands("quitforce") end
end
