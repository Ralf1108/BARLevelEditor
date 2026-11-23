-- Mock test of LevelEditor/scripts/td_waves.lua (the waves of Tower Defense) outside the game: the gadget is loaded with a fake engine and plays
-- small games: the payload of the editor (tdw|start), the waves and their spawn queue, the route of a unit, an enemy that gets through, a kill and
-- its payment, won and lost, a stuck unit, Stop, and the build rule (only towers; economy and radar by the settings; other teams are free).
-- REPO (set by mock_test.py): the folder of the repository. check(cond, text), ok(text): see mock_test.py.
local frame = 0
local units, nextId = {}, 100 -- id -> { name, x, z, team, orders = { {x, z}, ... } }
local rules, said, added, refused = {}, {}, { metal = 0, energy = 0 }, {}

-- the unit definitions of this world: two walking units for the waves (a bot of Armada), one anti-air bot (never in a wave), structures for the build rule
WeaponDefs = { [1] = { canAttackGround = true }, [2] = { canAttackGround = false } }
local function def(id, name, t)
	t.id, t.name, t.customParams = id, name, t.customParams or {}
	t.weapons = t.weapons or {}
	return t
end
local bot = { canMove = true, speed = 60, moveDef = { name = "bot2" }, weapons = { { weaponDef = 1 } }, metalCost = 50, energyCost = 700 }
UnitDefs = {
	[1] = def(1, "armpw", bot),
	[2] = def(2, "armjeth", { canMove = true, speed = 60, moveDef = { name = "bot2" }, weapons = { { weaponDef = 2 } } }),
	[3] = def(3, "armllt", { weapons = { { weaponDef = 1 } } }), -- a tower
	[4] = def(4, "armsolar", { customParams = { unitgroup = "energy" } }), -- economy
	[5] = def(5, "armrad", { radarDistance = 2000 }), -- a radar
	[6] = def(6, "armlab", { isFactory = true, canMove = true }), -- a factory
	[7] = def(7, "armcom", { canMove = true, speed = 30, customParams = { iscommander = "1" }, weapons = { { weaponDef = 1 } }, isBuilder = true }),
}
UnitDefNames = {}
for _, ud in pairs(UnitDefs) do UnitDefNames[ud.name] = ud end

CMD = { MOVE = 10, BUILD = -1, INSERT = 1, ANY = 0 }
GG = {}
gadget = {}
gadgetHandler = { IsSyncedCode = function() return true end, RegisterAllowCommand = function() end }
VFS = { ZIP_FIRST = 1, Include = function(path)
	local name = path:match("([^/]+)$")
	return dofile(REPO .. (name == "led_gadgets.lua" and "/LevelEditor/scripts/" or "/shared/") .. name)
end }
Spring = setmetatable({
	GetModOptions = function() return { leveleditor = "1" } end, -- the editor: messages need no cheat, no GameOver
	GetGameFrame = function() return frame end,
	GetGaiaTeamID = function() return 9 end,
	GetTeamList = function() return { 0, 1, 2 } end,
	GetTeamInfo = function(team) return team, 0, false, team == 1, "arm", team == 1 and 1 or 0 end, -- team 1 is the computer (ally team 1); 0 and 2 are humans of ally team 0
	GetTeamUnits = function(team)
		local out = {}
		for id, u in pairs(units) do if u.team == team then out[#out + 1] = id end end
		return out
	end,
	GetUnitDefID = function(id) return units[id] and UnitDefNames[units[id].name].id end,
	ValidUnitID = function(id) return units[id] ~= nil end,
	DestroyUnit = function(id) units[id] = nil end,
	CreateUnit = function(name, x, y, z, facing, team)
		nextId = nextId + 1
		units[nextId] = { name = name, x = x, z = z, team = team, orders = {} }
		return nextId
	end,
	GetUnitHealth = function() return 100, 100 end,
	GetUnitPosition = function(id) local u = units[id]; if u then return u.x, 0, u.z end end,
	GetGroundHeight = function() return 0 end,
	GiveOrderToUnit = function(id, cmd, params, opts)
		local u = units[id]
		if type(opts) ~= "table" then u.orders = {} end -- (not shift: a new queue)
		u.orders[#u.orders + 1] = { params[1], params[3] }
	end,
	SetGameRulesParam = function(k, v) rules[k] = v end,
	AddTeamResource = function(team, kind, n) added[kind] = added[kind] + n end,
	SendMessage = function(t) said[#said + 1] = t end,
	SendMessageToTeam = function(team, t) refused[#refused + 1] = t end,
	Echo = function(t) said[#said + 1] = tostring(t) end,
	IsCheatingEnabled = function() return false end,
}, { __index = function() return function() end end })

dofile(REPO .. "/LevelEditor/scripts/td_waves.lua")
gadget:Initialize()
check(rules.tdState == "", "no game at the start: tdState is empty")

local function run(to)
	while frame < to do
		frame = frame + 1
		gadget:GameFrame(frame)
	end
end
local function waveUnits()
	local out = {}
	for id, u in pairs(units) do if u.team == 1 then out[#out + 1] = id end end
	table.sort(out)
	return out
end
-- enemy team 1, player team 0, spawn 100,100, goal 2000,100, 1 enemy may get through, two waypoints, two waves of Armada bots T1:
-- 3 units after 2 s at 50 % health, 2 units 4 s later; only towers; no fog; start resources 500 / 2000
local PAYLOAD = "1;0;100;100;2000;100;1;500,100/1000,400;arm,b,1,3,2,50/arm,b,1,2,4,100;towers;0;500;2000"

-- ---------------------------------------------------------------- a payload that is not usable
gadget:RecvLuaMsg("tdw|start|1;0;100;100;2000;100;1;-;", 0)
check(rules.tdState == "" and #said >= 1 and said[#said]:find("Cannot start", 1, true), "a payload without a wave does not start a game and says why")
check(gadget:RecvLuaMsg("xyz|start|1", 0) == false, "a message of another gadget is not taken")
ok("messages")

-- ---------------------------------------------------------------- start, the waves, the route
units[50] = { name = "armcom", x = 0, z = 0, team = 0, orders = {} }
gadget:RecvLuaMsg("tdw|start|" .. PAYLOAD, 0)
check(rules.tdState == "running" and rules.tdWaves == 2 and rules.tdWave == 0 and rules.tdMaxLeaks == 1, "the game runs: 2 waves, none yet, 1 leak allowed")
check(units[50] == nil, "the commander of the player is removed")
run(59)
check(#waveUnits() == 0, "nothing spawns before the gap of the first wave (2 s)")
run(60 + 12 * 3)
local w = waveUnits()
check(rules.tdWave == 1 and #w == 3, "wave 1: three units, one every 12 frames: " .. #w)
local u = units[w[1]]
check(u.name == "armpw", "the wave takes the bot that hits the ground, never the anti-air bot: " .. u.name)
check(math.abs(u.x - 100) <= 24 and math.abs(u.z - 100) <= 24, "it appears at the spawn point (24 around it)")
check(#u.orders == 3 and u.orders[1][1] == 500 and u.orders[2][1] == 1000 and u.orders[3][1] == 2000, "its route: the two waypoints, then the goal")
check(rules.tdAlive == 3, "tdAlive counts them")
ok("start and wave 1")

-- ---------------------------------------------------------------- a kill pays, a unit at the goal counts as got through
gadget:UnitDestroyed(w[1], 1, 1, nil)
units[w[1]] = nil
check(rules.tdKilled == 1 and added.metal == 50 and added.energy == 700, "a kill pays the cost of the unit to the player (50 metal, 700 energy)")
units[w[2]].x, units[w[2]].z = 1950, 100
run(frame + 10)
check(rules.tdLeaks == 1 and units[w[2]] == nil and rules.tdState == "running", "a unit within 120 of the goal got through and is removed; 1 of 1 is still allowed")
ok("kill and leak")

-- ---------------------------------------------------------------- wave 2, then all dead: won
run(60 + 4 * 30 + 12 * 2 + 1)
check(rules.tdWave == 2 and #waveUnits() == 3, "wave 2 comes 4 s after wave 1: two more units")
for _, id in ipairs(waveUnits()) do
	gadget:UnitDestroyed(id, 1, 1, nil)
	units[id] = nil
end
run(frame + 10)
check(rules.tdState == "won" and rules.tdKilled == 4, "all waves out and every unit dead: won (4 killed)")
ok("wave 2 and won")

-- ---------------------------------------------------------------- lost: more got through than allowed
gadget:RecvLuaMsg("tdw|start|" .. PAYLOAD, 0)
local t0 = frame
run(t0 + 60 + 12 * 3)
for _, id in ipairs(waveUnits()) do units[id].x = 2000 end
run(frame + 10)
check(rules.tdState == "lost" and rules.tdLeaks >= 2, "two got through, one was allowed: lost")
ok("lost")

-- ---------------------------------------------------------------- a stuck unit gets its route again, then it is removed
gadget:RecvLuaMsg("tdw|start|" .. PAYLOAD, 0)
t0 = frame
run(t0 + 60 + 12)
local s = waveUnits()[#waveUnits()]
units[s].x, units[s].z = 900, 380 -- near the second waypoint
run(t0 + 60 + 12 + 30 * 30 + 20) -- (the first check after 30 s: it has moved, nothing happens)
check(#units[s].orders == 3, "a unit that moved keeps its route")
units[s].orders = {}
run(frame + 30 * 30)
check(units[s] and #units[s].orders == 2 and units[s].orders[1][1] == 1000, "a unit that did not move for 30 s gets its route again from the nearest waypoint on")
run(frame + 3 * 30 * 30)
check(units[s] == nil, "after two new routes without moving it is removed")
gadget:RecvLuaMsg("tdw|stop", 0)
check(rules.tdState == "" and #waveUnits() == 0, "Stop: no game, the units of the waves are gone")
ok("stuck and Stop")

-- ---------------------------------------------------------------- the build rule
check(gadget:AllowCommand(1, 7, 0, -3, {}) == true, "no game: every build order is allowed")
gadget:RecvLuaMsg("tdw|start|" .. PAYLOAD, 0)
check(gadget:AllowCommand(1, 7, 0, -3, {}) == true, "towers only: a tower is allowed")
check(gadget:AllowCommand(1, 7, 0, -4, {}) == false and #refused == 1 and refused[1]:find("only towers may be built", 1, true), "towers only: a solar collector is refused, with a message to the team")
check(gadget:AllowCommand(1, 7, 0, -5, {}) == false, "no fog of war: a radar is refused")
check(gadget:AllowCommand(1, 7, 0, -6, {}) == false, "a factory is refused")
check(gadget:AllowCommand(1, 7, 0, CMD.INSERT, { 0, -4, 0 }) == false, "an inserted build order is refused, too")
check(gadget:AllowCommand(1, 7, 2, -4, {}) == false, "the rule holds for every human of the player's alliance (team 2)")
check(gadget:AllowCommand(1, 7, 1, -4, {}) == true, "the computer team builds what it wants")
check(gadget:AllowCommand(1, 7, 0, -1, {}) == true and gadget:AllowCommand(1, 7, 0, CMD.MOVE, {}) == true, "units and other orders are not restricted")
gadget:RecvLuaMsg("tdw|start|" .. PAYLOAD:gsub(";towers;0;", ";economy;1;"), 0)
check(gadget:AllowCommand(1, 7, 0, -4, {}) == true and gadget:AllowCommand(1, 7, 0, -5, {}) == true, "towers and economy with fog of war: solar collector and radar are allowed")
check(gadget:AllowCommand(1, 7, 0, -6, {}) == false, "a factory is still refused")
ok("build rule")
