-- Generate page of the Level Editor (button G): faction, type, tech, count; then drag an area, the units (or a maze) appear in it.
-- Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_gen.lua")) as a function that gets the host and returns the page `gen`:
-- the state of the page (open, armed, drag, faction, shape, sub, ...) and its functions gen.layout(rect), gen.finish(accept), gen.height(), gen.mazeFaction().
-- The widget works the area modes (gen.arm and the drag on the map) itself.
--   host.Shared, host.S() (UI scale), host.mazeKind() (the maze mode of the widget: nil = off)
return function(host)
	local Shared = host.Shared
	local gen = {
		open = false,
		armed = false, -- area mode on
		drag = nil, -- { x, z }: start point of the area
		faction = "arm",
		shape = "rect", -- area to drag: "rect" (rectangle) or "circle" (from the center outwards)
		sub = "units", -- sub-tab: "units" or "maze"
		mazeSel = 1, -- chosen maze material (1 = dragon teeth, 2 = walls)
		mazePath = 4, -- corridor width of the maze in tiles of 16 Elmo
		kinds = { units = true }, -- chosen types (multiple choice)
		edit = nil, -- count input field: text while typing
		tech = { [1] = true, [2] = false, [3] = false },
		count = 100,
	}

	function gen.mazeFaction()
		return (gen.faction == "cor" or gen.faction == "leg") and gen.faction or "arm"
	end

	gen.KINDS = { { "units", "Units" }, { "buildings", "Buildings" }, { "turrets", "Turrets" }, { "air", "Air" }, { "ships", "Ships" } }

	-- Generate page: buttons and labels; rect.top is the top edge, the third value is the height
	function gen.layout(rect)
		local S, m = host.S(), Shared.m
		local rects, labels = {}, {}
		local y = rect.top - m.PAD
		local TIPS = {
			genfac = "Faction of the generated units",
			genkind = "Type of the generated units: several can be on at once",
			gentech = "Tech level: several can be on at once, none chosen means all",
			gencount = "Total number of units (1-2000). Click, type a number, Enter accepts",
			genshape = "Press, then drag the area on the map: the units (or the maze) appear in it for the chosen team. A rectangle, or a circle dragged from its center outwards. Press again or right click to end, Ctrl+Z undoes it.",
			genmaze = "Material of the maze walls: dragon teeth or walls",
			genmazew = "Width of the corridors of the maze in Elmo",
		}
		local function row(title, items, kind)
			labels[#labels + 1] = { text = title, x = rect.x1 + m.PAD, y = y - 30 * S, size = 25 * S, head = true }
			y = y - 36 * S
			local gap = 4 * S
			local n = #items
			local w = (rect.x2 - rect.x1 - 2 * m.PAD - gap * (n - 1)) / n
			for i, it in ipairs(items) do
				local bx = rect.x1 + m.PAD + (i - 1) * (w + gap)
				rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = it.kind or kind, value = it.value, label = it.label, active = it.active, icon = it.icon, fs = 24 * S, tint = it.tint,
					tip = it.tip or TIPS[it.kind or kind] }
			end
			y = y - m.HB - 10 * S
		end
		-- Sub-tabs: Units | Maze
		do
			local gap = 4 * S
			local w = (rect.x2 - rect.x1 - 2 * m.PAD - gap) / 2
			for i, it in ipairs({ { "units", "Units" }, { "maze", "Maze" } }) do
				local bx = rect.x1 + m.PAD + (i - 1) * (w + gap)
				rects[#rects + 1] = { x1 = bx, x2 = bx + w, y0 = y - m.HB, y1 = y, kind = "gensub", value = it[1], label = it[2], active = gen.sub == it[1], fs = 24 * S,
					tip = it[1] == "units" and "Generate random units in an area" or "Build a random maze in an area (entrance top left, exit bottom right)" }
			end
			y = y - m.HB - 12 * S
		end
		-- all five factions for units; the maze only for the three that have dragon teeth and walls of their own
		local function factionRow(maze)
			local items = {}
			local chosen = maze and gen.mazeFaction() or gen.faction
			for _, f in ipairs(Shared.FACTIONS) do
				if not maze or f[1] == "arm" or f[1] == "cor" or f[1] == "leg" then
					items[#items + 1] = { value = f[1], label = f[2], active = chosen == f[1], icon = Shared.FACTION_ICONS[f[1]] }
				end
			end
			row("Faction", items, "genfac")
		end
		-- Bottom of both sub-tabs: Area (rectangle / circle: pressing one starts the generating, there is no extra button)
		local function bottom()
			local armed = gen.sub == "maze" and host.mazeKind() ~= nil or gen.sub ~= "maze" and gen.armed
			local START_GREEN = { 0.25, 0.5, 0.28 } -- light green: these are the buttons to press
			row(armed and "Drag the area on the map (right click ends)" or "Generate in an area (circle: drag from the center outwards)", {
				{ value = "rect", label = "Rectangle", active = armed and gen.shape == "rect", tint = not (armed and gen.shape == "rect") and START_GREEN or nil },
				{ value = "circle", label = "Circle", active = armed and gen.shape == "circle", tint = not (armed and gen.shape == "circle") and START_GREEN or nil },
			}, "genshape")
			return rects, labels, rect.top - y
		end
		if gen.sub == "maze" then
			factionRow(true)
			row("Maze material", {
				{ value = 1, label = "Dragon teeth", active = gen.mazeSel == 1 },
				{ value = 2, label = "Walls", active = gen.mazeSel == 2 },
			}, "genmaze")
			local widths = {}
			for _, t in ipairs({ 2, 4, 8, 10, 12 }) do -- the same widths as the corridors of Tower Defense
				widths[#widths + 1] = { value = t, label = tostring(t * 16), active = gen.mazePath == t }
			end
			row("Corridor width (Elmo)", widths, "genmazew")
			labels[#labels + 1] = { text = "Random maze: entrance top left, exit bottom right.", x = rect.x1 + m.PAD, y = y - 22 * S, size = 21 * S }
			y = y - 34 * S
			return bottom()
		end
		factionRow()
		local kinds = {}
		for _, k in ipairs(gen.KINDS) do
			kinds[#kinds + 1] = { value = k[1], label = k[2], active = gen.kinds[k[1]] == true }
		end
		row("Type (multiple choice)", kinds, "genkind")
		row("Tech level (none chosen = all)", {
			{ value = 1, label = "T1", active = gen.tech[1] },
			{ value = 2, label = "T2", active = gen.tech[2] },
			{ value = 3, label = "T3", active = gen.tech[3] },
		}, "gentech")
		row("Total count (1-2000, type a number)", {
			{ value = 0, label = gen.edit and (gen.edit .. "_") or tostring(gen.count), kind = "gencount", active = gen.edit ~= nil },
		}, "gencount")
		return bottom()
	end

	-- End the count input field (accept: take the value, otherwise discard)
	function gen.finish(accept)
		if not gen.edit then
			return
		end
		local v = tonumber(gen.edit)
		gen.edit = nil
		widgetHandler:DisownText()
		if accept and v then
			gen.count = math.max(1, math.min(2000, math.floor(v)))
		end
	end

	function gen.height()
		local _, _, h = gen.layout({ x1 = 0, x2 = math.floor(560 * host.S()), top = 0 })
		return h
	end

	return gen
end
