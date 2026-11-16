function widget:GetInfo() return { name = "zz ren93", desc = "test only: Renegade kill goal, kill feed, banner of the end", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenBots 2 -RenGoal 3 -Widget zz_ren93.lua: three kills by the hook ren|test|9 (the nearest enemy is destroyed by the
-- player's unit): the kill feed gets a line each time, the third kill wins the round (game rules renWinner, renResult, renOver), the banner shows, the game ends
-- 8 s later (widget:GameOver). Lines "[zzren93]", a picture of the banner and the feed in <Work>\data\screenshots.
local function log(...) Spring.Echo("[zzren93] " .. table.concat({ ... }, " ")) end
local over = false
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	local team = Spring.GetMyTeamID()
	if f == 150 or f == 210 or f == 270 then Spring.SendLuaRulesMsg("ren|test|1") end
	if f == 160 or f == 220 or f == 280 then Spring.SendLuaRulesMsg("ren|test|9") end
	if f == 165 or f == 225 or f == 285 then
		local e = R.H and R.H.lastKill
		log("frame", f, "kills", tostring(Spring.GetTeamRulesParam(team, "renKills")), "goal", tostring(Spring.GetGameRulesParam("renGoal")),
			"feed:", e and (tostring(e.killer) .. " -> " .. tostring(e.victim)) or "none", "over", tostring(Spring.GetGameRulesParam("renOver")))
	end
	if f == 300 then
		log("after the third kill: winner", tostring(Spring.GetGameRulesParam("renWinner")), "my team", team, "result:", tostring(Spring.GetGameRulesParam("renResult")),
			"over at", tostring(Spring.GetGameRulesParam("renOver")), "title", R.H.goalTitle())
		Spring.SendCommands("screenshot png")
	end
	if f == 700 then log("still running at frame 700: game over", tostring(over)); Spring.SendCommands("quitforce") end
end
function widget:GameOver(winners)
	over = true
	log("GameOver at frame", Spring.GetGameFrame(), "winning ally teams", table.concat(winners or {}, ","))
	Spring.SendCommands("quitforce")
end
