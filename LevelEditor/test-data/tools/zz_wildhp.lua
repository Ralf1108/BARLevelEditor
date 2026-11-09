function widget:GetInfo() return { name = "zz wildhp", desc = "test only: health of the wild (Gaia) units of Evolution", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -Widget zz_wildhp.lua (one instance, speed 10): at frame 300 and 900 the health of every Gaia unit is logged: the fraction
-- health / maxHealth (what the health bar shows) and maxHealth / the health of the unit definition. Lines "[zzwildhp]". Ends at frame 1000.
local function log(...) Spring.Echo("[zzwildhp] " .. table.concat({ ... }, " ")) end
local function report(f)
	local gaia = Spring.GetGaiaTeamID()
	local n, sumFrac, minFrac, maxFrac, sumDef = 0, 0, 2, 0, 0
	for _, id in ipairs(Spring.GetTeamUnits(gaia)) do
		local hp, maxHp = Spring.GetUnitHealth(id)
		local ud = UnitDefs[Spring.GetUnitDefID(id)]
		if hp and maxHp and ud and ud.health and ud.health > 0 then
			local frac = hp / maxHp
			n = n + 1; sumFrac = sumFrac + frac; minFrac = math.min(minFrac, frac); maxFrac = math.max(maxFrac, frac)
			sumDef = sumDef + maxHp / ud.health
			if n <= 6 then log("unit", ud.name, "health", math.floor(hp), "max", math.floor(maxHp), "def", math.floor(ud.health)) end
		end
	end
	if n > 0 then log("frame", f, "gaia units", n, "health/max avg", string.format("%.2f", sumFrac / n), "min", string.format("%.2f", minFrac), "max", string.format("%.2f", maxFrac), "max/def avg", string.format("%.2f", sumDef / n)) end
end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10", "cheat 1", "globallos") end
	if f == 300 or f == 900 then report(f) end
	if f == 1000 then Spring.SendCommands("quitforce") end
end
