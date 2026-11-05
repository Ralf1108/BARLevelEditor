-- LAN Play: the Scavengers / Raptors AI of a room only spawns, it does not command (synchronized part).
-- The game's Scavenger and Raptor gadgets give their units orders (move, fight, attack ...); in a LAN room with such an AI the humans of its ally team command those
-- units themselves. This gadget drops every order that a gadget gives (fromSynced) to a unit of a team with the Lua AI "Scavengers..." / "Raptors...";
-- orders of players (also of the players of the same ally team) pass. Switching states (fire state, move state, repeat ...) pass too.
-- Active only when the game option lanpvehold=1 is set (lan_lobby.lua writes it into the start script when the room has such a computer).
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

-- orders that only switch a state: they stay allowed
local STATES = {
	[CMD.FIRE_STATE] = true, [CMD.MOVE_STATE] = true, [CMD.REPEAT] = true, [CMD.CLOAK] = true, [CMD.ONOFF] = true,
	[CMD.TRAJECTORY] = true, [CMD.IDLEMODE] = true, [CMD.AUTOREPAIRLEVEL] = true, [CMD.STOCKPILE] = true,
}

function gadget:Initialize()
	local on = (Spring.GetModOptions() or {}).lanpvehold
	if on ~= "1" and on ~= 1 then
		gadgetHandler:RemoveGadget(self)
		return
	end
	local count = 0
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local ai = Spring.GetTeamLuaAI(teamID)
		if ai and (ai:find("Scavengers", 1, true) or ai:find("Raptors", 1, true)) then
			held[teamID] = true
			count = count + 1
		end
	end
	if count == 0 then
		gadgetHandler:RemoveGadget(self)
		return
	end
	Spring.Echo("[LAN] the orders of the Scavengers / Raptors AI are dropped (" .. count .. " team(s)); players may command those units")
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if held[unitTeam] and fromSynced and not STATES[cmdID] then
		return false
	end
	return true
end
