-- Save page of the Level Editor (button S): the saved levels as a list with a scrollbar, Save as new (with a name field), Save (overwrites at once) and Load
-- (second click confirms) per level, sorted A-Z or by last use. Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_save.lua")) as a function that gets
-- the host (the services of the widget) and returns the page; a file of its own because the widget is close to the limit of 200 local variables.
-- The sort order and the levels used last are kept in LuaUI/Config/LevelEditorSave.lua.
--   host.Shared, host.S() (UI scale), host.say(text), host.outDir ("LevelEditor/"), host.currentLevel(),
--   host.saveLevel(name, quiet) (count of units, nil on failure), host.loadLevel(name), host.runningModes(stop) (a test of a game mode is running; stop = true ends it)
--   Methods: sv.scan(), sv.touch(name) (called by the widget when a level was saved or loaded), sv.layout(rect), sv.height(), sv.draw(rect), sv.press(rect, mx, my), sv.wheel(up),
--   sv.finish(accept) (ends the entry in the name field), sv.key(key), sv.text(utf8char); fields sv.open, sv.edit
return function(host)
	local Shared = host.Shared
	local sv = { open = false, list = {}, lg = { scroll = 0 }, name = "", custom = false, edit = nil, confirm = nil, notice = nil, sort = "name", recent = {}, listRect = nil }
	local FILE = "LuaUI/Config/LevelEditorSave.lua"
	local MIN_ROWS, MAX_ROWS, NAME_MAX, KEEP = 6, 12, 40, 200

	local function save()
		local names = {}
		for _, n in ipairs(sv.recent) do
			names[#names + 1] = string.format("%q", n)
		end
		Shared.writeFile(FILE, "-- Level Editor, page S: sort order of the level list and the levels used last (newest first)\nreturn { sort = " .. string.format("%q", sv.sort)
			.. ", recent = { " .. table.concat(names, ", ") .. " } }\n")
	end

	local function load()
		local text = Shared.fileText(FILE)
		local data = text and Shared.loadData(text)
		if type(data) ~= "table" then
			return
		end
		sv.sort = data.sort == "recent" and "recent" or "name"
		for _, n in ipairs(type(data.recent) == "table" and data.recent or {}) do
			if type(n) == "string" and #sv.recent < KEEP then
				sv.recent[#sv.recent + 1] = n
			end
		end
	end
	load()

	-- A level was saved or loaded: it moves to the front of the levels used last
	function sv.touch(name)
		if not name or name:sub(1, 1) == "_" or sv.recent[1] == name then
			return
		end
		for i = #sv.recent, 1, -1 do
			if sv.recent[i] == name then
				table.remove(sv.recent, i)
			end
		end
		table.insert(sv.recent, 1, name)
		while #sv.recent > KEEP do
			table.remove(sv.recent)
		end
		save()
	end

	-- level_001, level_002 ...: the first name that is free
	local function suggest()
		local taken = {}
		for _, n in ipairs(sv.list) do
			taken[n:lower()] = true
		end
		local n = 1
		while taken[string.format("level_%03d", n)] do
			n = n + 1
		end
		return string.format("level_%03d", n)
	end

	sv.suggest = suggest

	local function visibleRows()
		return math.max(MIN_ROWS, math.min(MAX_ROWS, #sv.list))
	end

	-- the list is the "grid" of the scrollbar of the shared code: .scroll and :maxScroll(rect), in rows
	function sv.lg:maxScroll()
		return math.max(0, #sv.list - visibleRows())
	end

	-- List of the saved levels (LevelEditor/*.lua, without internal files with _ except the autosave _last and _beforeplay), sorted
	function sv.scan()
		local list = {}
		local files = (VFS and VFS.DirList and VFS.DirList(host.outDir, "*.lua", VFS.RAW)) or {}
		for _, path in ipairs(files) do
			local name = path:match("([^/\\]+)%.lua$")
			if name and (name:sub(1, 1) ~= "_" or name == "_last" or name == "_beforeplay") then
				list[#list + 1] = name
			end
		end
		local rank = {}
		for i, n in ipairs(sv.recent) do
			rank[n] = i
		end
		table.sort(list, function(a, b)
			if sv.sort == "recent" then
				local ra, rb = rank[a] or math.huge, rank[b] or math.huge
				if ra ~= rb then
					return ra < rb
				end
			end
			local la, lb = a:lower(), b:lower()
			if la ~= lb then
				return la < lb
			end
			return a < b
		end)
		sv.list = list
		sv.lg.scroll = math.max(0, math.min(sv.lg:maxScroll(), sv.lg.scroll))
		if not sv.edit and (not sv.custom or sv.name == "") then
			sv.name = suggest()
			sv.custom = false
		end
	end

	-- the text cut so that it fits the width (with ... at the end)
	local function fit(text, size, width)
		if gl.GetTextWidth(text) * size <= width then
			return text
		end
		while #text > 1 and gl.GetTextWidth(text .. "...") * size > width do
			text = text:sub(1, -2)
		end
		return text .. "..."
	end

	-- Why a name cannot be used for a new level (nil: it can)
	local function problem(name)
		if name == "" then
			return "Type a name first."
		end
		if name:sub(1, 1) == "_" then
			return "A name must not start with _ (those files are internal)."
		end
		for _, n in ipairs(sv.list) do
			if n:lower() == name:lower() then
				return "There is already a level " .. n .. ": its Save button overwrites it."
			end
		end
		return nil
	end

	local function note(text, color)
		sv.notice = { text = text, color = color or { 1, 0.4, 0.35 }, untilT = os.clock() + 6 }
		host.say(text)
	end

	-- Buttons, labels and bars of the page; returns rects, labels, bars, height
	function sv.layout(rect)
		local S, m = host.S(), Shared.m
		local rects, labels, bars = {}, {}, {}
		local x1, x2 = rect.x1 + m.PAD, rect.x2 - m.PAD
		local y = rect.top - m.PAD
		local gap = 6 * S
		-- name of the new level and the button that saves it
		local bw = 230 * S
		rects[#rects + 1] = { x1 = x1, x2 = x2 - bw - gap, y0 = y - m.HB, y1 = y, kind = "svname", fs = 26 * S, active = sv.edit ~= nil,
			label = fit(sv.edit and (sv.name .. "_") or sv.name, 26 * S, x2 - bw - gap - x1 - 20 * S),
			tip = "Name of the new level: click, type, Enter accepts, Esc undoes.\nLetters, digits, _ and - (at most " .. NAME_MAX .. " characters)." }
		rects[#rects + 1] = { x1 = x2 - bw, x2 = x2, y0 = y - m.HB, y1 = y, kind = "svnew", label = "Save as new", fs = 24 * S, tint = { 0.15, 0.6, 0.2 },
			tip = "Saves the map as a new level under the name in the field" }
		y = y - m.HB - 4 * S
		if sv.notice and os.clock() < sv.notice.untilT then
			labels[#labels + 1] = { text = fit(sv.notice.text, 19 * S, x2 - x1), x = x1, y = y - 18 * S, size = 19 * S, color = sv.notice.color }
		else
			labels[#labels + 1] = { text = "Name: letters, digits, _ and -.  Save overwrites a level without asking.", x = x1, y = y - 18 * S, size = 19 * S, color = { 0.75, 0.75, 0.75 } }
		end
		y = y - 28 * S
		-- sort order
		labels[#labels + 1] = { text = "Saved levels", x = x1, y = y - 34 * S, size = 26 * S, head = true }
		local sw = 130 * S
		rects[#rects + 1] = { x1 = x2 - 2 * sw - gap, x2 = x2 - sw - gap, y0 = y - m.HB, y1 = y, kind = "svsort", value = "name", label = "A-Z", fs = 22 * S, active = sv.sort == "name",
			tip = "Sort the list alphabetically" }
		rects[#rects + 1] = { x1 = x2 - sw, x2 = x2, y0 = y - m.HB, y1 = y, kind = "svsort", value = "recent", label = "Recent", fs = 22 * S, active = sv.sort == "recent",
			tip = "Sort the list by last use: the level saved or loaded last is on top" }
		y = y - m.HB - 6 * S
		-- the list
		local rows = visibleRows()
		local rowH = m.HB + 6 * S
		local first = math.floor(sv.lg.scroll + 0.5)
		local sbw = 34 * S -- room for the scrollbar
		local bw2 = 140 * S
		local cur = host.currentLevel()
		sv.listRect = { x1 = x1, x2 = x2, top = y, y0 = y - rows * rowH }
		bars[#bars + 1] = { x1 = x1, y0 = y - rows * rowH, x2 = x2, y1 = y, color = { 0, 0, 0, 0.3 } }
		for i = 1, rows do
			local name = sv.list[first + i]
			if not name then
				break
			end
			local top = y - (i - 1) * rowH
			local ry1, ry0 = top - 3 * S, top - 3 * S - m.HB
			if name == cur then
				bars[#bars + 1] = { x1 = x1, y0 = ry0 - 3 * S, x2 = x2 - sbw, y1 = ry1 + 3 * S, color = { 0.25, 0.5, 0.8, 0.35 } }
			end
			local lx2 = x2 - sbw - gap - bw2
			local loading = sv.confirm == name
			labels[#labels + 1] = { text = fit(name, 27 * S, lx2 - bw2 - gap - x1 - 24 * S), x = x1 + 12 * S, y = ry0 + (m.HB - 27 * S) / 2 + 3 * S, size = 27 * S, color = { 1, 1, 1 } }
			rects[#rects + 1] = { x1 = lx2 - bw2 - gap, x2 = lx2 - gap, y0 = ry0, y1 = ry1, kind = "svload", name = name, fs = 22 * S, active = loading or nil,
				label = loading and "Sure?" or "Load", tip = "Load the level: replaces everything on the map\n(second click confirms)" }
			rects[#rects + 1] = { x1 = lx2, x2 = lx2 + bw2, y0 = ry0, y1 = ry1, kind = "svsave", name = name, fs = 22 * S, label = "Save",
				tip = "Writes the current state into this level (overwrites it at once)" }
		end
		y = y - rows * rowH - 4 * S
		if #sv.list == 0 then
			labels[#labels + 1] = { text = "No levels saved yet.", x = x1 + 12 * S, y = sv.listRect.top - 36 * S, size = 22 * S, color = { 0.75, 0.75, 0.75 } }
		end
		local last = math.min(#sv.list, first + rows)
		labels[#labels + 1] = { text = #sv.list > rows and string.format("%d-%d of %d (mouse wheel or scrollbar)", first + 1, last, #sv.list) or string.format("%d levels", #sv.list),
			x = x1, y = y - 20 * S, size = 19 * S, color = { 0.75, 0.75, 0.75 } }
		y = y - 28 * S
		return rects, labels, bars, rect.top - y + m.PAD
	end

	-- the page is a little wider than the other pages: room for long names
	function sv.width()
		return math.floor(680 * host.S())
	end

	function sv.height()
		local _, _, _, h = sv.layout({ x1 = 0, x2 = sv.width(), top = 0 })
		return h
	end

	function sv.draw(rect)
		local S = host.S()
		local rects, labels, bars = sv.layout(rect)
		for _, b in ipairs(bars) do
			gl.Color(b.color[1], b.color[2], b.color[3], b.color[4])
			gl.Rect(b.x1, b.y0, b.x2, b.y1)
		end
		Shared.drawButtons(rects, 22 * S, Shared.m.HB)
		for _, l in ipairs(labels) do
			local c = l.head and { 0.5, 0.8, 1 } or l.color or { 1, 1, 1 }
			gl.Color(c[1], c[2], c[3], 1)
			gl.Text(l.text, l.x, l.y, l.size, "o")
		end
		gl.Color(1, 1, 1, 1)
		Shared.scrollbarDraw(sv.lg, sv.listRect)
		local mx, my = Spring.GetMouseState()
		Shared.drawTip(rects, mx, my)
	end

	-- Ends the entry in the name field (accept = false: the name from before comes back)
	function sv.finish(accept)
		local e = sv.edit
		if not e then
			return
		end
		sv.edit = nil
		widgetHandler:DisownText()
		if not accept then
			sv.name = e.old
		end
		sv.custom = sv.name ~= suggest()
	end

	function sv.key(key)
		if key == 13 or key == 271 then
			sv.finish(true)
		elseif key == 27 then
			sv.finish(false)
		elseif key == 8 then
			sv.name = sv.name:sub(1, -2)
		end
		return true
	end

	function sv.text(ch)
		if ch and #ch == 1 and ch:match("^[%w_%-]$") and #sv.name < NAME_MAX then
			sv.name = sv.name .. ch
		end
		return true
	end

	function sv.wheel(up)
		sv.lg.scroll = math.max(0, math.min(sv.lg:maxScroll(), math.floor(sv.lg.scroll + 0.5) + (up and -1 or 1)))
	end

	-- The test of a game mode is running: it is stopped and the state before is back; the button has to be pressed again
	local function stopTest(what)
		if host.runningModes(true) then
			sv.confirm = nil
			note("The test was running: it is stopped and the state before is back. Press " .. what .. " again.", { 1, 0.8, 0.4 })
			return true
		end
		return false
	end

	function sv.press(rect, mx, my)
		local rects = sv.layout(rect)
		if Shared.scrollbarPress(sv.lg, sv.listRect, mx, my) then
			return true
		end
		local hit
		for _, r in ipairs(rects) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		if sv.edit and not (hit and hit.kind == "svname") then
			sv.finish(true)
		end
		if not hit then
			sv.confirm = nil
			return true
		end
		local k = hit.kind
		if k ~= "svload" then
			sv.confirm = nil
		end
		if k == "svname" then
			if not sv.edit then
				sv.edit = { old = sv.name }
				widgetHandler:OwnText()
			end
		elseif k == "svnew" then
			local why = problem(sv.name)
			if why then
				note(why)
			elseif not stopTest("Save as new") then
				local name = sv.name
				if host.saveLevel(name, false) then
					sv.custom = false
					sv.name = ""
					sv.scan()
					note("Saved as " .. name .. ".", { 0.5, 1, 0.5 })
				else
					note("Saving failed.")
				end
			end
		elseif k == "svsave" then
			if not stopTest("Save") then
				if host.saveLevel(hit.name, false) then
					sv.scan()
					note("Saved " .. hit.name .. ".", { 0.5, 1, 0.5 })
				else
					note("Saving failed.")
				end
			end
		elseif k == "svload" then
			if sv.confirm == hit.name then
				sv.confirm = nil
				host.runningModes(true) -- Stop first, then the other level replaces everything
				host.loadLevel(hit.name)
			else
				sv.confirm = hit.name
			end
		elseif k == "svsort" then
			if sv.sort ~= hit.value then
				sv.sort = hit.value
				save()
				sv.lg.scroll = 0
				sv.scan()
			end
		end
		return true
	end

	return sv
end
