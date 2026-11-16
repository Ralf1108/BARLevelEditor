-- Renegade, the round (synchronized; loaded by renegade_game.lua, luaui/Include/renegade_rounds.lua): the kill goal, the kill feed and the end of the round.
--   goal       game option lanrenegoal = kills (missing or 0: no goal); only with Always in unit, without Evolution and without the modes Survival and Race.
--              The first team with that many kills wins the round: game rules renWinner (team), renResult (text), renOver (frame); GameOver 8 s later.
--   kill feed  every lost unit of a player and every lost computer unit of the mode: SendToUnsynced("renKill", killer team or -1, victim team, victim unit definition,
--              killer unit definition or -1); the unsynced part of the gadget gives it to the widget (global renKill).
-- ctx: single (Always in unit), evo (Evolution is on), mode ("survival", "race" or nil), say(text). Returns M.
return function(ctx)
	local M = {}
	local MO = Spring.GetModOptions() or {}
	local GOAL = math.max(0, math.min(1000, math.floor(tonumber(MO.lanrenegoal) or 0)))
	if not ctx.single or ctx.evo or ctx.mode then GOAL = 0 end
	M.goal = GOAL
	local overAt, winnerAlly = nil, nil
	local END_WAIT = 8 * 30 -- frames between the winner and the end of the game (the banner is read)

	Spring.SetGameRulesParam("renGoal", GOAL)
	Spring.SetGameRulesParam("renWinner", -1)
	Spring.SetGameRulesParam("renResult", "")
	Spring.SetGameRulesParam("renOver", 0)

	-- the round is over: the winner (a team, or -1 for a text only, e.g. "the waves won") and the text of the banner; the game ends END_WAIT frames later
	function M.finish(team, text, allyTeams)
		if overAt then return end
		overAt = Spring.GetGameFrame()
		winnerAlly = allyTeams or (team >= 0 and { Spring.GetTeamAllyTeamID(team) } or {})
		Spring.SetGameRulesParam("renWinner", team)
		Spring.SetGameRulesParam("renResult", text)
		Spring.SetGameRulesParam("renOver", overAt)
		ctx.say(text)
	end

	function M.over() return overAt ~= nil end

	-- a unit was destroyed: the feed (only units of players and of the computer of the mode) and the goal (the kills are counted by the gadget before)
	function M.killed(defID, team, attackerDefID, attackerTeam, feed)
		if feed then
			SendToUnsynced("renKill", attackerTeam or -1, team, defID or -1, attackerDefID or -1)
		end
		if GOAL > 0 and not overAt and attackerTeam and attackerTeam >= 0 then
			local kills = Spring.GetTeamRulesParam(attackerTeam, "renKills") or 0
			if kills >= GOAL then
				local _, leader, _, isAI = Spring.GetTeamInfo(attackerTeam, false)
				local name = (not isAI) and leader and Spring.GetPlayerInfo(leader, false) or nil
				M.finish(attackerTeam, string.format("%s wins the round: %d kills!", (name and name ~= "") and name or ("Team " .. attackerTeam), kills))
			end
		end
	end

	function M.frame(f)
		if overAt and f == overAt + END_WAIT then
			Spring.GameOver(winnerAlly or {})
		end
	end

	return M
end
