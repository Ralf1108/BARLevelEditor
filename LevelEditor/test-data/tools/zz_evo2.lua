function widget:GetInfo() return { name = "zz evo2", desc = "test only: Evolution energy, wild units, towers, radars", layer = 1, enabled = true } end
-- Test widget of lan_test.ps1 -Mode evo -Solo (one instance: the host PlayerA and a computer; best with -EvoStage 5 -QuitFrame 9000).
-- Logs "[zzevo2]" lines: the energy of the own team (storage 1000, +10 per second), the units of Gaia (wild units of the players' stages, towers, radars),
-- sends the own unit to the nearest radar that is not its own (taken after 5 s: "radar taken: OK"), lets it shoot at the radar (it must take no damage) and
-- counts the T2 radars (with the players on stage 5 more than half of them are on stage 5: the radars become T2 one by one). The game is ended by zz_lantest.lua.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzevo2] " .. table.concat(t, " "))
end

local RADARS = { armrad = 1, corrad = 1, legrad = 1, armarad = 2, corarad = 2, legarad = 2 }
local target, targetHp, attacked, takenAt
local energySeen = {}

local function myUnit()
	local id = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoUnit")
	return id and id > 0 and Spring.ValidUnitID(id) and id or nil
end

local function radarList()
	local out = {}
	for _, id in ipairs(Spring.GetAllUnits()) do
		local name = UnitDefs[Spring.GetUnitDefID(id)].name
		if RADARS[name] then out[#out + 1] = { id = id, name = name, t2 = RADARS[name] == 2, team = Spring.GetUnitTeam(id) } end
	end
	return out
end

function widget:GameFrame(f)
	local me = Spring.GetMyTeamID()
	if f == 60 then
		Spring.SendCommands("cheat 1")
		Spring.SendCommands("globallos") -- the test sees the radars and the wild units everywhere
	end
	if f % 300 == 0 and f > 0 then
		local e, es = Spring.GetTeamResources(me, "energy")
		energySeen[#energySeen + 1] = e
		local gaia = Spring.GetGaiaTeamID()
		local mobile, towers = {}, 0
		for _, id in ipairs(Spring.GetTeamUnits(gaia) or {}) do
			local ud = UnitDefs[Spring.GetUnitDefID(id)]
			if not RADARS[ud.name] then
				if ud.isBuilding then towers = towers + 1 else mobile[ud.name] = (mobile[ud.name] or 0) + 1 end
			end
		end
		local names = {}
		for k, v in pairs(mobile) do names[#names + 1] = k .. "x" .. v end
		table.sort(names)
		local rs, t2, mine = radarList(), 0, 0
		for _, r in ipairs(rs) do
			if r.t2 then t2 = t2 + 1 end
			if r.team == me then mine = mine + 1 end
		end
		log("frame", f, "energy", math.floor(e or -1), "storage", math.floor(es or -1), "| wild towers", towers, "units", table.concat(names, " "),
			"| radars", #rs, "T2", t2, "mine", mine, "| taking", tostring(Spring.GetGameRulesParam("evoTaking")))
	end
	-- the radar: go there, shoot at it, wait until it is taken
	local u = myUnit()
	if f >= 300 and u and not takenAt and f % 60 == 0 then
		local ux, _, uz = Spring.GetUnitPosition(u)
		if not target or not Spring.ValidUnitID(target) then
			local best, bd
			for _, r in ipairs(radarList()) do
				if r.team ~= me then
					local x, _, z = Spring.GetUnitPosition(r.id)
					local d = (x - ux) ^ 2 + (z - uz) ^ 2
					if not bd or d < bd then best, bd = r.id, d end
				end
			end
			target = best
			if target then
				targetHp = select(1, Spring.GetUnitHealth(target))
				log("frame", f, "going to radar", target, UnitDefs[Spring.GetUnitDefID(target)].name, "distance", math.floor(math.sqrt(bd)), "health", targetHp)
			end
		end
		if target then
			local x, _, z = Spring.GetUnitPosition(target)
			local d = math.sqrt((x - ux) ^ 2 + (z - uz) ^ 2)
			if d > 120 then
				Spring.GiveOrderToUnit(u, CMD.MOVE, { x + 60, Spring.GetGroundHeight(x + 60, z), z }, 0)
			elseif not attacked then
				attacked = f
				Spring.GiveOrderToUnit(u, CMD.ATTACK, { target }, 0)
				log("frame", f, "next to the radar: shooting at it")
			end
			if Spring.GetUnitTeam(target) == me then
				takenAt = f
				local hp = select(1, Spring.GetUnitHealth(target))
				Spring.GiveOrderToUnit(u, CMD.STOP, {}, 0)
				log("frame", f, "radar taken:", "OK", "| health before", targetHp, "now", hp, hp and targetHp and hp >= targetHp and "not damaged: OK" or "damaged: FAIL")
			end
		end
	end
	if f == 8700 then
		local rising = #energySeen >= 2 and energySeen[#energySeen] > 0
		local rs, t2 = radarList(), 0
		for _, r in ipairs(rs) do if r.t2 then t2 = t2 + 1 end end
		log("RESULT energy of the team:", rising and "OK" or "FAIL", "| radars", #rs, #rs > 0 and "OK" or "FAIL", "| T2 radars", t2, t2 > 0 and "OK" or "FAIL",
			"| radar taken", takenAt and "OK" or "FAIL")
	end
end
