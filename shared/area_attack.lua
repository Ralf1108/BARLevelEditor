-- Experimental attacks of the Level Editor and the BluePrinter (XL, XR, XC area attacks, XS split attack, XF focus attack): selected armed units
-- attack a line, a rectangle or a circle dragged on the map. Split off from editor_common.lua, which offers it as M.newAreaAttack (both widgets call
-- Shared.newAreaAttack). Lies next to editor_common.lua: luaui/Include/area_attack.lua in the extra game, LuaUI\Include for the BluePrinter.
-- Returns the function newAreaAttack(o).

-- rules about unit definitions, shared with the gadgets (bar_rules.lua lies next to this file)
local Rules = VFS.Include("luaui/Include/bar_rules.lua", nil, VFS.ZIP_FIRST)
assert(Rules, "bar_rules.lua missing (run the installer again)")

-- Selected armed units attack a line, a rectangle or a circle that is dragged on the map. Used by the
-- Level Editor and the BluePrinter. o: { say = fn(text), mouseGround = fn() -> x, z, inPanel = fn(mx, my) -> bool
-- (no drawing over the menu), onArm = fn() (called when the mode is switched on, to end other stamp modes) }.
-- Methods: toggle(mode "line"|"rect"|"circle"|"split"|"focus"|nil; split = XS spreads the firepower evenly over the enemies in a circle, focus = XF kills them one after the other), armed(), mode(), press(button) (map click while armed; true if used),
-- release() (mouse released: starts the attack), draw() (in DrawWorld), step(frame) (call every frame), disarm().
local function newAreaAttack(o)
	local say = o.say
	local mouseGround = o.mouseGround
	local inPanel = o.inPanel or function() return false end
	local areaArmed = false -- an area attack is armed: drag the shape on the map
	local areaMode = "line" -- "line" | "rect" | "circle": shape that is dragged
	local areaDrag = nil -- { x, z }: start point of the line, rectangle corner or circle center
	local toggleArea

	local function commandCount(id)
		if Spring.GetUnitCommandCount then
			return Spring.GetUnitCommandCount(id) or 0
		end
		local c = Spring.GetUnitCommands(id, 0)
		if type(c) == "table" then
			return #c
		end
		return c or 0
	end

	local function dist2(x1, z1, x2, z2)
		local dx, dz = x1 - x2, z1 - z2
		return dx * dx + dz * dz
	end

	-- Selected armed units spread evenly over a line A -> B. Each gets a piece of the line. Bombers (aircraft with a bomb
	-- weapon) approach it from behind, i.e. along the line: move to a point BEFORE the piece, then attack its center; this
	-- way the bombs fall spread over the whole length. All other units that can shoot at the ground (tanks, bots, ships,
	-- gunships, artillery, rocket launchers, nukes, ...) only get the attack order on the center of their piece (ground
	-- target); mobile units walk into range for it.
	local STAGING_DISTANCE = 2000 -- Elmo from the target, where the bombers form up before the run (line: beside the line, on the side of the group)

	local function isBomber(ud)
		if not ud or not ud.canFly then
			return false
		end
		for _, w in ipairs(ud.weapons or {}) do
			local wd = WeaponDefs[w.weaponDef]
			if wd and wd.type == "AircraftBomb" then
				return true
			end
		end
		return false
	end

	-- Every other armed unit that can shoot at the ground (no bomber): a weapon with canAttackGround that is not an anti-air
	-- weapon (damage against the armor class vtol above the default damage). Units that only shoot at aircraft do not count.
	local function isGroundShooter(ud)
		if not ud or isBomber(ud) then
			return false
		end
		local types = Game.armorTypes or {}
		local defIdx, vtolIdx = types.default or 0, types.vtol or 14
		for _, w in ipairs(ud.weapons or {}) do
			local wd = WeaponDefs[w.weaponDef]
			if wd and wd.damages and wd.canAttackGround ~= false and not wd.paralyzer
				and (tonumber(wd.damages[vtolIdx]) or 0) <= (tonumber(wd.damages[defIdx]) or 0) then
				return true
			end
		end
		return false
	end

	local function selectedBy(test)
		local out = {}
		for _, id in ipairs(Spring.GetSelectedUnits()) do
			if test(UnitDefs[Spring.GetUnitDefID(id)]) then
				out[#out + 1] = id
			end
		end
		return out
	end

	local function selectedBombers()
		return selectedBy(isBomber)
	end

	local function selectedShooters()
		return selectedBy(isGroundShooter)
	end

	local function clampToMap(x, z)
		local m = 64
		return math.max(m, math.min((Game.mapSizeX or 8192) - m, x)), math.max(m, math.min((Game.mapSizeZ or 8192) - m, z))
	end

	-- Plan: per unit { id, x, z (center of the piece), fx, fz (approach point) }; ids is the list of units (or nil: n placeholders);
	-- approach = 0: no approach (everything but bombers), otherwise distance of the approach point before the piece
	local function linePlan(ax, az, bx, bz, ids, n, approach)
		approach = approach or STAGING_DISTANCE
		local dx, dz = bx - ax, bz - az
		local len = math.sqrt(dx * dx + dz * dz)
		local ux, uz = 0, 0
		if len >= 8 then
			ux, uz = dx / len, dz / len
		end
		n = ids and #ids or n
		local order = {}
		for i = 1, n do
			order[i] = ids and ids[i] or false
		end
		if ids and len >= 8 then
			-- Units are sorted along the line: the one at the A end takes the first piece, so the paths do not cross
			local function proj(id)
				local x, _, z = Spring.GetUnitPosition(id)
				return x and ((x - ax) * ux + (z - az) * uz) or 0
			end
			table.sort(order, function(a, b) return proj(a) < proj(b) end)
		end
		-- Bombers form up in a row beside the line (perpendicular to it, on the side where the group stands), so the run
		-- goes straight at the line as a front and nobody flies over the target area before the attack
		local side = 1
		if ids and len >= 8 and approach > 0 then
			local sx, sz, c = 0, 0, 0
			for _, id in ipairs(ids) do
				local x, _, z = Spring.GetUnitPosition(id)
				if x then
					sx, sz, c = sx + x, sz + z, c + 1
				end
			end
			if c > 0 and (sx / c - (ax + dx / 2)) * -uz + (sz / c - (az + dz / 2)) * ux < 0 then
				side = -1
			end
		end
		local vx, vz = -uz * side, ux * side
		local plan = {}
		for i = 1, n do
			local t = (n == 1) and 0.5 or (i - 0.5) / n
			local cx, cz = ax + dx * t, az + dz * t
			local fx, fz = cx + vx * approach, cz + vz * approach
			if len < 8 or approach == 0 then
				fx, fz = cx, cz
			end
			fx, fz = clampToMap(fx, fz)
			plan[i] = { id = order[i], x = cx, z = cz, fx = fx, fz = fz }
		end
		return plan, len
	end

	-- Rectangle or circle: one target point per unit spread evenly inside the area (grid or sunflower spiral).
	-- Bombers approach from the side where the group stands; units and points are paired by their position across
	-- that direction so the paths cross less. Returns the plan (same format as linePlan) and the size of the area.
	local function areaPlan(shape, ax, az, bx, bz, ids, n, approach)
		n = ids and #ids or n
		local pts, cx, cz, size = {}, 0, 0, 0
		if shape == "circle" then
			local r = math.max(math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2), 16)
			cx, cz, size = ax, az, r
			for i = 1, n do
				local rad, th = r * math.sqrt((i - 0.5) / n), i * 2.399963
				pts[i] = { x = cx + rad * math.cos(th), z = cz + rad * math.sin(th) }
			end
		else
			local x1, x2, z1, z2 = math.min(ax, bx), math.max(ax, bx), math.min(az, bz), math.max(az, bz)
			local w, h = math.max(x2 - x1, 16), math.max(z2 - z1, 16)
			cx, cz, size = (x1 + x2) / 2, (z1 + z2) / 2, math.max(w, h)
			local cols = math.max(1, math.min(n, math.ceil(math.sqrt(n * w / h))))
			local rows = math.ceil(n / cols)
			for i = 1, n do
				local k = math.floor((i - 0.5) * cols * rows / n)
				pts[i] = { x = x1 + (k % cols + 0.5) * w / cols, z = z1 + (math.floor(k / cols) + 0.5) * h / rows }
			end
		end
		-- direction of the approach: from the group to the middle of the area
		local ux, uz = 0, 1
		if ids and #ids > 0 then
			local sx, sz, c = 0, 0, 0
			for _, id in ipairs(ids) do
				local x, _, z = Spring.GetUnitPosition(id)
				if x then
					sx, sz, c = sx + x, sz + z, c + 1
				end
			end
			if c > 0 then
				local dx, dz = cx - sx / c, cz - sz / c
				local len = math.sqrt(dx * dx + dz * dz)
				if len >= 8 then
					ux, uz = dx / len, dz / len
				end
			end
		end
		local function across(x, z)
			return (x - cx) * -uz + (z - cz) * ux
		end
		table.sort(pts, function(a, b) return across(a.x, a.z) < across(b.x, b.z) end)
		local order = {}
		for i = 1, n do
			order[i] = ids and ids[i] or false
		end
		if ids then
			table.sort(order, function(a, b)
				local xa, _, za = Spring.GetUnitPosition(a)
				local xb, _, zb = Spring.GetUnitPosition(b)
				return across(xa or cx, za or cz) < across(xb or cx, zb or cz)
			end)
		end
		-- All bombers stage on ONE line `approach` before the front edge of the area (the edge nearest to the group); a
		-- target further back gets a staging point further back by its depth. The flight to the target is then longer
		-- for the targets at the back: the front targets are bombed first, nobody has to cross the area to hit the front.
		local frontD = math.huge
		for _, p in ipairs(pts) do
			frontD = math.min(frontD, (p.x - cx) * ux + (p.z - cz) * uz)
		end
		local plan = {}
		for i = 1, n do
			local p = pts[i]
			local fx, fz = p.x, p.z
			if approach > 0 then
				local back = approach + ((p.x - cx) * ux + (p.z - cz) * uz) - frontD
				fx, fz = clampToMap(p.x - ux * back, p.z - uz * back)
			end
			plan[i] = { id = order[i], x = p.x, z = p.z, fx = fx, fz = fz }
		end
		return plan, size
	end

	local function planFor(ax, az, bx, bz, ids, n, approach)
		if areaMode == "line" then
			return linePlan(ax, az, bx, bz, ids, n, approach)
		end
		return areaPlan(areaMode, ax, az, bx, bz, ids, n, approach)
	end

	-- Split attack (XS) and focus attack (XF): the selected units attack the visible enemy units inside a circle. XS spreads
	-- the damage per second of the units evenly over the targets (health is not looked at). XF kills the targets as fast as
	-- possible one after the other (nearest first), every target with as many units as it needs to die (health +
	-- SPLIT_BUFFER), the rest goes on to the next. Firepower = damage per second against the armor class of the target,
	-- from the weapon definitions (beam
	-- lasers count like the others; paralyzer weapons, stockpile weapons (nukes) and the D-Gun do not; area damage is not
	-- counted). Mobile enemies come first, buildings after them.
	local SPLIT_MODES = { split = true, focus = true } -- the modes of this attack (areaMode)
	local SPLIT_NAMES = { split = "Split attack", focus = "Focus attack" }
	local SPLIT_BUFFER = 1.15 -- XF: a target is planned with 15 % more damage than its health
	local SPLIT_KILL_TIME = 3 -- seconds in which the units given to a target should kill it
	local SPLIT_QUEUE = 8 -- planned targets per unit (and one more at the end)
	local SPLIT_MAX_TARGETS, SPLIT_MAX_UNITS = 150, 300
	local SPLIT_EVERY = 30 -- frames between two checks of the plan
	local SPLIT_TIMEOUT = 30 * 600 -- the plan ends after 10 minutes at the latest
	local split = nil -- running split attack: { units = { [unitID] = { target ids } }, targets = { [unitID] = true }, frame }
	local weaponCache = {}

	local function isArmed(ud)
		return ud ~= nil and #(ud.weapons or {}) > 0
	end

	-- Weapons of the unit def aDef that can hurt the unit def tDef: list of { dps, volley (damage of one salvo), range }
	local function weaponsAgainst(aDef, tDef)
		local key = aDef * 100000 + tDef
		local c = weaponCache[key]
		if c then
			return c
		end
		c = {}
		local aud, tud = UnitDefs[aDef], UnitDefs[tDef]
		if aud and tud and WeaponDefs then
			local types = Game.armorTypes or {}
			local defIdx, vtolIdx = types.default or 0, types.vtol or 14
			local armor = tonumber(tud.armorType) or defIdx
			local airTarget = tud.canFly and true or false
			for _, w in ipairs(aud.weapons or {}) do
				local wd = WeaponDefs[w.weaponDef]
				if wd and wd.damages and not wd.paralyzer and wd.type ~= "DGun" and not wd.stockpile then
					local aa = (tonumber(wd.damages[vtolIdx]) or 0) > (tonumber(wd.damages[defIdx]) or 0)
					local fits = (airTarget and aa) or (not airTarget and not aa and wd.canAttackGround ~= false)
					local dmg = tonumber(wd.damages[armor]) or tonumber(wd.damages[defIdx]) or 0
					local reload = tonumber(wd.reload) or 0
					if fits and dmg > 1 and reload > 0 then
						local volley = dmg * (tonumber(wd.projectiles) or 1) * (tonumber(wd.salvoSize) or 1)
						c[#c + 1] = { dps = volley / reload, volley = volley, range = tonumber(wd.range) or 0 }
					end
				end
			end
		end
		weaponCache[key] = c
		return c
	end

	-- Damage per second and damage per volley of a unit against a target at distance dist; a unit that cannot move
	-- (static) only counts the weapons that reach
	local function splitDps(aDef, tDef, static, dist)
		local dps, volley = 0, 0
		for _, w in ipairs(weaponsAgainst(aDef, tDef)) do
			if not static or dist <= w.range then
				dps, volley = dps + w.dps, volley + w.volley
			end
		end
		return dps, volley
	end

	local function targetInfo(id)
		local def = Spring.GetUnitDefID(id)
		local hp = Spring.GetUnitHealth(id)
		if not def or not hp or hp <= 0 or Spring.GetUnitIsDead(id) then
			return nil
		end
		local x, _, z = Spring.GetUnitPosition(id)
		if not x then
			return nil
		end
		return { id = id, def = def, x = x, z = z, hp = hp, team = Spring.GetUnitTeam(id), mobile = (tonumber(UnitDefs[def].speed) or 0) > 0 }
	end

	local function attackerInfo(id)
		local def = Spring.GetUnitDefID(id)
		local ud = def and UnitDefs[def]
		local x, _, z = Spring.GetUnitPosition(id)
		if not (ud and x and isArmed(ud)) then
			return nil
		end
		return { id = id, def = def, x = x, z = z, static = (tonumber(ud.speed) or 0) <= 0 }
	end

	-- The teams of a list of unit ids (every team once)
	local function teamsOf(ids)
		local out, seen = {}, {}
		for _, id in ipairs(ids) do
			local team = Spring.GetUnitTeam(id)
			if team and not seen[team] then
				seen[team] = true
				out[#out + 1] = team
			end
		end
		if #out == 0 then
			out[1] = Spring.GetMyTeamID()
		end
		return out
	end

	-- Is a team on the side of the attacking units: the same team or allied to one of their teams (in the Level Editor the
	-- teams of one group are allied with Spring.SetAlly, which Spring.ENEMY_UNITS does not know)
	local function ownSide(team, teams)
		for _, mine in ipairs(teams) do
			if team == mine or Spring.AreTeamsAllied(mine, team) then
				return true
			end
		end
		return false
	end

	-- The visible enemies in a circle: everything the player sees (also what only other units of the player see), no unit of
	-- the teams of the attackers or of their allies, no Gaia
	local function enemiesIn(cx, cz, r, teams)
		local out = {}
		local gaia = Spring.GetGaiaTeamID and Spring.GetGaiaTeamID() or -1
		for _, id in ipairs(Spring.GetUnitsInCylinder(cx, cz, r)) do
			local team = Spring.GetUnitTeam(id)
			if team and team ~= gaia and not ownSide(team, teams) then
				local t = targetInfo(id)
				if t then
					out[#out + 1] = t
				end
			end
		end
		return out
	end

	-- Split plan (XS): the damage per second of all units is spread evenly over the targets; health and armor of the targets
	-- are not looked at. Every target gets the same share of the total DPS. Target by target (mobile first, nearest to the
	-- group first) the nearest free units are taken until the share is reached; units that are left over go to the target
	-- that has the least damage so far. Every unit gets its target first and, behind it, the nearest other target it can hit.
	local function splitPlan(attackers, targets)
		local gx, gz = 0, 0
		for _, u in ipairs(attackers) do
			gx, gz = gx + u.x, gz + u.z
		end
		gx, gz = gx / math.max(1, #attackers), gz / math.max(1, #attackers)
		table.sort(targets, function(a, b)
			if a.mobile ~= b.mobile then
				return a.mobile
			end
			return dist2(a.x, a.z, gx, gz) < dist2(b.x, b.z, gx, gz)
		end)
		local total = 0 -- DPS of all units (mean over the targets a unit can hit)
		for _, u in ipairs(attackers) do
			local sum, count = 0, 0
			for _, t in ipairs(targets) do
				local d = splitDps(u.def, t.def, u.static, math.sqrt(dist2(u.x, u.z, t.x, t.z)))
				if d > 0 then
					sum, count = sum + d, count + 1
				end
			end
			total = total + (count > 0 and sum / count or 0)
		end
		local share = total / math.max(1, #targets)
		local free, queues, got = {}, {}, {}
		for _, u in ipairs(attackers) do
			free[#free + 1] = u
			queues[u.id] = {}
		end
		for _, t in ipairs(targets) do
			got[t.id] = 0
			local cand = {}
			for _, u in ipairs(free) do
				local d = math.sqrt(dist2(u.x, u.z, t.x, t.z))
				local dps = splitDps(u.def, t.def, u.static, d)
				if dps > 0 then
					cand[#cand + 1] = { u = u, d = d, dps = dps }
				end
			end
			table.sort(cand, function(a, b) return a.d < b.d end)
			local taken = {}
			for _, c in ipairs(cand) do
				if got[t.id] > 0 and got[t.id] + c.dps / 2 > share then
					break
				end
				got[t.id] = got[t.id] + c.dps
				taken[c.u.id] = true
				queues[c.u.id][1] = t.id
			end
			local left = {}
			for _, u in ipairs(free) do
				if not taken[u.id] then
					left[#left + 1] = u
				end
			end
			free = left
		end
		for _, u in ipairs(free) do -- units that were not needed for a share: the target with the least damage so far
			local best, bestGot, bestD
			for _, t in ipairs(targets) do
				local d = math.sqrt(dist2(u.x, u.z, t.x, t.z))
				if splitDps(u.def, t.def, u.static, d) > 0 and (not best or got[t.id] < bestGot or (got[t.id] == bestGot and d < bestD)) then
					best, bestGot, bestD = t, got[t.id], d
				end
			end
			if best then
				queues[u.id][1] = best.id
				got[best.id] = got[best.id] + splitDps(u.def, best.def, u.static, bestD)
			end
		end
		for _, u in ipairs(attackers) do -- behind its target the nearest other one, so nothing stands idle while an enemy lives
			local q, best, bestD = queues[u.id], nil, nil
			for _, t in ipairs(targets) do
				if t.id ~= q[1] then
					local d = math.sqrt(dist2(u.x, u.z, t.x, t.z))
					if (not bestD or d < bestD) and splitDps(u.def, t.def, u.static, d) > 0 then
						best, bestD = t, d
					end
				end
			end
			if best then
				q[#q + 1] = best.id
			end
		end
		return queues
	end

	-- Focus plan (XF): every unit gets a queue of target ids. The targets in order of danger: damage per second of the enemy
	-- (against the types of my units) divided by the time I need to get rid of it (the time until my group is in range, at the
	-- mean speed of its mobile units, plus health + SPLIT_BUFFER divided by the DPS of all my units against it); a target that
	-- does no damage comes last, nearest first. One after the other a target takes the nearest free units until the damage of
	-- these units within SPLIT_KILL_TIME seconds (at least one volley each) covers the need of the target: a weak target takes
	-- one unit, a strong one many. These units start on it. A target for which no free unit is left is uncovered: every unit
	-- goes on to the uncovered targets after its own, in the same order, so the whole group concentrates on one target after
	-- the other. Free units that are left when every target is covered start on the nearest target they can hit. At the end
	-- every unit gets one more target (the nearest one it can hit), so nothing stands idle while an enemy lives.
	local function focusPlan(attackers, targets)
		local gx, gz = 0, 0
		for _, u in ipairs(attackers) do
			gx, gz = gx + u.x, gz + u.z
		end
		gx, gz = gx / math.max(1, #attackers), gz / math.max(1, #attackers)
		local byDef, speedSum, mobiles = {}, 0, 0 -- my units by type; mean speed of the mobile ones
		for _, u in ipairs(attackers) do
			byDef[u.def] = (byDef[u.def] or 0) + 1
			if not u.static then
				speedSum, mobiles = speedSum + (tonumber(UnitDefs[u.def].speed) or 0), mobiles + 1
			end
		end
		local meanSpeed = mobiles > 0 and speedSum / mobiles or 0
		for _, t in ipairs(targets) do
			t.need = t.hp * SPLIT_BUFFER + 1
			local threat = 0 -- damage per second of the enemy against my units (mean over my units)
			for def, n in pairs(byDef) do
				for _, w in ipairs(weaponsAgainst(t.def, def)) do
					threat = threat + w.dps * n / #attackers
				end
			end
			local dps, rangeSum, rangeN = 0, 0, 0 -- damage per second of all my units against it, mean range
			for _, u in ipairs(attackers) do
				local d = splitDps(u.def, t.def, u.static, math.sqrt(dist2(u.x, u.z, t.x, t.z)))
				if d > 0 then
					dps = dps + d
					local reach = 0
					for _, w in ipairs(weaponsAgainst(u.def, t.def)) do
						reach = math.max(reach, w.range)
					end
					rangeSum, rangeN = rangeSum + reach, rangeN + 1
				end
			end
			t.gd = math.sqrt(dist2(gx, gz, t.x, t.z))
			local travel = (meanSpeed > 0 and rangeN > 0) and math.max(0, t.gd - rangeSum / rangeN) / meanSpeed or 0
			t.prio = (dps > 0 and threat > 0) and threat / (travel + t.need / dps) or 0
		end
		table.sort(targets, function(a, b)
			if a.prio ~= b.prio then
				return a.prio > b.prio
			end
			return a.gd < b.gd
		end)
		local free, queues, uncovered = {}, {}, {}
		for _, u in ipairs(attackers) do
			free[#free + 1] = u
			queues[u.id] = {}
		end
		for _, t in ipairs(targets) do
			local cand = {}
			for _, u in ipairs(free) do
				local d = math.sqrt(dist2(u.x, u.z, t.x, t.z))
				local dps, volley = splitDps(u.def, t.def, u.static, d)
				if dps > 0 then
					cand[#cand + 1] = { u = u, d = d, dps = dps, volley = volley }
				end
			end
			table.sort(cand, function(a, b) return a.d < b.d end)
			local rest, taken, count = t.need, {}, 0
			for _, c in ipairs(cand) do
				if rest <= 0 then
					break
				end
				local volleys = math.max(1, math.floor(SPLIT_KILL_TIME * c.dps / c.volley + 0.5))
				rest = rest - volleys * c.volley
				taken[c.u.id] = true
				count = count + 1
				queues[c.u.id][1] = t.id
			end
			if count == 0 then
				uncovered[#uncovered + 1] = t
			else
				local left = {}
				for _, u in ipairs(free) do
					if not taken[u.id] then
						left[#left + 1] = u
					end
				end
				free = left
			end
		end
		for _, u in ipairs(attackers) do
			local q, inQueue = queues[u.id], {}
			for _, id in ipairs(q) do
				inQueue[id] = true
			end
			local function nearest(list)
				local best, bestD
				for _, t in ipairs(list) do
					if not inQueue[t.id] then
						local d = math.sqrt(dist2(u.x, u.z, t.x, t.z))
						if (not bestD or d < bestD) and splitDps(u.def, t.def, u.static, d) > 0 then
							best, bestD = t, d
						end
					end
				end
				return best
			end
			if #q == 0 then -- a free unit that nobody needed: the nearest target
				local t = nearest(targets)
				if t then
					q[1], inQueue[t.id] = t.id, true
				end
			end
			for _, t in ipairs(uncovered) do
				if #q >= SPLIT_QUEUE then
					break
				end
				if not inQueue[t.id] and splitDps(u.def, t.def, u.static, math.sqrt(dist2(u.x, u.z, t.x, t.z))) > 0 then
					q[#q + 1], inQueue[t.id] = t.id, true
				end
			end
			local t = nearest(targets)
			if t then
				q[#q + 1] = t.id
			end
		end
		return queues
	end

	-- Gives the orders of a plan; units without a target are dropped from the attack
	local function splitApply(attackers, targets)
		local queues = (split.mode == "focus" and focusPlan or splitPlan)(attackers, targets)
		local given = 0
		split.units = {}
		for _, u in ipairs(attackers) do
			local q = queues[u.id]
			if q and #q > 0 then
				for i, tid in ipairs(q) do
					Spring.GiveOrderToUnit(u.id, CMD.ATTACK, { tid }, i == 1 and {} or { "shift" })
				end
				split.units[u.id] = q
				given = given + 1
			end
		end
		return given
	end

	local function splitGo(ax, az, bx, bz)
		local attackers = {}
		for _, id in ipairs(Spring.GetSelectedUnits()) do
			local u = attackerInfo(id)
			if u and #attackers < SPLIT_MAX_UNITS then
				attackers[#attackers + 1] = u
			end
		end
		if #attackers == 0 then
			say("No armed units selected")
			return
		end
		local r = math.max(math.sqrt(dist2(ax, az, bx, bz)), 16)
		local teams = teamsOf(Spring.GetSelectedUnits())
		local targets = enemiesIn(ax, az, r, teams)
		if #targets == 0 then
			say("No visible enemy in the circle")
			return
		end
		table.sort(targets, function(a, b) return dist2(a.x, a.z, ax, az) < dist2(b.x, b.z, ax, az) end)
		while #targets > SPLIT_MAX_TARGETS do
			targets[#targets] = nil
		end
		split = { units = {}, targets = {}, frame = Spring.GetGameFrame(), mode = areaMode, teams = teams }
		local mobile = 0
		for _, t in ipairs(targets) do
			split.targets[t.id] = true
			if t.mobile then
				mobile = mobile + 1
			end
		end
		local given = splitApply(attackers, targets)
		if given == 0 then
			split = nil
			say(SPLIT_NAMES[areaMode] .. ": no selected unit can hit these enemies")
			return
		end
		say(string.format("%s: %d units on %d enemies (%d mobile, %d buildings)", SPLIT_NAMES[areaMode], given, #targets, mobile, #targets - mobile))
	end

	local function firstCommand(id)
		if Spring.GetUnitCurrentCommand then
			return (Spring.GetUnitCurrentCommand(id, 1))
		end
		local c = Spring.GetUnitCommands(id, 1)
		return type(c) == "table" and c[1] and c[1].id or nil
	end

	-- Every second: forget dead targets and units that got another order; when a target has died, or a unit has finished its
	-- queue while enemies live, a new plan is made for all units that are left (current health, current positions)
	local function splitStep(frame)
		if not split or frame % SPLIT_EVERY ~= 0 then
			return
		end
		local name = SPLIT_NAMES[split.mode]
		if frame - split.frame > SPLIT_TIMEOUT then
			split = nil
			say(name .. " ended (time limit)")
			return
		end
		local living, count, before = {}, 0, 0
		for id in pairs(split.targets) do
			before = before + 1
			local t = targetInfo(id)
			if t and not ownSide(t.team, split.teams) then
				living[id] = t
				count = count + 1
			end
		end
		if count == 0 then
			split = nil
			say(name .. " finished")
			return
		end
		split.targets = {}
		for id in pairs(living) do
			split.targets[id] = true
		end
		local attackers, replan = {}, split.mode == "focus" and count < before
		for id, q in pairs(split.units) do
			local u = attackerInfo(id)
			local cmd = u and firstCommand(id)
			if not u then
				split.units[id] = nil
			elseif cmd == nil then
				local open = false
				for _, tid in ipairs(q) do
					open = open or living[tid] ~= nil
				end
				if open then
					split.units[id] = nil -- idle with a living target: stopped by the player
				else
					replan = true
					attackers[#attackers + 1] = u
				end
			elseif cmd ~= CMD.ATTACK then
				split.units[id] = nil -- the player gave another order
			else
				attackers[#attackers + 1] = u
			end
		end
		if next(split.units) == nil and #attackers == 0 then
			split = nil
			say(name .. " ended: no units left")
			return
		end
		if replan then
			local targets = {}
			for _, t in pairs(living) do
				targets[#targets + 1] = t
			end
			if splitApply(attackers, targets) == 0 then
				split = nil
				say(name .. " ended: nothing left to hit")
			end
		end
	end

	-- Bombers form up first (MOVE to their staging point), then all get the ATTACK order at the same moment: they
	-- fly the run together as a front. { members = { [unitID] = plan entry }, frame = start frame }
	local wave = nil
	local WAVE_RADIUS = 250 -- a bomber counts as in position within this distance of its staging point
	local WAVE_TIMEOUT = 1800 -- frames (60 s): go on even if someone is late

	local function waveStep(frame)
		if not wave then
			return
		end
		local total, ready = 0, 0
		for id, p in pairs(wave.members) do
			if not Spring.ValidUnitID(id) or Spring.GetUnitIsDead(id) then
				wave.members[id] = nil
			else
				total = total + 1
				local x, _, z = Spring.GetUnitPosition(id)
				if (x and dist2(x, z, p.fx, p.fz) <= WAVE_RADIUS * WAVE_RADIUS) or commandCount(id) == 0 then
					ready = ready + 1
				end
			end
		end
		if total == 0 then
			wave = nil
			return
		end
		if ready == total or frame - wave.frame > WAVE_TIMEOUT then
			for id, p in pairs(wave.members) do
				Spring.GiveOrderToUnit(id, CMD.ATTACK, { p.x, Spring.GetGroundHeight(p.x, p.z), p.z }, {})
			end
			say(string.format("Bombers attack: %d of %d in position", ready, total))
			wave = nil
		end
	end

	local function areaGo(ax, az, bx, bz)
		if SPLIT_MODES[areaMode] then
			return splitGo(ax, az, bx, bz)
		end
		local bombers, guns = selectedBombers(), selectedShooters()
		if #bombers == 0 and #guns == 0 then
			say("No armed units selected")
			return
		end
		local len = 0
		if #bombers > 0 then
			local plan
			plan, len = planFor(ax, az, bx, bz, bombers, nil, STAGING_DISTANCE)
			wave = nil
			for _, p in ipairs(plan) do
				if len >= 8 then
					Spring.GiveOrderToUnit(p.id, CMD.MOVE, { p.fx, Spring.GetGroundHeight(p.fx, p.fz), p.fz }, {})
					wave = wave or { members = {}, frame = Spring.GetGameFrame() }
					wave.members[p.id] = p
				else
					Spring.GiveOrderToUnit(p.id, CMD.ATTACK, { p.x, Spring.GetGroundHeight(p.x, p.z), p.z }, {})
				end
			end
		end
		if #guns > 0 then
			local plan
			plan, len = planFor(ax, az, bx, bz, guns, nil, 0)
			for _, p in ipairs(plan) do
				Spring.GiveOrderToUnit(p.id, CMD.ATTACK, { p.x, Spring.GetGroundHeight(p.x, p.z), p.z }, {})
			end
		end
		say(string.format("%s attack: %d bombers, %d other units (%s %d Elmo)", areaMode == "line" and "Carpet" or (areaMode == "rect" and "Rectangle" or "Circle"), #bombers, #guns, areaMode == "circle" and "radius" or "size", math.floor(len)))
	end

	local AREA_HINT = { line = "drag a line", rect = "drag a rectangle", circle = "drag a circle from the center outwards",
		split = "drag a circle from the center outwards: the firepower is spread evenly over the visible enemies in it",
		focus = "drag a circle from the center outwards: the units kill the visible enemies in it one after the other" }
	toggleArea = function(mode)
		if areaArmed and (mode == nil or mode == areaMode) then
			areaArmed = false
			areaDrag = nil
			say("Area attack ended")
			return true
		end
		areaMode = mode or "line"
		areaArmed = true
		areaDrag = nil
		if o.onArm then
			o.onArm()
		end
		local n = SPLIT_MODES[areaMode] and #selectedBy(isArmed) or (#selectedBombers() + #selectedShooters())
		say(n > 0 and string.format("Experimental: %d units selected. On the map %s, right click cancels.", n, AREA_HINT[areaMode])
			or "Experimental: select armed units first, then on the map " .. AREA_HINT[areaMode] .. ".")
		return true
	end

	local function drawArea()
		if not areaArmed then
			return
		end
		local mx, my = Spring.GetMouseState()
		if inPanel(mx, my) then
			return
		end
		local gx, gz = mouseGround()
		if not gx then
			return
		end
		gl.DepthTest(false)
		if not areaDrag then
			gl.Color(1, 0.7, 0.2, 0.9)
			gl.LineWidth(2)
			local y = Spring.GetGroundHeight(gx, gz) + 8
			gl.BeginEnd(GL.LINE_LOOP, function()
				gl.Vertex(gx - 24, y, gz - 24)
				gl.Vertex(gx + 24, y, gz - 24)
				gl.Vertex(gx + 24, y, gz + 24)
				gl.Vertex(gx - 24, y, gz + 24)
			end)
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 1)
			return
		end
		local bombers, guns = selectedBombers(), selectedShooters()
		local plans = {}
		if not SPLIT_MODES[areaMode] and (#bombers > 0 or #guns == 0) then
			plans[#plans + 1] = (planFor(areaDrag.x, areaDrag.z, gx, gz, #bombers > 0 and bombers or nil, math.max(1, #bombers), STAGING_DISTANCE))
		end
		if not SPLIT_MODES[areaMode] and #guns > 0 then
			plans[#plans + 1] = (planFor(areaDrag.x, areaDrag.z, gx, gz, guns, nil, 0))
		end
		gl.LineWidth(2)
		gl.Color(1, 0.7, 0.2, 0.9)
		local ax, az = areaDrag.x, areaDrag.z
		if areaMode == "line" then
			gl.BeginEnd(GL.LINES, function()
				gl.Vertex(ax, Spring.GetGroundHeight(ax, az) + 8, az)
				gl.Vertex(gx, Spring.GetGroundHeight(gx, gz) + 8, gz)
			end)
		elseif areaMode == "rect" then
			gl.BeginEnd(GL.LINE_LOOP, function()
				for _, c in ipairs({ { ax, az }, { gx, az }, { gx, gz }, { ax, gz } }) do
					gl.Vertex(c[1], Spring.GetGroundHeight(c[1], c[2]) + 8, c[2])
				end
			end)
		else
			local r = math.sqrt((gx - ax) ^ 2 + (gz - az) ^ 2)
			gl.BeginEnd(GL.LINE_LOOP, function()
				for k = 0, 47 do
					local x, z = ax + r * math.cos(k * math.pi / 24), az + r * math.sin(k * math.pi / 24)
					gl.Vertex(x, Spring.GetGroundHeight(x, z) + 8, z)
				end
			end)
		end
		for _, plan in ipairs(plans) do
			for _, p in ipairs(plan) do
				local y = Spring.GetGroundHeight(p.x, p.z) + 8
				gl.Color(1, 0.3, 0.2, 0.95)
				gl.BeginEnd(GL.LINE_LOOP, function()
					gl.Vertex(p.x - 14, y, p.z - 14)
					gl.Vertex(p.x + 14, y, p.z - 14)
					gl.Vertex(p.x + 14, y, p.z + 14)
					gl.Vertex(p.x - 14, y, p.z + 14)
				end)
				gl.Color(1, 1, 1, 0.35)
				gl.BeginEnd(GL.LINES, function() -- approach
					gl.Vertex(p.fx, Spring.GetGroundHeight(p.fx, p.fz) + 8, p.fz)
					gl.Vertex(p.x, y, p.z)
				end)
			end
		end
		if SPLIT_MODES[areaMode] then
			local list = enemiesIn(ax, az, math.max(math.sqrt(dist2(ax, az, gx, gz)), 16), teamsOf(Spring.GetSelectedUnits()))
			gl.Color(1, 0.3, 0.2, 0.95)
			for i, e in ipairs(list) do
				if i > SPLIT_MAX_TARGETS then
					break
				end
				local y = Spring.GetGroundHeight(e.x, e.z) + 8
				gl.BeginEnd(GL.LINE_LOOP, function()
					gl.Vertex(e.x - 22, y, e.z - 22)
					gl.Vertex(e.x + 22, y, e.z - 22)
					gl.Vertex(e.x + 22, y, e.z + 22)
					gl.Vertex(e.x - 22, y, e.z + 22)
				end)
			end
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
	end

	local A = {}
	function A:toggle(mode)
		return toggleArea(mode)
	end
	-- The three buttons in the command menu of the game (next to Hold pos, Repeat Off ...): Area Attack (circle), Split Attack (XS), Focus Attack (XF); their
	-- descriptions are in bar_rules.lua. A button is a custom command of type ICON; pressing it arms the mode like the key does (drag the circle on
	-- the map). The BluePrinter adds them with A:addCommands(widgetHandler) in widget:CommandsChanged; in the Level Editor the gadget gives them to the
	-- units. Both pass widget:CommandNotify to A:notify(cmdID).
	function A:commands()
		return Rules.attackButtonDescs()
	end
	-- the texts of the buttons for the order menu (call once, e.g. in widget:Initialize)
	function A:registerTexts()
		local i18n = (BAR and BAR.I18N) or Spring.I18N
		if i18n and i18n.load then
			pcall(i18n.load, Rules.attackButtonTexts())
		end
	end
	-- widget:CommandsChanged of a user widget: widgetHandler.customCommands (the handler of the game checks and copies them)
	function A:addCommands(handler)
		local list = handler.customCommands
		if not list then
			return
		end
		for _, cmd in ipairs(A:commands()) do
			list[#list + 1] = cmd
		end
	end
	-- widget:CommandNotify: true if the command is one of the three buttons (it is used up here, the units get no order)
	function A:notify(cmdID)
		local b = Rules.ATTACK_BUTTONS[(tonumber(cmdID) or 0) - Rules.ATTACK_BUTTONS.base]
		if not b then
			return false
		end
		toggleArea(b.mode)
		return true
	end
	function A:armed()
		return areaArmed
	end
	function A:mode()
		return areaMode
	end
	function A:disarm()
		areaArmed = false
		areaDrag = nil
	end
	-- Map click while armed: right click cancels, left click starts the drag
	function A:press(button)
		if not areaArmed then
			return false
		end
		if button == 3 then
			toggleArea()
			return true
		elseif button == 1 then
			local gx, gz = mouseGround()
			if gx then
				areaDrag = { x = gx, z = gz }
			end
			return true
		end
		return false
	end
	function A:release()
		if areaDrag then
			local d = areaDrag
			areaDrag = nil
			local gx, gz = mouseGround()
			if gx then
				areaGo(d.x, d.z, gx, gz)
				areaArmed = false
			end
		end
	end
	function A:draw()
		drawArea()
	end
	function A:step(frame)
		splitStep(frame)
		if wave and frame % 15 == 0 then
			waveStep(frame)
		end
	end
	return A
end

return newAreaAttack
