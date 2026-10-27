-- Level Editor: saved for scenariooptions.unitloadout and featureloadout
return {
	map = "Full Metal Plate 1.7",
	mapsize = { 12288, 12288 },
	unitlimit = 32000,
	scenario = [==[{
 "version": 2,
 "title": "CTF Test",
 "author": "Level Editor",
 "summary": "Capture the Flag on the flat map: hold 3 flags at once",
 "briefing": "Capture the Flag on the flat map: hold 3 flags at once",
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
 "sid": "ctf-test"
}]==],
	capture = {
		amount = 100,
		enabled = true,
		flags = {
			{ team = -1, x = 6144, z = 5600 },
			{ team = -1, x = 6144, z = 6144 },
			{ team = -1, x = 6144, z = 6688 },
		},
		homes = {
			{ team = 0, x = 4800, z = 6144 },
			{ team = 1, x = 7488, z = 6144 },
		},
		radius = 100,
		returnTime = 0,
		score = 3,
		speed = 50,
		visible = true,
	},
	requiredmodoptions = { experimentallegionfaction = "1", experimentalextraunits = "1", releasecandidates = "1" },
	unitloadout = {
		{ name = 'armcom', x = 4500, y = 449, z = 6144, rot = 0, team = 0, neutral = false },
		{ name = 'armflash', x = 5000, y = 449, z = 5900, rot = 0, team = 0, neutral = false },
		{ name = 'armflash', x = 5000, y = 449, z = 6400, rot = 0, team = 0, neutral = false },
		{ name = 'armpw', x = 5000, y = 449, z = 6144, rot = 0, team = 0, neutral = false },
		{ name = 'corcom', x = 7788, y = 449, z = 6144, rot = 0, team = 1, neutral = false },
		{ name = 'corgator', x = 7300, y = 449, z = 5900, rot = 0, team = 1, neutral = false },
		{ name = 'corgator', x = 7300, y = 449, z = 6400, rot = 0, team = 1, neutral = false },
		{ name = 'corak', x = 7300, y = 449, z = 6144, rot = 0, team = 1, neutral = false },
	},
	featureloadout = {
	},
}
