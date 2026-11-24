-- Mock test of the tweaked units outside the game: LevelEditor/scripts/tweak_rules.lua (reading a tweakunits text plain and in base64, refusing
-- program code, writing it again, what can be changed and what is ignored) and the gadget LevelEditor/scripts/unit_tweaks.lua with a fake engine
-- (the message of the editor, the values set for a unit, a unit that waits for its definition, the game options of a finished scenario).
-- REPO (set by mock_test.py): the folder of the repository. check(cond, text), ok(text): see mock_test.py.
local T = dofile(REPO .. "/LevelEditor/scripts/tweak_rules.lua")

-- ---------------------------------------------------------------- reading
local PLAIN = "{ armpw = { health = 2000, Speed = 90, footprintx = 4, weapondefs = { emg = { range = 500, damage = { default = 50, vtol = 5 }, model = 'x' }, nope = { range = 1 } } } }"
local t, err = T.parse(PLAIN)
check(t and t.armpw and t.armpw.health == 2000, "a plain Lua table is read: " .. tostring(err))
check(t and t.armpw.speed == 90, "keys are taken in lower case (Speed -> speed)")
check(T.parse("return " .. PLAIN) ~= nil, "'return' in front is allowed")
local b64 = T.encode64(PLAIN)
check(not b64:find("[=+/]"), "encode64 writes base64url without padding")
check(T.decode64(b64) == PLAIN, "decode64 reads it back")
local t2 = T.parse(b64)
check(t2 and t2.armpw.health == 2000, "the same text in base64url is read")
-- the standard form with + / and = padding, and BAR's form with _ as padding
check(T.decode64("eyBhID0gMSB9") == "{ a = 1 }" and T.decode64("eyBhID0gMSB9IA==") == "{ a = 1 } " and T.decode64("eyBhID0gMSB9IA__") == "{ a = 1 } ", "padding = and _ at the end is skipped")
local x, e1 = T.parse("{ armpw = { health = } }")
check(x == nil and e1:find("not correct", 1, true), "a syntax error is reported: " .. tostring(e1))
local y, e2 = T.parse("local a = UnitDefs.armpw\na.health = 5")
check(y == nil and e2:find("tweakdefs", 1, true), "program code is refused as a tweakdefs text: " .. tostring(e2))
local z, e3 = T.parse("{ armpw = 5 }")
check(z == nil and e3:find("unitname", 1, true), "an entry that is no table is refused")
check(T.parse("") == nil and T.parse("!!!") == nil and T.parse("{}") == nil, "an empty text, rubbish and an empty table are refused")
local inert = T.parse("{ armpw = { health = os and 1 or 2 } }")
check(inert and inert.armpw.health == 2, "the text runs in an empty environment (no os, no Spring)")
ok("reading")

-- ---------------------------------------------------------------- writing
local s = T.serialize({ armpw = t.armpw })
local back = T.parse(s)
check(back and back.armpw.weapondefs.emg.damage.vtol == 5 and back.armpw.footprintx == 4, "serialize gives a text that reads back the same")
check(T.serialize({ b = 1, a = 2 }) == "{ a = 2, b = 1 }", "the keys are sorted: " .. T.serialize({ b = 1, a = 2 }))
ok("writing")

-- ---------------------------------------------------------------- what works and what is ignored
WeaponDefs = { [7] = { name = "armpw_emg", range = 180, reload = 0.3, damages = { [0] = 9, [1] = 3, [2] = 9 } }, [8] = { name = "armpw_shield", isShield = true, range = 900 } }
local pawn = { id = 1, name = "armpw", health = 370, speed = 87, metalCost = 54, losRadius = 430, weapons = { { weaponDef = 7 }, { weaponDef = 8 } } }
UnitDefs = { [1] = pawn, [2] = { id = 2, name = "armllt", health = 600, speed = 0, weapons = {} } }
UnitDefNames = { armpw = pawn, armllt = UnitDefs[2] }
local c = T.check("armpw", t.armpw, pawn, WeaponDefs)
local applied, ignored = table.concat(c.applied, " | "), table.concat(c.ignored, " | ")
check(#c.errors == 0, "no errors in a correct table")
check(applied:find("health 370 -> 2000", 1, true) and applied:find("speed 87 -> 90", 1, true), "unit fields are shown as old -> new: " .. applied)
check(applied:find("emg range 180 -> 500", 1, true) and applied:find("emg damage (default) 9 -> 50", 1, true) and applied:find("emg damage (vtol) = 5", 1, true), "weapon fields and damage are shown")
check(ignored:find("footprintx", 1, true) and ignored:find("weapondefs.emg.model", 1, true) and ignored:find("weapondefs.nope: the unit carries no weapon", 1, true), "what cannot change is listed as ignored: " .. ignored)
local bad = T.check("armpw", { health = "many", stealth = 1 }, pawn, WeaponDefs)
check(#bad.errors == 2, "a value of the wrong type is an error (" .. table.concat(bad.errors, " | ") .. ")")
check(T.check("zzz", {}, nil, WeaponDefs).errors[1]:find("unknown unit", 1, true), "an unknown unit is an error")
local alias = T.check("armpw", { maxdamage = 5, buildcostmetal = 6 }, pawn, WeaponDefs)
check(#alias.applied == 2 and #alias.ignored == 0, "the older names maxdamage and buildcostmetal are taken")
for key in pairs(T.UNIT) do
	check(T.HELP:find(key, 1, true) ~= nil, "the help text names the field " .. key)
end
for key in pairs(T.WEAPON) do
	check(T.HELP:find(key, 1, true) ~= nil, "the help text names the weapon field " .. key)
end
ok("what works and what is ignored")

-- ---------------------------------------------------------------- the values of a unit as text
local ut = T.unitTable("armpw", pawn, WeaponDefs)
check(ut.health == 370 and ut.speed == 87 and ut.metalcost == 54 and ut.sightdistance == 430 and ut.radardistance == nil, "unitTable holds the values of the unit, without the empty ones")
check(ut.weapondefs and ut.weapondefs.emg and ut.weapondefs.emg.range == 180 and ut.weapondefs.emg.reloadtime == 0.3 and ut.weapondefs.emg.damage.default == 9,
	"unitTable holds the weapon with range, reload time and damage")
check(ut.weapondefs.shield == nil, "a shield is left out")
local pt = T.pretty({ armpw = ut })
local pb = T.parse(pt)
check(pb and T.serialize(pb) == T.serialize({ armpw = ut }), "pretty gives a text that reads back the same")
check(pt:find("\n\t\thealth = 370,\n", 1, true) ~= nil and pt:find("damage = { default = 9 }", 1, true) ~= nil, "pretty writes one field per line: " .. pt)
local same = T.check("armpw", pb.armpw, pawn, WeaponDefs)
check(#same.errors == 0 and #same.ignored == 0 and #same.applied > 0, "the copied text of a unit has nothing that is ignored")
local dt = T.defsText("armpw", ut)
local dn, de = T.parse(dt)
check(dn == nil and de:find("tweakdefs", 1, true), "the tweakdefs text is refused by the paste as program code: " .. tostring(de))
local fakeDefs = { armpw = { weapondefs = { emg = { damage = {} } } } }
local chunk = loadstring(dt)
setfenv(chunk, { UnitDefs = fakeDefs })
chunk()
check(fakeDefs.armpw.health == 370 and fakeDefs.armpw.weapondefs.emg.range == 180 and fakeDefs.armpw.weapondefs.emg.damage.default == 9, "the tweakdefs text runs and sets the values")
local ex = T.parse(T.EXAMPLE)
local exc = ex and T.check("armpw", ex.armpw, pawn, WeaponDefs)
check(ex and ex.armpw.health == 2000 and #exc.errors == 0 and #exc.ignored == 0, "the example is a correct tweakunits text for the Pawn")
ok("the values of a unit as text")

-- ---------------------------------------------------------------- the gadget with a fake engine
local calls, params, units, options, frame = {}, {}, {}, {}, 0
local function note(name)
	return function(...)
		calls[#calls + 1] = { name, ... }
	end
end
local function called(name, ...)
	local want = { ... }
	for _, c2 in ipairs(calls) do
		if c2[1] == name then
			local same = true
			for i, v in ipairs(want) do
				if type(v) == "number" and type(c2[i + 1]) == "number" then
					same = same and math.abs(c2[i + 1] - v) < 1e-6
				else
					same = same and c2[i + 1] == v
				end
			end
			if same then
				return c2
			end
		end
	end
end
Game = { armorTypes = { [0] = "default", [1] = "vtol", [2] = "mines", default = 0, vtol = 1, mines = 2 } }
GG = {}
gadget = {}
gadgetHandler = { IsSyncedCode = function() return true end }
VFS = { ZIP_FIRST = 1, Include = function(path)
	local name = path:match("([^/]+)$")
	return dofile(REPO .. (name == "bar_rules.lua" and "/shared/" or "/LevelEditor/scripts/") .. name)
end }
Spring = setmetatable({
	GetModOptions = function() return options end,
	IsCheatingEnabled = function() return false end,
	Echo = function() end,
	ValidUnitID = function(id) return units[id] ~= nil end,
	GetUnitDefID = function(id) return units[id] and UnitDefNames[units[id].name].id end,
	GetUnitsInCylinder = function(x, z, r)
		local out = {}
		for id, u in pairs(units) do
			if (u.x - x) ^ 2 + (u.z - z) ^ 2 <= r * r then out[#out + 1] = id end
		end
		table.sort(out)
		return out
	end,
	SetUnitRulesParam = function(id, k, v) params[id] = params[id] or {}; params[id][k] = v end,
	SetUnitMaxHealth = note("SetUnitMaxHealth"), SetUnitHealth = note("SetUnitHealth"), SetUnitCosts = note("SetUnitCosts"),
	SetUnitSensorRadius = note("SetUnitSensorRadius"), SetUnitWeaponState = note("SetUnitWeaponState"), SetUnitWeaponDamages = note("SetUnitWeaponDamages"),
	SetUnitMaxRange = note("SetUnitMaxRange"), SetUnitBuildSpeed = note("SetUnitBuildSpeed"), SetUnitResourcing = note("SetUnitResourcing"),
	SetUnitMass = note("SetUnitMass"), SetUnitStealth = note("SetUnitStealth"), SetUnitSonarStealth = note("SetUnitSonarStealth"),
	MoveCtrl = { SetGroundMoveTypeData = note("SetGroundMoveTypeData") },
}, { __index = function() return function() end end })

local function load(modoptions)
	options, calls, params, units, GG, gadget = modoptions, {}, {}, {}, {}, {}
	dofile(REPO .. "/LevelEditor/scripts/unit_tweaks.lua")
end

-- the editor: leveleditor = 1, so messages need no cheat
load({ leveleditor = "1" })
local TEXT = "{ armpw = { health = 2000, speed = 90, metalcost = 10, sightdistance = 600, workertime = 300, footprintx = 4, weapondefs = { emg = { range = 500, reloadtime = 0.1, areaofeffect = 64, weaponvelocity = 600, damage = { default = 50, vtol = 5 } } } } }"
units[11] = { name = "armpw", x = 100, z = 100 }
units[12] = { name = "armllt", x = 300, z = 300 }
-- a unit placed before its definition is known waits for it
check(GG.Tweaks.apply(11, "armpw_abc12") == false and params[11].ledtweak == "armpw_abc12", "a unit without a known definition carries the id and waits")
check(gadget:RecvLuaMsg("tweak|def|armpw_abc12|" .. T.encode64("Boss Pawn") .. "|armpw|" .. T.encode64(TEXT), 0) == true, "the message tweak|def is taken")
check(GG.Tweaks.defs.armpw_abc12 and GG.Tweaks.defs.armpw_abc12.name == "Boss Pawn", "the definition is known with its name")
check(params[11].ledtweakname == "Boss Pawn", "the waiting unit gets the name")
check(called("SetUnitMaxHealth", 11, 2000) and called("SetUnitHealth", 11, 2000), "health: the largest and the current health")
check(called("SetGroundMoveTypeData", 11, "maxSpeed", 90) and called("SetGroundMoveTypeData", 11, "maxWantedSpeed", 90), "speed: the data of the move type")
local cost = called("SetUnitCosts", 11)
check(cost and cost[3].metalCost == 10, "metalcost: SetUnitCosts")
check(called("SetUnitSensorRadius", 11, "los", 600) and called("SetUnitSensorRadius", 11, "airLos", 900), "sightdistance: sight, and 1.5 x into the air")
check(called("SetUnitBuildSpeed", 11, 300), "workertime: the build power")
check(called("SetUnitWeaponState", 11, 1, "range", 500) and called("SetUnitWeaponState", 11, 1, "reloadTime", 0.1), "weapon 1: range and reload time")
check(called("SetUnitWeaponState", 11, 1, "projectileSpeed", 20), "weaponvelocity is given per frame (600 / 30)")
check(called("SetUnitWeaponDamages", 11, 1, "damageAreaOfEffect", 32), "areaofeffect is given as a radius (64 / 2)")
local dmg
for _, c2 in ipairs(calls) do
	if c2[1] == "SetUnitWeaponDamages" and type(c2[4]) == "table" then dmg = c2[4] end
end
check(dmg and dmg[0] == 50 and dmg[1] == 5 and dmg[2] == 50, "damage: default goes to the classes that had the default damage, vtol gets its own value")
check(called("SetUnitMaxRange", 11, 500), "the range the unit attacks from is the longest weapon (the shield does not count)")
check(not called("SetUnitWeaponState", 11, 2), "the second weapon is not touched")
calls = {}
check(GG.Tweaks.apply(12, "armpw_abc12") == false and #calls == 0, "a unit of another type gets no values")
check(gadget:RecvLuaMsg("tweak|def|bad id|x|armpw|" .. T.encode64(TEXT), 0) == true and GG.Tweaks.defs["bad id"] == nil, "an id with other characters is refused")
check(gadget:RecvLuaMsg("led|place|armpw", 0) == false, "a message of another gadget is not taken")
gadget:UnitDestroyed(11)
ok("the gadget in the editor")

-- a finished scenario: the definitions and the places come from the game options; messages are not taken without cheats
load({
	ledtweaks = T.encode64("armpw_abc12,armpw," .. T.encode64("Boss Pawn") .. "," .. T.encode64(TEXT)),
	ledtweakunits = T.encode64("armpw_abc12:100,100,500,500"),
})
units[21] = { name = "armpw", x = 104, z = 98 }
units[22] = { name = "armpw", x = 110, z = 100 } -- a second unit near the same place: only one of them is meant
units[23] = { name = "armllt", x = 500, z = 500 } -- another type at the second place
gadget:GamePreload()
check(GG.Tweaks.defs.armpw_abc12 ~= nil, "the definition comes from the game option ledtweaks")
gadget:GameFrame(5)
check(params[21] and params[21].ledtweak == "armpw_abc12" and called("SetUnitMaxHealth", 21, 2000), "the unit at its place becomes the tweaked unit")
check(params[22] == nil and params[23] == nil, "one unit per entry, and only of the base type")
calls = {}
gadget:GameFrame(30)
check(#calls == 0, "an entry is applied once")
gadget:RecvLuaMsg("tweak|def|armpw_zzzzz|x|armpw|" .. T.encode64(TEXT), 0)
check(GG.Tweaks.defs.armpw_zzzzz == nil, "in a scenario a message cannot add a definition")
ok("the gadget in a scenario")
