-- Level Editor: saved for scenariooptions.unitloadout and featureloadout
return {
	map = "Full Metal Plate 1.7",
	mapsize = { 12288, 12288 },
	unitlimit = 32000,
	scenario = [==[{
 "version": 2,
 "title": "Scav and Raptor Test",
 "author": "Level Editor",
 "summary": "Scavenger and Raptor units placed on the flat map, no AI controls them",
 "briefing": "Scavenger and Raptor units placed on the flat map, no AI controls them",
 "roles": {
  "0": "s",
  "1": "e"
 },
 "tiers": {
  "0": "123",
  "1": "123"
 },
 "ai": "BARb",
 "win": "neverend",
 "metal": 2000,
 "energy": 5000,
 "grace": 0,
 "sid": "scav-test"
}]==],
	requiredmodoptions = { experimentallegionfaction = "1", experimentalextraunits = "1", releasecandidates = "1", forceallunits = "1" },
	unitloadout = {
		{ name = 'armcom', x = 4500, y = 449, z = 6144, rot = 0, team = 0, neutral = false },
		{ name = 'armpw_scav', x = 5200, y = 449, z = 5900, rot = 0, team = 0, neutral = false },
		{ name = 'armpw_scav', x = 5200, y = 449, z = 6000, rot = 0, team = 0, neutral = false },
		{ name = 'corak_scav', x = 5200, y = 449, z = 6100, rot = 0, team = 0, neutral = false },
		{ name = 'armllt_scav', x = 5400, y = 449, z = 6000, rot = 0, team = 0, neutral = false },
		{ name = 'armck_scav', x = 5300, y = 449, z = 6300, rot = 0, team = 0, neutral = false },
		{ name = 'raptor_land_swarmer_basic_t1_v1', x = 5600, y = 449, z = 5900, rot = 0, team = 0, neutral = false },
		{ name = 'raptor_land_swarmer_basic_t1_v1', x = 5600, y = 449, z = 6000, rot = 0, team = 0, neutral = false },
		{ name = 'raptor_land_assault_basic_t2_v1', x = 5700, y = 449, z = 6200, rot = 0, team = 0, neutral = false },
		{ name = 'raptor_land_spiker_basic_t2_v1', x = 5700, y = 449, z = 6300, rot = 0, team = 0, neutral = false },
		{ name = 'raptor_turret_basic_t2_v1', x = 5900, y = 449, z = 6100, rot = 0, team = 0, neutral = false },
		{ name = 'raptor_hive', x = 6000, y = 449, z = 6400, rot = 0, team = 0, neutral = false },
		{ name = 'corcom', x = 7788, y = 449, z = 6144, rot = 0, team = 1, neutral = false },
	},
	featureloadout = {
	},
}
