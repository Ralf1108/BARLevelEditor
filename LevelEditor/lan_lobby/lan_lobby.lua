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
local buildUi
local status = ""
local uiTried, autoStarted
local found, scan = {}, nil
local S = nil            -- the server (host only)
local lan = nil          -- { role = "host"|"client", saved = {address, port}, name, ip, step }
local hookedConnect

local function Config() return WG.Chobby and WG.Chobby.Configuration end
local function lobby() return WG.LibLobby and WG.LibLobby.lobby end
local function setStatus(s) status = s; log("status:", s); if ui.status then ui.status:SetText(s) end end
local function cleanName(n) return ((n or ""):gsub("[^%w_%-%[%]]", ""):sub(1, 20)) end

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

local function startGameNow()
	if S.battle.running then return end
	S.battle.running = true
	log("the autohost starts the game")
	say("Starting the game ...")
	toAll("CLIENTSTATUS " .. HOSTNAME .. " 65") -- bot + in game: every lobby in the battle connects
end

local function autohostCommand(c, msg)
	local isHost = (c == S.hostConn)
	local cmd, rest = msg:match("^!(%S+)%s*(.*)$")
	cmd = (cmd or ""):lower()
	if not isHost then say("Only the host can use !" .. cmd); return end
	if cmd == "map" and rest ~= "" then
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
		for _, bot in ipairs(S.battle.bots) do sendLine(c, string.format("ADDBOT 1 %s %s %s %s %s", bot.name, bot.owner, bot.status, bot.color, bot.lib)) end
		sendLine(c, "REQUESTBATTLESTATUS")
		updateBattleInfo()
		log("joined the battle:", c.name)
	elseif cmd == "LEAVEBATTLE" then
		if c.inBattle then c.inBattle = false; toAll("LEFTBATTLE 1 " .. c.name); updateBattleInfo() end
	elseif cmd == "MYBATTLESTATUS" then
		local st, col = args:match("^(%S+)%s+(%S+)")
		if st and c.inBattle then c.battleStatus, c.teamColor = st, col; toBattle("CLIENTBATTLESTATUS " .. c.name .. " " .. st .. " " .. col); updateBattleInfo() end
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
		if err == "closed" or c.close or (not c.name and os.clock() - c.t > 6) then removeConn(c) end
	end
end

-- the start script of the game, built from the state of the room (what the autohost SPADS does on a normal server)
local function buildScript(myName)
	local l = lobby()
	local cf = Config()
	local players, teams, ais = {}, {}, {}
	local allyIndex = {}
	local function ally(a) if allyIndex[a] == nil then local n = 0; for _ in pairs(allyIndex) do n = n + 1 end; allyIndex[a] = n end; return allyIndex[a] end
	local pi = 0
	local function rgb(col) col = tonumber(col) or 0; return string.format("%.4f %.4f %.4f", (col % 256) / 255, (math.floor(col / 256) % 256) / 255, (math.floor(col / 65536) % 256) / 255) end
	local function sideName(s) local sd = cf and cf:GetSideById(s); return (sd and sd.name) or "Armada" end
	for _, c in ipairs(battleUsers()) do
		local bs = c.battleStatus and l:ParseBattleStatus(c.battleStatus) or { isSpectator = true }
		local p = { name = c.name, password = c.scriptPassword, spec = bs.isSpectator, index = pi }
		if not bs.isSpectator then
			p.team = #teams
			teams[#teams + 1] = { leader = pi, ally = ally(bs.allyNumber), color = rgb(c.teamColor), side = sideName(bs.side), handicap = bs.handicap or 0 }
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
		";\n\tIsHost=1;\n\tMyPlayerName=", myName, ";\n\tNumPlayers=", #players, ";\n\tNumUsers=", #players + #ais, ";\n\tStartPosType=2;\n\tNoHelperAIs=0;\n\tGameStartDelay=5;\n" }
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
		return original(self, ...)
	end
	hookedConnect = true
end

local function lanStop(reason)
	local l = lobby()
	if S then
		for _, c in ipairs(S.conns) do pcall(function() c.sock:close() end) end
		pcall(function() S.srv:close() end)
		S = nil
	end
	if lan and lan.saved then
		local cf = Config()
		if cf then cf.serverAddress, cf.serverPort = lan.saved.address, lan.saved.port end
		if l and l.Disconnect then pcall(function() l:Disconnect(reason or "LAN play ended") end) end
	end
	lan = nil
end

local function lanConnect(role, ip, name)
	local l, cf = lobby(), Config()
	if not (l and cf) then setStatus("The lobby is not ready."); return false end
	if lan then lanStop("new LAN game") end
	lan = { role = role, ip = ip, name = name, saved = { address = cf.serverAddress, port = cf.serverPort }, step = "connecting", t = os.clock() }
	pcall(function() l:Disconnect("LAN play") end)
	cf.serverAddress, cf.serverPort = ip, PORT
	-- the login window sends the login when the server has greeted (OnConnect): do the same here
	local function onConnect()
		l:RemoveListener("OnConnect", onConnect)
		log("server greeted; login as", name)
		l:Login(name, "lan", 3, nil, "Chobby")
	end
	l:AddListener("OnConnect", onConnect)
	l:Connect(ip, PORT, name, "lan", 0, "*", "Chobby")
	return true
end

local function startHosting()
	local cf = Config()
	if S or lan then lanStop("restart") end
	local s, e = socket.bind("*", PORT)
	if not s then setStatus("Cannot listen on port " .. PORT .. ": " .. tostring(e)); return end
	s:settimeout(0)
	local name = cleanName(cfg.name or (cf and cf:GetPlayerName()) or "Player")
	local game = cf and cf:GetDefaultGameName() or "Beyond All Reason"
	S = { srv = s, conns = {}, nextId = 100, battle = { map = (cfg.map and cfg.map ~= "" and cfg.map) or "Hooked 1.1", game = game, title = "LAN game of " .. name, modoptions = {}, bots = {} } }
	hookConnect()
	setStatus("Hosting as " .. name .. " (port " .. PORT .. ").")
	lanConnect("host", "127.0.0.1", name)
end

local function joinHost(ip)
	local cf = Config()
	if S then lanStop("join") end
	local name = cleanName(cfg.name or (cf and cf:GetPlayerName()) or "Player")
	setStatus("Connecting to " .. ip .. " as " .. name .. " ...")
	lanConnect("client", ip, name)
end

local function updateLan()
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
local function startScan()
	found = {}
	local me = (socket.dns and socket.dns.toip and socket.dns.toip(socket.dns.gethostname())) or "127.0.0.1"
	local a, b, c = tostring(me):match("^(%d+)%.(%d+)%.(%d+)%.%d+$")
	local list = { "127.0.0.1" }
	if a then for i = 1, 254 do list[#list + 1] = a .. "." .. b .. "." .. c .. "." .. i end end
	scan = { list = list, next = 1, open = {}, until_ = os.clock() + 8, started = os.clock() }
	log("scan from own address", me, "(", #list, "addresses )")
	setStatus("Searching for games in the network ...")
end

local function updateFoundUi()
	if not ui.found then return end
	for i, b in ipairs(ui.found) do
		local f = found[i]
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
				if name and not o.done then o.done = true; found[#found + 1] = { ip = o.ip, name = name, map = map, players = players }; log("found", o.ip, name, map, players); updateFoundUi() end
			end
			if err == "closed" or os.clock() - o.t > 3 then drop = true end
		end
		if drop then o.sock:close(); table.remove(scan.open, i) end
	end
	if (scan.next > #scan.list and #scan.open == 0) or os.clock() > scan.until_ then
		for _, o in ipairs(scan.open) do o.sock:close() end
		log("scan finished:", #found, "game(s) in", string.format("%.1f", os.clock() - scan.started), "s")
		setStatus(#found > 0 and ("Found " .. #found .. " game(s).") or "No game found.")
		scan = nil
	end
end

---------------------------------------------------------------- per frame
function widget:Update()
	if not ui.panel and not uiTried and os.clock() > 3 then uiTried = buildUi() or false end
	if S then updateServer() end
	updateLan()
	updateScan()

	-- test automation
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
	ui.panel = P
	table.insert(cf.gameConfig.singleplayerConfig, 1, { name = "LAN Play", control = P })
	log("menu entry added; singleplayer entries:", #cf.gameConfig.singleplayerConfig)
	return true
end

function widget:Initialize()
	math.randomseed(os.time() + math.floor(os.clock() * 1000))
	log("loaded; socket:", type(socket))
	if Config() and not ui.panel then uiTried = buildUi() or false end
end

function widget:Shutdown()
	lanStop("shutdown")
end
