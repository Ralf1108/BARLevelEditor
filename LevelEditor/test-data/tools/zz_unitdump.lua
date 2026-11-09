function widget:GetInfo() return { name = "zz unit dump", desc = "test only: every mobile Armada, Cortex and Legion unit with its numbers", layer = 0, enabled = true } end
-- Test widget of pve_test.ps1 -Widget zz_unitdump.lua: one line "[zzunit] ..." (fields separated by ;) per mobile unit of Armada, Cortex and Legion with or without
-- weapons: name; faction; human name; tech level; dps against the default armor (without anti air, paralyzers, stockpile weapons, the D-gun); dps of the anti air weapons;
-- health; metal cost; speed; longest range; move class; flags (fly, builder, water, commander); the weapons as type:range:damage x projectiles x salvo / reload.
-- Then the game ends (quitforce). Used by evolution_units.py to make the table of the unit candidates of Evolution.
local done = false
function widget:GameFrame(f)
	if done or f < 30 then return end
	done = true
	local types = Game.armorTypes or {}
	local defIdx, vtolIdx = types.default or 0, types.vtol or 14
	for _, ud in pairs(UnitDefs) do
		local fac = ud.name:sub(1, 3)
		if (fac == "arm" or fac == "cor" or fac == "leg") and ((ud.speed or 0) > 0 or ud.canFly) and not ud.isBuilding and not ud.customParams.iscommander then
			local dps, aa, range, ws = 0, 0, 0, {}
			for _, w in ipairs(ud.weapons or {}) do
				local wd = WeaponDefs[w.weaponDef]
				if wd and wd.damages then
					local dmg = tonumber(wd.damages[defIdx]) or 0
					local dv = tonumber(wd.damages[vtolIdx]) or 0
					local n = (tonumber(wd.projectiles) or 1) * (tonumber(wd.salvoSize) or 1)
					local reload = tonumber(wd.reload) or 0
					local isAA = dv > dmg
					local d = (reload > 0) and (math.max(dmg, dv) * n / reload) or 0
					if not wd.paralyzer and wd.type ~= "DGun" and not wd.stockpile and dmg > 1 or isAA then
						if isAA then aa = aa + d else dps = dps + d; range = math.max(range, tonumber(wd.range) or 0) end
					end
					ws[#ws + 1] = string.format("%s:%.0f:%.0f", tostring(wd.type), tonumber(wd.range) or 0, d)
				end
			end
			local flags = {}
			if ud.canFly then flags[#flags + 1] = "fly" end
			if ud.isBuilder then flags[#flags + 1] = "builder" end
			if (ud.minWaterDepth or 0) > 0 then flags[#flags + 1] = "water" end
			Spring.Echo(string.format("[zzunit] %s;%s;%s;%s;%.1f;%.1f;%.0f;%.0f;%.0f;%.0f;%s;%s;%s", ud.name, ud.name:sub(1, 3), ud.translatedHumanName or ud.humanName or "",
				tostring(ud.customParams.techlevel or "?"), dps, aa, ud.health, ud.metalCost, ud.speed, range, ud.moveDef and ud.moveDef.name or "-", table.concat(flags, ","), table.concat(ws, " ")))
		end
	end
	Spring.Echo("[zzunit] done")
	Spring.SendCommands("quitforce")
end
