-- Capture the Flag page of the Level Editor (button CF): settings, collection points and flag points, test run.
-- The game itself is run by the gadget ctf_game.lua. Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_ctf.lua")) as a
-- function that gets the host (the services of the widget) and returns the page; a file of its own because the widget is close to
-- the limit of 200 local variables. The settings (ctf.data) are saved in their own section capture of the level file.
--   host.Shared, host.S() (UI scale), host.say(text), host.canEdit(), host.team() (team chosen in the strip), host.serialize(table),
--   host.disarm() (ends the other modes), host.disarmAll() (ends all modes when a test starts), host.excludeOthers() (switches Tower Defense and Reclaim the Fame off), host.restrictStart() / host.restrictStop() (the restrictions of the level), host.beforePlay() / host.afterPlay() (state before the test: saved and brought back),
--   host.step() / host.led(message) (undo history of the editor gadget)
return function(host)
	local Shared = host.Shared
	local ctf = { open = false, edit = nil, pick = nil, data = nil, notice = nil }
	local DELETE_RADIUS = 80 -- Del: the point within this distance of the mouse pointer goes
	local LIMITS = { amount = { 0, 99999 }, score = { 0, 99 }, radius = { 10, 2000 }, returnTime = { 0, 3600 }, speed = { 0, 2000 } }

	function ctf.new()
		return { enabled = false, amount = 100, score = 3, radius = 100, returnTime = 0, speed = 50, visible = true, homes = {}, flags = {} }
	end
	ctf.DEFAULT = ctf.new()

	-- Settings without write: the stored ones or the defaults (never changed by the caller); with write they are created
	function ctf.cfg(write)
		if type(ctf.data) == "table" then
			return ctf.data
		end
		if not write then
			return ctf.DEFAULT
		end
		ctf.data = ctf.new()
		return ctf.data
	end

	function ctf.lua()
		return host.serialize(ctf.data)
	end

	local function teamName(t)
		return t >= 0 and ("team " .. t) or "neutral"
	end

	-- Points as text for the undo history: "t,x,z/t,x,z" ("-" for none); state = "homes;flags"
	local function pointsText(list)
		local out = {}
		for _, p in ipairs(list) do
			out[#out + 1] = string.format("%d,%d,%d", p.team, p.x, p.z)
		end
		return #out > 0 and table.concat(out, "/") or "-"
	end

	local function pointsFrom(text)
		local out = {}
		for t, x, z in tostring(text):gmatch("(-?%d+),(-?%d+),(-?%d+)") do
			out[#out + 1] = { team = tonumber(t), x = tonumber(x), z = tonumber(z) }
		end
		return out
	end

	function ctf.state()
		local c = ctf.cfg()
		return pointsText(c.homes) .. ";" .. pointsText(c.flags)
	end

	function ctf.applyState(state)
		local c = ctf.cfg(true)
		local h, f = tostring(state):match("^([^;]*);(.*)$")
		c.homes, c.flags = pointsFrom(h or ""), pointsFrom(f or "")
	end

	-- The undo history of the points (Shared.newPointHistory): ctf.commit(before) notes a change as a step (before = ctf.state() from before the change),
	-- ctf.poll() takes over the state after an undo or redo (called every frame)
	local history = Shared.newPointHistory({ tag = "ctfpts", state = ctf.state, apply = ctf.applyState, default = "-;-",
		step = function() host.step() end, led = function(msg) host.led(msg) end })
	ctf.commit, ctf.poll = history.commit, history.poll

	-- The point (collection or flag point) next to the mouse pointer: list, index; nil if none
	function ctf.pointAt()
		local gx, gz = Shared.mouseGround()
		if not gx then
			return nil
		end
		local c = ctf.cfg()
		local best, list, bestD = nil, nil, DELETE_RADIUS ^ 2
		for _, l in ipairs({ c.homes, c.flags }) do
			for i, p in ipairs(l) do
				local d = (p.x - gx) ^ 2 + (p.z - gz) ^ 2
				if d <= bestD then
					best, list, bestD = i, l, d
				end
			end
		end
		return list, best
	end

	-- Buttons and labels of the page; returns rects, labels, height
	function ctf.layout(rect)
		local S, m = host.S(), Shared.m
		local c = ctf.cfg()
		local L = Shared.newPageLayout(rect, S)
		local rects, labels, x1, x2, gap = L.rects, L.labels, L.x1, L.x2, L.gap
		local line, head, note = L.line, L.head, L.note
		local function num(field)
			return (ctf.edit and ctf.edit.field == field) and (ctf.edit.buf .. "_") or tostring(c[field])
		end
		local function field(name, tip)
			return { kind = "ctfedit", field = name, label = num(name), active = ctf.edit ~= nil and ctf.edit.field == name, tip = tip }
		end
		-- the switch of the mode is the first thing on the page
		line({ { kind = "ctfon", label = (c.enabled and "[x] " or "[ ] ") .. "Capture the Flag", active = c.enabled, tint = c.enabled and { 0.15, 0.6, 0.2 } or nil,
			tip = "Switch Capture the Flag on or off for this level (saved in the level file, section capture)" } })
		L.y = L.y - 6 * S
		head("Places on the map (team: strip at the left)")
		line({
			{ kind = "ctfhome", label = "Collection point", active = ctf.pick == "home", w = 5,
				tip = "Collection point of the team chosen in the strip at the left: click, then click the places on the map (as many as you like per team). Right click ends. Del over a point removes it, Alt + drag moves it." },
			{ kind = "ctfhomex", label = "X", w = 1, tip = "Delete all collection points of the chosen team" },
			{ kind = "ctfflag", label = "Flag point", active = ctf.pick == "flag", w = 5,
				tip = "Flag point: every click on the map adds one, a flag lies there (with 'Own flags' it belongs to the team chosen in the strip at the left). Right click ends. Del over a point removes it, Alt + drag moves it." },
			{ kind = "ctfflagx", label = "X", w = 1, tip = "Delete all flag points (with 'Own flags': those of the chosen team)" },
		})
		-- what is placed
		local homeCount, homeOrder = {}, {}
		for _, h in ipairs(c.homes) do
			if not homeCount[h.team] then
				homeCount[h.team] = 0
				homeOrder[#homeOrder + 1] = h.team
			end
			homeCount[h.team] = homeCount[h.team] + 1
		end
		table.sort(homeOrder)
		local homes = {}
		for _, tm in ipairs(homeOrder) do
			homes[#homes + 1] = string.format("%d (team %d)", homeCount[tm], tm)
		end
		local byTeam, order = {}, {}
		for _, f in ipairs(c.flags) do
			if not byTeam[f.team] then
				byTeam[f.team] = 0
				order[#order + 1] = f.team
			end
			byTeam[f.team] = byTeam[f.team] + 1
		end
		table.sort(order)
		local parts = {}
		for _, t in ipairs(order) do
			parts[#parts + 1] = string.format("%d (%s)", byTeam[t], teamName(t))
		end
		note("Collection points: " .. (#homes > 0 and table.concat(homes, ", ") or "none"), { 0.8, 0.8, 0.8 })
		note("Flag points: " .. (#parts > 0 and table.concat(parts, ", ") or "none"), { 0.8, 0.8, 0.8 })
		L.y = L.y - 6 * S
		line({ { kind = "ctfvisible", label = (c.visible ~= false and "[x] " or "[ ] ") .. "Flags always visible on the map", active = c.visible ~= false,
			tip = "On: the flags are shown on the whole map and the minimap, also without radar or a unit nearby. Off: only what a unit sees." } })
		head("Income: metal per second per flag held")
		line({ field("amount", "Metal per second for every flag a team holds at its collection point; a flag that is carried or stolen pays nothing. Click, type a number, Enter accepts") })
		head("Flags a team must hold at once to win (0 = never)")
		line({ field("score", "The first team that holds this many flags at its collection point at the same time wins. 0: the level does not end. Click, type a number, Enter accepts") })
		head("Capture radius (Elmo)")
		line({ field("radius", "Distance within which a unit picks up a flag, delivers it, or brings its own dropped flag back. Click, type a number, Enter accepts") })
		head("Top speed of a flag carrier (Elmo/s, 0 = no limit)")
		line({ field("speed", "A unit that carries a flag is slowed down to this speed until it delivers the flag or loses it (a scout would fetch the flags in no time otherwise); slower units keep their own speed. For comparison: a scout drives about 100, a tank 30 to 60 Elmo per second. 0 = no limit. Click, type a number, Enter accepts") })
		head("Dropped flag goes back after (s, 0 = stays)")
		line({ field("returnTime", "When the unit that carries a flag is destroyed, the flag is dropped where it died. 0 = it stays there until a unit takes it, a number = it goes back to its flag point after this many seconds. A carrier cannot shoot. Click, type a number, Enter accepts") })
		L.y = L.y - 6 * S
		-- very bottom: the button that starts the test (red message above it: what is missing)
		local state = Spring.GetGameRulesParam("ctfState") or ""
		local running = state == "running"
		if ctf.notice and os.clock() < ctf.notice.untilT then
			note(ctf.notice.text, { 1, 0.4, 0.35 })
		end
		L.y = L.y - 8 * S
		line({ { kind = "ctfplay", label = running and "Stop" or (state ~= "" and "Reset" or "Start"), active = running, fs = 26 * S,
			tint = running and { 0.8, 0.15, 0.15 } or { 0.15, 0.6, 0.2 },
			tip = "Start: runs the game in the editor (the state before is saved as _beforeplay). Stop / Reset ends it and brings that state back." } })
		L.y = L.y - m.PAD
		return rects, labels, rect.top - L.y
	end

	function ctf.height()
		local _, _, h = ctf.layout({ x1 = 0, x2 = math.floor(560 * host.S()), top = 0 })
		return h
	end

	function ctf.draw(rect)
		local S = host.S()
		local rects, labels = ctf.layout(rect)
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

	-- The number fields of the page: Enter accepts, Esc discards, digits only (Shared.numberField); apply takes the typed value
	Shared.numberField(ctf, 5, function(e, v)
		if v then
			local lim = LIMITS[e.field]
			ctf.cfg(true)[e.field] = math.max(lim[1], math.min(lim[2], math.floor(v)))
		end
	end, function() widgetHandler:DisownText() end)

	-- Payload for the gadget (see ctf_game.lua); nil and a message if something is missing
	function ctf.payload()
		local c = ctf.cfg()
		if #c.homes == 0 then
			return nil, "Place at least one collection point first."
		end
		if #c.flags == 0 then
			return nil, "Place at least one flag point first."
		end
		local function list(items)
			local out = {}
			for _, p in ipairs(items) do
				out[#out + 1] = string.format("%d,%d,%d", p.team, p.x, p.z)
			end
			return #out > 0 and table.concat(out, "/") or "-"
		end
		return table.concat({ c.amount, c.radius, c.score, c.returnTime, c.speed, list(c.homes), list(c.flags), c.visible ~= false and "1" or "0" }, ";")
	end

	function ctf.endPick()
		ctf.pick = nil
	end

	-- Arms picking on the map: "home" or "flag"; the same button again ends it
	function ctf.startPick(kind)
		ctf.finish(true)
		local same = ctf.pick == kind
		host.disarm()
		ctf.endPick()
		if same then
			host.say("Capture the Flag: mode ended")
			return
		end
		ctf.pick = kind
		local t = host.team()
		if kind == "home" then
			host.say(string.format("Click the collection points of team %d on the map (team: strip at the left), right click ends.", t))
		else
			host.say(t == Spring.GetGaiaTeamID() and "Click the flag points on the map (Gaia = neutral flags that every team may take), right click ends." or string.format("Click the flag points of team %d on the map, right click ends.", t))
		end
	end

	function ctf.cancel()
		ctf.endPick()
		host.say("Capture the Flag: mode ended")
	end

	-- Left click on the map in the pick mode
	function ctf.click(x, z)
		local before = ctf.state()
		local c = ctf.cfg(true)
		x, z = math.floor(x), math.floor(z)
		local t = host.team()
		if ctf.pick == "home" then
			if t == Spring.GetGaiaTeamID() then
				host.say("A collection point belongs to a team: choose a team in the strip at the left (Gaia only works for flag points).")
				return
			end
			c.homes[#c.homes + 1] = { team = t, x = x, z = z }
			host.say(string.format("Collection point of team %d placed at %d, %d", t, x, z))
		else
			c.flags[#c.flags + 1] = { team = t == Spring.GetGaiaTeamID() and -1 or t, x = x, z = z } -- Gaia in the strip = neutral flag
			host.say(string.format("Flag point %d placed (%s).", #c.flags, teamName(c.flags[#c.flags].team)))
		end
		ctf.commit(before)
	end

	-- Del: removes the point (collection or flag point) next to the mouse pointer; true if there was one
	function ctf.deleteAt()
		if not ctf.open or not host.canEdit() then
			return false
		end
		local list, i = ctf.pointAt()
		if not i then
			return false
		end
		local before = ctf.state()
		table.remove(list, i)
		ctf.commit(before)
		host.say("Point removed (Ctrl+Z brings it back)")
		return true
	end

	-- Alt + left button over a point: it follows the mouse pointer (ctf.sample) until the button is released (ctf.endDrag); true if one was grabbed
	function ctf.grab()
		if not host.canEdit() then
			return false
		end
		local list, i = ctf.pointAt()
		if not i then
			return false
		end
		ctf.drag = { point = list[i], before = ctf.state() }
		return true
	end

	function ctf.sample()
		local d = ctf.drag
		if not d then
			return
		end
		local gx, gz = Shared.mouseGround()
		if gx then
			d.point.x, d.point.z = math.floor(gx), math.floor(gz)
		end
	end

	function ctf.endDrag()
		if ctf.drag then
			ctf.commit(ctf.drag.before)
			ctf.drag = nil
		end
	end

	function ctf.press(rect, mx, my)
		local hit
		for _, r in ipairs((ctf.layout(rect))) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		ctf.finish(true)
		if not hit then
			return true
		end
		local k = hit.kind
		if k == "ctfplay" then
			ctf.toggle()
		elseif k == "ctfedit" then
			ctf.edit = { field = hit.field, buf = "" }
			widgetHandler:OwnText()
		elseif k == "ctfhome" or k == "ctfflag" then
			ctf.startPick(k == "ctfhome" and "home" or "flag")
		elseif k == "ctfhomex" or k == "ctfflagx" then
			local before = ctf.state()
			local c = ctf.cfg(true)
			local list, t = k == "ctfhomex" and c.homes or c.flags, host.team()
			if t == Spring.GetGaiaTeamID() then
				t = -1
			end
			for i = #list, 1, -1 do
				if list[i].team == t then
					table.remove(list, i)
				end
			end
			ctf.commit(before)
		else
			local c = ctf.cfg(true)
			if k == "ctfon" then
				c.enabled = not c.enabled
				if c.enabled then
					host.excludeOthers()
				end
			elseif k == "ctfvisible" then
				c.visible = not (c.visible ~= false)
			end
		end
		return true
	end

	-- Play / Stop: runs the game in the editor; the state before is saved as _beforeplay and comes back on Stop
	function ctf.toggle()
		local state = Spring.GetGameRulesParam("ctfState")
		if state and state ~= "" then
			Spring.SendLuaRulesMsg("ctf|stop")
			host.restrictStop()
			host.afterPlay()
			host.say("Stopped: the state before the test is back.")
			return
		end
		local payload, err = ctf.payload()
		if not payload then
			host.say(err)
			ctf.notice = { text = err, untilT = os.clock() + 6 }
			return
		end
		host.disarmAll() -- no editor mode may stay armed: it would swallow the clicks of the game
		host.beforePlay()
		host.restrictStart()
		Spring.SendLuaRulesMsg("ctf|start|" .. payload)
		host.say("Test started: the state before is saved as _beforeplay; Stop brings it back.")
	end

	-- Markers in the world (also with the page closed, so nothing stays hidden): collection points (thick ring) and flag points (small ring),
	-- in the colors of the teams
	function ctf.drawWorld()
		local c = ctf.cfg()
		if not ctf.open and #c.homes == 0 and #c.flags == 0 then
			return
		end
		gl.DepthTest(false)
		local function circle(p, r, width)
			local cr, cg, cb = 1, 1, 1
			if p.team >= 0 then
				cr, cg, cb = Spring.GetTeamColor(p.team)
			end
			gl.LineWidth(width)
			gl.Color(cr or 1, cg or 1, cb or 1, 1)
			Shared.groundRing(p.x, p.z, r, 40)
		end
		local hotList, hotI
		if ctf.open then
			hotList, hotI = ctf.pointAt()
		end
		for i, h in ipairs(c.homes) do
			circle(h, c.radius, 4)
			if hotList == c.homes and hotI == i then
				circle(h, c.radius + 16, 2)
			end
		end
		for i, f in ipairs(c.flags) do
			circle(f, c.radius * 0.5, 2)
			if hotList == c.flags and hotI == i then
				circle(f, c.radius * 0.5 + 16, 2)
			end
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
	end

	return ctf
end
