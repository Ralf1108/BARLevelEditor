-- What the gadgets of the Level Editor and of its scenarios share (td_waves, ctf_game, rtf_game, unit_restrictions, unit_indestructible,
-- unit_level_editor): the editor mode, the rules about unit definitions, messages, the messages of the widget and the game options of a scenario.
-- In the extra games as luaui/Include/led_gadgets.lua (next to bar_rules.lua); load it with VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST).
local G = {}

G.Rules = VFS.Include("luaui/Include/bar_rules.lua", nil, VFS.ZIP_FIRST)
assert(G.Rules, "bar_rules.lua missing (run install_editor.bat again)")

-- Editor mode: the game option leveleditor=1 (set by start_level_editor.bat); then no /cheat is needed
local opt = Spring.GetModOptions().leveleditor
G.EDITOR_MODE = (opt == "1" or opt == 1 or opt == true)

-- A function that writes "[<prefix>] text" for everybody
function G.sayer(prefix)
	return function(text)
		if Spring.SendMessage then
			Spring.SendMessage("[" .. prefix .. "] " .. text)
		else
			Spring.Echo("[" .. prefix .. "] " .. text)
		end
	end
end

-- The parts of a text between the separator sep (one character); empty parts are left out
function G.split(text, sep)
	local out = {}
	for p in tostring(text):gmatch("[^" .. sep .. "]+") do
		out[#out + 1] = p
	end
	return out
end

-- The fields of a payload "a;b;;c" (empty fields stay, as "")
function G.fields(payload)
	local f = {}
	for p in (tostring(payload) .. ";"):gmatch("([^;]*);") do
		f[#f + 1] = p
	end
	return f
end

-- The alliance of a team: in the editor the group of the team (page T, 11f; the editor gadget keeps them in GG.LedGroups) as 100 + the group, a
-- team without a group is its own alliance (its ally team of the engine); in a scenario the ally team of the engine
function G.allyOf(team)
	local group = GG.LedGroups and GG.LedGroups[team]
	if group and group > 0 then
		return 100 + group
	end
	return (select(6, Spring.GetTeamInfo(team, false)))
end

-- How an alliance is called in a message: "group 3" for an alliance of the editor (page T), the number of the ally team otherwise
function G.allianceName(alliance)
	alliance = tonumber(alliance) or 0
	return alliance >= 100 and ("group " .. (alliance - 100)) or tostring(alliance)
end

-- The teams of an alliance (the value of G.allyOf)
function G.teamsOfAlliance(alliance)
	local out = {}
	for _, team in ipairs(Spring.GetTeamList() or {}) do
		if G.allyOf(team) == alliance then
			out[#out + 1] = team
		end
	end
	return out
end

-- All alliances (every value of G.allyOf once, ascending)
function G.allianceList()
	local seen, out = {}, {}
	for _, team in ipairs(Spring.GetTeamList() or {}) do
		local a = G.allyOf(team)
		if a and not seen[a] then
			seen[a] = true
			out[#out + 1] = a
		end
	end
	table.sort(out)
	return out
end

-- The unit a build order builds (also an order inserted into the queue: CMD.INSERT { position, command, options, ... }); nil for other orders
function G.builtDef(cmdID, cmdParams)
	if cmdID < 0 then
		return -cmdID
	end
	if cmdID == CMD.INSERT and cmdParams and (tonumber(cmdParams[2]) or 0) < 0 then
		return -cmdParams[2]
	end
	return nil
end

-- A function refuse(teamID, defID, text) that sends "[<prefix>] text" only to that team, at most once per unit type every 5 seconds, and never to a
-- computer player or Gaia (an AI tries a refused order again and again)
function G.teamMessenger(prefix)
	local GAP = 5 * 30
	local last = {} -- team -> unitDefID -> frame of the last message
	return function(teamID, defID, text)
		local isAI = select(4, Spring.GetTeamInfo(teamID, false))
		if isAI or teamID == Spring.GetGaiaTeamID() then
			return
		end
		local n = Spring.GetGameFrame()
		local seen = last[teamID] or {}
		last[teamID] = seen
		if seen[defID] and n - seen[defID] < GAP then
			return
		end
		seen[defID] = n
		text = "[" .. prefix .. "] " .. text
		if Spring.SendMessageToTeam then
			Spring.SendMessageToTeam(teamID, text)
		else
			Spring.Echo(text)
		end
	end
end

-- The messages of the widget "<tag>|<command>|<payload>": handlers[command](payload, playerID). Only with cheats or in the editor game (a finished
-- scenario gets its settings from the game options). Call it from gadget:RecvLuaMsg; true = the message was one of these.
function G.handleMessage(tag, handlers, msg, playerID)
	if msg:sub(1, #tag + 1) ~= tag .. "|" then
		return false
	end
	if Spring.IsCheatingEnabled() or G.EDITOR_MODE then
		local cmd, payload = msg:match("^" .. tag .. "|(%a+)|?(.*)$")
		if cmd and handlers[cmd] then
			handlers[cmd](payload, playerID)
		end
	end
	return true
end

-- What every game mode gadget (td_waves, ctf_game, rtf_game) does the same way: the messages "<tag>|start|<payload>" and "<tag>|stop" of the editor,
-- the game option of a finished scenario (read in GamePreload; started at frame START_FRAME, when the units and features of the scenario exist) and the
-- empty state parameter at the start. m = { tag, option (name of the game option), state (name of the game rules parameter), parse(payload) -> cfg or nil,
-- start(cfg), stop(), say, startFail (text when the editor's payload is not usable; optional), handler (gadgetHandler), allowCommand (the gadget has an
-- AllowCommand: the list of the command ids it wants, CMD.BUILD = every build order; true = every command) }. mode.install(gadget) sets the call-ins RecvLuaMsg, Initialize and GamePreload of the gadget; its GameFrame calls mode.gameFrame(n).
G.START_FRAME = 30
function G.gameMode(m)
	local pending = nil -- configuration of a finished scenario waiting for the start
	local messages = {
		start = function(payload)
			local cfg = m.parse(payload)
			if cfg then
				m.start(cfg)
			elseif m.startFail then
				m.say(m.startFail)
			end
		end,
		stop = function() m.stop() end,
	}
	local mode = {}
	function mode.initialize()
		if m.allowCommand and m.handler.RegisterAllowCommand then
			-- only these commands reach the AllowCommand of the gadget (without it the engine registers every command and warns)
			for _, id in ipairs(m.allowCommand == true and { CMD.ANY } or m.allowCommand) do
				m.handler:RegisterAllowCommand(id)
			end
		end
		Spring.SetGameRulesParam(m.state, "")
	end
	function mode.gamePreload()
		local text = G.option(m.option)
		if text then
			pending = m.parse(text)
		end
	end
	function mode.recvLuaMsg(msg, playerID)
		return G.handleMessage(m.tag, messages, msg, playerID)
	end
	function mode.gameFrame(n)
		if pending and n >= G.START_FRAME then
			local cfg = pending
			pending = nil
			m.start(cfg)
		end
	end
	function mode.install(gadget)
		function gadget:RecvLuaMsg(msg, playerID)
			return mode.recvLuaMsg(msg, playerID)
		end
		function gadget:Initialize()
			mode.initialize()
		end
		function gadget:GamePreload()
			mode.gamePreload()
		end
	end
	return mode
end

-- The units of an alliance blow up (keep: unitID -> true for units that stay, e.g. the flags of Capture the Flag)
function G.blowUp(alliance, keep)
	for _, team in ipairs(G.teamsOfAlliance(alliance)) do
		for _, id in ipairs(Spring.GetTeamUnits(team)) do
			if not (keep and keep[id]) then
				Spring.DestroyUnit(id, true, false)
			end
		end
	end
end

-- The score board of a game of alliances (ctf_game, rtf_game) as game rules parameters with the prefix p: <p>State, <p>Target (score that wins, 0 = none),
-- <p>Teams (the alliances "a,b,..."), <p>Score<alliance> and <p>Out (the alliances that lost). g = nil: no game (<p>State ""); otherwise g.state, g.cfg.score,
-- g.score[alliance], g.out[alliance]; perAlliance(alliance): more parameters of an alliance (optional)
function G.publishScores(p, g, alliances, perAlliance)
	if not g then
		Spring.SetGameRulesParam(p .. "State", "")
		return
	end
	for _, a in ipairs(alliances) do
		Spring.SetGameRulesParam(p .. "Score" .. a, math.floor(g.score[a] or 0))
		if perAlliance then
			perAlliance(a)
		end
	end
	Spring.SetGameRulesParam(p .. "State", g.state)
	Spring.SetGameRulesParam(p .. "Target", g.cfg.score)
	Spring.SetGameRulesParam(p .. "Teams", table.concat(alliances, ","))
	local out = {}
	for a in pairs(g.out) do
		out[#out + 1] = a
	end
	Spring.SetGameRulesParam(p .. "Out", table.concat(out, ","))
end

-- The line of the score board for the screen (unsynced part): "<title>   Alliance 0: 3/5   Alliance group 1: 2/5 (lost)   (won by ...)"; nil when no game
-- runs. extra(alliance): text after the score of an alliance (optional, e.g. the rate)
function G.scoreLine(p, title, extra)
	local state = Spring.GetGameRulesParam(p .. "State")
	if not state or state == "" then
		return nil
	end
	local target = Spring.GetGameRulesParam(p .. "Target") or 0
	local out = "," .. tostring(Spring.GetGameRulesParam(p .. "Out") or "") .. ","
	local parts = {}
	for a in tostring(Spring.GetGameRulesParam(p .. "Teams") or ""):gmatch("%d+") do
		parts[#parts + 1] = string.format("Alliance %s: %d%s%s%s", G.allianceName(a), Spring.GetGameRulesParam(p .. "Score" .. a) or 0, target > 0 and ("/" .. target) or "",
			extra and extra(a) or "", out:find("," .. a .. ",", 1, true) and " (lost)" or "")
	end
	local text = title .. "   " .. table.concat(parts, "   ")
	if state ~= "running" then
		text = text .. "   (" .. state .. ")"
	end
	return text
end

-- The text of a game option of a finished scenario (written as base64url by the scenario builder); nil when it is not set
function G.option(name)
	local v = Spring.GetModOptions()[name]
	if v and v ~= "" then
		return G.Rules.decode64(v)
	end
	return nil
end

-- The heal effect (unsynced, for the gadgets that heal a unit): green plus signs rise round the unit and a green "+N" climbs over it. The synced part sends each heal with
-- SendToUnsynced(<name>, unit, amount); the unsynced part calls G.healAdd(unit, amount) for it and G.healDraw(vsy) from gadget:DrawScreen.
local HEAL_LIFE, HEAL_MAX, HEAL_JOIN = 1.6, 40, 1.3 -- (heals of the same unit within HEAL_JOIN seconds are one number)
local heals = {}
function G.healAdd(unitID, amount)
	if not unitID or not amount or amount < 1 or #heals >= HEAL_MAX then return end
	if Spring.GetSpectatingState and not Spring.GetSpectatingState() then
		local los = Spring.GetUnitLosState(unitID, Spring.GetMyAllyTeamID(), false) -- (only what can be seen)
		if not (los and los.los) then return end
	end
	local now = os.clock()
	for _, e in ipairs(heals) do
		if e.unit == unitID and now - e.t1 <= HEAL_JOIN then -- (one number that counts up while the heal goes on)
			e.amount, e.t1 = e.amount + amount, now
			return
		end
	end
	heals[#heals + 1] = { unit = unitID, amount = amount, t0 = now, t1 = now }
end
function G.healDraw(vsy)
	if #heals == 0 then return end
	local now = os.clock()
	local px, py, pz = Spring.GetCameraPosition()
	local cdx, cdy, cdz = Spring.GetCameraDirection()
	local function project(x, y, z)
		if (x - px) * cdx + (y - py) * cdy + (z - pz) * cdz <= 0 then return nil end
		return Spring.WorldToScreenCoords(x, y, z)
	end
	local i = 1
	while i <= #heals do
		local e = heals[i]
		local age = now - e.t0
		if now - e.t1 > HEAL_LIFE or not Spring.ValidUnitID(e.unit) then
			table.remove(heals, i)
		else
			local x, y, z = Spring.GetUnitPosition(e.unit)
			local r, h = Spring.GetUnitRadius(e.unit) or 20, Spring.GetUnitHeight(e.unit) or 30
			if x and (x - px) ^ 2 + (y + h / 2 - py) ^ 2 + (z - pz) ^ 2 < (r + 30) ^ 2 then
				-- the camera is in the unit (first person view): the effect is drawn round the middle of the screen
				local vsx = select(1, Spring.GetViewGeometry())
				local fade = math.min(1, (HEAL_LIFE - (now - e.t1)) / 0.5)
				for k = 0, 11 do
					local tt = (age * 0.8 + k / 12) % 1
					local a = k * 2.4 + age * 1.5
					gl.Color(0.25, 1, 0.35, math.sin(tt * math.pi) * fade)
					gl.Text("+", vsx / 2 + math.cos(a) * vsy * 0.2, vsy * 0.5 + math.sin(a) * vsy * 0.12 - vsy * 0.05 + tt * vsy * 0.12, vsy / 28 * (0.7 + 0.5 * math.sin(k * 1.7) ^ 2), "co")
				end
				gl.Color(0.3, 1, 0.4, fade)
				gl.Text("+" .. math.floor(e.amount + 0.5), vsx / 2, vsy * 0.62 + vsy * 0.09 * (age / (HEAL_LIFE + e.t1 - e.t0)), vsy / 20, "co")
			elseif x then
				local fade = math.min(1, (HEAL_LIFE - (now - e.t1)) / 0.5)
				-- the plus signs: they circle round the unit and rise, each one fades in and out
				for k = 0, 11 do
					local tt = (age * 0.8 + k / 12) % 1
					local a = k * 2.4 + age * 2.5
					local rad = r * (0.9 + 0.3 * math.sin(k + age * 3))
					local sx, sy = project(x + math.cos(a) * rad, y + tt * h * 1.4, z + math.sin(a) * rad)
					if sx then
						gl.Color(0.25, 1, 0.35, math.sin(tt * math.pi) * fade)
						gl.Text("+", sx, sy, vsy / 28 * (0.7 + 0.5 * math.sin(k * 1.7) ^ 2), "co")
					end
				end
				-- the number: "+30" rises over the unit
				local sx, sy = project(x, y + h, z)
				if sx then
					gl.Color(0.3, 1, 0.4, fade)
					gl.Text("+" .. math.floor(e.amount + 0.5), sx, sy + vsy * 0.09 * (age / (HEAL_LIFE + e.t1 - e.t0)) + vsy / 40, vsy / 26, "co")
				end
			end
			i = i + 1
		end
	end
	gl.Color(1, 1, 1, 1)
end

return G
