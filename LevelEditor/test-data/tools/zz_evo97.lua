function widget:GetInfo() return { name = "zz evo97", desc = "test only: Evolution, choose the unit of the next level", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Debug -EvoChoose -Widget zz_evo97.lua: Level Up by the debug message (evo|debug|2) offers three units (team rules evoChoice), the unit
-- stays until the choice; "evo|pick|2" evolves into the second one; the next Level Up without a choice takes one of the three after 10 s; a choice is dropped when the unit is lost
-- (evo|test|8). Lines "[zzevo97]", a picture of the cards at frame 135.
local function log(...) Spring.Echo("[zzevo97] " .. table.concat({ ... }, " ")) end
local names
local function state(tag)
	local team = Spring.GetMyTeamID()
	local u = Spring.GetTeamRulesParam(team, "evoUnit") or 0
	local ud = u > 0 and UnitDefs[Spring.GetUnitDefID(u) or -1]
	log(tag, "level", tostring((Spring.GetTeamRulesParam(team, "evoStage"))), "unit", ud and ud.name or "-", "choice", tostring((Spring.GetTeamRulesParam(team, "evoChoice"))),
		"window", tostring(WG.evoWindowOpen))
end
function widget:GameFrame(f)
	local team = Spring.GetMyTeamID()
	if f == 120 then state("before"); Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 130 then
		state("after Level Up")
		names = {}
		for n in tostring((Spring.GetTeamRulesParam(team, "evoChoice"))):gmatch("[^,]+") do names[#names + 1] = n end
	end
	if f == 135 then Spring.SendCommands("screenshot png") end
	if f == 150 then Spring.SendLuaRulesMsg("evo|pick|2") end
	if f == 160 then state("after the pick of " .. tostring(names and names[2])) end
	if f == 200 then Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 210 then state("second Level Up") end
	if f == 520 then state("10 s later (a random one of the three)") end
	if f == 600 then Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 610 then state("third Level Up"); Spring.SendLuaRulesMsg("evo|test|8") end
	if f == 630 then state("lost during the choice") end
	if f == 800 then state("back"); Spring.SendCommands("quitforce") end
end
