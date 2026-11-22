-- Volcano and Lava Generator (proof of concept), the units: in the extra games as gamedata/unitdefs_pre.lua. BAR's gamedata/unitdefs.lua runs it
-- before it loads the unit files, with the still empty table of the unit definitions as UnitDefs (BAR has no file of this name; one of BAR would hide
-- this one, see specs/lava.md). It hooks the table: when a base unit is stored, its copy is stored next to it, and every builder that can build the
-- base unit can build the copy too.
--   Lava Generator (armlavagen, corlavagen, leglavagen): a copy of the metal extractor that stands only on a Volcano (feature lava_volcano); there it
--     makes energy and fills its metal stock (the gadget lava_generator.lua). A model of its own for all three (objects3d/Units/lavagen.s3o, made by
--     LevelEditor/models/make_lava_generator.py: a furnace with lava, a gear wheel, pistons, a yard with metal blocks) and a Lua unit script
--     (scripts/Units/lavagen.lua: it moves the parts and shows the blocks); footprint 6 x 6 (the yard).
--   Carrier (armlavacarrier, corlavacarrier, leglavacarrier): a copy of the light bot of the bot lab without weapons; it carries the metal of a Lava
--     Generator to a factory (the gadget).
--   Cargo Truck (armlavatruck): a copy of the missile truck armsam with a model of its own (objects3d/Units/armlavatruck.s3o, made by
--     LevelEditor/models/make_lava_truck.py: the launcher replaced by a container), without weapons; it carries more (customparams.lavaload).
--   Forklift (armlavafork): a copy of the scout car armfav with a model of its own (objects3d/Units/armlavafork.s3o, made by
--     LevelEditor/models/make_lava_forklift.py: a mast with a fork and three boxes) and a Lua unit script (scripts/Units/armlavafork.lua: it shows
--     the boxes it carries), without weapons; it loads boxes of 30 metal (customparams.lavabox), at most three.
-- The game option lanexpunits=0 (LAN Play, the button Experimental Units off) leaves all of them out; without the option (Level Editor, scenarios)
-- or with lanexpunits=1 they are in.
local defs = UnitDefs
if not defs or getmetatable(defs) then
	return
end
local modOptions = Spring and Spring.GetModOptions and Spring.GetModOptions() or {}
if modOptions.lanexpunits == "0" then
	return
end

local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and copy(v) or v
	end
	return out
end

local function named(d, name, tip)
	d.name = name
	d.description = tip
	d.customparams = d.customparams or {}
	for _, lang in ipairs({ "en", "de" }) do
		d.customparams["i18n_" .. lang .. "_humanname"] = name
		d.customparams["i18n_" .. lang .. "_tooltip"] = tip
	end
	return d
end

local function generator(mex)
	local d = named(copy(mex), "Lava Generator", "Makes energy from the lava of a Volcano and keeps its metal for the Carriers (build it on a Volcano)")
	d.extractsmetal = 0
	d.energyupkeep = 0
	d.energymake = 0 -- (the gadget gives the energy and fills the metal stock, only on a Volcano)
	d.metalcost = 250
	d.energycost = 2000
	d.buildtime = 6000
	d.health = 1200
	d.metalstorage = 0
	d.onoffable = false
	d.objectname = "Units/lavagen.s3o"
	d.script = "Units/lavagen.lua"
	d.footprintx, d.footprintz = 6, 6
	d.collisionvolumetype = "Box"
	d.collisionvolumescales = "88 40 80"
	d.collisionvolumeoffsets = "0 18 0"
	d.usepiececollisionvolumes = nil
	-- a "g" in the yardmap: the engine lets it stand only on a feature with geothermal = true (the Volcano); high resolution, 12 x 12 (footprint 6)
	d.yardmap = "h oooooooooooo oooooooooooo oocbbbbbbcoo oobgbggbgboo oobbgbbgbboo oobgbggbgboo oobgbggbgboo oobbgbbgbboo oobgbggbgboo oocbbbbbbcoo oooooooooooo oooooooooooo"
	local cp = d.customparams
	cp.metal_extractor, cp.standardextractor = nil, nil
	cp.unitgroup = "energy"
	cp.lavagenerator = 1
	return d
end

local function carrier(bot)
	local d = named(copy(bot), "Carrier", "Carries metal: right-click a Lava Generator to haul its metal to the nearest factory, right-click a factory to deliver there (order Haul)")
	d.weapondefs, d.weapons = {}, {}
	d.metalcost = 40
	d.energycost = 600
	d.buildtime = 1500
	local cp = d.customparams
	cp.unitgroup = "util"
	cp.lavacarrier = 1
	return d
end

local function truck(sam)
	local d = named(copy(sam), "Cargo Truck", "Carries 60 metal: right-click a Lava Generator to haul its metal to the nearest factory, right-click a factory to deliver there (order Haul)")
	d.objectname = "Units/armlavatruck.s3o"
	d.weapondefs, d.weapons = {}, {}
	d.airsightdistance = nil
	d.metalcost = 90
	d.energycost = 900
	d.buildtime = 2500
	d.health = 900
	local cp = d.customparams
	cp.maxrange = nil
	cp.unitgroup = "util"
	cp.lavacarrier = 1
	cp.lavaload = 60
	return d
end

local function forklift(fav)
	local d = named(copy(fav), "Forklift", "Carries up to 3 boxes of 30 metal: right-click a Lava Generator to haul its metal to the nearest factory, right-click a factory to deliver there (order Haul)")
	d.objectname = "Units/armlavafork.s3o"
	d.script = "Units/armlavafork.lua"
	d.weapondefs, d.weapons = {}, {}
	d.speed = 45
	d.turninplacespeedlimit = 1.0
	d.turnrate = 400
	d.metalcost = 120
	d.energycost = 1200
	d.buildtime = 3000
	d.health = 1000
	d.sightdistance = 300
	d.collisionvolumeoffsets = "0 5 3"
	d.collisionvolumescales = "16 22 32"
	local cp = d.customparams
	cp.unitgroup = "util"
	cp.lavacarrier = 1
	cp.lavaload = 90
	cp.lavabox = 30
	return d
end

local COPIES = {
	armmex = { "armlavagen", generator }, cormex = { "corlavagen", generator }, legmex = { "leglavagen", generator },
	armpw = { "armlavacarrier", carrier }, corak = { "corlavacarrier", carrier }, leggob = { "leglavacarrier", carrier },
	armsam = { "armlavatruck", truck },
	armfav = { "armlavafork", forklift },
}

setmetatable(defs, {
	__newindex = function(t, name, def)
		rawset(t, name, def)
		if type(def) ~= "table" then
			return
		end
		local c = COPIES[name]
		if c then
			rawset(t, c[1], c[2](def))
		end
		local opts = def.buildoptions
		if type(opts) == "table" then
			local add = {}
			for _, o in pairs(opts) do
				if COPIES[o] then
					add[#add + 1] = COPIES[o][1]
				end
			end
			for _, o in ipairs(add) do
				opts[#opts + 1] = o
			end
		end
	end,
})
