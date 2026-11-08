function widget:GetInfo() return { name = "zz brood", desc = "test only: a raptor healer builds a Raptor Brood Chamber, the chamber grows raptors", layer = 1000000, enabled = true } end
-- Test widget of pve_test.ps1 -Brood -Widget zz_brood.lua: one human and a Raptors AI in the same ally team, the game option tweakdefs9 = the file lan_lobby/raptor_brood_defs.lua.
-- A healer of the AI team is given with /give next to the commander, the human orders it to build a raptor_brood_chamber, the chamber is ordered to grow raptors, the raptors
-- are sent away from the chamber. Logs "[zzbrood]" lines (resources of the AI team, build progress, where the raptors appear, whether they walk out) and ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzbrood] " .. table.concat(t, " "))
end

local aiTeam, healer, chamber, cx, cz
local phase = "start"
local waitUntil = 0
local grown = {}
local queueChecked = false
local BUILD = { "raptor_land_swarmer_basic_t1_v1", "raptor_land_swarmer_basic_t1_v1", "raptor_land_assault_basic_t2_v1" }
local MAX_FRAME = 20000

local function findAiTeam()
	for _, t in ipairs(Spring.GetTeamList()) do
		local ok, ai = pcall(Spring.GetTeamLuaAI, t)
		if ok and ai and ai:find("Raptors", 1, true) then return t end
	end
end

local function res(team)
	local m, ms, _, mi = Spring.GetTeamResources(team, "metal")
	local e, es, _, ei = Spring.GetTeamResources(team, "energy")
	return string.format("metal %d/%d (+%.1f) energy %d/%d (+%.1f)", m or -1, ms or -1, mi or -1, e or -1, es or -1, ei or -1)
end

local function unitsNamed(team, name)
	local out = {}
	for _, id in ipairs(Spring.GetTeamUnits(team) or {}) do
		if UnitDefs[Spring.GetUnitDefID(id)].name == name then out[#out + 1] = id end
	end
	return out
end

local function pointAt(x, z)
	Spring.SetCameraTarget(x, Spring.GetGroundHeight(x, z), z, 0)
end

local lastUnpause = 0
function widget:Update()
	local _, _, paused = Spring.GetGameSpeed()
	if paused and os.clock() - lastUnpause > 1 then
		lastUnpause = os.clock()
		Spring.SendCommands("pause 0")
	end
	if phase == "give" then
		-- /give puts the unit at the mouse pointer: the pointer is moved onto the spot each frame until the healer is there
		local sx, sy = Spring.WorldToScreenCoords(cx + 150, Spring.GetGroundHeight(cx + 150, cz), cz)
		Spring.WarpMouse(sx, sy)
	end
end

function widget:GameFrame(n)
	if n > MAX_FRAME then log("FAIL timeout in phase", phase); Spring.SendCommands("quitforce"); return end
	if n < waitUntil then return end
	if phase == "start" and n >= 30 then
		aiTeam = findAiTeam()
		local mine = Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}
		-- in a LAN game the Raptor gadget moves a human of the Raptors' ally team into the Raptors team (no commander): then the start position
		local x, _, z
		if mine[1] then x, _, z = Spring.GetUnitPosition(mine[1]) else x, _, z = Spring.GetTeamStartPosition(Spring.GetMyTeamID()) end
		if not x or x < 0 then x, z = Game.mapSizeX * 0.1, Game.mapSizeZ * 0.5 end
		cx, cz = x, z
		local def = UnitDefNames.raptor_brood_chamber
		log("AI team", aiTeam, "commander at", math.floor(cx), math.floor(cz), "tweakdefs set in slot:", (function()
			for k, v in pairs(Spring.GetModOptions() or {}) do if k:match("^tweakdefs%d*$") and v ~= "" then return k end end
			return "none"
		end)())
		log("raptor_brood_chamber defined:", def ~= nil and "OK" or "FAIL", def and ("factory " .. tostring(def.isFactory) .. " builder " .. tostring(def.isBuilder) .. " options " .. #(def.buildOptions or {})) or "")
		local hd = UnitDefNames.raptor_land_swarmer_heal_t1_v1
		local can = false
		for _, id in ipairs(hd and hd.buildOptions or {}) do if def and id == def.id then can = true end end
		log("the healer can build the chamber:", can and "OK" or "FAIL")
		-- the name the game shows (BAR's luaui/i18nhelpers.lua fills translatedHumanName; the widget "Tweakdefs Custom Unit Names" gives the text)
		local shown = def and def.translatedHumanName
		log("name in the game:", tostring(shown), shown == "Raptor Brood Chamber" and "OK" or "FAIL")
		log("resources of the AI team at the start:", res(aiTeam))
		if not def or not can then Spring.SendCommands("quitforce"); return end
		Spring.SendCommands("cheat 1")
		pointAt(cx + 300, cz)
		phase = "give"; waitUntil = n + 20
	elseif phase == "give" then
		local h = unitsNamed(aiTeam, "raptor_land_swarmer_heal_t1_v1")
		if #h == 0 then
			Spring.SendCommands("give 1 raptor_land_swarmer_heal_t1_v1 " .. aiTeam)
			waitUntil = n + 15
			return
		end
		healer = h[1]
		local hx, _, hz = Spring.GetUnitPosition(healer)
		log("healer given at", math.floor(hx), math.floor(hz))
		local nx, nz = math.floor((cx + 400) / 16) * 16, math.floor(cz / 16) * 16
		local test = Spring.TestBuildOrder(UnitDefNames.raptor_brood_chamber.id, nx, Spring.GetGroundHeight(nx, nz), nz, 0)
		Spring.GiveOrderToUnit(healer, -UnitDefNames.raptor_brood_chamber.id, { nx, Spring.GetGroundHeight(nx, nz), nz, 0 }, 0)
		local q = Spring.GetUnitCommands(healer, 5) or {}
		local ids = {}
		for _, c in ipairs(q) do ids[#ids + 1] = tostring(c.id) end
		-- the order may already have become the repair of the started chamber (40 = CMD.REPAIR): the check is that the chamber appears
		log("build order for the chamber at", nx, nz, "TestBuildOrder", test, "queue of the healer:", table.concat(ids, " "))
		Spring.SendCommands("setspeed 10")
		phase = "building"; waitUntil = n + 30
	elseif phase == "building" then
		local ns = unitsNamed(aiTeam, "raptor_brood_chamber")
		if ns[1] and not chamber then log("frame", n, "the healer started the chamber: OK") end
		chamber = ns[1]
		if n % 300 == 0 then
			local p = chamber and select(5, Spring.GetUnitHealth(chamber))
			log("frame", n, "chamber", tostring(chamber), "build progress", p and string.format("%.2f", p) or "-", "healer orders", Spring.GetUnitCommands(healer, 0), res(aiTeam))
		end
		if chamber and select(5, Spring.GetUnitHealth(chamber)) >= 1 then
			log("frame", n, "the chamber is finished:", "OK", res(aiTeam))
			for _, name in ipairs(BUILD) do Spring.GiveOrderToUnit(chamber, -UnitDefNames[name].id, {}, 0) end
			phase = "growing"; waitUntil = n + 30
		end
	elseif phase == "growing" then
		if not queueChecked then
			-- the orders of a widget go over the network: they are in the queue of the chamber a few frames later
			queueChecked = true
			local fq = Spring.GetFactoryCommands(chamber, -1) or {}
			log("orders in the chamber:", #fq, "of", #BUILD, #fq == #BUILD and "OK" or "FAIL")
		end
		local nx, _, nz = Spring.GetUnitPosition(chamber)
		for _, name in ipairs({ "raptor_land_swarmer_basic_t1_v1", "raptor_land_assault_basic_t2_v1" }) do
			for _, id in ipairs(unitsNamed(aiTeam, name)) do
				local ux, _, uz = Spring.GetUnitPosition(id)
				-- only what grows at the chamber (the waves of the Raptor spawner come from its own hives far away)
				if not grown[id] and ux and (ux - nx) ^ 2 + (uz - nz) ^ 2 < 400 * 400 then
					local _, _, _, _, bp = Spring.GetUnitHealth(id)
					if bp and bp >= 1 then
						local x, _, z = Spring.GetUnitPosition(id)
						grown[id] = { x = x, z = z, frame = n }
						log("frame", n, "grown:", name, "at", math.floor(x), math.floor(z), "distance to the chamber", math.floor(math.sqrt((x - nx) ^ 2 + (z - nz) ^ 2)), res(aiTeam))
						Spring.GiveOrderToUnit(id, CMD.MOVE, { nx + 500, Spring.GetGroundHeight(nx + 500, nz + 200), nz + 200 }, 0)
					end
				end
			end
		end
		local count = 0
		for _ in pairs(grown) do count = count + 1 end
		if n % 300 == 0 then
			local building = Spring.GetUnitIsBuilding(chamber)
			local bp = building and select(5, Spring.GetUnitHealth(building))
			log("frame", n, "grown so far", count, "orders left in the chamber", #(Spring.GetFactoryCommands(chamber, -1) or {}), "building", building and UnitDefs[Spring.GetUnitDefID(building)].name or "nothing",
				bp and string.format("%.2f", bp) or "", res(aiTeam))
		end
		if count >= #BUILD then phase = "walk"; waitUntil = n + 450 end
	elseif phase == "walk" then
		local nx, _, nz = Spring.GetUnitPosition(chamber)
		local out = 0
		for id, g in pairs(grown) do
			local x, _, z = Spring.GetUnitPosition(id)
			local d = x and math.floor(math.sqrt((x - nx) ^ 2 + (z - nz) ^ 2)) or -1
			log("raptor", id, "now", d, "away from the chamber (was", math.floor(math.sqrt((g.x - nx) ^ 2 + (g.z - nz) ^ 2)) .. ")")
			if d > 200 then out = out + 1 end
		end
		local total = 0
		for _ in pairs(grown) do total = total + 1 end
		log("RESULT raptors that walked out of the chamber:", out, "of", total, out == total and "OK" or "FAIL")
		log("END")
		Spring.SendCommands("quitforce")
		phase = "end"
	end
end
