function widget:GetInfo() return { name = "zz ren59", desc = "test only: direct and indirect missiles", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren59.lua: the fields of missile weapons that tell a direct flight from a lofted one ("[zzren59]").
local function log(...) Spring.Echo("[zzren59] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f ~= 60 then return end
	local function show(name)
		local ud = UnitDefNames[name]
		for i, wp in ipairs(ud and ud.weapons or {}) do
			local wd = WeaponDefs[wp.weaponDef]
			if wd and (wd.type == "MissileLauncher" or wd.type == "StarburstLauncher") then
				log(name .. "#" .. i, wd.type, "range", tostring(wd.range), "trajH", tostring(wd.trajectoryHeight), "uptime", tostring(wd.uptime), "flightTime", tostring(wd.flightTime), "startVel", tostring(wd.startvelocity), "speed", tostring(wd.projectilespeed), "accel", tostring(wd.weaponAcceleration), "turnRate", tostring(wd.turnRate), "tracks", tostring(wd.tracks), "dance", tostring(wd.dance), "hi", tostring(wd.highTrajectory), "desc", tostring(wd.description))
			end
		end
	end
	for _, n in ipairs({ "corkarg", "armrock", "corstorm", "armmerl", "cormart", "armjanus", "corhurc", "armmlv", "armamd", "corvroc", "armbanth", "armsilo", "cortron", "corwolv", "armmship", "cormship", "corcrw", "armlance", "corban" }) do show(n) end
	-- all missile launchers: by trajectoryHeight, with examples
	local g, ex = {}, {}
	for _, ud in pairs(UnitDefs) do
		if not ud.name:find("_scav$") then
			for _, wp in ipairs(ud.weapons or {}) do
				local wd = WeaponDefs[wp.weaponDef]
				if wd and (tonumber(wd.range) or 0) > 0 and (wd.type == "MissileLauncher" or wd.type == "StarburstLauncher") then
					local key = wd.type .. " trajH>0=" .. tostring((tonumber(wd.trajectoryHeight) or 0) > 0) .. " uptime>0=" .. tostring((tonumber(wd.uptime) or 0) > 0)
					g[key] = (g[key] or 0) + 1
					ex[key] = ex[key] or {}
					if #ex[key] < 10 then ex[key][#ex[key] + 1] = ud.name end
				end
			end
		end
	end
	for k, n in pairs(g) do log(n, k, table.concat(ex[k], ",")) end
	Spring.SendCommands("quitforce")
end
