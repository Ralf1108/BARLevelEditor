function widget:GetInfo() return { name = "zz dps dump", desc = "test only", layer = 0, enabled = true } end
-- Writes one line per armed mobile ground unit: faction, name, tech, dps against default armor, health, metal, speed, range, human name
local done = false
function widget:GameFrame(f)
	if done or f < 30 then return end
	done = true
	local types = Game.armorTypes or {}
	local defIdx, vtolIdx = types.default or 0, types.vtol or 14
	for id, ud in pairs(UnitDefs) do
		local fac = ud.name:sub(1, 3)
		if (fac == "arm" or fac == "cor" or fac == "leg") and not ud.canFly and (ud.speed or 0) > 0 and not ud.isBuilding and not ud.isBuilder
			and (ud.minWaterDepth or 0) <= 0 and #(ud.weapons or {}) > 0 and not ud.customParams.iscommander then
			local dps, range = 0, 0
			for _, w in ipairs(ud.weapons) do
				local wd = WeaponDefs[w.weaponDef]
				if wd and wd.damages and not wd.paralyzer and wd.type ~= "DGun" and not wd.stockpile then
					local aa = (tonumber(wd.damages[vtolIdx]) or 0) > (tonumber(wd.damages[defIdx]) or 0)
					local dmg = tonumber(wd.damages[defIdx]) or 0
					local reload = tonumber(wd.reload) or 0
					if not aa and dmg > 1 and reload > 0 then
						dps = dps + dmg * (tonumber(wd.projectiles) or 1) * (tonumber(wd.salvoSize) or 1) / reload
						range = math.max(range, tonumber(wd.range) or 0)
					end
				end
			end
			if dps > 0 then
				Spring.Echo(string.format("[zzdps] %s;%s;%s;%.0f;%.0f;%.0f;%.0f;%.0f;%s;%s", fac, ud.name, tostring(ud.customParams.techlevel or "?"), dps, ud.health, ud.metalCost, ud.speed, range,
					ud.translatedHumanName or ud.humanName or "", ud.moveDef and ud.moveDef.name or "-"))
			end
		end
	end
	Spring.Echo("[zzdps] done")
	Spring.SendCommands("quitforce")
end
