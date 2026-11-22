-- The Volcano (feature "lava_volcano"), a proof of concept: the Lava Extractor is built on it and makes energy and metal from the lava; a geothermal
-- plant on it makes its normal energy.
-- In the extra games as features/lava_volcano.lua: BAR's gamedata/featuredefs.lua loads every features/*.lua of the game archives.
-- geothermal = true: the engine lets only buildings with a "g" in the yardmap stand on it (the Lava Extractor, also the geothermal plants)
-- and puts the geothermal smoke on it. The looks are a stand-in (a rock of BAR and the crack of BAR's geothermal vent of the map editor);
-- the gadget lava_generator.lua draws the glow of the lava around it.
return {
	lava_volcano = {
		name = "lava_volcano",
		description = "Volcano: a Lava Extractor on it makes energy and metal (Carriers fetch the metal), a geothermal plant energy",
		object = "rocks30/rocks30_def_01.s3o",
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
		footprintX = 4,
		footprintZ = 4,
		upright = false,
		hitdensity = 0,
		useBuildingGroundDecal = true,
		buildingGroundDecalDecaySpeed = 2.0,
		buildingGroundDecalType = "editor_geovent_crack.dds",
		buildingGroundDecalSizeX = 6,
		buildingGroundDecalSizeY = 6,
		customparams = {
			category = "geo",
			lavavolcano = 1,
		},
	},
}
