function widget:GetInfo() return { name = "zz evo98", desc = "test only: Team Evolution (at most one level above the lowest mate)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Debug -EvoTeam -Bots 2 -Widget zz_evo98.lua: the player (team 0) and Null1 (team 1) are one alliance, Null2 (team 2) the enemy.
-- Level Up of the player (evo|debug|2) to level 2; a second one waits (team 1 is on level 1: evoWait 1, the points are kept); the mate levels up (evo|test|9): the player follows to
-- level 3; a loss (evo|test|8) costs a level as usual. Lines "[zzevo98]".
local function log(...) Spring.Echo("[zzevo98] " .. table.concat({ ... }, " ")) end
local function state(tag)
	local t = {}
	for team = 0, 2 do
		local u = Spring.GetTeamRulesParam(team, "evoUnit") or 0
		local ud = u > 0 and UnitDefs[Spring.GetUnitDefID(u) or -1]
		t[#t + 1] = string.format("team %d level %s points %s wait %s unit %s", team, tostring((Spring.GetTeamRulesParam(team, "evoStage"))), tostring((Spring.GetTeamRulesParam(team, "evoXp"))),
			tostring((Spring.GetTeamRulesParam(team, "evoWait"))), ud and ud.name or "-")
	end
	log(tag, table.concat(t, " | "))
end
function widget:GameFrame(f)
	if f == 120 then state("start") Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 140 then state("after Level Up of team 0") Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 160 then state("after a second Level Up (waits for team 1)") Spring.SendLuaRulesMsg("evo|test|9") end
	if f == 180 then state("after the Level Up of the mate") Spring.SendLuaRulesMsg("evo|test|8") end
	if f == 200 then state("after the loss of team 0") end
	if f == 360 then state("back"); Spring.SendCommands("quitforce") end
end
