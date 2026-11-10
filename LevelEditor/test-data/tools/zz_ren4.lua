function widget:GetInfo() return { name = "zz ren4", desc = "test only: Renegade shots anywhere", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -Widget zz_ren4.lua: turns round in steps and logs what the engine ray says (rayKind) and what renegade.lua makes of it (hit,
-- shot); fires at the sky and at a far mountain and logs the weapon target and the reload state. Lines "[zzren4]".
local function log(...) Spring.Echo("[zzren4] " .. table.concat({ ... }, " ")) end
local function fmt(...) local t = {} for _, v in ipairs({ ... }) do t[#t + 1] = type(v) == "number" and string.format("%.0f", v) or tostring(v) end return table.concat(t, " ") end
local R
local function weapon()
	local a, b, c = Spring.GetUnitWeaponTarget(R.unit, 1)
	return "weapon target type " .. tostring(a) .. " target " .. (type(c) == "table" and fmt(c[1], c[2], c[3]) or tostring(c))
end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true end
	if f == 95 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		for _, id in ipairs(Spring.GetFeaturesInCylinder(x, z, 150)) do
			local fx, fy, fz = Spring.GetFeaturePosition(id)
			log("feature", FeatureDefs[Spring.GetFeatureDefID(id)].name, fmt(fx - x, fy - y, fz - z))
		end
	end
	-- a turn: every 12 frames another yaw
	if f >= 100 and f < 100 + 12 * 12 and (f - 100) % 12 == 0 then R.yaw, R.pitch = ((f - 100) / 12) * 30, 3 end
	if f >= 106 and f < 106 + 12 * 12 and (f - 106) % 12 == 0 then
		local h, s = R.hit, R.shot
		log("yaw", fmt(R.yaw), "ray", tostring(R.rayKind), "hit", h and (h.kind .. " " .. fmt(h.dist)) or "none", "shot", s and (s.kind .. " " .. fmt(s.dist)) or "none")
	end
	if f == 270 then R.yaw, R.pitch = 90, 25; R.fire = 1 end
	if f == 300 then log("at the sky:", "hit", R.hit and R.hit.kind or "none", "shot", R.shot.kind, fmt(R.shot.x, R.shot.y, R.shot.z), weapon(), "reloadFrame", tostring(Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame")), "frame", f) end
	if f == 330 then log("again:", weapon(), "reloadFrame", tostring(Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame")), "frame", f); R.fire = 0 end
	if f == 400 then Spring.SendCommands("quitforce") end
end
