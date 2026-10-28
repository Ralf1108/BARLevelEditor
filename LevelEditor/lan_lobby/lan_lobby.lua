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
-- Test automation: lanlobby_cfg.txt in the write dir (key=value lines): auto=host|join, startDelay= (seconds between the last player and the automatic Start, default 4), name=, map=, players=, ip=, noOnline=1 (a joiner cancels the lobby's online download of a missing map, as if there were no internet), showCopilot=1 (a joiner opens the list), copilot=<name> (gives that human the next number, like a click on the human in the Copilot list)

local PORT, GAMEPORT = 8453, 8452
-- Version of LAN Play (this widget and shared_start.lua): raise the number and set the date and time with every change of one of them (see CLAUDE.md);
-- the hashes below still tell a changed file whose number was not raised
local LAN_VERSION = { number = 4, stamp = "2026-10-28 09:11" }
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
local buildUi, updateFoundUi, scenarioList, forcedStatus, selectScenario, buildScript, ownGame, gameOfTag, fileTag, versionTag, mapBusyFn, runPendingFn, releaseHeld
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

-- a message window big enough for a longer text (the lobby's InformationPopup is a small box); falls back to it when the window cannot be built
local function bigPopup(msg)
	local ok = pcall(function()
		if ui.popup then pcall(function() ui.popup:Dispose() end) end
		local w, h = 640, 360
		local font = WG.Chobby.Configuration:GetFont(2)
		ui.popup = Window:New { parent = screen0, x = math.floor((screen0.width - w) / 2), y = math.floor((screen0.height - h) / 2), width = w, height = h,
			resizable = false, draggable = false, classname = "main_window" }
		TextBox:New { parent = ui.popup, x = 16, y = 16, right = 16, bottom = 70, text = msg, objectOverrideFont = font }
		Button:New { parent = ui.popup, x = "35%", right = "35%", bottom = 12, height = 40, caption = "OK", objectOverrideFont = font, classname = "action_button",
			OnClick = { function() ui.popup:Dispose(); ui.popup = nil end } }
	end)
	if not ok and WG.Chobby and WG.Chobby.InformationPopup then WG.Chobby.InformationPopup(msg) end
end
-- An address of this computer or of a local network: 127.x, the private networks 10.x, 172.16-31.x, 192.168.x, link-local 169.254.x and the usual
-- VPN ranges 100.64-127.x (Tailscale) and 25.x (Hamachi). The lobby in the game cannot list the network cards, so these ranges stand for the LAN.
local function localAddress(ip)
	local a, b = tostring(ip or ""):match("^(%d+)%.(%d+)%.%d+%.%d+$")
	a, b = tonumber(a), tonumber(b)
	if not a then return false end
	return a == 127 or a == 10 or a == 25 or (a == 172 and b >= 16 and b <= 31) or (a == 192 and b == 168) or (a == 169 and b == 254) or (a == 100 and b >= 64 and b <= 127)
end

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

-- who has which number as one line (name~ally~number|...): a joiner asks the host for it with the command COPILOT (a game option would be shown by the room as a text line)
local function copilotTag()
	local humans = humanList()
	local eff = effectiveSlots(humans)
	local t = {}
	for _, h in ipairs(humans) do t[#t + 1] = (h.name:gsub("%s", "_")) .. "~" .. h.ally .. "~" .. eff[h.name] end
	return table.concat(t, "|")
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
-- The extra game of the scenarios: "Level Editor Scenarios <version>" in games/LevelEditorScenarios_<version>.sdz (all gadgets; they switch on by the
-- game options of the scenario). The version comes from its files (Write-ScenarioGame in shared/bar_common.ps1), so another version never replaces
-- this one: a joiner who has not got the host's version gets it as a file of its own.
local SCENARIO_POINTER = "games/LevelEditorScenarios.txt" -- written by the Level Editor setup: file name and game name of its own version

-- the game of a version: file and name (nil for a version that is not 8 hex digits: it comes from the network)
gameOfTag = function(ver)
	if type(ver) ~= "string" or not ver:match("^%x%x%x%x%x%x%x%x$") then return nil end
	return { ver = ver, file = "games/LevelEditorScenarios_" .. ver .. ".sdz", name = "Level Editor Scenarios " .. ver }
end

-- the version the Level Editor setup built on this computer (nil when it is not installed)
ownGame = function()
	local text = VFS.LoadFile(SCENARIO_POINTER, VFS.RAW) or ""
	local ver = text:match("LevelEditorScenarios_(%x+)%.sdz")
	return gameOfTag(ver)
end

-- Versions of the Lua files of this computer that every player of a LAN game needs in the same version: the lobby widget (lan_lobby.lua) and the game
-- widget shared_start.lua (starts the Copilot games on official maps). The host answers the command LANVER (before the login, like COPILOT; a game option would be shown as a text line in the room) with "<lobby>|<shared>" (first 8 characters of VFS.CalculateHash each,
-- hash of the text without carriage returns; "-" when the file is not there); a joiner compares with his own and shows ONE warning on a difference.
fileTag = function(path)
	local text = VFS.LoadFile(path, VFS.RAW)
	if not text then return "-" end
	return VFS.CalculateHash((text:gsub("\r", "")), 0):sub(1, 8)
end

versionTag = function()
	return fileTag("LuaMenu/Widgets/lan_lobby.lua") .. "|" .. fileTag("LuaUI/Widgets/shared_start.lua") .. "|" .. LAN_VERSION.number .. "|" .. LAN_VERSION.stamp
end

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
	if sc.versus then
		-- Capture the Flag / Reclaim the Fame: human against human, the ally teams of the room decide. Only the first status of a joiner is corrected: he starts in
		-- the other ally team than the host (the room gives him the host's); afterwards he may choose (the lobby sends the status again after every change)
		local host = S.hostConn
		if c ~= host and not c.versusSet and host and host.battleStatus then
			c.versusSet = true
			local bs, hs = l:ParseBattleStatus(c.battleStatus), l:ParseBattleStatus(host.battleStatus)
			if not bs.isSpectator and bs.allyNumber == hs.allyNumber then
				bs.allyNumber = (hs.allyNumber + 1) % 2
				return encodeStatus(bs)
			end
		end
		return c.battleStatus
	end
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
	for _, c in ipairs(S.conns) do c.versusSet = nil end
	-- Capture the Flag and Reclaim the Fame are played human against human (a computer opponent does not play them): the opponent team of the scenario
	-- (the team of its AI) is taken by the humans who chose another ally team in the room than the host
	if low:find("ctfconfig%s*=") or low:find("rtfconfig%s*=") then
		local opp = low:match("%[ai%d+%]%s*{.-team%s*=%s*(%d+)")
		if opp then S.battle.scenario.versus = true; S.battle.scenario.oppTeam = tonumber(opp) end
	end
	-- the extra game: every computer needs the same file; the clients compare hash and size and fetch it from the host when theirs differs or is missing
	local own = ownGame()
	local data = own and VFS.LoadFile(own.file, VFS.RAW)
	S.gameFile = nil
	if data then
		S.gameFile = { data = data, size = #data, hash = VFS.CalculateHash(data, 0), ver = own.ver, name = own.name }
		toBattle("SETSCRIPTTAGS game/modoptions/lansync=" .. S.gameFile.ver .. "|" .. S.gameFile.hash .. "|" .. S.gameFile.size)
	else
		say("Warning: the extra game of the scenarios is not installed on the host (run the Level Editor setup).")
	end
	S.battle.map = map; updateBattleInfo()
	toBattle("SETSCRIPTTAGS game/modoptions/lanscenario=" .. name)
	applyScenarioToUsers()
	if S.battle.scenario.versus then
		say("Scenario: " .. name .. " (map " .. map .. "). Human against human: the players in the ally team of the host play the first team, the others the second team.")
	else
		say("Scenario: " .. name .. " (map " .. map .. "). The teams are the scenario's; the players join the team of the first player.")
	end
	log("scenario selected:", name, map, "player team", team, "ally team", ally)
end

local function startGameNow()
	if S.battle.running then return end
	S.battle.running = true
	log("the autohost starts the game")
	local humans = humanList()
	local parts = {}
	for _, g in ipairs(sharedGroups(humans, effectiveSlots(humans))) do parts[#parts + 1] = groupText(g) end
	if #parts > 0 and not S.battle.scenario then say("Copilot (one player, several humans): " .. table.concat(parts, "; ")) end
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

-- ---- maps: a joiner who has not got the map of the room gets the file from the host (asked with MAPINFO, fetched with FETCHMAP on short connections like
-- FETCHGAME). Only the map of the room is served, only a .sd7 / .sdz file of the maps folder, at most MAP_MAX bytes.
local MAP_MAX = 300 * 1024 * 1024

local function mapFileOf(name)
	if type(name) ~= "string" or name == "" then return nil end
	local ok, path = pcall(VFS.GetArchivePath, name)
	if not ok or type(path) ~= "string" then return nil end
	local file = path:gsub("\\", "/"):match("/maps/([^/]+)$")
	if not file or not file:lower():match("%.sd[7z]$") or file:find("..", 1, true) then return nil end
	return file
end

-- size and md5 (base64, as VFS.CalculateHash gives it) of the map file, worked out once
local function readWhole(path)
	local fh = io.open(path, "rb")
	if not fh then return nil end
	local parts = {}
	while true do
		local chunk = fh:read(65536)
		if not chunk then break end
		parts[#parts + 1] = chunk
	end
	fh:close()
	return table.concat(parts)
end

local function mapInfoOf(name)
	S.mapInfo = S.mapInfo or {}
	if S.mapInfo[name] then return S.mapInfo[name] end
	local file = mapFileOf(name)
	local data = file and readWhole("maps/" .. file)
	if not data or #data == 0 or #data > MAP_MAX then return nil end
	S.mapInfo[name] = { file = file, size = #data, hash = VFS.CalculateHash(data, 0) }
	return S.mapInfo[name]
end

-- md5 as the usual 32 hex digits (the file servers show it that way)
local function b64hex(b64)
	local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	local bits = {}
	for ch in b64:gsub("=", ""):gmatch(".") do
		local v = (alphabet:find(ch, 1, true) or 1) - 1
		for i = 5, 0, -1 do bits[#bits + 1] = math.floor(v / 2 ^ i) % 2 end
	end
	local out = {}
	for i = 1, #bits - 7, 8 do
		local byte = 0
		for j = 0, 7 do byte = byte * 2 + bits[i + j] end
		out[#out + 1] = string.format("%02x", byte)
	end
	return table.concat(out)
end

local function serverLine(c, line)
	line = line:gsub("^#%d+%s+", "")
	local cmd, args = line:match("^(%S+)%s*(.*)$")
	if not cmd then return end
	if cmd == "MAPINFO" and not c.name then
		local m = (args == S.battle.map) and mapInfoOf(args) or nil
		sendLine(c, "MAPINFO " .. (m and (m.size .. "|" .. m.hash .. "|" .. m.file) or "none")); c.close = true
		return
	end
	if cmd == "FETCHMAP" and not c.name then
		local m = (args == S.battle.map) and mapInfoOf(args) or nil
		local fh = m and io.open("maps/" .. m.file, "rb")
		if fh then c.mapServe = { fh = fh, header = "SIZE " .. m.size .. "\n" }; log("serving the map", args, "to", tostring(c.sock:getpeername()))
		else c.close = true end
		return
	end
	if cmd == "FETCHGAME" and not c.name then
		local g = S.gameFile
		if g and args == g.hash then c.serve = { pos = 1, header = "SIZE " .. g.size .. "\n" }; log("serving the extra game to", tostring(c.sock:getpeername()))
		else c.close = true end
		return
	end
	if cmd == "LANVER" and not c.name then
		sendLine(c, "LANVER " .. versionTag()); c.close = true
		return
	end
	if cmd == "COPILOT" and not c.name then
		sendLine(c, "COPILOT " .. copilotTag()); c.close = true
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
		if S.battle.scenario and S.gameFile then sendLine(c, "SETSCRIPTTAGS game/modoptions/lansync=" .. S.gameFile.ver .. "|" .. S.gameFile.hash .. "|" .. S.gameFile.size) end
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
		local from = new:getpeername()
		if not localAddress(from) then
			-- only this computer and the local network (a VPN included) may join
			log("connection refused (not a local network address):", tostring(from))
			pcall(function() new:close() end)
		else
			S.nextId = S.nextId + 1
			local c = { sock = new, buf = "", id = S.nextId, t = os.clock() }
			S.conns[#S.conns + 1] = c
			sendLine(c, "TASSERVER 0.38 " .. ((Spring.Utilities and Spring.Utilities.GetEngineVersion and Spring.Utilities.GetEngineVersion()) or "2026.07.04") .. " " .. PORT .. " 0")
		end
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
		if c.mapServe then
			local sv = c.mapServe
			if sv.header then
				if c.sock:send(sv.header) then sv.header = nil end
			else
				for _ = 1, 64 do   -- up to 4 MB a frame; the loop ends when the socket is full
					if not sv.pending then
						sv.pending = sv.fh:read(65536); sv.ppos = 1
						if not sv.pending then c.close = true; log("map served"); break end
					end
					local last, _, partial = c.sock:send(sv.pending, sv.ppos)
					local sent = last or partial
					if sent then sv.ppos = sent + 1 end
					if sv.ppos > #sv.pending then sv.pending = nil else break end
				end
			end
		end
		if err == "closed" or c.close or (not c.name and not c.serve and not c.mapServe and os.clock() - c.t > 6) then
			if c.mapServe then pcall(function() c.mapServe.fh:close() end) end
			removeConn(c)
		end
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
	local hostAlly = 0
	for _, c in ipairs(battleUsers()) do
		if c.name == myName and c.battleStatus then hostAlly = l:ParseBattleStatus(c.battleStatus).allyNumber or 0 end
	end
	local oppLeader   -- versus: the first human of the opponent team (its leader); his team replaces the AI of the scenario
	for i, c in ipairs(players) do
		local bs = c.battleStatus and l:ParseBattleStatus(c.battleStatus)
		local spec = (not bs) or bs.isSpectator
		local team = sc.team
		if sc.versus and not spec and bs.allyNumber ~= hostAlly then team = sc.oppTeam; oppLeader = oppLeader or i end
		extra[#extra + 1] = string.format("\t[player%d]\n\t{\n\t\tName=%s;\n\t\tPassword=%s;\n\t\tTeam=%d;\n\t\tspectator=%d;\n\t\trank=0;\n\t}\n", i, c.name, c.scriptPassword or "", team, spec and 1 or 0)
	end
	local removedAi = 0
	if oppLeader then
		-- the AI of the opponent team goes away, the first human of that team leads it
		text, removedAi = text:gsub("\t%[ai%d+%]%s*{[^}]*[Tt]eam%s*=%s*" .. sc.oppTeam .. "%s*;[^}]*}\n", "")
		text = text:gsub("(%[team" .. sc.oppTeam .. "%]%s*{[^}]-TeamLeader%s*=%s*)%d+", "%1" .. oppLeader, 1)
	end
	text = text:gsub("__GAMETYPE__", (S.gameFile and S.gameFile.name) or (ownGame() or {}).name or "Level Editor Scenarios"):gsub("__PLAYERNAME__", myName)
	text = text:gsub("hostip%s*=%s*[%d%.]+;", "hostip=0.0.0.0;"):gsub("hostport%s*=%s*%d+;", "hostport=" .. GAMEPORT .. ";")
	text = text:gsub("numplayers%s*=%s*%d+;", "numplayers=" .. (1 + #players) .. ";"):gsub("numusers%s*=%s*%d+;", "numusers=" .. (1 + #players + (origUsers - origPlayers) - removedAi) .. ";")
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
	t[#t + 1] = "\t\tlanplay=1;\n" -- the game widget shared_start.lua acts only in LAN Play games and scenarios
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
		if lan and lan.role == "client" and mapBusyFn and mapBusyFn() then
			lan.pendingConnect = { orig = original, args = { ... } }
			log("start postponed until the map is loaded")
			return
		end
		if lan and lan.role == "client" and self.modoptions and self.modoptions.lanscenario and self.modoptions.lanscenario ~= "" then
			local want = gameOfTag((self.modoptions.lansync or ""):match("^(%x+)|"))
			if not want then
				local msg = "The host plays the scenario '" .. self.modoptions.lanscenario .. "' with another version of the Level Editor (no game version announced): please update the Level Editor manually."
				log("cannot join the scenario:", msg)
				bigPopup(msg)
				return
			end
			if lan.fetch or lan.syncPending or (not VFS.HasArchive(want.name) and lan.syncFailed ~= want.ver) then
				-- still loading (or about to ask): the connection to the game is made as soon as the file is there
				lan.pendingConnect = { orig = original, args = { ... } }
				log("start postponed until the scenario game is loaded")
				return
			end
			if not VFS.HasArchive(want.name) then
				local msg = "The scenario game of the host (" .. want.name .. ") was not loaded: the scenario cannot start for you."
				log(msg); bigPopup(msg)
				return
			end
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

-- ---- the extra game of the scenario on a joiner: the host announces version, hash and size (game option lansync "<version>|<hash>|<size>"); a joiner who
-- has not got that version fetches it from the host after a question and keeps it as a file of its own (games/LevelEditorScenarios_<version>.sdz):
-- his own version is never replaced. A version he has already is used as it is (the version is made of the files, equal versions are equal games).

local function finishFetch(f, ok, reason)
	pcall(function() f.sock:close() end)
	lan.fetch = nil
	if ok then
		lan.syncPending = false
		setStatus("The scenario game is up to date.")
		if runPendingFn then runPendingFn() end
	else
		lan.syncFailed = f.game and f.game.ver; lan.syncPending = false; lan.pendingConnect = nil
		setStatus("Could not load the scenario game from the host: " .. tostring(reason))
		bigPopup("Could not load the scenario game from the host: " .. tostring(reason))
	end
end

local function startFetch(hash, size)
	local s = socket.tcp(); s:settimeout(3)
	local ok, e = s:connect(lan.ip, PORT)
	if not ok then finishFetch({ sock = s, hash = hash }, false, "no connection (" .. tostring(e) .. ")"); return end
	s:settimeout(0)
	s:send("FETCHGAME " .. hash .. "\n")
	lan.fetch = { sock = s, hash = hash, size = size, game = lan.syncGame, buf = "", parts = {}, got = 0, total = nil, t = os.clock() }
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
		local part = f.game.file .. ".part"
		local fh = io.open(part, "wb")
		if not fh then finishFetch(f, false, "cannot write " .. part); return end
		fh:write(all); fh:close()
		if not os.rename(part, f.game.file) then os.remove(part); finishFetch(f, false, "cannot write " .. f.game.file); return end
		pcall(VFS.ScanAllDirs)
		log("the extra game was loaded from the host:", f.total, "bytes; archive present:", tostring(VFS.HasArchive(f.game.name)))
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
	local ver, hash, size = tag:match("^(%x+)|(.-)|(%d+)$")
	local want = gameOfTag(ver)
	if not want or lan.syncAsked == ver then return end
	if VFS.HasArchive(want.name) then
		lan.syncAsked = ver
		local own = ownGame()
		log("scenario game check: same version as the host (" .. ver .. "), own version " .. tostring(own and own.ver) .. ", no transfer needed")
		setStatus("Same scenario game as the host (" .. ver .. ").")
		return
	end
	lan.syncAsked = ver
	log("scenario game check: the host has version " .. ver .. ", own version " .. tostring((ownGame() or {}).ver) .. ": different")
	local function yes() lan.syncGame = want; startFetch(hash, tonumber(size)) end
	local function no() lan.syncFailed = ver; setStatus("You did not load the scenario game: the scenario cannot start for you.") end
	if cfg.autoAccept then yes(); return end
	local q = "The host plays the scenario '" .. mo.lanscenario .. "' with the game '" .. want.name .. "', which you have not got. Load it from the host (" .. math.ceil(tonumber(size) / 1024) .. " KB, gadgets of the scenarios)? Only do this with a host you trust."
	if WG.Chobby and WG.Chobby.ConfirmationPopup then WG.Chobby.ConfirmationPopup(yes, q, nil, 480, 260, "Load it", "No", no) else yes() end
end

-- ---- a map the joiner has not got: ask the host (MAPINFO), ask the player (the checksum is the host's own word), fetch it (FETCHMAP) into maps/<file>.part,
-- check size and md5, then rename it and let the game scan its folders. The start of the game waits for it (see hookConnect).
mapBusyFn = function() return lan and (lan.mapAsk or lan.mapFetch or lan.mapPrompt) end

runPendingFn = function()
	if lan and lan.pendingConnect and not lan.fetch and not lan.syncPending and not mapBusyFn() then
		local a = lan.pendingConnect; lan.pendingConnect = nil
		local l = lobby()
		if l then a.orig(l, unpack(a.args)) end
	end
end

local function finishMap(ok, reason)
	local m = lan.mapFetch or {}
	if m.sock then pcall(function() m.sock:close() end) end
	if m.fh then pcall(function() m.fh:close() end) end
	if m.part and not ok then os.remove(m.part) end
	lan.mapFetch = nil
	if ok then
		setStatus("The map '" .. m.name .. "' was loaded from the host.")
		runPendingFn()
	else
		lan.mapFailed = m.name; lan.pendingConnect = nil
		lan.mapLan = nil; releaseHeld(m.name)
		local msg = "The map '" .. tostring(m.name) .. "' could not be loaded from the host: " .. tostring(reason)
		setStatus(msg); bigPopup(msg)
	end
end

-- the lobby starts the online download of a missing map by itself: it is in the queue of the download handler while it runs
local function onlineLoading(name)
	local dh = WG.DownloadHandler
	local queue = dh and dh.GetDownloadQueue and dh.GetDownloadQueue()
	for _, item in pairs(queue or {}) do
		if type(item) == "table" and item.name == name then return true end
	end
	return false
end

-- The lobby starts the online download of a missing map as soon as it knows the map of the room. In a LAN game as a joiner that call is kept back
-- (mapHold) until it is known where the map comes from: from the host (the held call is dropped, no online traffic) or online (it is let through).
local origQueue
local function installDownloadHold()
	local dh = WG.DownloadHandler
	if origQueue or not (dh and dh.QueueDownload) then return end
	origQueue = dh.QueueDownload
	dh.QueueDownload = function(n, ft, ...)
		if lan and lan.role == "client" and ft == "map" and not (lan.mapFree and lan.mapFree[n]) then
			if lan.mapLan == n then return end
			lan.held = lan.held or {}
			lan.held[n] = { ft = ft, args = { ... }, t = os.clock() }
			log("the online download of the map", n, "is held back until it is known where the map comes from")
			return
		end
		return origQueue(n, ft, ...)
	end
end

-- let the online download of a map go (the map does not come from the host)
releaseHeld = function(name)
	lan.mapFree = lan.mapFree or {}
	lan.mapFree[name] = true
	local h = lan.held and lan.held[name]
	if h then lan.held[name] = nil; origQueue(name, h.ft, unpack(h.args)) end
end

local function startMapFetch(name, info)
	local dh = WG.DownloadHandler
	lan.mapLan = name
	if lan.held then lan.held[name] = nil end
	if dh and dh.CancelDownload then pcall(dh.CancelDownload, name, "map") end   -- one that was already running
	local s = socket.tcp(); s:settimeout(3)
	local ok, e = s:connect(lan.ip, PORT)
	if not ok then lan.mapFetch = { sock = s, name = name }; finishMap(false, "no connection (" .. tostring(e) .. ")"); return end
	s:settimeout(0)
	s:send("FETCHMAP " .. name .. "\n")
	local part = "maps/" .. info.file .. ".part"
	local fh = io.open(part, "wb")
	lan.mapFetch = { sock = s, name = name, info = info, buf = "", got = 0, part = part, fh = fh, t = os.clock() }
	if not fh then finishMap(false, "cannot write " .. part); return end
	setStatus("Loading the map '" .. name .. "' from the host ...")
	log("loading the map", name, info.size, "bytes")
end

local function updateMapFetch()
	local f = lan.mapFetch
	for _ = 1, 64 do
		local data, err, partial = f.sock:receive(65536)
		data = data or partial
		if data and #data > 0 then
			f.t = os.clock()
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
						if f.total ~= f.info.size then finishMap(false, "the host sends another size than he announced"); return end
						data = f.buf; f.buf = ""
					elseif not line:find("^TASSERVER") then
						finishMap(false, "the host answered something else"); return
					end
				end
				if not f.total then data = nil end
			end
			if data and #data > 0 then
				local take = math.min(#data, f.total - f.got)   -- never more than the announced size
				if take > 0 then f.fh:write(data:sub(1, take)); f.got = f.got + take end
			end
		end
		if f.total and f.got >= f.total then
			f.fh:close(); f.fh = nil
			local all = readWhole(f.part)
			if not all or #all ~= f.info.size then finishMap(false, "the file has not the announced size"); return end
			if VFS.CalculateHash(all, 0) ~= f.info.hash then finishMap(false, "the file is not the one that was announced (md5)"); return end
			all = nil
			local final = "maps/" .. f.info.file
			os.remove(final)
			if not os.rename(f.part, final) then finishMap(false, "cannot write " .. final); return end
			pcall(VFS.ScanAllDirs)
			log("the map was loaded from the host:", f.total, "bytes, md5", b64hex(f.info.hash), "; archive present:", tostring(VFS.HasArchive(f.name)))
			finishMap(true)
			return
		end
		if err == "closed" then finishMap(false, "the host closed the connection"); return end
		if not data then break end
	end
	if os.clock() - f.t > 30 then finishMap(false, "timeout") end
end

-- the official md5 of a map from the list the Level Editor setup saved (games/LevelEditorMapHashes.txt, "<spring name>|<md5>"); nil when there is no list or no entry
local function officialMd5(name)
	if not lan.mapList then
		lan.mapList = {}
		local text = VFS.LoadFile("games/LevelEditorMapHashes.txt", VFS.RAW) or ""
		for line in text:gmatch("[^\r\n]+") do
			local n, h = line:match("^([^#|][^|]*)|(%x+)$")
			if n then lan.mapList[n] = h:lower() end
		end
	end
	return lan.mapList[name]
end

local function askMapQuestion(name, info)
	local mb = math.max(1, math.floor(info.size / 1048576 + 0.5))
	local function yes() lan.mapPrompt = nil; startMapFetch(name, info) end
	-- "online": the normal download of the lobby (pr-downloader checks the file against the official checksum); the lua of a widget cannot ask for a checksum itself
	local function online()
		lan.mapPrompt = nil; lan.mapFailed = name; lan.pendingConnect = nil
		releaseHeld(name)
		if WG.DownloadHandler and WG.DownloadHandler.MaybeDownloadArchive then
			if not onlineLoading(name) then WG.DownloadHandler.MaybeDownloadArchive(name, "map", 1) end
			setStatus("The lobby downloads the map '" .. name .. "' online. Start the game when it is there.")
		else
			setStatus("You did not load the map: the game cannot start for you.")
		end
	end
	-- the official list (saved by the Level Editor setup): the md5 of the host equals it = the file is checked by the file itself, no question needed
	local hostMd5, official = b64hex(info.hash), officialMd5(name)
	if official == hostMd5 then
		log("map check: the md5 of the host is the official one (" .. hostMd5 .. "): no question")
		yes(); return
	end
	log("map check: md5 of the host " .. hostMd5 .. ", official " .. tostring(official))
	if cfg.autoAccept then yes(); return end
	lan.mapPrompt = true
	local why
	if official then
		why = "The host's map is NOT the official one (its md5 " .. hostMd5 .. ", official " .. official .. "): the host or your list is out of date (run install_editor.bat to get the newest list), or it is a changed map."
	else
		why = "The map is not in your list of official maps (or you have no list): its md5 " .. hostMd5 .. " is only the host's word and cannot be checked from here."
	end
	local q = "The host plays the map '" .. name .. "' (" .. mb .. " MB), which you have not got.\n\nFrom the host: over the LAN, without internet. " .. why ..
		" Only accept from a host you trust.\n\nOnline: the lobby downloads the official map and checks it itself."
	if WG.Chobby and WG.Chobby.ConfirmationPopup then WG.Chobby.ConfirmationPopup(yes, q, nil, 620, 400, "From the host", "Online", online) else yes() end
end

local function updateMapSync()
	if not lan or lan.role ~= "client" or lan.step ~= "in" then return end
	if lan.mapFetch then updateMapFetch(); return end
	local a = lan.mapAsk
	if a then
		local reply
		if not a.sent then
			local _, w = socket.select(nil, { a.sock }, 0)
			if w and #w > 0 and a.sock:send("MAPINFO " .. a.name .. "\n") then a.sent = true end
		else
			local data, _, partial = a.sock:receive(2048)
			data = data or partial
			if data and #data > 0 then a.buf = a.buf .. data end
			reply = a.buf:match("MAPINFO ([^\r\n]*)")
		end
		if not reply and os.clock() - a.t < 5 then return end
		pcall(function() a.sock:close() end)
		lan.mapAsk = nil
		local size, hash, file = (reply or ""):match("^(%d+)|([^|]+)|([^|]+)$")
		if not size then
			lan.mapFailed = a.name; releaseHeld(a.name)
			log("map check: the host cannot send the map", a.name, "(" .. tostring(reply) .. ")")
			setStatus("You have not got the map '" .. a.name .. "' and the host cannot send it: load it with the lobby (online).")
			lan.pendingConnect = nil
			return
		end
		askMapQuestion(a.name, { size = tonumber(size), hash = hash, file = file })
		return
	end
	for n, h in pairs(lan.held or {}) do
		if not lan.mapPrompt and os.clock() - h.t > 30 then releaseHeld(n) end   -- nobody decided: the lobby loads it
	end
	if lan.mapPrompt then return end
	local l = lobby()
	local b = l and l.battles and l.battles[1]
	local name = b and b.mapName
	if not name or name == "" or VFS.HasArchive(name) or lan.mapFailed == name then return end
	if cfg.noOnline and WG.DownloadHandler and WG.DownloadHandler.CancelDownload then pcall(WG.DownloadHandler.CancelDownload, name, "map") end   -- test: no internet
	local sock = socket.tcp(); sock:settimeout(0)
	sock:connect(lan.ip, PORT)
	lan.mapAsk = { sock = sock, name = name, buf = "", sent = false, t = os.clock() }
	log("map check: the map", name, "is missing: asking the host")
end

-- one warning per join when the lobby widget or the game widget of the host is not the one of this computer
local function updateVersionCheck()
	if not lan or lan.role ~= "client" or lan.step ~= "in" or lan.verChecked then return end
	-- asked on a short connection (like COPILOT): a game option would be shown as a text line in the room and push its buttons away
	local q = lan.verQuery
	if not q then
		local sock = socket.tcp(); sock:settimeout(0)
		sock:connect(lan.ip, PORT)
		lan.verQuery = { sock = sock, buf = "", sent = false, t = os.clock() }
		return
	end
	local tag
	if not q.sent then
		local _, w = socket.select(nil, { q.sock }, 0)
		if w and #w > 0 then
			if q.sock:send("LANVER\n") then q.sent = true end
		end
	else
		local data, _, partial = q.sock:receive(2048)
		data = data or partial
		if data and #data > 0 then q.buf = q.buf .. data end
		tag = q.buf:match("LANVER ([^\r\n]*)")
	end
	if not tag and os.clock() - q.t < 4 then return end
	pcall(function() q.sock:close() end)
	lan.verChecked = true
	local mine = versionTag()
	if tag == mine then
		log("version check: same lobby and game widget as the host (" .. mine .. ")")
		return
	end
	local msg
	local own = "version " .. LAN_VERSION.number .. " (" .. LAN_VERSION.stamp .. ")"
	if not tag or tag == "" then
		msg = "Host:  no version announced (older than yours)" .. "\nYours: " .. own .. "\n\nUpdate the Level Editor on all computers to the same version: either git clone the repository on the other computers and git pull on all of them, or copy the whole Level Editor folder to the other computers and run install_editor.bat there. Then everybody has the same version. Otherwise the game may not start or behave differently."
	else
		local hl, hs, hn, hd = tag:match("^([^|]*)|([^|]*)|([^|]*)|(.*)$")
		local host = "version " .. tostring(hn) .. " (" .. tostring(hd) .. ")"
		local rel
		if tonumber(hn) and tonumber(hn) > LAN_VERSION.number then rel = "The host is newer than you."
		elseif tonumber(hn) and tonumber(hn) < LAN_VERSION.number then rel = "You are newer than the host."
		else rel = "Both have the same version number, but the files differ." end
		local what = {}
		if hl ~= fileTag("LuaMenu/Widgets/lan_lobby.lua") then what[#what + 1] = "lobby widget" end
		if hs ~= fileTag("LuaUI/Widgets/shared_start.lua") then what[#what + 1] = "game widget of the Copilot games" end
		msg = "Host:  " .. host .. "\nYours: " .. own .. "\n\n" .. rel .. " (differs: " .. table.concat(what, ", ") .. ")\n\nUpdate the Level Editor on all computers to the same version: either git clone the repository on the other computers and git pull on all of them, or copy the whole Level Editor folder to the other computers and run install_editor.bat there. Then everybody has the same version. Otherwise the game may not start or behave differently."
	end
	log("version check: DIFFERENT, host " .. tostring(tag) .. ", own " .. mine)
	setStatus((msg:gsub("\n", " ")))
	bigPopup(msg)
end

local function updateLan()
	if lan and lan.role == "client" then installDownloadHold() end
	if cfg.noOnline and not cfg.noOnlineDone and WG.DownloadHandler then
		cfg.noOnlineDone = true   -- test: the lobby cannot download anything (no internet)
		WG.DownloadHandler.QueueDownload = function() end
	end
	updateSync()
	updateMapSync()
	updateVersionCheck()
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

-- a joiner asks the host every two seconds who has which number (a short connection like the search for games)
local function updateCopilotPoll()
	if S or not lan or lan.step ~= "in" or not lan.ip then return end
	local p = lan.cop
	if not p then
		if os.clock() < (lan.copNext or 0) then return end
		lan.copNext = os.clock() + 2
		local sock = socket.tcp(); sock:settimeout(0)
		sock:connect(lan.ip, PORT)
		lan.cop = { sock = sock, buf = "", sent = false, t = os.clock() }
		return
	end
	local drop = false
	if not p.sent then
		local _, w = socket.select(nil, { p.sock }, 0)
		if w and #w > 0 then
			local n = p.sock:send("COPILOT\n")
			if n then p.sent = true else drop = true end
		elseif os.clock() - p.t > 2 then drop = true end
	else
		local data, err, partial = p.sock:receive(2048)
		data = data or partial
		if data and #data > 0 then p.buf = p.buf .. data end
		local value = p.buf:match("COPILOT ([^\r\n]*)")
		if value then lan.copilot = value; drop = true
		elseif err == "closed" or os.clock() - p.t > 3 then drop = true end
	end
	if drop then p.sock:close(); lan.cop = nil end
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
	local font = Config():GetFont((ui.roomCol and ui.roomCol.width < 300) and 1 or 2) -- small font in a narrow room (HD window)
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

-- The two host buttons sit in the middle column of the battle room, under the "Update Ready" / "Map Ready" lines (floating at the top left they were
-- hidden behind the lobby's own windows). The column is the parent of those labels; it is looked for about once a second, because the room is built again at times.
local function roomColumn()
	local found
	local function walk(c, depth)
		if found then return end
		local txt = c.caption or c.text
		if c.classname == "label" and type(txt) == "string" and (txt:find("^Map ") or txt:find("^Update ")) then found = c.parent; return end
		if depth < 16 and c.children then for _, ch in ipairs(c.children) do walk(ch, depth + 1) end end
	end
	walk(screen0, 0)
	if found then
		local bottom = 0
		for _, ch in ipairs(found.children or {}) do
			local txt = ch.caption or ch.text
			if ch.classname == "label" and type(txt) == "string" and (txt:find("^Map ") or txt:find("^Update ")) then bottom = math.max(bottom, ch.y + ch.height) end
		end
		ui.roomBottom = bottom
	end
	return found
end

-- sizes follow the column of the room: the column is about 380 wide in a 4K window and about 160 in a HD window (the heights of the lobby's buttons stay about the same)
local function roomNarrow() return ui.roomCol ~= nil and ui.roomCol.width < 300 end
local function roomFont() return Config():GetFont(roomNarrow() and 1 or 2) end
-- the lists open as a window over the team list (left of the column), in the panel that holds the column: below the buttons there is room for them in a 4K
-- window only; the window is left of the buttons, so the two buttons stay free to close it
local function roomWindowRect()
	local col = ui.roomCol
	local panel = col.parent
	return 5, 5, math.max(200, math.min(520, col.x - 10)), math.max(200, math.min(640, col.height - 4))
end

local function roomPlace(btn, row, show)
	if os.clock() > (ui.roomAt or 0) then ui.roomAt = os.clock() + 1; ui.roomCol = show and roomColumn() or nil end
	local col = ui.roomCol
	local mark = "lanButton" .. row -- the controls of the lobby are proxies here: a column is told apart by a field, not by ==
	if col then
		local y, w = (ui.roomBottom or 266) + 6 + (row - 1) * 42, col.width - 10
		local key = w .. ":" .. y
		if col[mark] ~= key then
			if col[mark] == nil then
				if btn.parent then btn.parent:RemoveChild(btn) end
				col:AddChild(btn)
			end
			btn:SetPos(5, y, w, 36)
			col[mark] = key
		end
	end
	local vis = show and col ~= nil
	if btn.visible ~= vis then btn:SetVisibility(vis) end
end

-- The two lists (scenarios, Copilot) are windows in the same column, below the two buttons (the main window of the room does not draw windows added to it).
local function roomMain()
	if os.clock() > (ui.roomAt or 0) then ui.roomAt = os.clock() + 1; ui.roomCol = roomColumn() end
	return ui.roomCol
end

-- The window is made new at every click, inside the column the room has just now (the lobby builds the room again at times; a window made earlier
-- would sit in the old one). A field of the column tells that this one has it (the controls are proxies here: no ==).
local function toggleScenarioWindow()
	ui.roomAt = 0
	local main = roomMain()
	if not main then return end
	if main.lanScnWin and ui.scnWindow and ui.scnWindow.visible then ui.scnWindow:Hide(); return end
	if not main.parent then return end
	if ui.scnWindow then pcall(function() ui.scnWindow:Dispose() end) end
	if ui.slotWindow then pcall(function() ui.slotWindow:Hide() end) end
	local wx, wy, ww, wh = roomWindowRect()
	ui.scnWindow = Window:New { parent = main.parent, x = wx, y = wy, width = ww, height = wh, resizable = false, draggable = false, classname = "main_window" }
	ui.scnList = ScrollPanel:New { parent = ui.scnWindow, x = 6, y = 6, right = 6, bottom = 50 }
	Button:New { parent = ui.scnWindow, x = 6, right = 6, bottom = 6, height = 36, caption = "Close", objectOverrideFont = roomFont(), OnClick = { function() ui.scnWindow:Hide() end } }
	main.lanScnWin = true
	fillScenarioList()
	ui.scnWindow:BringToFront()
end

local function ensureScenarioUi()
	if not ui.panel or not Config() then return end
	local show = (S ~= nil) and lan ~= nil and lan.step == "in"
	if not ui.scnButton then
		if not show or not roomMain() then return end
		local font = roomFont()
		ui.scnButton = Button:New { parent = screen0, x = 8, y = 8, width = 200, height = 36, caption = "Custom Scenario", objectOverrideFont = font, classname = "action_button",
			OnClick = { toggleScenarioWindow } }
		log("Custom Scenario button added")
	end
	roomPlace(ui.scnButton, 1, show)
	if not show then pcall(function() ui.scnButton:Dispose() end); ui.scnButton = nil end
end

---------------------------------------------------------------- "Copilot": numbers per human; the same number inside an ally team = one player together
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
		say(name .. " is player " .. eff[name] .. " of his team now and is Copilot with " .. table.concat(with, ", ") .. ".")
	else
		say(name .. " is player " .. eff[name] .. " of his team now (alone).")
	end
	log("slot:", name, "->", eff[name], #with > 0 and ("together with " .. table.concat(with, ", ")) or "alone")
end

-- who has which number: the host knows it, a joiner reads what the host announced
local function slotData()
	if S then
		local humans = humanList()
		return humans, effectiveSlots(humans)
	end
	local value = lan and lan.copilot or ""
	local humans, eff = {}, {}
	for name, ally, number in string.gmatch(value, "([^~|]+)~(%d+)~(%d+)") do
		humans[#humans + 1] = { name = name, ally = tonumber(ally) }
		eff[name] = tonumber(number)
	end
	return humans, eff
end

local function scenarioRoom()
	if S then return S.battle.scenario ~= nil end
	local l = lobby()
	local name = l and l.modoptions and l.modoptions.lanscenario
	return name ~= nil and name ~= ""
end

local function slotSignature()
	local humans, eff = slotData()
	local t = {}
	for _, h in ipairs(humans) do t[#t + 1] = h.name .. ":" .. h.ally .. ":" .. tostring(eff[h.name]) end
	return table.concat(t, "|") .. (scenarioRoom() and "|scenario" or "")
end

local COPILOT_TIP = "Click a player to give him the next number of his team. Players with the same number are Copilots: they play one player together."

-- a text box that is as high as its text needs at this width (about 9 px a letter in the small font)
local function textHeight(text, width)
	local perLine = math.max(8, math.floor(width / 9))
	return math.ceil(#text / perLine) * 20 + 6
end

local function fillSlotList()
	local font = roomFont()
	ui.slotList:ClearChildren()
	local y = 0
	local width = ui.slotW or 330
	local humans, eff = slotData()
	if scenarioRoom() then
		TextBox:New { parent = ui.slotList, x = 2, y = y, right = 2, height = 80, text = "A scenario: every human plays the team of the scenario together.", objectOverrideFont = font }
		return
	end
	if #humans == 0 then
		TextBox:New { parent = ui.slotList, x = 2, y = y, right = 2, height = 80, text = "No players in the room (spectators do not count).", objectOverrideFont = font }
		return
	end
	table.sort(humans, function(a, b) if a.ally ~= b.ally then return a.ally < b.ally end return a.name < b.name end)
	local groupOf = {}
	for _, g in ipairs(sharedGroups(humans, eff)) do groupOf[g.ally .. ":" .. g.number] = g end
	local lastAlly
	for _, h in ipairs(humans) do
		if h.ally ~= lastAlly then
			lastAlly = h.ally
			TextBox:New { parent = ui.slotList, x = 2, y = y + 4, right = 0, height = 30, text = "Team " .. (h.ally + 1), objectOverrideFont = font }
			y = y + 36
		end
		local name = h.name
		local nameW = math.min(90, math.floor(width * 0.4))
		TextBox:New { parent = ui.slotList, x = 4, y = y + 8, width = nameW, height = 30, text = name, objectOverrideFont = font }
		if S then
			Button:New { parent = ui.slotList, x = nameW + 6, y = y, right = 4, height = 36, caption = "player " .. eff[name], objectOverrideFont = font, tooltip = COPILOT_TIP,
				OnClick = { function() cycleSlot(name); fillSlotList() end } }
		else
			TextBox:New { parent = ui.slotList, x = nameW + 12, y = y + 8, right = 4, height = 30, text = "player " .. eff[name], objectOverrideFont = font, tooltip = COPILOT_TIP }
		end
		local g = groupOf[h.ally .. ":" .. eff[name]]
		if g then
			local others = {}
			for _, o in ipairs(g.names) do if o ~= name then others[#others + 1] = o end end
			local text = "+ Copilot: " .. table.concat(others, ", ")
			local th = textHeight(text, width)
			TextBox:New { parent = ui.slotList, x = 10, y = y + 40, right = 2, height = th, text = text, objectOverrideFont = Config():GetFont(1) }
			y = y + th
		end
		y = y + 44
	end
end

local function toggleSlotWindow(forceShow)
	ui.roomAt = 0
	local main = roomMain()
	if not main then return end
	if not forceShow and main.lanSlotWin and ui.slotWindow and ui.slotWindow.visible then ui.slotWindow:Hide(); return end
	if not main.parent then return end
	if ui.slotWindow then pcall(function() ui.slotWindow:Dispose() end) end
	if ui.scnWindow then pcall(function() ui.scnWindow:Hide() end) end
	local wx, wy, ww, wh = roomWindowRect()
	ui.slotWindow = Window:New { parent = main.parent, x = wx, y = wy, width = ww, height = wh, resizable = false, draggable = false, classname = "main_window" }
	ui.slotList = ScrollPanel:New { parent = ui.slotWindow, x = 6, y = 6, right = 6, bottom = 50 }
	Button:New { parent = ui.slotWindow, x = 6, right = 6, bottom = 6, height = 36, caption = "Close", objectOverrideFont = roomFont(), OnClick = { function() ui.slotWindow:Hide() end } }
	ui.slotW = ww - 80
	main.lanSlotWin = true
	fillSlotList()
	ui.slotSig = slotSignature()
	ui.slotWindow:BringToFront()
end

local function ensureSlotUi()
	if not ui.panel or not Config() then return end
	local show = lan ~= nil and lan.step == "in" -- the host and the joiners (a joiner only looks)
	if not ui.slotButton then
		if not show or not roomMain() then return end
		local font = roomFont()
		ui.slotButton = Button:New { parent = screen0, x = 8, y = 8, width = 200, height = 36, caption = "Copilot", objectOverrideFont = font, classname = "action_button", tooltip = COPILOT_TIP,
			OnClick = { function() toggleSlotWindow() end } }
		log("Copilot button added")
	end
	roomPlace(ui.slotButton, S and 2 or 1, show)
	if not show then pcall(function() ui.slotButton:Dispose() end); ui.slotButton = nil end
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
	updateCopilotPoll()

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
		local own = ownGame() or {}
		log("test: scenario.txt read:", txt and #txt or "FAILED", "bytes; game archive '" .. tostring(own.name) .. "' present:", tostring(own.name and VFS.HasArchive(own.name)))
		if txt then
			local script = txt:gsub("__GAMETYPE__", cfg.scenarioGame or own.name or "Level Editor Scenarios"):gsub("__PLAYERNAME__", cfg.name or "PlayerC")
			log("test: starting the scenario with Spring.Reload")
			Spring.Reload(script)
		end
	end
	if cfg.leaveAfter and lan and lan.step == "in" then
		lan.inAt = lan.inAt or os.clock()
		if os.clock() > lan.inAt + tonumber(cfg.leaveAfter) and not lan.leaveSent then lan.leaveSent = true; log("test: pressing Leave in the room (lobby:LeaveBattle)"); WG.BattleRoomWindow.LeaveBattle() end
	end
	if cfg.copilot and S and lan and lan.step == "in" and ui.slotButton and not cfg.copilotDone and #humanList() >= 2 then
		cfg.copilotAt = cfg.copilotAt or (os.clock() + 4)
		if os.clock() > cfg.copilotAt then
			cfg.copilotDone = true
			log("test: Copilot for", cfg.copilot)
			cycleSlot(cfg.copilot)
		end
	end
	if cfg.showCopilot and lan and lan.step == "in" and ui.slotButton and not cfg.showDone and os.clock() > (cfg.showAt or 1e9) then
		cfg.showDone = true
		log("test: Copilot list of a joiner:", slotSignature())
		toggleSlotWindow(true)
	end
	if cfg.showCopilot and lan and lan.step == "in" and not cfg.showAt then cfg.showAt = os.clock() + 30 end
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
			S.autoAt = S.autoAt or (os.clock() + (tonumber(cfg.startDelay) or 4))
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
