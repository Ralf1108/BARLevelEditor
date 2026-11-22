-- Volcano and Lava Extractor (proof of concept). A Lava Extractor (unit with customparams.lavagenerator, lava_generator_defs.lua) that stands on a
-- Volcano (feature with customparams.lavavolcano, lava_volcano_def.lua) makes LAVA_ENERGY energy per second at once and puts LAVA_METAL metal per
-- second into its own stock (at most STOCK_MAX); anywhere else nothing (the Level Editor places units anywhere). A normal geothermal plant on a
-- Volcano makes its own energy (the engine).
-- The metal reaches the team only by Carriers (customparams.lavacarrier). A Carrier has the order Haul (CMD_HAUL, a button, and the command of a
-- right click on a Lava Extractor or a factory of its team, DefaultCommand): Haul on a Lava Extractor makes it haul: to the generator, take LOAD metal
-- when the stock has it, to the factory, deliver (the team gets the metal), back again, until it gets another order. Haul on a factory chooses where
-- it delivers (before or while hauling); otherwise it is the nearest factory of its team.
-- A Carrier loads at a storage pad of the extractor: four, at the ends of its conveyor belts (east, south, west, north, outside the crater of a
-- Volcano); it takes the nearest free loading spot (three outside each pad) and stops there; it never drives into the crater, and around the
-- Volcano outside its lava: ROUTE. The vehicles at their spots are served in the order they came (none takes the metal another waits for).
-- A Cargo Truck (customparams.lavadock) takes only the middle spot of a pad: there the gadget turns it, backs it up to the pad and loads it crate by
-- crate (DOCK, Spring.MoveCtrl); it also unloads crate by crate (lavacrate).
-- On its own (AUTO): a vehicle on Maneuver or Roam that stands idle hauls again from its last Lava Extractor (after a Move or another order), or
-- from the nearest one of its team on a Volcano (a new one from the factory); on Hold Position or after Stop it waits for the order Haul.
-- The unit scripts show it: a Lava Extractor (lava_generator_script.lua) turns its wheel, moves its pistons and lets lava drops fall while it works on
-- a Volcano (SetActive; then crates ride out on its belts) and shows its stock as up to BLOCKS metal blocks on each pad (SetBlocks); a Forklift shows
-- its boxes (SetBoxes).
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
local ON_RADIUS = 44 -- the middle of the generator at most so far from the middle of a Volcano (Elmo; the engine: footprint 4, at most 4 * 8 - 4 = 28)
local BLOCKS = 6 -- metal blocks on each storage pad of a Lava Extractor (its model): a full stock shows all
local REACH = 70 -- a Carrier is at a building when it is this far from its edge (Elmo)
local CMD_HAUL = 39761 -- the order Haul of the Carriers (its own id)
local AUTO_RANGE = 1200 -- an idle vehicle on Maneuver or Roam without a last Lava Extractor takes the nearest one of its team so far away
-- the Cargo Truck at a storage pad (frames of the game; r: out from the middle of the extractor on the line of the pad)
local DOCK = {
	TURN = 30, -- it turns its back to the pad and pulls out to r = OUT
	OUT = 184,
	BACK = 30, -- it backs up to r = AT (its back at the edge of the pad, 134)
	AT = 160,
	GATE = 12, -- the tailgate opens (and closes at the end)
	CRATE = 15, -- one crate every so many frames
}
local ROUTE = {
	DIRS = { { 1, 0 }, { 0, 1 }, { -1, 0 }, { 0, -1 } }, -- the storage pads of a Lava Extractor (its model): east, south, west, north (alike: turning does not matter)
	STAND = 158, -- the loading spots: so far from the middle of the extractor on the line of a pad (the pads reach 106 to 134; just outside)
	LANE = 26, -- three loading spots side by side at each pad, so far apart (12 in all: a vehicle takes the nearest free one)
	BUSY = 220, -- a spot at a pad where others wait counts so much farther away for each of them (the vehicles spread over the pads)
	AT_SPOT = 28, -- a vehicle at most so far from its spot is there (the engine stops a little short when the others stand close)
	DETOUR = 185, -- the way around a Volcano (its streams end at 160)
	CLEAR = 152, -- a straight way that comes nearer to the middle of an extractor (the crater, the belts, the pads, the streams) goes around it
	GRID = math.pi / 6, -- the fixed points of the way around: every 30 degrees (the middle of a step stays 179 from the middle)
	PAST = 0.17, -- a point at most so far (radians, 10 degrees) ahead of a Carrier counts as passed: the next one is taken
	DIRECT = 0.26, -- a target at most so far (radians, 15 degrees) from the direction of the vehicle (seen from the middle): straight there (a point of
	-- the circle could lie behind a vehicle waiting at a pad: the engine drops a Move order it finds no way to)
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
		carrierDef[id] = { cap = tonumber(cp.lavaload) or LOAD, box = tonumber(cp.lavabox), crate = tonumber(cp.lavacrate), dock = cp.lavadock ~= nil }
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
	-- go = a Forklift on its way to the factory, goal = unit it walks to, last = the extractor it hauled from (AUTO), stopped = the player said Stop,
	-- crate = metal per crate and canDock (Cargo Truck), dock = its state at a pad while it backs up and loads }
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

	-- the looks of a generator: working or not, the blocks on its storage pads (called only when they change)
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

	-- an order of the gadget itself (AllowCommand lets it through; in the editor the orders of players come synced too, fromSynced cannot tell)
	local own = false
	local function order(c, cmd, params)
		own = true
		Spring.GiveOrderToUnit(c, cmd, params, 0)
		own = false
	end

	local function walkTo(c, h, u)
		if h.goal ~= u or orders(c) == 0 then
			h.goal, h.gx = u, nil
			local x, y, z = Spring.GetUnitPosition(u)
			order(c, CMD.MOVE, { x, y, z })
		end
	end

	local function walkPoint(c, h, x, z)
		if h.goal or not h.gx or (h.gx - x) ^ 2 + (h.gz - z) ^ 2 > 256 or orders(c) == 0 then
			h.goal, h.gx, h.gz = nil, x, z
			order(c, CMD.MOVE, { x, Spring.GetGroundHeight(x, z), z })
		end
	end

	-- loading spot i (1 to 12: three side by side outside each storage pad) of the extractor u, and the middle of u
	local function spotPos(u, i)
		local ux, _, uz = Spring.GetUnitPosition(u)
		local d = ROUTE.DIRS[math.floor((i - 1) / 3) + 1]
		local s = ((i - 1) % 3 - 1) * ROUTE.LANE
		return ux + d[1] * ROUTE.STAND - d[2] * s, uz + d[2] * ROUTE.STAND + d[1] * s, ux, uz
	end

	-- does the vehicle c still hold spot i of the extractor gen (hauling from it, not loaded and on its way)?
	local function holds(gen, c, i)
		local h = carriers[c]
		return h and h.src == gen and h.spot == i and (h.dock ~= nil or not (h.load > 0 and (h.go or not h.box))) or false
	end

	-- the spot of the vehicle c: its own, otherwise the nearest free one (nil when all 12 are taken)
	local function takeSpot(c, h, g, cx, cz)
		g.spots = g.spots or {}
		if h.spot and g.spots[h.spot] == c then
			return h.spot
		end
		local busy = {} -- pad -> vehicles holding a spot there
		for i = 1, 3 * #ROUTE.DIRS do
			local occ = g.spots[i]
			if occ and occ ~= c and holds(h.src, occ, i) then
				local pad = math.floor((i - 1) / 3)
				busy[pad] = (busy[pad] or 0) + 1
			end
		end
		local best, bi
		for i = 1, 3 * #ROUTE.DIRS do
			local occ = g.spots[i]
			if not (occ and occ ~= c and holds(h.src, occ, i)) and not (h.canDock and (i - 1) % 3 ~= 1) then
				local x, z = spotPos(h.src, i)
				local dd = math.sqrt((x - cx) ^ 2 + (z - cz) ^ 2) + ROUTE.BUSY * (busy[math.floor((i - 1) / 3)] or 0)
				if not best or dd < best then
					best, bi = dd, i
				end
			end
		end
		if bi then
			g.spots[bi], h.spot, h.waitSince = c, bi, nil
		end
		return bi
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
		if math.abs(d) < ROUTE.DIRECT then
			return tx, tz -- (the target lies in its own direction from the middle: straight there, not over a point of the circle)
		end
		local a
		if d > 0 then
			a = math.min(ac + d, math.ceil((ac + ROUTE.PAST) / ROUTE.GRID) * ROUTE.GRID)
		else
			a = math.max(ac + d, math.floor((ac - ROUTE.PAST) / ROUTE.GRID) * ROUTE.GRID)
		end
		return vx + ROUTE.DETOUR * math.cos(a), vz + ROUTE.DETOUR * math.sin(a)
	end

	-- an empty vehicle: to its loading spot at a storage pad of its extractor, around it if needed; true when it is there and its turn has come
	-- (it waits there longest)
	local function toPad(c, h, g)
		local cx, _, cz = Spring.GetUnitPosition(c)
		local i = takeSpot(c, h, g, cx, cz)
		if not i then
			return false -- (all spots taken: it waits where it is)
		end
		local sx, sz, ux, uz = spotPos(h.src, i)
		if (cx - sx) ^ 2 + (cz - sz) ^ 2 > ROUTE.AT_SPOT * ROUTE.AT_SPOT then
			h.waitSince = nil -- (not there, or pushed away: its turn waits until it is there again; it never blocks the others from afar)
			walkPoint(c, h, around(cx, cz, ux, uz, sx, sz))
			return false
		end
		h.waitSince = h.waitSince or Spring.GetGameFrame()
		for j, occ in pairs(g.spots) do
			if occ ~= c and holds(h.src, occ, j) then
				local o = carriers[occ]
				if o.waitSince and o.waitSince < h.waitSince then
					return false -- (another one came first)
				end
			end
		end
		return true
	end

	-- a loaded Carrier: to the factory dst, around its extractor if that is in the way
	local function toFactory(c, h, dst)
		if h.src and Spring.ValidUnitID(h.src) then
			local cx, _, cz = Spring.GetUnitPosition(c)
			local ux, _, uz = Spring.GetUnitPosition(h.src)
			local fx, _, fz = Spring.GetUnitPosition(dst)
			local tx, tz = around(cx, cz, ux, uz, fx, fz)
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
		elseif h.crate and not h.dock then -- the crates on the bed (the unit script of the Cargo Truck; while it loads: LoadCrate)
			callScript(c, "SetCrates", math.ceil(load / h.crate))
		end
	end

	-- the heading of the unit c (radians; its front is (sin, cos))
	local function heading(c)
		local dx, _, dz = Spring.GetUnitDirection(c)
		return math.atan2(dx, dz)
	end

	-- the Cargo Truck c at its spot: the gadget moves it (MoveCtrl) from now on, DOCK
	local function startDock(c, h)
		local d = ROUTE.DIRS[math.floor((h.spot - 1) / 3) + 1]
		local ux, _, uz = Spring.GetUnitPosition(h.src)
		local cx, _, cz = Spring.GetUnitPosition(c)
		order(c, CMD.STOP, {})
		Spring.MoveCtrl.Enable(c)
		if not DOCK.sign then -- (which way MoveCtrl.SetRotation turns: once, by the direction it gives)
			Spring.MoveCtrl.SetRotation(c, 0, 0, 0)
			local a0 = heading(c)
			Spring.MoveCtrl.SetRotation(c, 0, 0.5, 0)
			local a1 = heading(c)
			DOCK.sign = ((a1 - a0 + math.pi) % (2 * math.pi) - math.pi) > 0 and 1 or -1
			DOCK.zero = a0
		end
		local a = heading(c)
		h.dock = { f = 0, d = d, ux = ux, uz = uz, x0 = cx, z0 = cz, a0 = a, a1 = math.atan2(d[1], d[2]), crates = 0 }
		h.goal, h.gx = nil, nil
		Spring.MoveCtrl.SetRotation(c, 0, DOCK.sign * (a - DOCK.zero), 0)
	end

	local function endDock(c, h)
		if h.dock then
			h.dock = nil
			if Spring.ValidUnitID(c) then
				Spring.MoveCtrl.Disable(c)
				callScript(c, "Gate", false)
				callScript(c, "Wheels", 0)
			end
		end
	end

	-- one frame of a docking Cargo Truck: turn its back to the pad and pull out, back up, open the tailgate, load a crate every DOCK.CRATE frames
	-- from the stock until it is full, close the tailgate, drive off
	local function dockStep(c, h)
		local k, g = h.dock, h.src and gens[h.src]
		if not g then
			endDock(c, h)
			return
		end
		local f = k.f
		local function put(x, z, a)
			Spring.MoveCtrl.SetPosition(c, x, Spring.GetGroundHeight(x, z), z)
			Spring.MoveCtrl.SetRotation(c, 0, DOCK.sign * (a - DOCK.zero), 0)
		end
		local ox, oz = k.ux + k.d[1] * DOCK.OUT, k.uz + k.d[2] * DOCK.OUT
		if f <= DOCK.TURN then
			local s = f / DOCK.TURN
			s = s * s * (3 - 2 * s)
			local da = (k.a1 - k.a0 + math.pi) % (2 * math.pi) - math.pi
			put(k.x0 + (ox - k.x0) * s, k.z0 + (oz - k.z0) * s, k.a0 + da * s)
			if f == 0 then
				callScript(c, "Wheels", 1)
			end
		elseif f <= DOCK.TURN + DOCK.BACK then
			local s = (f - DOCK.TURN) / DOCK.BACK
			s = s * s * (3 - 2 * s)
			local r = DOCK.OUT + (DOCK.AT - DOCK.OUT) * s
			put(k.ux + k.d[1] * r, k.uz + k.d[2] * r, k.a1)
			if f == DOCK.TURN + 1 then
				callScript(c, "Wheels", -1)
			elseif f == DOCK.TURN + DOCK.BACK then
				callScript(c, "Wheels", 0)
				callScript(c, "Gate", true)
			end
		else
			local t = f - DOCK.TURN - DOCK.BACK - DOCK.GATE
			local n = h.cap / h.crate
			if t > 0 and t % DOCK.CRATE == 0 then
				if k.crates < n then
					if g.stock < h.crate then
						return -- (no crate in the stock: it waits)
					end
					g.stock = g.stock - h.crate
					Spring.SetUnitRulesParam(h.src, "lavaStock", g.stock, { public = true })
					showGen(h.src, g)
					k.crates = k.crates + 1
					callScript(c, "LoadCrate", k.crates)
					setLoad(c, h, h.load + h.crate)
				elseif not k.closing then
					k.closing = true
					callScript(c, "Gate", false)
				else
					endDock(c, h) -- (loaded: the next step of haul drives it to the factory)
					return
				end
			end
		end
		k.f = f + 1
	end

	-- one step of a hauling Carrier (every half second)
	local function haul(c, h)
		local team = Spring.GetUnitTeam(c)
		if h.load > 0 and (h.go or not h.box) then
			h.spot, h.waitSince = nil, nil -- (it leaves its loading spot)
			local dst = h.dst and Spring.ValidUnitID(h.dst) and isFactory(h.dst, team) and h.dst or nearestFactory(c, team)
			if not dst then
				return -- (no factory: it waits with its load)
			end
			if near(c, dst) then
				local per = h.box or h.crate
				local n = per and math.min(per, h.load) or h.load -- (a Forklift: one box per step, a Cargo Truck one crate)
				if h.crate then
					callScript(c, "Gate", h.load - n > 0)
				end
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
			h.src = nil -- (the generator is gone, or it had none: it stops)
			h.last = h.last and gens[h.last] and h.last or nil
			Spring.SetUnitRulesParam(c, "lavaHauling", 0, { public = true })
			return
		end
		local at = toPad(c, h, g)
		if at and h.box then
			if g.stock >= h.box and h.load + h.box <= h.cap then
				g.stock = g.stock - h.box
				Spring.SetUnitRulesParam(h.src, "lavaStock", g.stock, { public = true })
				showGen(h.src, g)
				setLoad(c, h, h.load + h.box)
			elseif h.load > 0 then
				h.go, h.goal, h.gx = true, nil, nil -- (full, or the stock has no box more)
			end
		elseif at and h.canDock then
			if g.stock >= h.cap then
				startDock(c, h) -- (it backs up and loads crate by crate: dockStep)
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

	-- an idle vehicle on Maneuver or Roam (not after Stop) hauls on its own: from its last Lava Extractor, otherwise from the nearest working one of its
	-- team within AUTO_RANGE
	local function autoHaul(c, h)
		if h.stopped or orders(c) > 0 or Spring.GetUnitIsBeingBuilt(c) then
			return
		end
		local st = Spring.GetUnitStates(c)
		if not st or st.movestate == 0 then
			return -- (Hold Position)
		end
		local team = Spring.GetUnitTeam(c)
		local src = h.last and gens[h.last] and Spring.GetUnitTeam(h.last) == team and h.last
		if not src then
			local x, _, z = Spring.GetUnitPosition(c)
			local bd = AUTO_RANGE * AUTO_RANGE
			for u, g in pairs(gens) do
				if g.on and Spring.GetUnitTeam(u) == team then
					local ux, _, uz = Spring.GetUnitPosition(u)
					local dd = (ux - x) ^ 2 + (uz - z) ^ 2
					if dd < bd then
						src, bd = u, dd
					end
				end
			end
		end
		if src then
			h.src, h.last, h.goal, h.gx = src, src, nil, nil
			Spring.SetUnitRulesParam(c, "lavaHauling", 1, { public = true })
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
			local cd = carrierDef[defID]
			carriers[u] = { load = 0, cap = cd.cap, box = cd.box, crate = cd.crate, canDock = cd.dock }
			Spring.InsertUnitCmdDesc(u, HAUL_DESC)
		end
	end

	function gadget:UnitDestroyed(u)
		gens[u], carriers[u] = nil, nil
	end

	function gadget:UnitGiven(u)
		local h = carriers[u]
		if h then
			endDock(u, h)
			h.src, h.dst, h.goal, h.last = nil, nil, nil, nil -- (another team: the orders of the old one end)
		end
	end

	-- A Carrier: Haul on a Lava Extractor of its team starts the hauling, on a factory of its team chooses where it delivers (the order itself is
	-- used up here, it never stands in the queue); every other order of a player ends the hauling (the load stays).
	function gadget:AllowCommand(u, defID, team, cmdID, params, opts, tag, playerID, fromSynced)
		local h = carriers[u]
		if cmdID == CMD_HAUL then
			local t = h and params[1]
			if h then
				h.stopped = nil
			end
			if t and gens[t] and Spring.GetUnitTeam(t) == team then
				h.src, h.last, h.goal = t, t, nil
				Spring.SetUnitRulesParam(u, "lavaHauling", 1, { public = true })
			elseif t and isFactory(t, team) then
				h.dst, h.goal = t, nil
				Spring.SetUnitRulesParam(u, "lavaDst", t, { public = true })
				if not h.src and h.load > 0 then
					h.src = h.last or -1 -- (loaded, not hauling: it delivers there, then hauls again from its last extractor if it has one)
				end
			end
			return false
		end
		if not h or own then
			return true -- (its own orders)
		end
		if HAUL_STOP[cmdID] then
			-- (after Stop it does not haul on its own; after Move and the others it does, AUTO; a Stop before it ever hauled does not count: the
			-- editor stops every unit it places)
			h.stopped = cmdID == CMD.STOP and (h.src or h.last) and true or nil
			endDock(u, h)
			if h.src then
				h.src, h.goal = nil, nil
				Spring.SetUnitRulesParam(u, "lavaHauling", 0, { public = true })
			end
		end
		return true
	end

	-- the test start of start_experimental.bat (game option lanexpdemo=1): a Volcano with a Lava Extractor, then
	-- a Carrier, a Cargo Truck and a Forklift side by side and a vehicle plant behind them, for team 0, between its start and the middle of the map
	local function placeDemo()
		local team = 0
		local sx, _, sz = Spring.GetTeamStartPosition(team)
		if not sx or sx < 0 then
			sx, sz = Game.mapSizeX / 2, Game.mapSizeZ / 2
		end
		local dx, dz = Game.mapSizeX / 2 - sx, Game.mapSizeZ / 2 - sz
		local l = math.sqrt(dx * dx + dz * dz)
		if l > 1 then
			dx, dz = dx / l, dz / l
		else
			dx, dz = 0, 1
		end
		local vx, vz = sx + dx * 380, sz + dz * 380
		local side = vx + 620 < Game.mapSizeX and 1 or -1 -- (the units to the right of the Volcano, or to the left near the edge of the map)
		local function at(x, z)
			x = math.max(64, math.min(Game.mapSizeX - 64, x))
			z = math.max(64, math.min(Game.mapSizeZ - 64, z))
			return x, Spring.GetGroundHeight(x, z), z
		end
		local x, y, z = at(vx, vz)
		Spring.CreateFeature("lava_volcano", x, y, z, 0)
		Spring.CreateUnit("armlavagen", x, y, z, 0, team)
		local facing = side == 1 and 3 or 1 -- (the units look at the Volcano)
		for i, name in ipairs({ "armlavacarrier", "armlavatruck", "armlavafork" }) do
			x, y, z = at(vx + side * 270, vz + (i - 2) * 60)
			Spring.CreateUnit(name, x, y, z, facing, team)
		end
		x, y, z = at(vx + side * 470, vz)
		Spring.CreateUnit("armvp", x, y, z, facing, team)
		Spring.Echo("Experimental Units: select a Carrier, the Cargo Truck or the Forklift and right-click the Lava Extractor (order Haul): they fetch its metal for the vehicle plant.")
	end

	function gadget:GameFrame(f)
		if f == 5 and (Spring.GetModOptions() or {}).lanexpdemo == "1" then
			placeDemo()
		end
		if f % 30 == 7 then
			for u, g in pairs(gens) do
				checkGen(u, g)
			end
		end
		for c, h in pairs(carriers) do
			if h.dock then
				dockStep(c, h)
			elseif f % 15 == 3 then
				if h.src then
					haul(c, h)
				else
					autoHaul(c, h)
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
		LAKE = 56, STREAM_END = 160, rivers = {} }
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
