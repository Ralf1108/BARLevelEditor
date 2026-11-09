function widget:GetInfo() return { name = "zz hell", desc = "test only: Hell on Earth", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_hell.lua (one instance, speed 10): Armageddon by the debug button message, the gift Hell on Earth, then
-- logs the number of units of the own team every 300 frames (8 at once, one more every 10 s = 300 frames). Ends at frame 2400. Lines "[zzhell]".
local function log(...) Spring.Echo("[zzhell] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	local me = Spring.GetMyTeamID()
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10") end
	if f == 30 then Spring.SendLuaRulesMsg("evo|debug|1") end
	if f == 60 then Spring.SendLuaRulesMsg("evo|gift|1") end
	if f >= 90 and f % 300 == 0 then log("frame", f, "units of the team", Spring.GetTeamUnitCount(me)) end
	if f == 2400 then Spring.SendCommands("quitforce") end
end
