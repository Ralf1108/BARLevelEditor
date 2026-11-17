function widget:GetInfo() return { name = "zz ren97", desc = "test only: Renegade, the mode Survival", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenMode survival -Widget zz_ren97.lua: the computer team loses its units, wave 1 comes at frame 450 (the player's unit becomes a level 2
-- unit), ren|test|10 destroys the wave (the break, then wave 2 with a level 3 unit), during wave 2 the own unit is lost (ren|test|2): nobody is left, the waves win, the banner
-- and GameOver. Lines "[zzren97]", pictures of wave 1 and of the end.
local function log(...) Spring.Echo("[zzren97] " .. table.concat({ ... }, " ")) end
local over = false
local function state(tag)
	local u = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit") or 0
	local ud = u > 0 and UnitDefs[Spring.GetUnitDefID(u) or -1]
	log(tag, "wave", tostring((Spring.GetGameRulesParam("renSurvWave"))), "left", tostring((Spring.GetGameRulesParam("renSurvLeft"))), "next", tostring((Spring.GetGameRulesParam("renSurvNext"))),
		"unit", ud and ud.name or "-", "units of team 1", #Spring.GetTeamUnits(1), "Gaia", #Spring.GetTeamUnits(Spring.GetGaiaTeamID()), "over", tostring((Spring.GetGameRulesParam("renOver"))))
end
function widget:GameFrame(f)
	if f == 60 then local R = WG.renegade; if R then R.fake = true; R.yaw, R.pitch = 0, 0 end end
	if f == 400 then state("before the first wave") end
	if f == 470 then state("wave 1"); Spring.SendCommands("screenshot png") end
	if f == 500 then Spring.SendLuaRulesMsg("ren|test|10") end
	if f == 520 then state("after clearing wave 1") end
	if f == 1000 then state("wave 2") end
	if f == 1020 then Spring.SendLuaRulesMsg("ren|test|2") end
	if f == 1040 then state("after the loss"); Spring.SendCommands("screenshot png") end
	if f == 1500 then log("timeout: over", tostring(over)); Spring.SendCommands("quitforce") end
end
function widget:GameOver(winners)
	over = true
	log("GameOver at frame", Spring.GetGameFrame(), "winners", table.concat(winners or {}, ","), "result:", tostring((Spring.GetGameRulesParam("renResult"))))
	Spring.SendCommands("quitforce")
end
