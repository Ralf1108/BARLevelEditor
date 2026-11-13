function widget:GetInfo() return { name = "zz ren91", desc = "test only: Renegade with Evolution: the keys 1 to 5 use the power-ups (Sprint, Radar Pulse, Cloak)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTakeover -RenTest -Evo -EvoTest -Debug -Quick -Widget zz_ren91.lua: the player takes over its Evolution unit, gets all five power-ups (evo|debug|6 to 10),
-- then the real key presses (R.keyPress: the key press of the Renegade widget) 1 (Sprint, W held: the speed), 3 (Radar Pulse: the sight) and 4 (Cloak: cloaked, fire state 0, and after the 15 s still 0, not
-- "fire at will"). Lines "[zzren91]".
local R
local function log(...) Spring.Echo("[zzren91] " .. table.concat({ ... }, " ")) end
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
	local fs = (Spring.GetUnitStates(u) or {}).firestate
	log(tag, "unit", UnitDefs[Spring.GetUnitDefID(u)].name, "fire state", tostring(fs), "cloaked", tostring((Spring.GetUnitIsCloaked(u))), "speed", string.format("%.1f", 30 * math.sqrt((vx or 0) ^ 2 + (vz or 0) ^ 2)),
		"los", tostring(Spring.GetUnitSensorRadius and Spring.GetUnitSensorRadius(u, "los")), "abilities", tostring(Spring.GetTeamRulesParam(team, "evoAbilities")))
end
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	local team = Spring.GetMyTeamID()
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	if f == 100 then
		local id = Spring.GetTeamRulesParam(team, "evoUnit")
		if id and id > 0 then Spring.SendLuaRulesMsg("ren|possess|" .. id) end
	end
	if f == 130 then R.fake = true; R.yaw, R.pitch = 0, 0; log("R.on", tostring(R.on), "R.evo", tostring(R.evo)) end
	if f >= 140 and f <= 148 and f % 2 == 0 then Spring.SendLuaRulesMsg("evo|debug|" .. (6 + (f - 140) / 2)) end
	if f == 160 then state("with all power-ups") end
	if f == 165 then press(4) end -- Cloak
	if f == 175 then state("cloak running") end
	if f == 180 then R.keys = 1 end -- W held from now on
	if f == 185 then press(1) end -- Sprint
	if f == 225 then state("sprint running (W held)") end
	if f == 230 then press(3) end -- Radar Pulse
	if f == 250 then state("pulse running") end
	if f == 255 then Spring.SendCommands("screenshot png") end -- (the bar of the power-ups with the numbers of the keys)
	if f == 300 then R.keys = 0 end
	if f == 330 then state("before the end of the cloak") end
	if f == 650 then state("after the end of the cloak (15 s)") end
	if f == 660 then Spring.SendCommands("quitforce") end
end
