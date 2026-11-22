function widget:GetInfo() return { name = "zz ren98", desc = "test only: Renegade, the mode Race", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenMode race -Widget zz_ren98.lua: the 8 checkpoints (game rules renRaceCps), the racers (renRaceUnits), the pick of another racer
-- (ren|race|pick|n: the unit turns into it), the start at frame 600 (the unit on the start grid), a deadly hit by ren|test|5 that must do nothing (no damage in a race: OK / WRONG), then ren|test|11 puts the unit onto its next checkpoint every 20 frames: 2 laps of
-- 8 checkpoints, the finish, the results (renRaceOver, renRaceResult); New race (ren|race|again): a new track, race 2, the pick again; Leave (ren|race|leave): the winner and GameOver.
-- Lines "[zzren98]", pictures of the cards, of the race (the ring, the arrows) and of the results.
local function log(...) Spring.Echo("[zzren98] " .. table.concat({ ... }, " ")) end
local over, steps, phase, firstCps = false, 0, "pick", nil
local function unitName()
	local u = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit") or 0
	local ud = u > 0 and UnitDefs[Spring.GetUnitDefID(u) or -1]
	return ud and ud.name or "-"
end
local function state(tag)
	local team = Spring.GetMyTeamID()
	local u = Spring.GetTeamRulesParam(team, "renUnit") or 0
	local x, _, z = Spring.GetUnitPosition(u > 0 and u or -1)
	local M = WG.renegade and WG.renegade.M
	log(tag, "lap", tostring((Spring.GetTeamRulesParam(team, "renRaceLap"))), "cp", tostring((Spring.GetTeamRulesParam(team, "renRaceCp"))), "place", tostring((Spring.GetTeamRulesParam(team, "renRacePos"))),
		"time", tostring((Spring.GetTeamRulesParam(team, "renRaceTime"))), "unit", unitName(), "at", x and (math.floor(x) .. " " .. math.floor(z)) or "-",
		"sounds checkpoint", tostring(M and M.played.checkpoint), "lap", tostring(M and M.played.lap), "race over", tostring((Spring.GetGameRulesParam("renRaceOver"))),
		"over", tostring((Spring.GetGameRulesParam("renOver"))))
end
local function free() local R = WG.renegade; return tostring(R and R.H and R.H.raceFree()) end
function widget:GameFrame(f)
	if f == 60 then local R = WG.renegade; if R then R.fake = true; R.yaw, R.pitch = 0, 0 end end
	if f == 200 then
		firstCps = tostring((Spring.GetGameRulesParam("renRaceCps")))
		log("checkpoints:", firstCps, "laps", tostring((Spring.GetGameRulesParam("renRaceLaps"))), "racers", tostring((Spring.GetGameRulesParam("renRaceUnits"))),
			"pick", tostring((Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renRacePick"))), "unit", unitName(), "mouse free", free())
		widget.pick = (Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renRacePick") or 1) % 4 + 1 -- (another one than the random one)
		Spring.SendLuaRulesMsg("ren|race|pick|" .. widget.pick)
	end
	if f == 260 then log("after the pick of racer", widget.pick, ": pick", tostring((Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renRacePick"))), "unit", unitName()) end
	if f == 540 then Spring.SendCommands("screenshot png") end
	if f == 620 then state("after the start"); log("mouse free", free()) end
	if f == 625 then -- no damage between the racers: the hook ren|test|5 hurts the unit by more than its health, it must keep all of it
		widget.racer = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit") or 0
		widget.hp = Spring.GetUnitHealth(widget.racer)
		Spring.SendLuaRulesMsg("ren|test|5")
	end
	if f == 635 then
		local hp = Spring.ValidUnitID(widget.racer) and Spring.GetUnitHealth(widget.racer) or nil
		log("no damage in a race: health", tostring(widget.hp), "after a deadly hit", tostring(hp), (hp and hp == widget.hp) and "OK" or "WRONG")
	end
	if phase == "pick" and f > 640 and f % 20 == 0 and steps < 16 then
		steps = steps + 1
		Spring.SendLuaRulesMsg("ren|test|11")
		if steps == 3 then Spring.SendCommands("screenshot png") end
		if steps == 8 or steps == 9 or steps == 16 then widget.check = f + 10 end
	end
	if widget.check and f == widget.check then state("after " .. steps .. " checkpoints") end
	if phase == "pick" and (Spring.GetGameRulesParam("renRaceOver") or 0) > 0 then
		phase = "results"
		log("results at frame", f, "list", tostring((Spring.GetGameRulesParam("renRaceResult"))), "mouse free", free())
		widget.again = f + 60
	end
	if widget.again and f == widget.again - 30 then Spring.SendCommands("screenshot png") end
	if widget.again and f == widget.again then Spring.SendLuaRulesMsg("ren|race|again") end
	if widget.again and f == widget.again + 30 then
		local cps = tostring((Spring.GetGameRulesParam("renRaceCps")))
		log("new race", tostring((Spring.GetGameRulesParam("renRaceNo"))), "race over", tostring((Spring.GetGameRulesParam("renRaceOver"))), "go", tostring((Spring.GetGameRulesParam("renRaceGo"))),
			"new track", tostring(cps ~= firstCps), "cp", tostring((Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renRaceCp"))), "unit", unitName(), "mouse free", free())
		widget.leave = (Spring.GetGameRulesParam("renRaceGo") or f) + 60
	end
	if widget.leave and f == widget.leave then state("race 2 running"); Spring.SendLuaRulesMsg("ren|race|leave") end
	if f == 3000 then log("timeout: over", tostring(over)); Spring.SendCommands("quitforce") end
end
function widget:GameOver(winners)
	over = true
	log("GameOver at frame", Spring.GetGameFrame(), "winners", table.concat(winners or {}, ","), "result:", tostring((Spring.GetGameRulesParam("renResult"))))
	Spring.SendCommands("quitforce")
end
