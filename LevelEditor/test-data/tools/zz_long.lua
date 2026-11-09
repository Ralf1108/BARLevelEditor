function widget:GetInfo() return { name = "zz long", desc = "test only: Evolution option Long range", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -Debug [-Long] -Widget zz_long.lua (one instance, speed 10): the debug buttons Level Up (8 times to level 9), then Level Down /
-- Level Up 40 times (levels 8 and 9, a new random unit each time); the gadget logs "[Evolution] ... evolves to level n: Name". Count the long range units
-- (Daedalus on 8, Thermite and Mukade on 9) in the log: with the option some, without it none. Ends at frame 1500.
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10") end
	if f >= 30 and f <= 110 and f % 10 == 0 then Spring.SendLuaRulesMsg("evo|debug|2") end
	if f >= 140 and f < 940 and f % 10 == 0 then Spring.SendLuaRulesMsg(((f - 140) / 10) % 2 == 0 and "evo|debug|3" or "evo|debug|2") end
	if f == 1500 then Spring.SendCommands("quitforce") end
end
