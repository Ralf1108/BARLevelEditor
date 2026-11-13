function widget:GetInfo() return { name = "zz ren90", desc = "test only: Renegade jump (Space) of a unit with two legs; tank and spider do not jump", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Quick -Widget zz_ren90.lua: a Pawn (two legs) jumps standing and while walking (W + Space), a Bulldog (tank) and a Webber (spider) must stay on
-- the ground, a Titan (big bot) jumps lower. Lines "[zzren90]": height above the ground, vertical and horizontal speed every 3 frames of a jump window; "peak" at the end of each window.
local R
local peak, win = 0, nil
local function line(f)
	if not R or not R.unit then return end
	local x, y, z = Spring.GetUnitPosition(R.unit)
	local vx, vy, vz = Spring.GetUnitVelocity(R.unit)
	local h = y - Spring.GetGroundHeight(x, z)
	peak = math.max(peak, h)
	if f % 3 == 0 then
		Spring.Echo(string.format("[zzren90] f %d %s height %.1f vy %.2f speed %.1f pos %.0f %.0f", f, UnitDefs[Spring.GetUnitDefID(R.unit)].name, h, vy * 30, 30 * math.sqrt(vx * vx + vz * vz), x, z))
	end
end
local function open(f, tag, len) win, peak = f + (len or 80), 0; Spring.Echo("[zzren90] --- " .. tag) end
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	-- the Pawn stands and jumps
	if f == 100 then open(f, "Pawn standing, Space") R.keys = 16 end
	if f == 103 then R.keys = 0 end
	-- a second press at once (the cooldown) and one after it
	if f == 190 then open(f, "Pawn walking W, Space (W held on after the landing)", 105) R.keys = 1 end
	if f == 215 then R.keys = 17 end
	if f == 218 then R.keys = 1 end
	if f == 296 then R.keys = 0 end
	-- a unit that must not jump
	if f == 320 then Spring.SendLuaRulesMsg("ren|unit|armbull") end
	if f == 360 then open(f, "Bulldog (tank), Space: no jump") R.keys = 16 end
	if f == 363 then R.keys = 0 end
	if f == 440 then Spring.SendLuaRulesMsg("ren|unit|armspid") end
	if f == 480 then open(f, "Webber (spider), Space: no jump") R.keys = 16 end
	if f == 483 then R.keys = 0 end
	if f == 560 then Spring.SendLuaRulesMsg("ren|unit|armbanth") end
	if f == 600 then open(f, "Titan (big bot), Space: a low jump") R.keys = 16 end
	if f == 603 then R.keys = 0 end
	if win and f <= win then line(f) end
	if win and f == win then Spring.Echo(string.format("[zzren90] peak %.1f above the ground", peak)); win = nil end
	if f == 700 then Spring.SendCommands("quitforce") end
end
