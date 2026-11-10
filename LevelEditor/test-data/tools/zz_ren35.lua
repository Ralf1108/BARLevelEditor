function widget:GetInfo() return { name = "zz ren35", desc = "test only: Renegade bomber with Space held never gets over its highest height", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren34.lua: the player becomes a bomber (armthund), takes off (W), then W and Space are held (it flies straight and tries to climb on); it must not get over its highest height (495 above the ground). Logs every 15 frames the ground height, the height above the ground and the vertical speed. Lines "[zzren35]".
local function log(...) Spring.Echo("[zzren35] " .. table.concat({ ... }, " ")) end
local R, bestYaw
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
	if f == 330 then R.keys = 17 end -- W and Space held from here on: it must not get over 495 (its highest height)
	if f >= 140 and f % 15 == 0 and f <= 900 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local _, vy = Spring.GetUnitVelocity(R.unit)
		local g = Spring.GetGroundHeight(x, z)
		log("f", f, "ground", string.format("%.0f", g), "above ground", string.format("%.0f", y - g), "vy", string.format("%.1f", vy or 0))
	end
	if f == 920 then Spring.SendCommands("quitforce") end
end
