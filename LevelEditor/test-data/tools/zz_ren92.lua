function widget:GetInfo() return { name = "zz ren92", desc = "test only: Renegade power-ups without Evolution (beacons, keys 1 to 5, the bar)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenPowerups -Quick -Widget zz_ren92.lua: the unit is put onto the nearest beacon (ren|test|8) and takes the power-up; then it gets all five
-- (ren|test|7) and the keys 1 (Sprint, W held: the speed), 3 (Radar Pulse: the sight), 4 (Cloak: stays on hold fire after the 15 s) and 2 (Repair at 30 % health) are pressed with R.keyPress.
-- A picture of the bar and of a beacon. Lines "[zzren92]".
local R
local function log(...) Spring.Echo("[zzren92] " .. table.concat({ ... }, " ")) end
local function press(n)
	local key = 48 + n
	local ok, res = pcall(R.keyPress, key, {}, false, tostring(n), key, 29 + n)
	log("key", tostring(n), ok and ("pressed, taken: " .. tostring(res)) or ("error " .. tostring(res)))
end
local function state(tag)
	local team = Spring.GetMyTeamID()
	local u = R and R.unit
	if not u then log(tag, "no unit") return end
	local vx, _, vz = Spring.GetUnitVelocity(u)
	local hp, mhp = Spring.GetUnitHealth(u)
	log(tag, "fire state", tostring((Spring.GetUnitStates(u) or {}).firestate), "speed", string.format("%.1f", 30 * math.sqrt((vx or 0) ^ 2 + (vz or 0) ^ 2)),
		"los", tostring(Spring.GetUnitSensorRadius and Spring.GetUnitSensorRadius(u, "los")), "health", string.format("%.0f of %.0f", hp or 0, mhp or 0),
		"abilities", tostring(Spring.GetTeamRulesParam(team, "renAbilities")), "beacons", tostring((Spring.GetGameRulesParam("renBeacons") or ""):gsub("[^/]", ""):len() + 1))
end
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0; log("R.on", tostring(R.on), "R.powerups", tostring(R.powerups), "bar", tostring(R.U ~= nil)); state("start") end
	if f == 70 then Spring.SendLuaRulesMsg("ren|test|8") end -- (onto the nearest beacon)
	if f == 100 then state("after the beacon") end
	if f == 110 then Spring.SendLuaRulesMsg("ren|test|7") end -- (all five)
	if f == 120 then state("all five") end
	if f == 125 then Spring.SendLuaRulesMsg("ren|test|6") end -- (30 % health, wrecks ahead)
	if f == 135 then state("hurt") end
	if f == 140 then press(2) end -- Repair
	if f == 150 then state("after Repair") end
	if f == 160 then press(4) end -- Cloak
	if f == 170 then R.keys = 1 end
	if f == 175 then press(1) end -- Sprint
	if f == 205 then state("sprint running (W held)") end
	if f == 210 then press(3) end -- Radar Pulse
	if f == 225 then state("pulse running"); Spring.SendCommands("screenshot png") end
	if f == 260 then R.keys = 0 end
	if f == 690 then state("after the end of the cloak (15 s)") end
	if f == 700 then Spring.SendCommands("quitforce") end
end
