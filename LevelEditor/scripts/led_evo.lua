-- Evolution page of the Level Editor (button EV): settings and test run. The game itself is run by the gadget evo_game.lua (the ladders of the
-- units are there). Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_evo.lua")) as a function that gets the host (the services of the
-- widget) and returns the page; a file of its own because the widget is close to the limit of 200 local variables. The settings (evo.data) are saved
-- in their own section evolution of the level file. The player teams are the teams with units: each gets one unit where its commander stands.
--   host.Shared, host.S() (UI scale), host.say(text), host.serialize(table), host.disarmAll() (ends all modes when a test starts),
--   host.excludeOthers() (switches the other game modes off), host.restrictStart() / host.restrictStop() (the restrictions of the level),
--   host.beforePlay() / host.afterPlay() (state before the test: saved and brought back)
return function(host)
	local Shared = host.Shared
	local evo = { open = false, edit = nil, data = nil, notice = nil }
	local LIMITS = { lives = { 0, 99 }, respawn = { 0, 600 }, wilds = { 0, 300 }, wildHp = { 1, 100 }, first = { 1, 10000 }, factor = { 100, 400 } }

	function evo.new()
		return { enabled = false, lives = 3, respawn = 5, wilds = 20, wildHp = 10, first = 3, factor = 160 }
	end
	evo.DEFAULT = evo.new()

	-- Settings without write: the stored ones or the defaults (never changed by the caller); with write they are created
	function evo.cfg(write)
		if type(evo.data) == "table" then
			return evo.data
		end
		if not write then
			return evo.DEFAULT
		end
		evo.data = evo.new()
		return evo.data
	end

	function evo.lua()
		return host.serialize(evo.data)
	end

	-- Points needed from stage 1 to 2, 2 to 3, ... 9 to 10 (as evo_game.lua counts them)
	function evo.steps(c)
		local out = {}
		for s = 1, 9 do
			out[s] = math.max(1, math.floor(c.first * (c.factor / 100) ^ (s - 1) + 0.5))
		end
		return out
	end

	-- Buttons and labels of the page; returns rects, labels, height
	function evo.layout(rect)
		local S = host.S()
		local c = evo.cfg()
		local L = Shared.newPageLayout(rect, S)
		local rects, labels = L.rects, L.labels
		local line, head, note = L.line, L.head, L.note
		local function num(field)
			return (evo.edit and evo.edit.field == field) and (evo.edit.buf .. "_") or tostring(c[field])
		end
		local function field(name, tip)
			return { kind = "evoedit", field = name, label = num(name), active = evo.edit ~= nil and evo.edit.field == name, tip = tip }
		end
		line({ { kind = "evoon", label = (c.enabled and "[x] " or "[ ] ") .. "Evolution", active = c.enabled, tint = c.enabled and { 0.15, 0.6, 0.2 } or nil,
			tip = "Switch Evolution on or off for this level (saved in the level file, section evolution)" } })
		L.y = L.y - 6 * S
		note("Every team with units gets one stage 1 unit where its commander stands.", { 0.8, 0.8, 0.8 })
		note("Kills give points; enough points evolve the unit (10 stages).", { 0.8, 0.8, 0.8 })
		head("Lives (0 = unlimited) / seconds until a lost unit is back")
		line({
			field("lives", "Lives of a team. A lost unit comes back at a random place on the same stage while lives are left. The last alliance with lives wins. 0 = unlimited (no end)"),
			field("respawn", "Seconds until a lost unit comes back"),
		})
		head("Wild units / their health in %")
		line({
			field("wilds", "Number of wild units (stage 1 units of nobody) walking around the map; each gives 1 point and comes back 10 s after it died"),
			field("wildHp", "Health of a wild unit in percent of the normal health of that unit"),
		})
		head("Points to stage 2 / factor in % per stage")
		line({
			field("first", "Points from stage 1 to stage 2 (a wild unit gives 1 point)"),
			field("factor", "Every further stage needs this many percent of the points of the stage before (160 = x1.6). A player unit gives as many points as its own stage cost"),
		})
		note("Points per stage: " .. table.concat(evo.steps(c), " "), { 0.8, 0.8, 0.8 })
		L.y = L.y - 6 * S
		local state = Spring.GetGameRulesParam("evoState") or ""
		local running = state == "running"
		if evo.notice and os.clock() < evo.notice.untilT then
			note(evo.notice.text, { 1, 0.4, 0.35 })
		end
		L.y = L.y - 8 * S
		line({ { kind = "evoplay", label = running and "Stop" or (state ~= "" and "Reset" or "Start"), active = running, fs = 26 * S,
			tint = running and { 0.8, 0.15, 0.15 } or { 0.15, 0.6, 0.2 },
			tip = "Start: runs the game in the editor (the state before is saved as _beforeplay). Stop / Reset ends it and brings that state back." } })
		return rects, labels, rect.top - L.y
	end

	function evo.height()
		local _, _, h = evo.layout({ x1 = 0, x2 = math.floor(560 * host.S()), top = 0 })
		return h
	end

	function evo.draw(rect)
		local S = host.S()
		local rects, labels = evo.layout(rect)
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
	Shared.numberField(evo, 5, function(e, v)
		if v then
			local lim = LIMITS[e.field]
			evo.cfg(true)[e.field] = math.max(lim[1], math.min(lim[2], math.floor(v)))
		end
	end, function() widgetHandler:DisownText() end)

	-- Payload for the gadget (see evo_game.lua); nil and a message if something is missing
	function evo.payload()
		local c = evo.cfg()
		local teams = 0
		for _, t in ipairs(Spring.GetTeamList()) do
			if t ~= Spring.GetGaiaTeamID() and Spring.GetTeamUnitCount(t) > 0 then
				teams = teams + 1
			end
		end
		if teams == 0 then
			return nil, "Place a unit (a commander) for every team that plays first."
		end
		return table.concat({ c.lives, c.respawn, c.wilds, c.wildHp, c.first, c.factor }, ";")
	end

	function evo.press(rect, mx, my)
		local hit
		for _, r in ipairs((evo.layout(rect))) do
			if mx >= r.x1 and mx <= r.x2 and my >= r.y0 and my <= r.y1 then
				hit = r
			end
		end
		evo.finish(true)
		if not hit then
			return true
		end
		local k = hit.kind
		if k == "evoplay" then
			evo.toggle()
		elseif k == "evoedit" then
			evo.edit = { field = hit.field, buf = "" }
			widgetHandler:OwnText()
		elseif k == "evoon" then
			local c = evo.cfg(true)
			c.enabled = not c.enabled
			if c.enabled then
				host.excludeOthers()
			end
		end
		return true
	end

	-- Play / Stop: runs the game in the editor; the state before is saved as _beforeplay and comes back on Stop
	function evo.toggle()
		local state = Spring.GetGameRulesParam("evoState")
		if state and state ~= "" then
			Spring.SendLuaRulesMsg("evo|stop")
			host.restrictStop()
			host.afterPlay()
			host.say("Stopped: the state before the test is back.")
			return
		end
		local payload, err = evo.payload()
		if not payload then
			host.say(err)
			evo.notice = { text = err, untilT = os.clock() + 6 }
			return
		end
		host.disarmAll() -- no editor mode may stay armed: it would swallow the clicks of the game
		host.beforePlay()
		host.restrictStart()
		Spring.SendLuaRulesMsg("evo|start|" .. payload)
		host.say("Test started: the state before is saved as _beforeplay; Stop brings it back.")
	end

	return evo
end
