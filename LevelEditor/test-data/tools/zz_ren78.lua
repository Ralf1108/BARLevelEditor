function widget:GetInfo() return { name = "zz ren78", desc = "test only: Renegade reverse gear (driving, steering, reverse from standing)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren78.lua: a Pawn (bot) and a Bulldog (armbull, tank) drive forward (W), forward with steering (W + D), turn on the spot (D), backward (S) and backward with steering (S + A) (the view stays at yaw 90 all the time: the hull is steered by W S A D alone). Logs position, heading (degrees), speed and the maximum speed. Lines "[zzren78]".
local function log(...) Spring.Echo("[zzren78] " .. table.concat({ ... }, " ")) end
-- Then (frame 820, zz_ren86.lua is part of it) a Pawn stands looking along +z and S is held for 80 frames: logs z and the speed every 5 frames (z must go down in the end: OK / WRONG).
local R, z0
local STEPS = { { 0, "stand" }, { 1, "W" }, { 1 + 8, "W+D" }, { 8, "D" }, { 4, "S" }, { 4 + 2, "S+A" }, { 0, "stand" } }
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 400 then Spring.SendLuaRulesMsg("ren|unit|armbull") end
	if f == 820 then R.keys = 0; Spring.SendLuaRulesMsg("ren|unit|armpw") end
	if f == 850 then R.yaw, R.pitch = 0, 0 end
	if f == 920 then R.keys = 4; z0 = R.unit and select(3, Spring.GetUnitPosition(R.unit)) end
	if f == 1000 then R.keys = 0 end
	if f >= 910 and f <= 1030 and f % 5 == 0 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local vx, _, vz = Spring.GetUnitVelocity(R.unit)
		log(string.format("from standing: f %d keys %d z %.1f speed %.1f", f, R.keys or 0, z, 30 * math.sqrt(vx * vx + vz * vz)))
		if f == 1030 then log(string.format("reverse from standing: z %.1f -> %.1f", z0 or -1, z), (z0 ~= nil and z < z0 - 10) and "OK" or "WRONG") end
	end
	if f == 1040 then Spring.SendCommands("quitforce") end
	if f < 100 or not R.unit then return end
	local t = f < 400 and f - 100 or f - 450
	if t >= 350 then return end
	if t < 0 then return end
	local step = STEPS[math.floor(t / 50) + 1]
	if step then R.keys = step[1] end -- (the view stays at yaw 90: the hull is steered by the keys alone)
	if t % 25 == 0 and step then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local vx, _, vz = Spring.GetUnitVelocity(R.unit)
		local ud = UnitDefs[Spring.GetUnitDefID(R.unit)]
		log(ud.name, "f", f, step[2], "pos", string.format("%.0f %.0f", x, z), "heading", string.format("%.0f", Spring.GetUnitHeading(R.unit) * 360 / 65536), "speed", string.format("%.1f", 30 * math.sqrt((vx or 0) ^ 2 + (vz or 0) ^ 2)), "max", ud.speed)
	end
end
