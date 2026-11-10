function widget:GetInfo() return { name = "zz ren30", desc = "test only: height of a gunship that flies in the normal game, with the height fields of its definition", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren30.lua: like zz_ren23 (an enemy Roughneck armbrawl is spawned 1000 Elmo away and fights toward the player, the game's own orders),
-- but logs the height above the ground, the ground and the sea level from the first frame on (the approach = a plain fight/move order), and the height fields of the definition. Lines "[zzren30]".
local function log(...) Spring.Echo("[zzren30] " .. table.concat({ ... }, " ")) end
local R, gun, me
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then
		Spring.SendLuaRulesMsg("ren|unit|armbanth")
		local ud = UnitDefNames.armbrawl
		for _, k in ipairs({ "cruiseAltitude", "hoverAttack", "verticalSpeed", "maxAcc", "speed", "turnRate", "sightDistance", "isHoveringAirUnit", "canMoveAlways", "maxWaterDepth", "wantedHeight", "model" }) do
			local ok, v = pcall(function() return ud[k] end)
			log("def", k, ok and tostring(v) or "error")
		end
	end
	if f == 120 then Spring.SendLuaRulesMsg("ren|spawn|armbrawl") end
	if f >= 121 and not gun then
		for _, id in ipairs(Spring.GetTeamUnits(1)) do if UnitDefs[Spring.GetUnitDefID(id)].name == "armbrawl" then gun = id end end
		me = R.unit
	end
	if gun and f % 15 == 0 and f <= 700 then
		local x, y, z = Spring.GetUnitPosition(gun)
		if not x then log("f", f, "gunship gone"); gun = nil return end
		local mx, my, mz = Spring.GetUnitPosition(me)
		local g = Spring.GetGroundHeight(x, z)
		log("f", f, "above ground", string.format("%.0f", y - g), "ground", string.format("%.0f", g), "sea level", string.format("%.0f", y), "distance to the player", string.format("%.0f", math.sqrt((x - mx) ^ 2 + (z - mz) ^ 2)), "target type", tostring((Spring.GetUnitWeaponTarget(gun, 1))))
	end
	if f == 720 then Spring.SendCommands("quitforce") end
end
