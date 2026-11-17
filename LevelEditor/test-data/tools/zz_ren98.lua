function widget:GetInfo() return { name = "zz ren98", desc = "test only: Renegade, the mode Race", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenMode race -Widget zz_ren98.lua: the 8 checkpoints (game rules renRaceCps), the start at frame 600 (the unit on the start grid),
-- then ren|test|11 puts the unit onto its next checkpoint every 20 frames: 2 laps of 8 checkpoints, the finish, the winner and GameOver; the sounds checkpoint and lap.
-- Lines "[zzren98]", pictures of the countdown and of the race (the ring, the arrow).
local function log(...) Spring.Echo("[zzren98] " .. table.concat({ ... }, " ")) end
local over, steps = false, 0
local function state(tag)
	local team = Spring.GetMyTeamID()
	local u = Spring.GetTeamRulesParam(team, "renUnit") or 0
	local x, _, z = Spring.GetUnitPosition(u > 0 and u or -1)
	local M = WG.renegade and WG.renegade.M
	log(tag, "lap", tostring((Spring.GetTeamRulesParam(team, "renRaceLap"))), "cp", tostring((Spring.GetTeamRulesParam(team, "renRaceCp"))), "place", tostring((Spring.GetTeamRulesParam(team, "renRacePos"))),
		"time", tostring((Spring.GetTeamRulesParam(team, "renRaceTime"))), "unit at", x and (math.floor(x) .. " " .. math.floor(z)) or "-",
		"sounds checkpoint", tostring(M and M.played.checkpoint), "lap", tostring(M and M.played.lap), "over", tostring((Spring.GetGameRulesParam("renOver"))))
end
function widget:GameFrame(f)
	if f == 60 then local R = WG.renegade; if R then R.fake = true; R.yaw, R.pitch = 0, 0 end end
	if f == 300 then log("checkpoints:", tostring((Spring.GetGameRulesParam("renRaceCps"))), "laps", tostring((Spring.GetGameRulesParam("renRaceLaps")))) end
	if f == 560 then Spring.SendCommands("screenshot png") end
	if f == 620 then state("after the start") end
	if f > 640 and f % 20 == 0 and steps < 16 then
		steps = steps + 1
		Spring.SendLuaRulesMsg("ren|test|11")
		if steps == 3 then Spring.SendCommands("screenshot png") end
		if steps == 8 or steps == 9 or steps == 16 then widget.check = f + 10 end
	end
	if widget.check and f == widget.check then state("after " .. steps .. " checkpoints") end
	if f == 2000 then log("timeout: over", tostring(over)); Spring.SendCommands("quitforce") end
end
function widget:GameOver(winners)
	over = true
	log("GameOver at frame", Spring.GetGameFrame(), "winners", table.concat(winners or {}, ","), "result:", tostring((Spring.GetGameRulesParam("renResult"))))
	Spring.SendCommands("quitforce")
end
