function widget:GetInfo() return { name = "zz lavabelt", desc = "test only: the crates on the four belts of a Lava Extractor ride alike to the pads", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lavabelt.lua: a Volcano with a Lava Extractor in the middle of the map. For 12 seconds the positions of
-- the crates item1..item8 (two on each belt: east, south, west, north) are read every frame (Spring.GetUnitPiecePosDir): how far out a crate
-- shows (from the middle of the extractor) and how far it is from the middle line of its belt. OK when on every belt the crates ride out from
-- the platform (at most 34) onto the pad (at least 106), never off the line, at the same time as on the other belts. A picture from above. Logs
-- "[zzbelt]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzbelt] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local DIRS = { { 1, 0, "east" }, { 0, 1, "south" }, { -1, 0, "west" }, { 0, -1, "north" } }
local gen, pieces
local belts = {} -- k -> { lo, hi, off, starts = { frames a crate showed near the platform } }
local steps = {}
steps[30] = function()
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", CX, CZ))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", CX, CZ))
end
steps[120] = function()
	for _, u in ipairs(Spring.GetUnitsInCylinder(CX, CZ, 60) or {}) do
		if UnitDefs[Spring.GetUnitDefID(u)].name == "armlavagen" then gen = u end
	end
	pieces = gen and Spring.GetUnitPieceMap(gen)
	log("extractor", gen, "pieces", pieces and pieces.item1)
	Spring.SetCameraState({ name = "ta", mode = 1, px = CX, py = 0, pz = CZ + 60, height = 420, angle = 0.95, flipped = -1 }, 0)
	for k = 1, 4 do belts[k] = { lo = 1e9, hi = -1e9, off = 0, starts = {} } end
end
steps[400] = function() Spring.SendCommands("screenshot png"); log("picture: the belts") end
steps[500] = function()
	local first
	for k, b in ipairs(belts) do
		local s = b.starts[1] or -1
		first = first or s
		log(DIRS[k][3], "crates from", math.floor(b.lo), "to", math.floor(b.hi), "off the line at most", math.floor(b.off), "first start frame", s,
			ok(b.lo <= 34 and b.hi - b.lo >= 76 and b.off <= 4 and math.abs(s - first) <= 2))
	end
	log("done"); Spring.SendCommands("quitforce")
end
local shown = {}
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if not (pieces and f > 140 and f < 500) then return end
	local ux, _, uz = Spring.GetUnitPosition(gen)
	for n = 1, 8 do
		local k = math.floor((n - 1) / 2) + 1
		local d = DIRS[k]
		local p = pieces["item" .. n]
		local x, _, z = Spring.GetUnitPiecePosDir(gen, p)
		if x then
			local rx, rz = x - ux, z - uz
			local r = rx * d[1] + rz * d[2] -- out along the belt
			local s = math.abs(-rx * d[2] + rz * d[1]) -- off its middle line
			local b = belts[k]
			-- (a hidden crate stands at its start; only the moving ones count: the way it went between two frames)
			local was = shown[n]
			if was and math.abs(r - was) > 0.05 then
				b.lo, b.hi = math.min(b.lo, r, was), math.max(b.hi, r, was)
				b.off = math.max(b.off, s)
				if was < 34 and r >= was and #b.starts < 3 and (b.starts[#b.starts] or -99) < f - 20 then b.starts[#b.starts + 1] = f end
			end
			shown[n] = r
		end
	end
end
