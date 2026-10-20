-- Tower Defense waves (synchronized part): spawns waves of land units at the spawn point, sends them along the path
-- to the goal, pays metal and energy for every kill and ends the level (won: all waves beaten, lost: too many got through).
-- Configuration: from the Level Editor with the message "tdw|start|<payload>" (stop: "tdw|stop"), or from the game option
-- tdconfig (same payload) for a finished scenario. Payload, fields separated by ";":
--   enemyTeam;playerTeam;spawnX;spawnZ;goalX;goalZ;allowedLeaks;path;waves;banned;bannedTech;restrict;fog
--   path  = "x,z/x,z/..." (waypoints between spawn and goal) or "-"
--   waves = "factions,types,techs,count,gap,hp/..." factions e.g. armcor (arm, cor, leg), types e.g. vb (v = vehicles, h = hovercraft,
--           b = bots), techs e.g. 12 (1-3), count of units, gap = seconds after the previous wave (first wave: after
--           the start), hp = health in percent. The units are chosen at random among all that match.
--   banned = "name,name,..." or "-": units (towers) the player must not build while the game runs
--   bannedTech = "1,3" or "-": tech levels of which the player may build no structure; restrict = "towers" | "economy":
--           the player may build only towers ("towers") or towers and economy structures ("economy"); fog = 1 | 0: fog of war
--           (radars may be built; in a finished scenario the whole map is visible without fog)
--   path = the waypoints between spawn and goal, already in the order the units walk them
-- State for the display: game rules parameters tdState, tdWave, tdWaves, tdLeaks, tdMaxLeaks, tdKilled, tdAlive.
function gadget:GetInfo()
	return {
		name = "Tower Defense waves",
		desc = "Spawns waves of enemies for tower defense levels",
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

local FPS = 30
local SPAWN_INTERVAL = 12 -- frames between two units of a wave (they walk off one after the other)
local GOAL_RADIUS = 120 -- a unit this close to the goal got through
local MAX_UNITS = 600 -- of all waves at the same time

local opt = Spring.GetModOptions().leveleditor
local EDITOR_MODE = (opt == "1" or opt == 1 or opt == true)

local td = nil -- running game: nil = none
local alive = {} -- unitID -> { reward factor }
local START_FRAME = 30 -- finished scenario: the waves start this frame (the units of the scenario exist by then)
local pendingCfg = nil -- configuration waiting for the start
local fixedList = nil -- { { name, x, z } ... } units that stay indestructible
local fixedIds = {} -- unitID -> true: nothing damages these units
local applyFixed -- (defined below)

local function say(text)
	if Spring.SendMessage then
		Spring.SendMessage("[Tower Defense] " .. text)
	else
		Spring.Echo("[Tower Defense] " .. text)
	end
end

local function split(text, sep)
	local out = {}
	for p in tostring(text):gmatch("[^" .. sep .. "]+") do
		out[#out + 1] = p
	end
	return out
end

-- Payload -> configuration table (nil when unusable)
local function parse(payload)
	local f = {}
	for p in (tostring(payload) .. ";"):gmatch("([^;]*);") do
		f[#f + 1] = p
	end
	local cfg = {
		enemy = tonumber(f[1]), player = tonumber(f[2]),
		spawn = { tonumber(f[3]), tonumber(f[4]) }, goal = { tonumber(f[5]), tonumber(f[6]) },
		leaks = tonumber(f[7]) or 0, path = {}, waves = {},
	}
	if not (cfg.enemy and cfg.player and cfg.spawn[1] and cfg.spawn[2] and cfg.goal[1] and cfg.goal[2]) then
		return nil
	end
	if f[8] and f[8] ~= "-" then
		for _, pt in ipairs(split(f[8], "/")) do
			local x, z = pt:match("^(-?[%d%.]+),(-?[%d%.]+)$")
			if x then
				cfg.path[#cfg.path + 1] = { tonumber(x), tonumber(z) }
			end
		end
	end
	for _, w in ipairs(split(f[9] or "", "/")) do
		local fac, kind, tech, count, gap, hp = w:match("^(%a+),(%a+),(%d+),(%d+),(%d+),(%d+)$")
		if fac then
			cfg.waves[#cfg.waves + 1] = { fac = fac, kind = kind, tech = tech, count = tonumber(count), gap = tonumber(gap), hp = tonumber(hp) }
		end
	end
	if #cfg.waves == 0 then
		return nil
	end
	cfg.banned = {}
	for _, name in ipairs(split(f[10] or "", ",")) do
		local ud = UnitDefNames[name]
		if ud then
			cfg.banned[ud.id] = true
		end
	end
	cfg.bannedTech = {}
	for _, v in ipairs(split(f[11] or "", ",")) do
		if tonumber(v) then
			cfg.bannedTech[tonumber(v)] = true
		end
	end
	cfg.restrict = f[12] == "economy" and "economy" or "towers"
	cfg.fog = f[13] == "1"
	return cfg
end

-- True when at least one weapon can hit the ground (pure anti-air units are of no use against walking enemies)
-- BAR files some Epic units under a lower tech level (Epic Grunt: T1, Epic Skater: T2): every Epic unit counts as T3
local function techLevel(ud)
	local t = tonumber(ud.customParams and ud.customParams.techlevel) or 1
	if t < 3 then
		local human = ud.translatedHumanName or ud.humanName or ""
		local mv = ud.moveDef and ud.moveDef.name or ""
		if human:find("^Epic") or tostring(mv):find("epic", 1, true) then
			return 3
		end
	end
	return t
end

local function hitsGround(ud)
	for _, w in ipairs(ud.weapons) do
		local wd = WeaponDefs[w.weaponDef]
		if wd and wd.canAttackGround then
			return true
		end
	end
	return false
end

-- Land units that walk: mobile, armed, not a builder, not a ship or an aircraft (same rules as Generate in the editor),
-- and not pure anti-air.
-- facs = "armcor", kinds = "vbh" (vehicles, bots, hovercraft), techs = "12": every unit that fits one choice of each group
local function pool(facs, kinds, techs)
	local out = {}
	for name, ud in pairs(UnitDefNames) do
		local cp = ud.customParams or {}
		local fac = name:sub(1, 3)
		if facs:find(fac, 1, true) and not name:find("scav") and not name:find("decom") and not name:find("dummy")
			and not name:find("drone") and not cp.iscommander and not cp.isdrone then
			local mc = ud.modCategories or {}
			local tech = tostring(techLevel(ud))
			if ud.canMove and not ud.canFly and not ud.isBuilder and not ud.isFactory and ud.speed and ud.speed > 0
				and #ud.weapons > 0 and not (mc.ship or mc.underwater) and techs:find(tech, 1, true) and hitsGround(ud) then
				-- the movement class tells bots (bot2, bot3 ...), vehicles (tank2, atank3 ...) and hovercraft (hover2 ...) apart
				local move = ud.moveDef and ud.moveDef.name or ""
				local bot, hover = move:find("bot") ~= nil, move:find("hover") ~= nil
				if (bot and kinds:find("b", 1, true)) or (hover and kinds:find("h", 1, true)) or (not bot and not hover and kinds:find("v", 1, true)) then
					out[#out + 1] = ud
				end
			end
		end
	end
	table.sort(out, function(a, b) return a.name < b.name end)
	return out
end

local function publish()
	if not td then
		Spring.SetGameRulesParam("tdState", "")
		return
	end
	local n = 0
	for _ in pairs(alive) do
		n = n + 1
	end
	Spring.SetGameRulesParam("tdState", td.state)
	Spring.SetGameRulesParam("tdWave", td.wave)
	Spring.SetGameRulesParam("tdWaves", #td.cfg.waves)
	Spring.SetGameRulesParam("tdLeaks", td.leaked)
	Spring.SetGameRulesParam("tdMaxLeaks", td.cfg.leaks)
	Spring.SetGameRulesParam("tdKilled", td.killed)
	Spring.SetGameRulesParam("tdAlive", n)
end

local function finish(won)
	td.state = won and "won" or "lost"
	publish()
	say(won and "All waves beaten: level won!" or ("Lost: " .. td.leaked .. " enemies got through (allowed: " .. td.cfg.leaks .. ")"))
	if not EDITOR_MODE then
		-- finished scenario: the game ends; the winner is the ally team of the player (or of the enemy)
		local _, _, _, _, _, ally = Spring.GetTeamInfo(won and td.cfg.player or td.cfg.enemy, false)
		Spring.GameOver({ ally })
	end
end

local function start(cfg)
	for id in pairs(alive) do
		if Spring.ValidUnitID(id) then
			Spring.DestroyUnit(id, false, true)
		end
	end
	alive = {}
	-- no commander for the player: the builders are placed by the level (the editor brings the state before Play back on Stop)
	for _, id in ipairs(Spring.GetTeamUnits(cfg.player)) do
		local cp = UnitDefs[Spring.GetUnitDefID(id)].customParams or {}
		if cp.iscommander then
			Spring.DestroyUnit(id, false, true)
		end
	end
	if not EDITOR_MODE then
		-- finished scenario: without fog of war the player sees the whole map (the editor always does, it needs it to save the units)
		local _, _, _, _, _, ally = Spring.GetTeamInfo(cfg.player, false)
		Spring.SetGlobalLos(ally, not cfg.fog)
	end
	local now = Spring.GetGameFrame()
	td = { cfg = cfg, state = "running", wave = 0, leaked = 0, killed = 0, queue = {}, nextWave = now + cfg.waves[1].gap * FPS, nextSpawn = 0 }
	publish()
	say(string.format("Started: %d waves, the first one in %d s, %d enemies may get through.", #cfg.waves, cfg.waves[1].gap, cfg.leaks))
end

local function stop()
	if td then
		for id in pairs(alive) do
			if Spring.ValidUnitID(id) then
				Spring.DestroyUnit(id, false, true)
			end
		end
		alive = {}
		td = nil
		publish()
		say("Stopped.")
	end
end

-- Next wave: picks the units (random among the matching ones) and puts them in the spawn queue
local function launchWave(n)
	local w = td.cfg.waves[td.wave + 1]
	td.wave = td.wave + 1
	local list = pool(w.fac, w.kind, w.tech)
	if #list == 0 then
		say(string.format("Wave %d: no matching units (factions %s, types %s, tech %s), wave skipped.", td.wave, w.fac, w.kind, w.tech))
	else
		for _ = 1, w.count do
			td.queue[#td.queue + 1] = { ud = list[math.random(#list)], hp = w.hp / 100 }
		end
		say(string.format("Wave %d of %d: %d units", td.wave, #td.cfg.waves, w.count))
	end
	local nxt = td.cfg.waves[td.wave + 1]
	td.nextWave = nxt and (n + nxt.gap * FPS) or nil
	publish()
end

local function spawnOne(entry)
	local c = td.cfg
	local ang = math.random() * 2 * math.pi
	local x, z = c.spawn[1] + math.cos(ang) * 24, c.spawn[2] + math.sin(ang) * 24
	local id = Spring.CreateUnit(entry.ud.name, x, Spring.GetGroundHeight(x, z), z, math.random(0, 3), c.enemy)
	if not id then
		return
	end
	if entry.hp ~= 1 then
		local _, maxHp = Spring.GetUnitHealth(id)
		if maxHp then
			Spring.SetUnitMaxHealth(id, maxHp * entry.hp)
			Spring.SetUnitHealth(id, maxHp * entry.hp)
		end
	end
	-- along the waypoints of the path to the goal; they march on and shoot on the way
	local first = true
	local function go(px, pz)
		Spring.GiveOrderToUnit(id, CMD.MOVE, { px, Spring.GetGroundHeight(px, pz), pz }, first and 0 or { "shift" })
		first = false
	end
	for _, p in ipairs(c.path) do
		go(p[1], p[2])
	end
	go(c.goal[1], c.goal[2])
	Spring.SetUnitRulesParam(id, "tdwave", 1, { public = true }) -- the editor does not save these units
	alive[id] = true
end

function gadget:GameFrame(n)
	if pendingCfg and n >= START_FRAME then
		local cfg = pendingCfg
		pendingCfg = nil
		start(cfg)
	end
	if fixedList and (n == 5 or n == 30 or n == 90) then
		applyFixed()
	end
	if not td or td.state ~= "running" then
		return
	end
	if td.nextWave and n >= td.nextWave then
		launchWave(n)
	end
	if #td.queue > 0 and n >= td.nextSpawn then
		local alone = 0
		for _ in pairs(alive) do
			alone = alone + 1
		end
		if alone < MAX_UNITS then
			spawnOne(table.remove(td.queue, 1))
			td.nextSpawn = n + SPAWN_INTERVAL
			publish()
		end
	end
	if n % 10 ~= 0 then
		return
	end
	-- got through: close to the goal
	local gx, gz = td.cfg.goal[1], td.cfg.goal[2]
	for id in pairs(alive) do
		local x, _, z = Spring.GetUnitPosition(id)
		if x and (x - gx) ^ 2 + (z - gz) ^ 2 <= GOAL_RADIUS ^ 2 then
			alive[id] = nil
			td.leaked = td.leaked + 1
			Spring.DestroyUnit(id, false, true)
			say(string.format("%d of %d enemies got through.", td.leaked, td.cfg.leaks))
			publish()
		end
	end
	if td.leaked > td.cfg.leaks then
		finish(false)
		return
	end
	if not td.nextWave and #td.queue == 0 and next(alive) == nil then
		finish(true)
	end
end

-- Payment: the cost of the unit in metal and energy goes to the player
function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID)
	fixedIds[unitID] = nil
	if td and alive[unitID] then
		alive[unitID] = nil
		if td.state == "running" then
			local ud = UnitDefs[unitDefID]
			td.killed = td.killed + 1
			Spring.AddTeamResource(td.cfg.player, "metal", ud.metalCost or 0)
			Spring.AddTeamResource(td.cfg.player, "energy", ud.energyCost or 0)
			publish()
		end
	end
end

-- Kind of a structure for the build restriction (same sorting as the catalog of the editor): "economy" = metal and energy
-- structures (extractors, solar, wind, geothermal, fusion, storage, converters), "tower" = armed structure, "radar", nil = the rest
local function buildClass(ud)
	local cp = ud.customParams or {}
	if ud.isFactory then
		return nil
	end
	local ug = cp.unitgroup
	if ug == "energy" or ug == "metal" or (tonumber(ud.extractsMetal) or 0) > 0 then
		return "economy"
	elseif #ud.weapons > 0 and ug ~= "explo" then
		return "tower"
	elseif (tonumber(ud.radarDistance) or 0) > 0 then
		return "radar"
	end
	return nil
end

-- Build orders of the player that are not allowed are refused while the game runs: forbidden towers (red X), tech levels
-- without structures, and the restriction to towers (and economy). Units from factories are not restricted.
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
	if not (td and cmdID < 0 and teamID == td.cfg.player) then
		return true
	end
	local cfg, ud = td.cfg, UnitDefs[-cmdID]
	local why
	if cfg.banned[-cmdID] then
		why = "forbidden"
	elseif not ud.canMove then
		if cfg.bannedTech[techLevel(ud)] then
			why = "tech level " .. techLevel(ud) .. " is forbidden"
		else
			local cls = buildClass(ud)
			if not (cls == "tower" or (cls == "economy" and cfg.restrict == "economy") or (cls == "radar" and cfg.fog)) then
				why = cls == "radar" and "no radars without fog of war" or (cfg.restrict == "economy" and "only towers and economy structures may be built" or "only towers may be built")
			end
		end
	end
	if why then
		say("Not allowed in this level: " .. (ud.translatedHumanName or ud.name) .. " (" .. why .. ")")
		return false
	end
	return true
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 4) ~= "tdw|" then
		return
	end
	if not (Spring.IsCheatingEnabled() or EDITOR_MODE) then
		return true
	end
	local cmd, payload = msg:match("^tdw|(%a+)|?(.*)$")
	if cmd == "start" then
		local cfg = parse(payload)
		if cfg then
			start(cfg)
		else
			say("Cannot start: set spawn point, goal and at least one wave first.")
		end
	elseif cmd == "stop" then
		stop()
	end
	return true
end

-- Finished scenario: the configuration is in the game option tdconfig and the waves start with the game
function gadget:Initialize()
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- build orders: otherwise the engine registers it and warns
	end
	Spring.SetGameRulesParam("tdState", "")
end

-- Finished scenario: the settings come in the game options tdconfig (the payload as base64url) and tdfixed (indestructible units
-- as base64url text "name:x,z,x,z|name:..."); the waves start a moment after the game start, when the units of the scenario exist
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64 = {}
for i = 1, #ALPHA do
	B64[ALPHA:byte(i)] = i - 1
end

local function decode64(s)
	s = (s:gsub("-", "+")):gsub("_", "/")
	local out, acc, bits = {}, 0, 0
	for i = 1, #s do
		local v = B64[s:byte(i)]
		if v then
			acc, bits = acc * 64 + v, bits + 6
			if bits >= 8 then
				bits = bits - 8
				local b = math.floor(acc / 2 ^ bits)
				out[#out + 1] = string.char(b)
				acc = acc - b * 2 ^ bits
			end
		end
	end
	return table.concat(out)
end

function gadget:GamePreload()
	local mo = Spring.GetModOptions()
	if mo.tdconfig and mo.tdconfig ~= "" then
		pendingCfg = parse(decode64(mo.tdconfig))
	end
	if mo.tdfixed and mo.tdfixed ~= "" then
		fixedList = {}
		for _, group in ipairs(split(decode64(mo.tdfixed), "|")) do
			local name, coords = group:match("^([^:]+):(.*)$")
			if name then
				local nums = split(coords, ",")
				for i = 1, #nums - 1, 2 do
					fixedList[#fixedList + 1] = { name, tonumber(nums[i]), tonumber(nums[i + 1]) }
				end
			end
		end
	end
end

-- The units of the list that stand at their place get the protection (repeated for a while, the scenario creates its units at the start)
applyFixed = function()
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

function gadget:UnitPreDamaged(unitID)
	if fixedIds[unitID] then
		return 0, 0
	end
end
