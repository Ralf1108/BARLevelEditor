function widget:GetInfo() return { name = "zz evo98", desc = "test only: Team Evolution (shared points and level)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Debug -EvoTeam -Bots 2 -Widget zz_evo98.lua: the player (team 0) and Null1 (team 1) are one alliance, Null2 (team 2) the enemy. Level Up
-- of the player (evo|debug|2) raises team 1 too, team 2 stays; the points of the alliance are the same; a loss (evo|test|8) keeps the level and sets the points of both to 0.
-- Lines "[zzevo98]".
local function log(...) Spring.Echo("[zzevo98] " .. table.concat({ ... }, " ")) end
local function state(tag)
	local t = {}
	for team = 0, 2 do
		local u = Spring.GetTeamRulesParam(team, "evoUnit") or 0
		local ud = u > 0 and UnitDefs[Spring.GetUnitDefID(u) or -1]
		t[#t + 1] = string.format("team %d level %s points %s unit %s", team, tostring((Spring.GetTeamRulesParam(team, "evoStage"))), tostring((Spring.GetTeamRulesParam(team, "evoXp"))), ud and ud.name or "-")
	end
	log(tag, table.concat(t, " | "))
end
function widget:GameFrame(f)
	if f == 120 then state("start") Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 140 then state("after Level Up of team 0") Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 160 then state("after a second Level Up") Spring.SendLuaRulesMsg("evo|test|8") end
	if f == 180 then state("after the loss of team 0") end
	if f == 360 then state("back"); Spring.SendCommands("quitforce") end
end
