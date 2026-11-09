function widget:GetInfo() return { name = "zz hell", desc = "test only: Hell on Earth and Heaven on Earth", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Debug [-Gift 1|2] -Widget zz_hell.lua (one instance, speed 10): Armageddon by the debug message, the gift (1 Hell on Earth,
-- 2 Heaven on Earth), the number of units of the own team every 300 frames (8 at once, one more every 30 s = 900 frames); at frame 400 all units except the own
-- evo unit are destroyed with the cheat command (a lost one is replaced: the number must come back to 8 + 1). Ends at frame 2400. Lines "[zzhell]".
local function log(...) Spring.Echo("[zzhell] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	local me = Spring.GetMyTeamID()
	local gift = tonumber((Spring.GetModOptions() or {}).lanevogift) or 1
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10") end
	if f == 30 then Spring.SendLuaRulesMsg("evo|debug|1") end
	if f == 60 then Spring.SendLuaRulesMsg("evo|gift|" .. gift) end
	if f >= 90 and f % 300 == 0 then log("frame", f, "units of the team", Spring.GetTeamUnitCount(me)) end
	if f == 400 then
		local own = Spring.GetTeamRulesParam(me, "evoUnit")
		local list = {}
		for _, id in ipairs(Spring.GetTeamUnits(me)) do if id ~= own then list[#list + 1] = id end end
		log("destroying", #list, "units")
		Spring.SendCommands("cheat 1")
		Spring.SelectUnitArray(list)
		Spring.SendCommands("destroy")
	end
	if f == 450 or f == 600 then log("frame", f, "units of the team", Spring.GetTeamUnitCount(me)) end
	if f == 2400 then Spring.SendCommands("quitforce") end
end
