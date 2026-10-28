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

	-- Cost of all units of every team on the map (for the remaining budget): worked out twice a second, not in every layout
	function ar.poll()
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
		Shared.drawTip(rects, mx, my)
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
		elseif k == "arunits" or k == "arpoint" or k == "arpointx" or k == "argen" or k == "arclear" or k == "arplay" then
			host.say("Arena: this button does not work yet.")
		end
		return true
	end

	return ar
end
