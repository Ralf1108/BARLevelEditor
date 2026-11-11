function widget:GetInfo() return { name = "zz ren65", desc = "test only: energy and metal cost of the shots of the Exploiters and the resources of the teams", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren65.lua: "[zzren65]" logs the cost of a shot of some weapons and the resources of every team.
local function log(...) Spring.Echo("[zzren65] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f ~= 100 then return end
	for _, n in ipairs({ "cormexp", "corexp", "corllt", "armamex", "armbanth", "corjugg", "armpw", "corfus", "armfus", "corafus", "legfus" }) do
		local ud = UnitDefNames[n]
		if ud then
			for i, wp in ipairs(ud.weapons) do
				local wd = WeaponDefs[wp.weaponDef]
				log(n .. "#" .. i, wd.name, "energyCost", tostring(wd.energyCost), "metalCost", tostring(wd.metalCost), "reload", tostring(wd.reload))
			end
			if #ud.weapons == 0 then log(n, "has no weapon") end
		end
	end
	for _, t in ipairs(Spring.GetTeamList()) do
		local e, es = select(1, Spring.GetTeamResources(t, "energy")), select(2, Spring.GetTeamResources(t, "energy"))
		local m = select(1, Spring.GetTeamResources(t, "metal"))
		log("team", t, "energy", tostring(e), "storage", tostring(es), "metal", tostring(m), "allied", tostring(Spring.AreTeamsAllied(t, Spring.GetMyTeamID())))
	end
	Spring.SendCommands("quitforce")
end
