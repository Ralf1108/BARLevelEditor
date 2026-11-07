-- Evolution (synchronized part), a game mode of LAN Play on any map: the room's button Evolution sets the game option lanevolution=1. Every team
-- that starts with a commander gets one weak unit instead (stage 1) and nothing else. Kills give points; with enough points the unit is replaced by a
-- unit of the next stage (10 stages, the last one a big tier 3 unit), of a random faction each time. A destroyed unit comes back after 5 s at a random
-- place of the map, one stage lower. Wild units (stage 1 units of Gaia with little health) stand around the map; they only shoot back. The game does not
-- end (unlimited lives). Computer players (teams without a human) are steered by this gadget: their unit attacks only enemies of its own stage or higher
-- and otherwise only shoots back; the orders of the AI itself are dropped.
-- Points: from stage s to s + 1 it takes need(s) = round(3 * 1.6^(s - 1)) points (3, 5, 8, 12, 20, 31, 50, 81, 129). A wild unit gives 1 point; a
-- player unit of stage v gives need(v), times (1 + v - k) when it is above the stage k of the killer.
-- State for the display: game rules parameters evoState ("" or "running"), evoTeams (the player teams); team rules parameters evoStage, evoXp, evoNeed
-- (points to the next stage, 0 on the last), evoKills, evoDeaths, evoUnit (the unit, 0 = none), evoSpawn (counts the spawns: the unsynced part points the
-- camera at a new unit), evoName (unit definition name; shown with its name from NAMES).
function gadget:GetInfo()
	return {
		name = "Evolution",
		desc = "LAN Play game mode: one unit per team that evolves with every kill",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local opt = (Spring.GetModOptions() or {}).lanevolution
if opt ~= "1" and opt ~= 1 then
	return false -- not an Evolution game: the gadget is not loaded
end

-- The names of the units of the ladders (the translated names are not known in every Lua state of the game)
local NAMES = {
	armpw = "Pawn", armflash = "Blitz", armwar = "Centurion", armzeus = "Welder", armbull = "Bull", armmar = "Marauder", armmeatball = "Meatball",
	armraz = "Razorback", armthor = "Thor", armbanth = "Titan",
	corak = "Grunt", corgator = "Incisor", corraid = "Brute", corpyro = "Fiend", correap = "Tiger", corcan = "Sumo", corshiva = "Shiva",
	corkarg = "Karganeth", cordemon = "Demon", corkorg = "Juggernaut",
	leghades = "Alaris", legcen = "Phobos", legkark = "Karkinos", leggat = "Decurion", legjav = "Javelin", legaheattank = "Prometheus", leginc = "Incinerator",
	legkeres = "Keres", legeshotgunmech = "Praetorian", legeheatraymech = "Sol Invictus",
}

if not gadgetHandler:IsSyncedCode() then
	-- ---------------------------------------------------------------- unsynced: the score lines, the selection and the camera
	local lastUnit, lastSpawn = nil, nil

	function gadget:Update()
		if (Spring.GetGameRulesParam("evoState") or "") == "" or Spring.GetSpectatingState() then
			return
		end
		local team = Spring.GetMyTeamID()
		local id = Spring.GetTeamRulesParam(team, "evoUnit")
		if id and id > 0 and id ~= lastUnit then
			lastUnit = id
			Spring.SelectUnitArray({ id }) -- the new unit (evolved or back) is selected: no new click needed
		end
		local spawn = Spring.GetTeamRulesParam(team, "evoSpawn")
		if spawn and spawn ~= lastSpawn then
			lastSpawn = spawn
			local x, y, z = Spring.GetUnitPosition(id or -1)
			if x then
				Spring.SetCameraTarget(x, y, z, 0.5) -- the unit is at a new place of the map
			end
		end
	end

	local function teamName(team)
		local _, leader, _, isAI = Spring.GetTeamInfo(team, false)
		if isAI then
			local _, name = Spring.GetAIInfo(team)
			return (name and name ~= "") and name or ("AI " .. team)
		end
		local name = leader and Spring.GetPlayerInfo(leader, false)
		return (name and name ~= "") and name or ("Team " .. team)
	end

	function gadget:DrawScreen()
		if (Spring.GetGameRulesParam("evoState") or "") == "" then
			return
		end
		local vsx, vsy = Spring.GetViewGeometry()
		local mine = Spring.GetMyTeamID()
		local y = vsy - 130
		gl.Color(1, 0.9, 0.5, 1)
		gl.Text("Evolution", vsx * 0.5, y, 20, "co")
		for t in tostring(Spring.GetGameRulesParam("evoTeams") or ""):gmatch("%d+") do
			local team = tonumber(t)
			y = y - 20
			local function p(k) return Spring.GetTeamRulesParam(team, k) or 0 end
			local unit = Spring.GetTeamRulesParam(team, "evoName") or ""
			local need = p("evoNeed")
			local text = string.format("%s: stage %d/10 %s   %s   kills %d   deaths %d", teamName(team), p("evoStage"), NAMES[unit] or unit,
				need > 0 and string.format("points %d/%d", p("evoXp"), need) or "top stage", p("evoKills"), p("evoDeaths"))
			if team == mine then
				gl.Color(1, 1, 1, 1)
			else
				local r, g, b = Spring.GetTeamColor(team)
				gl.Color(r or 1, g or 1, b or 1, 1)
			end
			gl.Text(text, vsx * 0.5, y, 16, "co")
		end
		gl.Color(1, 1, 1, 1)
	end
	return
end

-- ---------------------------------------------------------------- synced
local FPS = 30
local STAGES = 10
local FIRST, FACTOR = 3, 1.6 -- points from stage 1 to 2, and how much more every further stage costs
local RESPAWN = 5 * FPS -- frames until a destroyed unit comes back
local WILD_BACK = 10 * FPS -- frames until a destroyed wild unit comes back
local WILD_HP = 0.1 -- health of a wild unit (part of the normal)
local START_AFTER, START_UNTIL = 30, 900 -- frames: the commanders are looked for from START_AFTER on (BAR creates them at the start), new ones until START_UNTIL
local CMD_FIRE_STATE, CMD_MOVE_STATE = CMD.FIRE_STATE, CMD.MOVE_STATE
local RETURN_FIRE, HOLD_POSITION = 1, 0

-- The ladders: stage 1 to 10 per faction, ordered by damage per second times health (the strength in a fight of one against one); the last stage is
-- the biggest walking unit of the faction. Artillery, units for water and the bomb bots are left out. Every spawn takes a random faction of those
-- whose unit exists in the game (Legion only with its game option).
local LADDERS = {
	{ "armpw", "armflash", "armwar", "armzeus", "armbull", "armmar", "armmeatball", "armraz", "armthor", "armbanth" },
	{ "corak", "corgator", "corraid", "corpyro", "correap", "corcan", "corshiva", "corkarg", "cordemon", "corkorg" },
	{ "leghades", "legcen", "legkark", "leggat", "legjav", "legaheattank", "leginc", "legkeres", "legeshotgunmech", "legeheatraymech" },
}

local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST) -- what the gadgets of the editor share (led_gadgets.lua)
local say = G.sayer("Evolution")

local players = {} -- list of player records { team, ally, stage, xp, kills, deaths, unit, spawns, respawnAt, ai, name }
local byTeam = {} -- team -> player record
local owner = {} -- unitID -> player record (the unit of a player team)
local wild = {} -- unitID -> true: wild units
local removing = {} -- unitID -> true: destroyed by this gadget (no points, no respawn)
local wildDue = {} -- frames at which a wild unit comes back
local running = false

local function need(s)
	return math.max(1, math.floor(FIRST * FACTOR ^ (s - 1) + 0.5))
end

-- The worth of a kill of a player unit of stage v by a unit of stage k
local function worth(v, k)
	return need(v) * math.max(1, 1 + v - k)
end

-- A unit of the stage, of a random faction whose unit exists in the game
local function stageUnit(s)
	local options = {}
	for _, ladder in ipairs(LADDERS) do
		if UnitDefNames[ladder[s]] then
			options[#options + 1] = ladder[s]
		end
	end
	return options[math.random(1, math.max(1, #options))] or "armpw"
end

local function unitTitle(name)
	return NAMES[name] or name
end

local function publish()
	local teams = {}
	local pub = { public = true }
	for _, p in ipairs(players) do
		teams[#teams + 1] = p.team
		Spring.SetTeamRulesParam(p.team, "evoStage", p.stage, pub)
		Spring.SetTeamRulesParam(p.team, "evoXp", p.xp, pub)
		Spring.SetTeamRulesParam(p.team, "evoNeed", p.stage < STAGES and need(p.stage) or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoKills", p.kills, pub)
		Spring.SetTeamRulesParam(p.team, "evoDeaths", p.deaths, pub)
		Spring.SetTeamRulesParam(p.team, "evoUnit", p.unit or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoSpawn", p.spawns, pub)
		Spring.SetTeamRulesParam(p.team, "evoName", p.unitName or "", pub)
	end
	Spring.SetGameRulesParam("evoTeams", table.concat(teams, ","))
	Spring.SetGameRulesParam("evoState", running and "running" or "")
end

-- Can a unit of this kind stand and move at x, z (land, not too steep)? Without TestMoveOrder: not under water
local function fits(defID, x, z)
	local y = Spring.GetGroundHeight(x, z)
	if Spring.TestMoveOrder then
		local ok, res = pcall(Spring.TestMoveOrder, defID, x, y, z)
		if ok then
			return res and y > -5
		end
	end
	return y > 0
end

-- A random place for a new unit. A player's unit (far = true): of 24 tries the one farthest from the units of the players. A wild unit: the first
-- try at least 600 Elmo from every player unit (spread over the whole map, not only at the edges)
local WILD_GAP = 600 * 600
local function spawnPoint(defID, far)
	local margin = 200
	local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
	local best, bestD = nil, -1
	for _ = 1, 24 do
		local x, z = math.random(margin, mapX - margin), math.random(margin, mapZ - margin)
		if fits(defID, x, z) then
			local d = math.huge
			for id in pairs(owner) do
				local ux, _, uz = Spring.GetUnitPosition(id)
				if ux then
					d = math.min(d, (ux - x) ^ 2 + (uz - z) ^ 2)
				end
			end
			if not far and d >= WILD_GAP then
				return x, z
			end
			if d > bestD then
				best, bestD = { x, z }, d
			end
		end
	end
	if best then
		return best[1], best[2]
	end
	return mapX / 2, mapZ / 2
end

local function remove(id)
	if id and Spring.ValidUnitID(id) then
		removing[id] = true
		Spring.DestroyUnit(id, false, true) -- no explosion, no wreck
	end
end

-- The unit of a player: at x, z (a random place when nil), a unit of its stage. A computer team's unit only shoots back (it attacks what the
-- gadget chooses).
local function spawn(p, x, z, facing)
	local name = stageUnit(p.stage)
	if not x then
		x, z = spawnPoint(UnitDefNames[name].id, true)
		p.spawns = p.spawns + 1 -- (the camera of the player goes to the new place)
	end
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, facing or 0, p.team)
	p.unit, p.unitName, p.respawnAt = id, name, nil
	if id then
		owner[id] = p
		if p.ai then
			Spring.GiveOrderToUnit(id, CMD_FIRE_STATE, { RETURN_FIRE }, 0)
		end
	end
	publish()
end

-- The unit of the next stage replaces the unit where it stands (full health; the orders are kept)
local function evolve(p)
	local old = p.unit
	local x, _, z = Spring.GetUnitPosition(old)
	if not x then
		return
	end
	local facing = Spring.GetUnitBuildFacing(old) or 0
	local cmds = Spring.GetUnitCommands(old, 16) or {}
	owner[old] = nil
	remove(old)
	spawn(p, x, z, facing)
	if p.unit and not p.ai then
		for _, c in ipairs(cmds) do
			pcall(Spring.GiveOrderToUnit, p.unit, c.id, c.params, { "shift" })
		end
	end
	say(string.format("%s evolves to stage %d: %s.", p.name, p.stage, unitTitle(p.unitName)))
end

local function gain(p, points)
	p.xp = p.xp + points
	local up = false
	while p.stage < STAGES and p.xp >= need(p.stage) do
		p.xp = p.xp - need(p.stage)
		p.stage = p.stage + 1
		up = true
	end
	if p.stage >= STAGES then
		p.xp = 0 -- the top stage: nothing left to collect
	end
	if up and p.unit then
		evolve(p)
	end
	publish()
end

-- A wild unit: a stage 1 unit of a random faction, of Gaia, with WILD_HP of its health, at a random place; it holds its position and only shoots back
local function spawnWild()
	local name = stageUnit(1)
	local x, z = spawnPoint(UnitDefNames[name].id)
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, math.random(0, 3), Spring.GetGaiaTeamID())
	if id then
		wild[id] = true
		local _, maxHp = Spring.GetUnitHealth(id)
		local hp = math.max(1, (maxHp or 100) * WILD_HP)
		Spring.SetUnitMaxHealth(id, hp)
		Spring.SetUnitHealth(id, hp)
		Spring.GiveOrderToUnit(id, CMD_FIRE_STATE, { RETURN_FIRE }, 0)
		Spring.GiveOrderToUnit(id, CMD_MOVE_STATE, { HOLD_POSITION }, 0)
	end
end

-- The number of wild units: one per 1024 x 1024 Elmo of the map (a map of 16 x 16 has 64), at least 12, at most 100
local function wildCount()
	return math.max(12, math.min(100, math.floor(Game.mapSizeX * Game.mapSizeZ / (1024 * 1024) + 0.5)))
end

-- A team steered by a human: an active player who is not a spectator plays it
local function hasHuman(team)
	for _, pid in ipairs(Spring.GetPlayerList(team, true) or {}) do
		local _, active, spec = Spring.GetPlayerInfo(pid, false)
		if active and not spec then
			return true
		end
	end
	return false
end

local function nameOf(team)
	local _, leader, _, isAI = Spring.GetTeamInfo(team, false)
	if isAI then
		local _, name = Spring.GetAIInfo(team)
		return (name and name ~= "") and name or ("AI " .. team)
	end
	local name = leader and Spring.GetPlayerInfo(leader, false)
	return (name and name ~= "") and name or ("Team " .. team)
end

-- A team whose commander is there: it becomes a player; its units are removed and its stage 1 unit stands where the commander stood
local function join(team)
	local units = Spring.GetTeamUnits(team)
	local com
	for _, id in ipairs(units) do
		local ud = UnitDefs[Spring.GetUnitDefID(id)]
		if ud and ud.customParams and ud.customParams.iscommander then
			com = id
			break
		end
	end
	if not com then
		return false
	end
	local x, _, z = Spring.GetUnitPosition(com)
	for _, id in ipairs(units) do
		remove(id)
	end
	local p = { team = team, ally = select(6, Spring.GetTeamInfo(team, false)), stage = 1, xp = 0, kills = 0, deaths = 0, spawns = 1, ai = not hasHuman(team), name = nameOf(team) }
	players[#players + 1] = p
	byTeam[team] = p
	spawn(p, x, z)
	return true
end

local function idle(id)
	local n = Spring.GetUnitCommands(id, 0)
	return type(n) == "number" and n == 0
end

-- Computer teams: the unit attacks the nearest enemy player unit of its own stage or higher (at stage 1 also the wild units, they are stage 1); with
-- nothing to attack it walks to a random place
local function steer(p)
	local x, _, z = Spring.GetUnitPosition(p.unit)
	if not x then
		return
	end
	local best, bestD = nil, math.huge
	local function consider(id)
		local ux, _, uz = Spring.GetUnitPosition(id)
		local d = ux and (ux - x) ^ 2 + (uz - z) ^ 2
		if d and d < bestD then
			best, bestD = id, d
		end
	end
	for id, q in pairs(owner) do
		if q.ally ~= p.ally and q.stage >= p.stage then
			consider(id)
		end
	end
	if p.stage == 1 then
		for id in pairs(wild) do
			consider(id)
		end
	end
	if best then
		-- an attack order needs a target the team sees (or has on the radar): otherwise the unit walks there first
		if Spring.IsUnitInLos(best, p.ally) or Spring.IsUnitInRadar(best, p.ally) then
			Spring.GiveOrderToUnit(p.unit, CMD.ATTACK, { best }, 0)
		else
			local tx, _, tz = Spring.GetUnitPosition(best)
			Spring.GiveOrderToUnit(p.unit, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
		end
	elseif idle(p.unit) then
		local tx, tz = math.random(200, Game.mapSizeX - 200), math.random(200, Game.mapSizeZ - 200)
		Spring.GiveOrderToUnit(p.unit, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
	end
end

function gadget:GameFrame(n)
	if n >= START_AFTER and n <= START_UNTIL and n % 15 == 0 then
		local gaia = Spring.GetGaiaTeamID()
		for _, team in ipairs(Spring.GetTeamList()) do
			if team ~= gaia and not byTeam[team] then
				local _, _, dead = Spring.GetTeamInfo(team, false)
				if not dead and join(team) and not running then
					running = true
					for _ = 1, wildCount() do
						spawnWild()
					end
					say(string.format("Evolution: kill to evolve (10 stages, a random faction each time); a lost unit comes back 5 s later at another place, one stage lower. %d wild units only shoot back.", wildCount()))
				end
			end
		end
		publish()
	end
	if not running then
		return
	end
	if n % 15 == 0 then
		for _, p in ipairs(players) do
			if p.respawnAt and n >= p.respawnAt then
				spawn(p)
			end
		end
		local due = {}
		for _, f in ipairs(wildDue) do
			if n >= f then
				spawnWild()
			else
				due[#due + 1] = f
			end
		end
		wildDue = due
	end
	if n % 90 == 45 then
		for _, p in ipairs(players) do
			if p.ai and p.unit and Spring.ValidUnitID(p.unit) then
				steer(p)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	if removing[unitID] then
		removing[unitID] = nil
		return
	end
	local victim, wasWild = owner[unitID], wild[unitID]
	owner[unitID], wild[unitID] = nil, nil
	if not (victim or wasWild) then
		return
	end
	local killer = attackerTeam and byTeam[attackerTeam]
	if killer and killer ~= victim and (wasWild or killer.ally ~= victim.ally) then
		if not wasWild then
			killer.kills = killer.kills + 1
		end
		gain(killer, wasWild and 1 or worth(victim.stage, killer.stage))
	end
	if wasWild then
		wildDue[#wildDue + 1] = Spring.GetGameFrame() + WILD_BACK
		return
	end
	victim.unit, victim.xp = nil, 0
	victim.deaths = victim.deaths + 1
	victim.stage = math.max(1, victim.stage - 1)
	victim.respawnAt = Spring.GetGameFrame() + RESPAWN
	publish()
end

-- orders that only switch a state: they stay allowed for every unit
local STATES = { [CMD_FIRE_STATE] = true, [CMD_MOVE_STATE] = true, [CMD.REPEAT] = true, [CMD.IDLEMODE] = true }

-- The unit of a player cannot destroy itself (it would come back elsewhere at once) and is not given away; the unit of a computer team only takes the
-- orders of this gadget (the AI of the team would steer it otherwise)
function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	local p = owner[unitID]
	if not p then
		return true
	end
	if cmdID == CMD.SELFD then
		return false
	end
	-- (measured: the orders of BARb come with player 0 and fromSynced true, the orders of this gadget with player -1 and fromLua true)
	if p.ai and not (fromLua and (playerID or -1) < 0) and not STATES[cmdID] then
		return false
	end
	return true
end

function gadget:AllowUnitTransfer(unitID)
	return not owner[unitID]
end

function gadget:Initialize()
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- otherwise the engine registers it and warns
	end
	Spring.SetGameRulesParam("evoState", "")
end
