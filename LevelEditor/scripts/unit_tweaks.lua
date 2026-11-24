-- Tweaked units ("clones") of the Level Editor (synchronized part): a placed unit of a normal type gets the changed values of a tweakunits table
-- (health, speed, costs, sight, weapons ...). The unit definitions cannot change in a running game, so the values are set for the single unit.
-- In the editor the widget sends the definitions ("tweak|def|<id>|<name b64>|<base>|<table b64>") and the gadget unit_level_editor.lua calls
-- GG.Tweaks.apply(unitID, id) for every unit it places with a tweak. In a finished scenario the game options ledtweaks ("id,base,name b64,table b64;...")
-- and ledtweakunits ("id:x,z,x,z|id:...") name the definitions and the units; they are found at their place a moment after the start.
-- A tweaked unit carries the public unit rules parameters ledtweak (the id; the widget writes it into the level file) and ledtweakname.
function gadget:GetInfo()
	return {
		name = "Tweaked units",
		desc = "Units of a level with changed values (a tweakunits table applied to single units)",
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

local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST) -- what the gadgets of the editor share (led_gadgets.lua)
local T = VFS.Include("luaui/Include/tweak_rules.lua", nil, VFS.ZIP_FIRST) -- reading a tweakunits table, the fields that can be changed

local defs = {} -- id -> { name, base, tw (the table of the unit) }
local unitTweak = {} -- unitID -> id
local placed = nil -- { { id, x, z, done } ... } from the game option of a scenario, nil = none
local APPLY_FRAMES = { [5] = true, [30] = true, [90] = true } -- the scenario creates its units at the start: looked for several times
local split = G.split

local SENSOR = { sightdistance = "los", airsightdistance = "airLos", radardistance = "radar", sonardistance = "sonar", radardistancejam = "radarJammer",
	seismicdistance = "seismic" }
local MOVE = { speed = "maxSpeed", maxacc = "accRate", maxdec = "decRate", turnrate = "turnRate" }
local COST = { metalcost = "metalCost", energycost = "energyCost", buildtime = "buildTime" }
local WSTATE = { range = "range", reloadtime = "reloadTime", burst = "burst", burstrate = "burstRate", projectiles = "projectiles" }
local WDAMAGE = { edgeeffectiveness = "edgeEffectiveness", impulsefactor = "impulseFactor" }

-- the data of the move type of a unit (ground, hover and ships; gunships; planes)
local function setMove(unitID, ud, key, value)
	local mc = Spring.MoveCtrl
	local set = mc and (ud.canFly and (ud.hoverAttack and mc.SetGunshipMoveTypeData or mc.SetAirMoveTypeData) or mc.SetGroundMoveTypeData)
	if set and (ud.speed or 0) > 0 then
		pcall(set, unitID, key, value)
		if key == "maxSpeed" then
			pcall(set, unitID, "maxWantedSpeed", value)
		end
	end
end

-- an accuracy of a unit definition (an angle in 1/65536 of a turn) as the engine keeps it
local function spread(value)
	return math.sin(value * math.pi / 0xafff)
end

-- Sets the values of the tweak for one unit of the base type
local function applyValues(unitID, def)
	local defID = Spring.GetUnitDefID(unitID)
	local ud = defID and UnitDefs[defID]
	if not ud or ud.name ~= def.base then
		return false
	end
	local tw = def.tw
	local ranges = {} -- weapon number -> new range
	T.walk(def.base, tw, ud, WeaponDefs, {
		unit = function(key, value)
			if key == "health" then
				Spring.SetUnitMaxHealth(unitID, value)
				Spring.SetUnitHealth(unitID, value)
			elseif MOVE[key] then
				setMove(unitID, ud, MOVE[key], value)
			elseif COST[key] then
				Spring.SetUnitCosts(unitID, { [COST[key]] = value })
			elseif SENSOR[key] then
				pcall(Spring.SetUnitSensorRadius, unitID, SENSOR[key], value)
				if key == "sightdistance" and tw.airsightdistance == nil then
					pcall(Spring.SetUnitSensorRadius, unitID, "airLos", value * 1.5) -- (the engine's default for the sight into the air)
				end
			elseif key == "workertime" then
				Spring.SetUnitBuildSpeed(unitID, value, value, value, value, value)
			elseif key == "metalmake" then
				Spring.SetUnitResourcing(unitID, "umm", value)
			elseif key == "energymake" then
				Spring.SetUnitResourcing(unitID, "ume", value)
			elseif key == "mass" then
				Spring.SetUnitMass(unitID, value)
			elseif key == "stealth" then
				Spring.SetUnitStealth(unitID, value)
			elseif key == "sonarstealth" then
				Spring.SetUnitSonarStealth(unitID, value)
			end
		end,
		weapon = function(idx, wname, key, value)
			for _, i in ipairs(idx) do
				if WSTATE[key] then
					Spring.SetUnitWeaponState(unitID, i, WSTATE[key], value)
					if key == "range" then
						ranges[i] = value
					end
				elseif key == "weaponvelocity" then
					Spring.SetUnitWeaponState(unitID, i, "projectileSpeed", value / 30) -- (per frame)
				elseif key == "accuracy" or key == "sprayangle" then
					Spring.SetUnitWeaponState(unitID, i, key == "accuracy" and "accuracy" or "sprayAngle", spread(value))
				elseif key == "areaofeffect" then
					Spring.SetUnitWeaponDamages(unitID, i, "damageAreaOfEffect", value * 0.5) -- (the definition holds the diameter)
				elseif WDAMAGE[key] then
					Spring.SetUnitWeaponDamages(unitID, i, WDAMAGE[key], value)
				end
			end
		end,
		-- the damage per armor class: a named class gets its value; "default" goes to every class that had the default damage before
		damage = function(idx, wname, damages)
			for _, i in ipairs(idx) do
				local wd = WeaponDefs[ud.weapons[i].weaponDef]
				local old = wd and wd.damages or {}
				local oldDefault = old[0]
				local new = {}
				for index, name in pairs(Game.armorTypes or {}) do
					if type(index) == "number" and type(name) == "string" then
						local v = damages[name:lower()]
						if v == nil and damages.default ~= nil and (name:lower() == "default" or old[index] == oldDefault) then
							v = damages.default
						end
						if v ~= nil then
							new[index] = v
						end
					end
				end
				if next(new) ~= nil then
					Spring.SetUnitWeaponDamages(unitID, i, new)
				end
			end
		end,
		ignored = function() end,
		error = function() end,
	})
	if next(ranges) ~= nil then
		-- the range the unit moves into for an attack: the longest of its weapons
		local maxRange = 0
		for i, w in ipairs(ud.weapons or {}) do
			local wd = WeaponDefs[w.weaponDef]
			if wd and not wd.isShield then
				maxRange = math.max(maxRange, ranges[i] or wd.range or 0)
			end
		end
		if maxRange > 0 then
			Spring.SetUnitMaxRange(unitID, maxRange)
		end
	end
	return true
end

-- The unit becomes the tweaked unit <id> (the definition may arrive later: then the values are set when it comes)
local function apply(unitID, id)
	if not (unitID and id and id ~= "" and Spring.ValidUnitID(unitID)) then
		return false
	end
	unitTweak[unitID] = id
	Spring.SetUnitRulesParam(unitID, "ledtweak", id, { public = true })
	local def = defs[id]
	if def then
		Spring.SetUnitRulesParam(unitID, "ledtweakname", def.name, { public = true })
		return applyValues(unitID, def)
	end
	return false
end

-- A definition: nil and the reason when the text is no tweak of one unit
local function define(id, name, base, text)
	if not (id and id:match("^[%w_]+$") and base and UnitDefNames[base]) then
		return nil, "unknown unit " .. tostring(base)
	end
	local data, err = T.parse(text or "")
	if not data then
		return nil, err
	end
	local tw = data[base]
	if type(tw) ~= "table" then
		return nil, "the table has no entry for " .. base
	end
	local known = defs[id] ~= nil
	defs[id] = { name = (name and name ~= "") and name or id, base = base, tw = tw }
	if not known then
		-- units that were waiting for this definition
		for unitID, uid in pairs(unitTweak) do
			if uid == id and Spring.ValidUnitID(unitID) then
				Spring.SetUnitRulesParam(unitID, "ledtweakname", defs[id].name, { public = true })
				applyValues(unitID, defs[id])
			end
		end
	else
		for unitID, uid in pairs(unitTweak) do
			if uid == id and Spring.ValidUnitID(unitID) then
				Spring.SetUnitRulesParam(unitID, "ledtweakname", defs[id].name, { public = true })
			end
		end
	end
	return defs[id]
end

GG.Tweaks = { apply = apply, define = define, defs = defs }

local MESSAGES = {
	-- tweak|def|<id>|<name b64>|<base>|<table b64>
	def = function(payload)
		local p = split(payload, "|")
		local _, err = define(p[1], T.decode64(p[2] or ""), p[3], T.decode64(p[4] or "") or "")
		if err then
			Spring.Echo("Tweaked units: " .. tostring(p[1]) .. " not usable: " .. tostring(err))
		end
	end,
}

function gadget:RecvLuaMsg(msg, playerID)
	return G.handleMessage("tweak", MESSAGES, msg, playerID)
end

function gadget:GamePreload()
	local text = G.option("ledtweaks")
	if not text then
		return
	end
	for _, entry in ipairs(split(text, ";")) do
		local p = split(entry, ",")
		if p[1] and p[1] ~= "" then
			local _, err = define(p[1], T.decode64(p[3] or ""), p[2], T.decode64(p[4] or "") or "")
			if err then
				Spring.Echo("Tweaked units: " .. tostring(p[1]) .. " not usable: " .. tostring(err))
			end
		end
	end
	placed = {}
	for _, group in ipairs(split(G.option("ledtweakunits") or "", "|")) do
		local id, coords = group:match("^([^:]+):(.*)$")
		if id then
			local nums = split(coords, ",")
			for i = 1, #nums - 1, 2 do
				placed[#placed + 1] = { id = id, x = tonumber(nums[i]), z = tonumber(nums[i + 1]) }
			end
		end
	end
end

-- The units of the scenario's list that stand at their place become tweaked units (each entry once)
local function applyPlaced()
	for _, p in ipairs(placed) do
		local def = defs[p.id]
		if def and not p.done and p.x and p.z then
			for _, unitID in ipairs(Spring.GetUnitsInCylinder(p.x, p.z, 10)) do
				local defID = Spring.GetUnitDefID(unitID)
				if defID and UnitDefs[defID].name == def.base and not unitTweak[unitID] then
					apply(unitID, p.id)
					p.done = true
					break
				end
			end
		end
	end
end

function gadget:GameFrame(n)
	if placed and APPLY_FRAMES[n] then
		applyPlaced()
	end
end

function gadget:UnitDestroyed(unitID)
	unitTweak[unitID] = nil
end
