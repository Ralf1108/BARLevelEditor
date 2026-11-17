function widget:GetInfo() return { name = "zz LAN evo team", desc = "test only: Team Evolution over LAN Play", layer = 1, enabled = true } end
-- Test widget of lan_test.ps1 -Mode evoteam (host PlayerA and joiner PlayerB in one room team, a BARb computer in the other; Evolution and Team Evolution on, game option lanevodebug=1):
-- PlayerA levels up (evo|debug|2) to level 2, a second Level Up waits for PlayerB (evoWait); PlayerB levels up: PlayerA follows to level 3; PlayerB levels up once more.
-- Both log the levels, points and waits of both players (they must show the same). Lines "[zzlanevo]" in the infolog of both instances.
local function log(...) Spring.Echo("[zzlanevo] " .. table.concat({ ... }, " ")) end
local me = select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false))
local function state(tag)
	local t = {}
	for _, team in ipairs(Spring.GetTeamList()) do
		local _, _, _, isAI, _, ally = Spring.GetTeamInfo(team, false)
		local stage = Spring.GetTeamRulesParam(team, "evoStage")
		if stage then
			t[#t + 1] = string.format("team%d ally%d%s level %s points %s/%s wait %s unit %s", team, ally, isAI and " ai" or "", tostring(stage), tostring((Spring.GetTeamRulesParam(team, "evoXp"))),
				tostring((Spring.GetTeamRulesParam(team, "evoNeed"))), tostring((Spring.GetTeamRulesParam(team, "evoWait"))), tostring((Spring.GetTeamRulesParam(team, "evoName"))))
		end
	end
	log(tag, "me", tostring(me), "team", Spring.GetMyTeamID(), "|", table.concat(t, " | "))
end
function widget:Initialize() log("loaded, me", tostring(me), "start pos type", tostring(Game.startPosType), "evo team", tostring((Spring.GetModOptions() or {}).lanevoteam)) end
function widget:GameFrame(f)
	if f == 200 then state("start") end
	if me == "PlayerA" and (f == 300 or f == 360) then Spring.SendLuaRulesMsg("evo|debug|2") end
	if me == "PlayerB" and (f == 450 or f == 540) then Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 330 then state("PlayerA level up") end
	if f == 400 then state("PlayerA second level up (waits)") end
	if f == 480 then state("PlayerB level up (PlayerA follows)") end
	if f == 570 then state("PlayerB second level up") end
	if f == 610 and me == "PlayerA" then Spring.SendCommands("screenshot png") end
	if f > 600 and f % 900 == 0 then state("later") end
end
