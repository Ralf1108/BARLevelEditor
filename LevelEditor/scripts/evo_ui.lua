-- Evolution, the unsynced part (loaded by evo_game.lua when the gadget runs unsynced; the synced part is in evo_game.lua): the score lines, Armageddon, the missile targets,
-- the selection, the camera, the panels of the abilities and the experience bar, the heal effect. Returns function(gadget, S): it sets the call-ins of the gadget; S holds
-- what both parts use (the lists and names defined at the top of evo_game.lua).
return function(gadget, S)
	local NAMES, LADDERS, ABILITIES, teamName = S.NAMES, S.LADDERS, S.ABILITIES, S.teamName
	-- ---------------------------------------------------------------- unsynced: the score lines, Armageddon, the missile targets, the selection and the camera
	local lastUnit, lastSpawn = nil, nil
	local overviewDone = false
	local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST) -- the heal effect (G.healAdd, G.healDraw)

	-- The camera at the start: the game's own camera type (spring) from above over the middle of the map, so that the whole map is seen. (A camera left in another type - the first person
	-- view of a game before, which the game keeps in its settings - made Evolution start in a view from inside of the unit.)
	local function overview()
		local mx, mz = Game.mapSizeX, Game.mapSizeZ
		Spring.SetCameraState({ name = "spring", mode = 2, px = mx / 2, py = Spring.GetGroundHeight(mx / 2, mz / 2), pz = mz / 2,
			rx = 2.75, ry = 0, rz = 0, dist = math.max(mx, mz) * 1.15 }, 0)
	end

	function gadget:Update()
		if (Spring.GetGameRulesParam("evoState") or "") == "" or Spring.GetSpectatingState() then
			return
		end
		if not overviewDone and Spring.GetGameFrame() >= 1 then
			overviewDone = true
			overview()
		end
		local team = Spring.GetMyTeamID()
		local id = Spring.GetTeamRulesParam(team, "evoUnit")
		if id and id > 0 and id ~= lastUnit then
			lastUnit = id
			Spring.SelectUnitArray({ id }) -- the new unit (evolved or back) is selected: no new click needed
		end
		local spawn = Spring.GetTeamRulesParam(team, "evoSpawn")
		if spawn and spawn ~= lastSpawn then
			local first = lastSpawn == nil -- (the first one is the start: the camera shows the whole map then)
			lastSpawn = spawn
			local x, y, z = Spring.GetUnitPosition(id or -1)
			if x and not first then
				Spring.SetCameraTarget(x, y, z, 0.5) -- the unit is at a new place of the map
			end
		end
	end

	-- ---------------------------------------------------------------- the panel at the top (drawn with plain shapes: rounded boxes, badges, bars, symbols)
	local H = {}
	-- the shapes and the bar of buttons are shared with Renegade (powerups_ui.lua)
	local U = VFS.Include("luaui/Include/powerups_ui.lua", nil, VFS.ZIP_FIRST)
	H.outline, H.box, H.disc, H.ring, H.icon = U.outline, U.box, U.disc, U.ring, U.icon



	-- the radiation symbol (three blades, a dark ring, a centre) in yellow
	function H.atom(cx, cy, r)
		gl.Color(1, 0.9, 0.1, 1)
		for k = 0, 2 do
			local c = 90 + k * 120
			gl.BeginEnd(GL.TRIANGLE_FAN, function()
				gl.Vertex(cx, cy)
				for i = 0, 8 do
					local a = math.rad(c - 30 + 60 * i / 8)
					gl.Vertex(cx + r * math.cos(a), cy + r * math.sin(a))
				end
			end)
		end
		H.disc(cx, cy, r * 0.3, { 0.1, 0.05, 0.02, 1 })
		H.disc(cx, cy, r * 0.17, { 1, 0.9, 0.1, 1 })
	end



	-- the symbol of kills: a crosshair
	function H.crosshair(x, y, r)
		gl.LineWidth(2)
		H.ring(x, y, r * 0.7, { 1, 0.45, 0.35, 1 })
		gl.BeginEnd(GL.LINES, function()
			for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
				gl.Vertex(x + d[1] * r * 0.35, y + d[2] * r * 0.35)
				gl.Vertex(x + d[1] * r, y + d[2] * r)
			end
		end)
		gl.LineWidth(1)
	end

	-- the symbol of deaths: a small skull
	function H.skull(x, y, r)
		H.disc(x, y + r * 0.15, r * 0.75, { 0.85, 0.85, 0.85, 1 })
		H.box(x - r * 0.4, y - r * 0.8, x + r * 0.4, y - r * 0.2, r * 0.15, { 0.85, 0.85, 0.85, 1 }, { 0.85, 0.85, 0.85, 1 })
		H.disc(x - r * 0.3, y + r * 0.1, r * 0.2, { 0.1, 0.1, 0.12, 1 })
		H.disc(x + r * 0.3, y + r * 0.1, r * 0.2, { 0.1, 0.1, 0.12, 1 })
	end


	-- the abilities of a team as small squares in their colors, each in its own column (the order of ABILITIES; an empty frame where the team does not have
	-- it): its symbol, dimmed with the seconds while it cools down, a bright border while it works
	function H.abilities(team, x, y, size)
		local have = U.state(team, "evoAbilities")
		for i, a in ipairs(ABILITIES) do
			local h = have[i]
			if h then
				local c = a.color
				-- only the symbol: that a team has the ability, not its cooldown or state
				H.box(x, y - size / 2, x + size, y + size / 2, size * 0.2, { c[1] * 0.5, c[2] * 0.5, c[3] * 0.5, 0.95 }, { c[1], c[2], c[3], 0.95 }, { 0, 0, 0, 0.6 })
				H.icon(a.key, x + size / 2, y, size * 0.36)
			else
				H.box(x, y - size / 2, x + size, y + size / 2, size * 0.2, { 0.05, 0.05, 0.08, 0.5 }, { 0.08, 0.08, 0.12, 0.5 }, { 0.35, 0.38, 0.48, 0.35 })
			end
			x = x + size * 1.15
		end
		return x
	end

	-- the panel at the right edge below the bars of the game: a title line and one compact row per team, the highest level on top (the out players at the
	-- bottom): team color, level badge, name, points bar, kills, deaths, abilities
	-- the scale of everything drawn here: 1 at 1920 x 1080, smaller with a smaller window (by the smaller of width and height), times the UI scale of the game
	function H.scale()
		local vsx, vsy = Spring.GetViewGeometry()
		return math.min(vsx / 1920, vsy / 1080) * (Spring.GetConfigFloat("ui_scale", 1) or 1)
	end

	function H.panel(state, arma)
		local vsx, vsy = Spring.GetViewGeometry()
		local base = H.scale()
		local s = base * 1.26 -- (the overview is 26 % larger than the rest: 20 % plus 5 %)
		local rows = {}
		for t in tostring(Spring.GetGameRulesParam("evoTeams") or ""):gmatch("%d+") do
			local team = tonumber(t)
			local function p(k) return Spring.GetTeamRulesParam(team, k) or 0 end
			rows[#rows + 1] = { team = team, out = p("evoOut") == 1, stage = p("evoStage"), xp = p("evoXp"), need = p("evoNeed"), kills = p("evoKills"), deaths = p("evoDeaths") }
		end
		table.sort(rows, function(a, b)
			if a.out ~= b.out then return not a.out end
			if a.stage ~= b.stage then return a.stage > b.stage end
			if a.xp ~= b.xp then return a.xp > b.xp end
			return a.team < b.team
		end)
		local w, rowH, head, pad, gap = math.floor(410 * s), math.floor(44 * s), math.floor(28 * s), math.floor(7 * s), math.floor(4 * s)
		local x2 = math.floor(vsx - 8 * s)
		local x1 = x2 - w
		local top = math.floor(vsy - 72 * base)
		-- as many rows as fit above the music player (140 at 1080 lines from the bottom); more teams: a scroll bar and the mouse wheel (the highest level is on top)
		local maxRows = math.max(1, math.floor((top - head - pad - 140 * base) / (rowH + gap)))
		local shown = H.hidden and 0 or math.min(#rows, maxRows)
		H.scroll = math.max(0, math.min(H.scroll or 0, #rows - shown))
		local scrolling = shown > 0 and #rows > shown
		local rx2 = x2 - pad - (scrolling and 9 * s or 0)
		local y1 = top - head - (shown > 0 and (shown * (rowH + gap) + pad) or 0)
		local hot = arma > 0
		if H.hidden then
			-- folded away to the right: only a small tab at the right edge (an arrow to the left) brings the list back
			local tb = head
			H.toggle = { x2 - tb, top - head, x2, top }
			H.box(x2 - tb, top - head, x2, top, 6 * s, { 0.03, 0.04, 0.07, 0.85 }, { 0.10, 0.12, 0.18, 0.85 }, hot and { 1, 0.3, 0.2, 0.9 } or { 0.55, 0.65, 0.85, 0.6 }, 2)
			gl.Color(0.9, 0.95, 1, 1)
			gl.BeginEnd(GL.TRIANGLES, function()
				local cx, cy2, q = x2 - tb / 2, top - head / 2, tb * 0.25
				gl.Vertex(cx + q * 0.7, cy2 + q); gl.Vertex(cx + q * 0.7, cy2 - q); gl.Vertex(cx - q, cy2)
			end)
			H.area2, H.pageRows = H.toggle, 0
			gl.Color(1, 1, 1, 1)
			return x1, x2, top - head, base
		end
		H.box(x1, y1, x2, top, 8 * s, { 0.03, 0.04, 0.07, 0.82 }, { 0.10, 0.12, 0.18, 0.82 }, hot and { 1, 0.3, 0.2, 0.9 } or { 0.55, 0.65, 0.85, 0.45 })
		local pulse = 0.75 + 0.25 * math.sin(Spring.GetGameFrame() * 0.12)
		if hot then
			gl.Color(1, 0.3 * pulse, 0.15, 1)
		else
			gl.Color(0.55, 0.95, 0.7, 1)
		end
		gl.Text(hot and "ARMAGEDDON" or "EVOLUTION", x1 + pad * 2, top - head / 2, 17 * s, "vo")
		-- the button at the right of the title line: hides / shows the list
		local tb = head - 8 * s
		local tx2 = x2 - pad
		local tx1, ty1, ty2 = tx2 - tb, top - head + 4 * s, top - 4 * s
		H.toggle = { tx1, ty1, tx2, ty2 }
		-- the button ? left of it: the help of the levels
		local hx2 = tx1 - 6 * s
		H.helpBtn = { hx2 - tb, ty1, hx2, ty2 }
		H.box(hx2 - tb, ty1, hx2, ty2, 4 * s, { 0.12, 0.15, 0.22, 0.95 }, { 0.22, 0.27, 0.38, 0.95 }, { 0.7, 0.8, 1, 0.8 }, 2)
		gl.Color(0.9, 0.95, 1, 1)
		gl.Text("?", hx2 - tb / 2, (ty1 + ty2) / 2, 16 * s, "cvo")
		local stx = hx2 - tb - 6 * s
		H.box(tx1, ty1, tx2, ty2, 4 * s, { 0.12, 0.15, 0.22, 0.95 }, { 0.22, 0.27, 0.38, 0.95 }, { 0.7, 0.8, 1, 0.8 }, 2)
		gl.Color(0.9, 0.95, 1, 1)
		gl.BeginEnd(GL.TRIANGLES, function()
			local cx, cy2, q = (tx1 + tx2) / 2, (ty1 + ty2) / 2, tb * 0.25
			-- (an arrow to the right: fold the list away to the right)
			gl.Vertex(cx - q * 0.7, cy2 + q); gl.Vertex(cx - q * 0.7, cy2 - q); gl.Vertex(cx + q, cy2)
		end)
		if state ~= "running" then
			gl.Color(1, 0.85, 0.4, 1)
			gl.Text(state, stx - pad, top - head / 2, 12 * s, "rvo")
		end
		local mine = Spring.GetMyTeamID()
		local y = top - head
		for ri = H.scroll + 1, H.scroll + shown do
			local row = rows[ri]
			local team, out = row.team, row.out
			local ry2, ry1 = y, y - rowH
			local cy = (ry1 + ry2) / 2
			local r, g, b = Spring.GetTeamColor(team)
			r, g, b = r or 1, g or 1, b or 1
			if team == mine then
				H.box(x1 + pad, ry1, rx2, ry2, 6 * s, { 0.16, 0.2, 0.28, 0.9 }, { 0.24, 0.3, 0.42, 0.9 }, { 0.8, 0.9, 1, 0.7 })
			else
				H.box(x1 + pad, ry1, rx2, ry2, 6 * s, { 0.08, 0.09, 0.13, 0.85 }, { 0.13, 0.15, 0.21, 0.85 })
			end
			H.box(x1 + pad, ry1 + 3 * s, x1 + pad + 4 * s, ry2 - 3 * s, 2 * s, { r, g, b, 1 }, { r, g, b, 1 })
			-- the level badge
			local bx, br = x1 + pad + 24 * s, rowH * 0.38
			H.disc(bx, cy, br, out and { 0.25, 0.25, 0.25, 1 } or { r * 0.45, g * 0.45, b * 0.45, 1 })
			gl.LineWidth(2)
			H.ring(bx, cy, br, out and { 0.5, 0.5, 0.5, 1 } or { r, g, b, 1 })
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 1)
			gl.Text(out and "-" or tostring(row.stage), bx, cy, 18 * s, "cvo")
			-- the abilities at the right (large squares), left of them kills above deaths (a column), then at the left the name (first line, shortened to the
			-- room it has) and the points bar (second line)
			local asize = rowH * 0.66
			local ax = rx2 - 5 * asize * 1.15 - 2 * s
			local kx = ax - 50 * s
			local nx = bx + br + 8 * s
			local name = teamName(team)
			if out then
				name = name .. "  (out)"
			end
			local room = kx - 6 * s - nx
			while #name > 1 and gl.GetTextWidth(name) * 15 * s > room do
				name = name:sub(1, #name - 2) .. "."
			end
			gl.Color(out and 0.55 or 1, out and 0.55 or 1, out and 0.55 or 1, 1)
			gl.Text(name, nx, cy + 9 * s, 15 * s, "vo")
			local px1, px2 = nx, nx + 84 * s
			-- no bars here: the points now and for the next level, then the experience bonus of the unit
			local exp = Spring.GetTeamRulesParam(team, "evoExp") or 0
			if not out then
				gl.Color(0.8, 0.85, 0.95, 1)
				gl.Text((row.need > 0 and string.format("%d/%d", row.xp, row.need) or "MAX") .. "   XP " .. string.format("%.1f", exp), nx, cy - 9 * s, 12 * s, "vo")
			end
			H.crosshair(kx, cy + 9 * s, 7 * s)
			gl.Color(1, 1, 1, 1)
			gl.Text(tostring(row.kills), kx + 11 * s, cy + 9 * s, 14 * s, "vo")
			H.skull(kx, cy - 9 * s, 7 * s)
			gl.Color(1, 1, 1, 1)
			gl.Text(tostring(row.deaths), kx + 11 * s, cy - 9 * s, 14 * s, "vo")
			H.abilities(team, ax, cy, asize)
			y = ry1 - gap
		end
		if scrolling then
			-- the scroll bar: a track at the right edge of the rows and a handle (its size = the share of the rows that is visible)
			local tr1, tr2 = y1 + pad, top - head
			local bx1, bx2 = x2 - pad - 6 * s, x2 - pad
			H.box(bx1, tr1, bx2, tr2, 3 * s, { 0.02, 0.02, 0.04, 0.9 }, { 0.06, 0.06, 0.1, 0.9 })
			local len = tr2 - tr1
			local hl = math.max(16 * s, len * shown / #rows)
			local hy2 = tr2 - (len - hl) * H.scroll / math.max(1, #rows - shown)
			H.box(bx1, hy2 - hl, bx2, hy2, 3 * s, { 0.45, 0.55, 0.8, 1 }, { 0.65, 0.75, 0.95, 1 })
		end
		H.area2 = { x1, y1, x2, top }
		H.pageRows = #rows - shown
		gl.Color(1, 1, 1, 1)
		return x1, x2, y1, base
	end


	-- The buttons of the own abilities (powerups_ui.lua): a click uses one (game message "evo|use|<n>"). H.slots: the rectangles of the buttons for the mouse.
	H.slots = {}
	function H.bar(x1, y1, x2, y2, s)
		local mine = Spring.GetMyTeamID()
		local unit = Spring.GetTeamRulesParam(mine, "evoUnit")
		U.bar({ team = mine, rule = "evoAbilities", unit = (unit and unit > 0) and unit or nil, slots = H.slots }, x1, y1, x2, y2, s)
	end

	-- The own character at the bottom in the middle (where the game shows the selected units: only one unit is played): a big level badge, the unit, the
	-- points bar, kills and deaths, the buttons of the abilities. H.area: its rectangle for the mouse.
	function H.character(s)
		H.slots, H.area, H.dbg = {}, nil, nil
		local mine = Spring.GetMyTeamID()
		if Spring.GetSpectatingState() or not Spring.GetTeamRulesParam(mine, "evoStage") then
			return
		end
		local function p(k) return Spring.GetTeamRulesParam(mine, k) or 0 end
		local vsx = Spring.GetViewGeometry()
		local w, h = math.floor(720 * s), math.floor(104 * s)
		-- docked well to the left of the music player and the player list of the game at the bottom right (about 330 at 1080 lines), clear of the order menu
		-- and the grid of the build menu at the left (up to 45 % of the width): narrower when the screen is small
		local x2 = math.floor(vsx - 330 * s)
		local x1 = math.max(math.floor(vsx * 0.45), x2 - w)
		local y1 = math.floor(8 * s)
		local y2 = y1 + h
		local out = p("evoOut") == 1
		local r, g, b = Spring.GetTeamColor(mine)
		r, g, b = r or 1, g or 1, b or 1
		H.box(x1, y1, x2, y2, 10 * s, { 0.03, 0.04, 0.07, 0.85 }, { 0.10, 0.12, 0.18, 0.85 }, { 0.55, 0.65, 0.85, 0.5 })
		-- level badge
		local bx, by, br = x1 + 52 * s, (y1 + y2) / 2, 38 * s
		H.disc(bx, by, br, out and { 0.25, 0.25, 0.25, 1 } or { r * 0.45, g * 0.45, b * 0.45, 1 })
		gl.LineWidth(3)
		H.ring(bx, by, br, out and { 0.5, 0.5, 0.5, 1 } or { r, g, b, 1 })
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
		gl.Text(out and "-" or tostring(p("evoStage")), bx, by + 4 * s, 32 * s, "cvo")
		gl.Color(0.75, 0.8, 0.9, 1)
		gl.Text("LEVEL", bx, by - 22 * s, 10 * s, "cvo")
		-- unit, points, kills and deaths
		local nx = bx + br + 14 * s
		local unit = Spring.GetTeamRulesParam(mine, "evoName") or ""
		gl.Color(1, 1, 1, 1)
		gl.Text(out and "Out" or (NAMES[unit] or unit), nx, y2 - 14 * s, 18 * s, "vo")
		local need = p("evoNeed")
		local px1, px2 = nx, nx + 210 * s
		local frac = out and 0 or (need > 0 and math.min(1, p("evoXp") / need) or 1)
		local py = y1 + 66 * s
		H.box(px1, py - 9 * s, px2, py + 9 * s, 9 * s, { 0.02, 0.02, 0.04, 0.9 }, { 0.06, 0.06, 0.1, 0.9 }, { 0.4, 0.45, 0.6, 0.6 })
		if frac > 0 then
			local fill = need > 0 and { { 0.1, 0.55, 0.3, 1 }, { 0.35, 0.95, 0.6, 1 } } or { { 0.7, 0.45, 0.05, 1 }, { 1, 0.85, 0.3, 1 } }
			H.box(px1 + 1, py - 8 * s, px1 + 1 + math.max(16 * s, (px2 - px1 - 2) * frac), py + 8 * s, 8 * s, fill[1], fill[2])
		end
		gl.Color(1, 1, 1, 1)
		gl.Text(out and "" or (need > 0 and string.format("%d / %d points", p("evoXp"), need) or "MAX"), (px1 + px2) / 2, py, 12 * s, "cvo")
		-- the experience bar under the points: the bonus of the unit (+0.1 for a kill of a player, -0.1 for a death), kept through the levels
		local exp = p("evoExp")
		local ey = y1 + 43 * s
		H.box(px1, ey - 6 * s, px2, ey + 6 * s, 6 * s, { 0.02, 0.02, 0.04, 0.9 }, { 0.06, 0.06, 0.1, 0.9 }, { 0.4, 0.45, 0.6, 0.6 })
		if not out and exp > 0 then
			H.box(px1 + 1, ey - 5 * s, px1 + 1 + math.max(12 * s, (px2 - px1 - 2) * exp / (exp + 1)), ey + 5 * s, 5 * s, { 0.3, 0.2, 0.6, 1 }, { 0.65, 0.5, 1, 1 })
		end
		gl.Color(1, 1, 1, 1)
		gl.Text(out and "" or string.format("XP %.1f", exp), (px1 + px2) / 2, ey, 11 * s, "cvo")
		local ky = y1 + 18 * s
		H.crosshair(nx + 8 * s, ky, 8 * s)
		gl.Color(1, 1, 1, 1)
		gl.Text(tostring(p("evoKills")) .. " kills", nx + 20 * s, ky, 13 * s, "vo")
		H.skull(nx + 112 * s, ky, 8 * s)
		gl.Color(1, 1, 1, 1)
		gl.Text(tostring(p("evoDeaths")) .. " deaths", nx + 124 * s, ky, 13 * s, "vo")
		-- the abilities
		H.bar(px2 + 20 * s, y1 + 10 * s, x2 - 10 * s, y2 - 10 * s, s)
		-- debug mode (game option lanevodebug, the menu of the room): three buttons above the panel
		H.dbg = nil
		H.dbgShow = nil
		if (Spring.GetModOptions() or {}).lanevodebug == "1" and not H.dbgHidden then
			H.dbg = {}
			local bh = 30 * s
			local by1, by2 = y2 + 6 * s, y2 + 6 * s + bh
			-- label, width, colors (below, above), arrow, "XP" text: the buttons 1 to 5; then one per power-up (the buttons 6 to 10)
			local specs = { { "Armageddon", 124, { 0.35, 0.12, 0.1 }, { 0.6, 0.25, 0.15 } }, { "Level Up", 100, { 0.08, 0.35, 0.12 }, { 0.2, 0.65, 0.3 }, "up" },
				{ "Level Down", 108, { 0.4, 0.08, 0.08 }, { 0.75, 0.2, 0.2 }, "down" }, { "XP", 66, { 0.08, 0.35, 0.12 }, { 0.2, 0.65, 0.3 }, "up", true },
				{ "XP", 66, { 0.4, 0.08, 0.08 }, { 0.75, 0.2, 0.2 }, "down", true } }
			local bx = x1
			for i, sp in ipairs(specs) do
				local bw = sp[2] * s
				H.dbg[i] = { bx, by1, bx + bw, by2 }
				H.box(bx, by1, bx + bw, by2, 5 * s, { sp[3][1], sp[3][2], sp[3][3], 0.95 }, { sp[4][1], sp[4][2], sp[4][3], 0.95 }, { 1, 1, 1, 0.8 }, 2)
				gl.Color(1, 1, 1, 1)
				if sp[5] then
					-- an arrow up or down at the left of the label
					local ax, ay, q = bx + 14 * s, (by1 + by2) / 2, 6 * s
					gl.BeginEnd(GL.TRIANGLES, function()
						if sp[5] == "up" then
							gl.Vertex(ax - q, ay - q * 0.7); gl.Vertex(ax + q, ay - q * 0.7); gl.Vertex(ax, ay + q * 0.9)
						else
							gl.Vertex(ax - q, ay + q * 0.7); gl.Vertex(ax + q, ay + q * 0.7); gl.Vertex(ax, ay - q * 0.9)
						end
					end)
					gl.Text(sp[1], bx + 26 * s, (by1 + by2) / 2, 14 * s, "vo")
				else
					H.atom(bx + 17 * s, (by1 + by2) / 2, 9 * s)
					gl.Text(sp[1], bx + 32 * s, (by1 + by2) / 2, 14 * s, "vo")
				end
				bx = bx + bw + 8 * s
			end
			-- the power-ups: a button in the color of each gives it at once
			bx = bx + 6 * s
			for i, a in ipairs(ABILITIES) do
				local c = a.color
				H.dbg[5 + i] = { bx, by1, bx + bh, by2 }
				H.box(bx, by1, bx + bh, by2, 5 * s, { c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 1 }, { c[1], c[2], c[3], 1 }, { 1, 1, 1, 0.6 }, 2)
				H.icon(a.key, bx + bh / 2, (by1 + by2) / 2, 10 * s, 1)
				bx = bx + bh + 6 * s
			end
			-- the star: random level, power-ups, experience, kills and deaths for every player (the button 11); then "Hide" takes the debug buttons away for a picture
			H.dbg[11] = { bx, by1, bx + bh, by2 }
			H.box(bx, by1, bx + bh, by2, 5 * s, { 0.35, 0.28, 0.02, 1 }, { 0.85, 0.7, 0.1, 1 }, { 1, 1, 1, 0.8 }, 2)
			gl.Color(1, 0.95, 0.5, 1)
			gl.BeginEnd(GL.TRIANGLE_FAN, function()
				local cx, cy, r = bx + bh / 2, (by1 + by2) / 2, 11 * s
				gl.Vertex(cx, cy)
				for i = 0, 10 do
					local a = math.rad(90 + i * 36)
					local rr = (i % 2 == 0) and r or r * 0.42
					gl.Vertex(cx + rr * math.cos(a), cy + rr * math.sin(a))
				end
			end)
			bx = bx + bh + 6 * s
			H.dbgHide = { bx, by1, bx + 50 * s, by2 }
			H.box(bx, by1, bx + 50 * s, by2, 5 * s, { 0.15, 0.15, 0.2, 1 }, { 0.3, 0.3, 0.4, 1 }, { 1, 1, 1, 0.6 }, 2)
			gl.Color(1, 1, 1, 1)
			gl.Text("Hide", bx + 25 * s, (by1 + by2) / 2, 13 * s, "cvo")
			y2 = y2 + 40 * s
		elseif H.dbgHidden and (Spring.GetModOptions() or {}).lanevodebug == "1" then
			H.dbgShow = { x1, y2 + 6 * s, x1 + 24 * s, y2 + 6 * s + 30 * s } -- (hidden: a click on this spot brings the debug buttons back)
		end
		H.area = { x1, y1, x2, y2 }
	end

	-- The help: for every level the units of the three factions (picture and name), at the bottom what Armageddon brings. Open at the start of the game
	-- (for 40 s), the button ? at the title of the overview opens and closes it; H.helpArea: its rectangle for the mouse.
	-- (a picture for the manual, game option lanevoshot, has no help window except the picture of the help itself)
	H.helpOpen = (Spring.GetModOptions() or {}).lanevoshot == nil or (Spring.GetModOptions() or {}).lanevoshot == "help"
	function H.help(s, vsx, vsy)
		H.helpArea, H.helpClose = nil, nil
		if not H.helpOpen or Spring.GetGameFrame() > 40 * 30 and not H.helpPinned then
			return
		end
		-- two columns: at the left the units of the ten levels, at the right the power-ups and Armageddon; the window sits right of the minimap
		local L, R = math.floor(700 * s), math.floor(500 * s)
		local rowH, head = math.floor(44 * s), math.floor(64 * s)
		local uh = math.floor(46 * s)
		local W, Hh = L + R + math.floor(46 * s), head + uh + 10 * rowH + math.floor(14 * s)
		local x1 = math.floor(math.max(vsx * 0.26, (vsx - W) / 2))
		if x1 + W > vsx - 8 then
			x1 = math.max(8, vsx - 8 - W)
		end
		local y1 = math.floor((vsy - Hh) / 2)
		local x2, y2 = x1 + W, y1 + Hh
		H.box(x1, y1, x2, y2, 12 * s, { 0.02, 0.03, 0.06, 0.94 }, { 0.08, 0.10, 0.16, 0.94 }, { 0.55, 0.65, 0.85, 0.7 }, 2)
		gl.Color(0.55, 0.95, 0.7, 1)
		gl.Text("EVOLUTION: help", x1 + 24 * s, y2 - 26 * s, 24 * s, "vo")
		gl.Color(0.8, 0.85, 0.95, 1)
		gl.Text("Kill to level up. Your unit becomes one of a random faction of the next level.", x1 + 24 * s, y2 - 50 * s, 13 * s, "vo")
		-- the close button
		local cb = 28 * s
		H.helpClose = { x2 - cb - 14 * s, y2 - cb - 12 * s, x2 - 14 * s, y2 - 12 * s }
		H.box(H.helpClose[1], H.helpClose[2], H.helpClose[3], H.helpClose[4], 5 * s, { 0.3, 0.1, 0.1, 0.95 }, { 0.5, 0.18, 0.18, 0.95 }, { 1, 0.8, 0.8, 0.9 }, 2)
		gl.Color(1, 1, 1, 1)
		gl.Text("X", (H.helpClose[1] + H.helpClose[3]) / 2, (H.helpClose[2] + H.helpClose[4]) / 2, 16 * s, "cvo")
		-- the units (left)
		local labels = { "Armada", "Cortex", "Legion" }
		local cx0, cw = x1 + 78 * s, (L - 66 * s) / 3
		local top = y2 - head - uh
		gl.Color(0.55, 0.95, 0.7, 1)
		gl.Text("UNITS per level (examples: there are more of each level)", x1 + 24 * s, top + 30 * s, 16 * s, "vo")
		for c, label in ipairs(labels) do
			gl.Color(0.7, 0.8, 1, 1)
			gl.Text(label, cx0 + (c - 1) * cw + 4 * s, top + 8 * s, 14 * s, "vo")
		end
		for lv = 1, 10 do
			local ry2 = top - (lv - 1) * rowH
			local ry1 = ry2 - rowH + 3 * s
			H.box(x1 + 12 * s, ry1, x1 + 12 * s + L, ry2 - 3 * s, 6 * s, { 0.07, 0.08, 0.12, 0.9 }, { 0.12, 0.14, 0.20, 0.9 })
			local by = (ry1 + ry2 - 3 * s) / 2
			H.disc(x1 + 40 * s, by, 16 * s, { 0.12, 0.2, 0.45, 1 })
			gl.LineWidth(2)
			H.ring(x1 + 40 * s, by, 16 * s, { 0.5, 0.65, 1, 1 })
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 1)
			gl.Text(tostring(lv), x1 + 40 * s, by, 16 * s, "cvo")
			for c, ladder in ipairs(LADDERS) do
				local name = ladder[lv]
				local def = UnitDefNames[name]
				if def then
					local px = cx0 + (c - 1) * cw
					local ps = rowH - 10 * s
					gl.Color(1, 1, 1, 1)
					gl.Texture("#" .. def.id)
					gl.TexRect(px, by - ps / 2, px + ps, by + ps / 2)
					gl.Texture(false)
					gl.Color(0.5, 0.55, 0.7, 0.8)
					gl.LineWidth(1)
					gl.BeginEnd(GL.LINE_LOOP, function()
						gl.Vertex(px, by - ps / 2); gl.Vertex(px + ps, by - ps / 2); gl.Vertex(px + ps, by + ps / 2); gl.Vertex(px, by + ps / 2)
					end)
					gl.Color(1, 1, 1, 1)
					gl.Text(NAMES[name] or name, px + ps + 8 * s, by, 14 * s, "vo")
				end
			end
		end
		-- the power-ups (right, top): a beacon of the color lies on the map, a unit that drives over it has the ability until it dies
		local rx = x1 + 12 * s + L + 22 * s
		local ay = y2 - head - 2 * s
		gl.Color(0.55, 0.95, 0.7, 1)
		gl.Text("POWER-UPS", rx, ay - 10 * s, 16 * s, "vo")
		gl.Color(0.8, 0.85, 0.95, 1)
		gl.Text("Drive over a glowing beacon; you keep it until your unit dies.", rx + 120 * s, ay - 10 * s, 11 * s, "vo")
		for i, a in ipairs(ABILITIES) do
			local byy = ay - 32 * s - (i - 1) * 44 * s
			local c = a.color
			H.box(rx, byy - 34 * s, rx + 34 * s, byy, 6 * s, { c[1] * 0.4, c[2] * 0.4, c[3] * 0.4, 1 }, { c[1], c[2], c[3], 1 }, { 1, 1, 1, 0.5 }, 2)
			H.icon(a.key, rx + 17 * s, byy - 17 * s, 12 * s, 1)
			gl.Color(c[1], c[2], c[3], 1)
			gl.Text(a.name .. "   (" .. a.cost .. " energy, " .. a.cool .. " s cooldown)", rx + 44 * s, byy - 9 * s, 13 * s, "vo")
			gl.Color(0.82, 0.86, 0.94, 1)
			gl.Text(a.tip, rx + 44 * s, byy - 26 * s, 10.5 * s, "vo")
		end
		-- Armageddon (right, bottom)
		local fy = ay - 32 * s - 5 * 44 * s - 34 * s
		gl.Color(1, 0.4, 0.25, 1)
		gl.Text("ARMAGEDDON", rx, fy - 8 * s, 16 * s, "vo")
		gl.Color(0.85, 0.88, 0.95, 1)
		gl.Text("(when a player reaches level 10)", rx + 140 * s, fy - 8 * s, 11.5 * s, "vo")
		gl.Color(0.85, 0.88, 0.95, 1)
		gl.Text("No fog of war, no respawn, the last one standing wins.", rx, fy - 28 * s, 11.5 * s, "vo")
		gl.Text("The first one on level 10 chooses a gift:", rx, fy - 44 * s, 11.5 * s, "vo")
		-- the three gifts as small buttons in the colors of the window of the gifts (red, blue, atom yellow)
		local gifts = {
			{ "Hell on Earth", "8 tier 3 units; lost ones replaced, +1 every 30 s", { 0.22, 0.02, 0.02 }, { 0.75, 0.13, 0.04 }, { 1, 0.55, 0.2 } },
			{ "Heaven on Earth", "8 Dragons around you; lost ones replaced, +1 every 30 s", { 0.03, 0.10, 0.32 }, { 0.22, 0.52, 0.98 }, { 0.7, 0.88, 1 } },
			{ "Gates of Hell", "Nuclear missiles without end, ever closer to the enemies", { 0.07, 0.07, 0.01 }, { 0.38, 0.34, 0.03 }, { 1, 0.9, 0.1 } },
		}
		for g, gift in ipairs(gifts) do
			local gy2 = fy - 54 * s - (g - 1) * 34 * s
			H.box(rx, gy2 - 28 * s, x2 - 16 * s, gy2, 5 * s, { gift[3][1], gift[3][2], gift[3][3], 0.96 }, { gift[4][1], gift[4][2], gift[4][3], 0.96 }, { gift[5][1], gift[5][2], gift[5][3], 1 }, 2)
			gl.Color(gift[5][1], gift[5][2], gift[5][3], 1)
			gl.Text(gift[1], rx + 10 * s, gy2 - 14 * s, 13 * s, "vo")
			gl.Color(1, 1, 1, 1)
			gl.Text(gift[2], rx + 130 * s, gy2 - 14 * s, 10 * s, "vo")
		end
		H.helpArea = { x1, y1, x2, y2 }
		gl.Color(1, 1, 1, 1)
	end

	local function slotAt(x, y)
		for i, r in pairs(H.slots) do
			if x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] then
				return i
			end
		end
	end

	local function inside(r, x, y)
		return r ~= nil and x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4]
	end

	function gadget:IsAbove(x, y)
		return inside(H.area, x, y) or inside(H.area2, x, y) or inside(H.helpArea, x, y)
	end

	-- the mouse wheel over the overview scrolls its rows (only when some are out of view)
	function gadget:MouseWheel(up, value)
		local x, y = Spring.GetMouseState()
		if inside(H.area2, x, y) and (H.pageRows or 0) > 0 then
			H.scroll = (H.scroll or 0) + (up and -1 or 1)
			return true
		end
		return false
	end

	function gadget:MousePress(x, y, button)
		if button == 1 and H.dbgHide and H.dbg and inside(H.dbgHide, x, y) then
			H.dbgHidden = true
			return true
		end
		if button == 1 and H.dbgShow and inside(H.dbgShow, x, y) then
			H.dbgHidden = false
			return true
		end
		if button == 1 and H.dbg then
			for i, r in ipairs(H.dbg) do
				if inside(r, x, y) then
					Spring.SendLuaRulesMsg("evo|debug|" .. i)
					return true
				end
			end
		end
		if button == 1 and H.helpClose and inside(H.helpClose, x, y) then
			H.helpOpen = false
			return true
		end
		if button == 1 and H.helpBtn and not H.hidden and inside(H.helpBtn, x, y) then
			H.helpOpen = not H.helpOpen
			H.helpPinned = H.helpOpen
			return true
		end
		if H.helpArea and inside(H.helpArea, x, y) then
			return true
		end
		if H.helpArea and not (H.helpBtn and inside(H.helpBtn, x, y)) then
			H.helpOpen = false -- a click outside the help closes it (the click itself goes on to the game)
		end
		if button == 1 and inside(H.toggle, x, y) then
			H.hidden = not H.hidden
			return true
		end
		local i = slotAt(x, y)
		if i and button == 1 then
			Spring.SendLuaRulesMsg("evo|use|" .. i)
			return true
		end
		return gadget:IsAbove(x, y) and true -- (a click on the bar between the buttons does not reach the map)
	end

	function gadget:MouseRelease()
		return false
	end

	function gadget:Initialize()
		gadgetHandler:AddSyncAction("evoHeal", function(_, unitID, amount) G.healAdd(unitID, amount) end)
	end

	function gadget:DrawScreen()
		G.healDraw((select(2, Spring.GetViewGeometry())))
		local state = Spring.GetGameRulesParam("evoState") or ""
		if state == "" then
			return
		end
		local vsx, vsy = Spring.GetViewGeometry()
		local arma = Spring.GetGameRulesParam("evoArmageddon") or 0
		local _, _, _, s = H.panel(state, arma)
		H.character(s)
		H.help(s, vsx, vsy)
		-- radars being taken: "Taking 3/5" in the color of the taker above the radar
		for x, z, secs, t in tostring(Spring.GetGameRulesParam("evoTaking") or ""):gmatch("(%d+),(%d+),(%d+),(%d+)") do
			x, z = tonumber(x), tonumber(z)
			local sx, sy, onScreen = Spring.WorldToScreenCoords(x, Spring.GetGroundHeight(x, z) + 90, z)
			if onScreen ~= false and Spring.IsSphereInView(x, Spring.GetGroundHeight(x, z), z, 60) then
				local r, g, b = Spring.GetTeamColor(tonumber(t))
				gl.Color(r or 1, g or 1, b or 1, 1)
				gl.Text(string.format("Taking %d/5", tonumber(secs)), sx, sy, 18 * s, "co")
			end
		end
		-- the first 10 seconds of Armageddon: big letters above the middle of the screen (above the window of the gift)
		if arma > 0 and Spring.GetGameFrame() - arma < 300 then
			gl.Color(1, 0.25, 0.15, 1)
			gl.Text("ARMAGEDDON IS HERE", vsx * 0.5, vsy * 0.76, 46 * s, "co")
			gl.Color(1, 0.85, 0.6, 1)
			gl.Text(tostring(Spring.GetGameRulesParam("evoHero") or "") .. " reached level 10. The fog of war is gone: everybody sees everybody.", vsx * 0.5, vsy * 0.76 - 42 * s, 18 * s, "co")
			gl.Text("A lost unit does not come back any more. The last one standing wins.", vsx * 0.5, vsy * 0.76 - 68 * s, 18 * s, "co")
		end
		gl.Color(1, 1, 1, 1)
	end


	-- the beacons of the abilities: a column of light and a pulsing ring (powerups_ui.lua)
	function gadget:DrawWorld()
		U.drawBeacons("evoBeacons")
	end

	-- red rings where the next nuclear missiles come down (Gates of Hell)
	function gadget:DrawWorldPreUnit()
		local text = Spring.GetGameRulesParam("evoNukes")
		if not text or text == "" then
			return
		end
		local pulse = 0.55 + 0.45 * math.sin(Spring.GetGameFrame() * 0.3)
		gl.DepthTest(false)
		gl.LineWidth(3)
		gl.Color(1, 0.1, 0.05, pulse)
		for x, z in text:gmatch("(%d+),(%d+)") do
			x, z = tonumber(x), tonumber(z)
			local y = Spring.GetGroundHeight(x, z)
			gl.DrawGroundCircle(x, y, z, 600, 48)
			gl.DrawGroundCircle(x, y, z, 120, 24)
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
	end
end
