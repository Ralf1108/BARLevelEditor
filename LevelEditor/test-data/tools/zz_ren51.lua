function widget:GetInfo() return { name = "zz ren51", desc = "test only: which weapons shoot in an arc", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren51.lua: counts the weapon definitions of all units by type, highTrajectory and trajectoryHeight and lists some ("[zzren51]").
local function log(...) Spring.Echo("[zzren51] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f ~= 60 then return end
	local groups, ex = {}, {}
	for _, ud in pairs(UnitDefs) do
		for _, wp in ipairs(ud.weapons or {}) do
			local wd = WeaponDefs[wp.weaponDef]
			if wd and (tonumber(wd.range) or 0) > 0 then
				local key = string.format("%s hi=%s th=%s grav=%s", tostring(wd.type), tostring(wd.highTrajectory), tostring((tonumber(wd.trajectoryHeight) or 0) > 0), tostring((tonumber(wd.myGravity) or 0) > 0))
				groups[key] = (groups[key] or 0) + 1
				ex[key] = ex[key] or {}
				if #ex[key] < 6 then ex[key][#ex[key] + 1] = ud.name end
			end
		end
	end
	for k, n in pairs(groups) do log(n, k, table.concat(ex[k], ",")) end
	for _, name in ipairs({ "armmart", "armbull", "armpw", "armguard", "corwolv", "armrock", "cormart", "armham", "armfido" }) do
		local ud = UnitDefNames[name]
		local wd = ud and ud.weapons[1] and WeaponDefs[ud.weapons[1].weaponDef]
		if wd then log(name, wd.type, "hi", tostring(wd.highTrajectory), "traj", tostring(wd.trajectoryHeight), "range", tostring(wd.range), "speed", tostring(wd.projectilespeed), "grav", tostring(wd.myGravity)) end
	end
	Spring.SendCommands("quitforce")
end
