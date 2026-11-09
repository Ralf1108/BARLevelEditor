function widget:GetInfo() return { name = "zz watch", desc = "test only: wild units that a player sees keep their level", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_watch.lua (one instance, speed 10): at frame 60 the star button (random levels for all players: the wild
-- units are off the level of the weakest player), then the gadget replaces one wild unit every 3 s that no player sees and that is farther than 900 Elmo from a
-- player's unit; the test lines "[Evolution] test: wild units replaced n, left as they are because a player sees them k" show that the watched ones are left (k > 0).
-- Ends at frame 3600.
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10") end
	if f >= 60 and f <= 3000 and f % 500 == 60 then Spring.SendLuaRulesMsg("evo|debug|11") end   -- (random levels again and again: the weakest player changes)
	if f == 3600 then Spring.SendCommands("quitforce") end
end
