-- Indestructible buildings (synchronized part): buildings marked with FX in the Level Editor (and the corridor walls of Tower Defense) take no
-- damage and cannot be reclaimed, captured or self-destructed, in every game mode.
-- In the editor the gadget unit_level_editor.lua fills the table GG.Indestructible; in a finished scenario the game option fixedunits names
-- the buildings (base64url of "name:x,z,x,z|name:..."; older packages call it tdfixed) and they are found at their place a moment after the start.
function gadget:GetInfo()
	return {
		name = "Indestructible buildings",
		desc = "Buildings of a level that take no damage and cannot be taken apart",
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

local Rules = VFS.Include("luaui/Include/bar_rules.lua", nil, VFS.ZIP_FIRST)
assert(Rules, "bar_rules.lua missing (run install_editor.bat again)")

GG.Indestructible = GG.Indestructible or {}
local fixedIds = GG.Indestructible -- unitID -> true: nothing damages, reclaims, captures or self-destructs these units
local fixedList = nil -- { { name, x, z } ... } from the game option, nil = none
local APPLY_FRAMES = { [5] = true, [30] = true, [90] = true } -- the scenario creates its units at the start: looked for several times

local function split(text, sep)
	local out = {}
	for p in tostring(text):gmatch("[^" .. sep .. "]+") do
		out[#out + 1] = p
	end
	return out
end

-- The units of the list that stand at their place get the protection
local function applyFixed()
	for _, f in ipairs(fixedList) do
		for _, id in ipairs(Spring.GetUnitsInCylinder(f[2], f[3], 10)) do
			local defID = Spring.GetUnitDefID(id)
			if defID and UnitDefs[defID].name == f[1] then
				fixedIds[id] = true
				Spring.SetUnitRulesParam(id, "indestructible", 1, { public = true })
			end
		end
	end
end

function gadget:GamePreload()
	local mo = Spring.GetModOptions()
	local opt = (mo.fixedunits and mo.fixedunits ~= "" and mo.fixedunits) or (mo.tdfixed ~= "" and mo.tdfixed) or nil
	if not opt then
		return
	end
	fixedList = {}
	for _, group in ipairs(split(Rules.decode64(opt), "|")) do
		local name, coords = group:match("^([^:]+):(.*)$")
		if name then
			local nums = split(coords, ",")
			for i = 1, #nums - 1, 2 do
				fixedList[#fixedList + 1] = { name, tonumber(nums[i]), tonumber(nums[i + 1]) }
			end
		end
	end
end

function gadget:GameFrame(n)
	if fixedList and APPLY_FRAMES[n] then
		applyFixed()
	end
end

function gadget:UnitDestroyed(unitID)
	fixedIds[unitID] = nil
end

function gadget:UnitPreDamaged(unitID)
	if fixedIds[unitID] then
		return 0, 0
	end
end

function gadget:AllowUnitBuildStep(builderID, builderTeamID, unitID, unitDefID, part)
	if part < 0 and fixedIds[unitID] then
		return false -- reclaiming (also area reclaim)
	end
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	if (cmdID == CMD.RECLAIM or cmdID == CMD.CAPTURE) and cmdParams and #cmdParams == 1 and cmdParams[1] < Game.maxUnits and fixedIds[cmdParams[1]] then
		return false
	end
	if cmdID == CMD.SELFD and fixedIds[unitID] then
		return false
	end
	return true
end

function gadget:Initialize()
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- otherwise the engine registers it and warns
	end
end
