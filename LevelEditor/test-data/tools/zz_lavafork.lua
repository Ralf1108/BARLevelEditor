function widget:GetInfo() return { name = "zz lavafork", desc = "test only: the Forklift of the Lava Extractor", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lavafork.lua: the Forklift armlavafork (its own model objects3d/Units/armlavafork.s3o, its Lua unit
-- script scripts/Units/armlavafork.lua, no weapons, load 90 in boxes of 30, in the build list of the vehicle plant armvp). A picture of it empty
-- next to armfav; the generator fills its stock for 50 seconds, then Haul: the Forklift loads 3 boxes (picture), unloads them one by one at the
-- vehicle plant, takes what the stock has on the second trip (picture) and brings it. Logs "[zzfork]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzfork] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local GEN = { CX - 300, CZ - 300 }
local PLANT = { CX + 300, CZ + 200 }
local FORK = { CX - 300, CZ - 200 }
local fork, lastLoad, trips, shots = nil, 0, 0, 0
local function unitAt(p, name)
	for _, u in ipairs(Spring.GetUnitsInCylinder(p[1], p[2], 90) or {}) do
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
end
local function shot(what)
	shots = shots + 1
	Spring.SendCommands("screenshot png")
	log("picture", shots, what)
end
local steps = {}
steps[30] = function()
	local fd = UnitDefNames.armlavafork
	log("unit armlavafork", ok(fd ~= nil), fd and (fd.translatedHumanName or fd.humanName) or "", fd and ("weapons " .. #(fd.weapons or {}) .. " model " .. tostring(fd.modelname) .. " script " .. tostring(fd.scriptName)) or "",
		fd and ("lavaload " .. tostring(fd.customParams.lavaload) .. " lavabox " .. tostring(fd.customParams.lavabox) .. " speed " .. tostring(fd.speed)) or "")
	local has = false
	for _, id in ipairs(UnitDefNames.armvp and UnitDefNames.armvp.buildOptions or {}) do has = has or UnitDefs[id].name == "armlavafork" end
	log("vehicle plant armvp builds it", ok(has))
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", GEN[1], GEN[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", GEN[1], GEN[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armvp|0|%d|%d|0", PLANT[1], PLANT[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavafork|0|%d|%d|0", FORK[1], FORK[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armfav|0|%d|%d|0", FORK[1] + 50, FORK[2]))
end
steps[90] = function() look(FORK[1] + 25, FORK[2], 0.9, 200) end
steps[120] = function() shot("empty, next to the Rover armfav") end
steps[150] = function() look(FORK[1], FORK[2], 2.4, 160) end
steps[180] = function() shot("empty, from the front") end
steps[1560] = function()
	fork = unitAt(FORK, "armlavafork")
	local gen = unitAt(GEN, "armlavagen")
	log("forklift", tostring(fork), "generator", tostring(gen), "stock", gen and Spring.GetUnitRulesParam(gen, "lavaStock"))
	if fork and gen then Spring.GiveOrderToUnit(fork, 39761, { gen }, 0) end
end
steps[6000] = function()
	log("delivered", Spring.GetTeamRulesParam(0, "lavaDelivered"), "trips", trips, ok(trips >= 2 and (Spring.GetTeamRulesParam(0, "lavaDelivered") or 0) >= 120))
	log("done"); Spring.SendCommands("quitforce")
end
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if fork and f % 15 == 4 then
		local load = Spring.GetUnitRulesParam(fork, "lavaLoad") or 0
		if load ~= lastLoad then
			log("frame", f, "load", load, "boxes", math.ceil(load / 30), "lavaDelivered", Spring.GetTeamRulesParam(0, "lavaDelivered") or 0)
			if load < lastLoad and load == 0 then
				trips = trips + 1
				if trips >= 2 then steps[f + 60] = steps[6000] end
			end
			lastLoad = load
		end
		-- a picture when it leaves the generator with its boxes (first trip: 3 boxes; second trip: what the stock had)
		local x, _, z = Spring.GetUnitPosition(fork)
		local leaving = load > 0 and x and ((x - GEN[1]) ^ 2 + (z - GEN[2]) ^ 2) > 140 ^ 2 and ((x - GEN[1]) ^ 2 + (z - GEN[2]) ^ 2) < 200 ^ 2
		if leaving and not steps.shotTrip then
			steps.shotTrip = trips + 1
			look(x, z, 0.9, 170)
			steps[f + 20] = function() shot("trip " .. (trips + 1) .. ", " .. math.ceil(load / 30) .. " boxes") end
		elseif load == 0 and steps.shotTrip and steps.shotTrip <= trips then
			steps.shotTrip = nil
		end
	end
end
