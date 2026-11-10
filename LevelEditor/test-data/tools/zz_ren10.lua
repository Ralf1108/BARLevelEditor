function widget:GetInfo() return { name = "zz ren10", desc = "test only: Renegade anti-air circle and lock", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren10.lua: turns into an anti-air turret (armrl), an enemy gunship hovers ahead; the crosshair points a few degrees beside it
-- (inside the orange circle): the lock, then fire: the weapon gets the aircraft as its target and the aircraft loses health. Lines "[zzren10]".
local function log(...) Spring.Echo("[zzren10] " .. table.concat({ ... }, " ")) end
local R, plane
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armrl") end
	if f == 140 then log("unit", UnitDefs[Spring.GetUnitDefID(R.unit)].name, "slots", tostring(Spring.GetUnitRulesParam(R.unit, "renSlots")), "aa", tostring(Spring.GetUnitRulesParam(R.unit, "renAA"))); Spring.SendLuaRulesMsg("ren|test|3") end
	if f == 180 then
		for _, id in ipairs(Spring.GetTeamUnits(1)) do
			if UnitDefs[Spring.GetUnitDefID(id)].canFly then plane = id end
		end
		log("gunship", tostring(plane), "health", plane and string.format("%.0f", (Spring.GetUnitHealth(plane))) or "?")
		if plane then
			local px, py, pz = Spring.GetUnitViewPosition(R.unit)
			py = py + Spring.GetUnitHeight(R.unit) * 0.85
			local x, y, z = Spring.GetUnitPosition(plane)
			R.yaw = math.deg(math.atan2(x - px, z - pz)) % 360 + 3 -- 3 degrees beside it
			R.pitch = math.deg(math.atan2(y - py, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2))) - 3
		end
	end
	if f == 200 then
		log("circle", tostring(R.aaCircle and math.floor(R.aaCircle)), "lock", tostring(R.aaTarget), "plane", tostring(plane))
		Spring.SendCommands("screenshot png")
		R.fire = 1
	end
	if f == 240 then log("firing: weapon target", tostring(Spring.GetUnitWeaponTarget(R.unit, 1)), "plane health", plane and string.format("%.0f", (Spring.GetUnitHealth(plane) or -1)) or "?"); R.fire = 0 end
	if f == 260 then
		R.yaw = (R.yaw + 60) % 360
	end
	if f == 280 then log("looking away: lock", tostring(R.aaTarget)); R.fire = 1 end
	if f == 300 then log("fire without a lock: weapon target", tostring(Spring.GetUnitWeaponTarget(R.unit, 1))); R.fire = 0 end
	if f == 320 then Spring.SendCommands("quitforce") end
end
