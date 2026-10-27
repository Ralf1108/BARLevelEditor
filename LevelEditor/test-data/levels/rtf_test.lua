-- Level Editor: saved for scenariooptions.unitloadout and featureloadout
return {
	map = "Full Metal Plate 1.7",
	mapsize = { 12288, 12288 },
	unitlimit = 32000,
	scenario = [==[{
 "version": 2,
 "title": "RTF Test",
 "author": "Level Editor",
 "summary": "Reclaim the Fame on the flat map: farm the crystals in the middle",
 "briefing": "Reclaim the Fame on the flat map: farm the crystals in the middle",
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
 "sid": "rtf-test"
}]==],
	reclaim = {
		enabled = true,
		score = 2000,
		rate = 100,
		f1 = 100,
		f2 = 200,
		f3 = 400,
		visible = true,
		statics = false,
		ground = true,
		ships = true,
		air = false,
	},
	requiredmodoptions = { experimentallegionfaction = "1", experimentalextraunits = "1", releasecandidates = "1" },
	unitloadout = {
		{ name = 'armcom', x = 4500, y = 449, z = 6144, rot = 0, team = 0, neutral = false },
		{ name = 'armck', x = 5200, y = 449, z = 5900, rot = 0, team = 0, neutral = false },
		{ name = 'armck', x = 5200, y = 449, z = 6000, rot = 0, team = 0, neutral = false },
		{ name = 'armck', x = 5200, y = 449, z = 6300, rot = 0, team = 0, neutral = false },
		{ name = 'armck', x = 5200, y = 449, z = 6400, rot = 0, team = 0, neutral = false },
		{ name = 'corcom', x = 7788, y = 449, z = 6144, rot = 0, team = 1, neutral = false },
		{ name = 'corck', x = 7100, y = 449, z = 5900, rot = 0, team = 1, neutral = false },
		{ name = 'corck', x = 7100, y = 449, z = 6000, rot = 0, team = 1, neutral = false },
		{ name = 'corck', x = 7100, y = 449, z = 6300, rot = 0, team = 1, neutral = false },
		{ name = 'corck', x = 7100, y = 449, z = 6400, rot = 0, team = 1, neutral = false },
	},
	featureloadout = {
		{ name = 'pilha_crystal1', x = 5844, y = 449, z = 5844, rot = 0 },
		{ name = 'pilha_crystal1', x = 6444, y = 449, z = 5844, rot = 0 },
		{ name = 'pilha_crystal1', x = 5844, y = 449, z = 6444, rot = 0 },
		{ name = 'pilha_crystal1', x = 6444, y = 449, z = 6444, rot = 0 },
		{ name = 'pilha_crystal2', x = 6144, y = 449, z = 5800, rot = 0 },
		{ name = 'pilha_crystal2', x = 6144, y = 449, z = 6490, rot = 0 },
		{ name = 'pilha_crystal3', x = 6144, y = 449, z = 6144, rot = 0 },
	},
}
