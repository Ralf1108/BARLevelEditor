-- Level restrictions (synchronized part): what the player may not build while a test or a finished scenario runs. One list for the whole
-- level (the Place menu and the Tower Defense page of the editor write the same list), for every game mode.
-- Configuration: from the Level Editor with the message "rst|start|<payload>" (stop: "rst|stop"), or from the game option
-- restrictions (same payload as base64url) for a finished scenario. Payload: "name,name,..." or "-": the units that cannot be built.
-- Tech levels per team (the scenario info of the level, "Tech team n"): the game option techtiers (base64url of "team:digits/team:digits", e.g.
-- "1:12" = team 1 may build only T1 and T2); a unit counts as T3 from tech level 3 on and as T2 above 1 (bar_rules.techLevel: Epic units are T3).
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
local TECH_REASON = "scenario_tech" -- the same for the tech levels of a team
local START_FRAME = 5 -- finished scenario: the restrictions start this frame (after the build blocking of BAR has started)

local opt = Spring.GetModOptions().leveleditor
local EDITOR_MODE = (opt == "1" or opt == 1 or opt == true)

local Rules = VFS.Include("luaui/Include/bar_rules.lua", nil, VFS.ZIP_FIRST)
assert(Rules, "bar_rules.lua missing (run install_editor.bat again)")
local decode64 = Rules.decode64

local blocked = nil -- running restrictions: unitDefID -> true; nil = none
local blockedTeams = {} -- teams the build blocking of BAR was told about
local pendingPayload = nil
local teamTech = {} -- team -> { unitDefID -> true }: what the tech levels of the team do not allow (finished scenario)
local pendingTiers = nil

local function say(text)
	if Spring.SendMessage then
		Spring.SendMessage("[Level restrictions] " .. text)
	else
		Spring.Echo("[Level restrictions] " .. text)
	end
end

local function split(text, sep)
	local out = {}
	for part in (tostring(text) .. sep):gmatch("(.-)" .. sep:gsub("%p", "%%%0")) do
		if part ~= "" and part ~= "-" then
			out[#out + 1] = part
		end
	end
	return out
end

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

local MESSAGE_GAP = 5 * 30 -- frames between two messages of the same unit type to the same team
local lastMessage = {} -- team -> unitDefID -> frame of the last message

-- The unit a build order builds (also an order inserted into the queue: CMD.INSERT { position, command, options, ... }); nil for other orders
local function builtDef(cmdID, cmdParams)
	if cmdID < 0 then
		return -cmdID
	end
	if cmdID == CMD.INSERT and cmdParams and (tonumber(cmdParams[2]) or 0) < 0 then
		return -cmdParams[2]
	end
	return nil
end

-- "Not allowed" only to a human team (an AI would get it again and again), at most once per unit type every few seconds
local function refuse(teamID, defID)
	local isAI = select(4, Spring.GetTeamInfo(teamID, false))
	if isAI or teamID == Spring.GetGaiaTeamID() then
		return
	end
	local n = Spring.GetGameFrame()
	local seen = lastMessage[teamID] or {}
	lastMessage[teamID] = seen
	if seen[defID] and n - seen[defID] < MESSAGE_GAP then
		return
	end
	seen[defID] = n
	local ud = UnitDefs[defID]
	local text = "[Level restrictions] Not allowed in this level: " .. ((ud and (ud.translatedHumanName or ud.name)) or "?")
	if Spring.SendMessageToTeam then
		Spring.SendMessageToTeam(teamID, text)
	else
		Spring.Echo(text)
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	local defID = builtDef(cmdID, cmdParams)
	if defID and ((blocked and blocked[defID]) or (teamTech[teamID] and teamTech[teamID][defID])) then
		refuse(teamID, defID)
		return false
	end
	return true
end

-- "1", "2" or "3": the tech level of a unit as the scenario counts it
local function tierOf(ud)
	local t = Rules.techLevel(ud)
	if t >= 3 then
		return "3"
	elseif t > 1 then
		return "2"
	end
	return "1"
end

-- The tech levels of the teams: "team:digits/team:digits" (the digits are the allowed levels)
local function startTiers(text)
	for team, allowed in tostring(text):gmatch("(%d+):(%d*)") do
		team = tonumber(team)
		if Spring.GetTeamInfo(team, false) then
			local set, n = {}, 0
			for id, ud in pairs(UnitDefs) do
				if not allowed:find(tierOf(ud), 1, true) then
					set[id] = true
					n = n + 1
					if GG.BuildBlocking and GG.BuildBlocking.AddBlockedUnit then
						GG.BuildBlocking.AddBlockedUnit(id, team, TECH_REASON)
					end
				end
			end
			teamTech[team] = set
			say(string.format("Team %d may build only tech level %s (%d units blocked).", team, allowed:gsub(".", "%0+"):sub(1, -2), n))
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 4) ~= "rst|" then
		return
	end
	if not (Spring.IsCheatingEnabled() or EDITOR_MODE) then
		return true
	end
	local cmd, payload = msg:match("^rst|(%a+)|?(.*)$")
	if cmd == "start" then
		start(payload)
	elseif cmd == "stop" then
		release()
	end
	return true
end

function gadget:Initialize()
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- build orders: otherwise the engine registers it and warns
	end
end

-- Finished scenario: the restrictions come in the game option restrictions (the payload as base64url)
function gadget:GamePreload()
	local mo = Spring.GetModOptions()
	if mo.restrictions and mo.restrictions ~= "" then
		pendingPayload = decode64(mo.restrictions)
	end
	if mo.techtiers and mo.techtiers ~= "" then
		pendingTiers = decode64(mo.techtiers)
	end
end

function gadget:GameFrame(n)
	if pendingPayload and n >= START_FRAME then
		local payload = pendingPayload
		pendingPayload = nil
		start(payload)
	end
	if pendingTiers and n >= START_FRAME then
		local tiers = pendingTiers
		pendingTiers = nil
		startTiers(tiers)
	end
end

function gadget:Shutdown()
	release()
end
