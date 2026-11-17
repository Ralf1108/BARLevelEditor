function widget:GetInfo() return { name = "zz LAN race", desc = "test only: Renegade Race over LAN Play", layer = 1, enabled = true } end
-- Test widget of lan_test.ps1 -Mode race (host PlayerA and joiner PlayerB, Race switched on in the room, game option lanrenotest=1): both log the start (frame of GameStart),
-- the track, the racers and the units of both players; PlayerA picks racer 3, PlayerB racer 4; after the start PlayerA passes a checkpoint every 15 frames, PlayerB every 25
-- (ren|test|11): PlayerA wins; both log the results; PlayerA presses New race, both log the new track; PlayerA presses Leave at the start of race 2: GameOver on both.
-- Lines "[zzlanrace]" in the infolog of both instances (they must show the same results).
local function log(...) Spring.Echo("[zzlanrace] " .. table.concat({ ... }, " ")) end
local me = select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false))
local host = me == "PlayerA"
local steps, phase, firstCps, again = 0, "race", nil, nil
local function units()
	local t = {}
	for _, team in ipairs(Spring.GetTeamList()) do
		local u = Spring.GetTeamRulesParam(team, "renUnit") or 0
		local ud = u > 0 and UnitDefs[Spring.GetUnitDefID(u) or -1]
		local x, _, z = Spring.GetUnitPosition(u > 0 and u or -1)
		t[#t + 1] = string.format("team%d %s pick %s units %d at %s", team, ud and ud.name or "-", tostring((Spring.GetTeamRulesParam(team, "renRacePick"))), #Spring.GetTeamUnits(team),
			x and (math.floor(x) .. " " .. math.floor(z)) or "-")
	end
	return table.concat(t, " | ")
end
function widget:Initialize() log("loaded, me", tostring(me), "start pos type", tostring(Game.startPosType), "mode", tostring((Spring.GetModOptions() or {}).lanrenemode)) end
function widget:GameStart() log("GameStart") end
function widget:GameFrame(f)
	if f == 30 then local R = WG.renegade; if R then R.fake = true end end
	if f == 200 then
		firstCps = tostring((Spring.GetGameRulesParam("renRaceCps")))
		log("track", firstCps, "racers", tostring((Spring.GetGameRulesParam("renRaceUnits"))), "go", tostring((Spring.GetGameRulesParam("renRaceGo"))))
		Spring.SendLuaRulesMsg("ren|race|pick|" .. (host and 3 or 4))
	end
	if f == 300 then log("after the picks:", units()) end
	if f == 400 and host then Spring.SendCommands("screenshot png") end
	local go = Spring.GetGameRulesParam("renRaceGo") or 600
	if f == go + 20 then log("after the start:", units()) end
	if phase == "race" and f > go + 30 and f % (host and 15 or 25) == 0 and steps < 16 then
		steps = steps + 1
		Spring.SendLuaRulesMsg("ren|test|11")
	end
	if phase == "race" and (Spring.GetGameRulesParam("renRaceOver") or 0) > 0 then
		phase = "results"
		log("results at frame", f, tostring((Spring.GetGameRulesParam("renRaceResult"))))
		again = f + 90
		if host then Spring.SendCommands("screenshot png") end
	end
	if again and f == again and host then Spring.SendLuaRulesMsg("ren|race|again") end
	if again and f == again + 30 then
		log("new race", tostring((Spring.GetGameRulesParam("renRaceNo"))), "new track", tostring(tostring((Spring.GetGameRulesParam("renRaceCps"))) ~= firstCps), "over", tostring((Spring.GetGameRulesParam("renRaceOver"))),
			"go", tostring((Spring.GetGameRulesParam("renRaceGo"))))
		widget.leave = (Spring.GetGameRulesParam("renRaceGo") or f) + 60
	end
	if widget.leave and f == widget.leave then
		log("race 2:", units())
		if host then Spring.SendLuaRulesMsg("ren|race|leave") end
	end
end
function widget:GameOver(winners)
	log("GameOver at frame", Spring.GetGameFrame(), "winners", table.concat(winners or {}, ","), "result", tostring((Spring.GetGameRulesParam("renResult"))))
	Spring.SendCommands("quitforce")
end
