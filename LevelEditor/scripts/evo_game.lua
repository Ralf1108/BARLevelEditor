-- Evolution (synchronized part), a game mode of LAN Play on any map: the button Evolution of the room (menu LAN Play) sets the game option lanevolution=1. Every
-- team that starts with a commander gets one weak unit instead (stage 1) and nothing else. Kills give points; with enough points the unit is replaced by a
-- unit of the next stage (10 stages, the last one a big tier 3 unit), of a random faction each time. A destroyed unit comes back after 5 s at a random
-- place, one stage lower. Every unit spawns on the land the commanders stand on (one connected piece of land: everybody can reach everybody). Wild units
-- (stage 1 units of Gaia with little health) stand around the map; they only shoot back. Computer players (teams without a human) are steered by this
-- gadget: their unit attacks only enemies of its own stage or higher and otherwise only shoots back; the orders of the AI itself are dropped.
-- Armageddon: the first unit on stage 10 ends the fog of war for everybody, and from then on a lost unit does not come back; the last alliance standing
-- wins. Every player who reaches stage 10 chooses a gift (window of the game widget evo_gift.lua, message "evo|gift|<n>"; a computer player chooses at
-- once, a human after 30 s at the latest): 1 Hell on Earth (strong ground units rise all over the map, they belong to the player), 2 Heaven on Earth
-- (Dragons come down around the player's unit), 3 Gates of Hell (nuclear missiles that never stop and come ever closer to the enemies).
-- Points: from stage s to s + 1 it takes need(s) = round(3 * 1.6^(s - 1)) points (3, 5, 8, 12, 20, 31, 50, 81, 129). A wild unit gives 1 point; a
-- player unit of stage v gives need(v), times (1 + v - k) when it is above the stage k of the killer.
-- Test only: the game option lanevolutionstage=<n> lets every player start on stage n.
-- State for the display: game rules parameters evoState ("" / "running" / "won by alliance N"), evoTeams (the player teams), evoArmageddon (frame of its
-- start, 0 = not yet), evoHero (who brought it), evoNukes ("x,z/..." the targets of the missiles of the next seconds); team rules parameters evoStage, evoXp,
-- evoNeed (points to the next stage, 0 on the last), evoKills, evoDeaths, evoOut (1 = out), evoUnit (the unit, 0 = none), evoSpawn (counts the spawns: the
-- unsynced part points the camera at a new unit), evoName (unit definition name; shown with its name from NAMES), evoGift (1 = the player chooses a gift now).
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
	armsnipe = "Sharpshooter", legsrail = "Arquebus", cordeadeye = "Deadeye", armmanni = "Starlight", corsiegebreaker = "Siegebreaker",
	legerailtank = "Daedalus", corthermite = "Thermite", legpede = "Mukade", legapollyon = "Apollyon",
}
-- BEGIN POOL (made by test-data/generators/evolution_units.py from game-modes/evolution_units.csv: change the csv, then update_evolution_units.bat, not this block)
-- Every level: the candidates of Armada, Cortex and Legion (a spawn takes a random faction, then a random unit of it); POOL_LONG: the units that join with the game option Long range
local POOL = {
	[1] = { { "armpw" }, { "corak" }, { "leghades" } },
	[2] = { { "armamph", "armanac", "armfast", "armflash", "armgremlin", "armham", "armpincer" }, { "corgarp", "corgator", "corsnap", "corthud", "cortorch" }, { "legamphtank", "legcen", "leghelios", "legmrv", "legner" } },
	[3] = { { "armlatnk", "armstump", "armwar" }, { "corlevlr", "corraid" }, { "legaskirmtank", "legkark" } },
	[4] = { { "armcroc", "armmav", "armzeus" }, { "coramph", "corpyro", "corsala", "corseal", "corsok" }, { "legehovertank", "leggat", "legshot", "legstr" } },
	[5] = { { "armbull", "armlun" }, { "corftiger", "corgatreap", "corhal", "corparrow", "correap", "cortermite" }, { "legbunk", "legcar", "legfloat", "legjav" } },
	[6] = { { "armmar" }, { "corcan", "corgol" }, { "legaheattank" } },
	[7] = { { "armmeatball" }, { "corshiva" }, { "legamph", "leginc" } },
	[8] = { { "armraz" }, { "corkarg" }, { "legkeres" } },
	[9] = { { "armthor" }, { "cordemon" }, { "legeshotgunmech" } },
	[10] = { { "armbanth" }, { "corkorg" }, { "legeheatraymech" } },
}
local POOL_LONG = {
	[3] = { { "armsnipe" }, {}, { "legsrail" } },
	[4] = { {}, { "cordeadeye" }, {} },
	[5] = { { "armmanni" }, { "corsiegebreaker" }, {} },
	[8] = { {}, {}, { "legerailtank" } },
	[9] = { {}, { "corthermite" }, { "legpede" } },
	[10] = { {}, {}, { "legapollyon" } },
}
for name, title in pairs({
	armamph = "Platypus",
	armanac = "Crocodile",
	armbanth = "Titan",
	armbull = "Bull",
	armcroc = "Turtle",
	armfast = "Sprinter",
	armflash = "Blitz",
	armgremlin = "Gremlin",
	armham = "Mace",
	armlatnk = "Jaguar",
	armlun = "Lunkhead",
	armmanni = "Starlight",
	armmar = "Marauder",
	armmav = "Gunslinger",
	armmeatball = "Meatball",
	armpincer = "Pincer",
	armpw = "Pawn",
	armraz = "Razorback",
	armsnipe = "Sharpshooter",
	armstump = "Stout",
	armthor = "Thor",
	armwar = "Centurion",
	armzeus = "Welder",
	corak = "Grunt",
	coramph = "Duck",
	corcan = "Sumo",
	cordeadeye = "Deadeye",
	cordemon = "Demon",
	corftiger = "Heat Tiger",
	corgarp = "Garpike",
	corgator = "Incisor",
	corgatreap = "Laser Tiger",
	corgol = "Tzar",
	corhal = "Halberd",
	corkarg = "Karganeth",
	corkorg = "Juggernaut",
	corlevlr = "Pounder",
	corparrow = "Poison Arrow",
	corpyro = "Fiend",
	corraid = "Brute",
	correap = "Tiger",
	corsala = "Salamander",
	corseal = "Alligator",
	corshiva = "Shiva",
	corsiegebreaker = "Siegebreaker",
	corsnap = "Cayman",
	corsok = "Cataphract",
	cortermite = "Termite",
	corthermite = "Thermite",
	corthud = "Thug",
	cortorch = "Torch",
	legaheattank = "Prometheus",
	legamph = "Telchine",
	legamphtank = "Cetus",
	legapollyon = "Apollyon",
	legaskirmtank = "Gladiator",
	legbunk = "Pilum",
	legcar = "Cardea",
	legcen = "Phobos",
	legeheatraymech = "Sol Invictus",
	legehovertank = "Charybdis",
	legerailtank = "Daedalus",
	legeshotgunmech = "Praetorian",
	legfloat = "Triton",
	leggat = "Decurion",
	leghades = "Alaris",
	leghelios = "Helios",
	leginc = "Incinerator",
	legjav = "Javelin",
	legkark = "Karkinos",
	legkeres = "Keres",
	legmrv = "Quickshot",
	legner = "Nereus",
	legpede = "Mukade",
	legshot = "Phalanx",
	legsrail = "Arquebus",
	legstr = "Hoplite",
}) do
	NAMES[name] = title
end
-- END POOL
local LONG_RANGE = (Spring.GetModOptions() or {}).lanevolong == "1"
local TESTING = (Spring.GetModOptions() or {}).lanevotest == "1" -- test only: some lines for the log
local ALL_GODS = (Spring.GetModOptions() or {}).lanevogods == "1" -- the room's button All Be Gods: every player who reaches level 10 gets a gift (default: only the first one)

-- (used by both parts: the ladders and the help window)
-- The ladders: stage 1 to 10 per faction, ordered by damage per second times health (the strength in a fight of one against one); the last stage is
-- the biggest walking unit of the faction. Artillery, units for water and the bomb bots are left out. Every spawn takes a random faction of those
-- whose unit exists in the game (Legion only with its game option).
local LADDERS = {
	{ "armpw", "armflash", "armwar", "armzeus", "armbull", "armmar", "armmeatball", "armraz", "armthor", "armbanth" },
	{ "corak", "corgator", "corraid", "corpyro", "correap", "corcan", "corshiva", "corkarg", "cordemon", "corkorg" },
	{ "leghades", "legcen", "legkark", "leggat", "legjav", "legaheattank", "leginc", "legkeres", "legeshotgunmech", "legeheatraymech" },
}
local GUNSHIPS = { "corcrw" } -- Heaven on Earth: the Dragon (without it in the game: Hell on Earth)
local GIFT_NAMES = { "Hell on Earth", "Heaven on Earth", "Gates of Hell" }

-- The abilities (data and logic: powerups.lua, shared with Renegade): used by both parts here (the beacons and the display)
local P = VFS.Include("luaui/Include/powerups.lua", nil, VFS.ZIP_FIRST)
local ABILITIES = P.ABILITIES

-- The name of a team: the AI's name or the name of its leader (used by both parts)
local function teamName(team)
	local _, leader, _, isAI = Spring.GetTeamInfo(team, false)
	if isAI then
		local _, name = Spring.GetAIInfo(team)
		return (name and name ~= "") and name or ("AI " .. team)
	end
	local name = leader and Spring.GetPlayerInfo(leader, false)
	return (name and name ~= "") and name or ("Team " .. team)
end

if not gadgetHandler:IsSyncedCode() then
	-- the unsynced part (score lines, panels, camera, heal effect) is its own file
	VFS.Include("luaui/Include/evo_ui.lua", nil, VFS.ZIP_FIRST)(gadget, { NAMES = NAMES, LADDERS = LADDERS, ABILITIES = ABILITIES, teamName = teamName })
	return
end

-- ---------------------------------------------------------------- synced
local FPS = 30
local STAGES = 10
local FIRST, FACTOR = 3, 1.6 -- points from stage 1 to 2, and how much more every further stage costs
local RESPAWN = 5 * FPS -- frames until a destroyed unit comes back
local WILD_BACK = 10 * FPS -- frames until a destroyed wild unit comes back
local REGEN, REGEN_STEP, REGEN_WAIT = 0.002, 30, 150 -- the unit of a player regenerates 0.2 % of its health per second (1 % in 5 s), 5 s after the last damage
-- the health of a wild unit at the start (part of the normal maximum: the bar shows it): by its level 10 % on level 1, 30 % on levels 2 to 4, 40 % on levels 5 to 7, 50 % from level 8;
-- the game option lanevohp (10 - 100) sets one value for all levels
local WILD_HP_FIXED = tonumber((Spring.GetModOptions() or {}).lanevohp)
local function wildHp(stage)
	if WILD_HP_FIXED then
		return math.max(0.1, math.min(1, WILD_HP_FIXED / 100))
	end
	return stage >= 8 and 0.5 or (stage >= 5 and 0.4 or (stage >= 2 and 0.3 or 0.1))
end
local REGEN_ON = (Spring.GetModOptions() or {}).lanevoregen ~= "0" -- game option lanevoregen=0: the units of the players do not regenerate
local START_AFTER, START_UNTIL = 30, 900 -- frames: the commanders are looked for from START_AFTER on (BAR creates them at the start), new ones until START_UNTIL
local CMD_FIRE_STATE, CMD_MOVE_STATE = CMD.FIRE_STATE, CMD.MOVE_STATE
local EXP_STEP = 0.1 -- the experience of the unit (the game's own: more health, damage, reload) for a kill of a player unit, minus it for a death
local RETURN_FIRE, HOLD_POSITION = 1, 0
local CELL = 128 -- size of a cell of the land grid in Elmo
local GIFT_WAIT = 30 * FPS -- a human who does not choose a gift gets a random one after this time
local HELL_UNITS, HEAVEN_UNITS, HELL_GAP, HEAVEN_GAP = 8, 8, 30 * FPS, 30 * FPS -- units of the gifts Hell on Earth and Heaven on Earth; one more of each every 30 s
local NUKE_WARN, NUKE_SAFE = 5 * FPS, 900 -- Gates of Hell: warning ring before a missile, distance to the units of the player who chose it
-- Further rules in one table (Lua 5.1 allows only so many locals):
--   energy: every player team gets ENERGY_BASE + ENERGY per level per second and a storage of STORE (the commanders are gone; laser weapons need energy);
--     more comes from the solar collectors and wind turbines (GENERATORS, one per GEN_AREA x GEN_AREA Elmo of the land, GEN_MIN to GEN_MAX), taken like the radars
--   wild units: the lowest stage of the players who are still in; TOWER = chance that a wild spawn is a tower; TOWER_DAMAGE = part of the damage of a wild
--     tower; every CHECK frames the number is topped up; every UPGRADE frames one wild unit two or more stages away from that stage is replaced by one of it
--   catching up: the points of a kill times 1 + CATCH_UP x (the highest stage of the players who are in - the stage of the killer)
--   radars: neutral, cannot be destroyed, placed until COVER of the land is in their range; a player's unit within RANGE for TAKE frames (no enemy player
--     unit as near) takes one; when more than half of the players are on stage T2_STAGE or higher they become T2 radars one by one
local R = {
	ENERGY_BASE = 5, ENERGY = 3, GIFT_ENERGY = 1000, STORE = 1000, STORE_BIG = 2000, RECLAIM_RANGE = 100, RECLAIM_RATE = 60, RECLAIM_HEAL_PERCENT = 0.01, RECLAIM_HEAL_MIN = 1, RECLAIM_HEAL_MAX = 150, RECLAIM_ENEMY = 700, -- (STORE_BIG on level 10 and with the option Long range: the big beam weapons cost up to 1500 per shot)
	GENERATORS = { "armsolar", "corsolar", "legsolar", "armwin", "corwin", "legwin" }, GEN_AREA = 1536, GEN_MIN = 6, GEN_MAX = 30,
	TOWER = 0.15, TOWER_DAMAGE = 0.5, CHECK = 10 * FPS, UPGRADE = 3 * FPS, SAFE = 900, CATCH_UP = 0.5,
	WANDER = 5 * FPS, WANDER_SHARE = 0.6, WANDER_DIST = 700, STILL = 0.2, -- every WANDER frames a part of the idle walking wild units goes to a place nearby;
	-- STILL = part of the wild units that never walk (towers never do)
	COVER = 0.95, RANGE = 200, TAKE = 5 * FPS, T2_STAGE = 6, REVEAL_STAGE = 8, MAX_RADARS = 60,
	-- the towers of a stage per faction (ground targets; anti air, nuclear and anti nuclear buildings left out), ordered by cost
	TOWERS = {
		{ "armllt", "armbeamer", "armclaw", "armhlt", "armpb", "armguard", "armamb", "armanni", "armanni", "armannit3" },
		{ "corllt", "corhllt", "cormaw", "corhlt", "corvipe", "corpun", "cortoast", "cordoom", "corbhmth", "cordoomt3" },
		{ "leglht", "legdtr", "leghive", "legmg", "legapopupdef", "legcluster", "legperdition", "legbastion", "legbastion", "leggatet3" },
	},
	RADAR1 = { "armrad", "corrad", "legrad" },
	-- the T2 version of a radar, a solar collector and a wind turbine (they change when the first player is on stage T2_STAGE; back when nobody is)
	RADAR2 = { armrad = "armarad", corrad = "corarad", legrad = "legarad", armsolar = "armadvsol", corsolar = "coradvsol", legsolar = "legadvsol",
		armwin = "armwint2", corwin = "corwint2", legwin = "legwint2" },
}
R.BACK1 = {} -- T2 name -> T1 name
for t1, t2 in pairs(R.RADAR2) do
	R.BACK1[t2] = t1
end
local radars = {} -- unitID -> { team = owner team (Gaia at first), name, take = { team, frames } while a player takes it }

local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST) -- what the gadgets of the editor share (led_gadgets.lua)
local say = G.sayer("Evolution")

local godPlayer = nil -- the first player on level 10 (he alone chooses a gift without the option All Be Gods)
local players = {} -- list of player records { team, ally, stage, xp, kills, deaths, unit, unitName, spawns, respawnAt, ai, name, out, top, giftAt }
local byTeam = {} -- team -> player record
local owner = {} -- unitID -> player record (the unit of a player team)
local wild = {} -- unitID -> true: wild units
local summoned = {} -- unitID -> player record: the units of the gifts Hell on Earth and Heaven on Earth
local removing = {} -- unitID -> true: destroyed by this gadget (no points, no respawn)
local wildDue = {} -- frames at which a wild unit comes back
local nukes = {} -- { frame, x, z, p }: the missiles of Gates of Hell still to come
local land = nil -- the land grid: { cols, rows, cells = list of cell numbers of the land everybody stands on, onLand = cell -> true }
local running, armageddon, finished = false, false, false
local armaFrame, hero = 0, "" -- the frame Armageddon began and who brought it
local alliancesAtStart = 0
local startStage = math.max(1, math.min(STAGES, tonumber((Spring.GetModOptions() or {}).lanevolutionstage) or 1)) -- test only

local function need(s)
	return math.max(1, math.floor(FIRST * FACTOR ^ (s - 1) + 0.5))
end

-- The worth of a kill of a player unit of stage v by a unit of stage k
local function worth(v, k)
	return need(v) * math.max(1, 1 + v - k)
end

-- A unit of the stage, of a random faction whose unit exists in the game
local function stageUnit(s)
	-- a random faction of those that have a unit on this level, then a random unit of it (every faction has the same chance, whatever its number of units)
	local pools = {}
	for f = 1, 3 do
		local list = {}
		for _, name in ipairs((POOL[s] or {})[f] or {}) do
			list[#list + 1] = name
		end
		for _, name in ipairs(LONG_RANGE and (POOL_LONG[s] or {})[f] or {}) do
			list[#list + 1] = name -- (the option Long range adds the units with a long range)
		end
		local present = {}
		for _, name in ipairs(list) do
			if UnitDefNames[name] then
				present[#present + 1] = name
			end
		end
		if #present > 0 then
			pools[#pools + 1] = present
		end
	end
	if #pools == 0 then
		return "armpw"
	end
	local pool = pools[math.random(1, #pools)]
	return pool[math.random(1, #pool)]
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
		Spring.SetTeamRulesParam(p.team, "evoOut", p.out and 1 or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoUnit", p.unit or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoSpawn", p.spawns, pub)
		Spring.SetTeamRulesParam(p.team, "evoName", p.unitName or "", pub)
		Spring.SetTeamRulesParam(p.team, "evoExp", p.exp or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoGift", p.giftAt and 1 or 0, pub)
	end
	Spring.SetGameRulesParam("evoTeams", table.concat(teams, ","))
	-- (set again with every publish: a value set only once at that moment did not reach the unsynced part and the widgets in the test)
	Spring.SetGameRulesParam("evoArmageddon", armaFrame)
	Spring.SetGameRulesParam("evoHero", hero)
	if not finished then
		Spring.SetGameRulesParam("evoState", running and "running" or "")
	end
end

-- Can a unit of this kind stand and move at x, z (land, not too steep)? objects = false: features and units do not count (G.fits of led_gadgets.lua)
local fits = G.fits

-- The land grid: every cell of CELL x CELL Elmo where a heavy tank can drive (the ladders' most demanding units on slopes), and of those the connected piece
-- (8 neighbours) that holds the most commanders (on a tie the bigger one). Every unit of the game spawns there: nobody is cut off by water or cliffs.
local function buildLand(starts)
	local ref = UnitDefNames.armbull or UnitDefNames.corraid or UnitDefNames.armpw
	local cols, rows = math.floor(Game.mapSizeX / CELL), math.floor(Game.mapSizeZ / CELL)
	local pass = {}
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			if fits(ref.id, (c + 0.5) * CELL, (r + 0.5) * CELL, false) then
				pass[r * cols + c] = true
			end
		end
	end
	local comp, sizes, n = {}, {}, 0
	for start in pairs(pass) do
		if not comp[start] then
			n = n + 1
			local stack, size = { start }, 0
			comp[start] = n
			while #stack > 0 do
				local i = table.remove(stack)
				size = size + 1
				local r, c = math.floor(i / cols), i % cols
				for dr = -1, 1 do
					for dc = -1, 1 do
						local rr, cc = r + dr, c + dc
						local j = rr * cols + cc
						if rr >= 0 and rr < rows and cc >= 0 and cc < cols and pass[j] and not comp[j] then
							comp[j] = n
							stack[#stack + 1] = j
						end
					end
				end
			end
			sizes[n] = size
		end
	end
	local votes = {}
	for _, s in ipairs(starts) do
		local c = comp[math.floor(s[2] / CELL) * cols + math.floor(s[1] / CELL)]
		if c then
			votes[c] = (votes[c] or 0) + 1
		end
	end
	local best
	for c = 1, n do
		if not best or (votes[c] or 0) > (votes[best] or 0) or ((votes[c] or 0) == (votes[best] or 0) and sizes[c] > sizes[best]) then
			best = c
		end
	end
	land = { cols = cols, rows = rows, cells = {}, onLand = {} }
	for i, c in pairs(comp) do
		if c == best then
			land.cells[#land.cells + 1] = i
			land.onLand[i] = true
		end
	end
	table.sort(land.cells) -- (pairs has no fixed order: the list must be the same on every computer)
	Spring.Echo(string.format("[Evolution] land: %d of %d cells (%d x %d Elmo) in the piece with %d of %d commanders", #land.cells, cols * rows, CELL, CELL, votes[best] or 0, #starts))
end

local function onLand(x, z)
	return not land or land.onLand[math.floor(z / CELL) * land.cols + math.floor(x / CELL)] == true
end

-- A random place on the land
local function randomLand()
	if land and #land.cells > 0 then
		local i = land.cells[math.random(1, #land.cells)]
		return (i % land.cols + math.random()) * CELL, (math.floor(i / land.cols) + math.random()) * CELL
	end
	return math.random(200, Game.mapSizeX - 200), math.random(200, Game.mapSizeZ - 200)
end

local function nearestPlayer(x, z)
	local d = math.huge
	for id in pairs(owner) do
		local ux, _, uz = Spring.GetUnitPosition(id)
		if ux then
			d = math.min(d, (ux - x) ^ 2 + (uz - z) ^ 2)
		end
	end
	return d
end

-- A random place on the land for a new unit. A player's unit (far = true): of 24 tries the one farthest from the units of the players. Otherwise the first
-- try at least minGap Elmo from every player unit (default 600: the wild units are spread over the whole land, not only at its edges)
local function spawnPoint(defID, far, minGap)
	local gap2 = (minGap or 600) ^ 2
	local best, bestD = nil, -1
	for _ = 1, 24 do
		local x, z = randomLand()
		if fits(defID, x, z) then
			local d = nearestPlayer(x, z)
			if not far and d >= gap2 then
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
	return randomLand()
end

local function remove(id)
	if id and Spring.ValidUnitID(id) then
		removing[id] = true
		Spring.DestroyUnit(id, false, true) -- no explosion, no wreck
	end
end

-- ---------------------------------------------------------------- abilities and their beacons: powerups.lua (shared with Renegade); the players are Evolution's records
local A = P.new({
	players = players, owner = owner, say = say, testing = TESTING, healMsg = "evoHeal", abilitiesRule = "evoAbilities", beaconsRule = "evoBeacons",
	-- a random place of the land where a unit can stand (10 tries)
	randomSpot = function()
		local ref = UnitDefNames.armpw
		for _ = 1, 10 do
			local x, z = randomLand()
			if not ref or fits(ref.id, x, z, false) then return x, z end
		end
	end,
	-- beacons of every ability at the start: one per 3000 x 3000 Elmo of the land and at least one per two players, 2 to 6 of each kind
	count = function()
		local area = land and (#land.cells * CELL * CELL) or (Game.mapSizeX * Game.mapSizeZ)
		return math.max(2, math.min(6, math.max(math.floor(area / (3000 * 3000) + 0.5), math.ceil((#Spring.GetTeamList() - 1) / 2)))) -- (all teams but Gaia: the players are not all joined yet)
	end,
})

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
		if (p.exp or 0) > 0 then
			Spring.SetUnitExperience(id, p.exp)
		end
		if p.ai then
			Spring.GiveOrderToUnit(id, CMD_FIRE_STATE, { RETURN_FIRE }, 0)
		end
	end
	publish()
end

-- The last alliance with a player that is not out wins (after Armageddon; only when the game began with two alliances or more)
local function checkWin()
	if finished or not armageddon then
		return
	end
	local left, n, last = {}, 0, nil
	for _, p in ipairs(players) do
		if not p.out and not left[p.ally] then
			left[p.ally] = true
			n, last = n + 1, p.ally
		end
	end
	if alliancesAtStart >= 2 and n <= 1 and last then
		finished = true
		local names = {}
		for _, p in ipairs(players) do
			if p.ally == last then
				names[#names + 1] = p.name
			end
		end
		Spring.SetGameRulesParam("evoState", "won by " .. table.concat(names, ", "))
		say(table.concat(names, ", ") .. " is the last one standing: the game is won!")
		Spring.GameOver({ last })
	end
end

-- Armageddon: the first unit on stage 10. No fog of war for anybody, no respawn any more
local function startArmageddon(p)
	armageddon = true
	for _, a in ipairs(Spring.GetAllyTeamList()) do
		pcall(Spring.SetGlobalLos, a, true)
	end
	armaFrame, hero = Spring.GetGameFrame(), p.name
	publish()
	say("Armageddon is here! " .. p.name .. " reached level 10. The fog of war is gone: everybody sees everybody.")
	say("From now on a lost unit does not come back. The last one standing wins.")
end

-- Enemies of each other: not the same alliance and not allied for the time being (the alliance against level 10, setCoalition)
local function enemies(p, q)
	return p.ally ~= q.ally and not Spring.AreTeamsAllied(p.team, q.team)
end

-- The alliance against level 10: as long as a player on level 10 is in, every alliance without such a player is allied with every other one of them
-- (Spring.SetAlly both ways); when no player on level 10 is left, everybody is on their own again. Called when a player reaches level 10 and when one is out.
-- The game is still won by the last alliance of the start (checkWin): when the players on level 10 are gone, the others fight each other.
local coalitionOn = false
local function setCoalition()
	local top, names = {}, {}
	for _, p in ipairs(players) do
		if not p.out and p.stage >= STAGES then
			top[p.ally] = true
			names[#names + 1] = p.name
		end
	end
	local on = #names > 0
	local list, seen, pairsAllied = {}, {}, 0
	for _, p in ipairs(players) do
		if not seen[p.ally] then
			seen[p.ally] = true
			list[#list + 1] = p.ally
		end
	end
	for i = 1, #list do
		for j = i + 1, #list do
			local together = on and not top[list[i]] and not top[list[j]]
			pairsAllied = pairsAllied + (together and 1 or 0)
			pcall(Spring.SetAlly, list[i], list[j], together)
			pcall(Spring.SetAlly, list[j], list[i], together)
		end
	end
	if on and pairsAllied > 0 then
		say("Everybody else is allied now against " .. table.concat(names, ", ") .. " (level 10)!")
	elseif coalitionOn then
		say("Nobody on level 10 is left: the alliance is over, everybody fights on their own again.")
	end
	coalitionOn = on and pairsAllied > 0
end

-- ---------------------------------------------------------------- the gifts of stage 10
-- Hell on Earth: strong ground units (stages 6 to 8, random factions) rise at random places of the land, far from the enemies
local hells = {} -- { p, nextAt, pending }: the players whose Hell on Earth runs
local hellOf = {} -- unitID -> the record in hells (to replace a unit that dies)
-- one random tier 3 unit (levels 8 to 10 of a random faction) somewhere on the land, the player's own
local function hellUnit(g)
	local name = stageUnit(math.random(8, 10))
	local x, z = spawnPoint(UnitDefNames[name].id, false, 900)
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, math.random(0, 3), g.p.team)
	if id then
		summoned[id] = g.p
		hellOf[id] = g
	end
end

-- Hell on Earth: HELL_UNITS tier 3 units at once; a unit that is lost is replaced by a new one somewhere (it never ends), and one more comes every
-- HELL_GAP frames (until the game is won or the player is out)
local function giftHell(p)
	local g = { p = p, nextAt = Spring.GetGameFrame() + HELL_GAP, pending = 0 }
	hells[#hells + 1] = g
	for _ = 1, HELL_UNITS do
		hellUnit(g)
	end
end

local function hellStep(n)
	for i = #hells, 1, -1 do
		local g = hells[i]
		if finished or g.p.out then
			table.remove(hells, i)
		else
			while g.pending > 0 do
				g.pending = g.pending - 1
				hellUnit(g)
			end
			if n >= g.nextAt then
				g.nextAt = n + HELL_GAP
				hellUnit(g)
			end
		end
	end
end

-- Heaven on Earth: Dragons come down on a hexagon round the player's unit
local heavens = {} -- { p, nextAt, pending, options }: the players whose Heaven on Earth runs
local heavenOf = {} -- unitID -> the record in heavens
local function dragon(g, x, z)
	x, z = math.max(50, math.min(Game.mapSizeX - 50, x)), math.max(50, math.min(Game.mapSizeZ - 50, z))
	local id = Spring.CreateUnit(g.options[math.random(1, #g.options)], x, Spring.GetGroundHeight(x, z) + 300, z, 0, g.p.team)
	if id then
		summoned[id] = g.p
		heavenOf[id] = g
	end
end

-- Heaven on Earth: HEAVEN_UNITS Dragons evenly spread on a hexagon round the unit (corners at 0, 60, 120 ... degrees, 320 Elmo from the unit); a lost one is
-- replaced by a new one near the player's unit, and one more comes at a random place every HEAVEN_GAP frames
local function giftHeaven(p)
	local options = {}
	for _, n in ipairs(GUNSHIPS) do
		if UnitDefNames[n] then
			options[#options + 1] = n
		end
	end
	local x, _, z = Spring.GetUnitPosition(p.unit or -1)
	if not x or #options == 0 then
		return giftHell(p)
	end
	local g = { p = p, nextAt = Spring.GetGameFrame() + HEAVEN_GAP, pending = 0, options = options }
	heavens[#heavens + 1] = g
	for i = 1, HEAVEN_UNITS do
		local e = (i - 1) / HEAVEN_UNITS * 6
		local k, f = math.floor(e), e - math.floor(e)
		local a1, a2 = math.rad(k * 60), math.rad((k + 1) * 60)
		local hx = math.cos(a1) * (1 - f) + math.cos(a2) * f
		local hz = math.sin(a1) * (1 - f) + math.sin(a2) * f
		dragon(g, x + hx * 320, z + hz * 320)
	end
end

local function heavenStep(n)
	for i = #heavens, 1, -1 do
		local g = heavens[i]
		if finished or g.p.out then
			table.remove(heavens, i)
		else
			local x, _, z = Spring.GetUnitPosition(g.p.unit or -1)
			while g.pending > 0 and x do
				g.pending = g.pending - 1
				local a = math.random() * 2 * math.pi
				dragon(g, x + math.cos(a) * 320, z + math.sin(a) * 320) -- (a new one near the player)
			end
			if n >= g.nextAt then
				g.nextAt = n + HEAVEN_GAP
				local rx, rz = randomLand()
				dragon(g, rx, rz)
			end
		end
	end
end

-- Gates of Hell: missiles at a growing rate (see gatesStep); a red ring warns NUKE_WARN frames before each one
local gates = {} -- { p, start, nextAt, follow = team -> frame }: the players whose Gates of Hell run
local FOLLOW_AI = (Spring.GetModOptions() or {}).lanevotest == "1" -- test only: the computer players are followed too (a test has no second human)
local GATES_PER_PLAYER = 10 -- the first barrage: this many missiles per player (not per map size), all at once
local function giftGates(p)
	local now = Spring.GetGameFrame()
	gates[#gates + 1] = { p = p, start = now, nextAt = now + 10 * FPS }
	-- the first barrage: at once (all after the warning time) at random places of the land, only not near the units of the player who chose the gate or of
	-- his alliance; the others see the rings and know what is coming
	local safe = {}
	for _, q in ipairs(players) do
		if q.ally == p.ally and q.unit and Spring.ValidUnitID(q.unit) then
			local ux, _, uz = Spring.GetUnitPosition(q.unit)
			if ux then
				safe[#safe + 1] = { ux, uz }
			end
		end
	end
	for _ = 1, math.max(20, GATES_PER_PLAYER * #players) do
		for _ = 1, 30 do
			local x, z = randomLand()
			local free = true
			for _, s in ipairs(safe) do
				if (s[1] - x) ^ 2 + (s[2] - z) ^ 2 < NUKE_SAFE ^ 2 then
					free = false
				end
			end
			if free then
				nukes[#nukes + 1] = { frame = now + NUKE_WARN, x = math.floor(x), z = math.floor(z), p = p }
				break
			end
		end
	end
end

-- Gates of Hell never ends and gets worse (after the first barrage of giftGates). Every human enemy has missiles of his own that follow him: a volley at him
-- every `interval` (10 s at the start, 3 s after four minutes) of 1 + t / 120 s missiles (one at the start, two after two minutes, then one more every two
-- minutes), at 2000 Elmo (+ up to 200) from his unit at first, 12 Elmo less per second down to 120, so they come closer and closer. Computer players are not
-- followed. Besides that one missile at a random place of the land at every volley rhythm of the gate, so the map fills up. Never within NUKE_SAFE Elmo of a unit
-- of the player who chose the gate or of his alliance.
local function gatesStep(n)
	for gi = #gates, 1, -1 do
		local g = gates[gi]
		if finished or g.p.out then
			table.remove(gates, gi)
		else
			local t = (n - g.start) / FPS
			local interval = math.floor(math.max(3, 10 - 7 * t / 240) * FPS) -- 10 s at the start, 3 s after four minutes
			local safe = {}
			for _, q in ipairs(players) do
				if q.ally == g.p.ally and q.unit and Spring.ValidUnitID(q.unit) then
					local ux, _, uz = Spring.GetUnitPosition(q.unit)
					if ux then
						safe[#safe + 1] = { ux, uz }
					end
				end
			end
			local function ok(x, z)
				for _, s in ipairs(safe) do
					if (s[1] - x) ^ 2 + (s[2] - z) ^ 2 < NUKE_SAFE ^ 2 then
						return false
					end
				end
				return x > 100 and z > 100 and x < Game.mapSizeX - 100 and z < Game.mapSizeZ - 100
			end
			local function add(x, z, k)
				nukes[#nukes + 1] = { frame = n + NUKE_WARN + (k - 1) * 20, x = math.floor(x), z = math.floor(z), p = g.p }
			end
			g.follow = g.follow or {}
			for _, q in ipairs(players) do
				if enemies(g.p, q) and (not q.ai or FOLLOW_AI) and not q.out and q.unit and Spring.ValidUnitID(q.unit) and n >= (g.follow[q.team] or 0) then
					g.follow[q.team] = n + interval
					local qx, _, qz = Spring.GetUnitPosition(q.unit)
					for k = 1, 1 + math.floor(t / 120) do
						for _ = 1, 20 do
							local d = math.max(120, 2000 - t * 12) + math.random() * 200
							local a = math.random() * 2 * math.pi
							local x, z = qx + math.cos(a) * d, qz + math.sin(a) * d
							if ok(x, z) then
								add(x, z, k)
								break
							end
						end
					end
				end
			end
			if n >= g.nextAt then
				g.nextAt = n + interval
				for _ = 1, 20 do
					local x, z = randomLand()
					if ok(x, z) then
						add(x, z, 1)
						break
					end
				end
			end
		end
	end
end

local function nukeWeapon()
	for _, n in ipairs({ "armsilo", "corsilo", "legsilo" }) do
		local ud = UnitDefNames[n]
		if ud and ud.weapons and ud.weapons[1] then
			return ud.weapons[1].weaponDef
		end
	end
end

-- A missile of Gates of Hell: falls from high above onto its target (the explosion of the game's nuclear missile)
local function launch(nk)
	local wd = nukeWeapon()
	if not wd then
		return
	end
	local y = Spring.GetGroundHeight(nk.x, nk.z)
	local src = (nk.p.unit and Spring.ValidUnitID(nk.p.unit)) and nk.p.unit or -1 -- (the kills count for the player)
	local ok, id = pcall(Spring.SpawnProjectile, wd, { pos = { nk.x, y + 2500, nk.z }, ["end"] = { nk.x, y, nk.z }, speed = { 0, -30, 0 }, owner = src, team = nk.p.team, ttl = 900 })
	if not ok or not id then
		-- (no projectile: the explosion itself)
		pcall(Spring.SpawnExplosion, nk.x, y, nk.z, 0, 0, 0, { weaponDef = wd, owner = src })
	end
end

-- Three sayings for every gift, one of them (at random) goes to the chat when the gift is chosen
local GIFT_SAYINGS = {
	{ "The earth cracks open and the dead things climb out. Run!", "Hell has no more room: it sends its giants to walk the land.", "Something enormous is breathing below your feet." },
	{ "Look to the sky: the dragons have come, flying fortresses with heavy lasers.", "The sky tears apart and the hosts of heaven fall like a hammer.", "A shadow slides over the land, and the gunships are right behind it." },
	{ "The gates of Hell are open and the fire never stops.", "Look up. Every missile you see has your name on it.", "Doomsday has no end: the sky burns and there is no shelter." },
}
local function giveGift(p, n)
	if not p.giftAt then
		return
	end
	n = (n >= 1 and n <= 3) and n or math.random(1, 3)
	p.giftAt = nil
	say(p.name .. " chose " .. GIFT_NAMES[n] .. "!")
	say(GIFT_SAYINGS[n][math.random(1, #GIFT_SAYINGS[n])])
	if n == 1 then
		giftHell(p)
	elseif n == 2 then
		giftHeaven(p)
	else
		giftGates(p)
	end
	if n <= 2 then
		p.giftEnergy = true -- (the heavy lasers of the units of the gift need energy: +R.GIFT_ENERGY per second for good)
		if FOLLOW_AI then
			Spring.Echo("[Evolution] test: gift energy +" .. R.GIFT_ENERGY .. " per second for " .. p.name)
		end
	end
	publish()
end

-- A player reaches stage 10 for the first time: Armageddon (the first one) and the choice of a gift
local function reachTop(p)
	if p.top then
		return
	end
	p.top = true
	if not armageddon then
		startArmageddon(p)
		godPlayer = p
	elseif ALL_GODS then
		say(p.name .. " reached level 10 as well.")
	else
		-- only the first one on level 10 has the special power at the end
		say(p.name .. " reached level 10 as well, but too late: the special power belongs to the first one.")
	end
	setCoalition() -- the others ally against the players on level 10
	if not ALL_GODS and p ~= godPlayer then
		return
	end
	p.giftAt = Spring.GetGameFrame()
	if p.ai then
		giveGift(p, math.random(1, 3))
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
	local ohp, omax = Spring.GetUnitHealth(old)
	owner[old] = nil
	remove(old)
	spawn(p, x, z, facing)
	if p.unit and ohp and omax and omax > 0 then
		-- level up: 20 % of the new unit's health come back, not a full heal (the health fraction of the old unit plus 20 %)
		local _, nmax = Spring.GetUnitHealth(p.unit)
		if nmax then
			Spring.SetUnitHealth(p.unit, math.min(nmax, nmax * (ohp / omax + 0.2)))
		end
	end
	if p.unit and not p.ai then
		for _, c in ipairs(cmds) do
			pcall(Spring.GiveOrderToUnit, p.unit, c.id, c.params, { "shift" })
		end
	end
	say(string.format("%s evolves to level %d: %s.", p.name, p.stage, unitTitle(p.unitName)))
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
	if p.stage >= STAGES then
		reachTop(p)
	end
	publish()
end

-- A wild unit: a stage 1 unit of a random faction, of Gaia, with wildHp(stage) of its health, at a random place; it holds its position and only shoots back
-- The number of wild units: one per 1024 x 1024 Elmo of the land (a map of 16 x 16 without water has 64), at least 12, at most 100
local function wildCount()
	local area = land and (#land.cells * CELL * CELL) or (Game.mapSizeX * Game.mapSizeZ)
	local mult = math.max(1, math.min(10, tonumber((Spring.GetModOptions() or {}).lanevomult) or 1)) -- the unit multiplier of the room (1 - 10)
	return math.floor(math.max(12, math.min(100, math.floor(area / (1024 * 1024) + 0.5))) * mult)
end

-- The stage of a new wild unit: the lowest stage of the players who are still in (the weakest player can always catch up on them)
local function wildStage()
	local low
	for _, p in ipairs(players) do
		if not p.out and (not low or p.stage < low) then
			low = p.stage
		end
	end
	return low or 1
end

-- A tower of the stage, of a random faction whose tower exists in the game
local function stageTower(s)
	local options = {}
	for _, ladder in ipairs(R.TOWERS) do
		if UnitDefNames[ladder[s]] then
			options[#options + 1] = ladder[s]
		end
	end
	return options[math.random(1, math.max(1, #options))]
end

-- The points of a wild unit of stage s: a third of what stage s needs (about three of them for the next stage), at least 1
local function wildWorth(s)
	return math.max(1, math.floor(need(s) / 3 + 0.5))
end

-- A wild unit (Gaia): of stage s (default: wildStage()), a tower with the chance R.TOWER (tower = true / false forces it), at x, z (default: a random place
-- away from the players)
local function spawnWild(s, tower, x, z, facing)
	s = s or wildStage()
	if tower == nil then
		tower = math.random() < R.TOWER
	end
	local name = tower and stageTower(s) or stageUnit(s)
	tower = tower and name ~= nil
	name = name or stageUnit(s)
	if not x then
		x, z = spawnPoint(UnitDefNames[name].id)
	end
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, facing or math.random(0, 3), Spring.GetGaiaTeamID())
	if id then
		wild[id] = { stage = s, tower = tower, still = tower or math.random() < R.STILL }
		local _, maxHp = Spring.GetUnitHealth(id)
		Spring.SetUnitHealth(id, math.max(1, (maxHp or 100) * wildHp(s))) -- (the maximum stays: the health bar shows the fraction)
		Spring.GiveOrderToUnit(id, CMD_FIRE_STATE, { RETURN_FIRE }, 0)
		Spring.GiveOrderToUnit(id, CMD_MOVE_STATE, { HOLD_POSITION }, 0)
	end
	return id
end

-- Every R.WANDER frames: a part (R.WANDER_SHARE) of the idle wild units that walk (not the towers and not the R.STILL that stand) go to a random place of the
-- land within R.WANDER_DIST
local function wanderWild()
	for id, w in pairs(wild) do
		if not w.still and math.random() < R.WANDER_SHARE and Spring.ValidUnitID(id) then
			local n = Spring.GetUnitCommands(id, 0)
			local x, _, z = Spring.GetUnitPosition(id)
			if x and type(n) == "number" and n == 0 then
				for _ = 1, 4 do
					local a, d = math.random() * 2 * math.pi, R.WANDER_DIST * (0.3 + 0.7 * math.random())
					local tx, tz = x + d * math.cos(a), z + d * math.sin(a)
					if tx > 64 and tz > 64 and tx < Game.mapSizeX - 64 and tz < Game.mapSizeZ - 64 and onLand(tx, tz) then
						Spring.GiveOrderToUnit(id, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
						break
					end
				end
			end
		end
	end
end

-- Every R.CHECK frames: as many wild units as wildCount() (living ones and those due to come back); a wild unit that is gone without UnitDestroyed is dropped
local function topUpWild()
	local n = #wildDue
	for id in pairs(wild) do
		if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then
			n = n + 1
		else
			wild[id] = nil
		end
	end
	for _ = n + 1, wildCount() do
		spawnWild()
	end
end

-- (not a unit that a player sees or that is within R.SAFE Elmo of a player's unit)
-- Every R.UPGRADE frames: one wild unit above the lowest stage of the players who are still in, or two or more below it (the weakest player
-- went down after a death) becomes one of that stage, at its place
local cloakers = {} -- unitID -> true: units that can cloak by themselves (see gadget:UnitCreated)
local function generatorsOn() -- every second: the solar collectors and wind turbines are on (a player can switch them off, but they come back on)
	for id, rd in pairs(radars) do
		if rd.name:find("sol", 1, true) or rd.name:find("win", 1, true) then
			local st = Spring.ValidUnitID(id) and Spring.GetUnitStates(id)
			if st and st.active == false then
				Spring.GiveOrderToUnit(id, CMD.ONOFF, { 1 }, 0)
			end
		end
	end
end
-- One of these (at random) goes to the chat when a player begins to show on the radar of everybody
local RADAR_SAYINGS = {
	"%s lights up every radar screen. Time to panic, and then to team up!",
	"Something big is waking up: %s is on the radar of everybody now. Run, or gang up!",
	"%s has become a beacon of doom. Everybody can see it, so everybody can hunt it.",
	"Alarm! %s is far too powerful to hide. All hands to the radar, and sharpen your teeth!",
	"The ground trembles and %s blinks on every screen. A group hug against it, maybe?",
	"Bad news in neon letters: %s is on every radar. The big bad wolf has a name now.",
}
-- On the levels R.REVEAL_STAGE to 9 the unit of a player shows on the radar and the minimap of every other ally team (the others can ally against it); not while
-- the power-up Cloak or Jammer hides it, not in Armageddon (no fog of war then). Every second; the radar and "contact" bits of the line of sight state (2 + 8) are set by Lua.
local function revealTop()
	for _, p in ipairs(players) do
		local id = p.unit
		local cloaked = false -- (the power-ups Cloak and Jammer hide the unit for a while, also on the levels with the radar signal)
		for i, a in ipairs(ABILITIES) do
			if (a.key == "cloak" or a.key == "jammer") and p.active and p.active[i] then
				cloaked = true
			end
		end
		if not cloaked then
			local want = id and not p.out and not armageddon and p.stage >= R.REVEAL_STAGE and p.stage < STAGES
			if want or (p.onRadar and id) then
				local mine = Spring.GetUnitAllyTeam(id)
				for _, a in ipairs(Spring.GetAllyTeamList()) do
					if a ~= mine then
						pcall(Spring.SetUnitLosMask, id, a, want and 10 or 0)
						if want then
							pcall(Spring.SetUnitLosState, id, a, 10)
						end
					end
				end
			end
			if want and FOLLOW_AI and Spring.GetGameFrame() % (5 * FPS) == 0 then
				for _, a in ipairs(Spring.GetAllyTeamList()) do
					if a ~= Spring.GetUnitAllyTeam(id) then
						local st = Spring.GetUnitLosState(id, a, false)
						Spring.Echo("[Evolution] test: " .. p.name .. " (level " .. p.stage .. ") on the radar of ally team " .. a .. ": " .. tostring(Spring.IsUnitInRadar(id, a)) .. " | state los " .. tostring(st and st.los) .. " radar " .. tostring(st and st.radar) .. " typed " .. tostring(st and st.typed))
					end
				end
			end
			if want and not p.onRadar then
				p.onRadar = true
				say(string.format(RADAR_SAYINGS[math.random(1, #RADAR_SAYINGS)], p.name))
			elseif not want then
				p.onRadar = nil
			end
		end
	end
end
-- Every second the unit of a player reclaims by itself the trees and wrecks within R.RECLAIM_RANGE, when no unit of an enemy player is within R.RECLAIM_ENEMY: the energy of
-- a feature (a tree) goes into the energy of the team 1 to 1, only while the storage is not full; the metal of a wreck does not go into the metal storage but heals the unit
-- 1 to 1, only while it is hurt. At most R.RECLAIM_RATE of each per second.
local function autoReclaim()
	for _, p in ipairs(players) do
		local id = p.unit
		if id and not p.out and Spring.ValidUnitID(id) then
			local x, _, z = Spring.GetUnitPosition(id)
			local enemy = false
			for _, q in ipairs(players) do
				if q.ally ~= p.ally and not q.out and q.unit then
					local qx, _, qz = Spring.GetUnitPosition(q.unit)
					if qx and (qx - x) ^ 2 + (qz - z) ^ 2 < R.RECLAIM_ENEMY ^ 2 then
						enemy = true
						break
					end
				end
			end
			if not enemy then
				local energy, store = Spring.GetTeamResources(p.team, "energy")
				local hp, maxHp = Spring.GetUnitHealth(id)
				local healRate = math.max(R.RECLAIM_HEAL_MIN, math.min(R.RECLAIM_HEAL_MAX, (maxHp or 0) * R.RECLAIM_HEAL_PERCENT)) -- (health: 1 % of the maximum health a second, 1 to RECLAIM_HEAL_MAX)
				local healed, gotE = G.reclaimFeatures(x, z, R.RECLAIM_RANGE, { health = (maxHp or 0) - (hp or 0), healthRate = healRate,
					energy = (store or 0) - (energy or 0), energyRate = R.RECLAIM_RATE })
				if gotE > 0 then
					Spring.AddTeamResource(p.team, "energy", gotE)
				end
				if healed > 0 then
					Spring.SetUnitHealth(id, math.min(maxHp, (select(1, Spring.GetUnitHealth(id)) or hp) + healed))
					if healed >= 1 then SendToUnsynced("evoHeal", id, healed) end
				end
				if FOLLOW_AI and (gotE > 0 or healed > 0) then
					Spring.Echo(string.format("[Evolution] test: %s reclaims features: energy %.0f, health %.0f", p.name, gotE, healed))
				end
			end
		end
	end
end
local function noCloak() -- the cloak order of those units is switched off every second (the game switches it on after the creation)
	for id in pairs(cloakers) do
		local st = Spring.ValidUnitID(id) and Spring.GetUnitStates(id)
		if not st then
			cloakers[id] = nil
		elseif st.cloak then
			local p = owner[id]
			local power = false
			for i, a in ipairs(ABILITIES) do
				if a.key == "cloak" and p and p.active and p.active[i] then
					power = true -- (the power-up Cloak works: leave it)
				end
			end
			if not power then
				Spring.GiveOrderToUnit(id, CMD.CLOAK, { 0 }, 0)
				pcall(Spring.SetUnitCloak, id, false) -- (the order alone did not switch it off in the test)
				if FOLLOW_AI then
					local st2 = Spring.GetUnitStates(id)
					Spring.Echo("[Evolution] test: cloak order off for " .. id .. ", state now " .. tostring(st2 and st2.cloak))
				end
			end
		end
	end
end

-- A wild unit that a player can see, or that stands within R.SAFE Elmo of a player's unit, is left as it is (no change of level in the middle of a fight)
local function watched(id, x, z)
	for _, p in ipairs(players) do
		if not p.out and p.unit then
			if Spring.IsUnitInLos(id, p.ally) then
				return true
			end
			local ux, _, uz = Spring.GetUnitPosition(p.unit)
			if ux and (ux - x) ^ 2 + (uz - z) ^ 2 < R.SAFE * R.SAFE then
				return true
			end
		end
	end
	return false
end

local wildSwapped, wildKept = 0, 0 -- (counted for the test: replaced, and left as they are because a player sees them)
local function upgradeWild()
	local low = wildStage()
	for id, w in pairs(wild) do
		if w.stage > low or low - w.stage >= 2 then -- (above the weakest player at all: he must have a chance; below: two or more)
			local x, _, z = Spring.GetUnitPosition(id)
			if x and watched(id, x, z) then
				wildKept = wildKept + 1
			elseif x then
				local facing = Spring.GetUnitBuildFacing(id)
				wild[id] = nil
				remove(id)
				spawnWild(low, w.tower, x, z, facing)
				wildSwapped = wildSwapped + 1
				if FOLLOW_AI then
					Spring.Echo(string.format("[Evolution] test: wild units replaced %d, left as they are because a player sees them %d", wildSwapped, wildKept))
				end
				return
			end
		end
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

local function commanderOf(team)
	for _, id in ipairs(Spring.GetTeamUnits(team)) do
		local ud = UnitDefs[Spring.GetUnitDefID(id)]
		if ud and ud.customParams and ud.customParams.iscommander then
			return id
		end
	end
end

-- A team whose commander is there: it becomes a player; its units are removed and its first unit stands where the commander stood (somewhere else on the
-- land when the commander stands off it, e.g. on another island)
local function join(team)
	local com = commanderOf(team)
	if not com then
		return false
	end
	local x, _, z = Spring.GetUnitPosition(com)
	for _, id in ipairs(Spring.GetTeamUnits(team)) do
		remove(id)
	end
	local p = { team = team, ally = select(6, Spring.GetTeamInfo(team, false)), stage = startStage, xp = 0, kills = 0, deaths = 0, spawns = 1, ai = not hasHuman(team), name = teamName(team) }
	players[#players + 1] = p
	byTeam[team] = p
	if onLand(x, z) then
		spawn(p, x, z)
	else
		spawn(p)
	end
	if p.stage >= STAGES then
		reachTop(p)
	end
	return true
end

local function idle(id)
	local n = Spring.GetUnitCommands(id, 0)
	return type(n) == "number" and n == 0
end

local function attackOrWalk(unitID, ally, target)
	-- an attack order needs a target the team sees (or has on the radar): otherwise the unit walks there first
	if Spring.IsUnitInLos(target, ally) or Spring.IsUnitInRadar(target, ally) then
		Spring.GiveOrderToUnit(unitID, CMD.ATTACK, { target }, 0)
	else
		local tx, _, tz = Spring.GetUnitPosition(target)
		Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
	end
end

-- The nearest unit of the list (unitID -> anything) for which want(record) is true
local function nearest(x, z, list, want)
	local best, bestD = nil, math.huge
	for id, rec in pairs(list) do
		if want(rec) then
			local ux, _, uz = Spring.GetUnitPosition(id)
			local d = ux and (ux - x) ^ 2 + (uz - z) ^ 2
			if d and d < bestD then
				best, bestD = id, d
			end
		end
	end
	return best, bestD
end

-- Computer teams: the unit attacks the nearest enemy player unit of its own stage or higher (at stage 1 also the wild units, they are stage 1; in
-- Armageddon every enemy player unit); with nothing to attack it walks to a random place. The units of its gifts attack the nearest enemy player unit.
local function steer(p)
	local x, _, z = Spring.GetUnitPosition(p.unit)
	if not x then
		return
	end
	local best, bestD = nearest(x, z, owner, function(q) return enemies(p, q) and (armageddon or q.stage >= p.stage) end)
	if not armageddon then
		-- wild units of its own stage or lower (they give points)
		local w, wd = nearest(x, z, wild, function(rec) return rec.stage <= p.stage end)
		if w and wd < bestD then
			best = w
		end
	end
	A.ai(p, best)
	-- radars and collectors: as long as its team holds fewer than its share (all of them divided by the players, at least 2) the nearest one that is not its
	-- team's comes first unless an enemy player unit is within 600 Elmo; it stands within the range until the radar is taken (R.TAKE), then the next one
	local owned, total = 0, 0
	for _, rd in pairs(radars) do
		total = total + 1
		if rd.team == p.team then
			owned = owned + 1
		end
	end
	local r, d
	if owned < math.max(2, math.ceil(total / math.max(1, #players))) then
		r, d = nearest(x, z, radars, function(rd) return rd.team ~= p.team and not Spring.AreTeamsAllied(rd.team, p.team) end)
	end
	local urgent = best and bestD < 600 * 600 and owner[best]
	if r and not urgent then
		if d <= (R.RANGE * 0.6) ^ 2 then
			if not idle(p.unit) then
				Spring.GiveOrderToUnit(p.unit, CMD.STOP, {}, 0)
			end
		elseif idle(p.unit) or p.goal ~= r then
			local rx, _, rz = Spring.GetUnitPosition(r)
			p.goal = r
			Spring.GiveOrderToUnit(p.unit, CMD.MOVE, { rx, Spring.GetGroundHeight(rx, rz), rz }, 0)
		end
	elseif best then
		p.goal = nil
		attackOrWalk(p.unit, p.ally, best)
	elseif idle(p.unit) then
		local tx, tz = randomLand()
		Spring.GiveOrderToUnit(p.unit, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
	end
end

local function steerSummoned()
	for id, p in pairs(summoned) do
		if p.ai and Spring.ValidUnitID(id) then
			local x, _, z = Spring.GetUnitPosition(id)
			local target = x and nearest(x, z, owner, function(q) return enemies(p, q) end)
			if target then
				attackOrWalk(id, p.ally, target)
			end
		end
	end
end

-- Every second: R.ENERGY_BASE + R.ENERGY per level for every player team that is still in, and a storage of at least R.STORE (the commanders and their storage are gone)
local function giveEnergy()
	for _, p in ipairs(players) do
		if not p.out then
			local _, store = Spring.GetTeamResources(p.team, "energy")
			local want = (p.stage >= STAGES or LONG_RANGE) and R.STORE_BIG or R.STORE -- (2000 on level 10 as a bonus for the big beam weapons, and with the option Long range)
			if (store or 0) < want then
				Spring.SetTeamResource(p.team, "es", want)
			end
			Spring.AddTeamResource(p.team, "energy", R.ENERGY_BASE + R.ENERGY * p.stage + (p.giftEnergy and R.GIFT_ENERGY or 0))
		end
	end
end

-- A radar of the game (Gaia at first): neutral (nobody shoots at it on its own), cannot be destroyed (UnitPreDamaged, and GG.Indestructible of
-- unit_indestructible.lua against reclaiming)
local function newRadar(name, x, z, team)
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, 0, team)
	if id then
		Spring.SetUnitNeutral(id, true)
		radars[id] = { team = team, name = name }
		if GG.Indestructible then
			GG.Indestructible[id] = true
		end
	end
	return id
end

-- At the start: radars until R.COVER of the land is in their range. Each new one stands in a random cell that no radar reaches yet: they keep their distance
-- (a circle of the radar's range around each) and cover the land evenly
local function placeRadars()
	local kinds = {}
	for _, name in ipairs(R.RADAR1) do
		if UnitDefNames[name] then
			kinds[#kinds + 1] = name
		end
	end
	if not land or #land.cells == 0 or #kinds == 0 then
		return
	end
	local ud = UnitDefNames[kinds[1]]
	local range = ud.radarDistance or ud.radarRadius or 2100
	local covered, skip, left, count = {}, {}, #land.cells, 0
	local goal = math.floor(#land.cells * (1 - R.COVER))
	local gaia = Spring.GetGaiaTeamID()
	while left > goal and count < R.MAX_RADARS do
		local open = {}
		for _, i in ipairs(land.cells) do
			if not covered[i] and not skip[i] then
				open[#open + 1] = i
			end
		end
		if #open == 0 then
			break
		end
		local i = open[math.random(1, #open)]
		local name = kinds[math.random(1, #kinds)]
		local px, pz
		for _ = 1, 8 do
			local x, z = (i % land.cols + math.random()) * CELL, (math.floor(i / land.cols) + math.random()) * CELL
			if fits(UnitDefNames[name].id, x, z) then
				px, pz = x, z
				break
			end
		end
		if px and newRadar(name, px, pz, gaia) then
			count = count + 1
			for _, j in ipairs(land.cells) do
				if not covered[j] and ((j % land.cols + 0.5) * CELL - px) ^ 2 + ((math.floor(j / land.cols) + 0.5) * CELL - pz) ^ 2 <= range * range then
					covered[j] = true
					left = left - 1
				end
			end
		else
			skip[i] = true
		end
	end
	Spring.Echo(string.format("[Evolution] %d radars (range %d), %d of %d land cells in range", count, range, #land.cells - left, #land.cells))
end

-- Every half second (step frames): a radar with units of exactly one alliance of players within R.RANGE, not its owner's, is being taken; after R.TAKE frames
-- it belongs to the team of the unit that began. The progress goes to the game rule evoTaking ("x,z,seconds,team" separated by /) for the display.
local function takeRadars(step)
	local gaia = Spring.GetGaiaTeamID()
	local shown = {}
	for id, rd in pairs(radars) do
		local x, _, z = Spring.GetUnitPosition(id)
		if not x then
			radars[id] = nil
		else
			local here, allies = {}, 0
			for _, uid in ipairs(Spring.GetUnitsInCylinder(x, z, R.RANGE)) do
				local p = owner[uid] or summoned[uid]
				if p and not p.out and not here[p.ally] then
					here[p.ally] = p
					allies = allies + 1
				end
			end
			local ownerAlly = rd.team ~= gaia and select(6, Spring.GetTeamInfo(rd.team, false))
			local taker
			if allies == 1 then
				for ally, p in pairs(here) do
					if ally ~= ownerAlly then
						taker = p
					end
				end
			end
			if not taker then
				rd.take = nil
			else
				if not rd.take or rd.take.team ~= taker.team then
					rd.take = { team = taker.team, frames = 0 }
				end
				rd.take.frames = rd.take.frames + step
				if rd.take.frames >= R.TAKE then
					Spring.TransferUnit(id, taker.team, false)
					Spring.SetUnitNeutral(id, true)
					rd.team, rd.take = taker.team, nil
					say(taker.name .. " took " .. ((rd.name:find("sol", 1, true)) and "a solar collector" or (rd.name:find("win", 1, true) and "a wind turbine" or "a radar")) .. ".")
				else
					shown[#shown + 1] = string.format("%d,%d,%d,%d", x, z, math.floor(rd.take.frames / FPS), taker.team)
				end
			end
		end
	end
	Spring.SetGameRulesParam("evoTaking", table.concat(shown, "/"))
end

-- As soon as one player who is still in is on stage R.T2_STAGE or higher the radars, solar collectors and wind turbines become the T2 versions (every R.UPGRADE
-- frames one, at its place, for the same owner); when no player is on that stage any more they go back to T1. Only a building that no player sees (see
-- watched) is changed.
local function upgradeRadars()
	local high = false
	for _, p in ipairs(players) do
		if not p.out and p.stage >= R.T2_STAGE then
			high = true
		end
	end
	for id, rd in pairs(radars) do
		local to = high and R.RADAR2[rd.name] or (not high and R.BACK1[rd.name])
		local x, _, z = Spring.GetUnitPosition(id)
		if to and UnitDefNames[to] and x and not watched(id, x, z) then
			radars[id] = nil
			if GG.Indestructible then
				GG.Indestructible[id] = nil
			end
			remove(id)
			newRadar(to, x, z, rd.team)
			if FOLLOW_AI then
				Spring.Echo("[Evolution] test: building " .. rd.name .. " -> " .. to)
			end
			return
		end
	end
end

-- The radars of a player who is out go back to Gaia (nobody's)
-- At the start: neutral solar collectors and wind turbines of level 1 (a random faction each) at random places of the land, at least 300 Elmo apart; they
-- cannot be destroyed and are taken like the radars (the same table radars): then they give their energy to the team that took them
local function placeGenerators()
	local kinds = {}
	for _, name in ipairs(R.GENERATORS) do
		if UnitDefNames[name] then
			kinds[#kinds + 1] = name
		end
	end
	if not land or #land.cells == 0 or #kinds == 0 then
		return
	end
	local area = #land.cells * CELL * CELL
	local want = math.max(R.GEN_MIN, math.min(R.GEN_MAX, math.floor(area / (R.GEN_AREA * R.GEN_AREA) + 0.5)))
	local placed, gaia = {}, Spring.GetGaiaTeamID()
	for _ = 1, want * 10 do
		if #placed >= want then
			break
		end
		local name = kinds[math.random(1, #kinds)]
		local x, z = randomLand()
		local free = fits(UnitDefNames[name].id, x, z)
		for _, q in ipairs(placed) do
			if free and (q[1] - x) ^ 2 + (q[2] - z) ^ 2 < 300 * 300 then
				free = false
			end
		end
		if free and newRadar(name, x, z, gaia) then
			placed[#placed + 1] = { x, z }
		end
	end
	Spring.Echo(string.format("[Evolution] %d solar collectors and wind turbines", #placed))
end

local function freeRadars(p)
	local gaia = Spring.GetGaiaTeamID()
	for id, rd in pairs(radars) do
		if rd.team == p.team then
			Spring.TransferUnit(id, gaia, false)
			Spring.SetUnitNeutral(id, true)
			rd.team, rd.take = gaia, nil
		end
	end
end

function gadget:GameFrame(n)
	if n >= START_AFTER and n <= START_UNTIL and n % 15 == 0 then
		local gaia = Spring.GetGaiaTeamID()
		if not land then
			local starts = {}
			for _, team in ipairs(Spring.GetTeamList()) do
				local com = team ~= gaia and commanderOf(team)
				if com then
					local x, _, z = Spring.GetUnitPosition(com)
					starts[#starts + 1] = { x, z }
				end
			end
			if #starts > 0 then
				buildLand(starts)
			end
		end
		for _, team in ipairs(Spring.GetTeamList()) do
			if land and team ~= gaia and not byTeam[team] then
				local _, _, dead = Spring.GetTeamInfo(team, false)
				if not dead and join(team) and not running then
					running = true
					for _ = 1, wildCount() do
						spawnWild()
					end
					placeRadars()
					placeGenerators()
					for kind = 1, #ABILITIES do
						for _ = 1, A.count() do
							A.place(kind)
						end
					end
					A.publish()
					say(string.format("Evolution: kill to evolve (10 levels, a random faction each time); a lost unit comes back 5 s later at another place, one level lower. %d wild units and towers only shoot back; they grow with the players. Stand next to a radar for 5 s to take it; drive over a glowing beacon to get an ability. Level 10 brings Armageddon.", wildCount()))
				end
			end
		end
		local allies = {}
		alliancesAtStart = 0
		for _, p in ipairs(players) do
			if not allies[p.ally] then
				allies[p.ally] = true
				alliancesAtStart = alliancesAtStart + 1
			end
		end
		publish()
	end
	if not running then
		return
	end
	if n % FPS == 0 then
		giveEnergy()
	end
	if n % R.CHECK == 0 then
		topUpWild()
	end
	if n % R.WANDER == 75 then
		wanderWild()
	end
	if n % R.UPGRADE == 0 then
		upgradeWild()
		upgradeRadars()
	end
	if REGEN_ON and n % REGEN_STEP == 0 then
		-- the units regenerate: REGEN of the health every REGEN_STEP frames, not for REGEN_WAIT frames after the last damage
		for _, p in ipairs(players) do
			local id = p.unit
			if id and not p.out and n - (p.hurtAt or -REGEN_WAIT) >= REGEN_WAIT and Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then
				local hp, maxHp = Spring.GetUnitHealth(id)
				if hp and maxHp and hp < maxHp then
					Spring.SetUnitHealth(id, math.min(maxHp, hp + maxHp * REGEN))
				end
			end
		end
	end
	if n % FPS == 0 then
		noCloak()
		generatorsOn()
		revealTop()
		autoReclaim()
	end
	if n % 15 == 0 then
		takeRadars(15)
		A.update(n)
		for _, p in ipairs(players) do
			if p.respawnAt and n >= p.respawnAt and not p.out then
				spawn(p)
			end
			if p.giftAt and n - p.giftAt >= GIFT_WAIT then
				giveGift(p, 0) -- (no choice: a random gift)
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
		-- Gates of Hell: new volleys, launch what is due, show the rings of the next ones
		gatesStep(n)
		hellStep(n)
		heavenStep(n)
		local left, rings = {}, {}
		for _, nk in ipairs(nukes) do
			if n >= nk.frame then
				launch(nk)
			else
				left[#left + 1] = nk
				if nk.frame - n <= NUKE_WARN and #rings < 250 then
					rings[#rings + 1] = nk.x .. "," .. nk.z
				end
			end
		end
		nukes = left
		Spring.SetGameRulesParam("evoNukes", table.concat(rings, "/"))
		Spring.SetGameRulesParam("evoArmageddon", armaFrame)
		Spring.SetGameRulesParam("evoHero", hero)
	end
	if n % 90 == 45 then
		for _, p in ipairs(players) do
			if p.ai and p.unit and Spring.ValidUnitID(p.unit) then
				steer(p)
			end
		end
		steerSummoned()
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	summoned[unitID] = nil
	if hellOf[unitID] then
		hellOf[unitID].pending = hellOf[unitID].pending + 1 -- (a lost unit of Hell on Earth is replaced)
		hellOf[unitID] = nil
	end
	if heavenOf[unitID] then
		heavenOf[unitID].pending = heavenOf[unitID].pending + 1
		heavenOf[unitID] = nil
	end
	radars[unitID] = nil
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
	if killer and killer ~= victim and (wasWild or enemies(killer, victim)) then
		if not wasWild then
			killer.kills = killer.kills + 1
			killer.exp = (killer.exp or 0) + EXP_STEP -- (the experience of the unit: kept when the unit evolves)
			if killer.unit and Spring.ValidUnitID(killer.unit) then
				Spring.SetUnitExperience(killer.unit, killer.exp)
			end
		end
		-- catching up: a player below the best one gets more (R.CATCH_UP per stage below it)
		local best = killer.stage
		for _, q in ipairs(players) do
			if not q.out and q.stage > best then
				best = q.stage
			end
		end
		local base = wasWild and wildWorth(wasWild.stage) or worth(victim.stage, killer.stage)
		gain(killer, math.floor(base * (1 + R.CATCH_UP * (best - killer.stage)) + 0.5))
	end
	if wasWild then
		wildDue[#wildDue + 1] = Spring.GetGameFrame() + WILD_BACK
		return
	end
	victim.unit, victim.xp = nil, 0
	victim.deaths = victim.deaths + 1
	victim.exp = math.max(0, (victim.exp or 0) - EXP_STEP) -- (a death costs the same experience)
	A.lose(victim) -- the abilities are gone with the unit
	A.publish()
	if armageddon then
		-- no respawn any more: the player is out, the units of its gifts go with it
		victim.out = true
		victim.giftAt = nil
		freeRadars(victim)
		setCoalition() -- (when the last player on level 10 is out, the alliance against level 10 ends)
		for id, p in pairs(summoned) do
			if p == victim then
				summoned[id] = nil
				if Spring.ValidUnitID(id) then
					Spring.DestroyUnit(id, true, false)
				end
			end
		end
		say(victim.name .. " is out.")
	else
		victim.stage = math.max(1, victim.stage - 1)
		victim.respawnAt = Spring.GetGameFrame() + RESPAWN
	end
	publish()
	checkWin()
end

-- The gift of a player on stage 10: "evo|gift|<1..3>" from the game widget evo_gift.lua of that player
-- debug mode (the star button) and the test hook: random values for every player that is in (level 1 to 9 with its unit, points, power-ups, experience, kills
-- and deaths), so the overview can be photographed
local function randomize()
	for _, q in ipairs(players) do
		if not q.out and q.unit and Spring.ValidUnitID(q.unit) then
			q.stage, q.xp = math.random(1, STAGES - 1), 0
			q.xp = math.random(0, math.max(0, need(q.stage) - 1))
			q.exp = math.random(0, 15) / 10
			q.kills, q.deaths = math.random(0, 14), math.random(0, 9)
			q.abilities = {}
			for i = 1, #ABILITIES do
				q.abilities[i] = math.random() < 0.5
			end
			evolve(q)
			Spring.SetUnitExperience(q.unit or -1, q.exp)
		end
	end
	A.publish()
	publish()
end

local test = {} -- (test only)
function gadget:RecvLuaMsg(msg, playerID)
	local kind, n = msg:match("^evo|(%a+)|(%d+)$")
	if kind == "test" and (Spring.GetModOptions() or {}).lanevotest == "1" then
		-- test only (game option lanevotest=1): "evo|test|1" gives the player all abilities, "evo|test|2" logs whether its unit is cloaked
		local _, _, _, team = Spring.GetPlayerInfo(playerID, false)
		local p = team and byTeam[team]
		if p and n == "1" then
			p.abilities = {}
			for i = 1, #ABILITIES do p.abilities[i] = true end
			Spring.AddTeamResource(p.team, "energy", 1000) -- (the abilities cost energy)
			A.publish()
		elseif p and n == "5" then
			randomize()
		elseif p and p.unit and n == "4" then
			gain(p, 1000000) -- (level 10 at once: Armageddon, for the pictures of the manual)
		elseif p and p.unit and n == "6" then
			-- the unit is hurt (30 % health) and a wreck lies next to it (the automatic reclaim must heal it)
			local hp, maxHp = Spring.GetUnitHealth(p.unit)
			Spring.SetUnitHealth(p.unit, maxHp * 0.3)
			local x, _, z = Spring.GetUnitPosition(p.unit)
			local fid = Spring.CreateFeature("armpw_dead", x + 40, Spring.GetGroundHeight(x + 40, z + 40), z + 40)
			Spring.Echo("[Evolution] test: hurt to 30 %, wreck " .. tostring(fid))
		elseif p and n == "7" then
			-- every other player reaches level 10 (to see who may choose a gift)
			for _, q in ipairs(players) do
				if q ~= p and q.unit and not q.out and q.stage < STAGES then
					gain(q, 1000000)
				end
			end
		elseif p and p.unit and n == "3" then
			-- an enemy unit next to the player's unit sees it (or not, when it is hidden)
			local x, _, z = Spring.GetUnitPosition(p.unit)
			for _, q in ipairs(players) do
				if q.ally ~= p.ally then
					test.spy = Spring.CreateUnit("armpw", x + 120, Spring.GetGroundHeight(x + 120, z), z, 0, q.team)
					test.spyAlly = Spring.GetTeamAllyTeamID(q.team)
					Spring.SetGameRulesParam("evoTestSpy", test.spy or 0, { public = true })
					break
				end
			end
		elseif p and p.unit then
			local ud = UnitDefs[Spring.GetUnitDefID(p.unit)]
			local los = test.spy and Spring.GetUnitLosState(p.unit, test.spyAlly, false)
			Spring.Echo("[Evolution] test: spy " .. tostring(test.spy) .. " sees " .. (los and ("los " .. tostring(los.los) .. " radar " .. tostring(los.radar)) or "?") .. " | " .. ud.name .. " canCloak " .. tostring(ud.canCloak) .. " cloaked " .. tostring(Spring.GetUnitIsCloaked(p.unit)) .. " stealth " .. tostring(Spring.GetUnitStealth and Spring.GetUnitStealth(p.unit)))
		end
		return true
	end
	if kind == "debug" and (Spring.GetModOptions() or {}).lanevodebug == "1" then
		-- debug mode: 1 = Armageddon (level 10 at once), 2 = one level up (level 10 brings Armageddon), 3 = one level down (not below 1), 4 = XP up, 5 = XP down (0.1 each), 6 to 10 = that power-up
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		local p = team and not spec and byTeam[team]
		if p and not p.out and p.unit then
			if n == "11" then
				randomize() -- (the star button)
			elseif tonumber(n) >= 6 and ABILITIES[tonumber(n) - 5] then
				p.abilities = p.abilities or {}
				local ai = tonumber(n) - 5 -- (the power-up buttons of the debug mode: the ability, and when it is there already, ready again: no cooldown)
				p.abilities[ai] = true
				if p.cool then
					p.cool[ai] = nil
				end
				A.publish()
			elseif n == "4" or n == "5" then
				p.exp = math.max(0, (p.exp or 0) + (n == "4" and EXP_STEP or -EXP_STEP)) -- (XP up / down)
				Spring.SetUnitExperience(p.unit, p.exp)
				publish()
			elseif n == "1" or n == "2" then
				if p.stage < STAGES then
					gain(p, n == "1" and 1000000 or need(p.stage))
				end
			elseif p.stage > 1 then
				p.stage, p.xp = p.stage - 1, 0
				evolve(p)
				publish()
			end
		end
		return true
	end
	if kind ~= "gift" and kind ~= "use" then
		return false
	end
	local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
	local p = team and not spec and byTeam[team]
	if p and kind == "gift" then
		giveGift(p, tonumber(n))
	elseif p then
		A.use(p, tonumber(n)) -- a button of the bar of abilities (the unsynced part)
	end
	return true
end

-- orders that only switch a state: they stay allowed for every unit
local STATES = { [CMD_FIRE_STATE] = true, [CMD_MOVE_STATE] = true, [CMD.REPEAT] = true, [CMD.IDLEMODE] = true }

-- The unit of a player cannot destroy itself (it would come back elsewhere at once) and is not given away; the units of a computer team only take the
-- orders of this gadget (the AI of the team would steer them otherwise)
-- A unit that can cloak by itself (Gremlin, Sharpshooter) does not: cloaking is only the power-up (the cloak order of the unit is switched off, again and again
-- every second because the game switches it on after the creation, and the order cannot be switched on; the power-up uses SetUnitCloak and is not affected)
function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local ud = UnitDefs[unitDefID]
	if ud and ud.canCloak then
		cloakers[unitID] = true
		Spring.GiveOrderToUnit(unitID, CMD.CLOAK, { 0 }, 0)
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD.CLOAK and (cmdParams[1] or 0) ~= 0 and not fromLua then
		return false
	end
	if cmdID == CMD.ONOFF and radars[unitID] and (cmdParams[1] or 1) == 0 then
		return false -- (the solar collectors and wind turbines stay on)
	end
	local p = owner[unitID] or summoned[unitID]
	if not p then
		return true
	end
	if cmdID == CMD.SELFD and owner[unitID] then
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

-- the radars cannot be destroyed (also not by the missiles of Gates of Hell); a wild tower does only R.TOWER_DAMAGE of its damage
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID)
	local hurt = owner[unitID]
	if hurt and damage > 0 then
		hurt.hurtAt = Spring.GetGameFrame() -- (the regeneration waits REGEN_WAIT after the last hit)
	end
	if radars[unitID] then
		return 0, 0
	end
	local w = attackerID and wild[attackerID]
	if w and w.tower then
		return damage * R.TOWER_DAMAGE, 1
	end
end

function gadget:Initialize()
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- otherwise the engine registers it and warns
	end
	Spring.SetGameRulesParam("evoState", "")
	Spring.SetGameRulesParam("evoArmageddon", 0)
	Spring.SetGameRulesParam("evoNukes", "")
	Spring.SetGameRulesParam("evoTaking", "")
	Spring.SetGameRulesParam("evoBeacons", "")
end
