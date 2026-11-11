function widget:GetInfo() return { name = "zz tech", desc = "test only: tech level and metal cost of every armed unit, lines [zztech]", layer = 0, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -Widget zz_tech.lua: one line "[zztech] code;techlevel;metal" per unit of Armada, Cortex and Legion with a weapon (used to find the size limits of the
-- weapon categories of Renegade, see weapon_categories.py). Then the game ends (quitforce).
local done = false
function widget:GameFrame(f)
	if done or f < 30 then return end
	done = true
	for _, ud in pairs(UnitDefs) do
		local fac = ud.name:sub(1, 3)
		if (fac == "arm" or fac == "cor" or fac == "leg") and not ud.name:find("scav") and not ud.name:find("raptor") and #(ud.weapons or {}) > 0 then
			Spring.Echo(string.format("[zztech] %s;%s;%.0f", ud.name, tostring(ud.customParams.techlevel or "?"), ud.metalCost or 0))
		end
	end
	Spring.Echo("[zztech] done")
	Spring.SendCommands("quitforce")
end
