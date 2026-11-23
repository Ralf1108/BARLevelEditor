function widget:GetInfo() return { name = "zz ren64", desc = "test only: the Exploiters (extractors with weapons) fire at the ground and at an enemy unit", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren64.lua: the player becomes an Advanced Exploiter (cormexp) and an Exploiter (corexp) in turn, looks at the ground, presses the left and right button;
-- "[zzren64]" logs the groups, the reload frames and the unit states. Then the player becomes an Advanced Exploiter again, a test enemy stands 150 Elmo ahead (ren|test|1, hold
-- fire), the crosshair is on it, both buttons are held: the enemy must lose health (OK / WRONG) (zz_ren69.lua is part of it).
local function log(...) Spring.Echo("[zzren64] " .. table.concat({ ... }, " ")) end
local list = { "cormexp", "corllt", "armllt" }
local END = 70 + 200 * #list -- the second part starts here
local enemy, hp0
function widget:GameFrame(f)
	local R = WG.renegade
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 8 end
	for k, name in ipairs(list) do
		local b = 70 + (k - 1) * 200
		if f == b then Spring.SendLuaRulesMsg("ren|unit|" .. name) end
		if f == b + 40 and R.unit then
			local u = R.unit
			local ud = UnitDefs[Spring.GetUnitDefID(u)]
			log(name, "slots", tostring(Spring.GetUnitRulesParam(u, "renSlots")), "aa", tostring(Spring.GetUnitRulesParam(u, "renAA")), "canMove", tostring(ud.canMove), "isBuilding", tostring(ud.isBuilding), "weapons", #ud.weapons, "hit", tostring(R.hit and R.hit.kind), "udist", tostring(R.hit and math.floor(R.hit.udist)))
			local act = Spring.GetUnitIsActive and Spring.GetUnitIsActive(u)
			local st = Spring.GetUnitStates(u)
			log("active", tostring(act), "firestate", tostring(st and st.firestate), "stunned", tostring(Spring.GetUnitIsStunned(u)), "buildProgress", tostring(select(5, Spring.GetUnitHealth(u))))
			R.fire = 3
		end
		if f == b + 80 and R.unit then
			local u = R.unit
			local ud = UnitDefs[Spring.GetUnitDefID(u)]
			local parts = {}
			for i = 1, #ud.weapons do parts[#parts + 1] = string.format("w%d reload %s", i, tostring(Spring.GetUnitWeaponState(u, i, "reloadFrame"))) end
			log(name, "after the press (frame", f, "):", table.concat(parts, " | "))
			R.fire = 0
		end
	end
	if f == END then R.fire = 0; R.yaw, R.pitch = 90, 0 end
	if f == END + 10 then Spring.SendLuaRulesMsg("ren|unit|cormexp") end
	if f == END + 60 then Spring.SendLuaRulesMsg("ren|test|1") end
	if f == END + 90 then
		for _, id in ipairs(Spring.GetAllUnits()) do
			if not Spring.IsUnitAllied(id) and Spring.GetUnitTeam(id) ~= Spring.GetGaiaTeamID() then enemy = id end
		end
		hp0 = enemy and Spring.GetUnitHealth(enemy)
		log("enemy", tostring(enemy), "hp", hp0 and string.format("%.0f", hp0) or "?")
		if enemy then
			local px, py, pz = Spring.GetUnitViewPosition(R.unit)
			py = py + Spring.GetUnitHeight(R.unit) * 0.85
			local x, y, z = Spring.GetUnitPosition(enemy)
			y = y + Spring.GetUnitHeight(enemy) * 0.5
			R.yaw = math.deg(math.atan2(x - px, z - pz)) % 360
			R.pitch = math.deg(math.atan2(y - py, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)))
		end
	end
	if f == END + 130 then log("crosshair", tostring(R.hit and R.hit.kind), tostring(R.hit and R.hit.unit), "udist", tostring(R.hit and math.floor(R.hit.udist)), "best", tostring(R.best)); R.fire = 3 end
	if f == END + 270 then
		R.fire = 0
		local hp = enemy and Spring.GetUnitHealth(enemy)
		log("after the buttons: enemy hp", tostring(hp0 and math.floor(hp0)), "->", hp and string.format("%.0f", hp) or "destroyed", (hp0 ~= nil and (hp == nil or hp < hp0)) and "OK" or "WRONG")
		Spring.SendCommands("quitforce")
	end
end
