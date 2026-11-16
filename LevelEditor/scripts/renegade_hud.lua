-- Renegade, the parts of the screen of the round (unsynced; loaded by the widget renegade.lua, luaui/Include/renegade_hud.lua): the kill feed, the goal in the list of the
-- players and the banner at the end of the round. Returns H.
--   H.kill(killerTeam, victimTeam, victimDef, killerDef)   one line of the feed (global renKill of the gadget renegade_game.lua)
--   H.drawFeed(vsx, vsy)                                   the feed at the top, left of the list of the players: the last FEED_MAX lines, each FEED_LIFE seconds
--   H.goalTitle()                                          the title of the list of the players: "FIRST TO 20 KILLS" (game rules renGoal) or "PLAYERS"
--   H.drawEnd(vsx, vsy)                                    the banner when the round is over (game rules renOver, renWinner, renResult)
local H = {}
local FEED_MAX, FEED_LIFE = 6, 8
local feed = {} -- { t = os.clock(), killer = text, kc = color, victim = text, vc = color, mine = true when the own team is in it }

function H.teamName(team)
	if not team or team < 0 then return "" end
	if team == Spring.GetGaiaTeamID() then return "Waves" end
	local _, leader, _, isAI = Spring.GetTeamInfo(team, false)
	if isAI then
		local _, n = Spring.GetAIInfo(team)
		if n and n ~= "" then return n end
	elseif leader then
		local n = Spring.GetPlayerInfo(leader, false)
		if n and n ~= "" then return n end
	end
	return "Team " .. team
end

local function unitName(defID)
	local ud = defID and UnitDefs[defID]
	return ud and (ud.translatedHumanName or ud.name) or "unit"
end

local function teamColor(team)
	if not team or team < 0 then return { 0.8, 0.8, 0.8 } end
	local r, g, b = Spring.GetTeamColor(team)
	return { r or 1, g or 1, b or 1 }
end

function H.kill(killerTeam, victimTeam, victimDef, killerDef)
	local me = Spring.GetMyTeamID()
	local e = { t = os.clock(), victim = H.teamName(victimTeam) .. " (" .. unitName(victimDef) .. ")", vc = teamColor(victimTeam),
		mine = killerTeam == me or victimTeam == me }
	if killerTeam and killerTeam >= 0 then
		e.killer = H.teamName(killerTeam) .. " (" .. unitName(killerDef) .. ")"
		e.kc = teamColor(killerTeam)
	end
	table.insert(feed, 1, e)
	while #feed > FEED_MAX do table.remove(feed) end
	H.lastKill = e -- (for the tests)
end

function H.drawFeed(vsx, vsy)
	if #feed == 0 then return end
	local s = math.max(0.7, vsy / 1080)
	local now = os.clock()
	local x2, y = vsx - 320 * s, vsy - 90 * s
	local fs = 15 * s
	for i = #feed, 1, -1 do
		if now - feed[i].t > FEED_LIFE then table.remove(feed, i) end
	end
	for _, e in ipairs(feed) do
		local a = math.min(1, (FEED_LIFE - (now - e.t)) / 1.5)
		local mid = e.killer and "  destroyed  " or "  was destroyed"
		local w = (gl.GetTextWidth((e.killer or "") .. mid .. (e.killer and e.victim or e.victim)) * fs) + 16 * s
		local x1 = x2 - w
		gl.Color(e.mine and 0.25 or 0.05, e.mine and 0.2 or 0.06, e.mine and 0.05 or 0.08, 0.7 * a)
		gl.Rect(x1, y - 6 * s, x2, y + fs + 4 * s)
		local x = x1 + 8 * s
		if e.killer then
			gl.Color(e.kc[1], e.kc[2], e.kc[3], a)
			gl.Text(e.killer, x, y, fs, "o")
			x = x + gl.GetTextWidth(e.killer) * fs
			gl.Color(0.85, 0.85, 0.85, a)
			gl.Text("  destroyed  ", x, y, fs, "o")
			x = x + gl.GetTextWidth("  destroyed  ") * fs
			gl.Color(e.vc[1], e.vc[2], e.vc[3], a)
			gl.Text(e.victim, x, y, fs, "o")
		else
			gl.Color(e.vc[1], e.vc[2], e.vc[3], a)
			gl.Text(e.victim, x, y, fs, "o")
			x = x + gl.GetTextWidth(e.victim) * fs
			gl.Color(0.85, 0.85, 0.85, a)
			gl.Text("  was destroyed", x, y, fs, "o")
		end
		y = y - fs - 12 * s
	end
	gl.Color(1, 1, 1, 1)
end

function H.goalTitle()
	local goal = Spring.GetGameRulesParam("renGoal") or 0
	if goal > 0 then return string.format("FIRST TO %d KILLS", goal) end
	return "PLAYERS"
end

-- the banner of the end: VICTORY (green) for the own alliance, otherwise the text of the gadget (red); the line below says the game ends in a few seconds
function H.drawEnd(vsx, vsy)
	local over = Spring.GetGameRulesParam("renOver") or 0
	if over <= 0 then return false end
	local s = math.max(0.7, vsy / 1080)
	local winner = Spring.GetGameRulesParam("renWinner") or -1
	local text = tostring(Spring.GetGameRulesParam("renResult") or "")
	local won = winner >= 0 and Spring.AreTeamsAllied(winner, Spring.GetMyTeamID())
	if Spring.GetSpectatingState() or winner < 0 then won = nil end
	local title = won == true and "VICTORY" or (won == false and "DEFEAT" or "ROUND OVER")
	local w, h = 900 * s, 170 * s
	local x1, y1 = (vsx - w) / 2, vsy * 0.62
	gl.Color(0.02, 0.03, 0.05, 0.82)
	gl.Rect(x1, y1, x1 + w, y1 + h)
	if won == true then gl.Color(0.35, 1, 0.45, 1) elseif won == false then gl.Color(1, 0.3, 0.25, 1) else gl.Color(1, 0.85, 0.3, 1) end
	gl.Text(title, vsx / 2, y1 + h - 70 * s, 60 * s, "co")
	gl.Color(1, 1, 1, 1)
	gl.Text(text, vsx / 2, y1 + 48 * s, 22 * s, "co")
	gl.Color(0.7, 0.75, 0.85, 1)
	gl.Text("The game ends in a few seconds.", vsx / 2, y1 + 16 * s, 15 * s, "co")
	gl.Color(1, 1, 1, 1)
	return true
end

return H
