function widget:GetInfo() return { name = "zz ren57", desc = "test only: the shoulder rockets of the Karganeth (right button, air only) lock on an aircraft", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren57.lua: turns into an anti-air turret (corkarg), an enemy gunship hovers ahead; the crosshair points a few degrees beside it
-- (inside the orange circle): the lock, then fire: the weapon gets the aircraft as its target and the aircraft loses health. Lines "[zzren57]".
local function log(...) Spring.Echo("[zzren57] " .. table.concat({ ... }, " ")) end
local R, plane
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|corkarg") end
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
	if f == 420 then
		log("circle", tostring(R.aaCircle and math.floor(R.aaCircle)), "lock", tostring(R.aaTarget), "plane", tostring(plane))
		Spring.SendCommands("screenshot png")
		R.fire = 2
	end
	if f == 460 then log("firing: weapon target", tostring(Spring.GetUnitWeaponTarget(R.unit, 2)), "plane health", plane and string.format("%.0f", (Spring.GetUnitHealth(plane) or -1)) or "?"); R.fire = 0 end
	if f == 480 then
		R.yaw = (R.yaw + 60) % 360
	end
	if f == 490 then R.pitch = -8 end
	if f == 500 then log("looking away: lock", tostring(R.aaTarget), "hy", tostring(Spring.GetUnitRulesParam(R.unit, "renHY"))); R.fire = 2 end
	if f == 520 then log("fire at the ground (no lock): weapon target type", tostring(Spring.GetUnitWeaponTarget(R.unit, 2))); R.fire = 0 end
	if f == 560 then Spring.SendCommands("quitforce") end
end
