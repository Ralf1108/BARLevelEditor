-- The Volcano (feature "lava_volcano"), a proof of concept: the Lava Extractor is built on it and makes energy and metal from the lava; a geothermal
-- plant on it makes its normal energy.
-- In the extra games as features/lava_volcano.lua: BAR's gamedata/featuredefs.lua loads every features/*.lua of the game archives.
-- geothermal = true: the engine lets only buildings with a "g" in the yardmap stand on it (the Lava Extractor, also the geothermal plants)
-- and puts the geothermal smoke on it. The model (objects3d/Units/lavavolcano.s3o, LevelEditor/models/make_lava_volcano.py) is a crater of rock
-- with three breaches, textured like BAR's rocks; the gadget lava_generator.lua draws the lava in it (a lake and three streams, moving).
return {
	lava_volcano = {
		name = "lava_volcano",
		description = "Volcano: a Lava Extractor on it makes energy and metal (Carriers fetch the metal), a geothermal plant energy",
		object = "Units/lavavolcano.s3o",
		blocking = false,
		burnable = false,
		flammable = false,
		geothermal = true,
		indestructible = true,
		reclaimable = false,
		autoreclaimable = false,
		energy = 0,
		metal = 0,
		damage = 40000,
		footprintX = 6,
		footprintZ = 6,
		upright = false,
		hitdensity = 0,
		collisionvolumetype = "CylY",
		collisionvolumescales = "196 22 196",
		collisionvolumeoffsets = "0 6 0",
		customparams = {
			category = "geo",
			lavavolcano = 1,
		},
	},
}
