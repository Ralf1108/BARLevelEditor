function widget:GetInfo() return { name = "zz lavatruck", desc = "test only: the Cargo Truck of the Lava Extractor", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lavatruck.lua: the Cargo Truck armlavatruck (its own model objects3d/Units/armlavatruck.s3o, no weapons,
-- load 60, in the build list of the vehicle plant armvp), two pictures of it close up (from the side and from behind), then it hauls once: Haul on
-- a Lava Extractor on a Volcano, 60 metal to the vehicle plant (team rules lavaDelivered). Logs "[zztruck]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zztruck] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local GEN = { CX - 300, CZ - 300 }
local PLANT = { CX + 400, CZ + 300 }
local TRUCK = { CX, CZ }
local truck, lastLoad = nil, 0
local function unitAt(p, name)
	for _, u in ipairs(Spring.GetUnitsInCylinder(p[1], p[2], 80) or {}) do
		local d = Spring.GetUnitDefID(u)
		if d and UnitDefs[d].name == name then return u end
	end
end
-- close to (x, z): the camera of the game as it is (its tilt), only nearer (dist) and turned (ry added to its turn)
local function look(x, z, ry, dist)
	Spring.SetCameraTarget(x, Spring.GetGroundHeight(x, z), z, 0)
	local s = Spring.GetCameraState()
	s.px, s.py, s.pz = x, Spring.GetGroundHeight(x, z), z
	if s.dist then s.dist = dist end
	if s.height then s.height = dist end
	if s.ry then s.ry = s.ry + ry end
	Spring.SetCameraState(s, 0)
	log("camera", s.name, "rx", s.rx, "ry", s.ry, "dist", s.dist, "height", s.height)
end
local steps = {}
steps[30] = function()
	local td = UnitDefNames.armlavatruck
	log("unit armlavatruck", ok(td ~= nil), td and (td.translatedHumanName or td.humanName) or "", td and ("weapons " .. #(td.weapons or {}) .. " model " .. tostring(td.modelname)) or "", td and ("lavaload " .. tostring(td.customParams.lavaload)) or "")
	local has = false
	for _, id in ipairs(UnitDefNames.armvp and UnitDefNames.armvp.buildOptions or {}) do has = has or UnitDefs[id].name == "armlavatruck" end
	log("vehicle plant armvp builds it", ok(has))
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", GEN[1], GEN[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", GEN[1], GEN[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armvp|0|%d|%d|0", PLANT[1], PLANT[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavatruck|0|%d|%d|1", TRUCK[1], TRUCK[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armsam|0|%d|%d|1", TRUCK[1], TRUCK[2] + 70))
end
steps[90] = function() look(TRUCK[1], TRUCK[2] + 35, 0.9, 260) end
steps[120] = function() Spring.SendCommands("screenshot png"); log("picture: from the side (the truck in front, armsam behind it)") end
steps[150] = function() look(TRUCK[1], TRUCK[2], 2.6, 220) end
steps[180] = function() Spring.SendCommands("screenshot png"); log("picture: from behind") end
steps[200] = function()
	truck = unitAt(TRUCK, "armlavatruck")
	local gen = unitAt(GEN, "armlavagen")
	log("truck", tostring(truck), "generator", tostring(gen))
	if truck and gen then Spring.GiveOrderToUnit(truck, 39761, { gen }, 0) end
	Spring.SetCameraState({ name = "ta", mode = 1, px = CX, py = 0, pz = CZ + 100, height = 1400, angle = 0.8, flipped = -1 }, 0)
end
steps[2400] = function()
	log("delivered", Spring.GetTeamRulesParam(0, "lavaDelivered"), ok((Spring.GetTeamRulesParam(0, "lavaDelivered") or 0) >= 60))
	log("done"); Spring.SendCommands("quitforce")
end
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if truck and f % 15 == 4 then
		local load = Spring.GetUnitRulesParam(truck, "lavaLoad") or 0
		if load ~= lastLoad then
			log("frame", f, load > 0 and "loaded" or "delivered", load > 0 and load or lastLoad, "lavaDelivered", Spring.GetTeamRulesParam(0, "lavaDelivered") or 0)
			lastLoad = load
			if load == 0 then steps[f + 60] = steps[2400] end
		end
	end
end
