function widget:GetInfo() return { name = "zz volcano", desc = "test only: the model of the Volcano and its lava", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_volcano.lua: the Volcano (feature lava_volcano, its own model objects3d/Units/lavavolcano.s3o; the lava
-- drawn by the gadget lava_generator.lua). One Volcano alone, one with a Lava Extractor on it (which must still make energy). Pictures close up from
-- the angle of the game and from lower, and two pictures one second apart (the lava moves). Logs "[zzvol]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzvol] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local V1 = { CX - 250, CZ }
local V2 = { CX + 250, CZ }
local function look(x, z, ry, dist, rx)
	Spring.SetCameraTarget(x, Spring.GetGroundHeight(x, z), z, 0)
	local s = Spring.GetCameraState()
	s.px, s.py, s.pz = x, Spring.GetGroundHeight(x, z), z
	if s.dist then s.dist = dist end
	if s.height then s.height = dist end
	if s.ry then s.ry = ry end
	if s.rx then s.rx = rx end
	Spring.SetCameraState(s, 0)
end
local function shot(what)
	Spring.SendCommands("screenshot png")
	log("picture:", what)
end
local steps = {}
steps[30] = function()
	local fd = FeatureDefNames.lava_volcano
	log("feature lava_volcano", ok(fd ~= nil), fd and ("model " .. tostring(fd.modelname or (fd.model and fd.model.path)) .. " geothermal " .. tostring(fd.geoThermal) .. " footprint " .. tostring(fd.footprintX or fd.xsize)) or "")
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", V1[1], V1[2]))
	Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", V2[1], V2[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", V2[1], V2[2]))
end
steps[90] = function() look(V1[1], V1[2], 0, 420, 2.6) end
steps[120] = function() shot("the Volcano alone, the angle of the game") end
steps[121] = function() end
steps[150] = function() shot("the same one second later (the lava moved)") end
steps[160] = function() look(V1[1], V1[2], 0.7, 360, 2.25) end
steps[190] = function() shot("the Volcano alone, lower") end
steps[200] = function() look(V2[1], V2[2], -0.5, 400, 2.4) end
steps[230] = function()
	shot("the Volcano with a Lava Extractor")
	for _, u in ipairs(Spring.GetUnitsInCylinder(V2[1], V2[2], 60) or {}) do
		log("extractor", u, "energy", Spring.GetUnitRulesParam(u, "lavaEnergy"), ok(Spring.GetUnitRulesParam(u, "lavaEnergy") == 200))
	end
end
steps[260] = function() log("done"); Spring.SendCommands("quitforce") end
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
end
