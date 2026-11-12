function widget:GetInfo() return { name = "zz ren78", desc = "test only: Renegade reverse gear", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren78.lua: a Pawn (bot) and a Bulldog (armbull, tank) drive backward (S), backward with steering (S + D), forward (W) and forward
-- with steering (W + D) (the view looks along -x for S, so that backward goes into the map, and along +x for W). Logs position, heading (degrees), speed and the maximum speed. Lines "[zzren78]".
local function log(...) Spring.Echo("[zzren78] " .. table.concat({ ... }, " ")) end
local R
local STEPS = { { 0, "stand" }, { 4, "S" }, { 4 + 8, "S+D" }, { 1, "W" }, { 1 + 8, "W+D" }, { 0, "stand" } }
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 400 then Spring.SendLuaRulesMsg("ren|unit|armbull") end
	if f < 100 or not R.unit then return end
	local t = f < 400 and f - 100 or f - 450
	if t < 0 then return end
	local step = STEPS[math.floor(t / 50) + 1]
	if step then R.keys = step[1]; R.yaw = (step[1] % 2 >= 1) and 90 or 270 end -- (S: looks to -x so that backward goes to +x, into the map; W: looks to +x)
	if t % 25 == 0 and step then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local vx, _, vz = Spring.GetUnitVelocity(R.unit)
		local ud = UnitDefs[Spring.GetUnitDefID(R.unit)]
		log(ud.name, "f", f, step[2], "pos", string.format("%.0f %.0f", x, z), "heading", string.format("%.0f", Spring.GetUnitHeading(R.unit) * 360 / 65536), "speed", string.format("%.1f", 30 * math.sqrt((vx or 0) ^ 2 + (vz or 0) ^ 2)), "max", ud.speed)
	end
	if f == 760 then Spring.SendCommands("quitforce") end
end
