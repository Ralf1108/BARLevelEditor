function widget:GetInfo() return { name = "zz lavaroad", desc = "test only: the way of the Carriers through the pass of a Volcano", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lavaroad.lua: two Volcanoes with a Lava Extractor each (build facing 0 and 1: the yard faces another
-- pass), a bot lab and a Carrier on the far side of each (away from the yard). The Carriers haul: they must go around the Volcano to the pass of
-- the yard, load in the yard (its cells are free: TestMoveOrder), leave through the pass and go around again to the lab. Every half second each
-- Carrier is checked: over the wall (nearer than 100 to the middle of its Volcano, not in the pass) or in a stream of lava (at most 12 degrees
-- from a breach, 45 or 225, nearer than 165) = WRONG.
-- Logs "[zzroad]" lines, pictures of a Carrier in the yard, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzroad] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local SETS = {
	{ vol = { CX - 450, CZ }, facing = 0, lab = { CX - 450, CZ + 380 }, carrier = { CX - 450, CZ + 260 } },
	{ vol = { CX + 450, CZ }, facing = 1, lab = { CX + 450, CZ - 380 }, carrier = { CX + 450, CZ - 260 } },
}
local function unitAt(p, name, r)
	for _, u in ipairs(Spring.GetUnitsInCylinder(p[1], p[2], r or 90) or {}) do
		local d = Spring.GetUnitDefID(u)
		if d and UnitDefs[d].name == name then return u end
	end
end
local function yardOf(gen)
	local map = Spring.GetUnitPieceMap(gen)
	local x, y, z = Spring.GetUnitPiecePosDir(gen, map.block8)
	local ux, _, uz = Spring.GetUnitPosition(gen)
	local dx, dz = x - ux, z - uz -- (the direction of the pass: one of the four, as the gadget takes it)
	if math.abs(dx) >= math.abs(dz) then dx, dz = dx >= 0 and 1 or -1, 0 else dx, dz = 0, dz >= 0 and 1 or -1 end
	return x, y, z, ux, uz, dx, dz
end
local function look(x, z, ry, dist)
	Spring.SetCameraTarget(x, Spring.GetGroundHeight(x, z), z, 0)
	local s = Spring.GetCameraState()
	s.px, s.py, s.pz = x, Spring.GetGroundHeight(x, z), z
	if s.dist then s.dist = dist end
	if s.height then s.height = dist end
	if s.ry then s.ry = ry end
	if s.rx then s.rx = 2.5 end
	Spring.SetCameraState(s, 0)
end
local steps = {}
steps[30] = function()
	Spring.SendLuaRulesMsg("led|step")
	for _, s in ipairs(SETS) do
		Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", s.vol[1], s.vol[2]))
		Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|%d", s.vol[1], s.vol[2], s.facing))
		Spring.SendLuaRulesMsg(string.format("led|place|armlab|0|%d|%d|0", s.lab[1], s.lab[2]))
		Spring.SendLuaRulesMsg(string.format("led|place|armlavacarrier|0|%d|%d|0", s.carrier[1], s.carrier[2]))
	end
end
steps[90] = function()
	for i, s in ipairs(SETS) do
		s.gen = unitAt(s.vol, "armlavagen")
		s.c = unitAt(s.carrier, "armlavacarrier")
		local yx, yy, yz, ux, uz, dx, dz = yardOf(s.gen)
		local free = Spring.TestMoveOrder(UnitDefNames.armlavacarrier.id, yx, yy, yz)
		log("set", i, "facing", s.facing, "yard at", math.floor(yx - ux), math.floor(yz - uz), "from the middle; the yard can be driven on:", ok(free))
		local blockedMine = Spring.TestMoveOrder(UnitDefNames.armlavacarrier.id, ux - dx * 20, yy, uz - dz * 20)
		log("set", i, "the furnace side is blocked:", ok(not blockedMine))
		s.wrong, s.loads, s.last = 0, 0, 0
		Spring.GiveOrderToUnit(s.c, 39761, { s.gen }, 0)
	end
end
steps[3600] = function()
	for i, s in ipairs(SETS) do
		log("set", i, "loads", s.loads, "times over the wall or the lava", s.wrong, ok(s.loads >= 2 and s.wrong == 0))
	end
	log("delivered", Spring.GetTeamRulesParam(0, "lavaDelivered"))
	log("done"); Spring.SendCommands("quitforce")
end
local shots = 0
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if f > 90 and f % 15 == 5 then
		for i, s in ipairs(SETS) do
			if s.c and Spring.ValidUnitID(s.c) then
				local cx, _, cz = Spring.GetUnitPosition(s.c)
				local _, _, _, ux, uz, dx, dz = yardOf(s.gen)
				local rx, rz = cx - s.vol[1], cz - s.vol[2]
				local r = math.sqrt(rx * rx + rz * rz)
				local px, pz = cx - ux, cz - uz
				local along, side = px * dx + pz * dz, math.abs(px * dz - pz * dx)
				local inPass = along > -10 and (side < 24 or math.deg(math.atan2(side, along)) < 16)
				local deg = math.deg(math.atan2(rz, rx)) % 360
				local inStream = false
				for _, b in ipairs({ 45, 225 }) do
					inStream = inStream or (math.abs((deg - b + 180) % 360 - 180) < 12 and r < 165 and r > 40)
				end
				if (r < 100 and not inPass) or inStream then
					s.wrong = s.wrong + 1
					log("set", i, "frame", f, "WRONG: the Carrier is", math.floor(r), "from the middle at", math.floor(deg), "degrees", inStream and "(in a stream)" or "(on the wall)")
				end
				local load = Spring.GetUnitRulesParam(s.c, "lavaLoad") or 0
				if load ~= s.last then
					if load > s.last then
						s.loads = s.loads + 1
						log("set", i, "frame", f, "loaded", load, "at", math.floor(r), "from the middle")
						if shots < 2 then
							shots = shots + 1
							look(cx, cz, 0.6, 300)
							steps[f + 20] = function() Spring.SendCommands("screenshot png"); log("picture: set", i, "a Carrier loading in the yard") end
						end
					else
						log("set", i, "frame", f, "delivered, lavaDelivered", Spring.GetTeamRulesParam(0, "lavaDelivered"))
					end
					s.last = load
				end
			end
		end
	end
end
