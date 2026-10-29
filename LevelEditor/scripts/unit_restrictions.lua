-- Level restrictions (synchronized part): what the player may not build while a test or a finished scenario runs. One list for the whole
-- level (the Place menu and the Tower Defense page of the editor write the same list), for every game mode.
-- Configuration: from the Level Editor with the message "rst|start|<payload>" (stop: "rst|stop"), or from the game option
-- restrictions (same payload as base64url) for a finished scenario. Payload: "name,name,..." or "-": the units that cannot be built.
-- The block goes through the build blocking of BAR (GG.BuildBlocking.AddBlockedUnit: the units are greyed out in the build menu) when it
-- exists, and always through AllowCommand (build orders of builders and factories, also inserted ones). It holds for every team, the
-- computer players too (they do not know the list and may try again and again: their refused orders stay silent; a human team gets a
-- message, at most one per unit type every few seconds).
function gadget:GetInfo()
	return {
		name = "Level restrictions",
		desc = "Units the player cannot build in this level",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local REASON = "level_restrictions" -- reason key at the build blocking of BAR
local START_FRAME = 5 -- finished scenario: the restrictions start this frame (after the build blocking of BAR has started)

local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST) -- what the gadgets of the editor share (led_gadgets.lua)

local blocked = nil -- running restrictions: unitDefID -> true; nil = none
local blockedTeams = {} -- teams the build blocking of BAR was told about
local pendingPayload = nil

local say = G.sayer("Level restrictions")
local split = G.split
local message = G.teamMessenger("Level restrictions")

-- The unitDefIDs of the names in the payload
local function parse(payload)
	local set, count = {}, 0
	for _, name in ipairs(split(payload, ",")) do
		local ud = UnitDefNames[name]
		if ud and not set[ud.id] then
			set[ud.id] = true
			count = count + 1
		end
	end
	return set, count
end

local function release()
	if blocked and GG.BuildBlocking and GG.BuildBlocking.RemoveBlockedUnit then
		for _, team in ipairs(blockedTeams) do
			for id in pairs(blocked) do
				GG.BuildBlocking.RemoveBlockedUnit(id, team, REASON)
			end
		end
	end
	blocked, blockedTeams = nil, {}
end

local function start(payload)
	release()
	local set, count = parse(payload)
	if count == 0 then
		return
	end
	blocked = set
	if GG.BuildBlocking and GG.BuildBlocking.AddBlockedUnit then
		local gaia = Spring.GetGaiaTeamID()
		for _, team in ipairs(Spring.GetTeamList()) do
			if team ~= gaia then
				blockedTeams[#blockedTeams + 1] = team
				for id in pairs(set) do
					GG.BuildBlocking.AddBlockedUnit(id, team, REASON)
				end
			end
		end
	end
	say(count .. " units cannot be built in this level.")
end

-- "Not allowed" only to a human team, at most once per unit type every few seconds (G.teamMessenger)
local function refuse(teamID, defID)
	local ud = UnitDefs[defID]
	message(teamID, defID, "Not allowed in this level: " .. ((ud and (ud.translatedHumanName or ud.name)) or "?"))
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	local defID = G.builtDef(cmdID, cmdParams)
	if defID and blocked and blocked[defID] then
		refuse(teamID, defID)
		return false
	end
	return true
end

local messages = { start = function(payload) start(payload) end, stop = function() release() end }

function gadget:RecvLuaMsg(msg, playerID)
	return G.handleMessage("rst", messages, msg, playerID)
end

function gadget:Initialize()
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- build orders: otherwise the engine registers it and warns
	end
end

-- Finished scenario: the restrictions come in the game option restrictions (the payload as base64url)
function gadget:GamePreload()
	pendingPayload = G.option("restrictions")
end

function gadget:GameFrame(n)
	if pendingPayload and n >= START_FRAME then
		local payload = pendingPayload
		pendingPayload = nil
		start(payload)
	end
end

function gadget:Shutdown()
	release()
end
