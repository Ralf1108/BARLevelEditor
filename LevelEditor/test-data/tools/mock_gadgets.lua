-- Mock test of shared code of the gadgets outside the game (run by mock_test.py with Lua 5.1): the wreck reclaim of Renegade and Evolution (G.reclaimFeatures of
-- LevelEditor/scripts/led_gadgets.lua), its text helpers (split, fields, allianceName) and shared/bar_rules.lua (techLevel, headingToFacing, base64url).
-- REPO (set by mock_test.py): the folder of the repository. check(cond, text), ok(text): see mock_test.py.

local features = {} -- id -> { metal, energy, left, reclaimable }
local destroyed, reclaimSet = {}, {}
Spring = setmetatable({
	GetModOptions = function() return {} end,
	GetFeaturesInCylinder = function()
		local ids = {}
		for id in pairs(features) do ids[#ids + 1] = id end
		table.sort(ids)
		return ids
	end,
	GetFeatureDefID = function(id) return id end,
	GetFeatureResources = function(id)
		local f = features[id]
		return 0, f.metal, 0, f.energy, f.left
	end,
	DestroyFeature = function(id) destroyed[id] = true; features[id] = nil end,
	SetFeatureReclaim = function(id, left) reclaimSet[id] = left; features[id].left = left end,
}, { __index = function() return function() end end })
VFS = { ZIP_FIRST = 1, Include = function(path) return dofile(REPO .. "/shared/" .. path:match("([^/]+)$")) end }
CMD, GG = {}, {}
FeatureDefs = setmetatable({}, { __index = function(_, id) return { reclaimable = not (features[id] or {}).fixed, name = "f" .. tostring(id) } end })

local G = dofile(REPO .. "/LevelEditor/scripts/led_gadgets.lua")

local function reset(list)
	features, destroyed, reclaimSet = {}, {}, {}
	for i, f in ipairs(list) do
		features[i] = { metal = f.metal or 0, energy = f.energy or 0, left = f.left or 1, fixed = f.fixed }
	end
end
local function near(a, b) return math.abs(a - b) < 0.01 end

-- ---------------------------------------------------------------- the wreck reclaim
do
	reset { { metal = 400 } }
	local h, e = G.reclaimFeatures(0, 0, 300, { health = 300, healthRate = 3.7 })
	check(near(h, 3.7) and e == 0, "a wreck of 400 metal, a budget of 3.7: 3.7 health (" .. h .. ")")
	check(near(features[1].left, 1 - 3.7 / 400), "the wreck keeps what was not taken (" .. features[1].left .. ")")

	reset { { metal = 400 } }
	h = G.reclaimFeatures(0, 0, 300, { health = 2, healthRate = 150 })
	check(near(h, 2), "the room limits it: a unit that misses 2 health takes 2 (" .. h .. ")")

	reset { { metal = 100 } }
	h = G.reclaimFeatures(0, 0, 300, { health = 500, healthRate = 150 })
	check(near(h, 100) and destroyed[1], "a small wreck is taken completely and destroyed (" .. h .. ")")

	reset { { metal = 100 }, { metal = 100 }, { metal = 100 } }
	h = G.reclaimFeatures(0, 0, 300, { health = 500, healthRate = 150 })
	check(near(h, 150), "three wrecks, a budget of 150: the budget is shared (" .. h .. ")")
	check(destroyed[1] and not destroyed[2] and near(features[2].left, 0.5) and near(features[3].left, 1), "the first is used up, the second half, the third untouched")

	reset { { metal = 100, fixed = true } }
	h = G.reclaimFeatures(0, 0, 300, { health = 500, healthRate = 150 })
	check(h == 0 and not destroyed[1], "a feature that cannot be reclaimed stays")

	reset { { metal = 100 } }
	h = G.reclaimFeatures(0, 0, 300, { health = 0, healthRate = 150 })
	check(h == 0 and not destroyed[1], "a unit at full health takes nothing and the wreck stays")

	reset { { metal = 50, energy = 200 } }
	local hh, ee = G.reclaimFeatures(0, 0, 300, { health = 0, healthRate = 150, energy = 1000, energyRate = 60 })
	check(hh == 0 and near(ee, 60), "full health: the energy of a wreck is still taken, up to its rate (" .. hh .. ", " .. ee .. ")")

	reset { { metal = 50, energy = 200 } }
	hh, ee = G.reclaimFeatures(0, 0, 300, { health = 500, healthRate = 150, energy = 0, energyRate = 60 })
	check(near(hh, 50) and ee == 0, "full storage: only the metal heals (" .. hh .. ", " .. ee .. ")")

	reset { { metal = 50, energy = 200 } }
	hh, ee = G.reclaimFeatures(0, 0, 300, { health = 500, healthRate = 150, energy = 1000, energyRate = 60 })
	check(near(ee, 60) and near(hh, 15), "both: the energy limit (60 of 200) sets the part, 30 % of the metal heals (" .. hh .. ", " .. ee .. ")")

	reset { { metal = 0.4 } }
	h = G.reclaimFeatures(0, 0, 300, { health = 100, healthRate = 1 })
	check(near(h, 0.4), "a tiny wreck gives its small amount (" .. h .. ")")
	ok("G.reclaimFeatures")
end

-- ---------------------------------------------------------------- text helpers
do
	local p = G.split("a,b,,c", ",")
	check(#p == 3 and p[1] == "a" and p[3] == "c", "split: empty parts are left out")
	local f = G.fields("a;b;;c")
	check(#f == 4 and f[3] == "" and f[4] == "c", "fields: empty fields stay (" .. #f .. ")")
	check(G.allianceName(103) == "group 3" and G.allianceName(2) == "2" and G.allianceName("102") == "group 2", "allianceName: a group of the editor or the ally team")
	check(G.wonBy(1) == "won by alliance 1" and G.wonBy(103) == "won by group 3", "wonBy: an alliance or a group of the editor")
	ok("text helpers")
end

-- ---------------------------------------------------------------- bar_rules.lua
do
	local R = G.Rules
	check(R.decode64("SGVsbG8") == "Hello", "decode64: base64url without padding (" .. R.decode64("SGVsbG8") .. ")")
	local bin = R.decode64("-_-_")
	check(bin == string.char(251, 255, 191), "decode64: - and _ stand for + and / (" .. bin:byte(1, -1) .. ")")
	check(R.headingToFacing(0) == 0 and R.headingToFacing(16384) == 1 and R.headingToFacing(-32768) == 2 and R.headingToFacing(-16384) == 3, "headingToFacing: south, east, north, west")
	check(R.techLevel({ customParams = { techlevel = 1 }, humanName = "Epic Grunt" }) == 3, "techLevel: an Epic unit counts as T3")
	check(R.techLevel({ customParams = { techlevel = 2 }, humanName = "Pawn" }) == 2, "techLevel: a normal T2 stays")
	local fac, base = R.factionOf("armpw_scav")
	check(fac == "scv" and base == "armpw", "factionOf: a Scavenger copy (" .. tostring(fac) .. ", " .. tostring(base) .. ")")
	fac, base = R.factionOf("raptor_land_swarmer_basic_t1_v1")
	check(fac == "rap" and base == "raptor_land_swarmer_basic_t1_v1", "factionOf: a raptor keeps its name")
	check(R.factionOf("corak") == "cor" and R.factionOf("legcom") == "leg", "factionOf: the first three letters")
	check(R.dist2(0, 0, 3, 4) == 25 and R.dist2(5, 5, 5, 5) == 0, "dist2: the square of the distance")
	local realSpring = Spring
	Spring = { GetUnitCommandCount = function() return 3 end }
	check(R.commandCount(1) == 3, "commandCount: the new engine function")
	Spring = { GetUnitCommands = function(_, count) return count == 0 and 2 or {} end }
	check(R.commandCount(1) == 2, "commandCount: the old function that returns a number for 0")
	Spring = { GetUnitCommands = function() return { 1, 2, 3, 4 } end }
	check(R.commandCount(1) == 4, "commandCount: the old function that returns a table")
	Spring = realSpring
	local dead, hp, mt = false, 100, nil
	Spring.GetUnitIsDead = function() return dead end
	Spring.GetUnitHealth = function() return hp end
	Spring.GetUnitMoveTypeData = function() return mt end
	check(not R.shotDown(1), "shotDown: a healthy aircraft is not shot down")
	mt = { aircraftState = "crashing" }
	check(R.shotDown(1), "shotDown: a crashing aircraft")
	mt, hp = nil, 0
	check(R.shotDown(1), "shotDown: no health left")
	hp, dead = 50, true
	check(R.shotDown(1), "shotDown: a dead unit")
		local function mk(class, extra) local ud = { speed = 50, moveDef = { name = class } }; for k, v in pairs(extra or {}) do ud[k] = v end; return ud end
		local kinds = { bot2 = "bot", bot3 = "bot", abot3 = "bot", hbot4 = "bot", hbot7 = "bot", habot5 = "bot", vbot6 = "bot", epicbot = "bot", commanderbot = "bot", scavcommanderbot = "bot",
			tbot3 = "spider", epicallterrain = "spider", htbot6 = "spider", abotbomb2 = "spider", sbot2 = "spider",
			tank2 = "tank", tank3 = "tank", htank4 = "tank", mtank3 = "tank", atank3 = "tank", epicveh = "tank",
			hover2 = "hover", hover3 = "hover", hhover4 = "hover", ahover2 = "hover",
			boat3 = "ship", boat9 = "ship", uboat4 = "ship", epicship = "ship", epicsubmarine = "ship", scavmist = "other" }
		for class, kind in pairs(kinds) do
			check(R.moveKind(mk(class)) == kind, "moveKind: " .. class .. " is " .. kind .. " (" .. R.moveKind(mk(class)) .. ")")
		end
		check(R.moveKind(mk("bot2", { canFly = true })) == "air", "moveKind: a flying unit is air")
		check(R.moveKind(mk("bot2", { speed = 0 })) == "building", "moveKind: no speed is a building")
		check(R.moveKind({ speed = 50 }) == "building" and R.moveKind(nil) == "building", "moveKind: no movement class is a building")
		check(R.moveKind({ speed = 50, moveDef = { family = "ship", name = "x" } }) == "ship", "moveKind: the family ship")
		ok("bar_rules")
end

-- ---------------------------------------------------------------- G.setSight
do
	local realSpring = Spring
	local radius = { los = 400, airLos = 300 }
	Spring = setmetatable({
		ValidUnitID = function() return true end,
		GetUnitSensorRadius = function(_, k) return radius[k] end,
		SetUnitSensorRadius = function(_, k, v) radius[k] = v end,
	}, { __index = realSpring })
	G.setSight(1, "renegade", { factor = 3 })
	check(radius.los == 1200 and radius.airLos == 900, "setSight: three times the own sight (" .. radius.los .. ", " .. radius.airLos .. ")")
	G.setSight(1, "pulse", { radius = 2500 })
	check(radius.los == 2500 and radius.airLos == 2500, "setSight: the larger reason counts (a pulse of 2500)")
	G.setSight(1, "pulse", nil)
	check(radius.los == 1200 and radius.airLos == 900, "setSight: the end of the pulse keeps the three times sight")
	G.setSight(1, "renegade", nil)
	check(radius.los == 400 and radius.airLos == 300, "setSight: no reason left, the own sight is back (" .. radius.los .. ", " .. radius.airLos .. ")")
	G.setSight(1, "pulse", nil)
	check(radius.los == 400, "setSight: taking away a reason that is not there changes nothing")
	radius = { los = 400, airLos = 0 }
	G.setSight(2, "pulse", { radius = 1000 })
	check(radius.airLos == 1000, "setSight: a radius also works where the unit has no air sight")
	G.setSight(2, "pulse", nil)
	check(radius.airLos == 0 and radius.los == 400, "setSight: and goes back to none")
	Spring = realSpring
	ok("setSight")
end

-- ---------------------------------------------------------------- G.fits and G.randomPlace
do
	local realSpring = Spring
	Game = { mapSizeX = 4000, mapSizeZ = 4000 }
	UnitDefs = { [1] = { name = "tank" }, [2] = { name = "turret", isBuilding = true } }
	local water = function(x) return x < 1000 end -- (the west quarter of the map is under water)
	Spring = setmetatable({
		GetGroundHeight = function(x, z) return water(x) and -20 or 50 end,
		TestMoveOrder = function(def, x) return x > 1500 end, -- (the west third is too steep)
		TestBuildOrder = function(def, x) return x > 3000 and 2 or 1 end,
	}, { __index = realSpring })
	check(G.fits(1, 2000, 100) and not G.fits(1, 1200, 100) and not G.fits(1, 500, 100), "fits: a unit needs land the move test accepts")
	check(G.fits(2, 3500, 100) and not G.fits(2, 2000, 100), "fits: a building needs a free place (TestBuildOrder 2)")
	check(G.fits(2, 2000, 100, false) and not G.fits(2, 500, 100, false), "fits: objects == false lets a place with a unit in the way count, not water")
	check(G.fits(1, 2000, 100, nil, 100) == false, "fits: minY raises the lowest ground that counts as land")
	math.randomseed(7)
	local good = true
	for _ = 1, 50 do
		local x, y, z = G.randomPlace(1, { tries = 24, margin = 200 })
		if not x or x <= 1500 or x < 200 or x > 3800 or z < 200 or z > 3800 or y ~= 50 then good = false end
	end
	check(good, "randomPlace: a place inside the margin where the unit fits")
	local x = G.randomPlace(1, { tries = 24, score = function(px) return px end })
	local best = 0
	for _ = 1, 200 do local px = G.randomPlace(1, { tries = 24, score = function(q) return q end }) best = math.max(best, px) end
	check(x and best > 3000, "randomPlace: the score picks the best of the tries (the farthest east: " .. string.format("%.0f", best) .. ")")
	Spring.TestMoveOrder = function() return false end
	check(G.randomPlace(1, { tries = 24 }) == nil, "randomPlace: nothing fits and no relax: nil")
	local rx, ry = G.randomPlace(1, { tries = 24, relax = true, minY = 2 })
	check(rx and ry == 50, "randomPlace: relax takes a dry place without the move test")
	Spring.GetGroundHeight = function() return -20 end
	check(G.randomPlace(1, { tries = 24, relax = true, minY = 2 }) == nil, "randomPlace: all water: nil")
	Spring = realSpring
	ok("fits and randomPlace")
end
