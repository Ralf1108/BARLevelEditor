-- Level Editor: saved for scenariooptions.unitloadout and featureloadout
return {
	map = "Full Metal Plate 1.7",
	mapsize = { 12288, 12288 },
	unitlimit = 32000,
	scenario = [==[{
 "version": 2,
 "title": "Tweak Test",
 "author": "Level Editor",
 "summary": "Tweaked units: two Boss Pawns and a Watch Tower next to the normal ones",
 "briefing": "Tweaked units: two Boss Pawns and a Watch Tower next to the normal ones",
 "roles": {
  "0": "s",
  "1": "e"
 },
 "tiers": {
  "0": "123",
  "1": "123"
 },
 "ai": "NullAI",
 "win": "neverend",
 "metal": 2000,
 "energy": 5000,
 "grace": 0,
 "sid": "tweak-test"
}]==],
	tweaks = {
		{ id = "armllt_tower", name = "Watch Tower", base = "armllt", b64 = "eyBhcm1sbHQgPSB7IGhlYWx0aCA9IDUwMDAsIHNpZ2h0ZGlzdGFuY2UgPSA5MDAgfSB9" },
		{ id = "armpw_boss1", name = "Boss Pawn", base = "armpw", b64 = "eyBhcm1wdyA9IHsgZm9vdHByaW50eCA9IDQsIGhlYWx0aCA9IDIwMDAsIG1ldGFsY29zdCA9IDEwLCBzcGVlZCA9IDkwLCB3ZWFwb25kZWZzID0geyBlbWcgPSB7IGRhbWFnZSA9IHsgZGVmYXVsdCA9IDUwIH0sIHJhbmdlID0gNTAwIH0gfSB9IH0" },
	},
	requiredmodoptions = { experimentallegionfaction = "1", experimentalextraunits = "1", releasecandidates = "1" },
	unitloadout = {
		{ name = 'armcom', x = 4500, y = 449, z = 6144, rot = 0, team = 0, neutral = false },
		{ name = 'armllt', x = 5000, y = 449, z = 6400, rot = 0, team = 0, neutral = false, tweak = 'armllt_tower' },
		{ name = 'armllt', x = 5000, y = 449, z = 6600, rot = 0, team = 0, neutral = false },
		{ name = 'armpw', x = 5200, y = 449, z = 5900, rot = 0, team = 0, neutral = false, tweak = 'armpw_boss1' },
		{ name = 'armpw', x = 5200, y = 449, z = 6000, rot = 0, team = 0, neutral = false, tweak = 'armpw_boss1' },
		{ name = 'armpw', x = 5200, y = 449, z = 6100, rot = 0, team = 0, neutral = false },
		{ name = 'corcom', x = 7788, y = 449, z = 6144, rot = 0, team = 1, neutral = false },
	},
	featureloadout = {
	},
}
