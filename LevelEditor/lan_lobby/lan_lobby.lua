function widget:GetInfo()
	return {
		name      = "LAN Lobby",
		desc      = "Host or join a game in the local network from the official lobby (no server needed)",
		author    = "Level Editor",
		date      = "2026-10-23",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true,
	}
end

-- Prototype. Everything goes over TCP (the lobby may listen and connect, but may not send UDP unless springsettings.cfg says so).
--   lobby port 18460:  client -> host  WHO              host answers  LANHOST <host name>|<map>|<number of players>   and closes
--                      client -> host  HELLO <name>     host answers  OK <map>|<game>   and  ROSTER a,b,c  (to everybody, whenever it changes)
--                      host -> clients START <game port> <password>   (then everybody starts the engine with a start script)
--   Finding hosts: the addresses x.y.z.1 .. x.y.z.254 of the own network are asked on the lobby port (WHO); or type the address.
-- Test automation: lanlobby_cfg.txt in the write dir (key=value lines): auto=host|join, name=, map=, game=, players=, ip=

local PORT, GAMEPORT = 18460, 8452
local DEFAULT_GAME = "Beyond All Reason test-31691-a617033"
local DEFAULT_MAP = "Hooked 1.1"

local cfg = {}
for line in string.gmatch(VFS.LoadFile("lanlobby_cfg.txt", VFS.RAW) or "", "[^\r\n]+") do
	local k, v = line:match("^%s*(%w+)%s*=%s*(.-)%s*$")
	if k then cfg[k] = v end
end

local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	local s = table.concat(t, " ")
	Spring.Echo("[LANLOBBY] " .. s)
	local f = io.open("lan_status.txt", "a")
	if f then f:write(os.date("%H:%M:%S ") .. s .. "\n"); f:close() end
end

local state = { mode = nil, name = cfg.name or ("Player" .. math.random(100, 999)), map = cfg.map or DEFAULT_MAP, game = cfg.game or DEFAULT_GAME }
local srv, clients, link, scan = nil, {}, nil, nil
local startAt, startScript, found = nil, nil, {}
local ui = {}
local buildUi
local status = ""
local autoStarted, autoWaitUntil, launched, uiTried

local function setStatus(s) status = s; log("status:", s); if ui.status then ui.status:SetText(s) end end

---------------------------------------------------------------- network helpers
local function readLines(c)
	-- c = { sock, buf }; returns a list of complete lines and whether the connection is closed
	local data, err, partial = c.sock:receive(4096)
	data = data or partial
	if data and #data > 0 then c.buf = c.buf .. data end
	local lines = {}
	while true do
		local i = c.buf:find("\n", 1, true)
		if not i then break end
		lines[#lines + 1] = c.buf:sub(1, i - 1):gsub("\r$", "")
		c.buf = c.buf:sub(i + 1)
	end
	return lines, (err == "closed")
end

local function send(c, text) if c.sock then c.sock:send(text .. "\n") end end

local function roster()
	local names = { state.name }
	for _, c in ipairs(clients) do if c.name then names[#names + 1] = c.name end end
	return names
end

local function showRoster(names)
	if ui.roster then ui.roster:SetText("Players: " .. table.concat(names, ", ")) end
end

local function broadcastRoster()
	local names = roster()
	for _, c in ipairs(clients) do if c.name then send(c, "ROSTER " .. table.concat(names, ",")) end end
	showRoster(names)
	log("roster:", table.concat(names, ","))
end

---------------------------------------------------------------- start scripts
local function hostScript(names, password)
	local n = #names
	local t = { "[GAME]\n{\n",
		"\tGameType=", state.game, ";\n\tMapName=", state.map, ";\n",
		"\tHostIP=0.0.0.0;\n\tHostPort=", GAMEPORT, ";\n\tIsHost=1;\n\tMyPlayerName=", names[1], ";\n",
		"\tNumPlayers=", n, ";\n\tNumUsers=", n, ";\n\tStartPosType=2;\n\tNoHelperAIs=0;\n\tGameStartDelay=3;\n" }
	for i, name in ipairs(names) do
		t[#t + 1] = string.format("\t[PLAYER%d]\n\t{\n\t\tName=%s;\n\t\tTeam=%d;\n\t\trank=0;\n%s\t}\n", i - 1, name, i - 1, (i > 1) and ("\t\tPassword=" .. password .. ";\n") or "")
	end
	for i = 1, n do
		t[#t + 1] = string.format("\t[TEAM%d]\n\t{\n\t\tTeamLeader=%d;\n\t\tAllyTeam=%d;\n\t\tRgbColor=%s;\n\t\tSide=%s;\n\t\tHandicap=0;\n\t}\n",
			i - 1, i - 1, i - 1, (i == 1) and "0.2 0.4 1.0" or "1.0 0.3 0.2", (i == 1) and "Armada" or "Cortex")
		t[#t + 1] = string.format("\t[ALLYTEAM%d]\n\t{\n\t\tNumAllies=0;\n\t}\n", i - 1)
	end
	t[#t + 1] = "}\n"
	return table.concat(t)
end

local function clientScript(ip, port, name, password)
	return string.format("[GAME]\n{\n\tHostIP=%s;\n\tHostPort=%s;\n\tSourcePort=0;\n\tIsHost=0;\n\tMyPlayerName=%s;\n\tMyPasswd=%s;\n\tShowServerName=LAN;\n}\n", ip, port, name, password)
end

local function checkArchives()
	if not VFS.HasArchive(state.game) then return "missing game '" .. state.game .. "'" end
	if not VFS.HasArchive(state.map) then return "missing map '" .. state.map .. "'" end
end

---------------------------------------------------------------- host
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
	local err = checkArchives(); if err then setStatus("Cannot host: " .. err); return end
	local s, e = socket.bind("*", PORT)
	if not s then setStatus("Cannot listen on port " .. PORT .. ": " .. tostring(e)); return end
	s:settimeout(0)
	srv = s; state.mode = "host"
	setStatus("Hosting '" .. state.map .. "' as " .. state.name .. " on port " .. PORT .. ". Waiting for players.")
	showRoster(roster())
end

local function startGame()
	if state.mode ~= "host" or startAt or launched then return end
	local names = roster()
	if #names < 2 then setStatus("Need at least 2 players."); return end
	local pw = tostring(math.random(100000, 999999))
	for _, c in ipairs(clients) do if c.name then send(c, "START " .. GAMEPORT .. " " .. pw) end end
	startScript = hostScript(names, pw)
	startAt = os.clock() + 1.0
	setStatus("Starting the game with " .. #names .. " players ...")
end

---------------------------------------------------------------- client
local function joinHost(ip)
	stopAll()
	local err = checkArchives(); if err then setStatus("Cannot join: " .. err); return end
	local s = socket.tcp(); s:settimeout(3)
	local ok, e = s:connect(ip, PORT)
	if not ok then s:close(); setStatus("No connection to " .. ip .. ": " .. tostring(e)); return end
	s:settimeout(0)
	link = { sock = s, buf = "", ip = ip }
	state.mode = "client"
	send(link, "HELLO " .. state.name)
	setStatus("Connected to " .. ip .. ". Waiting for the host to start.")
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
		if f then b:SetCaption(f.ip .. "  " .. f.name .. "  [" .. f.map .. "]  " .. f.players .. " player(s)"); b:Show() else b:Hide() end
	end
end

local function updateScan()
	if not scan then return end
	-- open a few connections per frame (a refused or unreachable address just times out)
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
				local n, e = o.sock:send("WHO\n")
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
	if scan.next > #scan.list and #scan.open == 0 or os.clock() > scan.until_ then
		for _, o in ipairs(scan.open) do o.sock:close() end
		log("scan finished:", #found, "game(s) in", string.format("%.1f", os.clock() - scan.started), "s")
		setStatus(#found > 0 and ("Found " .. #found .. " game(s).") or "No game found.")
		scan = nil; state.mode = nil
	end
end

---------------------------------------------------------------- per frame
local function updateHost()
	local new = srv:accept()
	while new do
		new:settimeout(0)
		clients[#clients + 1] = { sock = new, buf = "", ip = (new:getpeername()), t = os.clock() }
		new = srv:accept()
	end
	local changed = false
	for i = #clients, 1, -1 do
		local c = clients[i]
		local lines, closed = readLines(c)
		for _, l in ipairs(lines) do
			if l == "WHO" then
				send(c, "LANHOST " .. state.name .. "|" .. state.map .. "|" .. #roster()); closed = true
			elseif l:sub(1, 6) == "HELLO " and not c.name then
				local nm = l:sub(7):gsub("[^%w_%-%[%]]", ""):sub(1, 20)
				local taken = (nm == "" or nm == state.name)
				for _, o in ipairs(clients) do if o.name == nm then taken = true end end
				if taken then send(c, "NO name taken or invalid"); closed = true
				else c.name = nm; send(c, "OK " .. state.map .. "|" .. state.game); changed = true end
			end
		end
		if closed or (not c.name and os.clock() - c.t > 5) then
			c.sock:close(); table.remove(clients, i); changed = changed or c.name ~= nil
		end
	end
	if changed then broadcastRoster() end
end

local function updateClient()
	local lines, closed = readLines(link)
	for _, l in ipairs(lines) do
		if l:sub(1, 7) == "ROSTER " then showRoster({ l:sub(8) }); log("roster:", l:sub(8))
		elseif l:sub(1, 6) == "START " then
			local port, pw = l:match("^START (%d+) (%S+)$")
			if port then
				startScript = clientScript(link.ip, port, state.name, pw)
				startAt = os.clock() + 4.0 -- the host's engine must be listening first
				setStatus("The host starts the game ...")
			end
		elseif l:sub(1, 3) == "NO " then setStatus("The host refused: " .. l:sub(4)) end
	end
	if closed and not startAt then setStatus("The host closed the connection."); link.sock:close(); link = nil; state.mode = nil end
end

function widget:Update()
	if not ui.window and not uiTried then if os.clock() > 3 then uiTried = buildUi() end end
	if startAt and os.clock() >= startAt then
		local s = startScript; startAt, startScript = nil, nil; launched = true
		log("Spring.Reload with start script:\n" .. s)
		Spring.Reload(s)
		return
	end
	if state.mode == "host" and srv then updateHost()
	elseif state.mode == "client" and link then updateClient()
	elseif state.mode == "scan" then updateScan() end

	-- test automation
	if cfg.auto and not autoStarted and not launched and os.clock() > 5 then
		autoStarted = true
		log("auto:", cfg.auto)
		if cfg.auto == "host" then startHosting()
		elseif cfg.auto == "join" then
			if cfg.ip and cfg.ip ~= "" then joinHost(cfg.ip) else startScan() end
		end
	end
	if cfg.auto == "host" and state.mode == "host" and not startAt and not launched and #roster() >= (tonumber(cfg.players) or 2) then
		autoWaitUntil = autoWaitUntil or (os.clock() + 3)
		if os.clock() > autoWaitUntil then startGame() end
	end
	if cfg.auto == "join" and state.mode == nil and #found > 0 and not link and not startAt and not launched then joinHost(found[1].ip) end
end

---------------------------------------------------------------- window
local function buildWindow()
	local font = WG.Chobby.Configuration:GetFont(2)
	local W = Window:New { parent = screen0, x = 8, y = 44, width = 520, height = 470, resizable = false, draggable = true, classname = "main_window" }
	local function label(y, text) return TextBox:New { parent = W, x = 12, y = y + 6, width = 90, height = 24, text = text, objectOverrideFont = font } end
	label(8, "Name"); label(46, "Map")
	ui.name = EditBox:New { parent = W, x = 100, y = 8, right = 12, height = 32, text = state.name, objectOverrideFont = font }
	ui.map = EditBox:New { parent = W, x = 100, y = 46, right = 12, height = 32, text = state.map, objectOverrideFont = font }
	local function readFields() state.name = (ui.name.text or ""):gsub("[^%w_%-%[%]]", ""):sub(1, 20); if state.name == "" then state.name = "Player" end; state.map = ui.map.text or state.map end
	Button:New { parent = W, x = 12, y = 88, width = 150, height = 38, caption = "Host LAN game", objectOverrideFont = font, classname = "action_button", OnClick = { function() readFields(); startHosting() end } }
	Button:New { parent = W, x = 172, y = 88, width = 150, height = 38, caption = "Find games", objectOverrideFont = font, OnClick = { function() readFields(); startScan() end } }
	Button:New { parent = W, x = 332, y = 88, width = 160, height = 38, caption = "Start the game", objectOverrideFont = font, classname = "action_button", OnClick = { function() startGame() end } }
	label(134, "Address")
	ui.ip = EditBox:New { parent = W, x = 100, y = 134, width = 220, height = 32, text = cfg.ip or "", objectOverrideFont = font }
	Button:New { parent = W, x = 332, y = 132, width = 160, height = 36, caption = "Join", objectOverrideFont = font, OnClick = { function() readFields(); joinHost(ui.ip.text) end } }
	ui.found = {}
	for i = 1, 6 do
		local idx = i
		local b = Button:New { parent = W, x = 12, y = 178 + (i - 1) * 40, right = 12, height = 36, caption = "", objectOverrideFont = font, OnClick = { function() if found[idx] then readFields(); joinHost(found[idx].ip) end end } }
		b:Hide()
		ui.found[i] = b
	end
	ui.roster = TextBox:New { parent = W, x = 12, y = 424, right = 12, height = 24, text = "", objectOverrideFont = font }
	ui.status = TextBox:New { parent = W, x = 12, y = 400, right = 12, height = 24, text = status, objectOverrideFont = font }
	ui.window = W
	return W
end

function widget:Initialize()
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)
	math.randomseed(os.time() + math.floor(os.clock() * 1000))
	log("loaded; socket:", type(socket), "game:", state.game, "map:", state.map)
end

buildUi = function()
	VFS.Include(LUA_DIRNAME .. "widgets/chobby/headers/exports.lua", nil, VFS.RAW_FIRST)
	if not (WG.Chili and WG.Chobby and WG.Chobby.Configuration and screen0) then return false end
	buildWindow()
	ui.window:Hide()
	ui.toggle = Button:New { parent = screen0, x = 8, y = 6, width = 90, height = 34, caption = "LAN", objectOverrideFont = WG.Chobby.Configuration:GetFont(2),
		OnClick = { function() if ui.window.visible then ui.window:Hide() else ui.window:Show(); ui.window:BringToFront() end end } }
	log("window built")
	return true
end

function widget:Shutdown()
	stopAll()
	if ui.window then ui.window:Dispose() end
	if ui.toggle then ui.toggle:Dispose() end
end
