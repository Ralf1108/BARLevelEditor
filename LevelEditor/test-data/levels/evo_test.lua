-- Level Editor: saved for scenariooptions.unitloadout and featureloadout
return {
	map = "Full Metal Plate 1.7",
	mapsize = { 12288, 12288 },
	unitlimit = 32000,
	scenario = [==[{
 "version": 2,
 "title": "Evolution Test",
 "author": "Level Editor",
 "summary": "Evolution on the flat map: kill to evolve, the last one standing wins",
 "briefing": "Evolution on the flat map: kill to evolve, the last one standing wins",
 "win": "neverend",
 "grace": 0,
 "sid": "evo-test"
}]==],
	evolution = {
		enabled = true,
		factor = 160,
		first = 3,
		lives = 3,
		respawn = 5,
		wildHp = 10,
		wilds = 20,
	},
	requiredmodoptions = { experimentallegionfaction = "1", experimentalextraunits = "1", releasecandidates = "1" },
	unitloadout = {
		{ name = 'armcom', x = 5200, y = 449, z = 6144, rot = 0, team = 0, neutral = false },
		{ name = 'corcom', x = 7088, y = 449, z = 6144, rot = 0, team = 1, neutral = false },
	},
	featureloadout = {
	},
}
