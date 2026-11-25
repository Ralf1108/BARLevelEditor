-- Tweaks tab of the Place menu of the Level Editor: tweaked units ("clones"). A tweakunits text (plain Lua or base64) is pasted from the clipboard, checked
-- and kept in a library; a click on an entry arms the base unit, and every unit placed then gets the changed values (gadget unit_tweaks.lua). Entries can be
-- renamed and deleted. The library is the file LevelEditor/_tweaks.lua; a level file carries every entry of the list and those its units use (section tweaks).
-- The box before an entry checks it for "Copy checked" (one tweakunits text for BAR's lobby, plain or base64; one entry per unit type).
-- Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_tweaks.lua")) as a function that gets the host (the services of the widget) and returns
-- the page; a file of its own because the widget is close to the limit of 200 local variables.
--   host.Shared, host.S() (UI scale), host.say(text), host.outDir ("LevelEditor/"), host.armUnit(name) (arms the unit stamp), host.disarm() (ends it),
--   host.menuMode() (the open sub-tab), host.armedUnit(), host.unitName()
--   Methods: tw.layout(rect), tw.height(), tw.draw(rect), tw.press(rect, mx, my), tw.wheel(up), tw.finish(accept), tw.key(key), tw.text(utf8char),
--   tw.placeSuffix() (the end of a "led|place" message while a tweaked unit is armed), tw.hint(), tw.lua(used) (section tweaks of the level file),
--   tw.load(list) (the section of a loaded level), tw.paste(text) (the action of the button; text = nil reads the clipboard), tw.drawLabels(),
--   tw.copyExample() (the example into the clipboard), tw.checkedText(kind) / tw.copyChecked(kind) (the checked entries, kind "text" | "b64"), tw.unitText(name, "units" | "defs") and tw.copyUnit(name, kind) (the values of a unit as text),
--   tw.openUnitMenu(name, mx, my) / tw.openEntryMenu(id, mx, my) / tw.menuRects() / tw.drawMenu() / tw.menuPress(mx, my, button) (the menu of a right
--   click on a unit tile or on an entry), tw.rightPress(rect, mx, my) (a right click in the tab),
--   tw.openEditor(base, entry) / tw.closeEditor() / tw.winRects() / tw.drawWindow() / tw.winPress(mx, my, button) / tw.winWheel(up) (the window of the
--   values, tw.win; it takes every click while it is open); host.showTweaks() opens the Tweaks tab;
--   fields tw.edit, tw.armed
return function(host)
	local Shared = host.Shared
	local T = VFS.Include("luaui/Include/tweak_rules.lua", nil, VFS.ZIP_FIRST)
	local tw = { list = {}, lg = { scroll = 0 }, armed = nil, edit = nil, confirm = nil, notice = nil, listRect = nil, known = {} }
	-- tw.list: the library { id, name, base, text }; tw.known: id -> entry, everything the gadget was told (also entries of a level that are not in the library)
	local FILE = host.outDir .. "_tweaks.lua"
	local ROWS, NAME_MAX = 8, 40
	local YELLOW = { 0.85, 0.68, 0.1 }
	local labels = { at = -1, list = {} } -- the tweaked units on the map, looked up once a second

	local function cleanName(name)
		name = tostring(name or ""):gsub("[^%w _%-%.%(%)]", ""):gsub("^%s+", ""):gsub("%s+$", "")
		return name:sub(1, NAME_MAX)
	end

	local function saveLibrary()
		local out = { "-- Level Editor, tab Tweaks: the library of the tweaked units (id, name in the list, base unit, the tweakunits table of the unit in base64url,\n" ..
			"-- pick = true: checked for Copy checked)\nreturn {\n" }
		for _, e in ipairs(tw.list) do
			out[#out + 1] = string.format("\t{ id = %q, name = %q, base = %q, b64 = %q%s },\n", e.id, e.name, e.base, T.encode64(e.text), e.pick and ", pick = true" or "")
		end
		out[#out + 1] = "}\n"
		Shared.writeFile(FILE, table.concat(out))
	end

	-- an entry of the library file or of a level file: nil when it is not usable
	local function entryOf(raw)
		if type(raw) ~= "table" or type(raw.id) ~= "string" or not raw.id:match("^[%w_]+$") or type(raw.base) ~= "string" or type(raw.b64) ~= "string" then
			return nil
		end
		local text = T.decode64(raw.b64)
		local data = text and T.parse(text)
		if not data or type(data[raw.base]) ~= "table" then
			return nil
		end
		local name = cleanName(raw.name)
		return { id = raw.id, name = name ~= "" and name or raw.id, base = raw.base, text = T.serialize({ [raw.base] = data[raw.base] }), tw = data[raw.base],
			pick = raw.pick == true or nil }
	end

	function tw.libraryText() -- test hook: the library file as it is on disk
		return Shared.fileText(FILE)
	end

	local function loadLibrary()
		local text = Shared.fileText(FILE)
		local data = text and Shared.loadData(text)
		for _, raw in ipairs(type(data) == "table" and data or {}) do
			local e = entryOf(raw)
			if e then
				tw.list[#tw.list + 1] = e
			end
		end
	end
	loadLibrary()

	local function note(text, color)
		tw.notice = { text = text, color = color or { 1, 0.4, 0.35 }, untilT = os.clock() + 8 }
		host.say(text)
	end

	-- what the tweak does to its unit (texts), worked out once per entry
	local function info(e)
		if not e.info then
			e.info = T.check(e.base, e.tw, UnitDefNames[e.base], WeaponDefs)
		end
		return e.info
	end

	-- The gadget learns the definition (again: the name may have changed)
	local function send(e)
		tw.known[e.id] = e
		Spring.SendLuaRulesMsg(string.format("tweak|def|%s|%s|%s|%s", e.id, T.encode64(e.name), e.base, T.encode64(e.text)))
	end

	local function byId(id)
		for i, e in ipairs(tw.list) do
			if e.id == id then
				return e, i
			end
		end
	end

	-- an id nobody has: the base unit and five random characters (a level refers to it, so it never changes and is not given twice)
	local function newId(base)
		local id
		for try = 1, 200 do
			local s = ""
			for _ = 1, try <= 100 and 5 or 8 do
				local d = math.random(0, 35)
				s = s .. string.char(d < 10 and (48 + d) or (87 + d))
			end
			id = base .. "_" .. s
			if not byId(id) and not tw.known[id] then
				break
			end
		end
		return id
	end

	-- A new entry (not in the list yet): the table of one unit, what T.check says about it, a name (nil: the name of the unit and "(tweaked)")
	function tw.newEntry(base, data, check, name)
		local ud = UnitDefNames[base]
		local human = cleanName(ud.translatedHumanName or ud.humanName or base)
		local e = { id = newId(base), name = (name and name ~= "") and name or ((human ~= "" and human or base) .. " (tweaked)"), base = base,
			text = T.serialize({ [base] = data }), tw = data, info = check }
		tw.known[e.id] = e
		return e
	end

	-- the same, put on top of the list
	function tw.addEntry(base, data, check, name)
		local e = tw.newEntry(base, data, check, name)
		table.insert(tw.list, 1, e)
		return e
	end

	-- A tweakunits text (nil: the clipboard) becomes entries of the library, one per unit; returns the number of new entries
	function tw.paste(text)
		text = text or (Spring.GetClipboard and Spring.GetClipboard()) or ""
		local data, err = T.parse(text)
		if not data then
			note("Paste: " .. tostring(err) .. ".")
			return 0
		end
		local made, problems, ignored = {}, {}, 0
		for _, base in ipairs(T.sortedKeys(data)) do
			local ud = UnitDefNames[base]
			local check = T.check(base, data[base], ud, WeaponDefs)
			if #check.errors > 0 then
				problems[#problems + 1] = base .. ": " .. check.errors[1]
			elseif #check.applied == 0 then
				problems[#problems + 1] = base .. ": nothing in it can be changed in a running game"
			else
				made[#made + 1] = tw.newEntry(base, data[base], check)
				ignored = ignored + #check.ignored
			end
		end
		for i = #made, 1, -1 do
			table.insert(tw.list, 1, made[i])
		end
		if #made > 0 then
			saveLibrary()
			tw.lg.scroll = 0
		end
		if #problems > 0 then
			note("Paste: " .. table.concat(problems, "; ") .. (#made > 0 and (" (" .. #made .. " added)") or ""))
		elseif ignored > 0 then
			note(#made .. " tweaked unit" .. (#made == 1 and "" or "s") .. " added; " .. ignored .. " field" .. (ignored == 1 and " is" or "s are") .. " ignored (see the yellow !).", YELLOW)
		else
			note(#made .. " tweaked unit" .. (#made == 1 and "" or "s") .. " added.", { 0.5, 1, 0.5 })
		end
		return #made
	end

	-- A text into the clipboard, with a note
	local function copy(text, what)
		if not Spring.SetClipboard then
			note("This game version cannot write the clipboard.")
			return false
		end
		-- (Windows can hold the clipboard for a moment, e.g. its clipboard history: then the text did not arrive; try once more)
		local function arrived()
			return not Spring.GetClipboard or ((Spring.GetClipboard() or ""):gsub("\r", "")) == (text:gsub("\r", ""))
		end
		Spring.SetClipboard(text)
		if not arrived() then
			Spring.SetClipboard(text)
			if not arrived() then
				note("The clipboard of Windows is busy: click again.")
				return false
			end
		end
		note(what, { 0.5, 1, 0.5 })
		return true
	end

	function tw.copyExample()
		return copy(T.EXAMPLE, "The example (a tweaked Pawn) is in the clipboard: paste it into a text editor, change it, copy it, then Paste here.")
	end

	-- The values a unit has now as text: kind "units" = a tweakunits table, "defs" = tweakdefs program code; nil for an unknown unit
	function tw.unitText(name, kind)
		local ud = UnitDefNames[name]
		if not ud then
			return nil
		end
		local t = T.unitTable(name, ud, WeaponDefs)
		if kind == "defs" then
			return T.defsText(name, t)
		end
		return T.pretty({ [name] = t }) .. "\n"
	end

	function tw.copyUnit(name, kind)
		local text = tw.unitText(name, kind)
		if not text then
			return false
		end
		if kind == "defs" then
			return copy(text, name .. " is in the clipboard as tweakdefs code (for BAR's game option; the Tweaks tab takes tweakunits).")
		end
		return copy(text, name .. " is in the clipboard as a tweakunits text: change the values, then Paste it in the Tweaks tab.")
	end

	-- The checked entries as one tweakunits text (kind "text": plain, one field per line; "b64": base64url for BAR's lobby option tweakunits).
	-- Returns the text and the number of entries, or nil and the reason (nothing checked; two entries change the same unit type).
	function tw.checkedText(kind)
		local t, first, n = {}, {}, 0
		for _, e in ipairs(tw.list) do
			if e.pick then
				if first[e.base] then
					return nil, "Not copied: '" .. first[e.base].name .. "' and '" .. e.name .. "' both change " .. e.base ..
						". A tweakunits text holds one entry per unit type: uncheck one."
				end
				first[e.base], t[e.base], n = e, e.tw, n + 1
			end
		end
		if n == 0 then
			return nil, "Check an entry first (the box before its name): the checked entries are copied."
		end
		if kind == "b64" then
			return T.encode64(T.serialize(t)), n
		end
		return T.pretty(t) .. "\n", n
	end

	function tw.copyChecked(kind)
		local text, n = tw.checkedText(kind)
		if not text then
			note(n)
			return false
		end
		local what = n .. " tweaked unit" .. (n == 1 and " is" or "s are") .. " in the clipboard"
		return copy(text, kind == "b64" and (what .. " as base64: paste it into the game option tweakunits of BAR's lobby.") or (what .. " as a tweakunits text."))
	end

	-- ---------------------------------------------------------------- the menu of a right click
	-- tw.menu = { x, y, items = { { value, label, tip, run } ... } }: a unit tile of the tab Units or an entry of the list
	function tw.openUnitMenu(name, mx, my)
		tw.menu = { x = mx, y = my, items = {
			{ value = "modify", label = "Modify tweakunits", run = function() tw.openEditor(name) end,
				tip = "Opens a window with the values of " .. name .. ": change them,\nthen copy the tweakunits text or create a tweaked unit from it." },
			{ value = "units", label = "Copy as tweakunits", run = function() tw.copyUnit(name, "units") end,
				tip = "The values of " .. name .. " as a tweakunits text into the clipboard.\nChange them in a text editor, then Paste in the Tweaks tab." },
			{ value = "defs", label = "Copy as tweakdefs", run = function() tw.copyUnit(name, "defs") end,
				tip = "The values of " .. name .. " as tweakdefs program code into the clipboard\n(for BAR's game option tweakdefs; the Tweaks tab takes only tweakunits)." },
		} }
	end

	function tw.openEntryMenu(id, mx, my)
		local e = byId(id)
		if not e then
			return
		end
		tw.menu = { x = mx, y = my, items = {
			{ value = "edit", label = "Edit", run = function() tw.openEditor(e.base, e) end,
				tip = "Opens the window with the values of '" .. e.name .. "':\nSave changes this entry and its placed units, Create new clone makes another entry." },
			{ value = "units", label = "Copy as tweakunits", run = function()
				copy(T.pretty({ [e.base] = e.tw }) .. "\n", "'" .. e.name .. "' is in the clipboard as a tweakunits text.")
			end, tip = "The tweakunits text of this entry into the clipboard." },
			{ value = "defs", label = "Copy as tweakdefs", run = function()
				copy(T.defsText(e.base, e.tw), "'" .. e.name .. "' is in the clipboard as tweakdefs code (for BAR's game option).")
			end, tip = "The changed values of this entry as tweakdefs program code into the clipboard\n(for BAR's game option tweakdefs)." },
		} }
	end

	function tw.menuRects()
		local mn = tw.menu
		if not mn then
			return nil
		end
		local S, hb = host.S(), Shared.m.HB
		local w = 300 * S
		local vsx = Spring.GetViewGeometry()
		local x1 = math.max(0, math.min(mn.x, vsx - w))
		local top = math.max(#mn.items * hb + 4 * S, mn.y)
		local rects = {}
		for i, it in ipairs(mn.items) do
			rects[i] = { x1 = x1, x2 = x1 + w, y0 = top - i * hb, y1 = top - (i - 1) * hb, kind = "twmenu", value = it.value, label = it.label, fs = 22 * S, tip = it.tip, run = it.run }
		end
		return rects
	end

	function tw.drawMenu()
		local rects = tw.menuRects()
		if not rects then
			return
		end
		local S = host.S()
		gl.Color(0, 0, 0, 1)
		gl.Rect(rects[1].x1 - 2 * S, rects[#rects].y0 - 2 * S, rects[1].x2 + 2 * S, rects[1].y1 + 2 * S)
		Shared.drawButtons(rects, 22 * S, Shared.m.HB)
		gl.Color(1, 1, 1, 1)
		local mx, my = Spring.GetMouseState()
		Shared.drawTip(rects, mx, my)
	end

	-- A click while the menu is open: closes it; a left click on a line runs it. Returns true when the click was used
	function tw.menuPress(mx, my, button)
		local rects = tw.menuRects()
		if not rects then
			return false
		end
		tw.menu = nil
		if button == 1 then
			for _, r in ipairs(rects) do
				if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
					r.run()
				end
			end
		end
		return true
	end

	-- A right click in the tab: the menu of the entry under the pointer
	function tw.rightPress(rect, mx, my)
		for _, r in ipairs((tw.layout(rect))) do
			if r.kind == "twarm" and mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				tw.finish(true)
				tw.confirm = nil
				tw.openEntryMenu(r.id, mx, my)
			end
		end
		return true
	end

	-- ---------------------------------------------------------------- the window of the values (Modify tweakunits / Edit)
	-- tw.win = { base, id (the entry that is edited, nil = from a unit), name, tw0 (the table of the entry), rows (T.rows), lines (heads and rows), scroll }
	local WROWS = 12

	function tw.openEditor(base, entry)
		local ud = UnitDefNames[base]
		if not ud then
			note("The unit " .. tostring(base) .. " does not exist in this game.")
			return
		end
		tw.finish(true)
		tw.menu, tw.confirm = nil, nil
		local human = cleanName(ud.translatedHumanName or ud.humanName or base)
		local w = { base = base, id = entry and entry.id, name = entry and entry.name or (human ~= "" and human or base), tw0 = entry and entry.tw or {},
			rows = T.rows(base, ud, WeaponDefs, entry and entry.tw or {}), lines = { { head = "Unit" } }, lineOf = {}, scroll = 0 }
		local weapon
		for i, r in ipairs(w.rows) do
			if r.weapon ~= weapon then
				weapon = r.weapon
				w.lines[#w.lines + 1] = { head = "Weapon " .. tostring(weapon) }
			end
			w.lines[#w.lines + 1] = { row = i }
			w.lineOf[i] = #w.lines
		end
		function w:maxScroll()
			return math.max(0, #self.lines - WROWS)
		end
		tw.win = w
	end

	function tw.closeEditor()
		tw.finish(false)
		tw.win = nil
	end

	local function winChanged()
		local n = 0
		for _, r in ipairs(tw.win.rows) do
			if T.rowChanged(r) then
				n = n + 1
			end
		end
		return n
	end

	local function valueText(v)
		if type(v) == "number" then
			return T.numberText(v)
		elseif v == nil then
			return "?"
		end
		return v and "yes" or "no"
	end

	-- Buttons, labels and bars of the window; returns rects, labels, bars, frame
	local function winLayout()
		local w = tw.win
		local S, m = host.S(), Shared.m
		local vsx, vsy = Spring.GetViewGeometry()
		local W, rowH, gap = 1020 * S, m.HB + 4 * S, 6 * S
		local H = 2 * m.PAD + 40 * S + 30 * S + WROWS * rowH + 10 * S + m.HB
		local x1 = math.floor((vsx - W) / 2)
		local top = math.floor((vsy + H) / 2)
		local frame = { x1 = x1, x2 = x1 + W, y0 = top - H, y1 = top }
		local rects, lab, bars = {}, {}, {}
		local ix1, ix2 = x1 + m.PAD + 6 * S, x1 + W - m.PAD - 6 * S
		local y = top - m.PAD
		lab[#lab + 1] = { text = (w.id and ("Edit '" .. w.name .. "'") or ("Modify " .. w.name)) .. "  (" .. w.base .. ")", x = ix1, y = y - 30 * S, size = 27 * S, color = { 1, 0.85, 0.3 } }
		y = y - 40 * S
		local n = winChanged()
		if tw.notice and os.clock() < tw.notice.untilT then
			lab[#lab + 1] = { text = tw.fit(tw.notice.text, 19 * S, ix2 - ix1), x = ix1, y = y - 20 * S, size = 19 * S, color = tw.notice.color }
		else
			lab[#lab + 1] = { text = n .. " value" .. (n == 1 and "" or "s") .. " changed. Click a value and type; Enter accepts, Tab goes to the next one.", x = ix1, y = y - 20 * S, size = 19 * S,
				color = { 0.75, 0.75, 0.75 } }
		end
		y = y - 30 * S
		w.listRect = { x1 = ix1, x2 = ix2, top = y, y0 = y - WROWS * rowH }
		bars[#bars + 1] = { x1 = ix1, y0 = y - WROWS * rowH, x2 = ix2, y1 = y, color = { 0, 0, 0, 0.35 } }
		local first = math.floor(w.scroll + 0.5)
		local vw = 210 * S
		local rx2 = ix2 - 34 * S - gap -- (room for the scrollbar)
		local vx2 = rx2 - m.HB - gap
		for i = 1, WROWS do
			local ln = w.lines[first + i]
			if not ln then
				break
			end
			local ry1 = y - (i - 1) * rowH - 2 * S
			local ry0 = ry1 - m.HB
			local ty = ry0 + (m.HB - 21 * S) / 2
			if ln.head then
				lab[#lab + 1] = { text = ln.head, x = ix1 + 8 * S, y = ty, size = 23 * S, color = { 0.5, 0.8, 1 } }
			else
				local r = w.rows[ln.row]
				local changed = T.rowChanged(r)
				local editing = tw.edit and tw.edit.row == ln.row
				lab[#lab + 1] = { text = r.label .. "  (" .. r.key .. ")", x = ix1 + 28 * S, y = ty, size = 21 * S, color = changed and { 1, 0.85, 0.3 } or { 1, 1, 1 } }
				lab[#lab + 1] = { text = "normal " .. valueText(r.normal), x = vx2 - vw - 200 * S, y = ty, size = 19 * S, color = { 0.65, 0.65, 0.65 } }
				if r.kind == "boolean" then
					rects[#rects + 1] = { x1 = vx2 - vw, x2 = vx2, y0 = ry0, y1 = ry1, kind = "twbool", row = ln.row, label = valueText(r.value), fs = 22 * S,
						tint = changed and { 0.6, 0.48, 0.08 } or nil, tip = "Click switches between yes and no." }
				else
					rects[#rects + 1] = { x1 = vx2 - vw, x2 = vx2, y0 = ry0, y1 = ry1, kind = "twval", row = ln.row, fs = 22 * S, active = editing or nil,
						label = editing and (tw.edit.buf .. "_") or valueText(r.value), tint = (changed and not editing) and { 0.6, 0.48, 0.08 } or nil,
						tip = "Click, type the new value: Enter accepts, Tab accepts and goes to the next value, Esc undoes." }
				end
				if changed then
					rects[#rects + 1] = { x1 = vx2 + gap, x2 = rx2, y0 = ry0, y1 = ry1, kind = "twreset", row = ln.row, label = "x", fs = 22 * S, tip = "Back to the normal value." }
				end
			end
		end
		y = y - WROWS * rowH - 10 * S
		local buttons = w.id and {
			{ "twsave", "Save", "Changes this entry: its placed units get the new values at once." },
			{ "twclone", "Create new clone", "Makes another entry with these values; this entry stays as it is." },
		} or {
			{ "twclone", "Create clone", "Makes a tweaked unit with these values and shows it in the Tweaks tab." },
		}
		buttons[#buttons + 1] = { "twwcopy", "Copy", "The tweakunits text of the changed values into the clipboard\n(nothing changed: all values of the unit)." }
		buttons[#buttons + 1] = { "twresetall", "Reset all", "All values back to the normal ones." }
		buttons[#buttons + 1] = { "twclose", "Close", "Closes the window without saving (also Esc)." }
		local bw = (ix2 - ix1 - (#buttons - 1) * gap) / #buttons
		for i, b in ipairs(buttons) do
			local bx = ix1 + (i - 1) * (bw + gap)
			rects[#rects + 1] = { x1 = bx, x2 = bx + bw, y0 = y - m.HB, y1 = y, kind = b[1], label = b[2], fs = 22 * S, tip = b[3],
				tint = (b[1] == "twsave" or (b[1] == "twclone" and not w.id)) and { 0.15, 0.6, 0.2 } or nil }
		end
		return rects, lab, bars, frame
	end

	function tw.winRects()
		return tw.win and (winLayout()) or nil
	end

	function tw.drawWindow()
		if not tw.win then
			return
		end
		local S = host.S()
		local rects, lab, bars, f = winLayout()
		gl.Color(0.8, 0.65, 0.2, 1)
		gl.Rect(f.x1 - 3 * S, f.y0 - 3 * S, f.x2 + 3 * S, f.y1 + 3 * S)
		gl.Color(0.06, 0.06, 0.09, 1)
		gl.Rect(f.x1, f.y0, f.x2, f.y1)
		for _, b in ipairs(bars) do
			gl.Color(b.color[1], b.color[2], b.color[3], b.color[4])
			gl.Rect(b.x1, b.y0, b.x2, b.y1)
		end
		Shared.drawButtons(rects, 22 * S, Shared.m.HB)
		for _, l in ipairs(lab) do
			gl.Color(l.color[1], l.color[2], l.color[3], 1)
			gl.Text(l.text, l.x, l.y, l.size, "o")
		end
		gl.Color(1, 1, 1, 1)
		Shared.scrollbarDraw(tw.win, tw.win.listRect)
		local mx, my = Spring.GetMouseState()
		Shared.drawTip(rects, mx, my)
	end

	function tw.winWheel(up)
		local w = tw.win
		w.scroll = math.max(0, math.min(w:maxScroll(), math.floor(w.scroll + 0.5) + (up and -2 or 2)))
	end

	-- the entry of a value starts (the line comes into view)
	function tw.editRowAt(i)
		local w = tw.win
		local r = w.rows[i]
		if not r or r.kind ~= "number" then
			return
		end
		local line = w.lineOf[i]
		local first = math.floor(w.scroll + 0.5)
		if line <= first then
			w.scroll = line - 1
		elseif line > first + WROWS then
			w.scroll = line - WROWS
		end
		tw.edit = { row = i, buf = r.value ~= nil and T.numberText(r.value) or "" }
		widgetHandler:OwnText()
	end

	-- the table of the window, or nil with a note when it would change nothing
	local function winTable()
		local w = tw.win
		local t = T.rowsTable(w.rows, w.tw0)
		local check = T.check(w.base, t, UnitDefNames[w.base], WeaponDefs)
		if #check.applied == 0 then
			note("Change a value first: a tweaked unit needs at least one changed value.")
			return nil
		end
		return t, check
	end

	function tw.winPress(mx, my, button)
		local w = tw.win
		local rects = winLayout()
		if button ~= 1 then
			return true
		end
		if Shared.scrollbarPress(w, w.listRect, mx, my) then
			return true
		end
		local hit
		for _, r in ipairs(rects) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		tw.finish(true)
		local k = hit and hit.kind
		if k == "twval" then
			tw.editRowAt(hit.row)
		elseif k == "twbool" then
			w.rows[hit.row].value = not w.rows[hit.row].value
		elseif k == "twreset" then
			w.rows[hit.row].value = w.rows[hit.row].normal
		elseif k == "twresetall" then
			for _, r in ipairs(w.rows) do
				r.value = r.normal
			end
		elseif k == "twclose" then
			tw.closeEditor()
		elseif k == "twwcopy" then
			local t = T.rowsTable(w.rows, w.tw0)
			if next(t) == nil then
				copy(tw.unitText(w.base, "units"), "Nothing is changed: all values of " .. w.base .. " are in the clipboard as a tweakunits text.")
			else
				copy(T.pretty({ [w.base] = t }) .. "\n", "The tweakunits text of the changed values is in the clipboard.")
			end
		elseif k == "twclone" then
			local t, check = winTable()
			if t then
				local e = tw.addEntry(w.base, t, check, w.id and cleanName(w.name:sub(1, NAME_MAX - 5) .. " copy") or nil)
				saveLibrary()
				tw.lg.scroll = 0
				tw.win = nil
				host.showTweaks()
				note("'" .. e.name .. "' created: click it and place it on the map.", { 0.5, 1, 0.5 })
			end
		elseif k == "twsave" then
			local e = byId(w.id)
			local t, check = winTable()
			if t and e then
				e.tw, e.text, e.info = t, T.serialize({ [e.base] = t }), check
				saveLibrary()
				send(e) -- the gadget gives the placed units of this entry the new values
				tw.win = nil
				host.showTweaks()
				note("'" .. e.name .. "' saved: its placed units have the new values.", { 0.5, 1, 0.5 })
			elseif t then
				note("The entry is not in the list any more: use Create new clone.")
			end
		end
		return true
	end

	-- the tweaked unit that is armed right now (the Tweaks tab is open and its base unit is the stamp), or nil
	local function armedEntry()
		local e = tw.armed and tw.known[tw.armed]
		if e and host.menuMode() == "tw" and host.armedUnit() and host.unitName() == e.base then
			return e
		end
	end

	-- the end of a "led|place|name|team|x|z|facing|neutral" message: |indestructible|arena|<tweak id>
	function tw.placeSuffix()
		local e = armedEntry()
		return e and ("|0|0|" .. e.id) or ""
	end

	function tw.hint()
		local e = armedEntry()
		return e and ("Left click places '" .. e.name .. "', right click ends, [ and ] rotate") or "Paste a tweakunits text, then click an entry and place it on the map"
	end

	-- Section tweaks of the level file: every entry of the list and the definitions of the given ids (used = id -> true, the units on the map); nil when there is none
	function tw.lua(used)
		local ids, seen = {}, {}
		for _, e in ipairs(tw.list) do
			tw.known[e.id] = tw.known[e.id] or e
		end
		for id in pairs(used) do
			tw.known[id] = tw.known[id] or byId(id) -- (after a reload of the widget the library still knows it)
		end
		for _, e in ipairs(tw.list) do
			seen[e.id] = true
			ids[#ids + 1] = e.id
		end
		for id in pairs(used) do
			if tw.known[id] and not seen[id] then
				seen[id] = true
				ids[#ids + 1] = id
			end
		end
		if #ids == 0 then
			return nil
		end
		table.sort(ids)
		local out = { "{\n" }
		for _, id in ipairs(ids) do
			local e = tw.known[id]
			out[#out + 1] = string.format("\t\t{ id = %q, name = %q, base = %q, b64 = %q },\n", e.id, e.name, e.base, T.encode64(e.text))
		end
		out[#out + 1] = "\t}"
		return table.concat(out)
	end

	-- The section of a loaded level: its definitions go to the gadget (before the units) and into the library when it does not have them
	function tw.load(list)
		local added = 0
		for _, raw in ipairs(type(list) == "table" and list or {}) do
			local e = entryOf(raw)
			if e then
				local mine = byId(e.id)
				if not mine then
					tw.list[#tw.list + 1] = e
					added = added + 1
				end
				send(e)
			else
				host.say("A tweaked unit of the level is not usable: " .. tostring(type(raw) == "table" and raw.id or raw))
			end
		end
		if added > 0 then
			saveLibrary()
		end
	end

	function tw.lg:maxScroll()
		return math.max(0, #tw.list - ROWS)
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
	tw.fit = fit

	local function lines(list, limit)
		local out = {}
		for i = 1, math.min(#list, limit) do
			out[#out + 1] = "  " .. list[i]
		end
		if #list > limit then
			out[#out + 1] = "  ... and " .. (#list - limit) .. " more"
		end
		return table.concat(out, "\n")
	end

	-- Buttons, labels and bars of the tab; returns rects, labels, bars, height
	function tw.layout(rect)
		local S, m = host.S(), Shared.m
		local rects, lab, bars = {}, {}, {}
		local x1, x2 = rect.x1 + m.PAD, rect.x2 - m.PAD
		local y = rect.top - m.PAD
		local gap = 6 * S
		local ew = 210 * S
		rects[#rects + 1] = { x1 = x2 - m.HB - gap - ew, x2 = x2 - m.HB - gap, y0 = y - m.HB, y1 = y, kind = "twexample", label = "Copy an example", fs = 22 * S,
			tip = "Puts an example into the clipboard: a tweaked Pawn as a tweakunits text.\nPaste it into a text editor to see how it looks, change it, copy it and click Paste.\nA right click on a unit in the tab Units copies the values of that unit." }
		rects[#rects + 1] = { x1 = x1, x2 = x2 - m.HB - 2 * gap - ew, y0 = y - m.HB, y1 = y, kind = "twpaste", label = "Paste tweakunits", fs = 22 * S, tint = { 0.15, 0.6, 0.2 },
			tip = "Copy a tweakunits text first (Ctrl+C in an editor or a browser), then click here.\nPlain Lua ( { armpw = { health = 2000 } } ) or the same in base64.\nEvery unit in it becomes an entry of the list." }
		rects[#rects + 1] = { x1 = x2 - m.HB, x2 = x2, y0 = y - m.HB, y1 = y, kind = "twhelp", label = "!", fs = 30 * S, tint = YELLOW, tip = T.HELP }
		y = y - m.HB - 4 * S
		if tw.notice and os.clock() < tw.notice.untilT then
			lab[#lab + 1] = { text = fit(tw.notice.text, 19 * S, x2 - x1), x = x1, y = y - 18 * S, size = 19 * S, color = tw.notice.color }
		else
			lab[#lab + 1] = { text = "A tweaked unit is the normal unit with changed values (the yellow ! says which).", x = x1, y = y - 18 * S, size = 19 * S, color = { 0.75, 0.75, 0.75 } }
		end
		y = y - 28 * S
		local rowH = m.HB + 6 * S
		local first = math.floor(tw.lg.scroll + 0.5)
		local sbw = 34 * S
		local bw, ww = 120 * S, m.HB
		tw.listRect = { x1 = x1, x2 = x2, top = y, y0 = y - ROWS * rowH }
		bars[#bars + 1] = { x1 = x1, y0 = y - ROWS * rowH, x2 = x2, y1 = y, color = { 0, 0, 0, 0.3 } }
		local armed = armedEntry()
		for i = 1, ROWS do
			local e = tw.list[first + i]
			if not e then
				break
			end
			local top = y - (i - 1) * rowH
			local ry1, ry0 = top - 3 * S, top - 3 * S - m.HB
			local inf = info(e)
			local bx2 = x2 - sbw - gap
			local editing = tw.edit and tw.edit.id == e.id
			local nx2 = bx2 - 2 * (bw + gap) - (ww + gap)
			local known = UnitDefNames[e.base] ~= nil
			local ax1 = x1 + m.HB + gap
			rects[#rects + 1] = { x1 = x1, x2 = x1 + m.HB, y0 = ry0, y1 = ry1, kind = "twpick", id = e.id, label = "", fs = 22 * S, tick = e.pick or nil,
				tint = e.pick and { 0.1, 0.6, 0.15 } or { 0.38, 0.38, 0.4 },
				tip = "Checked: this entry goes into Copy checked (a tweakunits text for BAR's lobby).\nOne entry per unit type: two checked entries of the same unit cannot be copied together.\n" ..
					"The box does not decide what the level keeps: every entry of the list is saved with the level." }
			rects[#rects + 1] = { x1 = ax1, x2 = nx2, y0 = ry0, y1 = ry1, kind = "twarm", id = e.id, fs = 23 * S, active = (armed == e or editing) or nil,
				icon = known and ("#" .. UnitDefNames[e.base].id) or nil,
				label = fit(editing and (tw.edit.buf .. "_") or e.name, 23 * S, nx2 - ax1 - m.HB - 16 * S),
				tip = known and (e.name .. "  (" .. e.base .. ")\n" .. lines(inf.applied, 14) .. "\nClick, then place it on the map. Right click: edit the values, copy the text.") or ("The unit " .. e.base .. " does not exist in this game.") }
			if #inf.ignored > 0 or not known then
				rects[#rects + 1] = { x1 = nx2 + gap, x2 = nx2 + gap + ww, y0 = ry0, y1 = ry1, kind = "twwarn", label = "!", fs = 28 * S, tint = YELLOW,
					tip = known and ("Ignored, cannot be changed in a running game:\n" .. lines(inf.ignored, 16)) or ("The unit " .. e.base .. " does not exist in this game.") }
			end
			rects[#rects + 1] = { x1 = bx2 - 2 * bw - gap, x2 = bx2 - bw - gap, y0 = ry0, y1 = ry1, kind = "twname", id = e.id, fs = 21 * S, label = "Rename", active = editing or nil,
				tip = "Give the entry another name: click, type, Enter accepts, Esc undoes.\nThe name is for the list; the unit itself stays " .. e.base .. "." }
			rects[#rects + 1] = { x1 = bx2 - bw, x2 = bx2, y0 = ry0, y1 = ry1, kind = "twdel", id = e.id, fs = 21 * S, label = tw.confirm == e.id and "Sure?" or "Delete",
				active = tw.confirm == e.id or nil, tip = "Removes the entry from the list (second click confirms).\nUnits already placed keep their values." }
		end
		y = y - ROWS * rowH - 4 * S
		if #tw.list == 0 then
			lab[#lab + 1] = { text = "No tweaked units yet.", x = x1 + 12 * S, y = tw.listRect.top - 36 * S, size = 22 * S, color = { 0.75, 0.75, 0.75 } }
		end
		local last = math.min(#tw.list, first + ROWS)
		lab[#lab + 1] = { text = #tw.list > ROWS and string.format("%d-%d of %d (mouse wheel or scrollbar)", first + 1, last, #tw.list) or string.format("%d tweaked units", #tw.list),
			x = x1, y = y - 20 * S, size = 19 * S, color = { 0.75, 0.75, 0.75 } }
		y = y - 28 * S
		local cw = (x2 - x1 - gap) / 2
		rects[#rects + 1] = { x1 = x1, x2 = x1 + cw, y0 = y - m.HB, y1 = y, kind = "twcopytext", label = "Copy checked as text", fs = 22 * S,
			tip = "The checked entries as one tweakunits text into the clipboard (readable, one value per line).\nOne entry per unit type." }
		rects[#rects + 1] = { x1 = x2 - cw, x2 = x2, y0 = y - m.HB, y1 = y, kind = "twcopyb64", label = "Copy checked as base64", fs = 22 * S,
			tip = "The checked entries as one tweakunits text in base64 into the clipboard:\npaste it into the game option tweakunits of BAR's lobby (every unit of that type changes).\nOne entry per unit type." }
		y = y - m.HB - 6 * S
		return rects, lab, bars, rect.top - y + m.PAD
	end

	function tw.height()
		local _, _, _, h = tw.layout({ x1 = 0, x2 = 600, top = 0 })
		return h
	end

	function tw.draw(rect)
		local S = host.S()
		local rects, lab, bars = tw.layout(rect)
		for _, b in ipairs(bars) do
			gl.Color(b.color[1], b.color[2], b.color[3], b.color[4])
			gl.Rect(b.x1, b.y0, b.x2, b.y1)
		end
		Shared.drawButtons(rects, 22 * S, Shared.m.HB)
		for _, l in ipairs(lab) do
			local c = l.color or { 1, 1, 1 }
			gl.Color(c[1], c[2], c[3], 1)
			gl.Text(l.text, l.x, l.y, l.size, "o")
		end
		gl.Color(1, 1, 1, 1)
		Shared.scrollbarDraw(tw.lg, tw.listRect)
		local mx, my = Spring.GetMouseState()
		Shared.drawTip(rects, mx, my)
	end

	-- Ends the entry of a name or of a value of the window (accept = false: what was there before stays)
	function tw.finish(accept)
		local ed = tw.edit
		if not ed then
			return
		end
		tw.edit = nil
		widgetHandler:DisownText()
		if ed.row then
			local r = tw.win and tw.win.rows[ed.row]
			local v = tonumber(ed.buf)
			if accept and r and v then
				r.value = v
			end
			return
		end
		local e = byId(ed.id)
		local name = cleanName(ed.buf)
		if accept and e and name ~= "" and name ~= e.name then
			e.name = name
			saveLibrary()
			if tw.known[e.id] then
				send(e)
			end
		end
	end

	function tw.key(key)
		if key == 13 or key == 271 then
			tw.finish(true)
		elseif key == 27 then
			tw.finish(false)
		elseif key == 9 and tw.edit.row then -- Tab: the next value
			local i = tw.edit.row
			tw.finish(true)
			for j = i + 1, #tw.win.rows do
				if tw.win.rows[j].kind == "number" then
					tw.editRowAt(j)
					break
				end
			end
		elseif key == 8 then
			tw.edit.buf = tw.edit.buf:sub(1, -2)
		end
		return true
	end

	function tw.text(ch)
		if tw.edit.row then
			if ch and #ch == 1 and ch:match("^[%d%.%-]$") and #tw.edit.buf < 14 then
				tw.edit.buf = tw.edit.buf .. ch
			end
			return true
		end
		if ch and #ch == 1 and ch:match("^[%w _%-%.%(%)]$") and #tw.edit.buf < NAME_MAX then
			tw.edit.buf = tw.edit.buf .. ch
		end
		return true
	end

	function tw.wheel(up)
		tw.lg.scroll = math.max(0, math.min(tw.lg:maxScroll(), math.floor(tw.lg.scroll + 0.5) + (up and -1 or 1)))
	end

	function tw.press(rect, mx, my)
		local rects = tw.layout(rect)
		if Shared.scrollbarPress(tw.lg, tw.listRect, mx, my) then
			return true
		end
		local hit
		for _, r in ipairs(rects) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		if tw.edit and not (hit and hit.kind == "twname" and hit.id == tw.edit.id) then
			tw.finish(true)
		end
		local k = hit and hit.kind
		if k ~= "twdel" then
			tw.confirm = nil
		end
		if k == "twpaste" then
			tw.paste()
		elseif k == "twexample" then
			tw.copyExample()
		elseif k == "twcopytext" then
			tw.copyChecked("text")
		elseif k == "twcopyb64" then
			tw.copyChecked("b64")
		elseif k == "twpick" then
			local e = byId(hit.id)
			if e then
				e.pick = (not e.pick) or nil
				saveLibrary()
			end
		elseif k == "twarm" then
			local e = byId(hit.id)
			if e and UnitDefNames[e.base] then
				send(e)
				host.armUnit(e.base)
				tw.armed = e.id
			elseif e then
				note("The unit " .. e.base .. " does not exist in this game.")
			end
		elseif k == "twname" then
			local e = byId(hit.id)
			if e and not tw.edit then
				tw.edit = { id = e.id, buf = e.name }
				widgetHandler:OwnText()
			end
		elseif k == "twdel" then
			if tw.confirm == hit.id then
				local _, i = byId(hit.id)
				tw.confirm = nil
				if i then
					if tw.armed == hit.id then
						tw.armed = nil
						host.disarm()
					end
					table.remove(tw.list, i)
					saveLibrary()
					tw.lg.scroll = math.max(0, math.min(tw.lg:maxScroll(), tw.lg.scroll))
				end
			else
				tw.confirm = hit.id
			end
		end
		return true
	end

	-- The names of the tweaked units above them on the map (at most 60, looked up once a second)
	function tw.drawLabels()
		local now = os.clock()
		if now - labels.at > 1 then
			labels.at, labels.list = now, {}
			if next(tw.known) ~= nil then
				for _, id in ipairs(Spring.GetAllUnits()) do
					local t = Spring.GetUnitRulesParam(id, "ledtweak")
					if t then
						labels.list[#labels.list + 1] = { id = id, name = (tw.known[t] and tw.known[t].name) or Spring.GetUnitRulesParam(id, "ledtweakname") or tostring(t) }
					end
				end
			end
		end
		local S, n = host.S(), 0
		for _, l in ipairs(labels.list) do
			if n >= 60 then
				break
			end
			if Spring.ValidUnitID(l.id) and Spring.IsUnitInView(l.id) then
				local x, y, z = Spring.GetUnitPosition(l.id)
				local sx, sy, sz = Spring.WorldToScreenCoords(x, y + (Spring.GetUnitHeight(l.id) or 30) + 12, z)
				if sz and sz < 1 then
					gl.Color(1, 0.85, 0.3, 1)
					gl.Text(l.name, sx, sy, 17 * S, "co")
					n = n + 1
				end
			end
		end
		gl.Color(1, 1, 1, 1)
	end

	return tw
end
