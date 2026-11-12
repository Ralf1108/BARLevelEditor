function widget:GetInfo() return { name = "zz ren86", desc = "test only: reverse from standing starts with a short forward drive", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren86.lua: a Pawn stands, then S is held for 60 frames; logs z (the unit looks along +z: forward = z grows) and the speed every 5 frames. Lines "[zzren86]".
local R
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 120 then R.keys = 4 end
	if f == 200 then R.keys = 0 end
	if f >= 110 and f <= 230 and f % 5 == 0 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local vx, _, vz = Spring.GetUnitVelocity(R.unit)
		Spring.Echo(string.format("[zzren86] f %d keys %d z %.1f speed %.1f", f, R.keys or 0, z, 30 * math.sqrt(vx * vx + vz * vz)))
	end
	if f == 240 then Spring.SendCommands("quitforce") end
end
