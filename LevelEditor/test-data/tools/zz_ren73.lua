function widget:GetInfo() return { name = "zz ren73", desc = "test only: Renegade Flying Black Hydra on slopes", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren73.lua: the player becomes a bomber (corfblackhyt4), takes off (W) and flies straight (W held) in the direction of the next 3000 Elmo with the largest
-- differences in ground height. Logs every 15 frames the ground height, the height above the ground and the vertical speed. Lines "[zzren73]".
local function log(...) Spring.Echo("[zzren73] " .. table.concat({ ... }, " ")) end
local R, bestYaw
local function pick(x, z)
	local best, by = -1, 0
	for a = 0, 350, 10 do
		local dx, dz = math.sin(math.rad(a)), math.cos(math.rad(a))
		local lo, hi, ok = 1e9, -1e9, true
		for d = 0, 1500, 50 do
			local px, pz = x + dx * d, z + dz * d
			if px < 100 or pz < 100 or px > Game.mapSizeX - 100 or pz > Game.mapSizeZ - 100 then break end
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
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|corfblackhyt4") end
	if f == 130 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local a, d = pick(x, z)
		R.yaw = a
		log("start", string.format("%.0f %.0f", x, z), "direction", a, "ground difference on the way", string.format("%.0f", d))
	end
	if f == 135 and R.unit then local ud = UnitDefs[Spring.GetUnitDefID(R.unit)]; local mv = Spring.GetUnitMoveTypeData(R.unit) or {}; log("unit", ud.name, "canFly", tostring(ud.canFly), "hover", tostring(ud.isHoveringAirUnit), "hoverAttack", tostring(ud.hoverAttack), "speed", tostring(ud.speed), "radius", tostring(ud.radius), "movetype", tostring(mv.name), "state", tostring(mv.aircraftState), "renMaxAlt", tostring((Spring.GetUnitRulesParam(R.unit, "renMaxAlt"))), "wantedHeight", tostring(mv.wantedHeight)) end
	if f == 140 then R.keys = 17 end
	if f == 260 then R.keys = 1 end
	if f >= 280 and f % 40 == 0 and f <= 460 and R.unit then local cmds = Spring.GetUnitCommands(R.unit, 2) or {}; local x, y, z = Spring.GetUnitPosition(R.unit); log("pos", math.floor(x), math.floor(y), math.floor(z), "commands", #cmds, cmds[1] and cmds[1].id or "-", cmds[1] and cmds[1].params and (math.floor(cmds[1].params[1] or 0) .. "," .. math.floor(cmds[1].params[3] or 0)) or "-", "keys", R.keys, "yaw", R.yaw) end
	if f >= 140 and f % 15 == 0 and f <= 900 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local _, vy = Spring.GetUnitVelocity(R.unit)
		local g = Spring.GetGroundHeight(x, z)
		log("f", f, "speed", string.format("%.1f", math.sqrt((select(1, Spring.GetUnitVelocity(R.unit)) or 0) ^ 2 + (select(3, Spring.GetUnitVelocity(R.unit)) or 0) ^ 2) * 30), "ground", string.format("%.0f", g), "above ground", string.format("%.0f", y - g), "vy", string.format("%.1f", vy or 0))
	end
	if f == 920 then Spring.SendCommands("quitforce") end
end
