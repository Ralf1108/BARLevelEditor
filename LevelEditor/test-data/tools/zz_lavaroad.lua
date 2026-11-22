function widget:GetInfo() return { name = "zz lavaroad", desc = "test only: the Carriers load at the storage pads outside a Volcano", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lavaroad.lua: two Volcanoes with a Lava Extractor each. Set 1 as start_experimental.bat places it: a
-- Carrier, a Cargo Truck and a Forklift side by side to the right, a vehicle plant behind them (do they get in each other's way?). Set 2: a Carrier
-- south of the Volcano, a bot lab north of it (it must go around). All of them haul: they load at the nearest storage pad outside the crater.
-- Every half second each vehicle is checked: in the crater (nearer than 112 to the middle) or in a stream of lava (at most 12 degrees from a
-- breach, 45 or 225, between 98 and 165) = WRONG. Logs "[zzroad]" lines, two pictures, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzroad] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local SETS = {
	{ vol = { CX - 700, CZ }, plant = { "armvp", CX - 700 + 470, CZ },
		units = { { "armlavacarrier", CX - 700 + 270, CZ - 60 }, { "armlavatruck", CX - 700 + 270, CZ }, { "armlavafork", CX - 700 + 270, CZ + 60 } } },
	{ vol = { CX + 500, CZ }, plant = { "armlab", CX + 500, CZ - 420 }, units = { { "armlavacarrier", CX + 500, CZ + 300 } } },
}
local vehicles = {} -- { u, set, name, loads, last, wrong }
local function unitAt(x, z, name, r)
	for _, u in ipairs(Spring.GetUnitsInCylinder(x, z, r or 60) or {}) do
		local d = Spring.GetUnitDefID(u)
		if d and UnitDefs[d].name == name then return u end
	end
end
local function look(x, z, dist)
	Spring.SetCameraState({ name = "ta", mode = 1, px = x, py = 0, pz = z + 80, height = dist, angle = 0.95, flipped = -1 }, 0)
end
local steps = {}
steps[30] = function()
	Spring.SendLuaRulesMsg("led|step")
	for _, s in ipairs(SETS) do
		Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", s.vol[1], s.vol[2]))
		Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", s.vol[1], s.vol[2]))
		Spring.SendLuaRulesMsg(string.format("led|place|%s|0|%d|%d|0", s.plant[1], s.plant[2], s.plant[3]))
		for _, v in ipairs(s.units) do
			Spring.SendLuaRulesMsg(string.format("led|place|%s|0|%d|%d|0", v[1], v[2], v[3]))
		end
	end
end
steps[90] = function()
	for i, s in ipairs(SETS) do
		s.gen = unitAt(s.vol[1], s.vol[2], "armlavagen")
		for _, v in ipairs(s.units) do
			local u = unitAt(v[2], v[3], v[1])
			if u then
				vehicles[#vehicles + 1] = { u = u, set = i, name = v[1], loads = 0, last = 0, wrong = 0 }
				Spring.GiveOrderToUnit(u, 39761, { s.gen }, 0)
			end
		end
	end
	log("vehicles hauling:", #vehicles)
	look(SETS[1].vol[1] + 120, SETS[1].vol[2], 900)
end
steps[1500] = function() Spring.SendCommands("screenshot png"); log("picture: set 1 after 45 seconds") end
steps[1530] = function() look(SETS[1].vol[1], SETS[1].vol[2], 420) end
steps[1560] = function() Spring.SendCommands("screenshot png"); log("picture: the belts and pads close up") end
steps[3900] = function()
	for _, v in ipairs(vehicles) do
		log("set", v.set, v.name, "loads", v.loads, "times in the crater or the lava", v.wrong, ok(v.loads >= 1 and v.wrong == 0)) -- (set 1: three share 2 metal per second)
	end
	log("delivered", Spring.GetTeamRulesParam(0, "lavaDelivered"))
	log("done"); Spring.SendCommands("quitforce")
end
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if f > 90 and f % 15 == 5 then
		for _, v in ipairs(vehicles) do
			if Spring.ValidUnitID(v.u) then
				local s = SETS[v.set]
				local cx, _, cz = Spring.GetUnitPosition(v.u)
				local rx, rz = cx - s.vol[1], cz - s.vol[2]
				local r = math.sqrt(rx * rx + rz * rz)
				local deg = math.deg(math.atan2(rz, rx)) % 360
				local inStream = false
				for _, b in ipairs({ 45, 225 }) do
					inStream = inStream or (math.abs((deg - b + 180) % 360 - 180) < 12 and r > 98 and r < 165)
				end
				if r < 112 or inStream then
					v.wrong = v.wrong + 1
					log("set", v.set, v.name, "frame", f, "WRONG:", math.floor(r), "from the middle at", math.floor(deg), "degrees", inStream and "(in a stream)" or "(in the crater)")
				end
				local load = Spring.GetUnitRulesParam(v.u, "lavaLoad") or 0
				if load > v.last and v.last == 0 then
					v.loads = v.loads + 1
					log("set", v.set, v.name, "frame", f, "loaded at", math.floor(r), "from the middle,", math.floor(deg), "degrees")
				end
				v.last = load
			end
		end
	end
end
