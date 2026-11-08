-- Mock test of shared/area_attack.lua outside the game (run by mock_test.py with Lua 5.1): a small fake of the Spring API with units on a flat map,
-- then the attacks are dragged like in the game (toggle, press, release, step) and the orders the units get are checked.
-- REPO (set by mock_test.py): the folder of the repository, with forward slashes. check(cond, text) counts a failure, ok(text) prints a passed check.

VFS = { ZIP_FIRST = 1, Include = function() return dofile(REPO .. "/shared/bar_rules.lua") end }
UnitDefs = {
	[1] = { name = "tank", speed = 50, weapons = { { weaponDef = 1 } } },
	[2] = { name = "pawn", speed = 60, weapons = { { weaponDef = 2 } } },
	[3] = { name = "wall", speed = 0, weapons = {} },
	[4] = { name = "turret", speed = 0, weapons = { { weaponDef = 1 } } },
	[5] = { name = "bomber", speed = 200, canFly = true, weapons = { { weaponDef = 4 } } },
	[6] = { name = "aa", speed = 50, weapons = { { weaponDef = 5 } } },
}
WeaponDefs = {
	[1] = { damages = { [0] = 100, [14] = 1 }, reload = 3, projectiles = 1, salvoSize = 1, range = 400, type = "Cannon" },
	[2] = { damages = { [0] = 10, [14] = 1 }, reload = 1, projectiles = 1, salvoSize = 1, range = 200, type = "Cannon" },
	[4] = { damages = { [0] = 500, [14] = 1 }, reload = 9, projectiles = 1, salvoSize = 1, range = 100, type = "AircraftBomb" },
	[5] = { damages = { [0] = 1, [14] = 200 }, reload = 1, projectiles = 1, salvoSize = 1, range = 800, type = "MissileLauncher" },
}
Game = { armorTypes = { default = 0, vtol = 14 }, mapSizeX = 8192, mapSizeZ = 8192 }
CMD = { ATTACK = 20, MOVE = 10 }
GL = { LINES = 1, LINE_LOOP = 2 }
gl = setmetatable({}, { __index = function() return function() end end })

local units, nextId, selected, frame = {}, 1, {}, 0
local MY_TEAM, ALLY_TEAM, ENEMY_TEAM, GAIA = 0, 2, 1, 99
Spring = {
	ENEMY_UNITS = -4,
	GetSelectedUnits = function() return selected end,
	GetUnitDefID = function(id) return units[id] and units[id].def end,
	GetUnitPosition = function(id) local u = units[id]; if u then return u.x, 0, u.z end end,
	GetUnitHealth = function(id) return units[id] and units[id].hp end,
	GetUnitIsDead = function(id) return units[id] == nil end,
	GetUnitTeam = function(id) return units[id] and units[id].team end,
	GetGaiaTeamID = function() return GAIA end,
	GetUnitsInCylinder = function(x, z, r)
		local out = {}
		for id, u in pairs(units) do
			if (u.x - x) ^ 2 + (u.z - z) ^ 2 <= r * r then out[#out + 1] = id end
		end
		table.sort(out)
		return out
	end,
	GiveOrderToUnit = function(id, cmd, params, opts)
		local u = units[id]
		if not (opts and opts[1] == "shift") then u.cmds = {} end
		u.cmds[#u.cmds + 1] = { cmd = cmd, params = params }
	end,
	GetGameFrame = function() return frame end,
	GetUnitCurrentCommand = function(id) local c = units[id] and units[id].cmds[1]; return c and c.cmd end,
	GetUnitCommandCount = function(id) return units[id] and #units[id].cmds or 0 end,
	GetGroundHeight = function() return 0 end,
	GetMouseState = function() return 0, 0 end,
	ValidUnitID = function(id) return units[id] ~= nil end,
	GetMyTeamID = function() return MY_TEAM end,
	AreTeamsAllied = function(a, b) return a == b or (a == MY_TEAM and b == ALLY_TEAM) or (a == ALLY_TEAM and b == MY_TEAM) end,
}

local function add(def, x, z, hp, team)
	local id = nextId
	nextId = nextId + 1
	units[id] = { def = def, x = x, z = z, hp = hp, team = team, cmds = {} }
	return id
end

-- a new field: the selected units ({ def, count } in a row at z = 0) and the other units ({ def, count, hp, team } in a row at x = 2000)
local function field(mine, others)
	units, nextId, selected = {}, 1, {}
	for _, d in ipairs(mine) do
		for i = 1, d[2] do selected[#selected + 1] = add(d[1], i * 10, 0, 1000, MY_TEAM) end
	end
	local list = {}
	for _, d in ipairs(others or {}) do
		for i = 1, d[2] do list[#list + 1] = add(d[1], 2000 + i * 5, 0, d[3], d[4] or ENEMY_TEAM) end
	end
	return list
end

local newAreaAttack = dofile(REPO .. "/shared/area_attack.lua")
local mouse = { 0, 0 }
local said = {}
local area = newAreaAttack({ say = function(s) said[#said + 1] = s end, mouseGround = function() return mouse[1], mouse[2] end })

-- one drag on the map: from (ax, az) to (bx, bz) in the mode
local function drag(mode, ax, az, bx, bz)
	said = {}
	area:toggle(mode)
	mouse = { ax, az }
	area:press(1)
	mouse = { bx, bz }
	area:release()
end

-- the attack targets (unit ids) of a unit, in the order of its queue
local function targetsOf(id)
	local out = {}
	for _, c in ipairs(units[id].cmds) do
		if c.cmd == CMD.ATTACK and #c.params == 1 then out[#out + 1] = c.params[1] end
	end
	return out
end

-- every target of every selected unit is an enemy (no own, allied or Gaia unit)
local function onlyEnemies()
	for _, id in ipairs(selected) do
		for _, t in ipairs(targetsOf(id)) do
			if units[t].team ~= ENEMY_TEAM then return false end
		end
	end
	return true
end

-- ---------------------------------------------------------------- split attack (XS)
do
	local enemies = field({ { 1, 10 } }, { { 2, 10, 60 } })
	drag("split", 2000, 0, 2300, 0)
	local first = {}
	for _, id in ipairs(selected) do
		local t = targetsOf(id)
		check(#t >= 1, "XS: every tank has a target")
		if t[1] then first[t[1]] = true end
	end
	local covered = 0
	for _, e in ipairs(enemies) do if first[e] then covered = covered + 1 end end
	check(covered == 10, "XS: 10 tanks on 10 pawns: every pawn is the first target of one tank (got " .. covered .. ")")
	check(onlyEnemies(), "XS: only enemies are targets")
	ok("XS spreads the tanks over the pawns")
end

do
	field({ { 1, 4 } }, { { 2, 2, 60 }, { 1, 2, 500, MY_TEAM }, { 1, 2, 500, ALLY_TEAM }, { 2, 2, 60, GAIA } })
	drag("split", 2000, 0, 2300, 0)
	check(onlyEnemies(), "XS: own, allied and Gaia units in the circle are no targets")
	for _, id in ipairs(selected) do check(#targetsOf(id) >= 1, "XS: every tank attacks one of the two enemies") end
	ok("XS leaves own, allied and Gaia units alone")
end

do
	field({ { 1, 3 } }, { { 3, 2, 3000, ENEMY_TEAM } })
	for _, id in ipairs(selected) do units[id].cmds = {} end
	drag("split", 2000, 0, 2300, 0)
	check(onlyEnemies(), "XS: walls are enemies too")
	ok("XS attacks enemy buildings without weapons")
end

do
	-- a turret cannot move: it only takes targets in its range (400); the tank walks
	field({ { 4, 1 }, { 1, 1 } }, { { 2, 3, 60 } })
	drag("split", 2000, 0, 2300, 0)
	check(#targetsOf(selected[1]) == 0, "XS: the turret out of range gets no target")
	check(#targetsOf(selected[2]) >= 1, "XS: the tank gets a target")
	ok("XS gives a static unit only targets in its range")
end

do
	field({ { 1, 2 } }, {})
	drag("split", 2000, 0, 2300, 0)
	check(said[#said] == "No visible enemy in the circle", "XS: an empty circle says so (" .. tostring(said[#said]) .. ")")
	ok("XS with no enemy in the circle")
end

-- ---------------------------------------------------------------- focus attack (XF) and the steps after it
do
	local enemies = field({ { 1, 10 } }, { { 1, 3, 1000 }, { 2, 10, 60 } })
	drag("focus", 2000, 0, 2300, 0)
	check(onlyEnemies(), "XF: only enemies are targets")
	for _, id in ipairs(selected) do check(#targetsOf(id) >= 2, "XF: every tank has a queue (target and the next one)") end
	-- the enemy tanks (they shoot back) come before the pawns: most tanks start on one of them
	local onTanks = 0
	for _, id in ipairs(selected) do
		local t = targetsOf(id)[1]
		if t and units[t].def == 1 then onTanks = onTanks + 1 end
	end
	check(onTanks >= 5, "XF: the dangerous enemy tanks first (" .. onTanks .. " of 10 tanks start on them)")
	ok("XF concentrates on the dangerous targets")

	-- the enemy tanks die: the engine drops the orders on dead targets, the next step makes a new plan for the pawns
	for _, e in ipairs(enemies) do if units[e].def == 1 then units[e] = nil end end
	for _, id in ipairs(selected) do
		local keep = {}
		for _, c in ipairs(units[id].cmds) do if units[c.params[1]] then keep[#keep + 1] = c end end
		units[id].cmds = keep
	end
	frame = 30
	area:step(frame)
	local busy = 0
	for _, id in ipairs(selected) do if #targetsOf(id) > 0 then busy = busy + 1 end end
	check(busy == 10, "XF step: after the tanks died all 10 tanks attack the pawns (" .. busy .. ")")
	ok("XF plans again when a target died")

	-- the player stops a tank while its target lives: it leaves the attack and is not given orders again
	local stopped = selected[3]
	units[stopped].cmds = {}
	frame = 60
	area:step(frame)
	check(#units[stopped].cmds == 0, "XF step: a tank stopped by the player stays stopped")
	ok("XF leaves a unit alone that the player stopped")

	-- all enemies dead: the attack ends
	for _, e in ipairs(enemies) do units[e] = nil end
	said = {}
	frame = 90
	area:step(frame)
	check(said[1] == "Focus attack finished", "XF: ends when every target is dead (" .. tostring(said[1]) .. ")")
	ok("XF ends when the enemies are dead")
end

-- ---------------------------------------------------------------- area attacks on the ground (line, rectangle, circle)
local function groundPoints()
	local pts = {}
	for _, id in ipairs(selected) do
		local c = units[id].cmds[1]
		if c and c.cmd == CMD.ATTACK and #c.params == 3 then pts[#pts + 1] = { x = c.params[1], z = c.params[3], id = id } end
	end
	return pts
end

do
	field({ { 1, 5 } })
	drag("line", 1000, 1000, 2000, 1000)
	local pts = groundPoints()
	check(#pts == 5, "XL: 5 tanks get 5 ground targets (" .. #pts .. ")")
	local seen = {}
	for _, p in ipairs(pts) do
		check(p.x >= 1000 and p.x <= 2000 and p.z == 1000, "XL: the target lies on the line")
		check(not seen[p.x], "XL: every tank gets its own piece of the line")
		seen[p.x] = true
	end
	ok("XL spreads the tanks over the line")
end

do
	field({ { 1, 6 } })
	drag("rect", 1000, 1000, 1600, 1400)
	local pts = groundPoints()
	check(#pts == 6, "XR: 6 ground targets (" .. #pts .. ")")
	for _, p in ipairs(pts) do check(p.x >= 1000 and p.x <= 1600 and p.z >= 1000 and p.z <= 1400, "XR: the target lies in the rectangle") end
	ok("XR spreads the tanks in the rectangle")
end

do
	field({ { 1, 7 } })
	drag("circle", 1500, 1500, 1800, 1500)
	local pts = groundPoints()
	check(#pts == 7, "XC: 7 ground targets (" .. #pts .. ")")
	for _, p in ipairs(pts) do check((p.x - 1500) ^ 2 + (p.z - 1500) ^ 2 <= 300 * 300 + 1, "XC: the target lies in the circle") end
	ok("XC spreads the tanks in the circle")
end

do
	-- bombers form up first (MOVE to a staging point), then attack together; anti-air units do not take part
	field({ { 5, 3 }, { 6, 2 } })
	drag("line", 1000, 3000, 2000, 3000)
	for i = 1, 3 do
		local c = units[selected[i]].cmds[1]
		check(c and c.cmd == CMD.MOVE, "XL: a bomber first moves to its staging point")
	end
	for i = 4, 5 do check(#units[selected[i]].cmds == 0, "XL: an anti-air unit gets no ground target") end
	for i = 1, 3 do
		local c = units[selected[i]].cmds[1]
		units[selected[i]].x, units[selected[i]].z = c.params[1], c.params[3]
	end
	frame = 105
	area:step(frame)
	for i = 1, 3 do
		local c = units[selected[i]].cmds[1]
		check(c and c.cmd == CMD.ATTACK, "XL: in position the bombers attack")
	end
	ok("XL: bombers form up and attack together, anti-air stays out")
end
