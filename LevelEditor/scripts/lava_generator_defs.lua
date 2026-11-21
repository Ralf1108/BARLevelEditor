-- Volcano and Lava Generator (proof of concept), the units: in the extra games as gamedata/unitdefs_pre.lua. BAR's gamedata/unitdefs.lua runs it
-- before it loads the unit files, with the still empty table of the unit definitions as UnitDefs (BAR has no file of this name; one of BAR would hide
-- this one, see specs/lava.md). It hooks the table: when a base unit is stored, its copy is stored next to it, and every builder that can build the
-- base unit can build the copy too.
--   Lava Generator (armlavagen, corlavagen, leglavagen): a copy of the metal extractor that stands only on a Volcano (feature lava_volcano); there it
--     makes energy and fills its metal stock (the gadget lava_generator.lua).
--   Carrier (armlavacarrier, corlavacarrier, leglavacarrier): a copy of the light bot of the bot lab without weapons; it carries the metal of a Lava
--     Generator to a factory (the gadget).
local defs = UnitDefs
if not defs or getmetatable(defs) then
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
	-- a "g" in the yardmap: the engine lets it stand only on a feature with geothermal = true (the Volcano)
	d.yardmap = "h cbbbbbbc bgbggbgb bbgbbgbb bgbggbgb bgbggbgb bbgbbgbb bgbggbgb cbbbbbbc"
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

local COPIES = {
	armmex = { "armlavagen", generator }, cormex = { "corlavagen", generator }, legmex = { "leglavagen", generator },
	armpw = { "armlavacarrier", carrier }, corak = { "corlavacarrier", carrier }, leggob = { "leglavacarrier", carrier },
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
