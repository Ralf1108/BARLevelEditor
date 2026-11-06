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
-- start(cfg), stop(), say, startFail (text when the editor's payload is not usable; optional), handler (gadgetHandler), allowCommand (true: the gadget has
-- an AllowCommand) }. The gadget calls from its call-ins: mode.initialize(), mode.gamePreload(), mode.recvLuaMsg(msg, playerID), mode.gameFrame(n).
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
			m.handler:RegisterAllowCommand(CMD.ANY) -- otherwise the engine registers it and warns
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
	return mode
end

-- The text of a game option of a finished scenario (written as base64url by the scenario builder); nil when it is not set
function G.option(name)
	local v = Spring.GetModOptions()[name]
	if v and v ~= "" then
		return G.Rules.decode64(v)
	end
	return nil
end

return G
