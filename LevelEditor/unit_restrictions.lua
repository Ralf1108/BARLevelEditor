-- Level restrictions (synchronized part): what the player may not build while a test or a finished scenario runs. One list for the whole
-- level (the Place menu and the Tower Defense page of the editor write the same list), for every game mode.
-- Configuration: from the Level Editor with the message "rst|start|<payload>" (stop: "rst|stop"), or from the game option
-- restrictions (same payload as base64url) for a finished scenario. Payload: "banned;bannedTech"
--   banned = "name,name,..." or "-": units that cannot be built
--   bannedTech = "1,3" or "-": tech levels (as the editor counts them, bar_rules.lua) of which no unit can be built
-- The block goes through the build blocking of BAR (GG.BuildBlocking.AddBlockedUnit: the units are greyed out in the build menu) when it
-- exists, and always through AllowCommand (build orders of builders and factories).
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

local opt = Spring.GetModOptions().leveleditor
local EDITOR_MODE = (opt == "1" or opt == 1 or opt == true)

local Rules = VFS.Include("luaui/Include/bar_rules.lua", nil, VFS.ZIP_FIRST)
assert(Rules, "bar_rules.lua missing (run install_editor.bat again)")
local techLevel, decode64 = Rules.techLevel, Rules.decode64

local blocked = nil -- running restrictions: unitDefID -> true; nil = none
local blockedTeams = {} -- teams the build blocking of BAR was told about
local pendingPayload = nil

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

-- The units that follow from the payload
local function parse(payload)
	local f = split(payload, ";")
	local set = {}
	local count = 0
	local names = {}
	for _, name in ipairs(split(f[1] or "", ",")) do
		names[name] = true
	end
	local techs = {}
	for _, v in ipairs(split(f[2] or "", ",")) do
		if tonumber(v) then
			techs[tonumber(v)] = true
		end
	end
	for id, ud in pairs(UnitDefs) do
		if names[ud.name] or techs[techLevel(ud)] then
			set[id] = true
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

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
	if blocked and cmdID < 0 and blocked[-cmdID] then
		local ud = UnitDefs[-cmdID]
		say("Not allowed in this level: " .. ((ud and (ud.translatedHumanName or ud.name)) or "?"))
		return false
	end
	return true
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
