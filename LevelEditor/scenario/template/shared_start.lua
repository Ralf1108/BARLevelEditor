function widget:GetInfo()
	return {
		name = "Shared player start",
		desc = "Starts a game in which two or more human players control the same team (the game does not start by itself then); only the host acts",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Found in a test with two instances of the game on one computer: with two humans in different teams the game starts by itself after the delay of the
-- start script, with two humans in the SAME team it stays in the pregame (nobody is "ready" for the second player of the team). The host (player 0) then
-- sends the engine command "forcestart" once every human player is active: a player becomes active when he has finished loading (seen in the test:
-- the host active after 3 s, the second player after 13 s).
local GRACE = 3 -- seconds after the moment when everybody is active, before the start is forced
local DEBUG = false

-- Only in a game of the Level Editor: a scenario (game option scenariooptions) or a LAN Play game (lanplay, set by the LAN Play lobby). The widget is
-- also a user widget where LAN Play is installed (for the Copilot games on official maps), so it must stay quiet in every other game.
function widget:Initialize()
	local mo = Spring.GetModOptions() or {}
	if mo.lanplay ~= "1" and (mo.scenariooptions or "") == "" then
		widgetHandler:RemoveWidget(widget)
	end
end

local t0, allSince, sent, lastLog = nil, nil, false, 0

-- true if some team has two or more human (non-spectating) players
local function sharedTeam()
	local count = {}
	for _, pid in ipairs(Spring.GetPlayerList()) do
		local _, _, spec, team = Spring.GetPlayerInfo(pid, false)
		if not spec and team then
			count[team] = (count[team] or 0) + 1
			if count[team] >= 2 then
				return true
			end
		end
	end
	return false
end

local function everybodyConnected()
	for _, pid in ipairs(Spring.GetPlayerList()) do
		local _, active, spec = Spring.GetPlayerInfo(pid, false)
		if not spec and not active then
			return false
		end
	end
	return true
end

function widget:Update()
	if sent then
		return
	end
	if Spring.GetGameFrame() > 0 then
		sent = true
		return
	end
	if Spring.GetMyPlayerID() ~= 0 then
		return -- only the host acts
	end
	t0 = t0 or os.clock()
	local waited = os.clock() - t0
	if DEBUG and os.clock() - lastLog > 2 then
		lastLog = os.clock()
		local parts = {}
		for _, pid in ipairs(Spring.GetPlayerList()) do
			local name, active, spec, team, _, ping, cpu = Spring.GetPlayerInfo(pid, false)
			parts[#parts + 1] = string.format("%s(team %s active %s ping %s cpu %s)", tostring(name), tostring(team), tostring(active), tostring(ping), tostring(cpu))
		end
		Spring.Echo(string.format("SHAREDSTART t=%.0f shared=%s %s", waited, tostring(sharedTeam()), table.concat(parts, " ")))
	end
	if sharedTeam() and everybodyConnected() then
		allSince = allSince or os.clock()
	else
		allSince = nil
	end
	if allSince and os.clock() - allSince >= GRACE then
		sent = true
		Spring.Echo("[Shared player start] two or more players control one team: starting the game")
		Spring.SendCommands("forcestart")
	end
end
