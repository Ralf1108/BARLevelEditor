-- LAN Play: the Scavengers / Raptors AI of a room only spawns, it does not command (synchronized part).
-- The game's Scavenger and Raptor gadgets give their units orders (move, fight, attack ...); in a LAN room with such an AI the humans of its ally team command those
-- units themselves. This gadget drops the orders that the Scavenger and Raptor gadgets give (found by the call stack: the order is given from inside their code)
-- to a unit of a team with the Lua AI "Scavengers..." / "Raptors...". Every other order passes: the orders of players, and also the orders that other gadgets of
-- the game derive from a player's order (they arrive as orders of a gadget, too, so the kind of the order alone does not tell them apart).
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
local logged = 0 -- the first orders to those teams are written to the log (to see what arrives), then it stays quiet
local LOG_MAX = 30
local blockedCount = 0

-- orders that only switch a state: they stay allowed
local STATES = {
	[CMD.FIRE_STATE] = true, [CMD.MOVE_STATE] = true, [CMD.REPEAT] = true, [CMD.CLOAK] = true, [CMD.ONOFF] = true,
	[CMD.TRAJECTORY] = true, [CMD.IDLEMODE] = true, [CMD.AUTOREPAIRLEVEL] = true, [CMD.STOCKPILE] = true,
}

-- true when the order is being given from inside the code of a Scavenger or Raptor gadget
local function givenBySpawner()
	if not (debug and debug.traceback) then
		return false
	end
	local ok, stack = pcall(debug.traceback, "", 2)
	if not ok or type(stack) ~= "string" then
		return false
	end
	stack = stack:lower()
	return stack:find("raptor", 1, true) ~= nil or stack:find("scav", 1, true) ~= nil
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
		if ai and (ai:find("Scavengers", 1, true) or ai:find("Raptors", 1, true)) then
			held[teamID] = true
			count = count + 1
		end
	end
	if count == 0 then
		gadgetHandler:RemoveGadget(self)
		return
	end
	Spring.Echo("[LAN] the orders of the Scavengers / Raptors gadgets are dropped (" .. count .. " team(s)); players may command those units")
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if not held[unitTeam] or STATES[cmdID] then
		return true
	end
	local drop = false
	if fromSynced or fromLua or (playerID or -1) < 0 then
		drop = givenBySpawner()
	end
	if logged < LOG_MAX then
		logged = logged + 1
		Spring.Echo(string.format("[LAN] order %s to a unit of team %d: player %s, fromSynced %s, fromLua %s -> %s", tostring(cmdID), unitTeam, tostring(playerID),
			tostring(fromSynced), tostring(fromLua), drop and "dropped" or "allowed"))
	end
	if drop then
		blockedCount = blockedCount + 1
		return false
	end
	return true
end
