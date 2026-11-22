-- Volcano and Lava Extractor (proof of concept). A Lava Extractor (unit with customparams.lavagenerator, lava_generator_defs.lua) that stands on a
-- Volcano (feature with customparams.lavavolcano, lava_volcano_def.lua) makes LAVA_ENERGY energy per second at once and puts LAVA_METAL metal per
-- second into its own stock (at most STOCK_MAX); anywhere else nothing (the Level Editor places units anywhere). A normal geothermal plant on a
-- Volcano makes its own energy (the engine).
-- The metal reaches the team only by Carriers (customparams.lavacarrier). A Carrier has the order Haul (CMD_HAUL, a button, and the command of a
-- right click on a Lava Extractor or a factory of its team, DefaultCommand): Haul on a Lava Extractor makes it haul: to the generator, take LOAD metal
-- when the stock has it, to the factory, deliver (the team gets the metal), back again, until it gets another order. Haul on a factory chooses where
-- it delivers (before or while hauling); otherwise it is the nearest factory of its team.
-- A Carrier loads in the yard of the extractor (its cells are free; the place of the middle block of the model). On a Volcano it comes and goes
-- through the pass of the crater the yard faces, and around the Volcano outside its lava (never over the wall or a stream): ROUTE.
-- The unit scripts show it: a Lava Extractor (lava_generator_script.lua) turns its wheel, moves its pistons and lets lava drops fall while it works on
-- a Volcano (SetActive) and shows its stock as up to BLOCKS metal blocks in its yard (SetBlocks); a Forklift shows its boxes (SetBoxes).
-- The unsynced part draws the lava of every Volcano (a lake in its crater and three streams, moving, with BAR's lava texture) and the numbers: the
-- stock over a generator, the load over a Carrier.
function gadget:GetInfo()
	return {
		name = "Lava Extractor",
		desc = "Lava Extractors on a Volcano make energy and metal; Carriers bring the metal to a factory",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local LAVA_ENERGY = 200 -- energy per second of a Lava Extractor on a Volcano (a geothermal plant of tech 1 makes 300)
local LAVA_METAL = 2 -- metal per second into the stock of a Lava Extractor on a Volcano (a metal extractor of tech 1 on a spot of 2.0 makes about 2)
local STOCK_MAX = 200 -- metal a Lava Extractor keeps at most (more is lost)
local LOAD = 20 -- metal a Carrier takes in one trip (a unit with customparams.lavaload takes that much: the Cargo Truck 60)
-- A unit with customparams.lavabox (the Forklift) loads boxes of that much metal, one every half second while the stock has one, and leaves when
-- it is full (lavaload) or the stock has no box more; it unloads them one by one; its unit script shows the boxes (SetBoxes).
local ON_RADIUS = 44 -- the middle of the generator at most so far from the middle of a Volcano (Elmo; the engine lets it stand there: footprint 6, 6 * 8 - 4)
local BLOCKS = 15 -- metal blocks in the yard of a Lava Extractor (its model): a full stock shows all
local REACH = 70 -- a Carrier is at a building when it is this far from its edge (Elmo)
local CMD_HAUL = 39761 -- the order Haul of the Carriers (its own id)
local ROUTE = {
	YARD_PIECE = "block8", -- a block in the middle of the yard: where a Carrier loads (its place in the world also when the extractor is turned)
	AT_YARD = 30, -- a Carrier at most so far from that place loads
	DETOUR = 185, -- the way around a Volcano (its streams end at 160) and the gate outside a pass
	CLEAR = 168, -- a straight way that comes nearer to the middle of a Volcano goes around it
	GRID = math.pi / 6, -- the fixed points of the way around a Volcano: every 30 degrees (the middle of a step stays 179 from the middle)
	PAST = 0.17, -- a point at most so far (radians, 10 degrees) ahead of a Carrier counts as passed: the next one is taken
	ROAD = 16, -- half width of the road through a pass (a Carrier on it drives straight)
	ENTRY = 46, -- the entrance of the yard: so far from the middle of the extractor, on the middle line of the pass
	PASS_ANGLE = 0.24, -- a Carrier at most so far (radians, about 14 degrees) from the direction of the pass, seen from the middle, is in the pass
	OUT_ANGLE = 0.52, -- a loaded Carrier nearer than CLEAR and at most so far (about 30 degrees) from that direction first goes out to the gate
}

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
		tooltip = "Haul: click a Lava Extractor: the Carrier brings its metal to a factory, again and again.\nClick a factory: it delivers there.",
	}

	-- the Volcano the unit stands on ({ x, y, z }), or nil
	local function onVolcano(u)
		local x, _, z = Spring.GetUnitPosition(u)
		if not x then
			return nil
		end
		for _, p in pairs(volcanoes) do
			if (p[1] - x) ^ 2 + (p[3] - z) ^ 2 <= ON_RADIUS * ON_RADIUS then
				return p
			end
		end
		return nil
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
		g.vol = onVolcano(u)
		local on = (built or 0) >= 1 and g.vol ~= nil
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

	local function orders(c)
		return (Spring.GetUnitCommandCount and Spring.GetUnitCommandCount(c) or Spring.GetUnitCommands(c, 0)) or 0
	end

	local function walkTo(c, h, u)
		if h.goal ~= u or orders(c) == 0 then
			h.goal, h.gx = u, nil
			local x, y, z = Spring.GetUnitPosition(u)
			Spring.GiveOrderToUnit(c, CMD.MOVE, { x, y, z }, 0)
		end
	end

	local function walkPoint(c, h, x, z)
		if h.goal or not h.gx or (h.gx - x) ^ 2 + (h.gz - z) ^ 2 > 256 or orders(c) == 0 then
			h.goal, h.gx, h.gz = nil, x, z
			Spring.GiveOrderToUnit(c, CMD.MOVE, { x, Spring.GetGroundHeight(x, z), z }, 0)
		end
	end

	-- where a Carrier loads (the middle of the yard), the middle of the extractor and the direction from it to the yard (to the pass)
	local function yard(u)
		local ux, _, uz = Spring.GetUnitPosition(u)
		local yx, yz = ux, uz
		local map = Spring.GetUnitPieceMap and Spring.GetUnitPieceMap(u)
		local idx = map and map[ROUTE.YARD_PIECE]
		if idx then
			local px, _, pz = Spring.GetUnitPiecePosDir(u, idx)
			if px then
				yx, yz = px, pz
			end
		end
		local dx, dz = yx - ux, yz - uz -- (the direction of the pass: one of the four, the side of the yard)
		if math.abs(dx) >= math.abs(dz) then
			dx, dz = dx >= 0 and 1 or -1, 0
		else
			dx, dz = 0, dz >= 0 and 1 or -1
		end
		return yx, yz, ux, uz, dx, dz
	end

	-- the next point on the way from (cx, cz) to (tx, tz) past a Volcano at (vx, vz): the target when the straight way does not come near the
	-- Volcano, otherwise the next of fixed points on the circle DETOUR (every 30 degrees) towards the side of the target (fixed: a point that moved
	-- with the Carrier would draw it inwards, in a spiral)
	local function around(cx, cz, vx, vz, tx, tz)
		local sx, sz = tx - cx, tz - cz
		local l2 = sx * sx + sz * sz
		local t = l2 > 0 and math.max(0, math.min(1, ((vx - cx) * sx + (vz - cz) * sz) / l2)) or 0
		local px, pz = cx + sx * t - vx, cz + sz * t - vz
		if px * px + pz * pz >= ROUTE.CLEAR * ROUTE.CLEAR then
			return tx, tz
		end
		local ac = math.atan2(cz - vz, cx - vx)
		local d = (math.atan2(tz - vz, tx - vx) - ac + math.pi) % (2 * math.pi) - math.pi
		local a
		if d > 0 then
			a = math.min(ac + d, math.ceil((ac + ROUTE.PAST) / ROUTE.GRID) * ROUTE.GRID)
		else
			a = math.max(ac + d, math.floor((ac - ROUTE.PAST) / ROUTE.GRID) * ROUTE.GRID)
		end
		return vx + ROUTE.DETOUR * math.cos(a), vz + ROUTE.DETOUR * math.sin(a)
	end

	-- on the road of the pass of an extractor (straight out from its middle towards its yard, or at most maxAngle away from that direction)?
	local function onRoad(cx, cz, ux, uz, dx, dz, maxAngle)
		local rx, rz = cx - ux, cz - uz
		local along, side = rx * dx + rz * dz, math.abs(rx * dz - rz * dx)
		return along > -10 and (side < ROUTE.ROAD or math.atan2(side, along) < maxAngle)
	end

	-- an empty Carrier: to the yard of its extractor (true when it is there)
	local function toYard(c, h, g)
		local yx, yz, ux, uz, dx, dz = yard(h.src)
		local cx, _, cz = Spring.GetUnitPosition(c)
		if (cx - yx) ^ 2 + (cz - yz) ^ 2 <= ROUTE.AT_YARD * ROUTE.AT_YARD then
			return true
		end
		local tx, tz = yx, yz
		if g.vol and not onRoad(cx, cz, ux, uz, dx, dz, ROUTE.PASS_ANGLE) then -- (first to the gate outside the pass, around the Volcano)
			tx, tz = around(cx, cz, g.vol[1], g.vol[3], ux + dx * ROUTE.DETOUR, uz + dz * ROUTE.DETOUR)
		elseif g.vol and (cx - ux) * dx + (cz - uz) * dz > ROUTE.ENTRY + 8 then -- (in the pass: along its middle to the entrance of the yard)
			tx, tz = ux + dx * ROUTE.ENTRY, uz + dz * ROUTE.ENTRY
		end
		walkPoint(c, h, tx, tz)
		return false
	end

	-- a loaded Carrier: to the factory dst; from the yard out through the pass first, then around the Volcano if it is in the way
	local function toFactory(c, h, dst)
		local g = h.src and gens[h.src]
		local v = g and g.vol
		if v then
			local cx, _, cz = Spring.GetUnitPosition(c)
			local _, _, ux, uz, dx, dz = yard(h.src)
			if (cx - v[1]) ^ 2 + (cz - v[3]) ^ 2 < ROUTE.CLEAR * ROUTE.CLEAR and onRoad(cx, cz, ux, uz, dx, dz, ROUTE.OUT_ANGLE) then
				walkPoint(c, h, ux + dx * ROUTE.DETOUR, uz + dz * ROUTE.DETOUR)
				return
			end
			local fx, _, fz = Spring.GetUnitPosition(dst)
			local tx, tz = around(cx, cz, v[1], v[3], fx, fz)
			if tx ~= fx or tz ~= fz then
				walkPoint(c, h, tx, tz)
				return
			end
		end
		walkTo(c, h, dst)
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
				toFactory(c, h, dst)
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
		local at = toYard(c, h, g)
		if at and h.box then
			if g.stock >= h.box and h.load + h.box <= h.cap then
				g.stock = g.stock - h.box
				Spring.SetUnitRulesParam(h.src, "lavaStock", g.stock, { public = true })
				showGen(h.src, g)
				setLoad(c, h, h.load + h.box)
			elseif h.load > 0 then
				h.go, h.goal, h.gx = true, nil, nil -- (full, or the stock has no box more)
			end
		elseif at then
			if g.stock >= h.cap then
				g.stock = g.stock - h.cap
				Spring.SetUnitRulesParam(h.src, "lavaStock", g.stock, { public = true })
				showGen(h.src, g)
				setLoad(c, h, h.cap)
				h.goal, h.gx = nil, nil
			end
		end
	end

	function gadget:Initialize()
		if not next(genDef) then
			gadgetHandler:RemoveGadget(self) -- (a game without the Lava Extractor)
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

	-- A Carrier: Haul on a Lava Extractor of its team starts the hauling, on a factory of its team chooses where it delivers (the order itself is
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

	-- the right click of selected Carriers on a Lava Extractor or a factory of the own team is the order Haul
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

	-- the lava of a Volcano (its model is only the rock, make_lava_volcano.py): a lake inside the crater and a stream out of each breach, in three
	-- layers: a dark red ground (the dark parts of BAR's lava texture are see-through), BAR's lava texture, the same texture once more moving the other
	-- way and adding light; the streams flow outwards; all of it pulses slowly.
	-- The numbers of the crater must match the model (RIM_*, BREACHES, BREACH_H in make_lava_volcano.py).
	local LAVA = { TEX = "luaui/images/lava/lava7_diffuseemit.dds", RIM_IN = 62, RIM_TOP = 72, RIM_OUT = 98, BREACHES = { 45, 225 }, BREACH_H = 2.5,
		LAKE = 40, STREAM_END = 160, rivers = {} }
	local timer0 = Spring.GetTimer()

	-- the height of the crest of the model in the middle of a breach at the distance r from the middle (0 at both feet)
	local function breachHeight(r)
		if r <= LAVA.RIM_IN or r >= LAVA.RIM_OUT then
			return 0
		elseif r <= LAVA.RIM_TOP then
			return LAVA.BREACH_H * (r - LAVA.RIM_IN) / (LAVA.RIM_TOP - LAVA.RIM_IN)
		end
		return LAVA.BREACH_H * (LAVA.RIM_OUT - r) / (LAVA.RIM_OUT - LAVA.RIM_TOP)
	end

	-- the streams of one Volcano: per breach a list of rows { left point, right point, distance, alpha }, on the rock or the ground (made once)
	local function streams(p)
		local list = {}
		for j, deg in ipairs(LAVA.BREACHES) do
			local a = math.rad(deg)
			local dx, dz = math.cos(a), math.sin(a)
			local rows = {}
			for r = LAVA.LAKE - 6, LAVA.STREAM_END, 6 do -- (from the lake over the floor of the crater, through the breach, onto the ground)
				local bend = math.max(0, math.min(1, (r - LAVA.RIM_OUT) / 30)) * 7 * math.sin(r / 17 + j * 2) -- (it winds only outside the crater)
				local w = 9 - 4 * (r - LAVA.LAKE) / (LAVA.STREAM_END - LAVA.LAKE)
				local cx, cz = p[1] + dx * r - dz * bend, p[3] + dz * r + dx * bend
				local h = p[2] + breachHeight(r) * 1.3 + 1.0 -- (the floor of the crater is 0.6 high)
				local row = { r = r, a = math.min(1, (LAVA.STREAM_END - r) / 45) }
				for s, side in ipairs({ -1, 1 }) do
					local x, z = cx - dz * w * side, cz + dx * w * side
					row[s] = { x, math.max(h, Spring.GetGroundHeight(x, z) + 0.8), z }
				end
				rows[#rows + 1] = row
			end
			list[j] = rows
		end
		return list
	end

	local function lake(p, du, dv, lift)
		local y = p[2] + lift
		gl.TexCoord(p[1] / 160 + du, p[3] / 160 + dv)
		gl.Vertex(p[1], y, p[3])
		for k = 0, 40 do
			local a = 2 * math.pi * k / 40
			local x, z = p[1] + LAVA.LAKE * math.cos(a), p[3] + LAVA.LAKE * math.sin(a)
			gl.TexCoord(x / 160 + du, z / 160 + dv)
			gl.Vertex(x, y, z)
		end
	end

	local function stream(rows, flow, r, g, b, alpha, lift)
		for _, row in ipairs(rows) do
			gl.Color(r, g, b, alpha * row.a)
			gl.TexCoord(0, row.r / 90 - flow)
			gl.Vertex(row[1][1], row[1][2] + lift, row[1][3])
			gl.TexCoord(0.22, row.r / 90 - flow)
			gl.Vertex(row[2][1], row[2][2] + lift, row[2][3])
		end
	end

	function gadget:DrawWorldPreUnit()
		if not next(volcanoes) then
			return
		end
		for fid in pairs(LAVA.rivers) do
			if not volcanoes[fid] then
				LAVA.rivers[fid] = nil -- (the Volcano is gone)
			end
		end
		local t = Spring.DiffTimers(Spring.GetTimer(), timer0) -- (real time: the lava moves also while the game is paused)
		gl.DepthTest(true)
		gl.Culling(false)
		for fid, p in pairs(volcanoes) do
			if Spring.IsSphereInView(p[1], p[2], p[3], LAVA.STREAM_END) then
				LAVA.rivers[fid] = LAVA.rivers[fid] or streams(p)
				local pulse = 0.82 + 0.18 * math.sin(t * 1.6 + p[1] * 0.01)
				gl.Texture(0, false)
				gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
				gl.Color(0.32 * pulse, 0.07, 0.02, 1)
				gl.BeginEnd(GL.TRIANGLE_FAN, lake, p, 0, 0, 1.1)
				for _, rows in ipairs(LAVA.rivers[fid]) do
					gl.BeginEnd(GL.QUAD_STRIP, stream, rows, 0, 0.32 * pulse, 0.07, 0.02, 1, -0.1)
				end
				gl.Texture(0, LAVA.TEX)
				gl.Color(pulse, pulse, pulse, 1)
				gl.BeginEnd(GL.TRIANGLE_FAN, lake, p, t * 0.010, t * 0.006, 1.2)
				for _, rows in ipairs(LAVA.rivers[fid]) do
					gl.BeginEnd(GL.QUAD_STRIP, stream, rows, t * 0.10, pulse, pulse, pulse, 1, 0)
				end
				gl.Blending(GL.SRC_ALPHA, GL.ONE) -- (the second layer adds light: the glowing veins move over each other)
				gl.Color(0.55 * pulse, 0.25 * pulse, 0.06, 1)
				gl.BeginEnd(GL.TRIANGLE_FAN, lake, p, -t * 0.008, t * 0.012, 1.3)
				for _, rows in ipairs(LAVA.rivers[fid]) do
					gl.BeginEnd(GL.QUAD_STRIP, stream, rows, t * 0.16 + 0.5, 0.55, 0.25, 0.06, pulse, 0.1)
				end
			end
		end
		gl.Texture(0, false)
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		gl.Color(1, 1, 1, 1)
		gl.Culling(GL.BACK)
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
