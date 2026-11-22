function widget:GetInfo() return { name = "zz ren56", desc = "test only: the groups and the weapons of the Karganeth (corkarg)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren56.lua: the player becomes a Karganeth, "[zzren56]" logs the weapon groups (renSlots, renAA, renHY) and the weapon definitions.
local function log(...) Spring.Echo("[zzren56] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|corkarg") end
	if f == 120 then
		local u = R.unit
		log("slots", tostring(Spring.GetUnitRulesParam(u, "renSlots")), "aa", tostring(Spring.GetUnitRulesParam(u, "renAA")), "hy", tostring(Spring.GetUnitRulesParam(u, "renHY")), "pics", tostring(Spring.GetUnitRulesParam(u, "renPics")))
		local ud = UnitDefs[Spring.GetUnitDefID(u)]
		for i, wp in ipairs(ud.weapons) do
			local wd = WeaponDefs[wp.weaponDef]
			local ot = {}
			for k, v in pairs(wp.onlyTargets or {}) do ot[#ot + 1] = tostring(k) .. "=" .. tostring(v) end
			local bt = {}
			for k, v in pairs(wp.badTargets or {}) do bt[#bt + 1] = tostring(k) end
			log(i, wd.name, wd.type, "range", tostring(wd.range), "damage", tostring(wd.damages and wd.damages[0]), "vtol", tostring(wd.damages and wd.damages[Game.armorTypes.vtol or 14]), "tracks", tostring(wd.tracks), "interceptor", tostring(wd.interceptor), "onlyTargets", table.concat(ot, ","), "bad", table.concat(bt, ","), "turret", tostring(wd.turret), "tolerance", tostring(wd.tolerance), "cos", tostring(wp.maxAngleDif))
		end
		Spring.SendCommands("quitforce")
	end
end
