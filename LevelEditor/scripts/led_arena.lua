-- Arena page of the Level Editor (button A): armies of several teams around an Arena Point, they fight there. A tool, not a game mode:
-- nothing is won or lost, nothing of it is played in a scenario. Specification: SPECIFICATION.md section 11e, user page tools/arena.md.
-- Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_arena.lua")) as a function that gets the host (the services of the widget) and
-- returns the page; a file of its own because the widget is close to the limit of 200 local variables. The settings (ar.data) are saved in
-- their own section arena of the level file.
--   host.Shared, host.cfg (settings of the editor), host.S() (UI scale), host.say(text), host.canEdit(), host.team(), host.serialize(table),
--   host.disarm() (ends the other modes), host.step() / host.led(message) (undo history of the editor gadget),
--   host.beforePlay() / host.afterPlay() (state before Start: saved and brought back)
return function(host)
	local Shared = host.Shared
	local ar = { open = false, edit = nil, pick = nil, data = nil, notice = nil, spent = {}, spentAt = -10 }
	local pollState -- below
	local ROWS = 10 -- one row per team 0 .. 9
	local MAX_UNITS = 3000 -- units of one army (and of one team on the map)
	local LIMITS = { radius = { 100, 30000 }, count = { 1, MAX_UNITS }, metal = { 0, 99999999 }, energy = { 0, 99999999 } }

	function ar.new()
		local rows = {}
		for i = 1, ROWS do
			rows[i] = { on = i <= 2, allowed = {} } -- the first two players are on; count, metal and energy empty = no limit
		end
		return { radius = 5000, budget = {}, rows = rows, armies = {} }
	end
	ar.DEFAULT = ar.new()

	-- Settings without write: the stored ones or the defaults (never changed by the caller); with write they are created
	function ar.cfg(write)
		if type(ar.data) == "table" then
			return ar.data
		end
		if not write then
			return ar.DEFAULT
		end
		ar.data = ar.new()
		return ar.data
	end

	-- After loading: every field and all ten rows exist (a section of the level file may have less)
	function ar.fix()
		local c = ar.data
		if type(c) ~= "table" then
			return
		end
		if type(c.budget) ~= "table" then
			c.budget = {}
		end
		if type(c.armies) ~= "table" then
			c.armies = {}
		end
		if type(c.rows) ~= "table" then
			c.rows = {}
		end
		for i = 1, ROWS do
			if type(c.rows[i]) ~= "table" then
				c.rows[i] = { on = i <= 2, allowed = {} }
			end
			if type(c.rows[i].allowed) ~= "table" then
				c.rows[i].allowed = {}
			end
		end
	end

	function ar.lua()
		return host.serialize(ar.data)
	end

	function ar.endPick()
		ar.pick = nil
	end

	local POINT_R = 64 -- the red circle of the Arena Point and the distance within which Alt grabs it (Elmo)

	-- State of the Arena Point and the armies as text for the undo history: "x,z;team,nx,nz,ax,az,hw,hh/..." ("-" for none)
	function ar.state()
		local c = ar.cfg()
		local p = c.point and string.format("%d,%d", c.point.x, c.point.z) or "-"
		local out = {}
		for _, a in ipairs(c.armies) do
			out[#out + 1] = string.format("%d,%d,%d,%d,%d,%d,%d", a.team, a.nx, a.nz, a.ax, a.az, a.hw, a.hh)
		end
		return p .. ";" .. (#out > 0 and table.concat(out, "/") or "-")
	end

	function ar.applyState(state)
		local c = ar.cfg(true)
		local p, a = tostring(state):match("^([^;]*);(.*)$")
		local x, z = tostring(p):match("^(-?%d+),(-?%d+)$")
		c.point = x and { x = tonumber(x), z = tonumber(z) } or nil
		c.armies = {}
		for t, nx, nz, ax, az, hw, hh in tostring(a):gmatch("(-?%d+),(-?%d+),(-?%d+),(-?%d+),(-?%d+),(-?%d+),(-?%d+)") do
			c.armies[#c.armies + 1] = { team = tonumber(t), nx = tonumber(nx), nz = tonumber(nz), ax = tonumber(ax), az = tonumber(az), hw = tonumber(hw), hh = tonumber(hh) }
		end
	end

	-- Notes a change of the point or the armies as a step of the undo history (before = ar.state() from before the change)
	function ar.commit(before)
		local after = ar.state()
		if after ~= before then
			host.step()
			host.led("led|arenastate|" .. before .. "|" .. after)
		end
	end

	-- The same without a new step: for the actions that opened their step before their units (Generate, Clear, moving the setup)
	function ar.noteState(before)
		local after = ar.state()
		if after ~= before then
			host.led("led|arenastate|" .. before .. "|" .. after)
		end
	end

	-- Undo / redo from the gadget: take over the new state (called every frame)
	pollState = function()
		local n = Spring.GetGameRulesParam("led_arenastate_n")
		if ar.seen == nil then
			ar.seen = n or 0
		elseif n and n ~= ar.seen then
			ar.seen = n
			ar.applyState(Spring.GetGameRulesParam("led_arenastate") or "-;-")
		end
	end

	local function ground(mx, my)
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		return pos
	end

	-- Is the Arena Point within POINT_R of the mouse pointer?
	function ar.pointAt()
		local c = ar.cfg()
		if not c.point then
			return false
		end
		local mx, my = Spring.GetMouseState()
		local pos = ground(mx, my)
		return pos ~= nil and (c.point.x - pos[1]) ^ 2 + (c.point.z - pos[3]) ^ 2 <= POINT_R ^ 2
	end

	-- Arms a click on the map: "point" (sets or moves the Arena Point) or "gen" (Generate); the same button again ends it
	function ar.startPick(kind)
		ar.finish(true)
		local same = ar.pick == kind
		host.disarm()
		ar.endPick()
		if same then
			host.say("Arena: mode ended")
			return
		end
		ar.pick = kind
		host.say(kind == "point" and "Click on the map: that is the Arena Point (right click ends)." or "Click on the map: the Arena Point is set there and the armies stand around it (right click ends).")
	end

	function ar.cancel()
		ar.endPick()
		host.say("Arena: mode ended")
	end

	-- Left click on the map in the pick mode
	function ar.click(x, z)
		x, z = math.floor(x), math.floor(z)
		if ar.pick == "point" then
			local before = ar.state()
			ar.cfg(true).point = { x = x, z = z }
			ar.commit(before)
			ar.endPick()
			host.say(string.format("Arena Point at %d, %d (Alt + drag moves it, Del removes it).", x, z))
		elseif ar.pick == "gen" then
			ar.generate(x, z) -- the mode stays: every click generates again
		end
	end

	function ar.deletePoint()
		if not host.canEdit() then
			return
		end
		local before = ar.state()
		if not ar.cfg().point then
			host.say("There is no Arena Point.")
			return
		end
		ar.cfg(true).point = nil
		ar.commit(before)
		host.say("Arena Point removed (Ctrl+Z brings it back).")
	end

	-- Del: removes the Arena Point when the mouse pointer is over it; true if it did
	function ar.deleteAt()
		if not ar.open or not host.canEdit() or not ar.pointAt() then
			return false
		end
		ar.deletePoint()
		return true
	end

	-- Alt + left button over the point: it follows the mouse pointer (ar.sample) until the button is released (ar.endDrag); true if it was grabbed.
	-- With Shift as well the whole setup moves with it (the armies when the button is released, see ar.moveSetup).
	function ar.grab(shift)
		if not host.canEdit() or not ar.pointAt() then
			return false
		end
		local p = ar.cfg().point
		ar.drag = { before = ar.state(), whole = shift or nil, x0 = p.x, z0 = p.z }
		return true
	end

	function ar.sample()
		if not ar.drag then
			return
		end
		local mx, my = Spring.GetMouseState()
		local pos = ground(mx, my)
		if pos then
			local p = ar.cfg(true).point
			p.x, p.z = math.floor(pos[1]), math.floor(pos[3])
		end
	end

	function ar.endDrag()
		local d = ar.drag
		if d then
			ar.drag = nil
			if d.whole then
				ar.moveSetup(d)
			else
				ar.commit(d.before)
			end
		end
	end

	-- ---------------------------------------------------------------- Generate, Clear, moving the setup
	local MARGIN = 100 -- an army stays this far from the edge of the map (Elmo)

	-- The center of an army block for a wanted center (nx, nz) pushed onto the map: the block (half sizes hw, hh) keeps MARGIN to the edge
	local function clampArmy(nx, nz, hw, hh)
		local function one(v, half, size)
			local lo, hi = MARGIN + half, size - MARGIN - half
			if lo > hi then
				return size / 2 -- the block is wider than the map allows: in the middle
			end
			return math.max(lo, math.min(hi, v))
		end
		return one(nx, hw, Game.mapSizeX), one(nz, hh, Game.mapSizeZ)
	end

	-- Facing (0 south, 1 east, 2 north, 3 west) of a unit that looks along (dx, dz)
	local function facingToward(dx, dz)
		if math.abs(dx) > math.abs(dz) then
			return dx > 0 and 1 or 3
		end
		return dz > 0 and 0 or 2
	end

	-- Can this unit stand there? Air units anywhere; turrets by the build test; the others by their move definition (terrain only)
	local function canStand(ud, x, z, facing)
		if x < 8 or z < 8 or x > Game.mapSizeX - 8 or z > Game.mapSizeZ - 8 then
			return false
		end
		if ud.canFly then
			return true
		end
		local y = Spring.GetGroundHeight(x, z)
		if not ud.canMove then
			local r = Spring.TestBuildOrder(ud.id, x, y, z, facing)
			return r ~= nil and r >= 1 -- 0 = blocked by the terrain or a building; units and features in the way do not count
		end
		if Spring.TestMoveOrder then
			local ok, res = pcall(Spring.TestMoveOrder, ud.id, x, y, z, 0, 0, 0)
			if ok and res ~= nil then
				return res and true or false
			end
		end
		local md = ud.moveDef
		local depth = y < 0 and -y or 0
		if md and (depth > (tonumber(md.maxWaterDepth) or 1e9) or depth < (tonumber(md.minWaterDepth) or 0)) then
			return false
		end
		return true
	end

	-- Metal and energy cost of all units of a team on the map
	local function teamSpent(team)
		local m, e = 0, 0
		for _, u in ipairs(Spring.GetTeamUnits(team) or {}) do
			local ud = UnitDefs[Spring.GetUnitDefID(u)]
			if ud then
				m, e = m + (ud.metalCost or 0), e + (ud.energyCost or 0)
			end
		end
		return m, e
	end

	-- The unit types of one army: drawn at random from the allowed ones that still fit into its budget, until the count is reached or none fits
	-- (returns the list of unit definitions, or nil and the reason)
	local function chooseUnits(row, team)
		local pool = {}
		for _, name in ipairs(row.allowed) do
			if UnitDefNames[name] then
				pool[#pool + 1] = UnitDefNames[name]
			end
		end
		if #pool == 0 then
			return nil, "no unit is allowed"
		end
		if not row.count and not row.metal and not row.energy then
			return nil, "enter a count or a budget"
		end
		local cap = math.min(MAX_UNITS, Spring.GetTeamMaxUnits and (Spring.GetTeamMaxUnits(team) or MAX_UNITS) or MAX_UNITS)
		local room = cap - (Spring.GetTeamUnitCount(team) or 0)
		if room <= 0 then
			return nil, "the team has " .. (Spring.GetTeamUnitCount(team) or 0) .. " units already (limit " .. cap .. ")"
		end
		local limit = math.min(row.count or room, room)
		local sm, se = teamSpent(team)
		local remM = row.metal and (row.metal - sm) or nil
		local remE = row.energy and (row.energy - se) or nil
		local chosen, n = {}, #pool
		while #chosen < limit and n > 0 do
			local k = math.random(n)
			local ud = pool[k]
			local cm, ce = ud.metalCost or 0, ud.energyCost or 0
			if (remM == nil or cm <= remM) and (remE == nil or ce <= remE) then
				chosen[#chosen + 1] = ud
				remM = remM and (remM - cm) or nil
				remE = remE and (remE - ce) or nil
			else
				pool[k] = pool[n] -- it does not fit any more (the budget only gets smaller)
				pool[n] = nil
				n = n - 1
			end
		end
		if #chosen == 0 then
			return nil, "nothing fits into the budget"
		end
		table.sort(chosen, function(a, b) return a.name < b.name end) -- the same types stand together
		return chosen
	end

	-- Places the army of one team around its spot: a rectangle of cells facing the point; a unit that does not fit its cell goes to the nearest
	-- free ground. Returns the messages and the number placed.
	local function layoutArmy(chosen, team, army, fx, fz, facing)
		local cell = 32
		for _, ud in ipairs(chosen) do
			cell = math.max(cell, 2 * (ud.radius or 16) + 16)
		end
		local n = #chosen
		local w = math.max(1, math.min(n, math.ceil(math.sqrt(2 * n))))
		local d = math.ceil(n / w)
		local tx, tz = -fz, fx -- across the facing
		local used, msgs, noGround = {}, {}, {}
		local function key(x, z)
			return math.floor(x / cell + 0.5) .. ":" .. math.floor(z / cell + 0.5)
		end
		local function put(ud, x, z)
			used[key(x, z)] = true
			msgs[#msgs + 1] = string.format("led|place|%s|%d|%d|%d|%d|0|0|1", ud.name, team, math.floor(x + 0.5), math.floor(z + 0.5), facing)
		end
		for i, ud in ipairs(chosen) do
			local col, row = (i - 1) % w, math.floor((i - 1) / w)
			local u = (col - (w - 1) / 2) * cell
			local v = ((d - 1) / 2 - row) * cell
			local x, z = army.ax + tx * u + fx * v, army.az + tz * u + fz * v
			if canStand(ud, x, z, facing) and not used[key(x, z)] then
				put(ud, x, z)
			else
				-- nearest free ground: rings around the wanted spot
				local done = noGround[ud.name] -- a unit type that found no ground at all before does not search again
				for ring = 1, done and 0 or 14 do
					for dx = -ring, ring do
						for dz = -ring, ring do
							if not done and math.max(math.abs(dx), math.abs(dz)) == ring then
								local px, pz = x + dx * cell, z + dz * cell
								if not used[key(px, pz)] and canStand(ud, px, pz, facing) then
									put(ud, px, pz)
									done = true
								end
							end
						end
					end
					if done then
						break
					end
				end
				if not done then
					noGround[ud.name] = true
				end
			end
		end
		return msgs, #msgs
	end

	-- Generate: the Arena Point is set at (cx, cz), every army of a row that is on stands around it
	function ar.generate(cx, cz)
		if not host.canEdit() then
			return
		end
		local c = ar.cfg(true)
		local active = {}
		for i = 1, ROWS do
			if c.rows[i].on and Spring.GetTeamInfo(i - 1) then
				active[#active + 1] = i
			end
		end
		if #active == 0 then
			host.say("No row is on: switch on the players that get an army.")
			ar.notice = { text = "No row is on.", untilT = os.clock() + 6 }
			return
		end
		local before = ar.state()
		host.step()
		c.point = { x = cx, z = cz }
		local lines, total = {}, 0
		local byTeam = {}
		for _, a in ipairs(c.armies) do
			byTeam[a.team] = a
		end
		for k, i in ipairs(active) do
			local team = i - 1
			local chosen, why = chooseUnits(c.rows[i], team)
			if not chosen then
				lines[#lines + 1] = string.format("Army %d: %s", i, why)
			else
				local a = -math.pi / 2 + 2 * math.pi * (k - 1) / #active -- equal angles, the first army in the north
				local nx, nz = cx + c.radius * math.cos(a), cz + c.radius * math.sin(a)
				local dx, dz = cx - nx, cz - nz
				local len = math.sqrt(dx * dx + dz * dz)
				local fx, fz = len > 0 and dx / len or 0, len > 0 and dz / len or 1
				-- size of the block: the cell is the largest unit plus a gap, about 1.4 times as wide as deep
				local cell = 32
				for _, ud in ipairs(chosen) do
					cell = math.max(cell, 2 * (ud.radius or 16) + 16)
				end
				local n = #chosen
				local w = math.max(1, math.min(n, math.ceil(math.sqrt(2 * n))))
				local d = math.ceil(n / w)
				local hw0, hh0 = w * cell / 2, d * cell / 2
				local tx, tz = -fz, fx
				local hw = math.abs(tx) * hw0 + math.abs(fx) * hh0
				local hh = math.abs(tz) * hw0 + math.abs(fz) * hh0
				local ax, az = clampArmy(nx, nz, hw, hh)
				local army = { team = team, nx = math.floor(nx), nz = math.floor(nz), ax = math.floor(ax), az = math.floor(az), hw = math.floor(hw), hh = math.floor(hh) }
				local msgs, placed = layoutArmy(chosen, team, army, fx, fz, facingToward(fx, fz))
				for _, m in ipairs(msgs) do
					host.queue(m)
				end
				byTeam[team] = army
				total = total + placed
				lines[#lines + 1] = string.format("Army %d: %d of %d placed%s", i, placed, #chosen, placed < #chosen and " (no fitting ground for the rest)" or "")
			end
		end
		c.armies = {}
		for t = 0, ROWS - 1 do
			if byTeam[t] then
				c.armies[#c.armies + 1] = byTeam[t]
			end
		end
		ar.noteState(before)
		host.say(string.format("Arena: %d units. %s (Ctrl+Z undoes it)", total, table.concat(lines, "; ")))
	end

	-- Clear: deletes the units that Generate placed (all of them) and the Arena Point; one undo step
	function ar.clear()
		if not host.canEdit() then
			return
		end
		local ids = {}
		for _, id in ipairs(Spring.GetAllUnits()) do
			if Spring.GetUnitRulesParam(id, "arena") == 1 then
				ids[#ids + 1] = "u" .. id
			end
		end
		local c = ar.cfg()
		if #ids == 0 and not c.point and #c.armies == 0 then
			host.say("Nothing to clear.")
			return
		end
		local before = ar.state()
		host.step()
		for i = 1, #ids, 100 do
			host.led("led|clearids|" .. table.concat(ids, ",", i, math.min(#ids, i + 99)))
		end
		local d = ar.cfg(true)
		d.point, d.armies = nil, {}
		ar.noteState(before)
		host.say(string.format("Arena cleared: %d units and the Arena Point (Ctrl+Z brings them back).", #ids))
	end

	-- Shift + Alt + drag of the Arena Point, on release: the point has moved by (dx, dz); every army's natural spot moves by that, its real spot
	-- is the natural spot pushed onto the map, and its units move with the real spot
	function ar.moveSetup(d)
		local c = ar.cfg(true)
		local p = c.point
		if not p then
			return
		end
		local dx, dz = p.x - d.x0, p.z - d.z0
		if dx == 0 and dz == 0 or #c.armies == 0 then
			ar.commit(d.before)
			return
		end
		local byTeam = {}
		for _, id in ipairs(Spring.GetAllUnits()) do
			if Spring.GetUnitRulesParam(id, "arena") == 1 then
				local t = Spring.GetUnitTeam(id)
				byTeam[t] = byTeam[t] or {}
				byTeam[t][#byTeam[t] + 1] = id
			end
		end
		host.step()
		for _, a in ipairs(c.armies) do
			a.nx, a.nz = a.nx + dx, a.nz + dz
			local ax, az = clampArmy(a.nx, a.nz, a.hw, a.hh)
			ax, az = math.floor(ax), math.floor(az)
			local mx, mz = ax - a.ax, az - a.az
			a.ax, a.az = ax, az
			local ids = byTeam[a.team]
			if ids and (mx ~= 0 or mz ~= 0) then
				for i = 1, #ids, 500 do
					host.led(string.format("led|move|%d|%d|%s", mx, mz, table.concat(ids, ",", i, math.min(#ids, i + 499))))
				end
			end
		end
		ar.noteState(d.before)
		host.say("Arena moved (Ctrl+Z undoes it).")
	end

	-- Markers in the world (also with the page closed): the Arena Point as a thick red circle, and with the page open a thin ring of the radius
	function ar.drawWorld()
		local c = ar.cfg()
		local p = c.point
		if not p then
			return
		end
		gl.DepthTest(false)
		local function circle(r, width, alpha)
			gl.LineWidth(width)
			gl.Color(1, 0.1, 0.1, alpha)
			gl.BeginEnd(GL.LINE_LOOP, function()
				for i = 0, 63 do
					local a = i / 64 * 2 * math.pi
					local x, z = p.x + math.cos(a) * r, p.z + math.sin(a) * r
					gl.Vertex(x, Spring.GetGroundHeight(x, z) + 8, z)
				end
			end)
		end
		circle(POINT_R, 7, 1)
		circle(POINT_R * 0.45, 7, 1)
		if ar.pointAt() then
			circle(POINT_R + 14, 2, 1)
		end
		if ar.open then
			circle(c.radius, 2, 0.55)
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
	end

	-- Cost of all units of every team on the map (for the remaining budget): worked out twice a second, not in every layout
	-- ---------------------------------------------------------------- the allow list of an army and its window
	-- The names an army may use are the list rows[i].allowed; a set of them is built once per list (a new list from a load rebuilds it)
	local sets = {}
	local function setOf(i)
		local list = ar.cfg().rows[i].allowed
		local s = sets[i]
		if not s or s.list ~= list then
			s = { list = list, set = {} }
			for _, n in ipairs(list) do
				s.set[n] = true
			end
			sets[i] = s
		end
		return s.set
	end

	function ar.isAllowed(i, name)
		return setOf(i)[name] == true
	end

	-- Allow or remove a list of unit names in army i
	function ar.setAllowed(i, names, on)
		local c = ar.cfg(true)
		local s = setOf(i)
		local list = c.rows[i].allowed
		for _, n in ipairs(names) do
			if on and not s[n] then
				s[n] = true
				list[#list + 1] = n
			elseif not on then
				s[n] = nil
			end
		end
		if not on then
			local out = {}
			for _, n in ipairs(list) do
				if s[n] then
					out[#out + 1] = n
				end
			end
			c.rows[i].allowed = out
			sets[i] = { list = out, set = s }
		end
	end

	-- The list of units next to the page (the Place menu: only the Units tab with its filters and search; check boxes instead of the red X)
	local function allBanned(names)
		if #names == 0 then
			return false
		end
		for _, n in ipairs(names) do
			if not ar.isAllowed(ar.winRow, n) then
				return false
			end
		end
		return true
	end
	ar.units = Shared.newUnits({
		cfg = host.cfg,
		ownText = host.ownText,
		noPreview = true,
		-- only what moves, and turrets (armed buildings): no factories, no economy, no walls
		filter = function(ud)
			return ud.canMove or (ud.weapons ~= nil and #ud.weapons > 0)
		end,
		restrict = {
			style = "allow", -- isBanned = allowed here: the box is a check box
			isBanned = function(name) return ar.isAllowed(ar.winRow, name) end,
			setBanned = function(names, on) ar.setAllowed(ar.winRow, names, on) end,
			allBanned = allBanned,
		},
	})
	ar.units.group = "bot"

	-- The unit window sits left of the team strip, from the top of the menu down
	function ar.winRect()
		if not ar.open or not ar.winRow then
			return nil
		end
		local S = host.S()
		local px1, _, _, py1 = host.panelRect()
		local vsx, vsy = Spring.GetViewGeometry()
		local right = px1 - Shared.m.HB - 8 * S - 70 * S -- the team strip and the numbers of units left of it
		local w = math.floor(560 * S)
		return { x1 = math.max(8 * S, right - w), x2 = right, top = py1, y0 = vsy * 0.06 }
	end

	function ar.winAt(mx, my)
		local w = ar.winRect()
		return w ~= nil and mx >= w.x1 and mx <= w.x2 and my >= w.y0 and my <= w.top
	end

	-- Buttons of the window, its list area and its labels
	local function winLayout()
		local w = ar.winRect()
		local S, m = host.S(), Shared.m
		local rects, labels = {}, {}
		local gap = 3 * S
		local x1, x2 = w.x1 + m.PAD, w.x2 - m.PAD
		local y = w.top - 44 * S
		labels[#labels + 1] = { text = "Copy the list of player:", x = x1, y = y - 18 * S, size = 19 * S }
		y = y - 24 * S
		local bw = (x2 - x1 - gap * (ROWS - 1)) / ROWS
		for j = 1, ROWS do
			local cr, cg, cb = Spring.GetTeamColor(j - 1)
			local bx = x1 + (j - 1) * (bw + gap)
			rects[#rects + 1] = { x1 = bx, x2 = bx + bw, y0 = y - m.HB, y1 = y, kind = "arcopyfrom", value = j, label = tostring(j), fs = 18 * S,
				tint = { (cr or 0.5) * 0.7, (cg or 0.5) * 0.7, (cb or 0.5) * 0.7 }, tip = "Copy the allowed units of player " .. j .. " into this army (they replace what is allowed here)" }
		end
		y = y - m.HB - 6 * S
		local half = (x2 - x1 - gap) / 2
		rects[#rects + 1] = { x1 = x1, x2 = x1 + half, y0 = y - m.HB, y1 = y, kind = "arclearlist", label = "Clear list", fs = 20 * S, tip = "Nothing is allowed in this army any more" }
		rects[#rects + 1] = { x1 = x1 + half + gap, x2 = x2, y0 = y - m.HB, y1 = y, kind = "arclose", label = "Close", fs = 20 * S, tip = "Close this list" }
		y = y - m.HB - 6 * S
		for _, r in ipairs(ar.units:filterRects(w.x1, w.x2, y, m.HB)) do
			rects[#rects + 1] = r
		end
		y = y - ar.units:filterRowCount() * (m.HB + 3) - 4 * S
		return rects, { x1 = w.x1, x2 = w.x2, top = y, y0 = w.y0 }, labels
	end

	function ar.drawWindow()
		local w = ar.winRect()
		if not w then
			return
		end
		local S = host.S()
		gl.Color(0.07, 0.07, 0.09, 0.94)
		gl.Rect(w.x1, w.y0, w.x2, w.top)
		local rects, listRect, labels = winLayout()
		local t = ar.winRow - 1
		local cr, cg, cb = Spring.GetTeamColor(t)
		gl.Color(cr or 1, cg or 1, cb or 1, 1)
		gl.Text("Army of team " .. t .. ": allowed units", w.x1 + 10 * S, w.top - 34 * S, 26 * S, "o")
		gl.Color(0.5, 0.8, 1, 1)
		for _, l in ipairs(labels) do
			gl.Text(l.text, l.x, l.y, l.size, "o")
		end
		Shared.drawButtons(rects, 20 * S, Shared.m.HB)
		local mx, my = Spring.GetMouseState()
		ar.units:draw(listRect, mx, my, nil, nil, ar.winAt(mx, my))
		-- the picture and the text under it are off in this window: a tooltip with name and cost instead
		local i = ar.winAt(mx, my) and ar.units:at(listRect, mx, my)
		local e = i and ar.units:list()[i]
		if e then
			local ud = UnitDefs[e.id]
			local text = string.format("%s (%s)\nMetal %d, Energy %d", tostring(ud.translatedHumanName or ud.humanName or e.name), e.name, ud.metalCost or 0, ud.energyCost or 0)
			Shared.tooltipBox(text, mx, my)
		else
			Shared.drawTip(rects, mx, my)
		end
		gl.Color(1, 1, 1, 1)
	end

	function ar.winWheel(up)
		local _, listRect = winLayout()
		ar.units:wheel(listRect, up)
	end

	function ar.winPress(mx, my, button)
		local rects, listRect = winLayout()
		if button ~= 1 then
			return true
		end
		local hit
		for _, r in ipairs(rects) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		if hit then
			local k = hit.kind
			if k == "arcopyfrom" then
				local c = ar.cfg(true)
				local from = c.rows[hit.value].allowed
				ar.setAllowed(ar.winRow, c.rows[ar.winRow].allowed, false)
				local names = {}
				for _, n in ipairs(from) do
					names[#names + 1] = n
				end
				ar.setAllowed(ar.winRow, names, true)
				ar.units:setFocus(false)
			elseif k == "arclearlist" then
				ar.setAllowed(ar.winRow, ar.cfg(true).rows[ar.winRow].allowed, false)
				ar.units:setFocus(false)
			elseif k == "arclose" then
				ar.units:setFocus(false)
				ar.winRow = nil
			else
				ar.units:applyFilter(hit) -- search field, faction, group, tech and their check boxes
			end
			return true
		end
		ar.units:setFocus(false)
		if mx >= listRect.x1 and mx <= listRect.x2 and my >= listRect.y0 and my <= listRect.top then
			local i = ar.units:at(listRect, mx, my)
			local e = i and ar.units:list()[i]
			if e then
				ar.setAllowed(ar.winRow, { e.name }, not ar.isAllowed(ar.winRow, e.name)) -- a click on the tile (also on its check box) allows or removes it
			end
		end
		return true
	end

	function ar.poll()
		pollState()
		local now = os.clock()
		if now - ar.spentAt < 0.5 then
			return
		end
		ar.spentAt = now
		local spent = {}
		for i = 1, ROWS do
			local t = i - 1
			local m, e = 0, 0
			if Spring.GetTeamInfo(t) then
				for _, u in ipairs(Spring.GetTeamUnits(t) or {}) do
					local ud = UnitDefs[Spring.GetUnitDefID(u)]
					if ud then
						m, e = m + (ud.metalCost or 0), e + (ud.energyCost or 0)
					end
				end
			end
			spent[i] = { m, e }
		end
		ar.spent = spent
	end

	local function short(n)
		if n == nil then
			return "-"
		end
		local a = math.abs(n)
		if a >= 1000000 then
			return string.format("%.1fM", n / 1000000)
		elseif a >= 10000 then
			return string.format("%.1fk", n / 1000)
		end
		return string.format("%d", n)
	end

	-- Value of a number field: name = "radius" | "bmetal" | "benergy" (the global ones) or "count" | "metal" | "energy" (of the row)
	local function getValue(c, name, row)
		if name == "radius" then
			return c.radius
		elseif name == "bmetal" then
			return c.budget.metal
		elseif name == "benergy" then
			return c.budget.energy
		end
		return c.rows[row][name]
	end

	local function setValue(c, name, row, v)
		if name == "radius" then
			c.radius = v or c.radius
		elseif name == "bmetal" then
			c.budget.metal = v
		elseif name == "benergy" then
			c.budget.energy = v
		else
			c.rows[row][name] = v
		end
	end

	-- The kind of limit a field has (bmetal / benergy use the limits of metal / energy)
	local function limitOf(name)
		return LIMITS[name] or LIMITS[name:sub(2)]
	end

	-- Buttons and labels of the page; returns rects, labels, height
	function ar.layout(rect)
		local S, m = host.S(), Shared.m
		local c = ar.cfg()
		local rects, labels = {}, {}
		local x1, x2 = rect.x1 + m.PAD, rect.x2 - m.PAD
		local y = rect.top - m.PAD
		local gap = 4 * S
		local function line(items, after)
			local total = 0
			for _, it in ipairs(items) do
				total = total + (it.w or 1)
			end
			local avail, bx = x2 - x1 - gap * (#items - 1), x1
			for _, it in ipairs(items) do
				local w = avail * (it.w or 1) / total
				rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = it.kind, value = it.value, label = it.label, active = it.active,
					fs = it.fs or 22 * S, field = it.field, row = it.row, tint = it.tint, tip = it.tip }
				bx = bx + w + gap
			end
			y = y - m.HB - (after or 6 * S)
		end
		local function head(text)
			labels[#labels + 1] = { text = text, x = x1, y = y - 26 * S, size = 22 * S, head = true }
			y = y - 32 * S
		end
		local function note(text, color)
			labels[#labels + 1] = { text = text, x = x1, y = y - 18 * S, size = 19 * S, color = color }
			y = y - 24 * S
		end
		local function field(name, row, tip)
			local e = ar.edit
			local editing = e ~= nil and e.field == name and e.row == row
			local v = getValue(c, name, row)
			return { kind = "arfield", field = name, row = row, label = editing and (e.buf .. "_") or (v ~= nil and tostring(v) or "-"), active = editing, tip = tip }
		end
		head("Radius (Elmo): distance of every army from the Arena Point")
		line({ field("radius", nil, "Distance of every army from the Arena Point (a radius, not a diameter). Click, type a number, Enter accepts"),
			{ kind = "arhdr", label = "", w = 2 } })
		head("Budget for all rows (empty = no limit)")
		line({
			field("bmetal", nil, "Metal budget for all rows. Empty = no limit. Click, type a number, Enter accepts; 'Copy to table' writes it into every row"),
			field("benergy", nil, "Energy budget for all rows. Empty = no limit. Click, type a number, Enter accepts; 'Copy to table' writes it into every row"),
			{ kind = "arcopy", label = "Copy to table", w = 1.4, tip = "Writes Metal and Energy of this line into every row (also the rows that are off); the values of a row stay editable" },
		})
		y = y - 4 * S
		-- table: team, on / off, units, count, metal, energy, remaining budget
		local W = { 1, 1.5, 2.4, 1.7, 2.1, 2.1, 3.2 }
		local function tline(items, after)
			for i, it in ipairs(items) do
				it.w = W[i]
			end
			line(items, after)
		end
		local hdr = { 0.12, 0.12, 0.12 }
		tline({ { kind = "arhdr", label = "Team", tint = hdr, fs = 18 * S }, { kind = "arhdr", label = "On", tint = hdr, fs = 18 * S },
			{ kind = "arhdr", label = "Units", tint = hdr, fs = 18 * S }, { kind = "arhdr", label = "Count", tint = hdr, fs = 18 * S },
			{ kind = "arhdr", label = "Metal", tint = hdr, fs = 18 * S }, { kind = "arhdr", label = "Energy", tint = hdr, fs = 18 * S },
			{ kind = "arhdr", label = "Left (metal / energy)", tint = hdr, fs = 18 * S } }, 3 * S)
		for i = 1, ROWS do
			local t = i - 1
			local r = c.rows[i]
			if Spring.GetTeamInfo(t) then
				local cr, cg, cb = Spring.GetTeamColor(t)
				local n = #r.allowed
				local spent = ar.spent[i] or { 0, 0 }
				local lm = r.metal and (r.metal - spent[1]) or nil
				local le = r.energy and (r.energy - spent[2]) or nil
				local left = (lm or le) and (short(lm) .. " / " .. short(le)) or "-"
				tline({
					{ kind = "arhdr", label = tostring(t), tint = { cr or 0.5, cg or 0.5, cb or 0.5 }, tip = "Team " .. t .. " (the number of the team button at the left)" },
					{ kind = "aron", row = i, label = r.on and "On" or "Off", tint = r.on and { 0.15, 0.6, 0.2 } or nil,
						tip = "On: this team gets an army when you press Generate, and its units fight at Start. Off: nothing is generated and its units stand still" },
					{ kind = "arunits", row = i, label = "Units " .. n, tint = n > 0 and { 0.15, 0.6, 0.2 } or nil,
						tip = "The units of this army: opens the list of units next to this page; a green check at a unit allows it. Green with the number of allowed unit types, gray when there are none" },
					field("count", i, "How many units each Generate adds to this army (empty = no limit by count; then the budget decides). At most " .. MAX_UNITS .. " units of a team stand on the map. Click, type a number, Enter accepts"),
					field("metal", i, "Metal budget of this army (empty = no limit). Click, type a number, Enter accepts"),
					field("energy", i, "Energy budget of this army (empty = no limit). Click, type a number, Enter accepts"),
					{ kind = "arhdr", label = left, tip = "What is left of the budget: budget minus the cost of all units of this team on the map (also the ones placed by hand), it can be negative" },
				}, 3 * S)
			else
				tline({ { kind = "arhdr", label = tostring(t), tint = { 0.1, 0.1, 0.1 }, tip = "The game has no team " .. t }, { kind = "arhdr", label = "-", tint = { 0.1, 0.1, 0.1 } },
					{ kind = "arhdr", label = "-", tint = { 0.1, 0.1, 0.1 } }, { kind = "arhdr", label = "-", tint = { 0.1, 0.1, 0.1 } },
					{ kind = "arhdr", label = "-", tint = { 0.1, 0.1, 0.1 } }, { kind = "arhdr", label = "-", tint = { 0.1, 0.1, 0.1 } },
					{ kind = "arhdr", label = "-", tint = { 0.1, 0.1, 0.1 } } }, 3 * S)
			end
		end
		y = y - 6 * S
		if ar.notice and os.clock() < ar.notice.untilT then
			note(ar.notice.text, { 1, 0.4, 0.35 })
		end
		y = y - 4 * S
		local state = Spring.GetGameRulesParam("arenaState") or ""
		local running = state == "running"
		line({
			{ kind = "arpoint", label = "Arena Point", w = 4, active = ar.pick == "point",
				tip = "Arena Point: click, then click the map. The point where all armies meet. Alt + drag moves it, Shift + Alt + drag moves the whole setup, Del over it removes it" },
			{ kind = "arpointx", label = "X", w = 1, tip = "Delete the Arena Point" },
			{ kind = "argen", label = "Generate", w = 3, active = ar.pick == "gen",
				tip = "Generate: click on the map. The Arena Point is set there and every army of a row that is on stands around it. Ctrl+Z undoes it" },
			{ kind = "arclear", label = "Clear", w = 3, tip = "Removes the units that Generate placed, and the Arena Point. Units you placed yourself stay. Ctrl+Z undoes it" },
		})
		line({ { kind = "arplay", label = running and "Stop" or "Start", active = running, fs = 26 * S, tint = running and { 0.8, 0.15, 0.15 } or { 0.15, 0.6, 0.2 },
			tip = "Start: all units of the rows that are on fight their way to the Arena Point. The state before is saved as _beforeplay. Stop brings it back." } })
		y = y - m.PAD
		return rects, labels, rect.top - y
	end

	function ar.height()
		local _, _, h = ar.layout({ x1 = 0, x2 = math.floor(780 * host.S()), top = 0 })
		return h
	end

	function ar.draw(rect)
		local S = host.S()
		local rects, labels = ar.layout(rect)
		Shared.drawButtons(rects, 22 * S, Shared.m.HB)
		for _, l in ipairs(labels) do
			if l.color then
				gl.Color(l.color[1], l.color[2], l.color[3], 1)
			else
				gl.Color(0.5, 0.8, 1, 1)
			end
			gl.Text(l.text, l.x, l.y, l.size, "o")
		end
		gl.Color(1, 1, 1, 1)
		local mx, my = Spring.GetMouseState()
		if ar.winRect() and ar.winAt(mx, my) then
			mx, my = -1, -1 -- the mouse is over the unit window: no tooltip of the page below it
		end
		Shared.drawTip(rects, mx, my)
		ar.drawWindow()
	end

	-- Ends the entry in a number field (accept: take the value; empty = no limit, except the radius)
	function ar.finish(accept)
		local e = ar.edit
		if not e then
			return
		end
		ar.edit = nil
		widgetHandler:DisownText()
		if not accept then
			return
		end
		local c = ar.cfg(true)
		local v = tonumber(e.buf)
		if v == nil or v == 0 and e.field ~= "radius" then
			setValue(c, e.field, e.row, nil)
		else
			local lim = limitOf(e.field)
			setValue(c, e.field, e.row, math.max(lim[1], math.min(lim[2], math.floor(v))))
		end
	end

	function ar.key(key)
		if key == 13 or key == 271 then
			ar.finish(true)
		elseif key == 27 then
			ar.finish(false)
		elseif key == 8 then
			ar.edit.buf = ar.edit.buf:sub(1, -2)
		end
		return true
	end

	function ar.text(ch)
		if ch and ch:match("^%d$") and #ar.edit.buf < 8 then
			ar.edit.buf = ar.edit.buf .. ch
		end
		return true
	end

	function ar.press(rect, mx, my)
		local hit
		for _, r in ipairs((ar.layout(rect))) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		ar.finish(true)
		if not hit then
			return true
		end
		local k = hit.kind
		if k == "arfield" then
			ar.edit = { field = hit.field, row = hit.row, buf = "" }
			widgetHandler:OwnText()
		elseif k == "aron" then
			local r = ar.cfg(true).rows[hit.row]
			r.on = not r.on
		elseif k == "arcopy" then
			local c = ar.cfg(true)
			for i = 1, ROWS do
				c.rows[i].metal, c.rows[i].energy = c.budget.metal, c.budget.energy
			end
		elseif k == "arpoint" then
			ar.startPick("point")
		elseif k == "arpointx" then
			ar.deletePoint()
		elseif k == "arunits" then
			ar.winRow = (ar.winRow ~= hit.row) and hit.row or nil -- the same Units button again closes the window
			ar.units:setFocus(false)
		elseif k == "argen" then
			ar.startPick("gen")
		elseif k == "arclear" then
			ar.clear()
		elseif k == "arplay" then
			host.say("Arena: this button does not work yet.")
		end
		return true
	end

	return ar
end
