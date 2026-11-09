function widget:GetInfo() return { name = "zz bld", desc = "test only: Evolution buildings change to T2 and back", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoStage 6 -EvoTest -Debug -Widget zz_bld.lua (one instance, speed 10): every player starts on level 6, so the radars, solar collectors
-- and wind turbines that nobody sees become T2 (lines "[Evolution] test: building armrad -> armarad"); the star button (random levels) at frames 2400 and 3600 may
-- take every player below level 6: then they go back. Lines "[zzbld] exists" tell which T2 names the game has. Ends at frame 5400.
function widget:GameFrame(f)
	if f == 5 then
		Spring.SendCommands("setmaxspeed 10", "setminspeed 10")
		local names = { "armarad", "corarad", "legarad", "armadvsol", "coradvsol", "legadvsol", "armwint2", "corwint2", "legwint2" }
		local t = {}
		for _, n in ipairs(names) do t[#t + 1] = n .. "=" .. tostring(UnitDefNames[n] ~= nil) end
		Spring.Echo("[zzbld] exists " .. table.concat(t, " "))
	end
	if f == 2400 or f == 3600 then Spring.SendLuaRulesMsg("evo|debug|11") end
	if f == 5400 then Spring.SendCommands("quitforce") end
end
