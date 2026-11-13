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
	ok("bar_rules")
end
