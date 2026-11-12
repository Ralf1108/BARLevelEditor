function widget:GetInfo() return { name = "zz ren88", desc = "test only: fires at the nearest enemy to see the damage numbers", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenBots 3 -Widget zz_ren88.lua: aims at the test enemy 150 Elmo ahead (ren|test|1) and fires; screenshots show the red damage numbers. Lines "[zzren88]".
local R
function widget:GameFrame(f)
	R = WG.renegade
	if not R or not R.unit then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|test|1") end
	if f >= 130 and f < 400 and f % 3 == 0 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local best, bd
		for _, id in ipairs(Spring.GetAllUnits()) do
			if not Spring.IsUnitAllied(id) then
				local ex, ey, ez = Spring.GetUnitPosition(id)
				local d = (ex - x) ^ 2 + (ez - z) ^ 2
				if not bd or d < bd then best, bd = id, d end
			end
		end
		if best then
			local ex, ey, ez = Spring.GetUnitPosition(best)
			R.yaw = math.deg(math.atan2(ex - x, ez - z))
			R.pitch = math.deg(math.atan2(ey - y, math.sqrt(bd)))
			R.fire = 1
			if f % 30 == 0 then Spring.Echo(string.format("[zzren88] f %d enemy %d dist %.0f", f, best, math.sqrt(bd))) end
		end
	end
	if f == 190 then Spring.SendCommands("screenshot png") end
	if f == 215 then Spring.SendCommands("screenshot png") end
	if f == 420 then R.fire = 0; Spring.SendCommands("quitforce") end
end
