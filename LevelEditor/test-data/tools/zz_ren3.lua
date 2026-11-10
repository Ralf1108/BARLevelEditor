function widget:GetInfo() return { name = "zz ren3", desc = "test only: Renegade proof of concept 3 and 4", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren3.lua: puts a test enemy in front of the unit, aims at it by setting yaw / pitch of renegade.lua,
-- logs what the crosshair says (WG.renegade.hit), fires and logs the health of the enemy, then fires at the ground while strafing. Lines "[zzren3]".
local function log(...) Spring.Echo("[zzren3] " .. table.concat({ ... }, " ")) end
local function fmt(...) local t = {} for _, v in ipairs({ ... }) do t[#t + 1] = type(v) == "number" and string.format("%.1f", v) or tostring(v) end return table.concat(t, " ") end
local R, enemy

local function hit()
	local h = R.hit
	if not h then return "sky" end
	return h.kind .. " unit " .. tostring(h.unit) .. " at " .. fmt(h.x, h.y, h.z) .. " dist " .. fmt(h.dist)
end

local function weapon()
	local a, b, c = Spring.GetUnitWeaponTarget(R.unit, 1)
	return "weapon target type " .. tostring(a) .. " user " .. tostring(b) .. " target " .. (type(c) == "table" and fmt(c[1], c[2], c[3]) or tostring(c))
end

local function aimAt(id)
	local px, py, pz = Spring.GetUnitViewPosition(R.unit)
	py = py + Spring.GetUnitHeight(R.unit) * 0.85
	local x, y, z = Spring.GetUnitPosition(id, true)
	local dx, dy, dz = x - px, y - py, z - pz
	R.yaw = math.deg(math.atan2(dx, dz)) % 360
	R.pitch = math.deg(math.atan2(dy, math.sqrt(dx * dx + dz * dz)))
end

function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then
		if f == 60 then log("no WG.renegade") Spring.SendCommands("quitforce") end
		return
	end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|test|1") end
	if f == 130 then
		for _, id in ipairs(Spring.GetTeamUnits(1)) do
			if UnitDefs[Spring.GetUnitDefID(id)].name == "armpw" then enemy = id end
		end
		log("enemy", tostring(enemy), "health", fmt(Spring.GetUnitHealth(enemy)))
		log("crosshair before aiming at the enemy:", hit())
		aimAt(enemy)
	end
	if f == 150 then log("crosshair on the enemy:", hit()); Spring.SendCommands("screenshot png"); R.fire = 1 end
	if f == 180 then log("firing 1 s:", weapon(), "enemy health", fmt(Spring.GetUnitHealth(enemy or -1))) end
	if f == 270 then
		log("firing 4 s: enemy health", fmt(Spring.GetUnitHealth(enemy or -1)), "(370 at the start)")
		R.fire = 0
	end
	if f == 290 then log("fire released:", weapon()) end
	-- the ground, while strafing: the target must stay
	if f == 300 then R.yaw, R.pitch = 90, -15; R.keys = 2 end
	if f == 330 then log("crosshair on the ground:", hit()); R.fire = 1 end
	if f == 340 then
		local vsx, vsy = Spring.GetViewGeometry()
		local a, b, c, d = Spring.TraceScreenRay(vsx / 2, vsy / 2, false, false, true)
		log("TraceScreenRay full:", tostring(a), type(b) == "table" and fmt(b[1], b[2], b[3]) or tostring(b), tostring(c), tostring(d))
		a, b, c, d = Spring.TraceScreenRay(vsx / 2, vsy / 2, true)
		log("TraceScreenRay onlyCoords:", type(a) == "table" and fmt(a[1], a[2], a[3]) or tostring(a), tostring(b), tostring(c), tostring(d))
		local px, py, pz = Spring.GetCameraPosition()
		log("camera", fmt(px, py, pz), "unit", fmt(Spring.GetUnitPosition(R.unit)), "ground height under the camera", fmt(Spring.GetGroundHeight(px, pz)))
	end
	if f == 360 then log("firing at the ground while strafing:", weapon(), "unit speed", fmt(Spring.GetUnitVelocity(R.unit)), "crosshair", hit()) end
	if f == 390 then log("firing at the ground, 3 s:", weapon(), "unit speed", fmt(Spring.GetUnitVelocity(R.unit))) R.fire = 0; R.keys = 0 end
	if f == 420 then Spring.SendCommands("quitforce") end
end
