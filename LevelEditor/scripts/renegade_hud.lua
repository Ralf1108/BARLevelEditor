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

-- The modes (game option lanrenemode): their panel at the top middle, their sounds and hints
local MODE = (Spring.GetModOptions() or {}).lanrenemode
H.MODE = MODE
local modeEv = {}
function H.modeHints(M, t, mode)
	if mode == "survival" then
		if t > 2 then M.hint("surv_goal", "Survival: beat the waves together with the other players.") end
		if t > 10 then M.hint("surv_dead", "A lost unit comes back when the wave is over. Every wave makes your unit stronger.") end
	elseif mode == "race" then
		if t > 2 then M.hint("race_goal", "Race: drive through the glowing green ring, then the next one. The arrow at the top shows the way.") end
		if t > 12 then M.hint("race_jump", "Space jumps over small obstacles. Sprint (key 1) helps when you found it.") end
	end
end
-- the panel of Survival: WAVE 3 / 10 and the enemies left, or the seconds to the next wave; a dead player reads that it comes back after the wave
local function drawSurvival(vsx, vsy, s)
	local wave, waves = Spring.GetGameRulesParam("renSurvWave") or 0, Spring.GetGameRulesParam("renSurvWaves") or 0
	local left, nextAt = Spring.GetGameRulesParam("renSurvLeft") or 0, Spring.GetGameRulesParam("renSurvNext") or 0
	local f = Spring.GetGameFrame()
	local secs = nextAt > 0 and math.max(0, math.ceil((nextAt - f) / 30)) or nil
	-- sounds: a new wave, the last three seconds before it
	if H.M then
		if modeEv.wave and wave > modeEv.wave then H.M.play("wave") end
		if secs and secs <= 3 and secs > 0 and secs ~= modeEv.secs then H.M.play("tick") end
	end
	modeEv.wave, modeEv.secs = wave, secs
	local y = vsy - 120 * s
	local w = 420 * s
	gl.Color(0.05, 0.06, 0.08, 0.75)
	gl.Rect(vsx / 2 - w / 2, y - 40 * s, vsx / 2 + w / 2, y + 34 * s)
	gl.Color(1, 0.75, 0.3, 1)
	if wave == 0 then
		gl.Text(string.format("SURVIVAL: the first wave in %d", secs or 0), vsx / 2, y, 26 * s, "co")
	elseif secs then
		gl.Text(string.format("WAVE %d OF %d BEATEN", wave, waves), vsx / 2, y, 26 * s, "co")
		gl.Color(1, 1, 1, 1)
		gl.Text(string.format("the next wave in %d s", secs), vsx / 2, y - 28 * s, 18 * s, "co")
	else
		gl.Text(string.format("WAVE %d OF %d", wave, waves), vsx / 2, y, 26 * s, "co")
		gl.Color(1, 1, 1, 1)
		gl.Text(string.format("%d enemies left", left), vsx / 2, y - 28 * s, 18 * s, "co")
	end
	local team = Spring.GetMyTeamID()
	if not Spring.GetSpectatingState() and wave > 0 and (Spring.GetTeamRulesParam(team, "renUnit") or 0) == 0 and (Spring.GetGameRulesParam("renOver") or 0) == 0 then
		gl.Color(1, 0.25, 0.2, 1)
		gl.Text("YOU DIED", vsx / 2, vsy * 0.62, vsy / 14, "co")
		gl.Color(1, 1, 1, 1)
		gl.Text("you come back when the others beat this wave", vsx / 2, vsy * 0.54, vsy / 30, "co")
	end
	gl.Color(1, 1, 1, 1)
end
-- Race: the checkpoints (game rules renRaceCps), the own progress (team rules renRaceLap, renRaceCp, renRacePos, renRaceTime)
local function raceCps()
	local list = {}
	for x, z in tostring(Spring.GetGameRulesParam("renRaceCps") or ""):gmatch("(%d+),(%d+)") do list[#list + 1] = { tonumber(x), tonumber(z) } end
	return list
end
local function clock(frames)
	local secs = math.max(0, math.floor(frames / 30))
	return string.format("%d:%02d", math.floor(secs / 60), secs % 60)
end
-- the panel: LAP 1/2, CHECKPOINT 3/8, the place and the time; the countdown before the start; an arrow to the next checkpoint (up = straight ahead of the view)
local function drawRace(vsx, vsy, s)
	local team, f = Spring.GetMyTeamID(), Spring.GetGameFrame()
	local go = Spring.GetGameRulesParam("renRaceGo") or 0
	local cps = raceCps()
	local lap, cp = Spring.GetTeamRulesParam(team, "renRaceLap") or 1, Spring.GetTeamRulesParam(team, "renRaceCp") or 1
	local pos, time = Spring.GetTeamRulesParam(team, "renRacePos") or 1, Spring.GetTeamRulesParam(team, "renRaceTime") or 0
	local players = 0
	for _, t in ipairs(Spring.GetTeamList()) do if Spring.GetTeamRulesParam(t, "renRacePos") then players = players + 1 end end
	-- sounds: the countdown, the start, every checkpoint, every lap
	if H.M then
		local secs = go > f and math.ceil((go - f) / 30) or nil
		if secs and secs <= 3 and secs ~= modeEv.secs then H.M.play("tick") end
		if not secs and modeEv.secs then H.M.play("wave") end
		modeEv.secs = secs
		if modeEv.lap and (lap > modeEv.lap or (time > 0 and (modeEv.time or 0) == 0)) then H.M.play("lap")
		elseif modeEv.cp and cp ~= modeEv.cp then H.M.play("checkpoint") end
		modeEv.lap, modeEv.cp, modeEv.time = lap, cp, time
	end
	local y = vsy - 120 * s
	local w = 520 * s
	gl.Color(0.05, 0.06, 0.08, 0.75)
	gl.Rect(vsx / 2 - w / 2, y - 40 * s, vsx / 2 + w / 2, y + 34 * s)
	if f < go then
		gl.Color(1, 0.85, 0.3, 1)
		gl.Text("RACE: through the rings in order", vsx / 2, y, 24 * s, "co")
		local secs = math.ceil((go - f) / 30)
		if secs <= 5 then
			gl.Color(1, 1, 1, 1)
			gl.Text(tostring(secs), vsx / 2, vsy * 0.6, 90 * s, "co")
		end
		gl.Color(1, 1, 1, 1)
		return
	end
	if f - go < 45 then
		gl.Color(0.4, 1, 0.45, 1)
		gl.Text("GO!", vsx / 2, vsy * 0.6, 90 * s, "co")
	end
	gl.Color(1, 0.85, 0.3, 1)
	if time > 0 then
		gl.Text(string.format("FINISHED: place %d in %s", pos, clock(time)), vsx / 2, y, 24 * s, "co")
	else
		gl.Text(string.format("LAP %d/%d   CHECKPOINT %d/%d   PLACE %d/%d", lap, Spring.GetGameRulesParam("renRaceLaps") or 1, cp, #cps, pos, math.max(1, players)), vsx / 2, y, 22 * s, "co")
		gl.Color(1, 1, 1, 1)
		gl.Text(clock(f - go), vsx / 2, y - 28 * s, 18 * s, "co")
		-- the arrow to the next checkpoint
		local u = Spring.GetTeamRulesParam(team, "renUnit") or 0
		local c = cps[cp]
		local ux, _, uz = Spring.GetUnitPosition(u > 0 and u or -1)
		local dx, _, dz = Spring.GetCameraDirection()
		if c and ux and dx then
			local tx, tz = c[1] - ux, c[2] - uz
			local ang = math.atan2(dx * tz - dz * tx, dx * tx + dz * tz) -- (from the view to the checkpoint, positive = to the right)
			local cx, cy, r = vsx / 2, y - 80 * s, 26 * s
			local function pt(a, d) return cx + math.sin(ang + a) * d, cy + math.cos(ang + a) * d end
			gl.Color(0.4, 1, 0.45, 0.95)
			gl.BeginEnd(GL.TRIANGLES, function()
				local x1, y1 = pt(0, r)
				local x2, y2 = pt(2.5, r)
				local x3, y3 = pt(-2.5, r)
				gl.Vertex(x1, y1); gl.Vertex(x2, y2); gl.Vertex(x3, y3)
			end)
			gl.Text(string.format("%d m", math.floor(math.sqrt(tx * tx + tz * tz))), cx, cy - r - 18 * s, 15 * s, "co")
		end
	end
	gl.Color(1, 1, 1, 1)
end
-- the rings of the checkpoints on the ground: the next one bright green and pulsing, with a column of light, the others faint with their number
function H.drawModeWorld()
	if MODE ~= "race" then return end
	local cps = raceCps()
	local cp = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renRaceCp") or 1
	local pulse = 0.6 + 0.4 * math.sin(os.clock() * 5)
	gl.DepthTest(false)
	for i, c in ipairs(cps) do
		local y = Spring.GetGroundHeight(c[1], c[2])
		if i == cp then
			gl.LineWidth(5)
			gl.Color(0.3, 1, 0.4, pulse)
			gl.DrawGroundCircle(c[1], y, c[2], 140, 48)
			gl.BeginEnd(GL.LINES, function() gl.Vertex(c[1], y, c[2]); gl.Vertex(c[1], y + 600, c[2]) end)
		else
			gl.LineWidth(2)
			gl.Color(1, 0.85, 0.3, 0.45)
			gl.DrawGroundCircle(c[1], y, c[2], 140, 32)
		end
	end
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

function H.drawMode(vsx, vsy)
	if not MODE then return end
	local s = math.max(0.7, vsy / 1080)
	if MODE == "survival" then drawSurvival(vsx, vsy, s) elseif MODE == "race" then drawRace(vsx, vsy, s) end
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
