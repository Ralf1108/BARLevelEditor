-- The Lava Generator (armlavagen, corlavagen, leglavagen), a proof of concept: a copy of the metal extractor of its faction that stands only on a
-- Volcano (feature lava_volcano) and makes energy and metal there (the gadget lava_generator.lua). In the extra games as gamedata/unitdefs_pre.lua: BAR's
-- gamedata/unitdefs.lua runs it before it loads the unit files, with the still empty table of the unit definitions as UnitDefs (BAR has no file of
-- this name; one of BAR would hide this one, see specs/lava.md). It hooks the table: when a metal extractor is stored, its copy is stored next to it,
-- and every builder that can build the extractor can build the copy too.
local defs = UnitDefs
if not defs or getmetatable(defs) then
	return
end
local LAVA = { armmex = "armlavagen", cormex = "corlavagen", legmex = "leglavagen" }
local NAME, TIP = "Lava Generator", "Makes energy and metal from the lava of a Volcano (build it on a Volcano)"

local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and copy(v) or v
	end
	return out
end

local function lavaCopy(mex)
	local d = copy(mex)
	d.name = NAME
	d.description = TIP
	d.extractsmetal = 0
	d.energyupkeep = 0
	d.energymake = 0 -- (the gadget gives the energy and the metal, only on a Volcano)
	d.metalcost = 250
	d.energycost = 2000
	d.buildtime = 6000
	d.health = 1200
	d.metalstorage = 0
	d.onoffable = false
	-- a "g" in the yardmap: the engine lets it stand only on a feature with geothermal = true (the Volcano)
	d.yardmap = "h cbbbbbbc bgbggbgb bbgbbgbb bgbggbgb bgbggbgb bbgbbgbb bgbggbgb cbbbbbbc"
	d.customparams = d.customparams or {}
	local cp = d.customparams
	cp.metal_extractor, cp.standardextractor = nil, nil
	cp.unitgroup = "energy"
	cp.lavagenerator = 1
	for _, lang in ipairs({ "en", "de" }) do
		cp["i18n_" .. lang .. "_humanname"] = NAME
		cp["i18n_" .. lang .. "_tooltip"] = TIP
	end
	return d
end

setmetatable(defs, {
	__newindex = function(t, name, def)
		rawset(t, name, def)
		if type(def) ~= "table" then
			return
		end
		if LAVA[name] then
			rawset(t, LAVA[name], lavaCopy(def))
		end
		local opts = def.buildoptions
		if type(opts) == "table" then
			local add = {}
			for _, o in pairs(opts) do
				if LAVA[o] then
					add[#add + 1] = LAVA[o]
				end
			end
			for _, o in ipairs(add) do
				opts[#opts + 1] = o
			end
		end
	end,
})
