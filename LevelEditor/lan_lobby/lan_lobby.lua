function widget:GetInfo()
	return {
		name      = "LAN Play",
		desc      = "Host or join a game in the local network with the official multiplayer battle room (a small lobby server runs inside the host's lobby)",
		author    = "Level Editor",
		date      = "2026-10-24",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

-- Prototype 3. The host's lobby runs a very small lobby server (the "TASServer" text protocol the official lobby speaks) and an "autohost" in it:
--   host:    the lobby connects to its own server and joins the battle
--   joiner:  the lobby connects to the server of the host (the server address of the lobby is changed for the time of the LAN game) and joins the battle
-- So the official MULTIPLAYER battle room is used unchanged (map, options, AIs, colours, teams, chat). The server answers the autohost commands the room sends
-- as chat: !map, !bSet, !cv start (and !start). Everything goes over TCP on port 8453 (the lobby may listen and connect, but may not send UDP).
-- The game itself: when the autohost says "in game", every lobby connects to the battle (as for a game on a normal server); the host's lobby starts the
-- engine as the host (HostIP 0.0.0.0, port 8452) with a start script built here from the state of the room.
-- Test automation: lanlobby_cfg.txt in the write dir (key=value lines): auto=host|join, name=, map=, players=, ip=

local PORT, GAMEPORT = 8453, 8452
local HOSTNAME = "LANHost" -- the user that is the founder of the battle (the autohost)
local cfg = {}
for line in string.gmatch(VFS.LoadFile("lanlobby_cfg.txt", VFS.RAW) or "", "[^\r\n]+") do
	local k, v = line:match("^%s*(%w+)%s*=%s*(.-)%s*$")
	if k then cfg[k] = v end
end

local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	local s = table.concat(t, " ")
	Spring.Echo("[LANPLAY] " .. s)
	local f = io.open("lan_status.txt", "a")
	if f then f:write(os.date("%H:%M:%S ") .. s .. "\n"); f:close() end
end

local ui = {}
local buildUi, updateFoundUi, scenarioList, forcedStatus, selectScenario, buildScript, SCENARIO_GAME, SCENARIO_FILE, localGameHash
local status = ""
local returnAt
local uiTried, autoStarted, tabCheckAt, tabAdded, tabReported, tabDumped, tabAddCount, nextScanAt, lastFoundCount, rowAt
local found, scan = {}, nil
local S = nil            -- the server (host only)
local lan = nil          -- { role = "host"|"client", saved = {address, port}, name, ip, step }
local hookedConnect

local function Config() return WG.Chobby and WG.Chobby.Configuration end
local function lobby() return WG.LibLobby and WG.LibLobby.lobby end
local function setStatus(s) status = s; log("status:", s); if ui.status then ui.status:SetText(s) end end
local function cleanName(n) return ((n or ""):gsub("[^%w_%-%[%]]", ""):sub(1, 20)) end

-- the player name in a LAN game: what is typed on the LAN Play page; else the name the lobby logs in with (Configuration.userName, saved in the lobby settings; the
-- player need not be logged in), else the name from Steam, else "Player". A name that differs from the account name is remembered in lan_name.txt.
local function defaultName()
	local cf = Config()
	local n = cf and cf.userName
	if type(n) ~= "string" or cleanName(n) == "" then n = cf and cf.suggestedNameFromSteam end
	n = cleanName(type(n) == "string" and n or "")
	return n ~= "" and n or "Player"
end

local function savedName()
	local s = VFS.LoadFile("lan_name.txt", VFS.RAW)
	s = s and cleanName(s)
	if s and s ~= "" then return s end
end

local function playerName()
	if cfg.name and cfg.name ~= "" then return cleanName(cfg.name) end
	if ui.name and ui.name.text then
		local n = cleanName(ui.name.text)
		if n ~= "" then
			if n == defaultName() then os.remove("lan_name.txt")
			else local f = io.open("lan_name.txt", "w"); if f then f:write(n); f:close() end end
			return n
		end
	end
	return savedName() or defaultName()
end

---------------------------------------------------------------- the small server (host only)
local function sendLine(c, text) if c.sock then c.sock:send(text .. "\n") end end
local function toAll(text, except) for _, c in ipairs(S.conns) do if c.name and c ~= except then sendLine(c, text) end end end
local function toBattle(text) for _, c in ipairs(S.conns) do if c.name and c.inBattle then sendLine(c, text) end end end
local function say(text) toBattle("SAIDBATTLE " .. HOSTNAME .. " " .. text) end
local function tag(k, v) toBattle("SETSCRIPTTAGS game/modoptions/" .. k .. "=" .. tostring(v)) end

local function battleUsers()
	local t = {}
	for _, c in ipairs(S.conns) do if c.name and c.inBattle then t[#t + 1] = c end end
	return t
end

-- SHARE-BEGIN (pure functions, no lobby needed; the test of the Level Editor loads this part by itself)
-- Player numbers: inside an ally team every human has a number 1 .. n (n = the humans of that ally team). By default everybody has a number of his
-- own; the host can give several humans the same number: they play ONE player together (one team of the start script, all of them can give orders to
-- its units and share its resources). humans: list of { name = , ally = , slot = number the host chose or nil }, in the order of joining; returns name -> number.
local function effectiveSlots(humans)
	local byAlly, out = {}, {}
	for _, h in ipairs(humans) do
		byAlly[h.ally] = byAlly[h.ally] or {}
		table.insert(byAlly[h.ally], h)
	end
	for _, list in pairs(byAlly) do
		local n = #list
		for i, h in ipairs(list) do
			-- the number the host chose (a number above the count of the team is not valid any more), otherwise the place in the team: so a human who
			-- chose the number of another one plays together with him, and the other one keeps his number
			out[h.name] = (h.slot and h.slot >= 1 and h.slot <= n) and h.slot or i
		end
	end
	return out
end

-- the number after this one inside a team of n humans (1 .. n, then 1 again)
local function nextSlot(current, n)
	return (current % math.max(1, n)) + 1
end

-- the humans who play one player together: list of { ally = , number = , names = { ... } } (only groups of two or more), ordered by ally and number
local function sharedGroups(humans, eff)
	local groups, order = {}, {}
	for _, h in ipairs(humans) do
		local key = h.ally .. ":" .. tostring(eff[h.name])
		if not groups[key] then
			groups[key] = { ally = h.ally, number = eff[h.name], names = {} }
			order[#order + 1] = groups[key]
		end
		table.insert(groups[key].names, h.name)
	end
	local out = {}
	for _, g in ipairs(order) do if #g.names > 1 then out[#out + 1] = g end end
	table.sort(out, function(a, b) if a.ally ~= b.ally then return a.ally < b.ally end return a.number < b.number end)
	return out
end
-- SHARE-END

-- the humans (not spectators) of the battle with their ally team and the number the host gave them
local function humanList(users)
	local l = lobby()
	local out = {}
	for _, c in ipairs(users or battleUsers()) do
		local bs = c.battleStatus and l and l:ParseBattleStatus(c.battleStatus)
		if bs and not bs.isSpectator then out[#out + 1] = { name = c.name, ally = bs.allyNumber, slot = c.slot } end
	end
	return out
end

local function groupText(g)
	return table.concat(g.names, " + ")
end

local function spectatorCount()
	local n = 1 -- the autohost
	local l = lobby()
	for _, c in ipairs(battleUsers()) do
		local bs = c.battleStatus and l and l:ParseBattleStatus(c.battleStatus)
		if not bs or bs.isSpectator then n = n + 1 end
	end
	return n
end

local function updateBattleInfo()
	toAll("UPDATEBATTLEINFO 1 " .. spectatorCount() .. " 0 0 " .. S.battle.map)
end

local function battleOpenedLine(c)
	local b = S.battle
	local ip = (c.sock:getsockname()) or "127.0.0.1"
	local engine = (Spring.Utilities and Spring.Utilities.GetEngineVersion and Spring.Utilities.GetEngineVersion()) or "2026.07.04"
	return string.format("BATTLEOPENED 1 0 0 %s %s %d 16 0 0 0 recoil\t%s\t%s\t%s\t%s", HOSTNAME, ip, GAMEPORT, engine, b.map, b.title, b.game)
end

-- ---- scenarios of the Level Editor (data\LevelEditorScenarios is a junction to scenario\scenarios): the team layout is the scenario's and cannot be changed
SCENARIO_FILE = "games/LevelEditorScenarios.sdz"
SCENARIO_GAME = "Level Editor Scenarios 1"  -- the extra game the Level Editor setup builds (all gadgets; they switch on by the game options of the scenario)

scenarioList = function()
	local names = {}
	for _, d in ipairs(VFS.SubDirs("LevelEditorScenarios/", "*", VFS.RAW) or {}) do
		local n = d:match("([^/\\]+)[/\\]?$")
		if n and VFS.LoadFile("LevelEditorScenarios/" .. n .. "/scenario.txt", VFS.RAW) then names[#names + 1] = n end
	end
	table.sort(names)
	return names
end

local function encodeStatus(s)
	local lsb = (s.isReady and 2 or 0) + (s.teamNumber % 16) * 4 + (s.allyNumber % 16) * 64 + (s.isSpectator and 0 or 1024) + ((s.handicap or 0) % 32) * 2048
	local msb = math.floor((s.handicap or 0) / 32) % 4 + (math.floor(s.teamNumber / 16) % 16) * 4 + ((s.sync or 0) % 4) * 64 + ((s.side or 0) % 16) * 256 + (math.floor(s.allyNumber / 16) % 16) * 4096
	return string.format("%d", msb * 65536 + lsb)
end

-- the user's status with the ally team the scenario wants (spectators stay as they are)
forcedStatus = function(c)
	local sc = S.battle.scenario
	local l = lobby()
	if not (sc and c.battleStatus and l) then return c.battleStatus end
	local bs = l:ParseBattleStatus(c.battleStatus)
	if bs.isSpectator or bs.allyNumber == sc.ally then return c.battleStatus end
	bs.allyNumber = sc.ally
	return encodeStatus(bs)
end

local function applyScenarioToUsers()
	for _, c in ipairs(battleUsers()) do
		local st = forcedStatus(c)
		if st ~= c.battleStatus then c.battleStatus = st; toBattle("CLIENTBATTLESTATUS " .. c.name .. " " .. st .. " " .. (c.teamColor or "0")) end
	end
end

selectScenario = function(name)
	if not S then return end
	if not name then
		S.battle.scenario = nil
		toBattle("SETSCRIPTTAGS game/modoptions/lanscenario=")
		toBattle("SETSCRIPTTAGS game/modoptions/lansync=")
		say("Scenario removed: choose a map and the teams as you like.")
		log("scenario cleared")
		return
	end
	local text = VFS.LoadFile("LevelEditorScenarios/" .. name .. "/scenario.txt", VFS.RAW)
	if not text then say("Scenario '" .. name .. "' could not be read."); return end
	local low = text:lower()
	local map = text:match("[Mm]apname%s*=%s*([^;]+);")
	local team = low:match("%[player0%]%s*{.-team%s*=%s*(%d+)")
	local ally = team and low:match("%[team" .. team .. "%]%s*{.-allyteam%s*=%s*(%d+)")
	if not (map and team and ally) then say("Scenario '" .. name .. "' has no player team (map " .. tostring(map) .. ")."); return end
	S.battle.scenario = { name = name, text = text, map = map, team = tonumber(team), ally = tonumber(ally) }
	-- the extra game: every computer needs the same file; the clients compare hash and size and fetch it from the host when theirs differs or is missing
	local data = VFS.LoadFile(SCENARIO_FILE, VFS.RAW)
	S.gameFile = nil
	if data then
		S.gameFile = { data = data, size = #data, hash = VFS.CalculateHash(data, 0) }
		toBattle("SETSCRIPTTAGS game/modoptions/lansync=" .. S.gameFile.hash .. "|" .. S.gameFile.size)
	else
		say("Warning: the extra game " .. SCENARIO_FILE .. " is not installed on the host (run the Level Editor setup).")
	end
	S.battle.map = map; updateBattleInfo()
	toBattle("SETSCRIPTTAGS game/modoptions/lanscenario=" .. name)
	applyScenarioToUsers()
	say("Scenario: " .. name .. " (map " .. map .. "). The teams are the scenario's; the players join the team of the first player.")
	log("scenario selected:", name, map, "player team", team, "ally team", ally)
end

local function startGameNow()
	if S.battle.running then return end
	S.battle.running = true
	log("the autohost starts the game")
	local humans = humanList()
	local parts = {}
	for _, g in ipairs(sharedGroups(humans, effectiveSlots(humans))) do parts[#parts + 1] = groupText(g) end
	if #parts > 0 and not S.battle.scenario then say("Playing together as one player: " .. table.concat(parts, "; ")) end
	say("Starting the game ...")
	toAll("CLIENTSTATUS " .. HOSTNAME .. " 65") -- bot + in game: every lobby in the battle connects
end

local function autohostCommand(c, msg)
	local isHost = (c == S.hostConn)
	local cmd, rest = msg:match("^!(%S+)%s*(.*)$")
	cmd = (cmd or ""):lower()
	if not isHost then say("Only the host can use !" .. cmd); return end
	if cmd == "map" and rest ~= "" then
		-- choosing a map sets the official-map mode again: the scenario (and its fixed teams) is dropped
		if S.battle.scenario then selectScenario(nil) end
		S.battle.map = rest; updateBattleInfo(); say("Map: " .. rest)
	elseif cmd == "bset" then
		local k, v = rest:match("^(%S+)%s+(.*)$")
		if k then S.battle.modoptions[k] = v; tag(k, v) end
	elseif cmd == "cv" and rest:lower():match("^start") then startGameNow()
	elseif cmd == "start" then startGameNow()
	else log("autohost: ignored command", msg) end
end

local function removeConn(c)
	for i, o in ipairs(S.conns) do if o == c then table.remove(S.conns, i); break end end
	pcall(function() c.sock:close() end)
	if c.name then
		if c.inBattle then
			c.inBattle = false
			toAll("LEFTBATTLE 1 " .. c.name)
			for i = #S.battle.bots, 1, -1 do
				local bot = S.battle.bots[i]
				if bot.owner == c.name then table.remove(S.battle.bots, i); toAll("REMOVEBOT 1 " .. bot.name) end
			end
		end
		toAll("REMOVEUSER " .. c.name)
		log("left:", c.name)
	end
end

local function serverLine(c, line)
	line = line:gsub("^#%d+%s+", "")
	local cmd, args = line:match("^(%S+)%s*(.*)$")
	if not cmd then return end
	if cmd == "FETCHGAME" and not c.name then
		local g = S.gameFile
		if g and args == g.hash then c.serve = { pos = 1, header = "SIZE " .. g.size .. "\n" }; log("serving the extra game to", tostring(c.sock:getpeername()))
		else c.close = true end
		return
	end
	if cmd == "WHO" then
		sendLine(c, "LANHOST " .. (S.hostName or "?") .. "|" .. S.battle.map .. "|" .. #battleUsers()); c.close = true
	elseif cmd == "PING" then sendLine(c, "PONG")
	elseif cmd == "LOGIN" then
		local name = cleanName(args:match("^(%S+)"))
		local taken = (name == "" or name == HOSTNAME)
		for _, o in ipairs(S.conns) do if o ~= c and o.name == name then taken = true end end
		if taken then sendLine(c, "DENIED name invalid or taken"); c.close = true; return end
		c.name = name
		if not S.hostConn then S.hostConn = c; S.hostName = name end
		sendLine(c, "ACCEPTED " .. name)
		sendLine(c, "ADDUSER " .. HOSTNAME .. " XX 0 LAN")
		sendLine(c, "CLIENTSTATUS " .. HOSTNAME .. " 64")
		for _, o in ipairs(S.conns) do
			if o.name then sendLine(c, "ADDUSER " .. o.name .. " XX " .. o.id .. " LAN"); sendLine(c, "CLIENTSTATUS " .. o.name .. " 0") end
		end
		toAll("ADDUSER " .. name .. " XX " .. c.id .. " LAN", c); toAll("CLIENTSTATUS " .. name .. " 0", c)
		sendLine(c, battleOpenedLine(c))
		for _, o in ipairs(battleUsers()) do sendLine(c, "JOINEDBATTLE 1 " .. o.name .. " " .. (o.scriptPassword or "")) end
		sendLine(c, "LOGININFOEND")
		log("login:", name)
	elseif not c.name then return
	elseif cmd == "JOINBATTLE" then
		local _, _, sp = args:match("^(%S+)%s+(%S+)%s*(%S*)")
		c.scriptPassword = (sp and sp ~= "") and sp or tostring(math.random(100000, 999999)); c.inBattle = true
		sendLine(c, "JOINBATTLE 1 0")
		toBattle("JOINEDBATTLE 1 " .. c.name .. " " .. c.scriptPassword)
		for _, o in ipairs(battleUsers()) do
			if o ~= c and o.battleStatus then sendLine(c, "CLIENTBATTLESTATUS " .. o.name .. " " .. o.battleStatus .. " " .. (o.teamColor or "0")) end
		end
		for k, v in pairs(S.battle.modoptions) do sendLine(c, "SETSCRIPTTAGS game/modoptions/" .. k .. "=" .. tostring(v)) end
		if S.battle.scenario then sendLine(c, "SETSCRIPTTAGS game/modoptions/lanscenario=" .. S.battle.scenario.name) end
		if S.battle.scenario and S.gameFile then sendLine(c, "SETSCRIPTTAGS game/modoptions/lansync=" .. S.gameFile.hash .. "|" .. S.gameFile.size) end
		for _, bot in ipairs(S.battle.bots) do sendLine(c, string.format("ADDBOT 1 %s %s %s %s %s", bot.name, bot.owner, bot.status, bot.color, bot.lib)) end
		sendLine(c, "REQUESTBATTLESTATUS")
		updateBattleInfo()
		log("joined the battle:", c.name)
	elseif cmd == "LEAVEBATTLE" then
		if c.inBattle then c.inBattle = false; toAll("LEFTBATTLE 1 " .. c.name); updateBattleInfo() end
	elseif cmd == "MYBATTLESTATUS" then
		local st, col = args:match("^(%S+)%s+(%S+)")
		if st and c.inBattle then
			c.battleStatus, c.teamColor = st, col
			c.battleStatus = forcedStatus(c)   -- with a scenario the ally team is the scenario's: the corrected status goes to everybody, also the sender
			toBattle("CLIENTBATTLESTATUS " .. c.name .. " " .. c.battleStatus .. " " .. col); updateBattleInfo()
		end
	elseif cmd == "SAYBATTLE" and c.inBattle then
		if args:sub(1, 1) == "!" then autohostCommand(c, args) else toBattle("SAIDBATTLE " .. c.name .. " " .. args) end
	elseif cmd == "SAYBATTLEEX" and c.inBattle then toBattle("SAIDBATTLEEX " .. c.name .. " " .. args)
	elseif cmd == "ADDBOT" and c.inBattle then
		local name, st, col, lib = args:match("^(%S+)%s+(%S+)%s+(%S+)%s+(.*)$")
		if name then
			S.battle.bots[#S.battle.bots + 1] = { name = name, owner = c.name, status = st, color = col, lib = lib }
			toBattle(string.format("ADDBOT 1 %s %s %s %s %s", name, c.name, st, col, lib))
		end
	elseif cmd == "REMOVEBOT" and c.inBattle then
		local name = args:match("^(%S+)")
		for i, bot in ipairs(S.battle.bots) do if bot.name == name then table.remove(S.battle.bots, i); toBattle("REMOVEBOT 1 " .. name); break end end
	elseif cmd == "UPDATEBOT" and c.inBattle then
		local name, st, col = args:match("^(%S+)%s+(%S+)%s+(%S+)")
		for _, bot in ipairs(S.battle.bots) do if bot.name == name then bot.status, bot.color = st, col; toBattle(string.format("UPDATEBOT 1 %s %s %s", name, st, col)) end end
	elseif cmd == "EXIT" then c.close = true
	else
		S.unknown = S.unknown or {}
		if not S.unknown[cmd] then S.unknown[cmd] = true; log("server: ignored command", cmd) end
	end
end

local function updateServer()
	local new = S.srv:accept()
	while new do
		new:settimeout(0)
		S.nextId = S.nextId + 1
		local c = { sock = new, buf = "", id = S.nextId, t = os.clock() }
		S.conns[#S.conns + 1] = c
		sendLine(c, "TASSERVER 0.38 " .. ((Spring.Utilities and Spring.Utilities.GetEngineVersion and Spring.Utilities.GetEngineVersion()) or "2026.07.04") .. " " .. PORT .. " 0")
		new = S.srv:accept()
	end
	for i = #S.conns, 1, -1 do
		local c = S.conns[i]
		local data, err, partial = c.sock:receive(8192)
		data = data or partial
		if data and #data > 0 then c.buf = c.buf .. data end
		while true do
			local n = c.buf:find("\n", 1, true)
			if not n then break end
			local line = c.buf:sub(1, n - 1):gsub("\r$", "")
			c.buf = c.buf:sub(n + 1)
			local ok, e = pcall(serverLine, c, line)
			if not ok then log("server error:", tostring(e), "in", line:sub(1, 60)) end
		end
		if c.serve and S.gameFile then
			local sv = c.serve
			if sv.header then
				local n = c.sock:send(sv.header)
				if n then sv.header = nil end
			else
				local last, e, partial = c.sock:send(S.gameFile.data, sv.pos, math.min(sv.pos + 65535, S.gameFile.size))
				local sent = last or partial
				if sent then sv.pos = sent + 1 end
				if sv.pos > S.gameFile.size then c.close = true; log("extra game served") end
			end
		end
		if err == "closed" or c.close or (not c.name and not c.serve and os.clock() - c.t > 6) then removeConn(c) end
	end
end

-- the start script of the game, built from the state of the room (what the autohost SPADS does on a normal server)
-- a scenario: its own script (teams, units, options, start positions); every human joins the team of the first player
local function buildScenarioScript(myName)
	local sc = S.battle.scenario
	local text = sc.text
	local players = {}
	for _, c in ipairs(battleUsers()) do if c.name ~= myName then players[#players + 1] = c end end
	local origPlayers = tonumber(text:match("numplayers%s*=%s*(%d+)")) or 1
	local origUsers = tonumber(text:match("numusers%s*=%s*(%d+)")) or origPlayers
	local l = lobby()
	local extra = {}
	for i, c in ipairs(players) do
		local bs = c.battleStatus and l:ParseBattleStatus(c.battleStatus)
		local spec = (not bs) or bs.isSpectator
		extra[#extra + 1] = string.format("\t[player%d]\n\t{\n\t\tName=%s;\n\t\tPassword=%s;\n\t\tTeam=%d;\n\t\tspectator=%d;\n\t\trank=0;\n\t}\n", i, c.name, c.scriptPassword or "", sc.team, spec and 1 or 0)
	end
	text = text:gsub("__GAMETYPE__", SCENARIO_GAME):gsub("__PLAYERNAME__", myName)
	text = text:gsub("hostip%s*=%s*[%d%.]+;", "hostip=0.0.0.0;"):gsub("hostport%s*=%s*%d+;", "hostport=" .. GAMEPORT .. ";")
	text = text:gsub("numplayers%s*=%s*%d+;", "numplayers=" .. (1 + #players) .. ";"):gsub("numusers%s*=%s*%d+;", "numusers=" .. (1 + #players + (origUsers - origPlayers)) .. ";")
	local at = text:find("[modoptions]", 1, true) or text:find("[MODOPTIONS]", 1, true)
	if at and #extra > 0 then
		local before = text:sub(1, at - 1)
		local lineStart = #before - (before:match("[^\n]*$") or ""):len()
		text = text:sub(1, lineStart) .. table.concat(extra) .. text:sub(lineStart + 1)
	end
	return text
end

buildScript = function(myName)
	if S.battle.scenario then return buildScenarioScript(myName) end
	local l = lobby()
	local cf = Config()
	local players, teams, ais = {}, {}, {}
	local allyIndex = {}
	local function ally(a) if allyIndex[a] == nil then local n = 0; for _ in pairs(allyIndex) do n = n + 1 end; allyIndex[a] = n end; return allyIndex[a] end
	local pi = 0
	local eff = effectiveSlots(humanList())
	-- the start positions are chosen in the game (2) unless humans play one player together: the game of such a team is started by the little widget
	-- shared_start.lua as soon as everybody has loaded, nobody could place a start position before that, so the positions of the map are used (0)
	local startPos = (#sharedGroups(humanList(), eff) > 0) and 0 or 2
	local groupTeam = {} -- "ally:number" -> the team of the start script (the humans with the same number play it together)
	local function rgb(col) col = tonumber(col) or 0; return string.format("%.4f %.4f %.4f", (col % 256) / 255, (math.floor(col / 256) % 256) / 255, (math.floor(col / 65536) % 256) / 255) end
	local function sideName(s) local sd = cf and cf:GetSideById(s); return (sd and sd.name) or "Armada" end
	-- the host is player 0 (the little widget shared_start.lua acts only in the game of player 0)
	local users = {}
	for _, c in ipairs(battleUsers()) do if c.name == myName then users[#users + 1] = c end end
	for _, c in ipairs(battleUsers()) do if c.name ~= myName then users[#users + 1] = c end end
	for _, c in ipairs(users) do
		local bs = c.battleStatus and l:ParseBattleStatus(c.battleStatus) or { isSpectator = true }
		local p = { name = c.name, password = c.scriptPassword, spec = bs.isSpectator, index = pi }
		if not bs.isSpectator then
			local key = tostring(bs.allyNumber) .. ":" .. tostring(eff[c.name])
			if groupTeam[key] == nil then
				groupTeam[key] = #teams
				teams[#teams + 1] = { leader = pi, ally = ally(bs.allyNumber), color = rgb(c.teamColor), side = sideName(bs.side), handicap = bs.handicap or 0 }
			end
			p.team = groupTeam[key]
		end
		players[#players + 1] = p; pi = pi + 1
	end
	for _, bot in ipairs(S.battle.bots) do
		local bs = l:ParseBattleStatus(bot.status)
		local lib, ver = bot.lib:match("^(%S+)%s*(.*)$")
		ais[#ais + 1] = { name = bot.name, lib = lib or bot.lib, version = ver, team = #teams }
		teams[#teams + 1] = { leader = 0, ally = ally(bs.allyNumber), color = rgb(bot.color), side = sideName(bs.side), handicap = bs.handicap or 0 }
	end
	local t = { "[GAME]\n{\n\tGameType=", S.battle.game, ";\n\tMapName=", S.battle.map, ";\n\tHostIP=0.0.0.0;\n\tHostPort=", GAMEPORT,
		";\n\tIsHost=1;\n\tMyPlayerName=", myName, ";\n\tNumPlayers=", #players, ";\n\tNumUsers=", #players + #ais, ";\n\tStartPosType=", startPos, ";\n\tNoHelperAIs=0;\n\tGameStartDelay=5;\n" }
	t[#t + 1] = "\t[MODOPTIONS]\n\t{\n"
	for k, v in pairs(S.battle.modoptions) do t[#t + 1] = "\t\t" .. k .. "=" .. tostring(v) .. ";\n" end
	t[#t + 1] = string.format("\t\tdate_year=%s;\n\t\tdate_month=%s;\n\t\tdate_day=%s;\n\t\tdate_hour=%s;\n\t}\n", os.date("%Y"), os.date("%m"), os.date("%d"), os.date("%H"))
	for _, p in ipairs(players) do
		t[#t + 1] = string.format("\t[PLAYER%d]\n\t{\n\t\tName=%s;\n\t\tPassword=%s;\n\t\tTeam=%d;\n\t\trank=0;\n%s\t}\n", p.index, p.name, p.password or "", p.team or 0, p.spec and "\t\tSpectator=1;\n" or "")
	end
	for i, a in ipairs(ais) do
		t[#t + 1] = string.format("\t[AI%d]\n\t{\n\t\tName=%s;\n\t\tShortName=%s;\n\t\tVersion=%s;\n\t\tTeam=%d;\n\t\tHost=0;\n\t}\n", i - 1, a.name, a.lib, a.version or "", a.team)
	end
	for i, tm in ipairs(teams) do
		t[#t + 1] = string.format("\t[TEAM%d]\n\t{\n\t\tTeamLeader=%d;\n\t\tAllyTeam=%d;\n\t\tRgbColor=%s;\n\t\tSide=%s;\n\t\tHandicap=%d;\n\t}\n", i - 1, tm.leader, tm.ally, tm.color, tm.side, tm.handicap)
	end
	local nAlly = 0; for _ in pairs(allyIndex) do nAlly = nAlly + 1 end
	for a = 0, math.max(nAlly - 1, 0) do t[#t + 1] = string.format("\t[ALLYTEAM%d]\n\t{\n\t\tNumAllies=0;\n\t}\n", a) end
	t[#t + 1] = "}\n"
	return table.concat(t)
end

---------------------------------------------------------------- the lobby of this computer: connect to a LAN server, restore the normal server afterwards
local function hookConnect()
	if hookedConnect then return end
	local l = lobby(); if not l then return end
	local original = l.ConnectToBattle
	l.ConnectToBattle = function(self, ...)
		if lan and lan.role == "host" and S then
			-- the host's lobby is the one that runs the game server
			local script = buildScript(lan.name)
			log("Spring.Reload (host) with start script:\n" .. script)
			return Spring.Reload(script)
		end
		if lan and lan.role == "client" and self.modoptions and self.modoptions.lanscenario and self.modoptions.lanscenario ~= "" then
			local tag = self.modoptions.lansync or ""
			local hash = tag:match("^(.-)|") or ""
			if lan.fetch or lan.syncPending or (hash ~= "" and lan.syncHash ~= hash and lan.syncFailed ~= hash and localGameHash() ~= hash) then
				-- still loading (or about to ask): the connection to the game is made as soon as the file is there
				lan.pendingConnect = { orig = original, args = { ... } }
				log("start postponed until the scenario game is loaded")
				return
			end
			if lan.syncFailed == hash and hash ~= "" and localGameHash() ~= hash then
				local msg = "The scenario game of the host was not loaded: the scenario cannot start for you."
				log(msg); if WG.Chobby and WG.Chobby.InformationPopup then WG.Chobby.InformationPopup(msg) end
				return
			end
		end
		if lan and self.modoptions and self.modoptions.lanscenario and self.modoptions.lanscenario ~= "" and not VFS.HasArchive(SCENARIO_GAME) then
			-- the scenario needs the extra game of the Level Editor setup on this computer too
			local msg = "The host plays the scenario '" .. self.modoptions.lanscenario .. "': it needs the game '" .. SCENARIO_GAME .. "' (installed by the Level Editor setup, install_editor.bat). Install the Level Editor and start the game again."
			log("cannot join the scenario:", msg)
			if WG.Chobby and WG.Chobby.InformationPopup then WG.Chobby.InformationPopup(msg) end
			return
		end
		return original(self, ...)
	end
	hookedConnect = true
end

local function openLanPage()
	local root = WG.Chobby and WG.Chobby.interfaceRoot
	if root and root.OpenSingleplayerTabByName then pcall(root.OpenSingleplayerTabByName, "LAN Play") end
end

local function lanStop(reason, noReconnect)
	log("lanStop:", reason, "configured server", tostring(Config() and Config().serverAddress))
	local l = lobby()
	if S then
		for _, c in ipairs(S.conns) do pcall(function() c.sock:close() end) end
		pcall(function() S.srv:close() end)
		S = nil
	end
	local wasLan = lan ~= nil
	if lan and lan.leftListener and l then pcall(l.RemoveListener, l, "OnLeftBattle", lan.leftListener) end
	lan = nil
	if wasLan and not noReconnect and l then
		-- back to the normal server: the lobby is disconnected from the LAN server and logs in again the way the settings window does after a server change
		pcall(function() l:Disconnect(reason or "LAN play ended") end)
		local cf = Config()
		if cf and cf.serverAddress then pcall(function() l.host = cf.serverAddress end) end
		if WG.LoginWindowHandler and WG.LoginWindowHandler.TryLogin then pcall(WG.LoginWindowHandler.TryLogin) end
		log("back on the normal server:", tostring(cf and cf.serverAddress))
	end
end

local function lanConnect(role, ip, name)
	local l, cf = lobby(), Config()
	if not (l and cf) then setStatus("The lobby is not ready."); return false end
	if lan then lanStop("new LAN game", true) end
	lan = { role = role, ip = ip, name = name, step = "connecting", t = os.clock() }
	-- the configuration (server address) stays as it is: the lobby saves it when it ends. Only this connection goes to the LAN server.
	pcall(function() l:Disconnect("LAN play") end)
	-- the login window sends the login when the server has greeted (OnConnect): do the same here
	local function onConnect()
		l:RemoveListener("OnConnect", onConnect)
		log("server greeted; login as", name)
		l:Login(name, "lan", 3, nil, "Chobby")
	end
	l:AddListener("OnConnect", onConnect)
	-- leaving the battle room (the Leave button) ends the LAN game and brings the player back to the LAN Play page
	lan.leftListener = function(listener, battleID, userName)
		if lan and userName == l:GetMyUserName() then lan.left = os.clock() end
	end
	l:AddListener("OnLeftBattle", lan.leftListener)
	l:Connect(ip, PORT, name, "lan", 0, "*", "Chobby")
	return true
end

local function startHosting()
	local cf = Config()
	if S or lan then lanStop("restart") end
	local s, e = socket.bind("*", PORT)
	if not s then setStatus("Cannot listen on port " .. PORT .. ": " .. tostring(e)); return end
	s:settimeout(0)
	local name = playerName()
	local game = cf and cf:GetDefaultGameName() or "Beyond All Reason"
	S = { srv = s, conns = {}, nextId = 100, battle = { map = (cfg.map and cfg.map ~= "" and cfg.map) or "Hooked 1.1", game = game, title = "LAN game of " .. name, modoptions = {}, bots = {} } }
	found = {}; updateFoundUi()
	setStatus("Hosting as " .. name .. " (port " .. PORT .. ").")
	lanConnect("host", "127.0.0.1", name)
end

local function joinHost(ip)
	local cf = Config()
	if S then lanStop("join") end
	local name = playerName()
	setStatus("Connecting to " .. ip .. " as " .. name .. " ...")
	lanConnect("client", ip, name)
end

-- ---- the extra game of the scenario on a joiner: the host announces hash and size (game option lansync); a different or missing file is fetched from the host after a question
localGameHash = function()
	local data = VFS.LoadFile(SCENARIO_FILE, VFS.RAW)
	return data and VFS.CalculateHash(data, 0) or nil, data and #data or 0
end

local function finishFetch(f, ok, reason)
	pcall(function() f.sock:close() end)
	lan.fetch = nil
	if ok then
		lan.syncHash = f.hash; lan.syncPending = false
		setStatus("The scenario game is up to date.")
		if lan.pendingConnect then
			local a = lan.pendingConnect; lan.pendingConnect = nil
			local l = lobby()
			if l then a.orig(l, unpack(a.args)) end
		end
	else
		lan.syncFailed = f.hash; lan.syncPending = false; lan.pendingConnect = nil
		setStatus("Could not load the scenario game from the host: " .. tostring(reason))
		if WG.Chobby and WG.Chobby.InformationPopup then WG.Chobby.InformationPopup("Could not load the scenario game from the host: " .. tostring(reason)) end
	end
end

local function startFetch(hash, size)
	local s = socket.tcp(); s:settimeout(3)
	local ok, e = s:connect(lan.ip, PORT)
	if not ok then finishFetch({ sock = s, hash = hash }, false, "no connection (" .. tostring(e) .. ")"); return end
	s:settimeout(0)
	s:send("FETCHGAME " .. hash .. "\n")
	lan.fetch = { sock = s, hash = hash, size = size, buf = "", parts = {}, got = 0, total = nil, t = os.clock() }
	lan.syncPending = true
	setStatus("Loading the scenario game from the host ...")
end

local function updateFetch()
	local f = lan.fetch
	local data, err, partial = f.sock:receive(65536)
	data = data or partial
	if data and #data > 0 then
		if not f.total then
			f.buf = f.buf .. data
			-- the server greets every connection first (TASSERVER ...); then comes "SIZE <n>" and the bytes
			while not f.total do
				local nl = f.buf:find("\n", 1, true)
				if not nl then break end
				local line = f.buf:sub(1, nl - 1)
				f.buf = f.buf:sub(nl + 1)
				local n = line:match("^SIZE (%d+)$")
				if n then
					f.total = tonumber(n)
					if f.total ~= f.size or f.total > 4 * 1024 * 1024 then finishFetch(f, false, "the host sends another size than he announced"); return end
					local rest = f.buf; f.buf = ""
					if #rest > 0 then f.parts[#f.parts + 1] = rest:sub(1, f.total); f.got = math.min(#rest, f.total) end
				elseif not line:find("^TASSERVER") then
					finishFetch(f, false, "the host answered something else"); return
				end
			end
		else
			local take = math.min(#data, f.total - f.got)   -- never more than the announced size
			if take > 0 then f.parts[#f.parts + 1] = data:sub(1, take); f.got = f.got + take end
		end
	end
	if f.total and f.got >= f.total then
		local all = table.concat(f.parts)
		if VFS.CalculateHash(all, 0) ~= f.hash then finishFetch(f, false, "the file is not the one that was announced (hash)"); return end
		local part = SCENARIO_FILE .. ".part"
		local fh = io.open(part, "wb")
		if not fh then finishFetch(f, false, "cannot write " .. part); return end
		fh:write(all); fh:close()
		os.remove(SCENARIO_FILE)
		if not os.rename(part, SCENARIO_FILE) then finishFetch(f, false, "cannot replace " .. SCENARIO_FILE); return end
		pcall(VFS.ScanAllDirs)
		log("the extra game was loaded from the host:", f.total, "bytes; archive present:", tostring(VFS.HasArchive(SCENARIO_GAME)))
		finishFetch(f, true)
	elseif err == "closed" or os.clock() - f.t > 30 then
		finishFetch(f, false, err == "closed" and "the host closed the connection" or "timeout")
	end
end

local function updateSync()
	if not lan or lan.role ~= "client" then return end
	local l = lobby()
	local mo = l and l.modoptions
	if lan.fetch then updateFetch(); return end
	local tag = mo and mo.lansync
	if not (mo and mo.lanscenario and mo.lanscenario ~= "" and tag and tag ~= "") then return end
	local hash, size = tag:match("^(.-)|(%d+)$")
	if not hash or lan.syncHash == hash or lan.syncAsked == hash then return end
	local mine = localGameHash()
	if mine == hash then lan.syncHash = hash; return end
	lan.syncAsked = hash
	local function yes() startFetch(hash, tonumber(size)) end
	local function no() lan.syncFailed = hash; setStatus("You did not load the scenario game: the scenario cannot start for you.") end
	if cfg.autoAccept then yes(); return end
	local q = "The host plays the scenario '" .. mo.lanscenario .. "'. Your game '" .. SCENARIO_GAME .. "' is " .. (mine and "different from his" or "missing") .. ". Load it from the host (" .. math.ceil(tonumber(size) / 1024) .. " KB, gadgets of the scenarios)? Only do this with a host you trust."
	if WG.Chobby and WG.Chobby.ConfirmationPopup then WG.Chobby.ConfirmationPopup(yes, q, nil, 480, 260, "Load it", "No", no) else yes() end
end

local function updateLan()
	updateSync()
	if not lan then return end
	local l = lobby()
	if not l then return end
	if lan.step == "connecting" then
		if l.status == "connected" and l.battles and l.battles[1] then
			lan.step = "joining"; lan.t = os.clock()
			log("logged in; joining the battle")
			l:JoinBattle(1)
		elseif os.clock() - lan.t > 10 then
			setStatus("No answer from " .. tostring(lan.ip) .. " (lobby status " .. tostring(l.status) .. ")."); lanStop("no answer")
		end
	elseif lan.step == "joining" then
		if l:GetMyBattleID() == 1 then
			lan.step = "in"; setStatus("In the LAN battle room of " .. tostring(lan.ip) .. ".")
		elseif os.clock() - lan.t > 10 then setStatus("Could not join the battle."); lan.step = "failed" end
	end
end

---------------------------------------------------------------- finding games: WHO on the lobby port of every address of the own /24 network
local function startScan(quiet)
	local me = (socket.dns and socket.dns.toip and socket.dns.toip(socket.dns.gethostname())) or "127.0.0.1"
	local a, b, c = tostring(me):match("^(%d+)%.(%d+)%.(%d+)%.%d+$")
	local list = {}
	if a then for i = 1, 254 do list[#list + 1] = a .. "." .. b .. "." .. c .. "." .. i end else list[1] = "127.0.0.1" end
	scan = { list = list, next = 1, open = {}, until_ = os.clock() + 8, started = os.clock(), results = {}, quiet = quiet }
	if not quiet then
		log("scan from own address", me, "(", #list, "addresses )")
		setStatus("Searching for games in the network ...")
	end
end

updateFoundUi = function()
	if not ui.found then return end
	for i, b in ipairs(ui.found) do
		local f = (not S) and found[i] or nil
		if f then b:SetCaption(f.ip .. "   " .. f.name .. "   " .. f.map .. "   (" .. f.players .. ")"); b:Show() else b:Hide() end
	end
end

local function updateScan()
	if not scan then return end
	for _ = 1, 24 do
		local ip = scan.list[scan.next]; if not ip then break end
		scan.next = scan.next + 1
		local s = socket.tcp(); s:settimeout(0)
		s:connect(ip, PORT)
		scan.open[#scan.open + 1] = { sock = s, ip = ip, buf = "", sent = false, t = os.clock() }
	end
	for i = #scan.open, 1, -1 do
		local o = scan.open[i]
		local drop = false
		if not o.sent then
			local _, w = socket.select(nil, { o.sock }, 0)
			if w and #w > 0 then
				local n = o.sock:send("WHO\n")
				if n then o.sent = true else drop = true end
			elseif os.clock() - o.t > 2 then drop = true end
		else
			local data, err, partial = o.sock:receive(2048)
			data = data or partial
			if data and #data > 0 then o.buf = o.buf .. data end
			for l in o.buf:gmatch("[^\r\n]+") do
				local name, map, players = l:match("^LANHOST (.-)|(.-)|(%d+)$")
				if name and not o.done then o.done = true; scan.results[#scan.results + 1] = { ip = o.ip, name = name, map = map, players = players } end
			end
			if err == "closed" or os.clock() - o.t > 3 then drop = true end
		end
		if drop then o.sock:close(); table.remove(scan.open, i) end
	end
	if (scan.next > #scan.list and #scan.open == 0) or os.clock() > scan.until_ then
		for _, o in ipairs(scan.open) do o.sock:close() end
		local results, quiet = scan.results, scan.quiet
		found = results
		updateFoundUi()
		if not quiet or #results ~= lastFoundCount then log("scan finished:", #results, "game(s) in", string.format("%.1f", os.clock() - scan.started), "s"); for _, f in ipairs(results) do log("found", f.ip, f.name, f.map, f.players) end end
		lastFoundCount = #results
		if ui.status and not (lan or S) then ui.status:SetText(#results > 0 and ("Games found: " .. #results .. " - click one to join it.") or "No LAN game found (searching again every few seconds).") end
		nextScanAt = os.clock() + 4
		scan = nil
	end
end

---------------------------------------------------------------- the entry in the main menu: a tab added to the menu the lobby has built (rank 1.5: right below Multiplayer, which is 1; the menu is one column, there is no place beside it)
local function findByName(ctrl, name, depth)
	if not ctrl or depth > 12 then return nil end
	if ctrl.name == name then return ctrl end
	for _, ch in ipairs(ctrl.children or {}) do
		local r = findByName(ch, name, depth + 1)
		if r then return r end
	end
end

local function ensureTab()
	if not ui.panel then return end
	if tabCheckAt and os.clock() < tabCheckAt then return end
	tabCheckAt = os.clock() + 1
	local root = WG.Chobby and WG.Chobby.interfaceRoot
	local sub = root and root.GetSingleplayerSubmenu and root.GetSingleplayerSubmenu()
	if not sub then return end
	-- the lobby may build its menu again (the tabs are new then): check every second that the tab is there
	local button = findByName(screen0, "LAN Play_button", 0)
	if not sub.GetTabByName("LAN Play") or not button or not button.parent then
		if sub.GetTabByName("LAN Play") then pcall(sub.RemoveTab, "LAN Play") end
		local ok, err = pcall(sub.AddTab, "LAN Play", "LAN Play", ui.panel, nil, 1.5)
		tabAdded = os.clock(); tabReported = false
		tabAddCount = (tabAddCount or 0) + 1
		if tabAddCount <= 3 then log("tab added to the main menu:", tostring(ok), tostring(err), "indexes: LAN", tostring((sub.GetTabByName("LAN Play"))), "multiplayer", tostring((sub.GetTabByName("multiplayer")))) end
		return
	end
	if not tabReported and tabAdded and os.clock() > tabAdded + 3 then
		tabReported = true
		for _, n in ipairs({ "multiplayer_button", "LAN Play_button", "skirmish_button" }) do
			local c = findByName(screen0, n, 0)
			if c then
				local x, y = c:LocalToScreen(0, 0)
				log("button", n, "screen x/y", math.floor(x), math.floor(y), "size", math.floor(c.width), math.floor(c.height), "visible", tostring(c.visible))
			else log("button", n, "not found") end
		end
	end
end

-- while the LAN Play page is open (and this computer neither hosts nor plays a LAN game): look for games every few seconds
local function autoScan()
	if scan or S or lan then return end
	local visible = ui.panel and ui.panel.parent and ui.panel.visible
	if not visible then nextScanAt = nil; return end
	if not nextScanAt then nextScanAt = os.clock() end
	if os.clock() >= nextScanAt then startScan(true) end
end

---------------------------------------------------------------- "Custom Scenario": a floating button top left (host only, while the LAN battle room is open) and a list of the built scenarios
local function scenarioMap(name)
	local text = VFS.LoadFile("LevelEditorScenarios/" .. name .. "/scenario.txt", VFS.RAW) or ""
	return text:match("[Mm]apname%s*=%s*([^;]+);") or "?"
end

local function fillScenarioList()
	local font = Config():GetFont(2)
	ui.scnList:ClearChildren()
	local y = 0
	local function add(caption, fn)
		Button:New { parent = ui.scnList, x = 0, y = y, right = 0, height = 36, caption = caption, objectOverrideFont = font,
			OnClick = { function() ui.scnWindow:Hide(); fn() end } }
		y = y + 40
	end
	add("Official map (no scenario)", function() selectScenario(nil) end)
	for _, name in ipairs(scenarioList()) do
		add(name .. "   (" .. scenarioMap(name) .. ")", function() selectScenario(name) end)
	end
end

local function ensureScenarioUi()
	if not ui.panel or not Config() then return end
	local show = (S ~= nil) and lan ~= nil and lan.step == "in"
	if not ui.scnButton then
		if not show then return end
		local font = Config():GetFont(2)
		ui.scnWindow = Window:New { parent = screen0, x = 8, y = 48, width = 420, height = 330, resizable = false, draggable = true, classname = "main_window" }
		ui.scnList = ScrollPanel:New { parent = ui.scnWindow, x = 6, y = 6, right = 6, bottom = 6 }
		ui.scnWindow:Hide()
		ui.scnButton = Button:New { parent = screen0, x = 8, y = 8, width = 200, height = 36, caption = "Custom Scenario", objectOverrideFont = font, classname = "action_button",
			OnClick = { function()
				if ui.scnWindow.visible then ui.scnWindow:Hide() else fillScenarioList(); ui.scnWindow:Show(); ui.scnWindow:BringToFront() end
			end } }
		log("Custom Scenario button added")
	end
	if ui.scnButton.visible ~= show then ui.scnButton:SetVisibility(show) end
	if not show and ui.scnWindow and ui.scnWindow.visible then ui.scnWindow:Hide() end
end

---------------------------------------------------------------- "Play together": numbers per human; the same number inside an ally team = one player together
-- Pressing the button of a human gives him the next number of his ally team (1 .. number of humans in it); everybody in the room gets a chat line.
local function cycleSlot(name)
	if not S then return end
	local humans = humanList()
	local eff = effectiveSlots(humans)
	local me
	local n = 0
	for _, h in ipairs(humans) do if h.name == name then me = h end end
	if not me then return end
	for _, h in ipairs(humans) do if h.ally == me.ally then n = n + 1 end end
	local newNo = nextSlot(eff[name], n)
	for _, c in ipairs(battleUsers()) do if c.name == name then c.slot = newNo end end
	humans = humanList()
	eff = effectiveSlots(humans)
	local with = {}
	for _, h in ipairs(humans) do if h.name ~= name and h.ally == me.ally and eff[h.name] == eff[name] then with[#with + 1] = h.name end end
	if #with > 0 then
		say(name .. " is player " .. eff[name] .. " of his team now and plays it together with " .. table.concat(with, ", ") .. ".")
	else
		say(name .. " is player " .. eff[name] .. " of his team now (alone).")
	end
	log("slot:", name, "->", eff[name], #with > 0 and ("together with " .. table.concat(with, ", ")) or "alone")
end

local function slotSignature()
	if not S then return "" end
	local humans = humanList()
	local eff = effectiveSlots(humans)
	local t = {}
	for _, h in ipairs(humans) do t[#t + 1] = h.name .. ":" .. h.ally .. ":" .. tostring(eff[h.name]) end
	return table.concat(t, "|") .. (S.battle.scenario and "|scenario" or "")
end

local function fillSlotList()
	local font = Config():GetFont(2)
	ui.slotList:ClearChildren()
	local y = 0
	local humans = humanList()
	if S.battle.scenario then
		TextBox:New { parent = ui.slotList, x = 0, y = y, right = 0, height = 60, text = "A scenario: every human plays the team of the scenario together.", objectOverrideFont = font }
		return
	end
	if #humans == 0 then
		TextBox:New { parent = ui.slotList, x = 0, y = y, right = 0, height = 30, text = "No players in the room (spectators do not count).", objectOverrideFont = font }
		return
	end
	table.sort(humans, function(a, b) if a.ally ~= b.ally then return a.ally < b.ally end return a.name < b.name end)
	local eff = effectiveSlots(humans)
	local groupOf = {}
	for _, g in ipairs(sharedGroups(humans, eff)) do groupOf[g.ally .. ":" .. g.number] = g end
	local lastAlly
	for _, h in ipairs(humans) do
		if h.ally ~= lastAlly then
			lastAlly = h.ally
			TextBox:New { parent = ui.slotList, x = 0, y = y + 4, right = 0, height = 30, text = "Team " .. (h.ally + 1), objectOverrideFont = font }
			y = y + 36
		end
		local name = h.name
		TextBox:New { parent = ui.slotList, x = 12, y = y + 8, width = 190, height = 30, text = name, objectOverrideFont = font }
		Button:New { parent = ui.slotList, x = 210, y = y, width = 130, height = 36, caption = "player " .. eff[name], objectOverrideFont = font,
			OnClick = { function() cycleSlot(name); fillSlotList() end } }
		local g = groupOf[h.ally .. ":" .. eff[name]]
		if g then
			local others = {}
			for _, o in ipairs(g.names) do if o ~= name then others[#others + 1] = o end end
			TextBox:New { parent = ui.slotList, x = 350, y = y + 8, right = 0, height = 30, text = "+ together with " .. table.concat(others, ", "), objectOverrideFont = font }
		end
		y = y + 42
	end
end

local function ensureSlotUi()
	if not ui.panel or not Config() then return end
	local show = (S ~= nil) and lan ~= nil and lan.step == "in"
	if not ui.slotButton then
		if not show then return end
		local font = Config():GetFont(2)
		ui.slotWindow = Window:New { parent = screen0, x = 216, y = 48, width = 560, height = 420, resizable = false, draggable = true, classname = "main_window" }
		TextBox:New { parent = ui.slotWindow, x = 12, y = 8, right = 12, height = 56, text = "Click a player to give him the next number of his team. Players with the same number play one player together.", objectOverrideFont = Config():GetFont(1) }
		ui.slotList = ScrollPanel:New { parent = ui.slotWindow, x = 6, y = 70, right = 6, bottom = 6 }
		ui.slotWindow:Hide()
		ui.slotButton = Button:New { parent = screen0, x = 216, y = 8, width = 200, height = 36, caption = "Play together", objectOverrideFont = font, classname = "action_button",
			OnClick = { function()
				if ui.slotWindow.visible then ui.slotWindow:Hide() else fillSlotList(); ui.slotSig = slotSignature(); ui.slotWindow:Show(); ui.slotWindow:BringToFront() end
			end } }
		log("Play together button added")
	end
	if ui.slotButton.visible ~= show then ui.slotButton:SetVisibility(show) end
	if not show and ui.slotWindow and ui.slotWindow.visible then ui.slotWindow:Hide() end
	-- a player came or left, changed his team: the list follows (only when the window is open)
	if show and ui.slotWindow and ui.slotWindow.visible and os.clock() > (ui.slotNext or 0) then
		ui.slotNext = os.clock() + 1
		local sig = slotSignature()
		if sig ~= ui.slotSig then ui.slotSig = sig; fillSlotList() end
	end
end

---------------------------------------------------------------- per frame
function widget:Update()
	ensureScenarioUi()
	ensureSlotUi()
	if cfg.scenario and S and lan and lan.step == "in" and not cfg.scenarioPicked and os.clock() > 14 then
		cfg.scenarioPicked = true
		log("test: choosing the scenario", cfg.scenario)
		selectScenario(cfg.scenario)
	end
	if lan and lan.left and os.clock() > lan.left + 0.3 then
		log("left the battle room: back to the LAN Play page")
		lanStop("left the room")
		openLanPage()
		setStatus("You left the LAN game.")
	end
	if returnAt and tabAdded and os.clock() > returnAt then returnAt = nil; log("back from the game: the LAN Play page"); openLanPage() end
	if not ui.panel and not uiTried and os.clock() > 3 then uiTried = buildUi() or false end
	ensureTab()
	autoScan()
	if S then updateServer() end
	updateLan()
	updateScan()

	-- test automation
	if cfg.openTab and tabAdded and not cfg.opened and os.clock() > tabAdded + 2 then
		cfg.opened = true
		local root = WG.Chobby and WG.Chobby.interfaceRoot
		log("test: opening the LAN Play page:", tostring(pcall(root.OpenSingleplayerTabByName, "LAN Play")))
	end
	if cfg.scenarioTest and not cfg.scenDone and os.clock() > 12 then
		cfg.scenDone = true
		local dirs = VFS.SubDirs("LevelEditorScenarios/", "*", VFS.RAW) or {}
		log("test: scenario folders seen through the junction:", #dirs, table.concat(dirs, " "))
		local txt = VFS.LoadFile("LevelEditorScenarios/" .. cfg.scenarioTest .. "/scenario.txt", VFS.RAW)
		log("test: scenario.txt read:", txt and #txt or "FAILED", "bytes; game archive 'Tower Defense Scenario 1' present:", tostring(VFS.HasArchive("Tower Defense Scenario 1")))
		if txt then
			local script = txt:gsub("__GAMETYPE__", cfg.scenarioGame or "Tower Defense Scenario 1"):gsub("__PLAYERNAME__", cfg.name or "Hanna")
			log("test: starting the scenario with Spring.Reload")
			Spring.Reload(script)
		end
	end
	if cfg.leaveAfter and lan and lan.step == "in" then
		lan.inAt = lan.inAt or os.clock()
		if os.clock() > lan.inAt + tonumber(cfg.leaveAfter) and not lan.leaveSent then lan.leaveSent = true; log("test: pressing Leave in the room (lobby:LeaveBattle)"); WG.BattleRoomWindow.LeaveBattle() end
	end
	if cfg.clickFirst and not lan and not S and #found > 0 then log("test: click on the first entry"); joinHost(found[1].ip) end
	local l = lobby()
	if cfg.auto and not autoStarted and os.clock() > 8 and Config() and l then
		autoStarted = true
		log("auto:", cfg.auto)
		if cfg.auto == "host" then startHosting()
		elseif cfg.auto == "join" then
			if cfg.ip and cfg.ip ~= "" then joinHost(cfg.ip) else startScan() end
		end
	end
	if cfg.auto == "join" and autoStarted and not lan and not scan and #found > 0 then joinHost(found[1].ip) end
	if cfg.auto == "host" and lan and lan.step == "in" and S and not S.battle.running then
		if #battleUsers() >= (tonumber(cfg.players) or 2) then
			S.autoAt = S.autoAt or (os.clock() + 4)
			if os.clock() > S.autoAt then
				if cfg.map and S.battle.map ~= cfg.map then l:SelectMap(cfg.map) end
				log("auto: pressing Start (lobby:StartBattle, the call of the Start button)")
				l:StartBattle()
			end
		end
	end
	if cfg.auto and lan and lan.step == "in" and not lan.chatted then
		lan.chatted = true
		l:SayBattle("hello from " .. lan.name)
	end
end

---------------------------------------------------------------- the main menu entry
buildUi = function()
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)
	local cf = Config()
	if not (WG.Chili and cf and cf.gameConfig and cf.gameConfig.singleplayerConfig and screen0) then return false end
	local font = cf:GetFont(2)
	local P = Control:New { name = "LAN Play", x = 0, y = 0, width = "100%", height = "100%", resizable = false, padding = { 10, 10, 10, 10 } }
	local y = 0
	TextBox:New { parent = P, x = 0, y = y + 4, right = 0, height = 30, text = "LAN Play - play with computers in the same network (no server needed)", objectOverrideFont = font }
	y = y + 44
	TextBox:New { parent = P, x = 0, y = y + 8, width = 130, height = 30, text = "Your name", objectOverrideFont = font }
	ui.name = EditBox:New { parent = P, x = 140, y = y + 2, width = 260, height = 36, text = savedName() or defaultName(), objectOverrideFont = font }
	TextBox:New { parent = P, x = 416, y = y + 8, right = 0, height = 30, text = "(your account name; change it if you like)", objectOverrideFont = font }
	y = y + 48
	Button:New { parent = P, x = 0, y = y, width = 260, height = 44, caption = "Host a LAN game", objectOverrideFont = font, classname = "action_button", OnClick = { function() startHosting() end } }
	TextBox:New { parent = P, x = 276, y = y + 8, right = 0, height = 30, text = "you get the multiplayer battle room: map, options, chat", objectOverrideFont = font }
	y = y + 60
	Button:New { parent = P, x = 0, y = y, width = 260, height = 44, caption = "Find LAN games", objectOverrideFont = font, OnClick = { function() startScan() end } }
	ui.ip = EditBox:New { parent = P, x = 276, y = y + 4, width = 200, height = 36, text = cfg.ip or "", hint = "or an address", objectOverrideFont = font }
	Button:New { parent = P, x = 486, y = y, width = 120, height = 44, caption = "Join", objectOverrideFont = font, OnClick = { function() joinHost(ui.ip.text) end } }
	y = y + 56
	ui.found = {}
	for i = 1, 6 do
		local idx = i
		local b = Button:New { parent = P, x = 0, y = y + (i - 1) * 46, width = 606, height = 40, caption = "", objectOverrideFont = font,
			OnClick = { function() if found[idx] then joinHost(found[idx].ip) end end } }
		b:Hide()
		ui.found[i] = b
	end
	y = y + 6 * 46 + 10
	ui.status = TextBox:New { parent = P, x = 0, y = y, right = 0, height = 30, text = status, objectOverrideFont = font }
	Button:New { parent = P, x = 0, y = y + 40, width = 260, height = 40, caption = "Leave LAN play", objectOverrideFont = font, OnClick = { function() lanStop("left"); setStatus("Back on the normal server.") end } }
	Button:New { parent = P, x = 276, y = y + 40, width = 180, height = 40, caption = "Back", objectOverrideFont = font, OnClick = { function()
		local root = WG.Chobby and WG.Chobby.interfaceRoot
		local sub = root and root.GetSingleplayerSubmenu and root.GetSingleplayerSubmenu()
		if sub and sub.CloseTabs then pcall(sub.CloseTabs) end
	end } }
	ui.panel = P
	log("panel built; player name on the page:", tostring(ui.name and ui.name.text), "(account name:", tostring(cf.userName) .. ")")
	return true
end

-- for the test of the Level Editor: the file is loaded in a stub environment (no lobby), a fake server is put in and the start script is built from it
widget.DebugShare = {
	setServer = function(server) S = server end,
	buildScript = function(name) return buildScript(name) end,
	cycle = function(name) return cycleSlot(name) end,
	list = function() local h = humanList(); local e = effectiveSlots(h); local out = {}; for _, x in ipairs(h) do out[x.name] = e[x.name] end; return out end,
}

function widget:Initialize()
	math.randomseed(os.time() + math.floor(os.clock() * 1000))
	log("loaded; socket:", type(socket))
	if VFS.LoadFile("lan_return.txt", VFS.RAW) then
		os.remove("lan_return.txt")
		returnAt = os.clock() + 4
	end
	if Config() and not ui.panel then uiTried = buildUi() or false end
	hookConnect()
end

function widget:Shutdown()
	if lan and lan.step == "in" then
		local f = io.open("lan_return.txt", "w")
		if f then f:write("back to the LAN Play page after the game"); f:close() end
	end
	lanStop("shutdown", true)
end
