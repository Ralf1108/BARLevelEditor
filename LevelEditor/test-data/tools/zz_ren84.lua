function widget:GetInfo() return { name = "zz ren84", desc = "test only: a Renegade aircraft with no health left crashes", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren84.lua (variants: unit name in the game option... edit UNIT): the player becomes an aircraft, climbs (W and Space), then takes lethal
-- damage (ren|test|5) with the keys still held; logs height, health and the state of the move type every 15 frames. Lines "[zzren84]".
local UNIT = "armbrawl"
local function log(...) Spring.Echo("[zzren84] " .. table.concat({ ... }, " ")) end
local R
local dead
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 0, 10 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|" .. UNIT) end
	if f == 140 then R.keys = 1 + 16 end
	if f == 400 then Spring.SendLuaRulesMsg("ren|test|5"); log("lethal damage sent") end
	if f >= 380 and f % 10 == 0 and f <= 700 then
		local u = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit")
		if u and u > 0 and Spring.ValidUnitID(u) then
			local x, y, z = Spring.GetUnitPosition(u)
			local hp = Spring.GetUnitHealth(u)
			local ok, md = pcall(Spring.GetUnitMoveTypeData, u)
			log("f", f, "unit", u, "height", string.format("%.0f", y - Spring.GetGroundHeight(x, z)), "health", tostring(hp), "state", tostring(ok and md and md.aircraftState), "dead", tostring(Spring.GetUnitIsDead(u)))
		elseif not dead then
			dead = true
			log("f", f, "no unit any more")
		end
	end
	if f == 720 then Spring.SendCommands("quitforce") end
end
