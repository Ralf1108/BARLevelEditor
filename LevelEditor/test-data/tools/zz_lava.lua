function widget:GetInfo() return { name = "zz lava", desc = "test only: Volcano, Lava Generator and Carrier", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lava.lua: the definitions (feature lava_volcano, units armlavagen / corlavagen, in the build lists of the
-- constructors; the Carrier armlavacarrier in the bot lab), two Volcanoes and two Lava Generators placed through the editor (one on a Volcano, one beside
-- it), the energy and the metal stock of both, the build rule (TestBuildOrder on a Volcano and beside it; the geothermal plant armgeo on the Volcano),
-- a picture; then a Carrier hauls (the order Haul, 39761, on the generator): its first loads go to the nearest bot lab (L1), after the order Haul on
-- the other lab (L2) to that one; the team rules parameter lavaDelivered counts. Logs "[zzlava]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzlava] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local A = { CX - 200, CZ } -- Volcano with a generator on it
local B = { CX + 200, CZ } -- Volcano left free (the build rule)
local C = { CX, CZ + 300 } -- generator without a Volcano
local L1 = { CX - 200, CZ + 700 } -- bot lab near the generator
local L2 = { CX + 700, CZ - 600 } -- bot lab farther away (chosen by a right click)
local K = { CX - 200, CZ + 160 } -- the Carrier
local function unitAt(p, name)
	for _, u in ipairs(Spring.GetUnitsInCylinder(p[1], p[2], 60) or {}) do
		local d = Spring.GetUnitDefID(u)
		if d and UnitDefs[d].name == (name or "armlavagen") then return u end
	end
end
local function dist(u, p)
	local x, _, z = Spring.GetUnitPosition(u or -1)
	return x and math.floor(math.sqrt((x - p[1]) ^ 2 + (z - p[2]) ^ 2)) or -1
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
	local kd = UnitDefNames.armlavacarrier
	log("unit armlavacarrier", ok(kd ~= nil), kd and (kd.translatedHumanName or kd.humanName) or "", kd and ("weapons " .. #(kd.weapons or {})) or "",
		"corlavacarrier", ok(UnitDefNames.corlavacarrier ~= nil), "leglavacarrier", ok(UnitDefNames.leglavacarrier ~= nil))
	for _, b in ipairs({ "armlab", "corlab", "leglab" }) do
		local bd = UnitDefNames[b]
		local n = b:sub(1, 3) .. "lavacarrier"
		log("bot lab", b, bd and (has(bd.buildOptions, n) and n or "none") or "missing")
	end
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
	Spring.SendLuaRulesMsg(string.format("led|place|armlab|0|%d|%d|0", L1[1], L1[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlab|0|%d|%d|0", L2[1], L2[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavacarrier|0|%d|%d|0", K[1], K[2]))
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
local carrier, lastLoad, deliveries = nil, 0, {}
steps[300] = function()
	carrier = unitAt(K, "armlavacarrier")
	local ga = unitAt(A)
	log("carrier", tostring(carrier), "generator", tostring(ga), "stock", ga and Spring.GetUnitRulesParam(ga, "lavaStock"), "(only the stock: no metal for the team yet)")
	local has
	for _, c in ipairs(carrier and Spring.GetUnitCmdDescs(carrier) or {}) do has = has or c.id == 39761 end
	log("the Carrier has the button Haul", ok(has))
	if carrier and ga then Spring.GiveOrderToUnit(carrier, 39761, { ga }, 0) end
end
steps[340] = function()
	log("after Haul on the generator: hauling", carrier and Spring.GetUnitRulesParam(carrier, "lavaHauling"), ok(carrier and Spring.GetUnitRulesParam(carrier, "lavaHauling") == 1))
end
steps[1600] = function()
	local l2 = unitAt(L2, "armlab")
	log("Haul on the far lab", tostring(l2))
	if carrier and l2 then Spring.GiveOrderToUnit(carrier, 39761, { l2 }, 0) end
end
steps[3600] = function()
	local n1, n2 = 0, 0
	for _, d in ipairs(deliveries) do
		if d.f < 1600 and d.to == "L1" then n1 = n1 + 1 end
		if d.f > 1650 and d.to == "L2" then n2 = n2 + 1 end
	end
	log("deliveries", #deliveries, "to L1 before the choice", n1, ok(n1 >= 1), "to L2 after it", n2, ok(n2 >= 1), "lavaDelivered", Spring.GetTeamRulesParam(0, "lavaDelivered"))
	log("done"); Spring.SendCommands("quitforce")
end
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if carrier and f % 15 == 4 then
		local load = Spring.GetUnitRulesParam(carrier, "lavaLoad") or 0
		if load ~= lastLoad then
			local d1, d2 = dist(carrier, L1), dist(carrier, L2)
			local to = load == 0 and (d1 < d2 and "L1" or "L2") or "-"
			if load == 0 then deliveries[#deliveries + 1] = { f = f, to = to } end
			log("frame", f, load > 0 and "loaded" or "delivered", load > 0 and load or lastLoad, "distance to L1", d1, "to L2", d2, "lavaDelivered", Spring.GetTeamRulesParam(0, "lavaDelivered") or 0)
			lastLoad = load
		end
	end
end
