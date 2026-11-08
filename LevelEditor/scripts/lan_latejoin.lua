-- LAN Play: a player who comes into a running game becomes a player.
-- The game server of the room lets players in who are not in the start script (start script key AllowAdditionalPlayers, written by lan_lobby.lua when the room has
-- "late join" on): the engine puts them into the game as spectators (their name gets a "~" in front). The unsynchronized part sends one game message "lanlatejoin"
-- for such a player; the synchronized part receives it on every computer at the same game frame (a late joiner replays it while catching up) and moves the player
-- into a team: the ally team with the fewest human players, there the team with the fewest players (the newcomer plays it together with them, as in Copilot).
-- A choice from the state of the game alone, no network state (every computer must come to the same result). Active only when the game option lanlatejoin=1 is set.
function gadget:GetInfo()
	return {
		name = "LAN: late join as a player",
		desc = "Moves a player who joins a running LAN game into a team",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local MSG = "lanlatejoin"

if not gadgetHandler:IsSyncedCode() then
	-- unsynchronized: an additional player (the engine adds "~" to its name) asks once for a team
	local sent = false
	function gadget:Initialize()
		local on = (Spring.GetModOptions() or {}).lanlatejoin
		if on ~= "1" and on ~= 1 then gadgetHandler:RemoveGadget(self) end
	end
	function gadget:Update()
		if sent then return end
		local _, _, spec = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
		local name = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
		if spec and type(name) == "string" and name:sub(1, 1) == "~" then
			sent = true
			Spring.SendLuaRulesMsg(MSG)
		elseif not spec then
			sent = true
		end
	end
	return
end

local function humanCount(teamID)
	local n = 0
	for _, pid in ipairs(Spring.GetPlayerList(teamID) or {}) do
		local spec = select(3, Spring.GetPlayerInfo(pid, false))
		if not spec then n = n + 1 end
	end
	return n
end

-- the team for a newcomer, or nil when there is none (only computers in the game)
local function chooseTeam()
	local gaia = Spring.GetGaiaTeamID()
	local allies = {} -- allyTeamID -> { humans = n, teams = { teamID ... } }
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local _, _, dead, isAI, _, allyID = Spring.GetTeamInfo(teamID, false)
		local luaAI = Spring.GetTeamLuaAI(teamID)
		if teamID ~= gaia and not dead and not isAI and (not luaAI or luaAI == "") then
			local a = allies[allyID] or { humans = 0, teams = {} }
			allies[allyID] = a
			a.teams[#a.teams + 1] = teamID
			a.humans = a.humans + humanCount(teamID)
		end
	end
	local bestAlly
	for allyID, a in pairs(allies) do
		if not bestAlly or a.humans < allies[bestAlly].humans or (a.humans == allies[bestAlly].humans and allyID < bestAlly) then bestAlly = allyID end
	end
	if not bestAlly then return nil end
	local best, bestN
	for _, teamID in ipairs(allies[bestAlly].teams) do
		local n = humanCount(teamID)
		if not best or n < bestN or (n == bestN and teamID < best) then best, bestN = teamID, n end
	end
	return best, bestAlly
end

function gadget:Initialize()
	local on = (Spring.GetModOptions() or {}).lanlatejoin
	if on ~= "1" and on ~= 1 then
		gadgetHandler:RemoveGadget(self)
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg ~= MSG then return end
	local name, _, spec = Spring.GetPlayerInfo(playerID, false)
	-- only an additional player ("~" in front of the name), not a spectator of the start script who sends the message by hand
	if not spec or type(name) ~= "string" or name:sub(1, 1) ~= "~" then return end
	local teamID, allyID = chooseTeam()
	if not teamID then return end
	Spring.AssignPlayerToTeam(playerID, teamID)
	Spring.Echo("[LAN] late join: " .. tostring(name) .. " plays team " .. teamID .. " (ally team " .. allyID .. ")")
end
