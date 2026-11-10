function widget:GetInfo() return { name = "zz ren23", desc = "test only: how a gunship attacks in the normal game", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren23.lua: the player stays a Pawn, an enemy Roughneck (armbrawl) is spawned 1000 Elmo ahead (ren|spawn|, it fights toward the player with the game's own AI orders: nothing of the Renegade steering). Logs every 15 frames its height, distance to the player, body pitch, weapon direction and the player's health. Lines "[zzren23]".
local function log(...) Spring.Echo("[zzren23] " .. table.concat({ ... }, " ")) end
local R, gun, me
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbanth") end -- (a Titan: it lives long enough to watch the whole attack)
	if f == 120 then Spring.SendLuaRulesMsg("ren|spawn|armbrawl") end
	if f >= 130 and not gun then
		for _, id in ipairs(Spring.GetTeamUnits(1)) do if UnitDefs[Spring.GetUnitDefID(id)].name == "armbrawl" then gun = id end end
		me = R.unit
	end
	if gun and f % 15 == 0 and f <= 1000 then
		local x, y, z = Spring.GetUnitPosition(gun)
		if not x then log("f", f, "gunship gone"); gun = nil return end
		local mx, my, mz = Spring.GetUnitPosition(me)
		local dy = select(2, Spring.GetUnitDirection(gun))
		local _, _, _, wx, wy, wz = Spring.GetUnitWeaponVectors(gun, 1)
		local tt = Spring.GetUnitWeaponTarget(gun, 1)
		log("f", f, "height above ground", string.format("%.0f", y - Spring.GetGroundHeight(x, z)), "horizontal distance", string.format("%.0f", math.sqrt((x - mx) ^ 2 + (z - mz) ^ 2)), "body direction y", string.format("%.2f", dy), "weapon dir y", wy and string.format("%.2f", wy) or "-", "target type", tostring(tt), "bearing from the target", string.format("%.0f", math.deg(math.atan2(x - mx, z - mz))), "my health", string.format("%.0f", Spring.GetUnitHealth(me) or -1))
	end
	if f == 1020 then Spring.SendCommands("quitforce") end
end
