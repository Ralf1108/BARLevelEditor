-- Restrictions of the level (what the player may not build) for the Level Editor: one list for the whole level, written by the Place menu and
-- by the Tower Defense page alike. Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_restrictions.lua")) as a function that gets
-- the host (host.serialize(table)) and returns the list; a file of its own because the widget is close to the limit of 200 local variables.
-- The data (rst.data) are saved in their own section restrictions of the level file: { banned = { "armllt", ... } }.
-- The game itself enforces them in the gadget unit_restrictions.lua (message "rst|start|<payload>" at the start of a test, "rst|stop").
return function(host)
	local rst = { data = nil, set = {} }

	function rst.new()
		return { banned = {} }
	end

	-- The stored data (from the level file) or nothing; the set of the banned names is rebuilt
	function rst.load(t)
		rst.data = nil
		rst.set = {}
		if type(t) == "table" and type(t.banned) == "table" then
			rst.data = { banned = {} } -- only the known field is taken over
			for _, n in ipairs(t.banned) do
				if type(n) == "string" and not rst.set[n] then
					rst.set[n] = true
					rst.data.banned[#rst.data.banned + 1] = n
				end
			end
		end
	end

	-- Data to change (created when missing)
	local function write()
		if not rst.data then
			rst.data = rst.new()
		end
		return rst.data
	end

	function rst.empty()
		return not rst.data or #rst.data.banned == 0
	end

	function rst.lua()
		return host.serialize(rst.data)
	end

	function rst.isBanned(name)
		return rst.set[name] == true
	end

	-- Ban or allow a list of unit names (all of them)
	function rst.setBanned(names, on)
		local d = write()
		for _, n in ipairs(names) do
			rst.set[n] = on and true or nil
		end
		local list = {}
		for n in pairs(rst.set) do
			list[#list + 1] = n
		end
		table.sort(list)
		d.banned = list
	end

	function rst.toggle(name)
		rst.setBanned({ name }, not rst.isBanned(name))
	end

	-- true when the list is not empty and every unit of it is banned
	function rst.allBanned(names)
		if #names == 0 then
			return false
		end
		for _, n in ipairs(names) do
			if not rst.set[n] then
				return false
			end
		end
		return true
	end

	-- The payload of the gadget: "name,name" ("-" for none)
	function rst.payload()
		local d = rst.data or rst.new()
		return #d.banned > 0 and table.concat(d.banned, ",") or "-"
	end

	-- At the start of a test: the gadget blocks the build orders; at its end the block is released
	function rst.start()
		Spring.SendLuaRulesMsg("rst|start|" .. rst.payload())
	end

	function rst.stop()
		Spring.SendLuaRulesMsg("rst|stop")
	end

	-- The window with the forbidden units (button R right of the search field of the Place menu): it sits left of the menu, one row per unit with its
	-- picture; a click on a row shows the unit in the Units list (host.locate, as the crosshair button does). host: Shared, S(), panelRect(), canShow(), locate(name)
	rst.open = false
	rst.scroll = 0
	local ROW = 44

	local function names()
		return rst.data and rst.data.banned or {}
	end

	function rst.winRect()
		if not rst.open or not host.canShow() then
			return nil
		end
		local S, m = host.S(), host.Shared.m
		local px1, _, _, py1 = host.panelRect()
		local vsx, vsy = Spring.GetViewGeometry()
		local right = px1 - m.HB - 12 * S -- the team strip lies between the window and the menu
		local w = math.min(560 * S, vsx * 0.4)
		local head = m.HB + 2 * m.PAD + 6 * S
		local h = math.min(py1 - vsy * 0.06, head + math.max(1, #names()) * ROW * S + m.PAD)
		return { x1 = math.max(8 * S, right - w), x2 = right, top = py1, y0 = py1 - h, head = head }
	end

	function rst.winAt(mx, my)
		local w = rst.winRect()
		return w ~= nil and mx >= w.x1 and mx <= w.x2 and my >= w.y0 and my <= w.top
	end

	local function closeRect(w)
		local S, m = host.S(), host.Shared.m
		return { x1 = w.x2 - m.PAD - 110 * S, x2 = w.x2 - m.PAD, y0 = w.top - m.PAD - m.HB, y1 = w.top - m.PAD, kind = "rclose", label = "Close", fs = 20 * S,
			tint = { 0.5, 0.15, 0.15 }, tip = "Close this list" }
	end

	local function maxScroll(w)
		return math.max(0, #names() * ROW * host.S() - (w.top - w.head - w.y0))
	end

	-- y of the upper edge of row i
	local function rowTop(w, i)
		return w.top - w.head - (i - 1) * ROW * host.S() + rst.scroll
	end

	function rst.drawWindow()
		local w = rst.winRect()
		if not w then
			return
		end
		local S, m = host.S(), host.Shared.m
		local list = names()
		gl.Color(0.07, 0.07, 0.09, 0.94)
		gl.Rect(w.x1, w.y0, w.x2, w.top)
		gl.Color(0.5, 0.8, 1, 1)
		gl.Text(string.format("Forbidden units (%d)", #list), w.x1 + m.PAD, w.top - m.PAD - m.HB / 2 - 8 * S, 24 * S, "o")
		local close = closeRect(w)
		host.Shared.drawButtons({ close }, 20 * S, m.HB)
		local mx, my = Spring.GetMouseState()
		rst.scroll = math.max(0, math.min(maxScroll(w), rst.scroll))
		gl.Scissor(w.x1, w.y0, w.x2 - w.x1, w.top - w.head - w.y0)
		if #list == 0 then
			gl.Color(0.7, 0.7, 0.7, 1)
			gl.Text("Nothing is forbidden.", w.x1 + m.PAD, w.top - w.head - 30 * S, 22 * S, "o")
		end
		for i, name in ipairs(list) do
			local y1 = rowTop(w, i)
			local y0 = y1 - ROW * S + 3 * S
			if y1 > w.y0 and y0 < w.top then
				local over = mx >= w.x1 and mx <= w.x2 and my >= y0 and my <= y1 and my < w.top - w.head
				gl.Color(0.2, 0.2, 0.2, over and 1 or 0.9)
				gl.Rect(w.x1 + m.PAD, y0, w.x2 - m.PAD, y1 - 3 * S)
				local ud = UnitDefNames[name]
				local pic = (ROW - 8) * S
				if ud then
					gl.Color(1, 1, 1, 1)
					gl.Texture("#" .. ud.id)
					gl.TexRect(w.x1 + m.PAD + 4 * S, y0 + 2 * S, w.x1 + m.PAD + 4 * S + pic, y0 + 2 * S + pic)
					gl.Texture(false)
				end
				gl.Color(1, 1, 1, 1)
				local human = ud and (ud.translatedHumanName or ud.humanName) or name
				gl.Text(string.format("%s (%s)", human, name), w.x1 + m.PAD + pic + 12 * S, y0 + (ROW * S - 3 * S - 22 * S) / 2 + 3 * S, 22 * S, "o")
			end
		end
		gl.Scissor(false)
		host.Shared.drawTip({ close }, mx, my)
		gl.Color(1, 1, 1, 1)
	end

	function rst.winWheel(up)
		local w = rst.winRect()
		if w then
			rst.scroll = math.max(0, math.min(maxScroll(w), rst.scroll - (up and 1 or -1) * 3 * ROW * host.S()))
		end
	end

	function rst.winPress(mx, my, button)
		local w = rst.winRect()
		if not w or button ~= 1 then
			return true
		end
		local c = closeRect(w)
		if mx >= c.x1 and mx <= c.x2 and my >= c.y0 and my <= c.y1 then
			rst.open = false
			return true
		end
		if my < w.top - w.head then
			for i, name in ipairs(names()) do
				local y1 = rowTop(w, i)
				if my <= y1 and my >= y1 - ROW * host.S() + 3 * host.S() then
					host.locate(name)
					break
				end
			end
		end
		return true
	end

	return rst
end
