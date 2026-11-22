function widget:GetInfo() return { name = "zz lavaauto", desc = "test only: vehicles haul on their own only on Maneuver or Roam", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_lavaauto.lua: a Volcano with a Lava Extractor and a bot lab; two Carriers without an order: H on Hold
-- Position, M on Maneuver (set when they appear). M must start hauling on its own (lavaHauling 1, a load), H never. Then M gets a Move order (it
-- stops hauling) and must haul again once it got there (its last extractor); then Stop: it must stay idle. H then gets the order Haul and hauls (an
-- order works on Hold Position). Logs "[zzauto]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzauto] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local CX, CZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local GEN = { CX, CZ }
local LAB = { CX + 500, CZ + 300 }
local SPOTS = { H = { CX - 300, CZ + 250 }, M = { CX - 300, CZ + 350 } }
local units = {} -- "H" / "M" -> unitID
local loads = { H = 0, M = 0 }
local last = { H = 0, M = 0 }
local function hauling(u) return Spring.GetUnitRulesParam(u, "lavaHauling") == 1 end
local steps = {}
steps[30] = function()
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|feature|lava_volcano|%d|%d|0", GEN[1], GEN[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlavagen|0|%d|%d|0", GEN[1], GEN[2]))
	Spring.SendLuaRulesMsg(string.format("led|place|armlab|0|%d|%d|0", LAB[1], LAB[2]))
end
steps[34] = function()
	for _, p in pairs(SPOTS) do
		Spring.SendLuaRulesMsg(string.format("led|place|armlavacarrier|0|%d|%d|0", p[1], p[2]))
	end
end
steps[1200] = function()
	log("after 40 seconds: H (Hold Position) hauling", hauling(units.H), "loads", loads.H, ok(not hauling(units.H) and loads.H == 0))
	log("after 40 seconds: M (Maneuver) hauling", hauling(units.M), "loads", loads.M, ok(hauling(units.M) and loads.M >= 1))
	Spring.GiveOrderToUnit(units.M, CMD.MOVE, { CX - 500, 0, CZ - 400 }, 0)
end
steps[1215] = function()
	log("M after a Move order: hauling", hauling(units.M), ok(not hauling(units.M)))
end
steps[1900] = function()
	log("M after the Move: hauling again", hauling(units.M), ok(hauling(units.M)))
	Spring.GiveOrderToUnit(units.M, CMD.STOP, {}, 0)
end
steps[2200] = function()
	log("M 10 seconds after Stop: hauling", hauling(units.M), ok(not hauling(units.M)))
	Spring.GiveOrderToUnit(units.H, 39761, { units.gen }, 0)
end
steps[2230] = function()
	log("H after the order Haul (still on Hold Position): hauling", hauling(units.H), ok(hauling(units.H)))
	log("done"); Spring.SendCommands("quitforce")
end
function widget:UnitCreated(u, defID)
	local name = UnitDefs[defID].name
	local x, _, z = Spring.GetUnitPosition(u)
	if name == "armlavagen" then units.gen = u end
	if name ~= "armlavacarrier" then return end
	for k, p in pairs(SPOTS) do
		if math.abs(x - p[1]) < 20 and math.abs(z - p[2]) < 20 then
			units[k] = u
			Spring.GiveOrderToUnit(u, CMD.MOVE_STATE, { k == "H" and 0 or 1 }, 0)
			log("carrier", k, u, k == "H" and "Hold Position" or "Maneuver")
		end
	end
end
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if f % 15 == 5 then
		for k in pairs(loads) do
			local u = units[k]
			if u and Spring.ValidUnitID(u) then
				local load = Spring.GetUnitRulesParam(u, "lavaLoad") or 0
				if load > 0 and last[k] == 0 then
					loads[k] = loads[k] + 1
					log("frame", f, k, "loaded", load)
				end
				last[k] = load
			end
		end
	end
end
