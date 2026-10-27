-- Tower Defense waves (synchronized part): spawns waves of land units at the spawn point, sends them along the path
-- to the goal, pays metal and energy for every kill and ends the level (won: all waves beaten, lost: too many got through).
-- Configuration: from the Level Editor with the message "tdw|start|<payload>" (stop: "tdw|stop"), or from the game option
-- tdconfig (same payload) for a finished scenario. Payload, fields separated by ";":
--   enemyTeam;playerTeam;spawnX;spawnZ;goalX;goalZ;allowedLeaks;path;waves;restrict;fog;metal;energy
--   path  = "x,z/x,z/..." (waypoints between spawn and goal) or "-"
--   waves = "factions,types,techs,count,gap,hp/..." factions e.g. armcor (arm, cor, leg), types e.g. vb (v = vehicles, h = hovercraft,
--           b = bots), techs e.g. 12 (1-3), count of units, gap = seconds after the previous wave (first wave: after
--           the start), hp = health in percent. The units are chosen at random among all that match.
--   restrict = "towers" | "economy": the player may build only towers ("towers") or towers and economy structures ("economy"); fog = 1 | 0: fog of war
--           (radars may be built; in a finished scenario the whole map is visible without fog)
--   path = the waypoints between spawn and goal, already in the order the units walk them
--   metal, energy (optional): start resources of the player; only the editor uses them (it sets them at the start of the test, a finished
--           scenario gets them from its game options)
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
local STUCK_FRAMES = 30 * 30 -- a unit that has moved less than STUCK_DISTANCE in this time is stuck: it gets its route again
local STUCK_DISTANCE = 64
local STUCK_TRIES = 2 -- after this many new routes without moving it is removed (it counts neither as got through nor as killed)

local opt = Spring.GetModOptions().leveleditor
local EDITOR_MODE = (opt == "1" or opt == 1 or opt == true)

-- rules about unit definitions: shared with the editor (shared/bar_rules.lua)
local Rules = VFS.Include("luaui/Include/bar_rules.lua", nil, VFS.ZIP_FIRST)
assert(Rules, "bar_rules.lua missing (run install_editor.bat again)")
local techLevel, buildClass, hitsGround = Rules.techLevel, Rules.buildClass, Rules.hitsGround

local td = nil -- running game: nil = none
local alive = {} -- unitID -> { x, z, frame: where it stood at the last check for being stuck, tries: new routes given }
local START_FRAME = 30 -- finished scenario: the waves start this frame (the units of the scenario exist by then)
local pendingCfg = nil -- configuration waiting for the start

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
	cfg.restrict = f[10] == "economy" and "economy" or "towers"
	cfg.fog = f[11] == "1"
	cfg.metal, cfg.energy = tonumber(f[12]), tonumber(f[13])
	return cfg
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

-- The teams the build rule holds for: every human team of the player's ally team (several humans of a LAN game, Copilots included)
local function playerTeams(cfg)
	local set = {}
	local ally = select(6, Spring.GetTeamInfo(cfg.player, false))
	for _, team in ipairs(Spring.GetTeamList(ally) or {}) do
		local isAI = select(4, Spring.GetTeamInfo(team, false))
		if not isAI or team == cfg.player then
			set[team] = true
		end
	end
	return set
end

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
	Spring.SetGameRulesParam("tdPlayer", td.cfg.player) -- the editor does not refill the resources of this team during the test
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
	td = { resFrame = (EDITOR_MODE and cfg.metal and cfg.energy) and now + 3 or nil, cfg = cfg, state = "running", wave = 0, leaked = 0, killed = 0, queue = {}, nextWave = now + cfg.waves[1].gap * FPS, nextSpawn = 0,
		teams = playerTeams(cfg) }
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

-- The orders of a wave unit: along the waypoints from number `from` on to the goal; they march on and shoot on the way
local function giveRoute(id, from)
	local c = td.cfg
	local first = true
	local function go(px, pz)
		Spring.GiveOrderToUnit(id, CMD.MOVE, { px, Spring.GetGroundHeight(px, pz), pz }, first and 0 or { "shift" })
		first = false
	end
	for i = from, #c.path do
		go(c.path[i][1], c.path[i][2])
	end
	go(c.goal[1], c.goal[2])
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
	giveRoute(id, 1)
	Spring.SetUnitRulesParam(id, "led_nosave", 1, { public = true }) -- a unit of the running game: the editor does not save it
	alive[id] = { x = x, z = z, frame = Spring.GetGameFrame(), tries = 0 }
end

-- A unit that has not moved for a while gets its route again (from the nearest waypoint on); after STUCK_TRIES it is removed
local function checkStuck(n)
	for id, a in pairs(alive) do
		if n - a.frame >= STUCK_FRAMES then
			local x, _, z = Spring.GetUnitPosition(id)
			if x then
				if (x - a.x) ^ 2 + (z - a.z) ^ 2 >= STUCK_DISTANCE ^ 2 then
					a.tries = 0
				elseif a.tries < STUCK_TRIES then
					a.tries = a.tries + 1
					local best, bd = #td.cfg.path + 1, (x - td.cfg.goal[1]) ^ 2 + (z - td.cfg.goal[2]) ^ 2
					for i, p in ipairs(td.cfg.path) do
						local d = (x - p[1]) ^ 2 + (z - p[2]) ^ 2
						if d < bd then
							best, bd = i, d
						end
					end
					giveRoute(id, best)
				else
					alive[id] = nil
					Spring.DestroyUnit(id, false, true)
					say("An enemy was stuck and has been removed (it counts neither as got through nor as killed).")
					publish()
				end
				if alive[id] then
					a.x, a.z, a.frame = x, z, n
				end
			end
		end
	end
end

function gadget:GameFrame(n)
	if td and td.resFrame and n >= td.resFrame then
		-- test in the editor: the player has the start resources of the level (the editor gives everybody a huge amount otherwise; it leaves
		-- the player alone while the test runs and starts again after Stop). A few frames after the start: the removed commander took its
		-- storage with it only now.
		td.resFrame = nil
		local c = td.cfg
		Spring.SetTeamResource(c.player, "ms", math.max(1000, c.metal))
		Spring.SetTeamResource(c.player, "es", math.max(1000, c.energy))
		Spring.SetTeamResource(c.player, "m", c.metal)
		Spring.SetTeamResource(c.player, "e", c.energy)
	end
	if pendingCfg and n >= START_FRAME then
		local cfg = pendingCfg
		pendingCfg = nil
		start(cfg)
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
	checkStuck(n)
	if not td.nextWave and #td.queue == 0 and next(alive) == nil then
		finish(true)
	end
end

-- Payment: the cost of the unit in metal and energy goes to the player
function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID)
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

local MESSAGE_GAP = 5 * FPS -- frames between two messages of the same unit type to the same team
local lastMessage = {} -- team -> unitDefID -> frame of the last message

-- Build orders of the players that are not allowed are refused while the game runs: the restriction to towers (and economy; the units
-- that are forbidden in the level are refused by unit_restrictions.lua, the indestructible buildings are protected by unit_indestructible.lua).
-- Units from factories are not restricted. The message goes only to the team of the order, at most once per unit type every few seconds.
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	local defID = td and td.state == "running" and td.teams[teamID] and builtDef(cmdID, cmdParams)
	if not defID then
		return true
	end
	local cfg, ud = td.cfg, UnitDefs[defID]
	local why
	if ud and not ud.canMove then
		local cls = buildClass(ud)
		if not (cls == "tower" or (cls == "economy" and cfg.restrict == "economy") or (cls == "radar" and cfg.fog)) then
			why = cls == "radar" and "no radars without fog of war" or (cfg.restrict == "economy" and "only towers and economy structures may be built" or "only towers may be built")
		end
	end
	if why then
		local n, seen = Spring.GetGameFrame(), lastMessage[teamID] or {}
		lastMessage[teamID] = seen
		if not seen[defID] or n - seen[defID] >= MESSAGE_GAP then
			seen[defID] = n
			local text = "[Tower Defense] Not allowed in this level: " .. (ud.translatedHumanName or ud.name) .. " (" .. why .. ")"
			if Spring.SendMessageToTeam then Spring.SendMessageToTeam(teamID, text) else Spring.Echo(text) end
		end
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

-- Finished scenario: the settings come in the game option tdconfig (the payload as base64url); the waves start a moment after the game
-- start, when the units of the scenario exist
local decode64 = Rules.decode64

function gadget:GamePreload()
	local mo = Spring.GetModOptions()
	if mo.tdconfig and mo.tdconfig ~= "" then
		pendingCfg = parse(decode64(mo.tdconfig))
	end
end
