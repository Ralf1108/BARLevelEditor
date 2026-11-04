-- Scenario info page of the Level Editor (button I): title, author, summary, briefing, win condition, grace period and ID of the scenario.
-- Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_scenario.lua")) as a function that gets the host and returns the page `si`:
-- si.data (the scenario info of the loaded level or the one made in the game, nil if none), si.dirty (changed in the game: saving writes this state
-- instead of the block of the file), si.edit (the text field being edited: { row, buf }) and the functions si.layout(rect), si.draw(rect),
-- si.press(rect, mx, my), si.key(key, mods), si.text(ch), si.finish(accept), si.height().
-- The page T (teams) shares the button column slot and the panel with this page; the widget decides which of the two is shown.
--   host.Shared, host.S() (UI scale)
return function(host)
	local Shared = host.Shared
	local si = { data = nil, dirty = false, edit = nil }

	local WIN_NEXT = { com = "killall", killall = "neverend", neverend = "com" }
	local WIN_TXT = { com = "Commanders", killall = "All units", neverend = "No end" }

	function si.rows()
		local rows = {
			{ id = "title", label = "Title", kind = "text", max = 80 },
			{ id = "author", label = "Author", kind = "text", max = 60 },
			{ id = "summary", label = "Summary", kind = "text", max = 200 },
			{ id = "briefing", label = "Briefing", kind = "text", max = 800, multi = true },
		}
		rows[#rows + 1] = { id = "win", label = "Win condition", kind = "cycle" }
		rows[#rows + 1] = { id = "grace", label = "Grace period (min:sec)", kind = "time", max = 6 }
		rows[#rows + 1] = { id = "sid", label = "ID", kind = "id", max = 24 }
		return rows
	end

	-- current value of a field (text), with the defaults of the scenario maker
	function si.value(row)
		local sc = si.data or {}
		if row.id == "win" then
			return sc.win or "com"
		elseif row.id == "grace" then
			local g = tonumber(sc.grace) or 0
			if g <= 0 then
				return "0"
			end
			local total = math.floor(g * 60 + 0.5)
			return string.format("%d:%02d", math.floor(total / 60), total % 60)
		end
		local v = sc[row.id]
		return type(v) == "string" and v or ""
	end

	function si.set(row, value)
		si.data = si.data or {}
		if row.kind == "num" then
			si.data[row.id] = tonumber(value) or 0
		elseif row.kind == "time" then
			-- "2:30" (minutes:seconds), "2,5" or "3" -> minutes as a number
			local m, sec = value:match("^(%d+):(%d%d?)$")
			local minutes = m and (tonumber(m) + math.min(59, tonumber(sec)) / 60) or tonumber((value:gsub(",", "."))) or 0
			si.data[row.id] = math.max(0, math.min(120, math.floor(minutes * 60 + 0.5) / 60))
		elseif value == "" then
			si.data[row.id] = nil
		else
			si.data[row.id] = value
		end
		si.dirty = true
	end

	local function rowH()
		return Shared.m.HB * 0.85
	end

	function si.height()
		return 44 * host.S() + (#si.rows() + 2) * (rowH() + 5 * host.S()) + Shared.m.PAD
	end

	-- Rows and button of the scenario page (button I)
	function si.layout(rect)
		local S, m = host.S(), Shared.m
		local rh = rowH()
		local gap = 5 * S
		local rects = {}
		local y = rect.top - 40 * S
		local vx1 = rect.x1 + (rect.x2 - rect.x1) * 0.36
		for _, row in ipairs(si.rows()) do
			rects[#rects + 1] = { x1 = vx1, x2 = rect.x2 - m.PAD, y0 = y - rh, y1 = y, row = row, labelX = rect.x1 + m.PAD }
			y = y - rh - gap
		end
		return rects
	end

	local function dropLastChar(t)
		return (t:gsub("[%z\1-\127\194-\244][\128-\191]*$", "", 1))
	end

	local function dropFirstChar(t)
		return (t:gsub("^[%z\1-\127\194-\244][\128-\191]*", "", 1))
	end

	local function display(row)
		local v
		if si.edit and si.edit.row.id == row.id and si.edit.row.team == row.team then
			v = si.edit.buf
		elseif row.id == "win" then
			v = WIN_TXT[si.value(row)] or si.value(row)
		else
			v = si.value(row)
		end
		return (v:gsub("\n", " / "))
	end

	function si.draw(rect)
		local S, m = host.S(), Shared.m
		gl.Color(0.5, 0.8, 1, 1)
		gl.Text("Scenario (written with the level when saving)", rect.x1 + m.PAD, rect.top - 30 * S, 22 * S, "o")
		local rects = si.layout(rect)
		local fs = 22 * S
		for _, r in ipairs(rects) do
			if r.row then
				local editing = si.edit and si.edit.row.id == r.row.id and si.edit.row.team == r.row.team
				gl.Color(1, 1, 1, 0.9)
				gl.Text(r.row.label, r.labelX, r.y0 + (r.y1 - r.y0 - fs) / 2 + 3 * S, fs, "o")
				if editing then
					gl.Color(0.25, 0.5, 1, 0.85)
				elseif r.row.kind == "cycle" then
					gl.Color(0.2, 0.2, 0.2, 0.9)
				else
					gl.Color(0.08, 0.08, 0.08, 0.95)
				end
				gl.Rect(r.x1, r.y0, r.x2, r.y1)
				local text = display(r.row)
				local avail = (r.x2 - r.x1) - 12 * S
				if editing then
					text = text .. "_"
					while text ~= "" and (tonumber(gl.GetTextWidth(text)) or 0) * fs > avail do
						text = dropFirstChar(text) -- while typing the end stays visible
					end
				else
					local cut = false
					while text ~= "" and (tonumber(gl.GetTextWidth(text .. (cut and "..." or ""))) or 0) * fs > avail do
						text = dropLastChar(text)
						cut = true
					end
					if cut then
						text = text .. "..."
					end
				end
				gl.Color(1, 1, 1, 1)
				gl.Text(text, r.x1 + 6 * S, r.y0 + (r.y1 - r.y0 - fs) / 2 + 3 * S, fs, "o")
			end
		end
		gl.Color(0.7, 0.7, 0.7, 1)
		local last = rects[#rects]
		gl.Text("Click a field to type: Enter done, Esc cancel,", rect.x1 + m.PAD, last.y0 - 22 * S, 17 * S, "o")
		gl.Text("Shift+Enter = new line in the briefing. Scenario package: start menu key 3.", rect.x1 + m.PAD, last.y0 - 42 * S, 17 * S, "o")
		gl.Color(1, 1, 1, 1)
	end

	function si.finish(accept)
		local e = si.edit
		if not e then
			return
		end
		si.edit = nil
		widgetHandler:DisownText()
		if accept then
			local v = e.buf
			if e.row.kind == "id" then
				v = v:lower():gsub("[^a-z0-9]", "")
			end
			if v ~= si.value(e.row) then
				si.set(e.row, v)
			end
		end
	end

	function si.press(rect, mx, my)
		for _, r in ipairs(si.layout(rect)) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				si.finish(true)
				if r.row then
					local row = r.row
					if row.kind == "cycle" then
						si.set(row, WIN_NEXT[si.value(row)] or si.value(row))
					else
						si.edit = { row = row, buf = si.value(row) }
						widgetHandler:OwnText()
					end
				end
				return true
			end
		end
		si.finish(true)
		return true
	end

	-- Keys while a field is being edited: Enter done, Esc cancel, Backspace deletes
	function si.key(key, mods)
		if key == 13 or key == 271 then
			if mods and mods.shift and si.edit.row.multi then
				if #si.edit.buf < si.edit.row.max then
					si.edit.buf = si.edit.buf .. "\n"
				end
			else
				si.finish(true)
			end
		elseif key == 27 then
			si.finish(false)
		elseif key == 8 then
			si.edit.buf = dropLastChar(si.edit.buf)
		end
		return true
	end

	function si.text(ch)
		local e = si.edit
		if not e or not ch or ch == "" or ch:byte(1) < 32 then
			return false
		end
		if e.row.kind == "num" then
			if not ch:match("^%d$") or #e.buf >= e.row.max then
				return true
			end
		elseif e.row.kind == "time" then
			if not ch:match("^[%d:.,]$") or #e.buf >= e.row.max then
				return true
			end
		elseif e.row.kind == "id" then
			ch = ch:lower()
			if not ch:match("^[a-z0-9]$") or #e.buf >= e.row.max then
				return true
			end
		elseif #e.buf + #ch > e.row.max then
			return true
		end
		e.buf = e.buf .. ch
		return true
	end

	return si
end
