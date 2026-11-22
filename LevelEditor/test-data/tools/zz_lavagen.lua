function widget:GetInfo() return { name = "zz lavagen", desc = "test only: the model of the Lava Extractor and the blocks of its yard", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lavagen.lua: the Lava Extractor with its own model (objects3d/Units/lavagen.s3o) and Lua unit script
-- (scripts/Units/lavagen.lua) on a Volcano, and one beside it (stands still). Pictures close up: at the start (stock nearly empty), after a minute
-- (the yard fills with blocks), after a Forklift took 3 boxes (fewer blocks). Logs "[zzgen]" lines (definition, stock), ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzgen] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local GEN = { CX - 200, CZ - 200 }
local PLANT = { CX + 400, CZ + 300 }
local FORK = { CX - 200, CZ - 60 }
local gen, fork, lastLoad = nil, nil, 0
local lowView = false
local function unitAt(p, name)
	for _, u in ipairs(Spring.GetUnitsInCylinder(p[1], p[2], 90) or {}) do
		local d = Spring.GetUnitDefID(u)
		if d and UnitDefs[d].name == name then return u end
	end
end
local function look(x, z, ry, dist)
	Spring.SetCameraTarget(x, Spring.GetGroundHeight(x, z), z, 0)
	local s = Spring.GetCameraState()
	s.px, s.py, s.pz = x, Spring.GetGroundHeight(x, z), z
	if s.dist then s.dist = dist end
	if s.height then s.height = dist end
	if s.ry then s.ry = s.ry + ry end
	log("camera", s.name, "rx", s.rx, "ry", s.ry)
	if s.rx then s.rx = lowView and 2.25 or 2.6 end -- (2.6: the tilt of the game; smaller: more from the side)
	Spring.SetCameraState(s, 0)
end
local function stock() return gen and Spring.GetUnitRulesParam(gen, "lavaStock") or -1 end
local function shot(what)
	Spring.SendCommands("screenshot png")
	log("picture:", what, "stock", stock(), "blocks", math.ceil(math.max(0, stock()) * 6 / 200))
end
local steps = {}
steps[30] = function()
	local gd = UnitDefNames.armlavagen
	log("armlavagen", ok(gd ~= nil), gd and ("model " .. tostring(gd.modelname) .. " script " .. tostring(gd.scriptName) .. " footprint " .. gd.xsize / 2 .. " x " .. gd.zsize / 2 .. " needGeo " .. tostring(gd.needGeo)) or "")
	for _, n in ipairs({ "corlavagen", "leglavagen" }) do
		local d = UnitDefNames[n]
		log(n, d and (tostring(d.modelname) .. " " .. tostring(d.scriptName)) or "missing")
	end
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", GEN[1], GEN[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", GEN[1], GEN[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", GEN[1] + 260, GEN[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armvp|0|%d|%d|0", PLANT[1], PLANT[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavafork|0|%d|%d|0", FORK[1], FORK[2]))
end
steps[90] = function()
	gen = unitAt(GEN, "armlavagen")
	local other = unitAt({ GEN[1] + 260, GEN[2] }, "armlavagen")
	log("generator", tostring(gen), "beside the Volcano", tostring(other), "energy", gen and Spring.GetUnitRulesParam(gen, "lavaEnergy"), other and Spring.GetUnitRulesParam(other, "lavaEnergy"))
	look(GEN[1], GEN[2], 0.5, 260)
end
steps[150] = function() shot("at the start, from the front left") end
steps[160] = function() lowView = true; look(GEN[1], GEN[2], -0.6, 240) end
steps[200] = function() shot("at the start, from the front right, lower") end
steps[210] = function() look(GEN[1], GEN[2], 0.4, 200) end
steps[250] = function() shot("at the start, from the front left, lower") end
steps[260] = function() lowView = false end
steps[1900] = function() look(GEN[1], GEN[2], 0.5, 260) end
steps[1930] = function() shot("after a minute") end
steps[1950] = function()
	fork = unitAt(FORK, "armlavafork")
	if fork and gen then Spring.GiveOrderToUnit(fork, 39761, { gen }, 0) end
end
steps[3000] = function() log("done"); Spring.SendCommands("quitforce") end
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if fork and f % 15 == 4 then
		local load = Spring.GetUnitRulesParam(fork, "lavaLoad") or 0
		if load ~= lastLoad then
			log("frame", f, "forklift load", load, "stock", stock())
			if load == 90 then
				local x, _, z = Spring.GetUnitPosition(gen)
				look(x, z, 0.5, 260)
				steps[f + 30] = function() shot("the Forklift took 3 boxes") end
				steps[f + 60] = steps[3000]
			end
			lastLoad = load
		end
	end
end
