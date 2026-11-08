-- LAN Play: the Scavengers / Raptors AI of a room only spawns, it does not command (synchronized part).
-- The game's Scavenger and Raptor gadgets give their units orders (move, fight, attack ...); in a LAN room with such an AI the humans of its ally team command those
-- units themselves. This gadget drops every order that Lua code gives to a unit of a team with the Lua AI "Scavengers..." / "Raptors..." without a player behind it
-- (playerID -1: the orders of those gadgets). Orders of players pass, also those that other gadgets of the game pass on for a player (they keep the player number).
-- Active only when the game option lanpvehold=1 is set (lan_lobby.lua writes it into the start script when the room has such a computer), and only for an AI
-- that has a human player in its ally team: a human there wants to command the units. An AI alone in its ally team stays as the game has it.
function gadget:GetInfo()
	return {
		name = "LAN: no orders of the Scavengers / Raptors AI",
		desc = "Drops the orders that the Scavenger and Raptor gadgets give to their units; players may command them",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local held = {} -- teamID -> true: a team with a Scavengers / Raptors Lua AI
local logged = 0 -- the first orders to those teams are written to the log (to see what arrives), then it stays quiet
local LOG_MAX = 30

-- orders that only switch a state: they stay allowed
local STATES = {
	[CMD.FIRE_STATE] = true, [CMD.MOVE_STATE] = true, [CMD.REPEAT] = true, [CMD.CLOAK] = true, [CMD.ONOFF] = true,
	[CMD.TRAJECTORY] = true, [CMD.IDLEMODE] = true, [CMD.AUTOREPAIRLEVEL] = true, [CMD.STOCKPILE] = true,
}

-- a human player (not a spectator) in a team of that ally team
local function hasHuman(allyTeamID)
	for _, teamID in ipairs(Spring.GetTeamList(allyTeamID) or {}) do
		local isAI = select(4, Spring.GetTeamInfo(teamID, false))
		if not isAI then
			for _, playerID in ipairs(Spring.GetPlayerList(teamID) or {}) do
				local spec = select(3, Spring.GetPlayerInfo(playerID, false))
				if not spec then
					return true
				end
			end
		end
	end
	return false
end

function gadget:Initialize()
	local on = (Spring.GetModOptions() or {}).lanpvehold
	if on ~= "1" and on ~= 1 then
		gadgetHandler:RemoveGadget(self)
		return
	end
	local count = 0
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local ai = Spring.GetTeamLuaAI(teamID)
		if ai and (ai:find("Scavengers", 1, true) or ai:find("Raptors", 1, true)) and hasHuman(select(6, Spring.GetTeamInfo(teamID, false))) then
			held[teamID] = true
			count = count + 1
		end
	end
	if count == 0 then
		gadgetHandler:RemoveGadget(self)
		return
	end
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- otherwise the engine registers it and warns (as in the other gadgets)
	end
	Spring.Echo("[LAN] the orders of the Scavengers / Raptors gadgets are dropped (" .. count .. " team(s)); players may command those units")
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if not held[unitTeam] or STATES[cmdID] then
		return true
	end
	-- an order of a player has a player number (playerID >= 0), also when another gadget passes it on; the orders of the Scavenger and Raptor gadgets are given by
	-- Lua code without a player (playerID -1)
	local drop = (playerID or -1) < 0 and (fromSynced or fromLua) and true or false
	if logged < LOG_MAX then
		logged = logged + 1
		Spring.Echo(string.format("[LAN] order %s to a unit of team %d: player %s, fromSynced %s, fromLua %s -> %s", tostring(cmdID), unitTeam, tostring(playerID),
			tostring(fromSynced), tostring(fromLua), drop and "dropped" or "allowed"))
	end
	if drop then
		return false
	end
	return true
end
