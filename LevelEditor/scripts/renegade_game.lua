-- Renegade (synchronized part), a planned game mode of LAN Play: every human player steers one original unit in the first person. Active only with the
-- game option lanrenegade=1. Proof of concept 2: every team with a human player and a commander gets a Peewee (armpw) instead; the game widget renegade.lua
-- sends the view and the keys ("ren|<yaw degrees>|<pitch degrees>|<keys>|<fire>|<x>|<y>|<z>|<unit>", keys: W 1, A 2, S 4, D 8; x y z the point under the crosshair, unit the enemy there or -1); this gadget moves the unit with ordinary
-- move orders (no MoveCtrl) toward a point in the wished direction and stops it when no key is down.
-- While fire is 1 the unit gets the point (or the enemy unit) as its target (Spring.SetUnitTarget, user target), so its own weapon, turret, reload and damage
-- apply; its fire state is hold fire: it shoots only at what the player aims at. Test only: game option lanrenotest=1 and "ren|test|1" put an enemy
-- Peewee (hold fire) 150 Elmo in front of the unit. 
-- Game option lanrenebots=<n>: n computer Peewees of the first team without a human walk around and fight the players (a lost one comes back after 5 s),
-- lanrenedebug=1: the player may turn into another unit ("ren|unit|<unit name>", units with a weapon: also aircraft, ships (they lie on the land: for the tests), turrets). A player's unit that is lost comes back after 3 s at a place far from
-- the enemies. Team rules parameter renUnit (public): the unit of the team (0 = none). Spec: specs/renegade.md.
function gadget:GetInfo()
	return {
		name = "Renegade",
		desc = "LAN Play game mode: one unit per human, steered in the first person",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local opt = (Spring.GetModOptions() or {}).lanrenegade
if opt ~= "1" and opt ~= 1 then
	return false -- not a Renegade game
end

if not gadgetHandler:IsSyncedCode() then
	return false -- everything is synchronized; the view is the job of the widget renegade.lua
end

local START_UNIT = "armpw"
local STEP = 200 -- Elmo: how far ahead of the unit the move order points
local REISSUE = 10 -- frames: a move order is given again after that time while a key is down
local TURN = 6 -- degrees: the order is given again at once when the wished direction turned by more than that

local TEST = (Spring.GetModOptions() or {}).lanrenotest == "1"
local AIM_EVERY = 3 -- frames: the target is given again (a move order may drop it)
local ENERGY = 500 -- energy per second for the players (the lasers need much; for the tests)
local MO = Spring.GetModOptions() or {}
local DEBUG = MO.lanrenedebug == "1"
local BOTS = math.max(0, math.min(30, tonumber(MO.lanrenebots) or 0))
local RESPAWN = 150 -- frames until a player's unit comes back (5 s; the widget counts down, team rules parameter renRespawn = the frame)
local lastPos = {} -- team -> where its unit was lost (when no place is found, e.g. for a ship on land)
local BOT_RESPAWN = 150
local turnInto -- (defined below: the debug message of RecvLuaMsg needs it)
local units = {} -- team -> unit id
local kind = {} -- team -> unit definition name of the player's unit (a lost unit comes back as the same one)
local due = {} -- team -> frame at which the unit comes back
local bots, botDue, botTeam = {}, {}, nil -- bots: unit id -> true; botDue: frames at which a lost one comes back
local input = {} -- team -> { yaw, pitch, keys, fire, last = { frame, yaw, keys }, moving }

local function sign(n) return n > 0 and 1 or (n < 0 and -1 or 0) end

-- the direction of the keys in the world: forward (sin yaw, cos yaw) on x / z, right (-cos yaw, sin yaw)
local function wish(inp)
	local k = inp.keys
	local f = (k % 2 >= 1 and 1 or 0) - (math.floor(k / 4) % 2 >= 1 and 1 or 0)
	local r = (math.floor(k / 8) % 2 >= 1 and 1 or 0) - (math.floor(k / 2) % 2 >= 1 and 1 or 0)
	if f == 0 and r == 0 then return nil end
	local y = math.rad(inp.yaw)
	local sx, cz = math.sin(y), math.cos(y)
	local dx, dz = sx * f + (-cz) * r, cz * f + sx * r
	local l = math.sqrt(dx * dx + dz * dz)
	return dx / l, dz / l
end

local function steer(team, f)
	local u, inp = units[team], input[team]
	if not u or not inp or not Spring.ValidUnitID(u) then return end
	local dx, dz = wish(inp)
	if not dx then
		if inp.moving then
			Spring.GiveOrderToUnit(u, CMD.STOP, {}, 0)
			inp.moving = false
		end
		return
	end
	local l = inp.last
	local turned = math.abs(((inp.yaw - l.yaw + 180) % 360) - 180) > TURN
	if inp.moving and not turned and l.keys == inp.keys and f - l.frame < REISSUE then return end
	local x, _, z = Spring.GetUnitPosition(u)
	local tx = math.max(16, math.min(Game.mapSizeX - 16, x + dx * STEP))
	local tz = math.max(16, math.min(Game.mapSizeZ - 16, z + dz * STEP))
	Spring.GiveOrderToUnit(u, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
	inp.moving = true
	l.frame, l.yaw, l.keys = f, inp.yaw, inp.keys
end

-- The shot (like in a shooter: never a "target"): three mouse buttons, each fires a group of the unit's weapons (slotsFor): the left button the short range
-- weapons, the right button the long range ones, the middle button the missiles. Each weapon gets the point the player aims at as its target
-- (Spring.SetUnitTarget with a position, user target, weapon number), shortened along the line from the unit to the point to the reach of that weapon, so it fires
-- toward the crosshair even where nothing is in reach. The enemy unit under the crosshair is not chosen as a target, except for anti-air weapons (they can only
-- hit what flies: the player looks at the aircraft). A message sets the target at once; it is renewed every AIM_EVERY frames; releasing the buttons clears it.
-- The groups: the weapons with the same weapon definition are one group (they fire together). Missiles (missile launchers, starburst, torpedoes, and the
-- anti-air weapons) and all others are sorted by range. With both kinds: the shortest weapon of the others on the left button, the rest of the others on the right
-- button (the right button takes the missiles when there is no second one), the missiles on the middle button. With only one kind: the shortest on the left,
-- the next on the right, all further ones on the middle button.
local MISSILE = { MissileLauncher = true, StarburstLauncher = true, TorpedoLauncher = true }
local slotCache = {}
local function slotsFor(ud)
	local c = slotCache[ud.id]
	if c then return c end
	local armor = (Game.armorTypes or {}).default or 0
	local vtol = (Game.armorTypes or {}).vtol or 14
	local groups, byDef = {}, {}
	for i, wp in ipairs(ud.weapons or {}) do
		local wd = WeaponDefs[wp.weaponDef]
		local d = wd and wd.damages and tonumber(wd.damages[armor]) or 0
		local v = wd and wd.damages and tonumber(wd.damages[vtol]) or 0
		-- (weapons without damage are no weapons: footsteps and the dummies that the unit scripts use)
		if wd and (tonumber(wd.range) or 0) > 0 and wd.type ~= "Shield" and (tonumber(wd.interceptor) or 0) == 0 and (d > 2 or v > 2) then
			local g = byDef[wp.weaponDef]
			if not g then
				g = { range = tonumber(wd.range), list = {}, missile = MISSILE[wd.type] and true or false, aa = (d <= 2 and v > d) }
				if g.aa then g.missile = true end
				byDef[wp.weaponDef] = g
				groups[#groups + 1] = g
			end
			g.list[#g.list + 1] = i
		end
	end
	local others, miss = {}, {}
	for _, g in ipairs(groups) do
		local l = g.missile and miss or others
		l[#l + 1] = g
	end
	local function byRange(x, y) return x.range < y.range end
	table.sort(others, byRange)
	table.sort(miss, byRange)
	local function merge(list, from)
		local out = {}
		for k = from, #list do
			for _, i in ipairs(list[k].list) do out[#out + 1] = i end
		end
		return out
	end
	local s = { L = {}, R = {}, M = {}, aa = {} }
	if #miss > 0 and #others > 0 then
		s.L, s.R, s.M = merge(others, 1), {}, merge(miss, 1)
		s.L = others[1].list
		s.R = merge(others, 2)
		if #s.R == 0 then s.R, s.M = s.M, {} end
	else
		local list = (#others > 0) and others or miss
		s.L = list[1] and list[1].list or {}
		s.R = list[2] and list[2].list or {}
		s.M = merge(list, 3)
	end
	for _, g in ipairs(groups) do
		if g.aa then
			for _, i in ipairs(g.list) do s.aa[i] = true end
		end
	end
	slotCache[ud.id] = s
	return s
end

local function weaponsFor(u, mask)
	local ud = UnitDefs[Spring.GetUnitDefID(u)]
	local s = slotsFor(ud)
	local list = {}
	local function add(l) for _, i in ipairs(l) do list[#list + 1] = i end end
	if mask % 2 >= 1 then add(s.L) end
	if math.floor(mask / 2) % 2 >= 1 then add(s.R) end
	if mask >= 4 then add(s.M) end
	return list, ud, s
end

local function shortened(u, ud, i, x, y, z)
	local wd = WeaponDefs[ud.weapons[i].weaponDef]
	local ux, uy, uz = Spring.GetUnitPosition(u, true)
	local dx, dy, dz = x - ux, y - uy, z - uz
	local d = math.sqrt(dx * dx + dy * dy + dz * dz)
	local r = ((wd and wd.range) or 0) - 8
	if d > r and d > 0 then
		local k = math.max(0, r) / d
		x, y, z = ux + dx * k, uy + dy * k, uz + dz * k
	end
	return math.max(1, math.min(Game.mapSizeX - 1, x)), y, math.max(1, math.min(Game.mapSizeZ - 1, z))
end

-- clear the targets of all weapons: SetUnitTarget(unit, nil) does not clear a target that was set for one weapon number, a stop order does (it clears the
-- move order too: the steering gives it again)
local function clearTargets(u, inp)
	Spring.SetUnitTarget(u, nil)
	Spring.GiveOrderToUnit(u, CMD.STOP, {}, 0)
	inp.moving = false
end

local function shoot(team, f, force)
	local u, inp = units[team], input[team]
	if not u or not inp or not Spring.ValidUnitID(u) then return end
	local mask = inp.fire
	if mask ~= inp.mask then
		if inp.mask ~= 0 then clearTargets(u, inp) end
		inp.mask = mask
		force = true
	end
	if mask == 0 then return end
	if not force and f % AIM_EVERY ~= 0 then return end
	local t = inp.target
	local list, ud, s = weaponsFor(u, mask)
	for _, i in ipairs(list) do
		if s.aa[i] then
			-- anti-air: only at the aircraft the player looks at
			if t.unit >= 0 and Spring.ValidUnitID(t.unit) and not Spring.AreTeamsAllied(team, Spring.GetUnitTeam(t.unit)) then
				Spring.SetUnitTarget(u, t.unit, false, true, i)
			end
		else
			local x, y, z = shortened(u, ud, i, t.x, t.y, t.z)
			Spring.SetUnitTarget(u, x, y, z, false, true, i)
		end
	end
end

function gadget:RecvLuaMsg(msg, playerID)
	if TEST and msg == "ren|test|1" then
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		local u = units[team]
		if u and not spec then
			local x, y, z = Spring.GetUnitPosition(u)
			local inp = input[team]
			local yaw = math.rad(inp.yaw)
			local ex, ez = x + math.sin(yaw) * 150, z + math.cos(yaw) * 150
			for _, t in ipairs(Spring.GetTeamList()) do
				if not Spring.AreTeamsAllied(t, team) and t ~= Spring.GetGaiaTeamID() then
					local e = Spring.CreateUnit(START_UNIT, ex, Spring.GetGroundHeight(ex, ez), ez, 0, t)
					if e then
						Spring.GiveOrderToUnit(e, CMD.FIRE_STATE, { 0 }, 0)
						Spring.Echo("[Renegade] test enemy " .. e .. " at " .. math.floor(ex) .. " " .. math.floor(ez))
					end
					break
				end
			end
		end
		return
	end
	if TEST and msg == "ren|test|2" then
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		if units[team] and not spec then Spring.DestroyUnit(units[team], true, false) end
		return
	end
	local want = msg:match("^ren|unit|([%w_]+)$")
	if want then
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		if DEBUG and not spec then turnInto(team, want) end
		return
	end
	local yaw, pitch, keys, fire, tx, ty, tz, tu = msg:match("^ren|(-?%d+)|(-?%d+)|(%d+)|(%d)|(-?%d+)|(-?%d+)|(-?%d+)|(-?%d+)$")
	if not yaw then return end
	local _, active, spec, team = Spring.GetPlayerInfo(playerID, false)
	if spec or not units[team] then return end
	local inp = input[team]
	inp.yaw, inp.pitch = tonumber(yaw) % 360, math.max(-89, math.min(89, tonumber(pitch)))
	inp.keys, inp.fire = math.max(0, math.min(15, tonumber(keys))), math.max(0, math.min(7, tonumber(fire)))
	inp.target = { x = tonumber(tx), y = tonumber(ty), z = tonumber(tz), unit = tonumber(tu) }
	shoot(team, Spring.GetGameFrame(), true)
end

-- a place on the land for a unit: of 24 random places where the unit can stand, the one farthest from the units of the other teams (a player) or the one at
-- about 800 Elmo from the nearest player unit (a bot: the fight comes to the player)
local function others(team)
	local l = {}
	for tm, u in pairs(units) do
		if tm ~= team and Spring.ValidUnitID(u) then l[#l + 1] = u end
	end
	return l
end

local function nearestDist(x, z, list)
	local best = 1e9
	for _, u in ipairs(list) do
		local ux, _, uz = Spring.GetUnitPosition(u)
		if ux then best = math.min(best, math.sqrt((ux - x) ^ 2 + (uz - z) ^ 2)) end
	end
	return best
end

local function place(defName, list, wanted)
	local defID = UnitDefNames[defName].id
	local bestX, bestZ, bestScore
	for pass = 1, 2 do -- the second pass without the test of the movement class (a ship on land, a turret)
		for _ = 1, 24 do
			local x = 200 + math.random() * (Game.mapSizeX - 400)
			local z = 200 + math.random() * (Game.mapSizeZ - 400)
			local y = Spring.GetGroundHeight(x, z)
			if y > 2 and (pass == 2 or Spring.TestMoveOrder(defID, x, y, z, 0, 0, 0, true, false, true)) then
				local d = nearestDist(x, z, list)
				local score = wanted and -math.abs(d - wanted) or d
				if not bestScore or score > bestScore then bestX, bestZ, bestScore = x, z, score end
			end
		end
		if bestX then break end
	end
	if not bestX then return nil end
	return bestX, Spring.GetGroundHeight(bestX, bestZ), bestZ
end

-- the unit of a player: new, or after a loss, or turned into another one (debug)
local function giveUnit(team, defName, x, y, z, face)
	local id = Spring.CreateUnit(defName, x, y, z, face or 0, team)
	if not id then return nil end
	units[team] = id
	kind[team] = defName
	input[team] = input[team] or { yaw = 0, pitch = 0, keys = 0, fire = 0, last = { frame = 0, yaw = 0, keys = 0 }, moving = false, target = { x = 0, y = 0, z = 0, unit = -1 }, mask = 0 }
	input[team].moving, input[team].mask = false, 0
	input[team].fire = 0
	Spring.GiveOrderToUnit(id, CMD.FIRE_STATE, { 0 }, 0) -- hold fire: only the player aims
	Spring.SetTeamRulesParam(team, "renUnit", id, { public = true })
	-- the groups of weapons of the buttons for the widget: "left;right;middle" (weapon numbers), and the anti-air weapons
	local s = slotsFor(UnitDefNames[defName])
	local aa = {}
	for i in pairs(s.aa) do aa[#aa + 1] = i end
	table.sort(aa)
	Spring.SetUnitRulesParam(id, "renSlots", table.concat(s.L, ",") .. ";" .. table.concat(s.R, ",") .. ";" .. table.concat(s.M, ","), { public = true })
	Spring.SetUnitRulesParam(id, "renAA", table.concat(aa, ","), { public = true })
	return id
end

turnInto = function(team, defName)
	local u = units[team]
	local ud = UnitDefNames[defName]
	if not u or not Spring.ValidUnitID(u) or not ud or #(ud.weapons or {}) == 0 then return end
	local x, y, z = Spring.GetUnitPosition(u)
	local hp, mhp = Spring.GetUnitHealth(u)
	local old = u
	local id = giveUnit(team, defName, x, y, z, Spring.GetUnitBuildFacing(u))
	if not id then return end
	local _, nmhp = Spring.GetUnitHealth(id)
	if hp and mhp and nmhp then Spring.SetUnitHealth(id, nmhp * hp / mhp) end
	Spring.DestroyUnit(old, false, true) -- (units[team] is the new one already: no respawn)
	Spring.Echo("[Renegade] team " .. team .. " turned into " .. defName .. " (unit " .. id .. ")")
end

-- a team with a human and a commander: the commander is replaced by the first unit
local function take(team)
	if units[team] ~= nil then return end
	local human = false
	for _, p in ipairs(Spring.GetPlayerList(team, true)) do
		local _, _, spec = Spring.GetPlayerInfo(p, false)
		if not spec then human = true end
	end
	if not human then return end
	for _, u in ipairs(Spring.GetTeamUnits(team)) do
		local ud = UnitDefs[Spring.GetUnitDefID(u)]
		if ud and ud.customParams and ud.customParams.iscommander then
			local x, y, z = Spring.GetUnitPosition(u)
			local face = Spring.GetUnitBuildFacing(u)
			Spring.DestroyUnit(u, false, true)
			local id = giveUnit(team, START_UNIT, x, y, z, face)
			if id then Spring.Echo("[Renegade] team " .. team .. " steers a " .. START_UNIT .. " (unit " .. id .. ")") end
			return
		end
	end
end

-- the bots: units of the first team that has no human; they fight their way toward the nearest player unit
local function findBotTeam()
	for _, team in ipairs(Spring.GetTeamList()) do
		if team ~= Spring.GetGaiaTeamID() and units[team] == nil then
			local human = false
			for _, p in ipairs(Spring.GetPlayerList(team, true)) do
				local _, _, spec = Spring.GetPlayerInfo(p, false)
				if not spec then human = true end
			end
			if not human then return team end
		end
	end
end

local function spawnBot()
	if not botTeam then return end
	local x, y, z = place(START_UNIT, others(botTeam), 800)
	if not x then return end
	local id = Spring.CreateUnit(START_UNIT, x, y, z, math.random(0, 3), botTeam)
	if id then
		bots[id] = true
		if TEST then Spring.Echo("[Renegade] bot " .. id .. " at " .. math.floor(x) .. " " .. math.floor(z)) end
	end
end

local function steerBots()
	local players = others(botTeam)
	if #players == 0 then return end
	if TEST then
		local n, near = 0, 1e9
		for id in pairs(bots) do
			n = n + 1
			local x, _, z = Spring.GetUnitPosition(id)
			if x then near = math.min(near, nearestDist(x, z, players)) end
		end
		Spring.Echo("[Renegade] bots " .. n .. ", nearest to a player " .. math.floor(near) .. " Elmo")
	end
	for id in pairs(bots) do
		local x, _, z = Spring.GetUnitPosition(id)
		if x then
			local best, bx, bz = 1e9
			for _, u in ipairs(players) do
				local ux, _, uz = Spring.GetUnitPosition(u)
				local d = (ux - x) ^ 2 + (uz - z) ^ 2
				if d < best then best, bx, bz = d, ux, uz end
			end
			local tx = math.max(16, math.min(Game.mapSizeX - 16, bx + (math.random() - 0.5) * 300))
			local tz = math.max(16, math.min(Game.mapSizeZ - 16, bz + (math.random() - 0.5) * 300))
			Spring.GiveOrderToUnit(id, CMD.FIGHT, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
		end
	end
end

-- test only: how many weapon groups do the units have (do three buttons do)?
local function census()
	local count, names = {}, {}
	for _, ud in pairs(UnitDefs) do
		if #(ud.weapons or {}) > 0 and not ud.name:find("_scav") and not ud.name:find("^raptor") then
			local s = slotsFor(ud)
			local n = 0
			for _, l in ipairs({ s.L, s.R, s.M }) do if #l > 0 then n = n + 1 end end
			count[n] = (count[n] or 0) + 1
			if #s.M > 0 and #s.R > 0 and #s.L > 0 then names[#names + 1] = ud.name end
		end
	end
	local t = {}
	for n, c in pairs(count) do t[#t + 1] = n .. " buttons: " .. c .. " units" end
	table.sort(t)
	Spring.Echo("[Renegade] census: " .. table.concat(t, ", "))
	for _, n in ipairs({ "armbanth", "armepoch", "corkarg", "armraz", "armpw", "armllt", "armroy", "corkorg", "armthor", "armmav" }) do
		local ud = UnitDefNames[n]
		if ud then
			local s = slotsFor(ud)
			local out = {}
			for i, wp in ipairs(ud.weapons) do
				local wd = WeaponDefs[wp.weaponDef]
				out[#out + 1] = i .. "=" .. wd.name .. "(" .. tostring(wd.type) .. " r" .. math.floor(wd.range) .. ")"
			end
			Spring.Echo("[Renegade] " .. n .. ": L " .. table.concat(s.L, ",") .. " R " .. table.concat(s.R, ",") .. " M " .. table.concat(s.M, ",") .. "   " .. table.concat(out, " "))
		end
	end
end

function gadget:GameFrame(f)
	if TEST and f == 40 then census() end
	if f >= 30 and f <= 300 and f % 15 == 0 then
		for _, team in ipairs(Spring.GetTeamList()) do
			if team ~= Spring.GetGaiaTeamID() then take(team) end
		end
	end
	for team in pairs(units) do
		steer(team, f)
		shoot(team, f)
		if f % 30 == 0 then
			Spring.SetTeamResource(team, "es", 20000) -- the storage: the lasers take much energy per shot
			Spring.AddTeamResource(team, "energy", ENERGY)
		end
	end
	for team, at in pairs(due) do
		if f >= at then
			local x, y, z = place(kind[team], others(team), nil)
			if not x and lastPos[team] then x, y, z = lastPos[team][1], lastPos[team][2], lastPos[team][3] end
			if x and giveUnit(team, kind[team], x, y, z, 0) then
				due[team] = nil
				Spring.SetTeamRulesParam(team, "renRespawn", 0, { public = true })
			else
				due[team] = f + 30 -- (it did not work: again in a second)
			end
		end
	end
	if BOTS > 0 then
		if f == 120 then
			botTeam = findBotTeam()
			for _ = 1, BOTS do spawnBot() end
		end
		if botTeam and f > 120 then
			for i = #botDue, 1, -1 do
				if f >= botDue[i] then table.remove(botDue, i); spawnBot() end
			end
			if f % 120 == 0 then steerBots() end
		end
	end
end

function gadget:UnitDestroyed(u, defID, team)
	if units[team] == u then
		units[team] = nil
		Spring.SetTeamRulesParam(team, "renUnit", 0, { public = true })
		due[team] = Spring.GetGameFrame() + RESPAWN
		Spring.SetTeamRulesParam(team, "renRespawn", due[team], { public = true })
		local x, y, z = Spring.GetUnitPosition(u)
		if x then lastPos[team] = { x, y, z } end
	elseif bots[u] then
		bots[u] = nil
		botDue[#botDue + 1] = Spring.GetGameFrame() + BOT_RESPAWN
	end
end
