-- Evolution (synchronized part): every player team starts with one weak unit (stage 1 of the ladder of its faction) and nothing else. Kills give
-- experience points; with enough points the unit is replaced by the unit of the next stage (10 stages, the last one a big tier 3 unit). Wild
-- units (stage 1 units of Gaia with little health) walk around the map and give 1 point each; a player unit gives as many points as its stage cost.
-- A destroyed player unit comes back at a random place of the map (on the same stage, the points of the stage are lost) while the team has lives left;
-- the last alliance with a unit or a life left wins. Computer players (teams without a human) are steered by this gadget.
-- Configuration: from the Level Editor with the message "evo|start|<payload>" (stop: "evo|stop"), or from the game option evoconfig (same payload
-- as base64url) for a finished scenario. Payload, fields separated by ";":
--   lives;respawn;wilds;wildHp;first;factor
--   lives   = lives of a team (0 = unlimited: the game does not end), respawn = seconds until a destroyed unit comes back,
--   wilds   = number of wild units on the map (a destroyed one comes back after 10 s at another place), wildHp = their health in percent of the normal,
--   first   = points from stage 1 to stage 2, factor = percent: every further stage needs factor / 100 times the points of the stage before
-- The player teams are the teams that own units when the game starts (their units are removed; the new unit stands where the commander, or the
-- first unit, stood); the faction comes from the name of that unit (arm, cor, leg).
-- State for the display: game rules parameters evoState ("", "running", "won by alliance N"), evoTeams (the player teams), evoLives (the setting);
-- team rules parameters evoStage, evoXp, evoNeed (points to the next stage, 0 on the last), evoLeft (lives left), evoOut (1 = out), evoUnit (the unit,
-- 0 = none), evoSpawn (counts the spawns: the unsynced part points the camera at a new unit), evoName (unit definition name of the stage; the unsynced
-- part shows its translated name, which the synced part does not know).
function gadget:GetInfo()
	return {
		name = "Evolution",
		desc = "One unit per team that evolves with every kill; last alliance standing wins",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	-- ---------------------------------------------------------------- unsynced: the score lines, the selection and the camera
	local lastUnit, lastSpawn = nil, nil

	function gadget:Update()
		local state = Spring.GetGameRulesParam("evoState")
		if not state or state == "" then
			lastUnit, lastSpawn = nil, nil
			return
		end
		local spec = Spring.GetSpectatingState()
		if spec then
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
			local first = lastSpawn == nil
			lastSpawn = spawn
			local x, y, z = Spring.GetUnitPosition(id or -1)
			if x and (first or spawn > 1) then
				Spring.SetCameraTarget(x, y, z, 0.5) -- the unit came back somewhere else on the map
			end
		end
	end

	local function teamName(team)
		local _, leader, _, isAI = Spring.GetTeamInfo(team, false)
		if isAI then
			return "AI " .. team
		end
		local name = leader and Spring.GetPlayerInfo(leader, false)
		return (name and name ~= "") and name or ("Team " .. team)
	end

	function gadget:DrawScreen()
		local state = Spring.GetGameRulesParam("evoState")
		if not state or state == "" then
			return
		end
		local vsx, vsy = Spring.GetViewGeometry()
		local lives = Spring.GetGameRulesParam("evoLives") or 0
		local mine = Spring.GetMyTeamID()
		local y = vsy - 130
		gl.Color(1, 0.9, 0.5, 1)
		gl.Text("Evolution" .. (state ~= "running" and ("   (" .. state .. ")") or ""), vsx * 0.5, y, 20, "co")
		for t in tostring(Spring.GetGameRulesParam("evoTeams") or ""):gmatch("%d+") do
			local team = tonumber(t)
			y = y - 20
			local p = function(k) return Spring.GetTeamRulesParam(team, k) or 0 end
			local text
			if p("evoOut") == 1 then
				text = string.format("%s: out (stage %d)", teamName(team), p("evoStage"))
			else
				local need = p("evoNeed")
				local ud = UnitDefNames[Spring.GetTeamRulesParam(team, "evoName") or ""]
				text = string.format("%s: stage %d/10 %s   %s%s", teamName(team), p("evoStage"), ud and (ud.translatedHumanName or ud.humanName) or "",
					need > 0 and string.format("points %d/%d", p("evoXp"), need) or "top stage",
					lives > 0 and string.format("   lives %d", p("evoLeft")) or "")
			end
			local r, g, b = Spring.GetTeamColor(team)
			if team == mine then
				gl.Color(1, 1, 1, 1)
			else
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
local WILD_BACK = 10 * FPS -- frames until a destroyed wild unit comes back
local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST) -- what the gadgets of the editor share (led_gadgets.lua)
local EDITOR_MODE = G.EDITOR_MODE

-- The ladders: stage 1 to 10 per faction, ordered by damage per second times health (the strength in a fight of one against one); the last stage is
-- the biggest walking unit of the faction. A unit missing in the game (an option off) is taken from another faction on the same stage.
local LADDERS = {
	arm = { "armpw", "armflash", "armwar", "armzeus", "armbull", "armmar", "armmeatball", "armraz", "armthor", "armbanth" },
	cor = { "corak", "corgator", "corraid", "corpyro", "correap", "corcan", "corshiva", "corkarg", "cordemon", "corkorg" },
	leg = { "leghades", "legcen", "legkark", "leggat", "legjav", "legaheattank", "leginc", "legkeres", "legeshotgunmech", "legeheatraymech" },
}
local FACTIONS = { "arm", "cor", "leg" }

local g = nil -- running game: nil = none
local mode -- messages, game option and start of a finished scenario: G.gameMode, made at the end of this file
local owner = {} -- unitID -> player record (the unit of a player team)
local wild = {} -- unitID -> true: wild units
local removing = {} -- unitID -> true: destroyed by this gadget (no points, no respawn)

local say = G.sayer("Evolution")

local function num(v, lo, hi, default)
	v = tonumber(v) or default
	return math.max(lo, math.min(hi, math.floor(v)))
end

local function parse(payload)
	local f = G.fields(payload)
	return {
		lives = num(f[1], 0, 99, 3), respawn = num(f[2], 0, 600, 5), wilds = num(f[3], 0, 300, 20), wildHp = num(f[4], 1, 100, 10),
		first = num(f[5], 1, 10000, 3), factor = num(f[6], 100, 400, 160),
	}
end

-- Points from stage s to stage s + 1 (also for s = 10: the worth of a unit of the top stage)
local function need(s)
	return math.max(1, math.floor(g.cfg.first * (g.cfg.factor / 100) ^ (s - 1) + 0.5))
end

-- The unit name of a stage for a faction (another faction's unit of the same stage if the own one is missing in the game)
local function stageUnit(fac, s)
	local own = LADDERS[fac] and LADDERS[fac][s]
	if own and UnitDefNames[own] then
		return own
	end
	for _, f in ipairs(FACTIONS) do
		if UnitDefNames[LADDERS[f][s]] then
			return LADDERS[f][s]
		end
	end
	return "armpw"
end

local function publish()
	if not g then
		Spring.SetGameRulesParam("evoState", "")
		return
	end
	local teams = {}
	for _, p in ipairs(g.players) do
		teams[#teams + 1] = p.team
		local pub = { public = true }
		Spring.SetTeamRulesParam(p.team, "evoStage", p.stage, pub)
		Spring.SetTeamRulesParam(p.team, "evoXp", p.xp, pub)
		Spring.SetTeamRulesParam(p.team, "evoNeed", p.stage < STAGES and need(p.stage) or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoLeft", p.lives, pub)
		Spring.SetTeamRulesParam(p.team, "evoOut", p.out and 1 or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoUnit", p.unit or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoSpawn", p.spawns, pub)
		Spring.SetTeamRulesParam(p.team, "evoName", stageUnit(p.fac, p.stage), pub)
	end
	Spring.SetGameRulesParam("evoTeams", table.concat(teams, ","))
	Spring.SetGameRulesParam("evoLives", g.cfg.lives)
	Spring.SetGameRulesParam("evoState", g.state)
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

-- A random place for a new unit: of 24 tries the one farthest from the units of the player teams
local function spawnPoint(defID)
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

local function create(name, x, z, facing, team)
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, facing or 0, team)
	if id then
		Spring.SetUnitRulesParam(id, "led_nosave", 1, { public = true }) -- a unit of the running game: the editor does not save it
	end
	return id
end

-- The unit of a player: at x, z (a random place when nil), the unit of its stage
local function spawn(p, x, z, facing)
	local name = stageUnit(p.fac, p.stage)
	if not x then
		x, z = spawnPoint(UnitDefNames[name].id)
		p.spawns = p.spawns + 1 -- (the camera of the player goes to the new place)
	end
	local id = create(name, x, z, facing, p.team)
	p.unit, p.respawnAt = id, nil
	if id then
		owner[id] = p
	end
	publish()
end

local function remove(id)
	if id and Spring.ValidUnitID(id) then
		removing[id] = true
		Spring.DestroyUnit(id, false, true) -- no explosion, no wreck
	end
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
	if p.unit then
		for _, c in ipairs(cmds) do
			pcall(Spring.GiveOrderToUnit, p.unit, c.id, c.params, { "shift" })
		end
	end
	local name = stageUnit(p.fac, p.stage)
	local human = UnitDefNames[name].humanName
	say(string.format("Team %d evolves to stage %d: %s.", p.team, p.stage, (human and human ~= "") and human or name))
end

local function gain(p, points)
	if p.out then
		return
	end
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

-- A wild unit: a stage 1 unit of a random faction, of Gaia, with wildHp % of its health, at a random place
local function spawnWild()
	local name = stageUnit(FACTIONS[math.random(1, #FACTIONS)], 1)
	local x, z = spawnPoint(UnitDefNames[name].id)
	local id = create(name, x, z, math.random(0, 3), Spring.GetGaiaTeamID())
	if id then
		wild[id] = true
		local _, maxHp = Spring.GetUnitHealth(id)
		local hp = math.max(1, (maxHp or 100) * g.cfg.wildHp / 100)
		Spring.SetUnitMaxHealth(id, hp)
		Spring.SetUnitHealth(id, hp)
	end
end

local function finish(ally)
	if g.state ~= "running" then
		return
	end
	g.state = "won by alliance " .. G.allianceName(ally)
	publish()
	say("Alliance " .. G.allianceName(ally) .. " is the last one standing: the game is won!")
	if not EDITOR_MODE then
		Spring.GameOver({ ally })
	end
end

-- The last alliance with a unit or a life left wins (only when the game began with two alliances or more)
local function checkWin()
	local left, last = {}, nil
	local n = 0
	for _, p in ipairs(g.players) do
		if not p.out and not left[p.ally] then
			left[p.ally] = true
			n, last = n + 1, p.ally
		end
	end
	if g.alliances >= 2 and n <= 1 and last then
		finish(last)
	end
end

local function clear()
	if g then
		for _, p in ipairs(g.players) do
			remove(p.unit)
			Spring.SetTeamRulesParam(p.team, "evoUnit", 0, { public = true })
		end
	end
	for id in pairs(wild) do
		remove(id)
	end
	owner, wild = {}, {}
	g = nil
end

local function stop()
	if g then
		clear()
		publish()
		say("Stopped.")
	end
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

local function start(cfg)
	clear()
	g = { cfg = cfg, state = "running", players = {}, byTeam = {}, wildDue = {}, alliances = 0 }
	local gaia = Spring.GetGaiaTeamID()
	local allies = {}
	for _, team in ipairs(Spring.GetTeamList()) do
		local units = team ~= gaia and Spring.GetTeamUnits(team) or {}
		if #units > 0 then
			local at = units[1]
			for _, id in ipairs(units) do
				local ud = UnitDefs[Spring.GetUnitDefID(id)]
				if ud and ud.customParams and ud.customParams.iscommander then
					at = id
					break
				end
			end
			local ud = UnitDefs[Spring.GetUnitDefID(at)]
			local fac = ud and ud.name:sub(1, 3)
			if not LADDERS[fac] then
				local side = tostring(select(5, Spring.GetTeamInfo(team, false)) or ""):lower()
				fac = side:find("cortex") and "cor" or (side:find("legion") and "leg" or "arm")
			end
			local x, _, z = Spring.GetUnitPosition(at)
			for _, id in ipairs(units) do
				remove(id)
			end
			local p = { team = team, ally = G.allyOf(team), fac = fac, stage = 1, xp = 0, lives = cfg.lives, spawns = 1, ai = not hasHuman(team) }
			g.players[#g.players + 1] = p
			g.byTeam[team] = p
			if not allies[p.ally] then
				allies[p.ally] = true
				g.alliances = g.alliances + 1
			end
			spawn(p, x, z)
		end
	end
	for _ = 1, cfg.wilds do
		spawnWild()
	end
	publish()
	say(string.format("Started: %d teams, %d wild units, %s. Kill to evolve (stage 2 after %d points, each stage x%.2f).", #g.players, cfg.wilds,
		cfg.lives > 0 and (cfg.lives .. " lives") or "unlimited lives", cfg.first, cfg.factor / 100))
end

local function idle(id)
	local n = Spring.GetUnitCommands(id, 0)
	return type(n) == "number" and n == 0
end

-- Computer teams: the unit fights its way to the nearest enemy that is not more than one stage above it, otherwise to the nearest wild unit
local function steer(p)
	local x, _, z = Spring.GetUnitPosition(p.unit)
	if not x then
		return
	end
	local best, bestD = nil, math.huge
	for id, q in pairs(owner) do
		if q.ally ~= p.ally and q.stage <= p.stage + 1 then
			local ux, _, uz = Spring.GetUnitPosition(id)
			local d = ux and (ux - x) ^ 2 + (uz - z) ^ 2
			if d and d < bestD then
				best, bestD = { ux, uz }, d
			end
		end
	end
	for id in pairs(wild) do
		local ux, _, uz = Spring.GetUnitPosition(id)
		local d = ux and (ux - x) ^ 2 + (uz - z) ^ 2
		if d and d * 4 < bestD then -- (a wild unit only when it is much closer than an enemy)
			best, bestD = { ux, uz }, d * 4
		end
	end
	if best then
		Spring.GiveOrderToUnit(p.unit, CMD.FIGHT, { best[1], Spring.GetGroundHeight(best[1], best[2]), best[2] }, {})
	end
end

-- Wild units walk to a place up to 1500 Elmo away when they stand still
local function wander(id)
	local x, _, z = Spring.GetUnitPosition(id)
	if x then
		local tx = math.max(100, math.min(Game.mapSizeX - 100, x + math.random(-1500, 1500)))
		local tz = math.max(100, math.min(Game.mapSizeZ - 100, z + math.random(-1500, 1500)))
		Spring.GiveOrderToUnit(id, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, {})
	end
end

function gadget:GameFrame(n)
	mode.gameFrame(n) -- a finished scenario starts at frame G.START_FRAME (led_gadgets.lua)
	if not g or g.state ~= "running" then
		return
	end
	if n % 15 == 0 then
		for _, p in ipairs(g.players) do
			if p.respawnAt and n >= p.respawnAt and not p.out then
				spawn(p)
			end
		end
		local due = {}
		for _, f in ipairs(g.wildDue) do
			if n >= f then
				spawnWild()
			else
				due[#due + 1] = f
			end
		end
		g.wildDue = due
	end
	if n % 90 == 0 then
		for _, p in ipairs(g.players) do
			if p.ai and p.unit and Spring.ValidUnitID(p.unit) and (idle(p.unit) or n % 270 == 0) then
				steer(p)
			end
		end
		for id in pairs(wild) do
			if idle(id) then
				wander(id)
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
	if not g or g.state ~= "running" or not (victim or wasWild) then
		return
	end
	local killer = attackerTeam and g.byTeam[attackerTeam]
	if killer and killer ~= victim and (wasWild or killer.ally ~= victim.ally) then
		gain(killer, wasWild and 1 or need(victim.stage))
	end
	if wasWild then
		g.wildDue[#g.wildDue + 1] = Spring.GetGameFrame() + WILD_BACK
		return
	end
	victim.unit, victim.xp = nil, 0
	if g.cfg.lives > 0 then
		victim.lives = victim.lives - 1
	end
	if g.cfg.lives == 0 or victim.lives > 0 then
		victim.respawnAt = Spring.GetGameFrame() + g.cfg.respawn * FPS
		say(string.format("Team %d lost its unit: back in %d s at another place%s.", victim.team, g.cfg.respawn,
			g.cfg.lives > 0 and (" (" .. victim.lives .. " lives left)") or ""))
	else
		victim.out = true
		say(string.format("Team %d has no lives left: out.", victim.team))
	end
	publish()
	checkWin()
end

-- The unit of a player cannot destroy itself (it would come back elsewhere at once) and is not given away
function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID)
	if cmdID == CMD.SELFD and owner[unitID] then
		return false
	end
	return true
end

function gadget:AllowUnitTransfer(unitID)
	return not owner[unitID]
end

-- The messages of the editor (evo|start|<payload>, evo|stop) and the game option evoconfig of a finished scenario (the payload as base64url; starts when the units of the scenario exist): G.gameMode of led_gadgets.lua
mode = G.gameMode({ tag = "evo", option = "evoconfig", state = "evoState", parse = parse, start = start, stop = stop, say = say, handler = gadgetHandler, allowCommand = true })

function gadget:RecvLuaMsg(msg, playerID)
	return mode.recvLuaMsg(msg, playerID)
end

function gadget:Initialize()
	mode.initialize()
end

function gadget:GamePreload()
	mode.gamePreload()
end
