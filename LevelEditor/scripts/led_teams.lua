-- Teams of the Level Editor: alliances (the colored frames of the team buttons, right click menu) and the page T (button T): human or AI per
-- team, alliance and start resources. Specification: SPECIFICATION.md section 11f. Loaded by lvl_level_editor.lua
-- (VFS.Include("luaui/Include/led_teams.lua")) as a function that gets the host (the services of the widget) and returns the table tm; a file of
-- its own because the widget is close to the limit of 200 local variables. The data (tm.data) is the section teams of the level file.
--   host.Shared, host.S() (UI scale), host.say(text), host.led(message) (message to the editor gadget), host.serialize(table), host.panelRect(),
--   host.teamUnits(team) (number of units of a team)
return function(host)
	local Shared = host.Shared
	local tm = { data = nil, edit = nil, menu = nil, drop = nil }
	local TEAMS = 10 -- teams 0 to 9 (Gaia is no team of this page)
	local LIMIT = 100000

	tm.AIS = { "NullAI", "BARb", "CircuitAI", "CircuitAI easy", "SimpleAI", "SimpleDefenderAI", "SimpleConstructorAI", "ScavengersAI", "RaptorsAI" }
	tm.AI_TXT = {
		NullAI = "NullAI (does nothing)", BARb = "BARb (expands, attacks)", CircuitAI = "CircuitAI", ["CircuitAI easy"] = "CircuitAI easy",
		SimpleAI = "SimpleAI (easy)", SimpleDefenderAI = "SimpleDefenderAI (easy, defends)", SimpleConstructorAI = "SimpleConstructorAI (easy, builds)",
		ScavengersAI = "Scavengers (infinite game)", RaptorsAI = "Raptors (defence)",
	}
	-- the ten alliance colors (group 1 to 10)
	tm.COLORS = {
		{ 0.92, 0.22, 0.22 }, { 0.25, 0.5, 1 }, { 0.2, 0.8, 0.3 }, { 0.95, 0.85, 0.2 }, { 1, 0.55, 0.1 },
		{ 0.7, 0.35, 0.9 }, { 0.2, 0.85, 0.85 }, { 1, 0.5, 0.75 }, { 0.95, 0.95, 0.95 }, { 0.6, 0.4, 0.2 },
	}

	local function newRow(i)
		return { group = 0, ai = (i == 1) and "" or "NullAI", metal = 1000, energy = 1000 } -- team 0 is a human, the others do nothing
	end
	function tm.new()
		local rows = {}
		for i = 1, TEAMS do
			rows[i] = newRow(i)
		end
		return rows
	end
	tm.DEFAULT = tm.new()
	local NONE = { group = 0, ai = "NullAI", metal = 1000, energy = 1000 } -- a team that is not on the page (Gaia)

	-- The row of team t (0 to 9): the stored one or the default (never changed by the caller)
	function tm.row(t)
		return (tm.data or tm.DEFAULT)[(tonumber(t) or -1) + 1] or NONE
	end
	local function write(t)
		if not tm.data then
			tm.data = tm.new()
		end
		return tm.data[t + 1]
	end

	function tm.group(t)
		return tm.row(t).group
	end

	-- After loading: only the known fields, in range; the default for everything else
	function tm.load(section)
		tm.data = nil
		if type(section) == "table" then
			local d = tm.new()
			for i = 1, TEAMS do
				local r = section[i]
				if type(r) == "table" then
					local g = tonumber(r.group)
					if g and g >= 0 and g <= #tm.COLORS then
						d[i].group = math.floor(g)
					end
					if type(r.ai) == "string" and (r.ai == "" or tm.AI_TXT[r.ai]) then
						d[i].ai = r.ai
					end
					for _, k in ipairs({ "metal", "energy" }) do
						local v = tonumber(r[k])
						if v and v >= 0 and v <= LIMIT then
							d[i][k] = math.floor(v)
						end
					end
				end
			end
			tm.data = d
		end
		tm.apply()
	end

	function tm.lua()
		return host.serialize(tm.data)
	end

	-- The alliances to the gadget: it sets Spring.SetAlly between the ally teams (the engine cannot move a team into another ally team)
	function tm.apply()
		local g = {}
		for t = 0, TEAMS - 1 do
			g[#g + 1] = tostring(tm.group(t))
		end
		host.led("led|teams|" .. table.concat(g, ","))
	end

	function tm.setGroup(t, g)
		write(t).group = g
		tm.apply()
		host.say(g > 0 and ("Team " .. t .. " is in alliance " .. g .. ".") or ("Team " .. t .. " has no alliance."))
	end

	local function colorOf(g)
		local c = tm.COLORS[g]
		return c and c[1], c and c[2], c and c[3]
	end

	-- A team button of the strip: outer frame in the color of the alliance (none: no frame), a thin black border, inside the color of the team
	function tm.drawButton(r, sel, cr, cg, cb)
		local S = host.S()
		local g = tm.group(r.team)
		local f = math.max(3, 4 * S)
		if g > 0 then
			local ar, ag, ab = colorOf(g)
			gl.Color(ar, ag, ab, 1)
		else
			gl.Color(0, 0, 0, 0.65)
		end
		gl.Rect(r.x1, r.y0, r.x2, r.y1)
		gl.Color(0, 0, 0, 0.9)
		gl.Rect(r.x1 + f, r.y0 + f, r.x2 - f, r.y1 - f)
		gl.Color(cr, cg, cb, sel and 1 or 0.45)
		gl.Rect(r.x1 + f + 2, r.y0 + f + 2, r.x2 - f - 2, r.y1 - f - 2)
	end

	-- Tooltip lines of a team button
	function tm.tipLines(t)
		local r = tm.row(t)
		local _, _, _, _, _, ally = Spring.GetTeamInfo(t, false)
		return {
			"Team " .. t .. (r.group > 0 and (" (alliance " .. r.group .. ")") or " (no alliance: enemy of everybody)"),
			r.ai == "" and "Human" or ("AI: " .. r.ai),
			"Start: " .. r.metal .. " metal, " .. r.energy .. " energy",
			"New units and blueprints belong to this team.",
			"Units: " .. (host.teamUnits(t) or 0) .. " of " .. (Spring.GetTeamMaxUnits(t) or "?"),
			"Right click: choose the alliance. Human or AI: button T.",
		}
	end

	-- ---------------------------------------------------------------- the menu of the alliance colors (right click on a team button, or the Alliance cell)
	-- items = list of { label, value = group }; anchored at a rectangle: the menu is a column that starts at the top of the anchor
	local function colorItems()
		local items = { { label = "none", value = 0 } }
		for g = 1, #tm.COLORS do
			items[#items + 1] = { label = tostring(g), value = g }
		end
		return items
	end

	function tm.openMenu(team, anchor, side)
		tm.menu = { team = team, anchor = anchor, side = side or "left", items = colorItems() }
	end

	local function menuRects()
		local m = tm.menu
		if not m then
			return nil
		end
		local S, hb = host.S(), Shared.m.HB
		local w = 110 * S
		local a = m.anchor
		local x1, x2
		if m.side == "left" then
			x2 = a.x1 - 70 * S -- room for the number of units left of the team button
			x1 = x2 - w
		else
			x1 = a.x1
			x2 = a.x1 + math.max(w, a.x2 - a.x1)
		end
		local top = (m.side == "left") and a.y1 or a.y0
		local n = #m.items
		if top - n * hb < 6 * S then
			top = 6 * S + n * hb
		end
		local rects = {}
		for k, it in ipairs(m.items) do
			local r = { x1 = x1, x2 = x2, y0 = top - k * hb, y1 = top - (k - 1) * hb, kind = "tmpick", value = it.value, label = it.label, fs = 22 * S,
				active = tm.row(m.team).group == it.value }
			if it.value > 0 then
				local cr, cg, cb = colorOf(it.value)
				r.tint = { cr * 0.8, cg * 0.8, cb * 0.8 }
			end
			rects[k] = r
		end
		return rects
	end

	function tm.drawMenu()
		local rects = menuRects()
		if not rects then
			return
		end
		local S = host.S()
		gl.Color(0, 0, 0, 1)
		gl.Rect(rects[1].x1 - 2 * S, rects[#rects].y0 - 2 * S, rects[1].x2 + 2 * S, rects[1].y1 + 2 * S)
		Shared.drawButtons(rects, 22 * S, Shared.m.HB)
		gl.Color(1, 1, 1, 1)
	end

	-- A click while the menu is open: closes it; a click on a color chooses it. Returns true when the click was used
	function tm.menuPress(mx, my, button)
		local rects = menuRects()
		if not rects then
			return false
		end
		local team = tm.menu.team
		tm.menu = nil
		if button == 1 then
			for _, r in ipairs(rects) do
				if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
					tm.setGroup(team, r.value)
				end
			end
		end
		return true
	end

	-- ---------------------------------------------------------------- the page T
	local W = { 1, 1.6, 3.4, 1.6, 1.8, 1.8 } -- Team, Human / AI, AI, Alliance, Start metal, Start energy

	local function field(name, t)
		local e = tm.edit
		local editing = e ~= nil and e.field == name and e.team == t
		return { kind = "tmfield", field = name, team = t, label = editing and (e.buf .. "_") or tostring(tm.row(t)[name]), active = editing,
			tip = "Start " .. name .. " of this team. Click, type a number, Enter accepts" }
	end

	function tm.layout(rect)
		local S, m = host.S(), Shared.m
		local rects, labels = {}, {}
		local x1, x2 = rect.x1 + m.PAD, rect.x2 - m.PAD
		local y = rect.top - m.PAD
		local gap = 4 * S
		local function line(items, after)
			local total = 0
			for i, it in ipairs(items) do
				it.w = W[i]
				total = total + it.w
			end
			local avail, bx = x2 - x1 - gap * (#items - 1), x1
			for _, it in ipairs(items) do
				local w = avail * it.w / total
				rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = it.kind, label = it.label, active = it.active, fs = it.fs or 22 * S,
					field = it.field, team = it.team, tint = it.tint, tip = it.tip }
				bx = bx + w + gap
			end
			y = y - m.HB - (after or 6 * S)
		end
		labels[#labels + 1] = { text = "Teams: human or AI, alliance, start resources (saved with the level)", x = x1, y = y - 26 * S, size = 22 * S }
		y = y - 32 * S
		local hdr = { 0.12, 0.12, 0.12 }
		local function head(text)
			return { kind = "tmhdr", label = text, tint = hdr, fs = 18 * S }
		end
		line({ head("Team"), head("Human / AI"), head("AI"), head("Alliance"), head("Metal"), head("Energy") }, 3 * S)
		for t = 0, TEAMS - 1 do
			local r = tm.row(t)
			local cr, cg, cb = Spring.GetTeamColor(t)
			local human = r.ai == ""
			local units = host.teamUnits(t) or 0
			local ar, ag, ab = colorOf(r.group)
			line({
				{ kind = "tmhdr", label = tostring(t), tint = { cr or 0.5, cg or 0.5, cb or 0.5 },
					tip = "Team " .. t .. ": " .. units .. " units" .. (units == 0 and " (a team without units is not part of a scenario)" or "") },
				{ kind = "tmkind", team = t, label = human and "Human" or "AI", tint = human and { 0.15, 0.5, 0.75 } or { 0.5, 0.3, 0.15 },
					tip = "Click: switches between a human (a player of the lobby takes this team) and an AI" },
				{ kind = "tmai", team = t, label = human and "-" or r.ai, tint = human and { 0.1, 0.1, 0.1 } or nil,
					tip = human and "A human plays this team: no AI" or ((tm.AI_TXT[r.ai] or r.ai) .. "\nClick: choose another AI") },
				{ kind = "tmgroup", team = t, label = r.group > 0 and tostring(r.group) or "-", tint = r.group > 0 and { ar * 0.8, ag * 0.8, ab * 0.8 } or nil,
					tip = "Alliance: teams with the same color are allies. Click to choose (also: right click on the team button at the left)" },
				field("metal", t),
				field("energy", t),
			}, 3 * S)
		end
		labels[#labels + 1] = { text = "A team with a human keeps no AI in a scenario; a team needs units to be part of it.", x = x1, y = y - 18 * S, size = 17 * S, dim = true }
		y = y - 26 * S
		y = y - m.PAD
		return rects, labels, rect.top - y
	end

	function tm.height()
		local _, _, h = tm.layout({ x1 = 0, x2 = math.floor(780 * host.S()), top = 0 })
		return h
	end

	-- the list of an AI choice (drop), placed under the cell
	local function dropRects()
		local d = tm.drop
		if not d then
			return nil
		end
		local S, hb = host.S(), Shared.m.HB
		local a = d.anchor
		local w = math.max(a.x2 - a.x1, 260 * S)
		local rects = {}
		local top = a.y0
		local n = #d.items
		if top - n * hb < 6 * S then
			top = 6 * S + n * hb
		end
		for k, it in ipairs(d.items) do
			rects[k] = { x1 = a.x1, x2 = a.x1 + w, y0 = top - k * hb, y1 = top - (k - 1) * hb, kind = "tmdrop", value = it.value, label = it.label, fs = 20 * S,
				active = it.value == d.current }
		end
		return rects
	end

	function tm.draw(rect)
		local S = host.S()
		local rects, labels = tm.layout(rect)
		Shared.drawButtons(rects, 22 * S, Shared.m.HB)
		for _, l in ipairs(labels) do
			if l.dim then
				gl.Color(0.7, 0.7, 0.7, 1)
			else
				gl.Color(0.5, 0.8, 1, 1)
			end
			gl.Text(l.text, l.x, l.y, l.size, "o")
		end
		local mx, my = Spring.GetMouseState()
		local dr = dropRects()
		if dr then
			gl.Color(0, 0, 0, 1)
			gl.Rect(dr[1].x1 - 2 * S, dr[#dr].y0 - 2 * S, dr[1].x2 + 2 * S, dr[1].y1 + 2 * S)
			Shared.drawButtons(dr, 20 * S, Shared.m.HB)
		else
			Shared.drawTip(rects, mx, my)
		end
		gl.Color(1, 1, 1, 1)
	end

	-- Ends the entry in a number field
	function tm.finish(accept)
		local e = tm.edit
		if not e then
			return
		end
		tm.edit = nil
		widgetHandler:DisownText()
		if accept then
			local v = tonumber(e.buf)
			if v then
				write(e.team)[e.field] = math.max(0, math.min(LIMIT, math.floor(v)))
			end
		end
	end

	function tm.key(key)
		if key == 13 or key == 271 then
			tm.finish(true)
		elseif key == 27 then
			tm.finish(false)
		elseif key == 8 then
			tm.edit.buf = tm.edit.buf:sub(1, -2)
		end
		return true
	end

	function tm.text(ch)
		if ch and ch:match("^%d$") and #tm.edit.buf < 6 then
			tm.edit.buf = tm.edit.buf .. ch
		end
		return true
	end

	function tm.press(rect, mx, my)
		local dr = dropRects()
		if dr then
			local d = tm.drop
			tm.drop = nil
			for _, r in ipairs(dr) do
				if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
					write(d.team).ai = r.value
				end
			end
			return true
		end
		local hit
		for _, r in ipairs((tm.layout(rect))) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		tm.finish(true)
		if not hit then
			return true
		end
		local k, t = hit.kind, hit.team
		if k == "tmkind" then
			local r = write(t)
			r.ai = (r.ai == "") and "NullAI" or ""
		elseif k == "tmai" then
			if tm.row(t).ai ~= "" then
				local items = {}
				for _, n in ipairs(tm.AIS) do
					items[#items + 1] = { label = tm.AI_TXT[n], value = n }
				end
				tm.drop = { team = t, anchor = hit, items = items, current = tm.row(t).ai }
			end
		elseif k == "tmgroup" then
			tm.openMenu(t, hit, "below")
		elseif k == "tmfield" then
			tm.edit = { field = hit.field, team = t, buf = "" }
			widgetHandler:OwnText()
		end
		return true
	end

	-- The first team that is a human (the player) and the first AI team (the enemy that spawns the waves of Tower Defense); a default when there is none
	function tm.player()
		for t = 0, TEAMS - 1 do
			if tm.row(t).ai == "" then
				return t
			end
		end
		return 0
	end
	function tm.enemy(player)
		for t = 0, TEAMS - 1 do
			if tm.row(t).ai ~= "" and t ~= player then
				return t
			end
		end
		return player == 0 and 1 or 0
	end

	return tm
end
