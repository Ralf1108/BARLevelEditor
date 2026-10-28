-- The Tower Defense page of the Level Editor (button TD): waves of enemies walk from the spawn point along a path to the goal; the walls of the
-- path are built here, the waves themselves by the gadget td_waves.lua. The settings (td.data) are saved in their own section towerdefense of the
-- level file. Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_td.lua")) as a function that gets the table td of the widget (its
-- state fields: open, edit, pick, mode, pts, stroke, wall, scroll, data) and the host H with the services of the widget: H.<value>() for values
-- that change (S, team, grid, armedUnit ...), H.<name> for its functions and tables, H.armUnit, H.disarmModes and H.restoreBeforePlay for what
-- changes the state of the widget. A file of its own because the widget is close to the limit of 200 local variables.
return function(td, H)
	td.FAC = { "arm", "cor", "leg" }
	td.FAC_TXT = { arm = "Armada", cor = "Cortex", leg = "Legion" }
	td.MAX_WAVES = 30
	td.VISIBLE = 8 -- rows of the wave table shown at once (mouse wheel scrolls)
	td.tfac, td.ttech = "arm", 1 -- tower list of the page: faction and tech level shown
	td.tcat = "tower" -- category of the list: tower | economy | radar
	td.tscroll, td.TROWS = 0, 4 -- first row shown, rows shown at most (mouse wheel scrolls)
	td.GOAL_RADIUS = 120 -- as in td_waves.lua: an enemy this close to the goal got through
	function td.new()
		return { enabled = false, width = 8, leaks = 10, economy = true, fog = true, waypoints = {}, waves = { { fac = "arm", kind = "vb", tech = "1", count = 10, gap = 0, hp = 100 } } }
	end
	td.DEFAULT = td.new()

	-- Settings (td.data = section towerdefense of the level): without write the stored ones or the defaults (never
	-- changed by the caller); with write they are created
	function td.cfg(write)
		if type(td.data) == "table" then
			return td.data
		end
		if not write then
			return td.DEFAULT
		end
		td.data = td.new()
		return td.data
	end

	-- Lua text of a table of numbers, strings and booleans (arrays and records), for the level file
	function td.lua(v, indent)
		local kind = type(v)
		if kind == "number" then
			return v == math.floor(v) and string.format("%d", v) or tostring(v)
		elseif kind == "boolean" then
			return tostring(v)
		elseif kind == "string" then
			return string.format("%q", v)
		elseif kind ~= "table" then
			return "nil"
		end
		local inner = indent .. "\t"
		local parts = {}
		if next(v) == nil or v[1] ~= nil then
			local flat = true
			for _, e in ipairs(v) do
				if type(e) == "table" then
					flat = false
				end
			end
			for _, e in ipairs(v) do
				parts[#parts + 1] = td.lua(e, inner)
			end
			if flat then
				return "{ " .. table.concat(parts, ", ") .. (#parts > 0 and " }" or "}")
			end
			return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. ",\n" .. indent .. "}"
		end
		local keys = {}
		for k in pairs(v) do
			keys[#keys + 1] = tostring(k)
		end
		table.sort(keys)
		for _, k in ipairs(keys) do
			parts[#parts + 1] = k .. " = " .. td.lua(v[k], inner)
		end
		return "{\n" .. inner .. table.concat(parts, ",\n" .. inner) .. ",\n" .. indent .. "}"
	end

	function td.height()
		local _, _, h = td.layout({ x1 = 0, x2 = math.floor(780 * H.S()), top = 0 })
		return h
	end

	function td.resize(n)
		local c = td.cfg(true)
		n = math.max(1, math.min(td.MAX_WAVES, n))
		while #c.waves < n do
			local last = c.waves[#c.waves]
			c.waves[#c.waves + 1] = { fac = td.chosen(last, "fac"), kind = td.chosen(last, "kind"), tech = td.chosen(last, "tech"), count = last.count, gap = math.max(last.gap, 10), hp = last.hp }
		end
		while #c.waves > n do
			c.waves[#c.waves] = nil
		end
		td.scroll = math.max(0, math.min(td.scroll, #c.waves - td.VISIBLE))
	end

	-- Selection of a wave row as short strings: fac "armcor", tech "12", kind "vb" (v = vehicles, b = bots, h = hovercraft).
	td.CHOICES = {
		fac = { "arm", "cor", "leg" },
		tech = { "1", "2", "3" },
		kind = { "v", "b", "h" },
	}
	function td.chosen(w, field)
		local s = tostring(w[field] or "")
		if s == "" then
			s = field == "fac" and "arm" or (field == "kind" and "vb" or "1")
		end
		local out = {}
		for _, v in ipairs(td.CHOICES[field]) do
			if s:find(v, 1, true) then
				out[#out + 1] = v
			end
		end
		if #out == 0 then
			out[1] = td.CHOICES[field][1]
		end
		return table.concat(out)
	end

	-- Toggles one choice; at least one stays on
	function td.toggleChoice(w, field, v)
		local cur = td.chosen(w, field)
		local on = cur:find(v, 1, true) ~= nil
		if on and #cur == #v then
			return
		end
		local out = {}
		for _, c in ipairs(td.CHOICES[field]) do
			if (c == v) ~= (cur:find(c, 1, true) ~= nil) then
				out[#out + 1] = c
			end
		end
		w[field] = table.concat(out)
	end

	-- Categories of the list: Towers, with "Towers + economy" also Economy, with fog of war also Radars
	function td.cats()
		local c = td.cfg()
		local out = { { "tower", "Towers" } }
		if c.economy ~= false then
			out[#out + 1] = { "economy", "Economy" }
		end
		if c.fog ~= false then
			out[#out + 1] = { "radar", "Radars" }
		end
		local ok = false
		for _, e in ipairs(out) do
			ok = ok or e[1] == td.tcat
		end
		if not ok then
			td.tcat = "tower"
		end
		return out
	end

	-- Structures of the page for a faction, tech level and category (land only)
	function td.turrets(fac, tech, cat)
		if not td.tcache then
			local cache = H.Shared.buildUnitCache()
			td.tcache = {}
			for _, f in ipairs(td.FAC) do
				td.tcache[f] = { {}, {}, {} }
				for t = 1, 3 do
					local buckets = { tower = {}, economy = {}, radar = {} }
					for _, e in ipairs(cache[f].buildings[t]) do
						local cls = e.rank < 100 and H.Shared.buildClass(UnitDefs[e.id])
						if cls then
							buckets[cls][#buckets[cls] + 1] = { name = e.name, id = e.id, class = cls }
						end
					end
					for _, cls in ipairs({ "tower", "economy", "radar" }) do
						for _, e in ipairs(buckets[cls]) do
							local list = td.tcache[f][t]
							list[#list + 1] = e
						end
					end
				end
			end
		end
		local out = {}
		for _, e in ipairs(td.tcache[fac][tech]) do
			if e.class == cat then
				out[#out + 1] = e
			end
		end
		return out
	end

	-- Route state as text for the undo history: "sx,sz;gx,gz;x,z/x,z" ("-" for nothing)
	function td.routeState()
		local c = td.cfg()
		local function pt(p)
			return p and string.format("%d,%d", p[1], p[2]) or "-"
		end
		local w = {}
		for _, p in ipairs(c.waypoints or {}) do
			w[#w + 1] = pt(p)
		end
		return pt(c.spawn) .. ";" .. pt(c.goal) .. ";" .. (#w > 0 and table.concat(w, "/") or "-")
	end

	function td.applyRoute(state)
		local c = td.cfg(true)
		local function pt(s)
			local x, z = tostring(s):match("^(-?%d+),(-?%d+)$")
			return x and { tonumber(x), tonumber(z) } or nil
		end
		local sp, gl_, wp = state:match("^([^;]*);([^;]*);(.*)$")
		c.spawn, c.goal, c.waypoints = pt(sp), pt(gl_), {}
		for s in tostring(wp):gmatch("[^/]+") do
			c.waypoints[#c.waypoints + 1] = pt(s)
		end
	end

	-- Notes a change of the route as a step of the undo history (before = td.routeState() from before the change)
	function td.commit(before)
		local after = td.routeState()
		if after ~= before then
			H.ledStep()
			H.led("led|tdroute|" .. before .. "|" .. after)
		end
	end

	-- Undo / redo from the gadget: take over the new state
	function td.pollRoute()
		local n = Spring.GetGameRulesParam("led_tdroute_n")
		if td.routeSeen == nil then
			td.routeSeen = n or 0
		elseif n and n ~= td.routeSeen then
			td.routeSeen = n
			td.applyRoute(Spring.GetGameRulesParam("led_tdroute") or "-;-;-")
		end
	end

	-- A new waypoint (x, z) goes into the route: onto a drawn line between two points of it (spawn point, waypoints, goal) it is
	-- inserted there, otherwise behind the nearest point of the route (spawn point or waypoint)
	function td.addWaypoint(x, z)
		local c = td.cfg(true)
		c.waypoints = c.waypoints or {}
		local wps = c.waypoints
		local pts = {} -- { x, z, index in wps (spawn point 0, goal behind the last one) }
		if c.spawn then
			pts[#pts + 1] = { c.spawn[1], c.spawn[2], 0 }
		end
		for i, p in ipairs(wps) do
			pts[#pts + 1] = { p[1], p[2], i }
		end
		if c.goal then
			pts[#pts + 1] = { c.goal[1], c.goal[2], #wps + 1 }
		end
		local at, bestD = nil, 48 ^ 2 -- on the line: within 48 Elmo
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local dx, dz = b[1] - a[1], b[2] - a[2]
			local len2 = dx * dx + dz * dz
			if len2 > 0 then
				local u = ((x - a[1]) * dx + (z - a[2]) * dz) / len2
				if u > 0 and u < 1 then
					local d = (x - a[1] - dx * u) ^ 2 + (z - a[2] - dz * u) ^ 2
					if d < bestD then
						at, bestD = a[3] + 1, d
					end
				end
			end
		end
		if not at then
			local nd = 1e18
			at = #wps + 1
			for _, q in ipairs(pts) do
				if q[3] <= #wps then
					local d = (x - q[1]) ^ 2 + (z - q[2]) ^ 2
					if d < nd then
						nd, at = d, q[3] + 1
					end
				end
			end
		end
		table.insert(wps, at, { math.floor(x), math.floor(z) })
		return #wps
	end

	-- Route of the enemies between spawn point and goal: the waypoints in their order
	function td.route()
		return td.cfg().waypoints or {}
	end

	-- Index of the waypoint under the mouse pointer (or nil)
	function td.waypointAt()
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		if not pos then
			return nil
		end
		local best, bd = nil, 64 ^ 2
		for i, p in ipairs(td.cfg().waypoints or {}) do
			local d = (p[1] - pos[1]) ^ 2 + (p[2] - pos[3]) ^ 2
			if d < bd then
				best, bd = i, d
			end
		end
		return best
	end

	-- What Alt + drag grabs under the mouse pointer: the index of a waypoint, "spawn" or "goal" (or nil)
	function td.dragAt()
		local i = td.waypointAt()
		if i then
			return i
		end
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		local c = td.cfg()
		if pos then
			for _, k in ipairs({ "spawn", "goal" }) do
				local p, r = c[k], k == "spawn" and 64 or td.GOAL_RADIUS
				if p and (p[1] - pos[1]) ^ 2 + (p[2] - pos[3]) ^ 2 <= r ^ 2 then
					return k
				end
			end
		end
		return nil
	end

	-- Del over a waypoint removes it; true when there was one
	function td.deleteWaypoint()
		local i = td.open and td.waypointAt()
		if not i then
			return false
		end
		local before = td.routeState()
		table.remove(td.cfg(true).waypoints, i)
		td.commit(before)
		H.say("Waypoint removed")
		return true
	end

	-- Arms placing a tower (or other structure) of the page: like a click in the unit list of the Place tab
	function td.armUnit(name)
		td.endPick()
		H.armUnit(name) -- the other modes end, the unit stamp of the Place menu is armed with it
		H.say("Unit: " .. name .. ". Left click on the map places, right click ends.")
	end

	-- The restrictions are one list for the whole level (led_restrictions.lua): the Tower Defense page and the Place menu write the same one
	function td.techBanned(t) -- every unit of the tech level is forbidden (the tech button X of the Place menu does the same)
		return H.rst.allBanned(H.uGrid:namesOf("tech", t))
	end

	function td.isBanned(name)
		return H.rst.isBanned(name)
	end

	function td.layout(rect)
		local m = H.Shared.m
		local c = td.cfg()
		local rects, labels = {}, {}
		local x1, x2 = rect.x1 + m.PAD, rect.x2 - m.PAD
		local y = rect.top - m.PAD
		local gap = 4 * H.S()
		local function line(items)
			local total = 0
			for _, it in ipairs(items) do
				total = total + (it.w or 1)
			end
			local avail, bx = x2 - x1 - gap * (#items - 1), x1
			for _, it in ipairs(items) do
				local w = avail * (it.w or 1) / total
				rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = it.kind, value = it.value, label = it.label, active = it.active,
					fs = it.fs or 22 * H.S(), row = it.row, field = it.field, tint = it.tint, icon = it.icon, tip = it.tip }
				bx = bx + w + gap
			end
			y = y - m.HB - 6 * H.S()
		end
		local function head(text)
			labels[#labels + 1] = { text = text, x = x1, y = y - 26 * H.S(), size = 22 * H.S(), head = true }
			y = y - 32 * H.S()
		end
		local function editing(field, row)
			return td.edit ~= nil and td.edit.field == field and td.edit.row == row
		end
		local function num(field, row, value)
			return editing(field, row) and (td.edit.buf .. "_") or tostring(value)
		end
		line({ { kind = "tdon", label = (c.enabled and "[x] " or "[ ] ") .. "Tower Defense", active = c.enabled, tint = c.enabled and { 0.15, 0.6, 0.2 } or nil,
			tip = "Switch Tower Defense on or off for this level (saved in the level file, section towerdefense)" } })
		-- Walls: material and single pieces; Corridor: walls on both sides of a line (Line, Free) and its width; Route: spawn point, waypoints, goal
		head("Walls")
		line({
			{ kind = "tdmat", value = 1, label = "Teeth", active = td.wall == 1, tip = "Corridor of dragon teeth" },
			{ kind = "tdmat", value = 2, label = "Walls", active = td.wall == 2, tip = "Corridor of walls" },
		})
		line({
			{ kind = "tddraw", field = "corridor", value = "single", label = "Single", active = td.pick == "corridor" and td.mode == "single",
				tip = "Place single wall pieces (indestructible): every click on the map places one piece of the chosen material; hold the mouse button and move it to place a piece in every grid cell. The mode stays on, right click ends it. Ctrl+Z undoes the last click or stroke." },
		})
		head("Corridor (walls on both sides)")
		line({
			{ kind = "tddraw", field = "corridor", value = "line", label = "Line", active = td.pick == "corridor" and td.mode == "line",
				tip = "Build a corridor: click the points on the map, right click builds the walls (indestructible). The mode stays on for the next corridor, right click again ends it. Ctrl+Z undoes it." },
			{ kind = "tddraw", field = "corridor", value = "free", label = "Free", active = td.pick == "corridor" and td.mode == "free",
				tip = "Build a corridor: hold the left mouse button and draw any line, the walls appear when you let go (indestructible). The mode stays on, right click ends it." },
		})
		head("Corridor width (Elmo)")
		local widths = {}
		for _, t in ipairs({ 2, 4, 8, 10, 12 }) do
			widths[#widths + 1] = { kind = "tdwidth", value = t, label = tostring(t * 16), active = c.width == t,
				tip = "Width of the corridor in Elmo (the free space between the walls)" }
		end
		line(widths)
		head("Route (spawn point, waypoints, goal)")
		line({
			{ kind = "tdspawn", label = "Spawn", active = td.pick == "spawn", w = 4,
				tip = "Spawn point of the enemies: click, then click the place on the map" },
			{ kind = "tdspawnx", label = "X", tip = "Delete the spawn point", w = 1 },
			{ kind = "tdwaypoint", label = "Waypoint", active = td.pick == "waypoint", w = 4,
				tip = "Place waypoints: every click on the map adds one (right click ends).\nMove a waypoint: Alt + hold the left mouse button over it and drag.\nRemove one: mouse over it, press Del." },
			{ kind = "tdwaypointx", label = "X", tip = "Delete ALL waypoints.\nA single waypoint: move the mouse over it on the map and press Del.", w = 1 },
			{ kind = "tdgoal", label = "Goal", active = td.pick == "goal", w = 4,
				tip = "Goal: click, then click the place on the map. Enemies that get within 120 Elmo of it are through." },
			{ kind = "tdgoalx", label = "X", tip = "Delete the goal", w = 1 },
		})
		head("Enemies allowed through (more = you lose)")
		line({
			{ kind = "tdminus", value = "leaks", label = "-", tip = "One less enemy allowed through" },
			{ kind = "tdedit", field = "leaks", label = num("leaks", nil, c.leaks), active = editing("leaks"), w = 2,
				tip = "How many enemies may reach the goal before you lose. Click, type a number, Enter accepts" },
			{ kind = "tdplus", value = "leaks", label = "+", tip = "One more enemy allowed through" },
		})
		y = y - 4 * H.S()
		labels[#labels + 1] = { line = true, x1 = x1, x2 = x2, y = y }
		y = y - 10 * H.S()
		head("Waves")
		line({
			{ kind = "tdminus", value = "nwaves", label = "-", tip = "One wave less (the last one is removed)" },
			{ kind = "tdedit", field = "nwaves", label = num("nwaves", nil, #c.waves), active = editing("nwaves"), w = 2,
				tip = "Number of waves. Click, type a number, Enter accepts" },
			{ kind = "tdplus", value = "nwaves", label = "+", tip = "One wave more (a copy of the last one)" },
		})
		-- Table: one row per wave: number, factions, tech levels, types, count, gap, health
		local W = { 0.5, 0.6, 0.6, 0.6, 0.6, 0.6, 0.6, 0.55, 0.55, 0.55, 0.9, 0.9, 0.9 }
		local total = 0
		for _, w in ipairs(W) do
			total = total + w
		end
		local avail, cx = x2 - x1 - gap * (#W - 1), {}
		local acc = 0
		for i, w in ipairs(W) do
			cx[i] = x1 + acc / total * avail + gap * (i - 1)
			acc = acc + w
		end
		for _, h in ipairs({ { 1, "#" }, { 2, "Faction" }, { 5, "Tech" }, { 8, "Type" }, { 11, "Count" }, { 12, "Gap s" }, { 13, "HP %" } }) do
			labels[#labels + 1] = { text = h[2], x = cx[h[1]] + 3 * H.S(), y = y - 20 * H.S(), size = 18 * H.S(), head = true }
		end
		y = y - 26 * H.S()
		local TYPE_TIP = { v = "V: vehicles (tanks)", b = "B: bots", h = "H: hovercraft" }
		for k, v in pairs(TYPE_TIP) do
			TYPE_TIP[k] = v .. " (several can be on at once, one always stays on)"
		end
		local last = math.min(#c.waves, td.scroll + td.VISIBLE)
		for i = td.scroll + 1, last do
			local w = c.waves[i]
			local items = { { kind = "tdnone", label = tostring(i), w = W[1], tint = { 0.15, 0.3, 0.5 }, tip = "Wave " .. i } }
			local facs, techs, kinds = td.chosen(w, "fac"), td.chosen(w, "tech"), td.chosen(w, "kind")
			for k, f in ipairs(td.CHOICES.fac) do
				items[#items + 1] = { kind = "tdtog", row = i, field = "fac", value = f, label = "", icon = H.Shared.FACTION_ICONS[f], active = facs:find(f, 1, true) ~= nil,
					w = W[1 + k], tip = td.FAC_TXT[f] .. " (several can be on at once, one always stays on)" }
			end
			for k, t in ipairs(td.CHOICES.tech) do
				items[#items + 1] = { kind = "tdtog", row = i, field = "tech", value = t, label = "T" .. t, active = techs:find(t, 1, true) ~= nil, w = W[4 + k], fs = 18 * H.S(),
				tip = "T" .. t .. ": tech level " .. t .. " units (several can be on at once, one always stays on)" }
			end
			for k, v in ipairs(td.CHOICES.kind) do
				items[#items + 1] = { kind = "tdtog", row = i, field = "kind", value = v, label = v:upper(), active = kinds:find(v, 1, true) ~= nil, w = W[7 + k], tip = TYPE_TIP[v] }
			end
			items[#items + 1] = { kind = "tdcell", row = i, field = "count", label = num("count", i, w.count), active = editing("count", i), w = W[11], tip = "Number of enemies in this wave. Click, type a number, Enter accepts" }
			items[#items + 1] = { kind = "tdcell", row = i, field = "gap", label = num("gap", i, w.gap), active = editing("gap", i), w = W[12], tip = "Gap: seconds after the previous wave (wave 1: after the start). 0 = at once. Click, type a number, Enter accepts" }
			items[#items + 1] = { kind = "tdcell", row = i, field = "hp", label = num("hp", i, w.hp), active = editing("hp", i), w = W[13], tip = "Strength of the enemies in percent: 100 = normal, 200 = double health" }
			line(items)
		end
		if #c.waves > td.VISIBLE then
			labels[#labels + 1] = { text = string.format("Waves %d-%d of %d (mouse wheel scrolls)", td.scroll + 1, last, #c.waves), x = x1, y = y - 18 * H.S(), size = 17 * H.S() }
			y = y - 24 * H.S()
		end
		y = y - 6 * H.S()
		labels[#labels + 1] = { line = true, x1 = x1, x2 = x2, y = y }
		y = y - 10 * H.S()
		head("Restrictions")
		local economy, fog = c.economy ~= false, c.fog ~= false
		line({
			{ kind = "tdeconomy", label = (economy and "[x] " or "[ ] ") .. "Economy", active = economy,
				tip = "On: the player can also build economy structures (metal extractors, solar, wind and other power plants, storage, converters); the list below shows them too, so you can forbid single ones. Off: towers only. Towers can always be built." },
			{ kind = "tdfog", label = (fog and "[x] " or "[ ] ") .. "Fog of war", active = fog,
				tip = "On: fog of war in the game, the player can build radars (they are in the list below). Off: no radars, the whole map is visible. The editor always shows the whole map." },
		})
		local facs = {}
		for _, f in ipairs(td.FAC) do
			facs[#facs + 1] = { kind = "tdfac", value = f, label = td.FAC_TXT[f], icon = H.Shared.FACTION_ICONS[f], active = td.tfac == f,
				tip = "Show the towers of " .. td.FAC_TXT[f] }
		end
		line(facs)
		local cats = {}
		for _, ct in ipairs(td.cats()) do
			cats[#cats + 1] = { kind = "tdcat", value = ct[1], label = ct[2], active = td.tcat == ct[1], tip = "Show the " .. ct[2]:lower() .. " of the list" }
		end
		line(cats)
		local techs = {}
		for t = 1, 3 do
			if #td.turrets(td.tfac, t, td.tcat) > 0 then
				techs[#techs + 1] = { kind = "tdtech", value = t, label = "T" .. t, active = td.ttech == t, tip = "Show the tech level " .. t .. " towers" }
			end
		end
		if #techs > 0 and #td.turrets(td.tfac, td.ttech, td.tcat) == 0 then
			td.ttech = techs[1].value
		end
		line(techs)
		local base = #rects - #techs
		for i = 1, #techs do
			local rt = rects[base + i]
			local xs = (rt.y1 - rt.y0) * 0.7
			local tb = td.techBanned(rt.value)
			if tb then
				rt.tint = { 0.4, 0.12, 0.12 }
			end
			rects[#rects + 1] = { x1 = rt.x2 - xs - 4 * H.S(), x2 = rt.x2 - 4 * H.S(), y0 = (rt.y0 + rt.y1) / 2 - xs / 2, y1 = (rt.y0 + rt.y1) / 2 + xs / 2, kind = "tdtechx",
				value = rt.value, label = "", banned = tb,
				tip = tb and ("Tech level " .. rt.value .. " is forbidden: no unit of it can be built in the game. Click to allow it again.") or
					("Click: the player can build no unit of tech level " .. rt.value .. " in the game (all factions).") }
		end
		local list = td.turrets(td.tfac, td.ttech, td.tcat)
		local cols, gapT = 8, 4 * H.S()
		local tw = (x2 - x1 - gapT * (cols - 1)) / cols
		local rows = math.ceil(#list / cols)
		local shown = math.min(rows, td.TROWS)
		td.tscroll = math.max(0, math.min(td.tscroll, rows - shown))
		for i = td.tscroll * cols + 1, math.min(#list, (td.tscroll + shown) * cols) do
			local e = list[i]
			local col, row = (i - 1) % cols, math.floor((i - 1) / cols) - td.tscroll
			local tx, ty = x1 + col * (tw + gapT), y - row * (tw + gapT)
			local banned = td.isBanned(e.name)
			rects[#rects + 1] = { x1 = tx, x2 = tx + tw, y0 = ty - tw, y1 = ty, kind = "tdtile", value = e.name, id = e.id, label = "",
				banned = banned, armed = H.armedUnit() and H.unitName() == e.name }
			local xs = tw * 0.36
			rects[#rects + 1] = { x1 = tx + tw - xs, x2 = tx + tw, y0 = ty - xs, y1 = ty, kind = "tdban", value = e.name, id = e.id, label = "", banned = banned,
				tip = banned and "Forbidden: the player cannot build this in the game. Click to allow it again." or
					"Click: the player cannot build this in the game (in the editor you can always place it)." }
		end
		y = y - shown * (tw + gapT) - 8 * H.S()
		if rows > shown then
			labels[#labels + 1] = { text = string.format("Rows %d-%d of %d (mouse wheel scrolls)", td.tscroll + 1, td.tscroll + shown, rows), x = x1, y = y - 14 * H.S(), size = 17 * H.S() }
			y = y - 22 * H.S()
		end
		y = y - 4 * H.S()
		-- very bottom: the button that starts the test (red message above it: what is missing)
		local state = Spring.GetGameRulesParam("tdState") or ""
		local running = state == "running"
		if td.notice and os.clock() < td.notice.untilT then
			labels[#labels + 1] = { text = td.notice.text, x = x1, y = y - 20 * H.S(), size = 19 * H.S(), color = { 1, 0.4, 0.35 } }
		end
		y = y - 26 * H.S()
		line({ { kind = "tdplay", label = running and "Stop" or (state ~= "" and "Reset" or "Start test"), active = running, fs = 26 * H.S(),
			tint = running and { 0.8, 0.15, 0.15 } or { 0.15, 0.6, 0.2 }, -- red while running, green otherwise
			tip = "Start test: runs the waves in the editor (the state before is saved as _beforeplay). Stop / Reset ends it and brings that state back." } })
		y = y - m.PAD
		return rects, labels, rect.top - y
	end

	-- Tower tiles: the picture, a red X in the upper right corner (button), a big red X over a forbidden tower; the 3D model and
	-- the data of the tower under the mouse pointer as in the unit list
	function td.drawTiles(rect, tiles)
		local mx, my = Spring.GetMouseState()
		local hover
		for _, r in ipairs(tiles) do
			if r.kind == "tdtile" then
				local over = mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1
				if r.armed then
					gl.Color(0.25, 0.5, 1, 0.8)
					gl.Rect(r.x1 - 3, r.y0 - 3, r.x2 + 3, r.y1 + 3)
				end
				if over then
					hover = r
					gl.Color(1, 1, 1, 0.35)
					gl.Rect(r.x1 - 2, r.y0 - 2, r.x2 + 2, r.y1 + 2)
				end
				gl.Color(1, 1, 1, r.banned and 0.35 or 1)
				gl.Texture("#" .. r.id)
				gl.TexRect(r.x1, r.y0, r.x2, r.y1)
				gl.Texture(false)
				if r.banned then
					gl.Color(1, 0.1, 0.1, 1)
					gl.LineWidth(5 * H.S())
					gl.BeginEnd(GL.LINES, function()
						gl.Vertex(r.x1 + 4 * H.S(), r.y0 + 4 * H.S())
						gl.Vertex(r.x2 - 4 * H.S(), r.y1 - 4 * H.S())
						gl.Vertex(r.x1 + 4 * H.S(), r.y1 - 4 * H.S())
						gl.Vertex(r.x2 - 4 * H.S(), r.y0 + 4 * H.S())
					end)
					gl.LineWidth(1)
				end
			end
		end
		for _, r in ipairs(tiles) do
			if r.kind == "tdban" or r.kind == "tdtechx" then
				if r.kind == "tdtechx" and r.banned then
					gl.Color(0.8, 0.1, 0.1, 0.95)
				else
					gl.Color(0, 0, 0, 0.75)
				end
				gl.Rect(r.x1, r.y0, r.x2, r.y1)
				gl.Color(1, 0.15, 0.15, 1)
				gl.LineWidth(3 * H.S())
				local g = (r.x2 - r.x1) * 0.22
				gl.BeginEnd(GL.LINES, function()
					gl.Vertex(r.x1 + g, r.y0 + g)
					gl.Vertex(r.x2 - g, r.y1 - g)
					gl.Vertex(r.x1 + g, r.y1 - g)
					gl.Vertex(r.x2 - g, r.y0 + g)
				end)
				gl.LineWidth(1)
			end
		end
		gl.Color(1, 1, 1, 1)
		if hover then
			local size = H.Shared.PREVIEW_SIZE * H.S()
			local px, py = H.Shared.previewPos(rect, hover.y0, hover.y1 - hover.y0, size)
			pcall(H.Shared.drawUnitPreview, hover.id, px, py, size)
			gl.Color(1, 1, 1, 1)
			local ud = UnitDefs[hover.id]
			local cx = (rect.x1 + rect.x2) / 2
			gl.Text(string.format("%s (%s)%s", ud.translatedHumanName or ud.humanName or hover.value, hover.value, hover.banned and "  - forbidden" or ""), cx, rect.y0 - 40 * H.S(), 29 * H.S(), "co")
			gl.Text(string.format("Metal %d   Energy %d", ud.metalCost or 0, ud.energyCost or 0), cx, rect.y0 - 78 * H.S(), 26 * H.S(), "co")
		end
	end

	function td.draw(rect)
		local rects, labels = td.layout(rect)
		local buttons, tiles = {}, {}
		for _, r in ipairs(rects) do
			if r.kind == "tdtile" or r.kind == "tdban" or r.kind == "tdtechx" then
				tiles[#tiles + 1] = r
			else
				buttons[#buttons + 1] = r
			end
		end
		H.Shared.drawButtons(buttons, 22 * H.S(), H.Shared.m.HB)
		td.drawTiles(rect, tiles)
		for _, r in ipairs(rects) do
			if r.kind == "tdspawn" or r.kind == "tdgoal" then
				local cr, cg, cb = 0.3, 1, 0.4
				if r.kind == "tdgoal" then
					cr, cg, cb = 1, 0.35, 0.3
				end
				local mx0, my0, rad = r.x1 + 18 * H.S(), (r.y0 + r.y1) / 2, (r.y1 - r.y0) * 0.26
				gl.Color(cr, cg, cb, 1)
				gl.BeginEnd(GL.TRIANGLE_FAN, function()
					gl.Vertex(mx0, my0)
					for k = 0, 24 do
						local a = k / 24 * 2 * math.pi
						gl.Vertex(mx0 + math.cos(a) * rad, my0 + math.sin(a) * rad)
					end
				end)
			end
		end
		for _, l in ipairs(labels) do
			if l.line then
				gl.Color(0.3, 0.85, 0.4, 1)
				gl.Rect(l.x1, l.y - 3 * H.S(), l.x2, l.y)
			elseif l.color then
				gl.Color(l.color[1], l.color[2], l.color[3], 1)
			elseif l.head then
				gl.Color(0.5, 0.8, 1, 1)
			else
				gl.Color(0.8, 0.8, 0.8, 1)
			end
			if l.text then
				gl.Text(l.text, l.x, l.y, l.size, "o")
			end
		end
		gl.Color(1, 1, 1, 1)
		local mx, my = Spring.GetMouseState()
		H.Shared.drawTip(rects, mx, my)
	end

	-- Ends the entry in a number field (accept: take the value)
	function td.finish(accept)
		local e = td.edit
		if not e then
			return
		end
		td.edit = nil
		widgetHandler:DisownText()
		local v = tonumber(e.buf)
		if not accept or not v then
			return
		end
		v = math.floor(v)
		if e.field == "nwaves" then
			td.resize(v)
		elseif e.field == "leaks" then
			td.cfg(true).leaks = math.max(0, math.min(999, v))
		else
			local w = td.cfg(true).waves[e.row]
			if w then
				local limits = { count = { 1, 200 }, gap = { 0, 3600 }, hp = { 10, 5000 } }
				w[e.field] = math.max(limits[e.field][1], math.min(limits[e.field][2], v))
			end
		end
	end

	function td.key(key)
		if key == 13 or key == 271 then
			td.finish(true)
		elseif key == 27 then
			td.finish(false)
		elseif key == 8 then
			td.edit.buf = td.edit.buf:sub(1, -2)
		end
		return true
	end

	function td.text(ch)
		if ch and ch:match("^%d$") and #td.edit.buf < 5 then
			td.edit.buf = td.edit.buf .. ch
		end
		return true
	end

	function td.wheel(up)
		local mx, my = Spring.GetMouseState()
		local top, bottom, count = -1e9, 1e9, 0
		for _, r in ipairs((td.layout(H.contentRect()))) do
			if r.kind == "tdtile" then
				top, bottom, count = math.max(top, r.y1), math.min(bottom, r.y0), count + 1
			end
		end
		if count > 0 and my >= bottom and my <= top then
			local rows = math.ceil(#td.turrets(td.tfac, td.ttech, td.tcat) / 8)
			td.tscroll = math.max(0, math.min(math.max(0, rows - td.TROWS), td.tscroll + (up and -1 or 1)))
			return
		end
		local n = #td.cfg().waves
		td.scroll = math.max(0, math.min(math.max(0, n - td.VISIBLE), td.scroll + (up and -1 or 1)))
	end

	-- Payload for the gadget (see td_waves.lua)
	function td.payload()
		local c = td.cfg()
		if not (c.spawn and c.goal) then
			return nil, "Cannot start the test: " .. (not c.spawn and not c.goal and "spawn point and goal are missing." or (not c.spawn and "the spawn point is missing." or "the goal is missing."))
		end
		-- the first human team is the player (every human team is a player), the first AI team spawns the waves (all AI teams are enemies)
		local player = H.tm.player()
		local enemy = H.tm.enemy(player)
		local path, waves = {}, {}
		for _, p in ipairs(td.route()) do
			path[#path + 1] = string.format("%d,%d", p[1], p[2])
		end
		for _, w in ipairs(c.waves) do
			waves[#waves + 1] = string.format("%s,%s,%s,%d,%d,%d", td.chosen(w, "fac"), td.chosen(w, "kind"), td.chosen(w, "tech"), w.count, w.gap, w.hp)
		end
		return table.concat({ enemy, player, c.spawn[1], c.spawn[2], c.goal[1], c.goal[2], c.leaks, #path > 0 and table.concat(path, "/") or "-", table.concat(waves, "/"),
			c.economy ~= false and "economy" or "towers", c.fog ~= false and "1" or "0",
			H.tm.row(player).metal, H.tm.row(player).energy }, ";")
	end

	-- Ends the pick mode (spawn point, goal, corridor, route)
	function td.endPick()
		td.pick, td.pts, td.stroke = nil, {}, nil
	end

	-- Arms picking on the map: "spawn" or "goal" (one click), or drawing: kind "corridor" (builds the walls on both sides of
	-- the drawn line) or "route" (only the way the enemies walk), mode "line" (click points) or "free" (hold the mouse button
	-- and drag); the same button again ends it
	function td.startPick(kind, mode)
		td.finish(true)
		local same = td.pick == kind and td.mode == mode
		H.disarmModes() -- stamp, delete, maze, generate, area attack end
		td.endPick()
		if same then
			H.say("Tower Defense: mode ended")
			return
		end
		td.pick, td.mode = kind, mode
		local what = kind == "corridor" and "the corridor (walls on both sides)" or "the route of the enemies"
		if mode == "single" then
			H.say("Click on the map: every click places one wall piece (indestructible). Right click ends, Ctrl+Z undoes.")
		elseif mode == "line" then
			H.say("Click the points of " .. what .. " on the map (start first), right click finishes (Ctrl+Z undoes).")
		elseif mode == "free" then
			H.say("Draw " .. what .. " with the left mouse button held down.")
		elseif kind == "waypoint" then
			H.say("Click the waypoints on the map, right click ends. Del over a waypoint removes it.")
		else
			H.say((kind == "spawn" and "Spawn point" or "Goal") .. ": click the place on the map, right click cancels.")
		end
	end

	-- Right click in the pick mode: a drawn line is finished (the corridor is built, undo with Ctrl+Z), otherwise the mode ends
	function td.cancel()
		if (td.pick == "corridor" or td.pick == "route") and td.mode == "line" and #td.pts >= 2 then
			td.finishDraw()
			return
		end
		td.endPick()
		H.say("Tower Defense: mode ended")
	end

	-- Left click on the map in the pick mode
	function td.click(x, z)
		local before = td.routeState()
		if td.pick == "waypoint" then
			local n = td.addWaypoint(x, z)
			td.commit(before)
			H.say(string.format("Waypoint placed (%d). Click for more, right click ends, Del over a waypoint removes it, Alt + drag moves it.", n))
			return
		end
		if td.pick == "corridor" and td.mode == "single" then
			td.startSingle(x, z)
			td.sdrag = nil -- a click only
			return
		end
		if td.pick == "corridor" or td.pick == "route" then
			td.pts[#td.pts + 1] = { math.floor(x), math.floor(z) }
			H.say(string.format("%d points. Right click finishes.", #td.pts))
			return
		end
		local c = td.cfg(true)
		c[td.pick] = { math.floor(x), math.floor(z) }
		td.commit(before)
		H.say(string.format("%s set at %d, %d", td.pick == "spawn" and "Spawn point" or "Goal", x, z))
		td.endPick()
	end

	-- Points of a hand-drawn line: take a point when the mouse moved far enough (called every frame while drawing)
	-- Single wall pieces: a press places one piece (one undo step for the whole press); while the mouse button is held every grid
	-- cell the pointer passes gets a piece (td.sample)
	-- One wall piece at (x, z); what stands in the way is deleted
	function td.wallCell(name, x, z)
		if not H.makeRoom(name, x, z, 0) then
			return
		end
		H.notePlaced(name, x, z, 0)
		H.placeQueue()[#H.placeQueue() + 1] = string.format("led|place|%s|%d|%d|%d|%d|%d|1", name, H.team(), x, z, 0, H.neutralOn() and 1 or 0)
	end

	function td.startSingle(x, z)
		local name = H.mazeUnitName(H.MAZE_KINDS[td.wall])
		if not name then
			H.say("This faction has no " .. MAZE_KINDS[td.wall].label .. " in this game")
			return
		end
		H.ledStep()
		local gx, gz = math.floor(x / 16 + 0.5), math.floor(z / 16 + 0.5)
		td.sdrag = { name = name, gx = gx, gz = gz, seen = { [gx * 100003 + gz] = true } }
		td.wallCell(name, gx * 16, gz * 16)
	end

	-- Ends the moving of a waypoint: one undo step
	function td.endWpDrag()
		if td.wpDrag then
			td.wpDrag = nil
			td.commit(td.wpBefore)
		end
	end

	function td.sample()
		if td.sdrag then
			local d = td.sdrag
			local mx, my, left = Spring.GetMouseState()
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if not left then
				td.sdrag = nil
			elseif pos then
				local nx, nz = math.floor(pos[1] / 16 + 0.5), math.floor(pos[3] / 16 + 0.5)
				local steps = math.max(math.abs(nx - d.gx), math.abs(nz - d.gz))
				for k = 1, steps do -- also the cells in between when the mouse moved fast
					local cx, cz = math.floor(d.gx + (nx - d.gx) * k / steps + 0.5), math.floor(d.gz + (nz - d.gz) * k / steps + 0.5)
					local key = cx * 100003 + cz
					if not d.seen[key] then
						d.seen[key] = true
						td.wallCell(d.name, cx * 16, cz * 16)
					end
				end
				d.gx, d.gz = nx, nz
			end
			return
		end
		if td.wpDrag then
			local mx, my, left = Spring.GetMouseState()
			local c = td.cfg()
			local holder = type(td.wpDrag) == "number" and c.waypoints or c -- waypoints[i] or c.spawn / c.goal
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			if not left or not (holder and holder[td.wpDrag]) then
				td.endWpDrag()
			elseif pos then
				holder[td.wpDrag] = { math.floor(pos[1]), math.floor(pos[3]) }
			end
			return
		end
		local s = td.stroke
		if not s then
			return
		end
		local mx, my = Spring.GetMouseState()
		local _, pos = Spring.TraceScreenRay(mx, my, true)
		local last = s[#s]
		if pos and (pos[1] - last[1]) ^ 2 + (pos[3] - last[2]) ^ 2 >= 48 ^ 2 then
			s[#s + 1] = { math.floor(pos[1]), math.floor(pos[3]) }
		end
	end

	-- Fewer points for the same line (Douglas-Peucker): a hand-drawn line has far too many
	function td.simplify(p, tol)
		if #p <= 2 then
			return p
		end
		local best, at = 0, 0
		local a, b = p[1], p[#p]
		local dx, dz = b[1] - a[1], b[2] - a[2]
		local len = math.sqrt(dx * dx + dz * dz)
		for i = 2, #p - 1 do
			local d = len > 0 and math.abs((p[i][1] - a[1]) * dz - (p[i][2] - a[2]) * dx) / len or math.sqrt((p[i][1] - a[1]) ^ 2 + (p[i][2] - a[2]) ^ 2)
			if d > best then
				best, at = d, i
			end
		end
		if best <= tol then
			return { a, b }
		end
		local left, right = {}, {}
		for i = 1, at do
			left[#left + 1] = p[i]
		end
		for i = at, #p do
			right[#right + 1] = p[i]
		end
		left, right = td.simplify(left, tol), td.simplify(right, tol)
		for i = 2, #right do
			left[#left + 1] = right[i]
		end
		return left
	end

	-- Distance of a point to the polyline of points p
	function td.distToPath(px, pz, p)
		local best = math.huge
		for i = 1, #p - 1 do
			local ax, az, bx, bz = p[i][1], p[i][2], p[i + 1][1], p[i + 1][2]
			local dx, dz = bx - ax, bz - az
			local len2 = dx * dx + dz * dz
			local t = len2 > 0 and math.max(0, math.min(1, ((px - ax) * dx + (pz - az) * dz) / len2)) or 0
			best = math.min(best, math.sqrt((px - ax - t * dx) ^ 2 + (pz - az - t * dz) ^ 2))
		end
		return best
	end

	-- Wall pieces left and right of the path: every 8 Elmo along the offset lines, not inside the corridor of another section;
	-- on the outer side of every bend an arc around the corner point closes the gap between the two offset lines
	function td.wallSpots(p, width)
		local clear = width * 16 / 2 -- half of the free corridor
		local off = clear + 8 -- middle of the wall piece
		local spots, seen = {}, {}
		local function add(x, z)
			local wx, wz = math.floor(x / 16 + 0.5) * 16, math.floor(z / 16 + 0.5) * 16
			local key = wx * 100003 + wz
			if not seen[key] then
				seen[key] = true
				if td.distToPath(wx, wz, p) >= clear - 6 then
					spots[#spots + 1] = { wx, wz }
				end
			end
		end
		for i = 1, #p - 1 do
			local ax, az, bx, bz = p[i][1], p[i][2], p[i + 1][1], p[i + 1][2]
			local len = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
			if len > 0 then
				local dx, dz = (bx - ax) / len, (bz - az) / len
				for s0 = 0, len + 8, 8 do
					local s = math.min(s0, len)
					for _, side in ipairs({ 1, -1 }) do
						add(ax + dx * s - dz * off * side, az + dz * s + dx * off * side)
					end
				end
			end
		end
		for i = 2, #p - 1 do
			local ax, az, bx, bz, cx, cz = p[i - 1][1], p[i - 1][2], p[i][1], p[i][2], p[i + 1][1], p[i + 1][2]
			local l1, l2 = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2), math.sqrt((cx - bx) ^ 2 + (cz - bz) ^ 2)
			if l1 > 0 and l2 > 0 then
				local d1x, d1z, d2x, d2z = (bx - ax) / l1, (bz - az) / l1, (cx - bx) / l2, (cz - bz) / l2
				local side = (d1x * d2z - d1z * d2x) > 0 and -1 or 1 -- the outer side of the bend
				local a1, a2 = math.atan2(d1x * side, -d1z * side), math.atan2(d2x * side, -d2z * side)
				local diff = (a2 - a1 + math.pi) % (2 * math.pi) - math.pi
				local n = math.max(1, math.ceil(math.abs(diff) * off / 8))
				for k = 0, n do
					local a = a1 + diff * k / n
					add(bx + math.cos(a) * off, bz + math.sin(a) * off)
				end
			end
		end
		return spots
	end

	-- Builds the walls on both sides of the line p (one undo step). The wall pieces are indestructible: enemies of higher tech
	-- levels would shoot a way through otherwise. Returns true when it built something.
	function td.buildWalls(p)
		if not H.canEdit() then
			return false
		end
		local name = H.mazeUnitName(H.MAZE_KINDS[td.wall])
		if not name then
			H.say("This faction has no " .. MAZE_KINDS[td.wall].label .. " in this game")
			return false
		end
		local c = td.cfg(true)
		local spots = td.wallSpots(p, c.width)
		if #spots > H.MAZE_MAX_WALLS then
			H.say("The corridor is too long (more than " .. MAZE_MAX_WALLS .. " wall pieces)")
			return false
		end
		H.ledStep()
		local made = 0
		for _, s in ipairs(spots) do
			if H.makeRoom(name, s[1], s[2], 0) then -- W on: what stands in the way is deleted, W off: occupied spots are left out
				H.notePlaced(name, s[1], s[2], 0)
				H.placeQueue()[#H.placeQueue() + 1] = string.format("led|place|%s|%d|%d|%d|%d|%d|1", name, H.team(), s[1], s[2], 0, H.neutralOn() and 1 or 0)
				made = made + 1
			end
		end
		H.say(string.format("Corridor: %d indestructible wall pieces (%s)%s. Ctrl+Z undoes it.", made, name, made < #spots and (", " .. (#spots - made) .. " occupied spots left out") or ""))
		return true
	end

	-- The drawn line (td.pts) is finished: the corridor mode builds the walls and stays on, the route mode takes the line as the route of the
	-- enemies and its ends as spawn point and goal
	function td.finishDraw()
		local p = td.simplify(td.pts, 24)
		if #p < 2 then
			H.say("Click at least two points first.")
			return
		end
		if td.pick == "corridor" then
			td.buildWalls(p)
			td.pts, td.stroke = {}, nil -- the mode stays on: the next corridor can be drawn right away (right click ends it)
			return
		end
		td.endPick()
	end

	function td.press(rect, mx, my)
		local hit
		for _, r in ipairs((td.layout(rect))) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		td.finish(true)
		if not hit then
			return true
		end
		local k = hit.kind
		if k == "tdon" then
			local c = td.cfg(true)
			c.enabled = not c.enabled
			if c.enabled and H.ctf.data and H.ctf.data.enabled then
				H.ctf.data.enabled = false -- only one of the two game modes can be on
				H.say("Capture the Flag switched off: Tower Defense and Capture the Flag exclude each other.")
			end
			if c.enabled and H.rtf.data and H.rtf.data.enabled then
				H.rtf.data.enabled = false
				H.say("Reclaim the Fame switched off: only one game mode can be on.")
			end
		elseif k == "tdmat" then
			td.wall = hit.value
		elseif k == "tddraw" then
			td.startPick(hit.field, hit.value)
		elseif k == "tdspawn" then
			td.startPick("spawn")
		elseif k == "tdgoal" then
			td.startPick("goal")
		elseif k == "tdspawnx" or k == "tdgoalx" then
			local before = td.routeState()
			td.cfg(true)[k == "tdspawnx" and "spawn" or "goal"] = nil
			td.commit(before)
		elseif k == "tdwidth" then
			td.cfg(true).width = hit.value
		elseif k == "tdminus" or k == "tdplus" then
			local d = k == "tdplus" and 1 or -1
			if hit.value == "nwaves" then
				td.resize(#td.cfg().waves + d)
			else
				local c = td.cfg(true)
				c.leaks = math.max(0, math.min(999, c.leaks + d))
			end
		elseif k == "tdedit" then
			td.edit = { field = hit.field, buf = "" }
			widgetHandler:OwnText()
		elseif k == "tdtog" then
			td.toggleChoice(td.cfg(true).waves[hit.row], hit.field, hit.value)
		elseif k == "tdcell" then
			td.edit = { field = hit.field, row = hit.row, buf = "" }
			widgetHandler:OwnText()
		elseif k == "tdplay" then
			td.toggle()
		elseif k == "tdfac" then
			td.tfac, td.tscroll = hit.value, 0
		elseif k == "tdtech" then
			td.ttech, td.tscroll = hit.value, 0
		elseif k == "tdcat" then
			td.tcat, td.tscroll = hit.value, 0
		elseif k == "tdtile" then
			td.armUnit(hit.value)
		elseif k == "tdwaypoint" then
			td.startPick("waypoint")
		elseif k == "tdwaypointx" then
			local before = td.routeState()
			td.cfg(true).waypoints = {}
			td.commit(before)
		elseif k == "tdfog" then
			local c = td.cfg(true)
			c.fog, td.tscroll = not (c.fog ~= false), 0
		elseif k == "tdban" then
			H.rst.toggle(hit.value)
		elseif k == "tdtechx" then
			local names = H.uGrid:namesOf("tech", hit.value) -- all units of the tech level, like the tech X of the Place menu
			H.rst.setBanned(names, not H.rst.allBanned(names))
		elseif k == "tdeconomy" then
			local c = td.cfg(true)
			c.economy, td.tscroll = not (c.economy ~= false), 0
		end
		return true
	end

	-- Play / Stop (button at the bottom of the TD page): runs the waves in the editor; the state before is saved as _beforeplay and comes back on Stop
	function td.toggle()
		local state = Spring.GetGameRulesParam("tdState")
		if state and state ~= "" then
			-- running, won or lost: stop and bring the state before Play back (destroyed towers, wave units)
			Spring.SendLuaRulesMsg("tdw|stop")
			H.rst.stop()
			H.restoreBeforePlay()
			H.say("Stopped: the state before Play is back.")
			return
		end
		local payload, err = td.payload()
		if not payload then
			H.say(err)
			td.notice = { text = err, untilT = os.clock() + 6 }
			return
		end
		H.gen.disarmAll()
		H.saveLevel("_beforeplay", true)
		H.rst.start()
		Spring.SendLuaRulesMsg("tdw|start|" .. payload)
		H.say("Test started: the state before is saved as _beforeplay; Stop brings it back.")
	end

	-- Markers in the world (also with the page closed): spawn point (green), goal (red), path and the points being clicked
	function td.drawWorld()
		local c = td.cfg()
		if not td.open and not c.spawn and not c.goal and #(c.waypoints or {}) == 0 then
			return -- the markers stay visible with the page closed, so nothing stays hidden
		end
		gl.DepthTest(false)
		gl.LineWidth(3)
		local function circle(p, r, cr, cg, cb)
			gl.Color(cr, cg, cb, 1)
			gl.BeginEnd(GL.LINE_LOOP, function()
				for i = 0, 31 do
					local a = i / 32 * 2 * math.pi
					local x, z = p[1] + math.cos(a) * r, p[2] + math.sin(a) * r
					gl.Vertex(x, Spring.GetGroundHeight(x, z) + 8, z)
				end
			end)
		end
		local function polyline(list, cr, cg, cb, extra)
			gl.Color(cr, cg, cb, 1)
			gl.BeginEnd(GL.LINE_STRIP, function()
				for _, q in ipairs(list) do
					gl.Vertex(q[1], Spring.GetGroundHeight(q[1], q[2]) + 8, q[2])
				end
				if extra then
					gl.Vertex(extra[1], extra[2] + 8, extra[3])
				end
			end)
		end
		if c.spawn then
			circle(c.spawn, 48, 0.3, 1, 0.4)
		end
		if c.goal then
			circle(c.goal, td.GOAL_RADIUS, 1, 0.35, 0.3)
		end
		local route = td.route()
		if c.spawn and c.goal then
			local list = { c.spawn }
			for _, p in ipairs(route) do
				list[#list + 1] = p
			end
			list[#list + 1] = c.goal
			polyline(list, 1, 0.9, 0.3) -- only to look at: the way of the enemies
		end
		local hot = td.open and td.waypointAt() or nil
		for i, p in ipairs(c.waypoints or {}) do
			circle(p, i == hot and 44 or 28, i == hot and 1 or 1, i == hot and 0.3 or 0.9, i == hot and 0.3 or 0.3)
		end
		if (td.pick == "corridor" or td.pick == "route") and td.mode == "line" and #td.pts > 0 then
			local mx, my = Spring.GetMouseState()
			local _, pos = Spring.TraceScreenRay(mx, my, true)
			polyline(td.pts, 0.4, 0.9, 1, pos)
		end
		if td.stroke and #td.stroke > 1 then
			polyline(td.stroke, 0.4, 0.9, 1)
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
	end

	-- Status of the running test (from the gadget) at the top of the screen
	function td.hud(vsx, vsy)
		local state = Spring.GetGameRulesParam("tdState")
		if not state or state == "" then
			return
		end
		local text
		if state == "won" then
			text = "TOWER DEFENSE: LEVEL WON"
		elseif state == "lost" then
			text = "TOWER DEFENSE: LEVEL LOST"
		else
			text = string.format("Tower Defense  wave %d/%d  enemies %d  killed %d  through %d/%d",
				Spring.GetGameRulesParam("tdWave") or 0, Spring.GetGameRulesParam("tdWaves") or 0, Spring.GetGameRulesParam("tdAlive") or 0,
				Spring.GetGameRulesParam("tdKilled") or 0, Spring.GetGameRulesParam("tdLeaks") or 0, Spring.GetGameRulesParam("tdMaxLeaks") or 0)
		end
		gl.Color(1, 0.9, 0.4, 1)
		gl.Text(text, vsx * 0.5, vsy - 70 * H.S(), 22 * H.S(), "co")
		gl.Color(1, 1, 1, 1)
	end
end
