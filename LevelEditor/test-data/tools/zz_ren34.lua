function widget:GetInfo() return { name = "zz ren34", desc = "test only: Renegade bomber: its height above the ground on slopes, its ceiling with Space held, the bomb sight colour", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Map "Hooked 1.1" -Widget zz_ren34.lua (a map with a cliff; on a flat map only the ceiling is checked): the player becomes a bomber (armthund), takes off (W) and flies straight (W held) in the direction of the next 3000 Elmo with the largest
-- differences in ground height. Logs every 15 frames the ground height, the height above the ground and the vertical speed. Then (frame 900) W and Space are held: it climbs to its
-- ceiling (0.95 x its attack altitude renAttackAlt: it never flies where its bombs do not fall) and must be there (15 more or less) in at least 80 % of the frames from 1000 on (the
-- ground that falls away at a cliff puts it higher for a moment) (OK / WRONG); every 20 frames the height, the attack altitude and the state of the bomb sight (green / yellow / red; it
-- must be green at the end), a picture at the ceiling. Lines "[zzren34]" (zz_ren35.lua and zz_ren74.lua are part of it).
local function log(...) Spring.Echo("[zzren34] " .. table.concat({ ... }, " ")) end
local R, bestYaw
local top, attack, sight, heights = 0, nil, nil, {} -- (the highest height above the ground with Space held, the attack altitude, the last state of the bomb sight, every height from frame 1000 on)
local function pick(x, z)
	local best, by = -1, 0
	for a = 0, 350, 10 do
		local dx, dz = math.sin(math.rad(a)), math.cos(math.rad(a))
		local lo, hi, ok = 1e9, -1e9, true
		for d = 0, 3000, 50 do
			local px, pz = x + dx * d, z + dz * d
			if px < 100 or pz < 100 or px > Game.mapSizeX - 100 or pz > Game.mapSizeZ - 100 then ok = false break end
			local g = Spring.GetGroundHeight(px, pz)
			lo, hi = math.min(lo, g), math.max(hi, g)
		end
		if ok and hi - lo > best then best, by = hi - lo, a end
	end
	return by, best
end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armthund") end
	if f == 130 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local a, d = pick(x, z)
		R.yaw = a
		log("start", string.format("%.0f %.0f", x, z), "direction", a, "ground difference on the way", string.format("%.0f", d))
	end
	if f == 140 then R.keys = 1 end
	if f >= 140 and f % 15 == 0 and f <= 900 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local _, vy = Spring.GetUnitVelocity(R.unit)
		local g = Spring.GetGroundHeight(x, z)
		log("f", f, "ground", string.format("%.0f", g), "above ground", string.format("%.0f", y - g), "vy", string.format("%.1f", vy or 0))
	end
	if f == 900 then R.keys = 1 + 16 end -- W and Space held from here on
	if f > 900 and f <= 1700 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local h = y - Spring.GetGroundHeight(x, z)
		top = math.max(top, h)
		if f >= 1000 then heights[#heights + 1] = h end
		if f % 20 == 0 then
			local at = tonumber(Spring.GetUnitRulesParam(R.unit, "renAttackAlt"))
			local st = at and (h <= at and "green" or (h <= at * 1.15 and "yellow" or "red")) or "none"
			attack, sight = at, st
			log("f", f, "climbing: above ground", string.format("%.0f", h), "attack", tostring(at), "sight", st)
		end
	end
	if f == 1500 then Spring.SendCommands("screenshot png") end
	if f == 1700 then
		local ceiling = (attack or 0) * 0.95
		local at = 0
		for _, h in ipairs(heights) do
			if math.abs(h - ceiling) <= 15 then at = at + 1 end
		end
		log("with Space held: at its ceiling of", string.format("%.0f", ceiling), "(15 more or less) in", at, "of", #heights, "frames, highest", string.format("%.0f", top),
			"(a cliff under it)", (attack ~= nil and at >= 0.8 * #heights) and "OK" or "WRONG")
		log("the bomb sight at the ceiling", tostring(sight), sight == "green" and "OK" or "WRONG")
	end
	if f == 1720 then Spring.SendCommands("quitforce") end
end
