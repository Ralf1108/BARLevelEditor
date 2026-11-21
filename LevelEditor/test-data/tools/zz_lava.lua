function widget:GetInfo() return { name = "zz lava", desc = "test only: Volcano and Lava Generator", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lava.lua: the definitions (feature lava_volcano, units armlavagen / corlavagen, in the build lists of the
-- constructors), two Volcanoes and two Lava Generators placed through the editor (one on a Volcano, one beside it), the energy and metal of both, the
-- build rule (TestBuildOrder on a Volcano and beside it; the geothermal plant armgeo on the Volcano) and a picture. Logs "[zzlava]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzlava] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local A = { CX - 200, CZ } -- Volcano with a generator on it
local B = { CX + 200, CZ } -- Volcano left free (the build rule)
local C = { CX, CZ + 300 } -- generator without a Volcano
local function unitAt(p)
	for _, u in ipairs(Spring.GetUnitsInCylinder(p[1], p[2], 30) or {}) do
		local d = Spring.GetUnitDefID(u)
		if d and UnitDefs[d].name == "armlavagen" then return u end
	end
end
local function has(list, name)
	for _, v in ipairs(list or {}) do
		if UnitDefs[v] and UnitDefs[v].name == name then return true end
	end
	return false
end
local steps = {}
steps[30] = function()
	local fd, ud, cd = FeatureDefNames.lava_volcano, UnitDefNames.armlavagen, UnitDefNames.corlavagen
	log("feature lava_volcano", ok(fd ~= nil), fd and ("geothermal " .. tostring(fd.geoThermal)) or "")
	log("unit armlavagen", ok(ud ~= nil), ud and (ud.translatedHumanName or ud.humanName) or "", ud and ("needGeo " .. tostring(ud.needGeo) .. " extractsMetal " .. tostring(ud.extractsMetal)) or "")
	log("unit corlavagen", ok(cd ~= nil), "leglavagen", ok(UnitDefNames.leglavagen ~= nil))
	for _, b in ipairs({ "armck", "armcv", "armcom", "corck", "legck" }) do
		local bd = UnitDefNames[b]
		log("builder", b, bd and (has(bd.buildOptions, "armlavagen") and "armlavagen" or has(bd.buildOptions, "corlavagen") and "corlavagen" or has(bd.buildOptions, "leglavagen") and "leglavagen" or "none") or "missing")
	end
end
steps[60] = function()
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", A[1], A[2]))
	Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", B[1], B[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", A[1], A[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", C[1], C[2]))
	Spring.SetCameraTarget(CX, Spring.GetGroundHeight(CX, CZ), CZ + 100, 0.5)
end
local e0
steps[120] = function() e0 = select(1, Spring.GetTeamResources(0, "energy")) end
steps[240] = function()
	local ua, uc = unitAt(A), unitAt(C)
	local function rp(u, k) return u and Spring.GetUnitRulesParam(u, k) end
	log("generator on the Volcano", tostring(ua), "energy", rp(ua, "lavaEnergy"), "metal", rp(ua, "lavaMetal"), ok(rp(ua, "lavaEnergy") == 200 and rp(ua, "lavaMetal") == 2))
	log("generator without a Volcano", tostring(uc), "energy", rp(uc, "lavaEnergy"), "metal", rp(uc, "lavaMetal"), ok(rp(uc, "lavaEnergy") == 0 and rp(uc, "lavaMetal") == 0))
	if ua then
		log("GetUnitResources (metal make, metal use, energy make, energy use)", Spring.GetUnitResources(ua))
	end
	local _, _, _, inc = Spring.GetTeamResources(0, "energy")
	local _, _, _, minc = Spring.GetTeamResources(0, "metal")
	log("team income: energy", inc, "metal", minc)
	local ud = UnitDefNames.armlavagen.id
	local tb = Spring.TestBuildOrder(ud, B[1], Spring.GetGroundHeight(B[1], B[2]), B[2], 0)
	local tn = Spring.TestBuildOrder(ud, B[1], Spring.GetGroundHeight(B[1], B[2] + 400), B[2] + 400, 0)
	log("build rule: on the free Volcano", tb, ok(tb and tb > 0), "on plain ground", tn, ok(tn == 0))
	local tg = Spring.TestBuildOrder(UnitDefNames.armgeo.id, B[1], Spring.GetGroundHeight(B[1], B[2]), B[2], 0)
	log("geothermal plant armgeo on the free Volcano", tg, ok(tg and tg > 0))
	Spring.SendCommands("screenshot png")
end
steps[300] = function() log("done"); Spring.SendCommands("quitforce") end
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
end
