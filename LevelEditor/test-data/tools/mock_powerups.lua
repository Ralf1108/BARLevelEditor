-- Mock test of LevelEditor/scripts/powerups.lua (the power-ups of Evolution and Renegade) outside the game: the use of a power-up (A.use: who may, the
-- energy, the cooldown), its effect and its end (A.start, A.stop: Repair, Sprint), the loss (A.lose) and what the unsynced part is told (A.publish).
-- REPO (set by mock_test.py): the folder of the repository. check(cond, text), ok(text): see mock_test.py.
local frame, energy, spent = 100, 1000, 0
local health = { [7] = { 500, 1000 } } -- unit -> { health, highest health }
local speed, rules, healed, sight = {}, {}, nil, nil
UnitDefs = { [1] = { speed = 60, weapons = {} } }
CMD = { FIRE_STATE = 45, STOP = 0 }
VFS = { ZIP_FIRST = 1, Include = function() return { setSight = function(id, reason, s) sight = s end } end }
SendToUnsynced = function(msg, id, n) healed = n end
Spring = {
	GetGameFrame = function() return frame end,
	UseTeamResource = function(team, kind, n)
		if n > energy then return false end
		energy, spent = energy - n, spent + n
		return true
	end,
	GetUnitHealth = function(id) local h = health[id]; if h then return h[1], h[2] end end,
	SetUnitHealth = function(id, hp) health[id][1] = hp end,
	GetUnitDefID = function() return 1 end,
	GetUnitRulesParam = function() return nil end,
	MoveCtrl = { SetGroundMoveTypeData = function(id, t) speed[id] = t.maxSpeed end },
	SetGameRulesParam = function(k, v) rules[k] = v end,
	SetTeamRulesParam = function(team, k, v) rules[k .. team] = v end,
	ValidUnitID = function(id) return health[id] ~= nil end,
	GetUnitIsDead = function() return false end,
}
local P = dofile(REPO .. "/LevelEditor/scripts/powerups.lua")
local index = {}
for i, a in ipairs(P.ABILITIES) do index[a.key] = i end
local SPRINT, REPAIR, PULSE = index.sprint, index.repair, index.pulse
local p = { team = 3, unit = 7, name = "PlayerA", abilities = {} }
local A = P.new({ players = { p }, owner = { [7] = p }, say = function() end, randomSpot = function() return 100, 200 end, count = function() return 1 end,
	healMsg = "heal", abilitiesRule = "abil", beaconsRule = "beacons" })

check(#P.ABILITIES == 5 and SPRINT and REPAIR and PULSE, "the five abilities with sprint, repair and pulse")
check(A.use(p, SPRINT) == false and spent == 0, "a power-up the player does not have is not used")
p.abilities[SPRINT], p.abilities[REPAIR], p.abilities[PULSE] = true, true, true
ok("who may use a power-up")

-- Repair: at once, 20 % of the highest health, the cooldown starts at once
check(A.use(p, REPAIR) == true, "Repair of a hurt unit begins")
check(health[7][1] == 700 and healed == 200, "Repair heals 20 % of the highest health (500 -> 700) and tells the unsynced part +200: " .. tostring(health[7][1]))
check(spent == 500 and energy == 500, "Repair costs 500 energy")
check(p.cool[REPAIR] == 100 + 60 * 30, "the cooldown of Repair (60 s) starts at once")
check(A.use(p, REPAIR) == false and spent == 500, "Repair in its cooldown is not used again")
frame = 100 + 60 * 30
health[7][1] = 1000
check(A.use(p, REPAIR) == false and spent == 500, "Repair at full health does nothing and costs nothing")
ok("Repair")

-- Sprint: lasts 8 s, the unit is 50 % faster, the cooldown starts when it ends
energy = 250
check(A.use(p, SPRINT) == true and speed[7] == 90, "Sprint: 1.5 times the speed (60 -> 90): " .. tostring(speed[7]))
check(p.active[SPRINT].frame == frame + 8 * 30 and not (p.cool[SPRINT] and p.cool[SPRINT] > frame), "Sprint lasts 8 s, no cooldown while it runs")
check(A.use(p, SPRINT) == false, "Sprint while it runs is not used again")
check(A.use(p, PULSE) == false and energy == 50, "no energy (50 of 250): the Radar Pulse does not begin and nothing is spent")
A.publish()
check(rules.abil3 == string.format("%d:0:8,%d:0:0,%d:0:0", SPRINT, REPAIR, PULSE),
	"the team rule tells index:cooldown:seconds left (Sprint 0 and 8): " .. tostring(rules.abil3))
frame = frame + 8 * 30
A.stop(p, SPRINT)
check(speed[7] == 60 and p.active[SPRINT] == nil, "Sprint ends: the speed is 60 again")
check(p.cool[SPRINT] == frame + 30 * 30, "the cooldown of Sprint (30 s) starts when it ends")
ok("Sprint")

-- the Radar Pulse makes the sight larger through G.setSight
energy = 1000
check(A.use(p, PULSE) == true and sight and sight.radius == A.PULSE, "the Radar Pulse sets the sight of 2500")
A.stop(p, PULSE)
check(sight == nil, "the Radar Pulse ends: the sight is given back")
ok("Radar Pulse")

-- a beacon and the loss of the power-ups
check(A.place(SPRINT) == true and #A.beacons == 1 and A.beacons[1].x == 100 and A.beacons[1].kind == SPRINT, "a beacon lies at the random spot")
A.publish()
check(rules.beacons == "100,200," .. SPRINT, "the game rule of the beacons: x,z,kind: " .. tostring(rules.beacons))
A.lose(p)
check(next(p.abilities) == nil and A.use(p, SPRINT) == false, "a player whose unit died has no power-ups")
p.out = true
ok("beacons and loss")
