function widget:GetInfo() return { name = "zz ren69", desc = "test only: an Exploiter fires at an enemy unit", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren69.lua: the player becomes an Advanced Exploiter, a test enemy stands 150 Elmo ahead (ren|test|1, hold fire), the crosshair is on it, the left and right button
-- are pressed: "[zzren69]" logs what the crosshair hits and the health of the enemy.
local function log(...) Spring.Echo("[zzren69] " .. table.concat({ ... }, " ")) end
local enemy
function widget:GameFrame(f)
	local R = WG.renegade
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|cormexp") end
	if f == 120 then Spring.SendLuaRulesMsg("ren|test|1") end
	if f == 150 then
		for _, id in ipairs(Spring.GetAllUnits()) do
			if not Spring.IsUnitAllied(id) then enemy = id end
		end
		log("enemy", tostring(enemy), "hp", enemy and string.format("%.0f", (Spring.GetUnitHealth(enemy))) or "?")
		if enemy then
			local px, py, pz = Spring.GetUnitViewPosition(R.unit)
			py = py + Spring.GetUnitHeight(R.unit) * 0.85
			local x, y, z = Spring.GetUnitPosition(enemy)
			y = y + Spring.GetUnitHeight(enemy) * 0.5
			R.yaw = math.deg(math.atan2(x - px, z - pz)) % 360
			R.pitch = math.deg(math.atan2(y - py, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)))
		end
	end
	if f == 190 then log("crosshair", tostring(R.hit and R.hit.kind), tostring(R.hit and R.hit.unit), "udist", tostring(R.hit and math.floor(R.hit.udist)), "best", tostring(R.best)); R.fire = 3 end
	if f == 330 then R.fire = 0; log("after the buttons: enemy hp", enemy and string.format("%.0f", (Spring.GetUnitHealth(enemy) or -1)) or "?"); Spring.SendCommands("quitforce") end
end
