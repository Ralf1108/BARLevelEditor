function widget:GetInfo() return { name = "zz reveal", desc = "test only: a player on level 8 shows on the radar of the others", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_reveal.lua (one instance, speed 10): the debug button Level Up seven times (level 8); the gadget then logs
-- every 5 s "[Evolution] test: <player> (level 8) on the radar of ally team <n>: true" (Spring.IsUnitInRadar of the other ally team); then Level Down (level 7): the lines
-- stop. Ends at frame 2400.
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10") end
	if f >= 30 and f <= 90 and f % 10 == 0 then Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 1500 then Spring.SendLuaRulesMsg("evo|debug|3") end
	if f == 2400 then Spring.SendCommands("quitforce") end
end
