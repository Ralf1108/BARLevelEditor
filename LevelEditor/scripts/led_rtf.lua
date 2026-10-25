-- Reclaim the Fame page of the Level Editor (button RF): settings, buttons to place the crystals, test run.
-- The game itself is run by the gadget rtf_game.lua. Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_rtf.lua")) as a
-- function that gets the host (the services of the widget) and returns the page; a file of its own because the widget is close to
-- the limit of 200 local variables. The settings (rtf.data) are saved in their own section reclaim of the level file. The nodes themselves
-- are features (pilha_crystal1/2/3), placed like any other feature and saved with the level.
--   host.Shared, host.cfg (settings of the widget: size of the lists), host.S() (UI scale), host.say(text), host.canEdit(), host.serialize(table),
--   host.armFeature(name) (arms placing of a feature), host.armedFeature() (name of the armed feature or false), host.disarmAll() (ends all modes when a test starts), host.excludeOthers() (switches Tower Defense and Capture the Flag off),
--   host.restrictStart() / host.restrictStop() (the restrictions of the level), host.beforePlay() / host.afterPlay() (state before the test: saved and brought back)
return function(host)
	local Shared = host.Shared
	local rtf = { open = false, edit = nil, data = nil, notice = nil, sizeFilter = 0 } -- sizeFilter: 0 = all crystals, 1 / 2 / 3 = only small / medium / large
	local LIMITS = { score = { 0, 9999999 }, rate = { 1, 10000 }, f1 = { 0, 100000 }, f2 = { 0, 100000 }, f3 = { 0, 100000 } }

	function rtf.new()
		return { enabled = false, score = 100000, rate = 100, f1 = 100, f2 = 200, f3 = 400, visible = true, statics = false, ground = true, ships = true, air = false }
	end
	rtf.DEFAULT = rtf.new()

	-- Settings without write: the stored ones or the defaults (never changed by the caller); with write they are created
	function rtf.cfg(write)
		if type(rtf.data) == "table" then
			return rtf.data
		end
		if not write then
			return rtf.DEFAULT
		end
		rtf.data = rtf.new()
		return rtf.data
	end

	function rtf.lua()
		return host.serialize(rtf.data)
	end

	-- The tile list of the crystals at the bottom of the page: the list of the Features tab of the Place menu, only the kind "crystal"
	-- (every color, small / medium / large: the digit at the end of the name)
	function rtf.grid()
		if not rtf.tiles then
			local grid = Shared.newFeatures({ cfg = host.cfg, ownText = function() end })
			grid.kind = "crystal"
			-- ordered by size (all small ones first, then the medium and the large ones, each by color) and filtered by the size buttons
			local all = grid.list
			function grid:list()
				if self.shownFilter ~= rtf.sizeFilter or not self.shown then
					local out, sorted = {}, all(self)
					for size = 1, 3 do
						if rtf.sizeFilter == 0 or rtf.sizeFilter == size then
							for _, e in ipairs(sorted) do
								if e.name:match("([123])$") == tostring(size) then
									out[#out + 1] = e
								end
							end
						end
					end
					self.shown, self.shownFilter = out, rtf.sizeFilter
				end
				return self.shown
			end
			rtf.tiles = grid
		end
		return rtf.tiles
	end

	-- Number of small, medium and large crystals on the map (every feature pilha_crystal[_color]<1|2|3>); counted at most twice a second
	function rtf.counts()
		local now = os.clock()
		if rtf.countedAt and now - rtf.countedAt < 0.5 then
			return rtf.counted
		end
		local c = { 0, 0, 0 }
		for _, id in ipairs(Spring.GetAllFeatures()) do
			local fd = FeatureDefs[Spring.GetFeatureDefID(id)]
			local d = fd and fd.name and fd.name:match("^pilha_crystal[%a_]*([123])$")
			if d then
				c[tonumber(d)] = c[tonumber(d)] + 1
			end
		end
		rtf.countedAt, rtf.counted = now, c
		return c
	end

	-- Buttons and labels of the page; returns rects, labels, height
	function rtf.layout(rect)
		local S, m = host.S(), Shared.m
		local c = rtf.cfg()
		local rects, labels = {}, {}
		local x1, x2 = rect.x1 + m.PAD, rect.x2 - m.PAD
		local y = rect.top - m.PAD
		local gap = 4 * S
		local function line(items)
			local total = 0
			for _, it in ipairs(items) do
				total = total + (it.w or 1)
			end
			local avail, bx = x2 - x1 - gap * (#items - 1), x1
			for _, it in ipairs(items) do
				local w = avail * (it.w or 1) / total
				rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = it.kind, value = it.value, label = it.label, active = it.active,
					fs = it.fs or 22 * S, field = it.field, tint = it.tint, tip = it.tip }
				bx = bx + w + gap
			end
			y = y - m.HB - 6 * S
		end
		local function head(text)
			labels[#labels + 1] = { text = text, x = x1, y = y - 26 * S, size = 22 * S, head = true }
			y = y - 32 * S
		end
		local function note(text, color)
			labels[#labels + 1] = { text = text, x = x1, y = y - 18 * S, size = 19 * S, color = color }
			y = y - 24 * S
		end
		local function num(field)
			return (rtf.edit and rtf.edit.field == field) and (rtf.edit.buf .. "_") or tostring(c[field])
		end
		local function field(name, tip)
			return { kind = "rtfedit", field = name, label = num(name), active = rtf.edit ~= nil and rtf.edit.field == name, tip = tip }
		end
		local function box(kind, on, text, tip)
			return { kind = kind, label = (on and "[x] " or "[ ] ") .. text, active = on, tip = tip }
		end
		-- the switch of the mode is the first thing on the page
		line({ { kind = "rtfon", label = (c.enabled and "[x] " or "[ ] ") .. "Reclaim the Fame", active = c.enabled, tint = c.enabled and { 0.15, 0.6, 0.2 } or nil,
			tip = "Switch Reclaim the Fame on or off for this level (saved in the level file, section reclaim)" } })
		y = y - 6 * S
		local n = rtf.counts()
		local total = n[1] + n[2] + n[3]
		note(string.format("On the map: %d small, %d medium, %d large", n[1], n[2], n[3]), { 0.8, 0.8, 0.8 })
		if total > 1 and total % 2 == 0 then
			note("Even number: both sides can farm in peace. Use an odd one.", { 1, 0.8, 0.4 })
		end
		head("Points factor in % (small / medium / large)")
		line({
			field("f1", "Points factor of a small crystal in percent. 100 = the basic rate. Click, type a number, Enter accepts"),
			field("f2", "Points factor of a medium crystal in percent. Click, type a number, Enter accepts"),
			field("f3", "Points factor of a large crystal in percent. Click, type a number, Enter accepts"),
		})
		head("Score limit of a team (0 = never)")
		line({ field("score", "The first team (alliance) that reaches this many points wins. 0: the level does not end. Click, type a number, Enter accepts") })
		head("Rate in % of the basic rate")
		line({ field("rate", "100 = a construction unit that reclaims a crystal earns 1 point per second for every 100 build power. The factor of the crystal comes on top. Click, type a number, Enter accepts") })
		line({ box("rtfvisible", c.visible ~= false, "Crystals always visible on the map",
			"On: the crystals are shown on the whole map and the minimap, also without radar or a unit nearby. Off: only what a unit sees.") })
		head("Builders that score")
		line({
			{ kind = "rtfcat", value = "statics", label = (c.statics and "[x] " or "[ ] ") .. "Buildings", active = c.statics, fs = 19 * S,
				tip = "Buildings that can reclaim (nano turrets) earn points. Off by default: a ring of cheap nano turrets would farm a crystal without any builder to hunt." },
			{ kind = "rtfcat", value = "ground", label = (c.ground and "[x] " or "[ ] ") .. "Ground", active = c.ground, fs = 19 * S,
				tip = "Ground builders earn points: bots, vehicles, hovercraft and amphibious vehicles (on by default)." },
			{ kind = "rtfcat", value = "ships", label = (c.ships and "[x] " or "[ ] ") .. "Ships", active = c.ships, fs = 19 * S,
				tip = "Ships and submarines that build earn points (on by default)." },
			{ kind = "rtfcat", value = "air", label = (c.air and "[x] " or "[ ] ") .. "Air", active = c.air, fs = 19 * S,
				tip = "Builder aircraft and seaplanes earn points. Off by default: they reach a crystal from anywhere and ignore the space around it." },
		})
		y = y - 6 * S
		-- very bottom: the button that starts the test (red message above it: what is missing)
		local state = Spring.GetGameRulesParam("rtfState") or ""
		local running = state == "running"
		if rtf.notice and os.clock() < rtf.notice.untilT then
			note(rtf.notice.text, { 1, 0.4, 0.35 })
		end
		y = y - 8 * S
		line({ { kind = "rtfplay", label = running and "Stop" or (state ~= "" and "Reset" or "Start test"), active = running, fs = 26 * S,
			tint = running and { 0.8, 0.15, 0.15 } or { 0.15, 0.6, 0.2 },
			tip = "Start test: runs the game in the editor (the state before is saved as _beforeplay). Stop / Reset ends it and brings that state back." } })
		-- very bottom: the crystals to place (like the tower list of the Tower Defense page)
		y = y - 4 * S
		head("Crystals: click a tile, then click the map to place")
		line({
			{ kind = "rtfsize", value = 0, label = "All", active = rtf.sizeFilter == 0, tip = "Show all crystals, ordered by size" },
			{ kind = "rtfsize", value = 1, label = "Small", active = rtf.sizeFilter == 1, tip = "Only the small crystals (pilha_crystal1 and its colors)" },
			{ kind = "rtfsize", value = 2, label = "Medium", active = rtf.sizeFilter == 2, tip = "Only the medium crystals (pilha_crystal2 and its colors)" },
			{ kind = "rtfsize", value = 3, label = "Large", active = rtf.sizeFilter == 3, tip = "Only the large crystals (pilha_crystal3 and its colors)" },
		})
		local grid = rtf.grid()
		local probe = { x1 = rect.x1, x2 = rect.x2, top = 0, y0 = 0 }
		local rows = math.ceil(#grid:list() / grid:colsFor(probe))
		local _, iy1 = grid:geom(probe, 1)
		local gridH = rows * (-iy1 - m.UPAD) + 2 * m.UPAD -- the rows of tiles, no scrolling
		rtf.gridRect = { x1 = rect.x1, x2 = rect.x2, top = y, y0 = y - gridH }
		y = y - gridH
		return rects, labels, rect.top - y
	end

	function rtf.height()
		local _, _, h = rtf.layout({ x1 = 0, x2 = math.floor(560 * host.S()), top = 0 })
		return h
	end

	function rtf.draw(rect)
		local S = host.S()
		local rects, labels = rtf.layout(rect)
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
		rtf.grid():draw(rtf.gridRect, mx, my, host.armedFeature(), true)
		Shared.drawTip(rects, mx, my)
	end

	-- Ends the entry in a number field (accept: take the value)
	function rtf.finish(accept)
		local e = rtf.edit
		if not e then
			return
		end
		rtf.edit = nil
		widgetHandler:DisownText()
		local v = tonumber(e.buf)
		if accept and v then
			local lim = LIMITS[e.field]
			rtf.cfg(true)[e.field] = math.max(lim[1], math.min(lim[2], math.floor(v)))
		end
	end

	function rtf.key(key)
		if key == 13 or key == 271 then
			rtf.finish(true)
		elseif key == 27 then
			rtf.finish(false)
		elseif key == 8 then
			rtf.edit.buf = rtf.edit.buf:sub(1, -2)
		end
		return true
	end

	function rtf.text(ch)
		if ch and ch:match("^%d$") and #rtf.edit.buf < 7 then
			rtf.edit.buf = rtf.edit.buf .. ch
		end
		return true
	end

	-- Payload for the gadget (see rtf_game.lua); nil and a message if something is missing
	function rtf.payload()
		local c = rtf.cfg()
		local n = rtf.counts()
		if n[1] + n[2] + n[3] == 0 then
			return nil, "Place at least one crystal first."
		end
		local cats = (c.statics and "1" or "0") .. (c.ground and "1" or "0") .. (c.ships and "1" or "0") .. (c.air and "1" or "0")
		return table.concat({ c.rate, c.score, c.f1, c.f2, c.f3, c.visible ~= false and "1" or "0", cats }, ";")
	end

	function rtf.press(rect, mx, my)
		local hit
		local rects = rtf.layout(rect)
		for _, r in ipairs(rects) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		rtf.finish(true)
		if not hit then
			local grid = rtf.grid()
			local i = grid:at(rtf.gridRect, mx, my)
			if i and my <= rtf.gridRect.top and my >= rtf.gridRect.y0 then
				host.armFeature(grid:list()[i].name)
			end
			return true
		end
		local k = hit.kind
		if k == "rtfplay" then
			rtf.toggle()
		elseif k == "rtfedit" then
			rtf.edit = { field = hit.field, buf = "" }
			widgetHandler:OwnText()
		elseif k == "rtfsize" then
			rtf.sizeFilter = hit.value
		else
			local c = rtf.cfg(true)
			if k == "rtfon" then
				c.enabled = not c.enabled
				if c.enabled then
					host.excludeOthers()
				end
			elseif k == "rtfvisible" then
				c.visible = not (c.visible ~= false)
			elseif k == "rtfcat" then
				c[hit.value] = not c[hit.value]
			end
		end
		return true
	end

	-- Play / Stop: runs the game in the editor; the state before is saved as _beforeplay and comes back on Stop
	function rtf.toggle()
		local state = Spring.GetGameRulesParam("rtfState")
		if state and state ~= "" then
			Spring.SendLuaRulesMsg("rtf|stop")
			host.restrictStop()
			host.afterPlay()
			host.say("Stopped: the state before the test is back.")
			return
		end
		local payload, err = rtf.payload()
		if not payload then
			host.say(err)
			rtf.notice = { text = err, untilT = os.clock() + 6 }
			return
		end
		host.disarmAll() -- no editor mode may stay armed: it would swallow the clicks of the game
		host.beforePlay()
		host.restrictStart()
		Spring.SendLuaRulesMsg("rtf|start|" .. payload)
		host.say("Test started: the state before is saved as _beforeplay; Stop brings it back.")
	end

	return rtf
end
