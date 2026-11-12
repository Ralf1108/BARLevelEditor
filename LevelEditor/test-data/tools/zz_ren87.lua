function widget:GetInfo() return { name = "zz ren87", desc = "test only: walking within 10 degrees of the view points the body exactly along it", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren87.lua: a Pawn stands looking along +z, the view yaw is 8 degrees, W is held; logs the body direction in degrees and the path angle every 10 frames. Lines "[zzren87]".
local R, x0, z0
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 90 and R.unit then local mx, mz = Game.mapSizeX / 2, Game.mapSizeZ / 2; Spring.GiveOrderToUnit(R.unit, CMD.MOVE, { mx, Spring.GetGroundHeight(mx, mz), mz }, 0) end
	if f == 500 then R.yaw = -8; R.keys = 1; x0, _, z0 = Spring.GetUnitPosition(R.unit) end
	if f == 580 then R.keys = 0 end
	if f >= 490 and f <= 590 and f % 10 == 0 and R.unit then
		local x, _, z = Spring.GetUnitPosition(R.unit)
		local hx, _, hz = Spring.GetUnitDirection(R.unit)
		local path = x0 and (x - x0) ^ 2 + (z - z0) ^ 2 > 25 and math.deg(math.atan2(x - x0, z - z0)) or 0
		Spring.Echo(string.format("[zzren87] f %d body %.1f path %.1f", f, math.deg(math.atan2(hx, hz)), path))
	end
	if f == 600 then Spring.SendCommands("quitforce") end
end

