function widget:GetInfo() return { name = "zz sight", desc = "test only: the sight of a unit with Renegade (3 times) and the Radar Pulse of Evolution (G.setSight)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTakeover -Evo -EvoTest -Debug -Widget zz_sight.lua: the player takes over its Evolution unit (3 times the sight), uses the power-up Radar Pulse
-- (evo|debug|8, evo|use|3: 2500 for 5 s) and the sight must be 3 times again after it, then 1 times after the player leaves the unit. Lines "[zzsight]": los and airLos.
local function log(...) Spring.Echo("[zzsight] " .. table.concat({ ... }, " ")) end
local unit
local function sight(tag)
	local u = unit
	if not u then log(tag, "no unit") return end
	log(tag, "los", tostring(Spring.GetUnitSensorRadius and Spring.GetUnitSensorRadius(u, "los")), "airLos", tostring(Spring.GetUnitSensorRadius and Spring.GetUnitSensorRadius(u, "airLos")),
		"def los", tostring(UnitDefs[Spring.GetUnitDefID(u)].losRadius))
end
function widget:GameFrame(f)
	local team = Spring.GetMyTeamID()
	if f == 100 then
		unit = Spring.GetTeamRulesParam(team, "evoUnit")
		sight("before the takeover")
		if unit and unit > 0 then Spring.SendLuaRulesMsg("ren|possess|" .. unit) end
	end
	if f == 140 then sight("taken over (3 times)") end
	if f == 150 then Spring.SendLuaRulesMsg("evo|debug|8") end
	if f == 160 then Spring.SendLuaRulesMsg("evo|use|3") end
	if f == 180 then sight("pulse running (2500)") end
	if f == 400 then sight("pulse over (3 times again)") end
	if f == 420 then Spring.SendLuaRulesMsg("ren|release") end
	if f == 450 then sight("left the unit (own sight)") end
	if f == 470 then Spring.SendCommands("quitforce") end
end
