-- Level Editor: saved for scenariooptions.unitloadout and featureloadout
return {
	map = "Full Metal Plate 1.7",
	mapsize = { 12288, 12288 },
	unitlimit = 32000,
	scenario = [==[{
 "version": 2,
 "title": "TD Test",
 "author": "Level Editor",
 "summary": "Tower Defense on the flat map: stop the waves before they reach the goal",
 "briefing": "Tower Defense on the flat map: stop the waves before they reach the goal",
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
 "sid": "td-test"
}]==],
	towerdefense = {
		banned = { },
		bannedTech = { },
		economy = true,
		enabled = true,
		fog = false,
		goal = { 7400, 6144 },
		leaks = 10,
		spawn = { 4900, 6144 },
		waves = {
			{ count = 5, fac = "arm", gap = 0, hp = 100, kind = "vb", tech = "1" },
			{ count = 5, fac = "cor", gap = 10, hp = 100, kind = "vb", tech = "1" },
		},
		waypoints = { },
		width = 8,
	},
	requiredmodoptions = { experimentallegionfaction = "1", experimentalextraunits = "1", releasecandidates = "1" },
	unitloadout = {
		{ name = 'armcom', x = 7600, y = 449, z = 6144, rot = 0, team = 0, neutral = false },
		{ name = 'armllt', x = 7300, y = 449, z = 6000, rot = 0, team = 0, neutral = false },
		{ name = 'armllt', x = 7300, y = 449, z = 6288, rot = 0, team = 0, neutral = false },
		{ name = 'armllt', x = 7200, y = 449, z = 6144, rot = 0, team = 0, neutral = false },
	},
	featureloadout = {
	},
}
