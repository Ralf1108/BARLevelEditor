function widget:GetInfo() return { name = "zz ren75", desc = "test only: Renegade laser aimed through the enemy at the point behind it", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren75.lua: the player becomes a Commander (corkorg, beam laser), the enemy (ren|test|1) stands in front, the right button is held
-- while the crosshair points at the enemy. Logs what the crosshair hits, the point behind it, the health of the enemy; a screenshot while firing. Lines "[zzren75]".
local function log(...) Spring.Echo("[zzren75] " .. table.concat({ ... }, " ")) end
local R, enemy, enemyD
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|corkorg") end
	if f == 110 then Spring.SendLuaRulesMsg("ren|test|1") end -- (an enemy right in front of the unit)
	if f >= 140 and f % 30 == 0 and not enemy and R.unit then -- (the enemy is found by position)
		local ux, uy, uz = Spring.GetUnitPosition(R.unit)
		for _, u in ipairs(Spring.GetAllUnits()) do
			if u ~= R.unit and not Spring.AreTeamsAllied(Spring.GetUnitTeam(u), Spring.GetUnitTeam(R.unit)) then
				local x, y, z = Spring.GetUnitPosition(u)
				if x and (not enemy or (x - ux) ^ 2 + (z - uz) ^ 2 < enemyD) then enemy = u; enemyD = (x - ux) ^ 2 + (z - uz) ^ 2 end
			end
		end
		if enemy then log("enemy", tostring(enemy), string.format("%.0f %.0f", Spring.GetUnitPosition(enemy))) end
	end
	if f > 140 and f < 700 and enemy and Spring.ValidUnitID(enemy) and R.unit then
		-- the aim follows the enemy; the right button is held when it is within 850
		local ux, uy, uz = Spring.GetUnitPosition(R.unit)
		local x, y, z = Spring.GetUnitPosition(enemy)
		local d = math.sqrt((x - ux) ^ 2 + (z - uz) ^ 2)
		R.yaw = math.deg(math.atan2(x - ux, z - uz))
		R.pitch = math.deg(math.atan2(y + 10 - (uy + 60), d))
		R.fire = 2
		if f % 20 == 0 then
			local hp = Spring.GetUnitHealth(enemy)
			log("f", f, "dist", string.format("%.0f", d), "hit", R.hit and R.hit.kind or "none", "far", R.hit and R.hit.far and string.format("%.0f %.0f %.0f", unpack(R.hit.far)) or "none", "enemy hp", string.format("%.0f", hp or -1))
		end
		if not R.shotDone and f % 20 == 0 and f > 300 then R.shotDone = true; Spring.SendCommands("screenshot") end
	end
	if f == 720 then Spring.SendCommands("quitforce") end
end
