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

-- The hit marker: a short white cross at the crosshair when a shot of the own team hits an enemy (H.hit, from the global renDamage), a bigger red one for a kill (H.kill)
function H.hit()
	H.hitAt = os.clock()
	if H.M then H.M.play("hit") end
end
function H.drawHitMarker(cx, cy, s)
	local now = os.clock()
	local kill = H.killAt and now - H.killAt < 0.35
	if not kill and not (H.hitAt and now - H.hitAt < 0.15) then return end
	local a, b = s * (kill and 1.4 or 0.9), s * (kill and 2.6 or 1.7)
	if kill then gl.Color(1, 0.25, 0.2, 1) else gl.Color(1, 1, 1, 0.95) end
	gl.LineWidth(kill and 3.5 or 2.5)
	gl.BeginEnd(GL.LINES, function()
		for _, d in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
			gl.Vertex(cx + d[1] * a, cy + d[2] * a); gl.Vertex(cx + d[1] * b, cy + d[2] * b)
		end
	end)
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

-- The sounds of the own unit and of the round (every Update of the widget; R = the state of the widget, H.M = mode_ui.lua): death and respawn, low health (below 30 %, once per
-- unit), jump and landing (unit rules renJump of the gadget), the anti-air lock, the end of the round (win / lose)
local ev = { unit = 0, dead = false, jump = 0 }
function H.sounds(R)
	local M = H.M
	if not M or Spring.GetSpectatingState() then return end
	local team = Spring.GetMyTeamID()
	local u = Spring.GetTeamRulesParam(team, "renUnit") or 0
	if u > 0 then
		if ev.dead then M.play("respawn") end
		ev.dead = false
		if Spring.ValidUnitID(u) then
			local hp, mhp = Spring.GetUnitHealth(u)
			if hp and mhp and hp < mhp * 0.3 and ev.low ~= u then ev.low = u; M.play("lowhp") end
			local j = Spring.GetUnitRulesParam(u, "renJump") or 0
			if j > 0 and ev.jump == 0 then M.play("jump") elseif j == 0 and ev.jump > 0 then M.play("land") end
			ev.jump = j
		end
	elseif ev.unit > 0 and (Spring.GetTeamRulesParam(team, "renRespawn") or 0) > Spring.GetGameFrame() then
		ev.dead = true
		M.play("death")
	end
	ev.unit = u
	if R.aaTarget and not ev.lock then M.play("lock") end
	ev.lock = R.aaTarget
	local over = (Spring.GetGameRulesParam("renOver") or 0) > 0
	if over and not ev.over then
		local w = Spring.GetGameRulesParam("renWinner") or -1
		M.play((w >= 0 and Spring.AreTeamsAllied(w, team)) and "win" or "lose")
	end
	ev.over = over
end

-- Hints for beginners (every Update while the view is on; mode_ui.lua shows each once per game, in the first 3 games of the computer)
local Rules = VFS.Include("luaui/Include/bar_rules.lua", nil, VFS.ZIP_FIRST)
local hintStart
function H.hints(R)
	local M = H.M
	if not M or not R.on or not R.unit or not Spring.ValidUnitID(R.unit) then return end
	local now = os.clock()
	hintStart = hintStart or now
	local t = now - hintStart
	local goal = Spring.GetGameRulesParam("renGoal") or 0
	local mode = (Spring.GetModOptions() or {}).lanrenemode
	if mode and H.modeHints then H.modeHints(M, t, mode) end
	if t > 2 then M.hint("ren_move", "W A S D drive, the mouse aims, the left mouse button fires.") end
	if t > 4 and goal > 0 then M.hint("ren_goal", string.format("The first player with %d kills wins the round.", goal)) end
	if t > 20 then M.hint("ren_buttons", "Right mouse button: long range weapons, middle button: missiles. Shift: the view from behind.") end
	local ud = UnitDefs[Spring.GetUnitDefID(R.unit) or -1]
	if t > 30 and ud and Rules.moveKind(ud) == "bot" then M.hint("ren_jump", "Space: jump (a unit with two legs).") end
	local x, _, z = Spring.GetUnitPosition(R.unit)
	if R.powerups and x then
		local d = M.nearestBeacon("renBeacons", x, z)
		if d and d < 700 then M.hint("ren_beacon", "Drive over the glowing beacon: it gives you a power-up.") end
		if tostring(Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renAbilities") or "") ~= "" then
			M.hint("ren_use", "You have a power-up: its key (1 to 5) uses it. The bar at the bottom shows the numbers.")
		end
	end
	local hp, mhp = Spring.GetUnitHealth(R.unit)
	if hp and mhp and hp < mhp * 0.5 then M.hint("ren_hurt", "Hurt? Stay near wrecks out of the fight: they repair your unit.") end
	if t > 90 and R.single then M.hint("ren_normal", "The key left of the 1 (or Insert) switches to the normal game and back.") end
end

function H.kill(killerTeam, victimTeam, victimDef, killerDef)
	local me = Spring.GetMyTeamID()
	if killerTeam == me and victimTeam ~= me then
		H.killAt = os.clock()
		if H.M then H.M.play("kill") end
	end
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
