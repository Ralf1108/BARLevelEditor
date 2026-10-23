function widget:GetInfo()
	return {
		name      = "LAN Play",
		desc      = "Host or join a game in the local network from the official lobby (no server needed)",
		author    = "Level Editor",
		date      = "2026-10-23",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

-- Prototype 2: a main menu entry "LAN Play" (next to Multiplayer / Skirmish). Everything goes over TCP (the lobby may listen and connect, but may not send UDP).
--   The host sets the game up in the OFFICIAL battle room (the Skirmish room: map, options, AIs, colours). Its Start button is redirected here: the remote
--   players are added as "friends" (the mechanism of the Steam coop: they play in the host's team) and the engine listens on the network (HostIP 0.0.0.0).
--   lobby port 8453:   WHO              -> LANHOST <host name>|<map>|<players>     (discovery, then the host closes)
--                      HELLO <name>     -> OK                                       and  ROSTER a,b,c  (to everybody, whenever it changes)
--                      START <game port> <password> <game>|<map>     (host -> clients; they download a missing map with the lobby's own downloader)
--   Finding hosts: the addresses x.y.z.1 .. x.y.z.254 of the own network are asked on the lobby port; or type the address.
-- Test automation: lanlobby_cfg.txt in the write dir (key=value lines): auto=host|join, name=, map=, players=, ip=

local PORT, GAMEPORT = 8453, 8452
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

local state = { mode = nil, name = cfg.name }
local srv, clients, link, scan = nil, {}, nil, nil
local startAt, startScript, found, launched = nil, nil, {}, false
local ui = {}
local buildUi, openRoom
local status = ""
local uiTried, autoStarted, autoWaitUntil, hooked, debugAt

local function Config() return WG.Chobby and WG.Chobby.Configuration end
local function myName() return state.name or (Config() and Config():GetPlayerName()) or "Player" end
local function setStatus(s) status = s; log("status:", s); if ui.status then ui.status:SetText(s) end end

---------------------------------------------------------------- network helpers
local function readLines(c)
	local data, err, partial = c.sock:receive(4096)
	data = data or partial
	if data and #data > 0 then c.buf = c.buf .. data end
	local lines = {}
	while true do
		local i = c.buf:find("\n", 1, true)
		if not i then break end
		lines[#lines + 1] = (c.buf:sub(1, i - 1):gsub("\r$", ""))
		c.buf = c.buf:sub(i + 1)
	end
	return lines, (err == "closed")
end

local function send(c, text) if c.sock then c.sock:send(text .. "\n") end end

local function roster()
	local names = { myName() }
	for _, c in ipairs(clients) do if c.name then names[#names + 1] = c.name end end
	return names
end

local function showRoster(text) if ui.roster then ui.roster:SetText("Players: " .. text) end end

local function broadcastRoster()
	local names = roster()
	for _, c in ipairs(clients) do if c.name then send(c, "ROSTER " .. table.concat(names, ",")) end end
	showRoster(table.concat(names, ", "))
	log("roster:", table.concat(names, ","))
end

---------------------------------------------------------------- the official battle room (Skirmish) as the setup screen of the host
local function battleInfo()
	local ll = WG.LibLobby and WG.LibLobby.localLobby
	local battle = ll and ll:GetBattle(ll:GetMyBattleID())
	return battle and battle.gameName, battle and battle.mapName
end

local function checkArchives(game, map)
	if game and not VFS.HasArchive(game) then return "missing game '" .. tostring(game) .. "'" end
	if map and not VFS.HasArchive(map) then return "missing map '" .. tostring(map) .. "'" end
end

-- hooks the Start button of the Skirmish room: while this computer hosts a LAN game, starting it means "LAN host start"
local function hookStart()
	if hooked then return end
	local ll = WG.LibLobby and WG.LibLobby.localLobby
	if not ll then return false end
	local original = ll.StartBattle
	ll.StartBattle = function(self, gameType, myNameArg, friendList, friendsReplaceAI, hostPort)
		if state.mode ~= "host" or launched then return original(self, gameType, myNameArg, friendList, friendsReplaceAI, hostPort) end
		local names = {}
		for _, c in ipairs(clients) do if c.name then names[#names + 1] = c.name end end
		local game, map = battleInfo()
		local pw = "12345" -- the password the lobby gives its coop friends
		launched = true
		for _, c in ipairs(clients) do if c.name then send(c, "START " .. GAMEPORT .. " " .. pw .. " " .. tostring(game) .. "|" .. tostring(map)) end end
		setStatus("Starting the game with " .. (#names + 1) .. " player(s) ...")
		-- the lobby's script has HostIP=127.0.0.1 (for Steam); for the network the engine has to listen on all addresses
		local reload = Spring.Reload
		Spring.Reload = function(script)
			Spring.Reload = reload
			script = script:gsub("hostip = 127%.0%.0%.1;", "hostip = 0.0.0.0;")
			log("Spring.Reload (host) with start script:\n" .. script)
			return reload(script)
		end
		return original(self, gameType, myNameArg or myName(), names, friendsReplaceAI, GAMEPORT)
	end
	hooked = true
	log("Start button of the Skirmish room is redirected")
	return true
end

---------------------------------------------------------------- connection handling
local function stopAll()
	if srv then srv:close(); srv = nil end
	for _, c in ipairs(clients) do c.sock:close() end
	clients = {}
	if link then link.sock:close(); link = nil end
	scan = nil
	state.mode = nil
end

local function startHosting()
	stopAll()
	local s, e = socket.bind("*", PORT)
	if not s then setStatus("Cannot listen on port " .. PORT .. ": " .. tostring(e)); return end
	s:settimeout(0)
	srv = s; state.mode = "host"; launched = false
	hookStart()
	setStatus("Hosting as " .. myName() .. " (port " .. PORT .. "). Set up the game in the Skirmish room and press Start.")
	showRoster(myName())
	if openRoom then openRoom() end
end

local function joinHost(ip)
	stopAll()
	local s = socket.tcp(); s:settimeout(3)
	local ok, e = s:connect(ip, PORT)
	if not ok then s:close(); setStatus("No connection to " .. ip .. ": " .. tostring(e)); return end
	s:settimeout(0)
	link = { sock = s, buf = "", ip = ip }
	state.mode = "client"; launched = false
	send(link, "HELLO " .. myName())
	setStatus("Connected to " .. ip .. " as " .. myName() .. ". Waiting for the host to start.")
end

local function startScan()
	stopAll()
	found = {}
	local me = (socket.dns and socket.dns.toip and socket.dns.toip(socket.dns.gethostname())) or "127.0.0.1"
	local a, b, c = tostring(me):match("^(%d+)%.(%d+)%.(%d+)%.%d+$")
	local list = { "127.0.0.1" }
	if a then for i = 1, 254 do list[#list + 1] = a .. "." .. b .. "." .. c .. "." .. i end end
	scan = { list = list, next = 1, open = {}, until_ = os.clock() + 8, started = os.clock() }
	state.mode = "scan"
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
			local lines, closed = readLines(o)
			for _, l in ipairs(lines) do
				local name, map, players = l:match("^LANHOST (.-)|(.-)|(%d+)$")
				if name then found[#found + 1] = { ip = o.ip, name = name, map = map, players = players }; log("found", o.ip, name, map, players); updateFoundUi() end
			end
			if closed or os.clock() - o.t > 3 then drop = true end
		end
		if drop then o.sock:close(); table.remove(scan.open, i) end
	end
	if (scan.next > #scan.list and #scan.open == 0) or os.clock() > scan.until_ then
		for _, o in ipairs(scan.open) do o.sock:close() end
		log("scan finished:", #found, "game(s) in", string.format("%.1f", os.clock() - scan.started), "s")
		setStatus(#found > 0 and ("Found " .. #found .. " game(s).") or "No game found.")
		scan = nil; state.mode = nil
	end
end

local function updateHost()
	local new = srv:accept()
	while new do
		new:settimeout(0)
		clients[#clients + 1] = { sock = new, buf = "", t = os.clock() }
		new = srv:accept()
	end
	local changed = false
	for i = #clients, 1, -1 do
		local c = clients[i]
		local lines, closed = readLines(c)
		for _, l in ipairs(lines) do
			if l == "WHO" then
				local _, map = battleInfo()
				send(c, "LANHOST " .. myName() .. "|" .. tostring(map or "?") .. "|" .. #roster()); closed = true
			elseif l:sub(1, 6) == "HELLO " and not c.name and not launched then
				local nm = l:sub(7):gsub("[^%w_%-%[%]]", ""):sub(1, 20)
				local taken = (nm == "" or nm == myName())
				for _, o in ipairs(clients) do if o.name == nm then taken = true end end
				if taken then send(c, "NO name taken or invalid"); closed = true
				else c.name = nm; send(c, "OK"); changed = true end
			end
		end
		if closed or (not c.name and os.clock() - c.t > 5) then
			c.sock:close(); table.remove(clients, i); changed = changed or c.name ~= nil
		end
	end
	if changed then broadcastRoster() end
end

local function prepareClientStart(ip, port, pw, game, map)
	local err = checkArchives(game, nil)
	if err then setStatus("Cannot start: " .. err); return end
	local function go()
		startScript = string.format("[GAME]\n{\n\tHostIP=%s;\n\tHostPort=%s;\n\tSourcePort=0;\n\tIsHost=0;\n\tMyPlayerName=%s;\n\tMyPasswd=%s;\n\tShowServerName=LAN;\n}\n", ip, port, myName(), pw)
		startAt = os.clock() + 4.0 -- the host's engine must be listening first
		setStatus("The host starts the game ...")
	end
	if map and map ~= "" and not VFS.HasArchive(map) then
		-- the map is downloaded with the lobby's own downloader (the Downloads tab shows it); the game starts when it is there
		setStatus("Downloading the map '" .. map .. "' ...")
		if WG.DownloadHandler and WG.DownloadHandler.QueueDownload then WG.DownloadHandler.QueueDownload(map, "map") end
		link.waitMap = { map = map, go = go, deadline = os.clock() + 600 }
	else
		go()
	end
end

local function updateClient()
	local lines, closed = readLines(link)
	for _, l in ipairs(lines) do
		if l:sub(1, 7) == "ROSTER " then showRoster(l:sub(8)); log("roster:", l:sub(8))
		elseif l:sub(1, 6) == "START " then
			local port, pw, game, map = l:match("^START (%d+) (%S+) (.-)|(.*)$")
			if port then prepareClientStart(link.ip, port, pw, game, map) end
		elseif l:sub(1, 3) == "NO " then setStatus("The host refused: " .. l:sub(4)) end
	end
	if link and link.waitMap then
		local w = link.waitMap
		if VFS.HasArchive(w.map) then link.waitMap = nil; w.go()
		elseif os.clock() > w.deadline then link.waitMap = nil; setStatus("The map '" .. w.map .. "' did not arrive.") end
	end
	if closed and not startAt and not (link and link.waitMap) then
		setStatus("The host closed the connection."); link.sock:close(); link = nil; state.mode = nil
	end
end

function widget:Update()
	if debugAt and os.clock() > debugAt then debugAt = nil; local g, m = battleInfo(); log('battle 3 s later: game', g, 'map', m) end
	if not ui.panel and not uiTried and os.clock() > 3 then uiTried = buildUi() or false end
	if startAt and os.clock() >= startAt then
		local s = startScript; startAt, startScript = nil, nil; launched = true
		log("Spring.Reload (client) with start script:\n" .. s)
		Spring.Reload(s)
		return
	end
	if state.mode == "host" and srv then updateHost()
	elseif state.mode == "client" and link then updateClient()
	elseif state.mode == "scan" then updateScan() end

	-- test automation
	if cfg.shot and not cfg.shotDone and os.clock() > (tonumber(cfg.shot) or 30) then
		cfg.shotDone = true
		if cfg.shotTab then local root = WG.Chobby and WG.Chobby.GetInterfaceRoot and WG.Chobby.GetInterfaceRoot(); if root then root.OpenSingleplayerTabByName(cfg.shotTab) end end
		log('screenshot:', tostring(pcall(Spring.SendCommands, 'screenshot png')))
		cfg.shotDone = os.clock()
	end
	if cfg.auto and not autoStarted and not launched and os.clock() > 8 and Config() then
		autoStarted = true
		log("auto:", cfg.auto)
		if cfg.auto == "host" then
			startHosting()
			-- what the player does in the Skirmish room: choose a map
			local ll = WG.LibLobby.localLobby
			if cfg.map and cfg.map ~= "" and ll then pcall(function() ll:SelectMap(cfg.map) end) end
		elseif cfg.auto == "join" then
			if cfg.ip and cfg.ip ~= "" then joinHost(cfg.ip) else startScan() end
		end
	end
	if cfg.auto == "host" and state.mode == "host" and not launched then
		local n = #roster()
		if n >= (tonumber(cfg.players) or 2) then
			autoWaitUntil = autoWaitUntil or (os.clock() + 3)
			if os.clock() > autoWaitUntil then
				log("auto: pressing Start (localLobby:StartBattle, the call of the Start button)")
				local ll = WG.LibLobby.localLobby
				ll:StartBattle("skirmish")
			end
		end
	end
	if cfg.auto == "join" and state.mode == nil and #found > 0 and not link and not startAt and not launched then joinHost(found[1].ip) end
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
	TextBox:New { parent = P, x = 276, y = y + 8, right = 0, height = 30, text = "then set up the game in the Skirmish room and press Start", objectOverrideFont = font }
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
	ui.roster = TextBox:New { parent = P, x = 0, y = y + 34, right = 0, height = 30, text = "", objectOverrideFont = font }
	ui.panel = P

	-- the entry in the main menu: before the lobby builds its menu (it reads this list once)
	table.insert(cf.gameConfig.singleplayerConfig, 1, { name = "LAN Play", control = P })
	log("menu entry added; singleplayer entries:", #cf.gameConfig.singleplayerConfig)
	return true
end

openRoom = function()
	local root = WG.Chobby and WG.Chobby.GetInterfaceRoot and WG.Chobby.GetInterfaceRoot()
	log("open the Skirmish room: interface root", type(root), root and type(root.OpenSingleplayerTabByName))
	if root and root.OpenSingleplayerTabByName then
		-- the same as a click on the Skirmish tab: its entry check chooses the game first, then the tab (and the room) is shown
		local function show() local ok, err = pcall(root.OpenSingleplayerTabByName, "skirmish"); log("OpenSingleplayerTabByName:", ok, err) end
		if WG.BattleRoomWindow and WG.BattleRoomWindow.SetSingleplayerGame then WG.BattleRoomWindow.SetSingleplayerGame(show, nil, nil) else show() end
	end
	local g, m = battleInfo()
	log("battle now: game", g, "map", m)
	log("rapid name of byar:test:", tostring(VFS.GetNameFromRapidTag and VFS.GetNameFromRapidTag("byar:test")), "default game name:", tostring(Config() and Config():GetDefaultGameName()))
	debugAt = os.clock() + 3
end

function widget:Initialize()
	math.randomseed(os.time() + math.floor(os.clock() * 1000))
	log("loaded; socket:", type(socket))
	-- the menu list is read when the lobby builds its interface: add the entry as early as possible
	if Config() and not ui.panel then uiTried = buildUi() or false end
end

function widget:Shutdown()
	stopAll()
end
