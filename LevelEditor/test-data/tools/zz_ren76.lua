function widget:GetInfo() return { name = "zz ren76", desc = "test only: does the Juggernaut (corkorg) move from the start point?", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren76.lua: the player becomes a Juggernaut (corkorg), looks into the map (yaw 90) and holds W; logs the position, the speed and
-- the number of look frames that were skipped. Lines "[zzren76]".
local function log(...) Spring.Echo("[zzren76] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|corkorg") end
	if f == 120 then R.keys = 1 end
	if f >= 100 and f % 30 == 0 and f <= 500 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local vx, _, vz = Spring.GetUnitVelocity(R.unit)
		log("f", f, "pos", string.format("%.0f %.0f %.0f", x, y, z), "speed", string.format("%.2f", math.sqrt((vx or 0) ^ 2 + (vz or 0) ^ 2)), "radius", string.format("%.0f", Spring.GetUnitRadius(R.unit)), "keys", R.keys)
	end
	if f == 520 then Spring.SendCommands("quitforce") end
end
