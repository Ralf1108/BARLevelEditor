function widget:GetInfo() return { name = "zz lavatruck", desc = "test only: the Cargo Truck of the Lava Extractor", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lavatruck.lua: the Cargo Truck armlavatruck (its own model objects3d/Units/armlavatruck.s3o, no weapons,
-- load 60, in the build list of the vehicle plant armvp), two pictures of it close up (from the side and from behind), then it hauls once: Haul on
-- a Lava Extractor on a Volcano, 60 metal to the vehicle plant (team rules lavaDelivered). At the storage pad it backs up: when it loads, its back
-- is at the pad (its front points away from the extractor, its middle about 160 out) and it loads crate by crate (10 metal at a time, 6 steps); it
-- unloads crate by crate too. Two pictures while it loads (the tailgate down, crates sliding in). Logs "[zztruck]" lines, ends with quitforce.
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
local truck, lastLoad, gen = nil, 0, nil
local ups, downs, docked = 0, 0, nil
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
	gen = unitAt(GEN, "armlavagen")
	log("truck", tostring(truck), "generator", tostring(gen))
	if truck and gen then Spring.GiveOrderToUnit(truck, 39761, { gen }, 0) end
	Spring.SetCameraState({ name = "ta", mode = 1, px = CX, py = 0, pz = CZ + 100, height = 1400, angle = 0.8, flipped = -1 }, 0)
end
steps[2400] = function()
	log("delivered", Spring.GetTeamRulesParam(0, "lavaDelivered"), ok((Spring.GetTeamRulesParam(0, "lavaDelivered") or 0) >= 60))
	log("done"); Spring.SendCommands("quitforce")
end
-- (on Hold Position: it must not haul on its own before the pictures; the order Haul works on Hold Position too)
function widget:UnitCreated(u, defID)
	if UnitDefs[defID].name == "armlavatruck" then Spring.GiveOrderToUnit(u, CMD.MOVE_STATE, { 0 }, 0) end
end
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if truck and f % 15 == 4 then
		local load = Spring.GetUnitRulesParam(truck, "lavaLoad") or 0
		if load ~= lastLoad then
			log("frame", f, load > lastLoad and "loaded" or "unloaded", load, "lavaDelivered", Spring.GetTeamRulesParam(0, "lavaDelivered") or 0)
			if load > lastLoad then ups = ups + 1 else downs = downs + 1 end
			if lastLoad == 0 and load > 0 and not docked and gen then
				local tx, _, tz = Spring.GetUnitPosition(truck)
				local gx, _, gz = Spring.GetUnitPosition(gen)
				local rx, rz = tx - gx, tz - gz
				local r = math.sqrt(rx * rx + rz * rz)
				local dx, _, dz = Spring.GetUnitDirection(truck)
				local dot = (dx * rx + dz * rz) / r
				docked = true
				log("first crate:", math.floor(r), "from the middle of the extractor, front outwards", string.format("%.2f", dot), ok(r > 150 and r < 170 and dot > 0.9))
				look(tx, tz, 0.6, 160)
				steps[f + 2] = function() Spring.SendCommands("screenshot png"); log("picture: the truck loads at the pad") end
				steps[f + 40] = function() Spring.SendCommands("screenshot png"); log("picture: more crates on the bed") end
			end
			if load == 0 and lastLoad > 0 then
				log("loaded in", ups, "steps", ok(ups >= 6), "unloaded in", downs, "steps", ok(downs >= 6))
				steps[f + 60] = steps[2400]
			end
			lastLoad = load
		end
	end
end
