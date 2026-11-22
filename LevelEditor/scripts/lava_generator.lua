-- Volcano and Lava Generator (proof of concept). A Lava Generator (unit with customparams.lavagenerator, lava_generator_defs.lua) that stands on a
-- Volcano (feature with customparams.lavavolcano, lava_volcano_def.lua) makes LAVA_ENERGY energy per second at once and puts LAVA_METAL metal per
-- second into its own stock (at most STOCK_MAX); anywhere else nothing (the Level Editor places units anywhere). A normal geothermal plant on a
-- Volcano makes its own energy (the engine).
-- The metal reaches the team only by Carriers (customparams.lavacarrier). A Carrier has the order Haul (CMD_HAUL, a button, and the command of a
-- right click on a Lava Generator or a factory of its team, DefaultCommand): Haul on a Lava Generator makes it haul: to the generator, take LOAD metal
-- when the stock has it, to the factory, deliver (the team gets the metal), back again, until it gets another order. Haul on a factory chooses where
-- it delivers (before or while hauling); otherwise it is the nearest factory of its team.
-- The unit scripts show it: a Lava Generator (lava_generator_script.lua) turns its wheel, moves its pistons and lets lava drops fall while it works on
-- a Volcano (SetActive) and shows its stock as up to BLOCKS metal blocks in its yard (SetBlocks); a Forklift shows its boxes (SetBoxes).
-- The unsynced part draws the glow of the lava around every Volcano and the numbers: the stock over a generator, the load over a Carrier.
function gadget:GetInfo()
	return {
		name = "Lava Generator",
		desc = "Lava Generators on a Volcano make energy and metal; Carriers bring the metal to a factory",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local LAVA_ENERGY = 200 -- energy per second of a Lava Generator on a Volcano (a geothermal plant of tech 1 makes 300)
local LAVA_METAL = 2 -- metal per second into the stock of a Lava Generator on a Volcano (a metal extractor of tech 1 on a spot of 2.0 makes about 2)
local STOCK_MAX = 200 -- metal a Lava Generator keeps at most (more is lost)
local LOAD = 20 -- metal a Carrier takes in one trip (a unit with customparams.lavaload takes that much: the Cargo Truck 60)
-- A unit with customparams.lavabox (the Forklift) loads boxes of that much metal, one every half second while the stock has one, and leaves when
-- it is full (lavaload) or the stock has no box more; it unloads them one by one; its unit script shows the boxes (SetBoxes).
local ON_RADIUS = 44 -- the middle of the generator at most so far from the middle of a Volcano (Elmo; the engine lets it stand there: footprint 6, 6 * 8 - 4)
local BLOCKS = 15 -- metal blocks in the yard of a Lava Generator (its model): a full stock shows all
local REACH = 70 -- a Carrier is at a building when it is this far from its edge (Elmo)
local CMD_HAUL = 39761 -- the order Haul of the Carriers (its own id)

local volcanoDef, genDef, carrierDef = {}, {}, {} -- defID -> true (carrierDef: -> { cap = load per trip, box = metal per box or nil })
for id, fd in pairs(FeatureDefs) do
	if fd.customParams and fd.customParams.lavavolcano then
		volcanoDef[id] = true
	end
end
for id, ud in pairs(UnitDefs) do
	local cp = ud.customParams or {}
	if cp.lavagenerator then
		genDef[id] = true
	elseif cp.lavacarrier then
		carrierDef[id] = { cap = tonumber(cp.lavaload) or LOAD, box = tonumber(cp.lavabox) }
	end
end
local volcanoes = {} -- featureID -> { x, y, z }

local function addFeature(fid, defID)
	if volcanoDef[defID] then
		local x, y, z = Spring.GetFeaturePosition(fid)
		if x then
			volcanoes[fid] = { x, y, z }
		end
	end
end

function gadget:FeatureCreated(fid)
	addFeature(fid, Spring.GetFeatureDefID(fid))
end

function gadget:FeatureDestroyed(fid)
	volcanoes[fid] = nil
end

if gadgetHandler:IsSyncedCode() then
	local gens = {} -- unitID -> { on = true/false/nil, stock = metal }
	local carriers = {} -- unitID -> { src = generator, dst = chosen factory or nil, load = metal, cap = metal per trip, box = metal per box (Forklift),
	-- go = a Forklift on its way to the factory, goal = unit it walks to }
	local HAUL_STOP = { [CMD.MOVE] = true, [CMD.STOP] = true, [CMD.PATROL] = true, [CMD.FIGHT] = true, [CMD.GUARD] = true, [CMD.ATTACK] = true,
		[CMD.RECLAIM] = true, [CMD.REPAIR] = true, [CMD.WAIT] = true }
	local HAUL_DESC = {
		id = CMD_HAUL, type = CMDTYPE.ICON_UNIT, name = "Haul", action = "lavahaul", cursor = "Guard",
		tooltip = "Haul: click a Lava Generator: the Carrier brings its metal to a factory, again and again.\nClick a factory: it delivers there.",
	}

	local function onVolcano(u)
		local x, _, z = Spring.GetUnitPosition(u)
		if not x then
			return false
		end
		for _, p in pairs(volcanoes) do
			if (p[1] - x) ^ 2 + (p[3] - z) ^ 2 <= ON_RADIUS * ON_RADIUS then
				return true
			end
		end
		return false
	end

	-- calls a function of the Lua unit script of u (BAR's unit_script.lua), if it has one
	local function callScript(u, name, ...)
		local env = Spring.UnitScript and Spring.UnitScript.GetScriptEnv and Spring.UnitScript.GetScriptEnv(u)
		if env and env[name] then
			Spring.UnitScript.CallAsUnit(u, env[name], ...)
		end
	end

	-- the looks of a generator: working or not, the blocks of its yard (called only when they change)
	local function showGen(u, g)
		if g.shownOn ~= g.on then
			g.shownOn = g.on
			callScript(u, "SetActive", g.on and true or false)
		end
		local n = math.ceil(g.stock * BLOCKS / STOCK_MAX)
		if g.shownBlocks ~= n then
			g.shownBlocks = n
			callScript(u, "SetBlocks", n)
		end
	end

	local function checkGen(u, g)
		local _, _, _, _, built = Spring.GetUnitHealth(u)
		local on = (built or 0) >= 1 and onVolcano(u)
		if g.on ~= on then
			g.on = on
			Spring.SetUnitResourcing(u, "ume", on and LAVA_ENERGY or 0) -- (unconditional make energy)
			Spring.SetUnitRulesParam(u, "lavaEnergy", on and LAVA_ENERGY or 0, { public = true })
			Spring.SetUnitRulesParam(u, "lavaMetal", on and LAVA_METAL or 0, { public = true })
		end
		if on and g.stock < STOCK_MAX then
			g.stock = math.min(STOCK_MAX, g.stock + LAVA_METAL)
		end
		Spring.SetUnitRulesParam(u, "lavaStock", g.stock, { public = true })
		showGen(u, g)
	end

	local function isFactory(u, team)
		local d = Spring.GetUnitDefID(u)
		return d and UnitDefs[d].isFactory and Spring.GetUnitTeam(u) == team and not Spring.GetUnitIsBeingBuilt(u)
	end

	local function nearestFactory(c, team)
		local x, _, z = Spring.GetUnitPosition(c)
		local best, bd
		for _, u in ipairs(Spring.GetTeamUnits(team)) do
			if isFactory(u, team) then
				local ux, _, uz = Spring.GetUnitPosition(u)
				local d = (ux - x) ^ 2 + (uz - z) ^ 2
				if not bd or d < bd then
					best, bd = u, d
				end
			end
		end
		return best
	end

	local function near(c, u)
		local cx, _, cz = Spring.GetUnitPosition(c)
		local ux, _, uz = Spring.GetUnitPosition(u)
		if not (cx and ux) then
			return false
		end
		local r = (Spring.GetUnitRadius(u) or 30) + REACH
		return (cx - ux) ^ 2 + (cz - uz) ^ 2 <= r * r
	end

	local function walkTo(c, h, u)
		local count = Spring.GetUnitCommandCount and Spring.GetUnitCommandCount(c) or Spring.GetUnitCommands(c, 0)
		if h.goal ~= u or (count or 0) == 0 then
			h.goal = u
			local x, y, z = Spring.GetUnitPosition(u)
			Spring.GiveOrderToUnit(c, CMD.MOVE, { x, y, z }, 0)
		end
	end

	local function setLoad(c, h, load)
		h.load = load
		Spring.SetUnitRulesParam(c, "lavaLoad", load, { public = true })
		if h.box then -- the boxes on the fork (the unit script of the Forklift)
			callScript(c, "SetBoxes", math.ceil(load / h.box))
		end
	end

	-- one step of a hauling Carrier (every half second)
	local function haul(c, h)
		local team = Spring.GetUnitTeam(c)
		if h.load > 0 and (h.go or not h.box) then
			local dst = h.dst and Spring.ValidUnitID(h.dst) and isFactory(h.dst, team) and h.dst or nearestFactory(c, team)
			if not dst then
				return -- (no factory: it waits with its load)
			end
			if near(c, dst) then
				local n = h.box and math.min(h.box, h.load) or h.load -- (a Forklift: one box per step)
				Spring.AddTeamResource(team, "metal", n)
				Spring.SetTeamRulesParam(team, "lavaDelivered", (Spring.GetTeamRulesParam(team, "lavaDelivered") or 0) + n, { public = true })
				setLoad(c, h, h.load - n)
				if h.load == 0 then
					h.goal, h.go = nil, nil
				end
			else
				walkTo(c, h, dst)
			end
			return
		end
		local g = h.src and gens[h.src]
		if not g then
			if h.load > 0 then
				h.go = true -- (a Forklift with boxes: it brings them first)
				return
			end
			h.src = nil -- (the generator is gone: it stops)
			Spring.SetUnitRulesParam(c, "lavaHauling", 0, { public = true })
			return
		end
		if near(c, h.src) and h.box then
			if g.stock >= h.box and h.load + h.box <= h.cap then
				g.stock = g.stock - h.box
				Spring.SetUnitRulesParam(h.src, "lavaStock", g.stock, { public = true })
				showGen(h.src, g)
				setLoad(c, h, h.load + h.box)
			elseif h.load > 0 then
				h.go, h.goal = true, nil -- (full, or the stock has no box more)
			end
		elseif near(c, h.src) then
			if g.stock >= h.cap then
				g.stock = g.stock - h.cap
				Spring.SetUnitRulesParam(h.src, "lavaStock", g.stock, { public = true })
				showGen(h.src, g)
				setLoad(c, h, h.cap)
				h.goal = nil
			end
		else
			walkTo(c, h, h.src)
		end
	end

	function gadget:Initialize()
		if not next(genDef) then
			gadgetHandler:RemoveGadget(self) -- (a game without the Lava Generator)
			return
		end
		if gadgetHandler.RegisterAllowCommand then
			-- only these orders reach AllowCommand (BAR's gadget handler gives an order only to the gadgets registered for its id)
			gadgetHandler:RegisterAllowCommand(CMD_HAUL)
			for id in pairs(HAUL_STOP) do
				gadgetHandler:RegisterAllowCommand(id)
			end
		end
		for _, fid in ipairs(Spring.GetAllFeatures()) do
			addFeature(fid, Spring.GetFeatureDefID(fid))
		end
		for _, u in ipairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(u, Spring.GetUnitDefID(u))
		end
	end

	function gadget:UnitCreated(u, defID)
		if genDef[defID] then
			gens[u] = { stock = 0 }
		elseif carrierDef[defID] then
			carriers[u] = { load = 0, cap = carrierDef[defID].cap, box = carrierDef[defID].box }
			Spring.InsertUnitCmdDesc(u, HAUL_DESC)
		end
	end

	function gadget:UnitDestroyed(u)
		gens[u], carriers[u] = nil, nil
	end

	function gadget:UnitGiven(u)
		local h = carriers[u]
		if h then
			h.src, h.dst, h.goal = nil, nil, nil -- (another team: the orders of the old one end)
		end
	end

	-- A Carrier: Haul on a Lava Generator of its team starts the hauling, on a factory of its team chooses where it delivers (the order itself is
	-- used up here, it never stands in the queue); every other order of a player ends the hauling (the load stays).
	function gadget:AllowCommand(u, defID, team, cmdID, params, opts, tag, playerID, fromSynced)
		local h = carriers[u]
		if cmdID == CMD_HAUL then
			local t = h and params[1]
			if t and gens[t] and Spring.GetUnitTeam(t) == team then
				h.src, h.goal = t, nil
				Spring.SetUnitRulesParam(u, "lavaHauling", 1, { public = true })
			elseif t and isFactory(t, team) then
				h.dst, h.goal = t, nil
				Spring.SetUnitRulesParam(u, "lavaDst", t, { public = true })
			end
			return false
		end
		if not h or fromSynced then
			return true
		end
		if HAUL_STOP[cmdID] and h.src then
			h.src, h.goal = nil, nil
			Spring.SetUnitRulesParam(u, "lavaHauling", 0, { public = true })
		end
		return true
	end

	function gadget:GameFrame(f)
		if f % 30 == 7 then
			for u, g in pairs(gens) do
				checkGen(u, g)
			end
		end
		if f % 15 == 3 then
			for c, h in pairs(carriers) do
				if h.src or (h.load > 0 and h.dst) then
					haul(c, h)
				end
			end
		end
	end
else
	local gens, carriers = {}, {} -- unitID -> true

	function gadget:Initialize()
		if not next(volcanoDef) then
			gadgetHandler:RemoveGadget(self)
			return
		end
		for _, fid in ipairs(Spring.GetAllFeatures()) do
			addFeature(fid, Spring.GetFeatureDefID(fid))
		end
		for _, u in ipairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(u, Spring.GetUnitDefID(u))
		end
	end

	function gadget:UnitCreated(u, defID)
		if genDef[defID] then
			gens[u] = true
		elseif carrierDef[defID] then
			carriers[u] = true
		end
	end

	function gadget:UnitDestroyed(u)
		gens[u], carriers[u] = nil, nil
	end

	-- the right click of selected Carriers on a Lava Generator or a factory of the own team is the order Haul
	function gadget:DefaultCommand(kind, id)
		if kind ~= "unit" or Spring.GetUnitTeam(id) ~= Spring.GetMyTeamID() then
			return
		end
		local d = Spring.GetUnitDefID(id)
		if not d or not (genDef[d] or UnitDefs[d].isFactory) then
			return
		end
		for _, u in ipairs(Spring.GetSelectedUnits()) do
			if carriers[u] then
				return CMD_HAUL
			end
		end
	end

	-- the glow of the lava: rings in red and orange around every Volcano in sight, slowly pulsing
	function gadget:DrawWorldPreUnit()
		if not next(volcanoes) then
			return
		end
		local t = Spring.GetGameSeconds() + Spring.GetFrameTimeOffset() / 30
		gl.DepthTest(false)
		for _, p in pairs(volcanoes) do
			if Spring.IsSphereInView(p[1], p[2], p[3], 120) then
				for i = 1, 6 do
					local a = (0.25 + 0.2 * math.sin(t * 2 + i)) * (1 - i / 8)
					gl.LineWidth(9 - i)
					gl.Color(1, 0.15 + i * 0.1, 0, a)
					gl.DrawGroundCircle(p[1], p[2], p[3], 14 + i * 11, 32)
				end
			end
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
		gl.DepthTest(true)
	end

	-- the numbers over the units: "Metal 34 / 200" over a generator, the load over a loaded Carrier
	local function label(u, text, above, size)
		if not Spring.IsUnitVisible(u) then
			return
		end
		local x, y, z = Spring.GetUnitPosition(u)
		if not x then
			return
		end
		local sx, sy, sz = Spring.WorldToScreenCoords(x, y + above, z)
		if sz and sz < 1 then
			gl.Text(text, sx, sy, size, "co")
		end
	end

	function gadget:DrawScreen()
		if not (next(gens) or next(carriers)) then
			return
		end
		for u in pairs(gens) do
			if (Spring.GetUnitRulesParam(u, "lavaMetal") or 0) > 0 then
				label(u, string.format("\255\180\220\255Metal %d / %d", Spring.GetUnitRulesParam(u, "lavaStock") or 0, STOCK_MAX), 70, 15)
			end
		end
		for u in pairs(carriers) do
			local load = Spring.GetUnitRulesParam(u, "lavaLoad") or 0
			if load > 0 then
				label(u, "\255\180\220\255" .. load, 45, 14)
			end
		end
	end
end
