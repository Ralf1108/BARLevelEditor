-- Rules about BAR unit definitions that the Level Editor, the BluePrinter, the Tower Defense gadget and the scenario need in the
-- same way. Small and free of game state, so gadgets (synced) and widgets can load it with VFS.Include("luaui/Include/bar_rules.lua").
-- (scenario/template/scenario_briefing.lua runs alone in a foreign BAR and keeps its own copy of techLevel: change both together.)
local R = {}

-- BAR files some Epic units under a lower tech level (Epic Grunt: T1, Epic Skater: T2): every Epic unit counts as T3
function R.techLevel(ud)
	local t = tonumber(ud.customParams and ud.customParams.techlevel) or 1
	if t < 3 then
		local human = ud.translatedHumanName or ud.humanName or ""
		local mv = ud.moveDef and ud.moveDef.name or ""
		if human:find("^Epic") or tostring(mv):find("epic", 1, true) then
			return 3
		end
	end
	return t
end

-- Kind of a structure for the Tower Defense build restriction: "economy" = metal and energy structures (extractors, solar,
-- wind, geothermal, fusion, storage, converters), "tower" = armed structure, "radar", nil = the rest (factories included)
function R.buildClass(ud)
	local cp = ud.customParams or {}
	if ud.isFactory then
		return nil
	end
	local ug = cp.unitgroup
	if ug == "energy" or ug == "metal" or (tonumber(ud.extractsMetal) or 0) > 0 then
		return "economy"
	elseif #ud.weapons > 0 and ug ~= "explo" then
		return "tower"
	elseif (tonumber(ud.radarDistance) or 0) > 0 then
		return "radar"
	end
	return nil
end

-- True when at least one weapon can hit the ground (pure anti-air units are of no use against walking enemies)
function R.hitsGround(ud)
	for _, w in ipairs(ud.weapons) do
		local wd = WeaponDefs[w.weaponDef]
		if wd and wd.canAttackGround then
			return true
		end
	end
	return false
end

return R
