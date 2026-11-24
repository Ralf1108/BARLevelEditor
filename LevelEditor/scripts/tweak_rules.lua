-- Tweaked units ("clones") of the Level Editor: what the widget page (led_tweaks.lua) and the gadget (unit_tweaks.lua) share. Pure Lua, no engine calls:
-- reading a tweakunits text (plain or base64), writing it again, and the list of the fields that can be changed for a unit in a running game.
-- A clone is a placed unit of a base type whose values the gadget changes; the unit definitions themselves cannot change after the game has loaded.
--   T.parse(text)                 the table of a tweakunits text ({ unitname = { field = value, ... }, ... }; keys in lower case) or nil, error text
--   T.serialize(t)                a table as Lua text (keys sorted: the same table gives the same text)
--   T.encode64(s), T.decode64(s)  base64url without padding (level file, messages, game options); decode64 also reads the standard alphabet and padding
--   T.walk(base, tw, ud, weaponDefs, visitor)   goes through the tweak of one unit and calls
--        visitor.unit(key, value, field)                  a unit field of T.UNIT
--        visitor.weapon(indexes, wname, key, value, field) a weapon field of T.WEAPON; indexes = the weapon numbers of the unit with this weapon definition
--        visitor.damage(indexes, wname, damages)          the damage table of a weapon ({ default = n, <armor class> = n })
--        visitor.ignored(path, why)                       a field that cannot be changed in a running game
--        visitor.error(path, why)                         a value of the wrong type
--   T.check(base, tw, ud, weaponDefs)   { applied = { text ... }, ignored = { text ... }, errors = { text ... } } for the display
--   T.HELP                        the text of the yellow "!" button: what works and what does not
local T = {}

-- ---------------------------------------------------------------- base64url
local ALPHA = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
local VALUE = {}
for i = 1, #ALPHA do
	VALUE[ALPHA:byte(i)] = i - 1
end
VALUE[("+"):byte()] = 62
VALUE[("/"):byte()] = 63

function T.encode64(s)
	local out = {}
	for i = 1, #s, 3 do
		local a, b, c = s:byte(i, i + 2)
		local n = a * 65536 + (b or 0) * 256 + (c or 0)
		local c1, c2, c3, c4 = math.floor(n / 262144), math.floor(n / 4096) % 64, math.floor(n / 64) % 64, n % 64
		out[#out + 1] = ALPHA:sub(c1 + 1, c1 + 1) .. ALPHA:sub(c2 + 1, c2 + 1) .. (b and ALPHA:sub(c3 + 1, c3 + 1) or "") .. (c and ALPHA:sub(c4 + 1, c4 + 1) or "")
	end
	return table.concat(out)
end

-- (padding at the end is "=" in the standard form; BAR's tweakunits option writes "_" for it)
function T.decode64(s)
	s = s:gsub("%s", ""):gsub("[=_]+$", "")
	local out, acc, bits = {}, 0, 0
	for i = 1, #s do
		local v = VALUE[s:byte(i)]
		if not v then
			return nil
		end
		acc, bits = acc * 64 + v, bits + 6
		if bits >= 8 then
			bits = bits - 8
			local b = math.floor(acc / 2 ^ bits)
			out[#out + 1] = string.char(b)
			acc = acc - b * 2 ^ bits
		end
	end
	return table.concat(out)
end

-- ---------------------------------------------------------------- reading and writing
local function lowerKeys(t)
	local out = {}
	for k, v in pairs(t) do
		out[type(k) == "string" and k:lower() or k] = type(v) == "table" and lowerKeys(v) or v
	end
	return out
end

-- the table of "return <text>", run in an empty environment (the text cannot call anything); nil, error text
local function tableOf(text)
	local chunk, err = (loadstring or load)("return " .. text)
	if not chunk then
		return nil, err
	end
	if setfenv then
		setfenv(chunk, {})
	end
	local ok, data = pcall(chunk)
	if not ok then
		return nil, data
	end
	if type(data) ~= "table" then
		return nil, "the text is no table"
	end
	return data
end

local function shortError(err)
	return (tostring(err):gsub("^%[string [^%]]*%]:", "line "):gsub("%s+", " "))
end

-- A tweakunits text, plain ("{ armpw = { health = 2000 } }", also with "return" in front) or the same in base64
function T.parse(text)
	if type(text) ~= "string" then
		return nil, "no text"
	end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return nil, "the text is empty"
	end
	local plain = text
	if not text:find("{", 1, true) then
		local decoded = T.decode64(text)
		if not decoded or decoded == "" then
			if text:find("%s") and (loadstring or load)(text) then
				return nil, "this is program code (a tweakdefs text): only a tweakunits table is supported"
			end
			return nil, "neither a Lua table nor base64"
		end
		plain = decoded:gsub("^%s+", ""):gsub("%s+$", "")
	end
	plain = plain:gsub("^return%s+", "")
	local data, err = tableOf(plain)
	if not data then
		-- program code (statements) compiles on its own but not behind "return": that is a tweakdefs text
		if (loadstring or load)(plain) and not plain:find("^{") then
			return nil, "this is program code (a tweakdefs text): only a tweakunits table is supported"
		end
		return nil, "the Lua text is not correct: " .. shortError(err)
	end
	data = lowerKeys(data)
	local n = 0
	for unit, tw in pairs(data) do
		if type(unit) ~= "string" or type(tw) ~= "table" then
			return nil, "every entry must be  unitname = { ... }  (found: " .. tostring(unit) .. ")"
		end
		n = n + 1
	end
	if n == 0 then
		return nil, "the table names no unit"
	end
	return data
end

local function sortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		keys[#keys + 1] = k
	end
	table.sort(keys, function(a, b)
		if type(a) == type(b) then
			return a < b
		end
		return type(a) == "number"
	end)
	return keys
end
T.sortedKeys = sortedKeys

-- a number as text: whole numbers without a point, others with up to four decimals (the %g of the game's Lua writes six decimals)
local function numberText(v)
	if v == math.floor(v) and math.abs(v) < 1e9 then
		return string.format("%d", v)
	end
	return (string.format("%.4f", v):gsub("0+$", ""):gsub("%.$", ""))
end
T.numberText = numberText

function T.serialize(v)
	local tv = type(v)
	if tv == "table" then
		local parts = {}
		for _, k in ipairs(sortedKeys(v)) do
			local key = (type(k) == "string" and k:match("^[%a_][%w_]*$")) and k or ("[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "]")
			parts[#parts + 1] = key .. " = " .. T.serialize(v[k])
		end
		return "{ " .. table.concat(parts, ", ") .. (#parts > 0 and " }" or "}")
	elseif tv == "string" then
		return string.format("%q", v)
	elseif tv == "number" then
		return numberText(v)
	end
	return tostring(v)
end

-- ---------------------------------------------------------------- the fields a running game can change
-- kind: the type of the value; label: the text of the display; get(ud) / get(wd): the value of the base unit (for "old -> new"), nil when unknown
local function num(label, get)
	return { kind = "number", label = label, get = get }
end
local function bool(label, get)
	return { kind = "boolean", label = label, get = get }
end

T.UNIT = {
	health = num("health", function(ud) return ud.health end),
	speed = num("speed", function(ud) return ud.speed end),
	maxacc = num("acceleration", function(ud) return ud.maxAcc end),
	maxdec = num("braking", function(ud) return ud.maxDec end),
	turnrate = num("turn rate", function(ud) return ud.turnRate end),
	metalcost = num("metal cost", function(ud) return ud.metalCost end),
	energycost = num("energy cost", function(ud) return ud.energyCost end),
	buildtime = num("build time", function(ud) return ud.buildTime end),
	sightdistance = num("sight", function(ud) return ud.losRadius end),
	airsightdistance = num("air sight", function(ud) return ud.airLosRadius end),
	radardistance = num("radar", function(ud) return ud.radarRadius end),
	sonardistance = num("sonar", function(ud) return ud.sonarRadius end),
	radardistancejam = num("jammer", function(ud) return ud.jammerRadius end),
	seismicdistance = num("seismic", function(ud) return ud.seismicRadius end),
	workertime = num("build power", function(ud) return ud.buildSpeed end),
	metalmake = num("metal income", function(ud) return ud.metalMake end),
	energymake = num("energy income", function(ud) return ud.energyMake end),
	mass = num("mass", function(ud) return ud.mass end),
	stealth = bool("stealth", function(ud) return ud.stealth end),
	sonarstealth = bool("sonar stealth", function(ud) return ud.sonarStealth end),
}
-- older names of the same fields
T.ALIAS = { maxdamage = "health", buildcostmetal = "metalcost", buildcostenergy = "energycost" }

T.WEAPON = {
	range = num("range", function(wd) return wd.range end),
	reloadtime = num("reload time", function(wd) return wd.reload end),
	areaofeffect = num("area of effect", function(wd) return wd.damageAreaOfEffect end),
	edgeeffectiveness = num("edge effectiveness", function(wd) return wd.edgeEffectiveness end),
	weaponvelocity = num("projectile speed", function(wd) return wd.projectilespeed and wd.projectilespeed * 30 or nil end),
	burst = num("burst", function(wd) return wd.salvoSize end),
	burstrate = num("burst rate", function(wd) return wd.salvoDelay end),
	projectiles = num("projectiles", function(wd) return wd.projectiles end),
	accuracy = num("accuracy", function() return nil end),
	sprayangle = num("spray angle", function() return nil end),
	impulsefactor = num("impulse", function() return nil end),
}

T.HELP = table.concat({
	"A tweaked unit is the normal unit with changed values.",
	"The game cannot make new unit types while it runs.",
	"",
	"WORKS: health, speed, maxacc, maxdec, turnrate,",
	"  metalcost, energycost, buildtime, workertime,",
	"  sightdistance, airsightdistance, radardistance,",
	"  sonardistance, radardistancejam, seismicdistance,",
	"  metalmake, energymake, mass, stealth, sonarstealth.",
	"  Weapons (weapondefs = { name = { ... } }): range,",
	"  reloadtime, damage, areaofeffect, edgeeffectiveness,",
	"  weaponvelocity, burst, burstrate, projectiles,",
	"  accuracy, sprayangle, impulsefactor.",
	"",
	"DOES NOT WORK (ignored, listed at the entry):",
	"  model, size, footprint, movement type, new or other",
	"  weapons, build options, customparams, explosions, wrecks.",
	"",
	"GOOD TO KNOW: only placed units are tweaked, a unit built",
	"  later by a factory is the normal one. The info of the game",
	"  still shows the name and the values of the normal unit.",
}, "\n")

local function typeOk(field, value)
	if field.kind == "boolean" then
		return type(value) == "boolean"
	end
	return type(value) == "number"
end

-- the weapon numbers of the unit that use the weapon definition <base>_<wname>
local function weaponIndexes(base, wname, ud, weaponDefs)
	local out = {}
	local want = (base .. "_" .. wname):lower()
	for i, w in ipairs(ud.weapons or {}) do
		local wd = weaponDefs[w.weaponDef]
		if wd and tostring(wd.name):lower() == want then
			out[#out + 1] = i
		end
	end
	return out
end

function T.walk(base, tw, ud, weaponDefs, visitor)
	for _, rawKey in ipairs(sortedKeys(tw)) do
		local value = tw[rawKey]
		local key = rawKey
		if T.ALIAS[key] then
			key = T.ALIAS[key]
		end
		local field = T.UNIT[key]
		if key == "weapondefs" then
			if type(value) ~= "table" then
				visitor.error("weapondefs", "a table is expected")
			else
				for _, wname in ipairs(sortedKeys(value)) do
					local wt = value[wname]
					local idx = weaponIndexes(base, tostring(wname), ud, weaponDefs)
					if type(wt) ~= "table" then
						visitor.error("weapondefs." .. tostring(wname), "a table is expected")
					elseif #idx == 0 then
						visitor.ignored("weapondefs." .. tostring(wname), "the unit carries no weapon of this name")
					else
						for _, wk in ipairs(sortedKeys(wt)) do
							local wv = wt[wk]
							local path = "weapondefs." .. tostring(wname) .. "." .. tostring(wk)
							local wf = T.WEAPON[wk]
							if wk == "damage" then
								local ok = type(wv) == "table"
								for _, dv in pairs(ok and wv or {}) do
									ok = ok and type(dv) == "number"
								end
								if ok then
									visitor.damage(idx, wname, wv)
								else
									visitor.error(path, "a table of numbers is expected")
								end
							elseif not wf then
								visitor.ignored(path, "cannot be changed in a running game")
							elseif not typeOk(wf, wv) then
								visitor.error(path, "a " .. wf.kind .. " is expected")
							else
								visitor.weapon(idx, wname, wk, wv, wf)
							end
						end
					end
				end
			end
		elseif not field then
			visitor.ignored(tostring(rawKey), "cannot be changed in a running game")
		elseif not typeOk(field, value) then
			visitor.error(tostring(rawKey), "a " .. field.kind .. " is expected")
		else
			visitor.unit(key, value, field)
		end
	end
end

local function show(v)
	if type(v) == "number" then
		return numberText(v)
	end
	return tostring(v)
end

-- What the tweak does to the unit, as texts for the display
function T.check(base, tw, ud, weaponDefs)
	local out = { applied = {}, ignored = {}, errors = {} }
	if not ud then
		out.errors[1] = "unknown unit: " .. tostring(base)
		return out
	end
	local function change(label, old, new)
		out.applied[#out.applied + 1] = old ~= nil and (label .. " " .. show(old) .. " -> " .. show(new)) or (label .. " = " .. show(new))
	end
	T.walk(base, tw, ud, weaponDefs, {
		unit = function(key, value, field)
			change(field.label, field.get(ud), value)
		end,
		weapon = function(idx, wname, key, value, field)
			local wd = weaponDefs[ud.weapons[idx[1]].weaponDef]
			change(tostring(wname) .. " " .. field.label, wd and field.get(wd) or nil, value)
		end,
		damage = function(idx, wname, damages)
			local wd = weaponDefs[ud.weapons[idx[1]].weaponDef]
			for _, k in ipairs(sortedKeys(damages)) do
				local old = (k == "default" and wd and type(wd.damages) == "table") and wd.damages[0] or nil
				change(tostring(wname) .. " damage (" .. tostring(k) .. ")", old, damages[k])
			end
		end,
		ignored = function(path, why)
			out.ignored[#out.ignored + 1] = path .. ": " .. why
		end,
		error = function(path, why)
			out.errors[#out.errors + 1] = path .. ": " .. why
		end,
	})
	return out
end

return T
