-- Drawing of the power-ups (Sprint, Repair, Radar Pulse, Cloak, Jammer), for the widgets and the unsynced part of a gadget: the shapes of the panels (U.box, U.disc, U.ring, U.icon),
-- the state of the abilities of a team (U.state), the bar of buttons (U.bar) and the beacons on the map (U.drawBeacons). Used by evo_ui.lua (Evolution) and renegade.lua.
local P = VFS.Include("luaui/Include/powerups.lua", nil, VFS.ZIP_FIRST)
local ABILITIES = P.ABILITIES
local U = { ABILITIES = ABILITIES }

-- The abilities of a team from its team rule "index:seconds of cooldown left:seconds the effect still lasts,...": index -> { cool, act }
function U.state(team, rule)
	local have = {}
	local list = Spring.GetTeamRulesParam(team, rule)
	if type(list) == "string" then
		for i, cool, act in list:gmatch("(%d+):(%d+):(%d+)") do
			have[tonumber(i)] = { cool = tonumber(cool), act = tonumber(act) }
		end
	end
	return have
end
-- the outline of a box with round corners (a list of points, counterclockwise)
function U.outline(x1, y1, x2, y2, r)
	local pts = {}
	for _, c in ipairs({ { x2 - r, y2 - r, 0 }, { x1 + r, y2 - r, 90 }, { x1 + r, y1 + r, 180 }, { x2 - r, y1 + r, 270 } }) do
		for k = 0, 4 do
			local a = math.rad(c[3] + k * 22.5)
			pts[#pts + 1] = { c[1] + r * math.cos(a), c[2] + r * math.sin(a) }
		end
	end
	return pts
end

-- a box with round corners, color `bottom` below fading to `top` above (r, g, b, a); `line`: a border in that color
function U.box(x1, y1, x2, y2, r, bottom, top, line, width)
	local pts = U.outline(x1, y1, x2, y2, r)
	local function col(y)
		local t = (y - y1) / math.max(1, y2 - y1)
		gl.Color(bottom[1] + (top[1] - bottom[1]) * t, bottom[2] + (top[2] - bottom[2]) * t, bottom[3] + (top[3] - bottom[3]) * t, bottom[4] + (top[4] - bottom[4]) * t)
	end
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		col((y1 + y2) / 2)
		gl.Vertex((x1 + x2) / 2, (y1 + y2) / 2)
		for _, p in ipairs(pts) do
			col(p[2])
			gl.Vertex(p[1], p[2])
		end
		col(pts[1][2])
		gl.Vertex(pts[1][1], pts[1][2])
	end)
	if line then
		gl.Color(line[1], line[2], line[3], line[4])
		gl.LineWidth(width or 1)
		gl.BeginEnd(GL.LINE_LOOP, function()
			for _, p in ipairs(pts) do
				gl.Vertex(p[1], p[2])
			end
		end)
		gl.LineWidth(1)
	end
end

function U.disc(x, y, r, c)
	gl.Color(c[1], c[2], c[3], c[4] or 1)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Vertex(x, y)
		for k = 0, 24 do
			local a = k / 24 * 2 * math.pi
			gl.Vertex(x + r * math.cos(a), y + r * math.sin(a))
		end
	end)
end

function U.ring(x, y, r, c)
	gl.Color(c[1], c[2], c[3], c[4] or 1)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for k = 0, 23 do
			local a = k / 24 * 2 * math.pi
			gl.Vertex(x + r * math.cos(a), y + r * math.sin(a))
		end
	end)
end

-- the symbol of an ability, white lines in a square of radius r around x, y: sprint a double arrow, repair a plus, cloak a crossed out eye, the pulse a dot
-- with radar waves, the jammer a zigzag wave
function U.icon(key, x, y, r, alpha)
	alpha = alpha or 1
	gl.Color(1, 1, 1, alpha)
	gl.LineWidth(2)
	if key == "sprint" then
		gl.BeginEnd(GL.LINES, function()
			for _, dx in ipairs({ -0.55, 0.15 }) do
				gl.Vertex(x + (dx) * r, y + 0.7 * r)
				gl.Vertex(x + (dx + 0.55) * r, y)
				gl.Vertex(x + (dx + 0.55) * r, y)
				gl.Vertex(x + (dx) * r, y - 0.7 * r)
			end
		end)
	elseif key == "repair" then
		local w = 0.28 * r
		U.box(x - w, y - 0.8 * r, x + w, y + 0.8 * r, w * 0.4, { 1, 1, 1, alpha }, { 1, 1, 1, alpha })
		U.box(x - 0.8 * r, y - w, x + 0.8 * r, y + w, w * 0.4, { 1, 1, 1, alpha }, { 1, 1, 1, alpha })
	elseif key == "cloak" then
		gl.BeginEnd(GL.LINE_LOOP, function()
			for k = 0, 15 do
				local a = k / 16 * 2 * math.pi
				gl.Vertex(x + 0.9 * r * math.cos(a), y + 0.45 * r * math.sin(a))
			end
		end)
		U.disc(x, y, 0.22 * r, { 1, 1, 1, alpha })
		gl.BeginEnd(GL.LINES, function()
			gl.Vertex(x - 0.8 * r, y - 0.8 * r)
			gl.Vertex(x + 0.8 * r, y + 0.8 * r)
		end)
	elseif key == "pulse" then
		U.disc(x - 0.55 * r, y - 0.55 * r, 0.2 * r, { 1, 1, 1, alpha })
		for _, rr in ipairs({ 0.6, 1.1 }) do
			gl.BeginEnd(GL.LINE_STRIP, function()
				for k = 0, 6 do
					local a = k / 6 * math.pi / 2
					gl.Vertex(x - 0.55 * r + rr * r * math.cos(a), y - 0.55 * r + rr * r * math.sin(a))
				end
			end)
		end
	elseif key == "jammer" then
		gl.BeginEnd(GL.LINE_STRIP, function()
			for k = 0, 6 do
				gl.Vertex(x + (-0.9 + k * 0.3) * r, y + (k % 2 == 0 and -0.45 or 0.45) * r)
			end
		end)
	end
	gl.LineWidth(1)
end

-- The buttons of the own abilities in the rectangle x1, y1 - x2, y2: five in the order of ABILITIES, each with its color and symbol; grey and pale while the
-- team does not have it, dimmed with the seconds while it cools down, a bright border while it works; a click uses it (game message "evo|use|<n>"), the
-- mouse over a button shows what it does (above it). o = { team, rule (team rule of the abilities), unit (the unit of the player or nil), slots (a table that gets the rectangles of the buttons
-- for the mouse), labels (true: the number of the key 1 to 5 stands at the top of each button) }.
function U.bar(o, x1, y1, x2, y2, s)
	local mine = o.team
	local have = U.state(mine, o.rule)
	local energy = Spring.GetTeamResources(mine, "energy") or 0
	local gap = 6 * s
	local fw = math.max(2, 4 * s) -- the thickness of the frames
	local hp, maxHp = 0, 0
	local unit = o.unit
	if unit and unit > 0 and Spring.ValidUnitID(unit) then
		hp, maxHp = Spring.GetUnitHealth(unit)
		hp, maxHp = hp or 0, maxHp or 0
	end
	local healthy = maxHp > 0 and hp >= maxHp - 0.5 -- (Repair is not needed now)
	local n = #ABILITIES
	local bw = (x2 - x1 - (n - 1) * gap) / n
	local bh = y2 - y1
	local mx, my = Spring.GetMouseState()
	local hover, hoverX
	for i, a in ipairs(ABILITIES) do
		local bx1 = x1 + (i - 1) * (bw + gap)
		local bx2, by1, by2 = bx1 + bw, y1, y2
		local h, c = have[i], a.color
		local cx, iy = (bx1 + bx2) / 2, by2 - bh * 0.42
		if not h then
			U.box(bx1, by1, bx2, by2, 7 * s, { 0.07, 0.07, 0.09, 0.9 }, { 0.12, 0.12, 0.15, 0.9 }, { c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, 0.8 }, fw)
			U.icon(a.key, cx, iy, 14 * s, 0.25)
			gl.Color(0.5, 0.5, 0.55, 1)
		else
			local cooling = h.cool > 0 and h.act == 0
			local k = cooling and 0.3 or 1
			local pulse = 0.6 + 0.4 * math.sin(Spring.GetGameFrame() * 0.25)
			U.box(bx1, by1, bx2, by2, 7 * s, { c[1] * 0.35 * k, c[2] * 0.35 * k, c[3] * 0.35 * k, 0.95 }, { c[1] * 0.85 * k, c[2] * 0.85 * k, c[3] * 0.85 * k, 0.95 },
				h.act > 0 and { 1, 1, 1, pulse } or { c[1], c[2], c[3], cooling and 0.55 or 1 }, fw)
			U.icon(a.key, cx, iy, 14 * s, cooling and 0.45 or 1)
			if cooling then
				-- the cooldown as a grey fill that runs down like a status bar (full at the start, empty when ready)
				local top2 = by1 + (by2 - by1) * math.min(1, h.cool / a.cool)
				U.box(bx1 + 2, by1 + 2, bx2 - 2, math.max(by1 + 6 * s, top2), 6 * s, { 0.25, 0.25, 0.28, 0.8 }, { 0.38, 0.38, 0.42, 0.8 })
				U.icon(a.key, cx, iy, 14 * s, 0.35)
			end
			if h.act > 0 then
				-- the time the effect still lasts: a bright fill in the color of the ability runs down like the cooldown (full at the start)
				local top3 = by1 + (by2 - by1) * math.min(1, h.act / a.time)
				U.box(bx1 + 2, by1 + 2, bx2 - 2, math.max(by1 + 6 * s, top3), 6 * s, { c[1], c[2], c[3], 0.45 }, { c[1], c[2], c[3], 0.7 })
				U.icon(a.key, cx, iy, 14 * s, 1)
			end
			gl.Color(1, 1, 1, cooling and 0.6 or 1)
		end
		if o.labels then
			gl.Color(1, 1, 1, h and 0.9 or 0.4)
			gl.Text(tostring(i), cx, by2 - 9 * s, 11 * s, "cvo") -- (the key that uses it)
			gl.Color(1, 1, 1, 1)
		end
		local w1, w2 = a.name:match("^(%S+)%s+(%S+)$")
		if w1 then
			gl.Text(w1, cx, by1 + 19 * s, 11 * s, "cvo") -- (two words: one line each, not too close to the edges)
			gl.Text(w2, cx, by1 + 8 * s, 11 * s, "cvo")
		else
			gl.Text(a.name, cx, by1 + 11 * s, 12 * s, "cvo")
		end
		if a.key == "repair" and h and healthy and h.act == 0 and h.cool == 0 then
			-- (not greyed: marked, a click does nothing now)
			gl.Color(0.6, 1, 0.7, 1)
			gl.Text("not needed", cx, by1 + 30 * s, 9 * s, "cvo")
		end
		if not (h and h.act > 0) then
			-- the energy it costs, top right: yellow, red when the energy is short (while it works the seconds left stand there)
			if energy < a.cost then
				gl.Color(1, 0.35, 0.3, h and 1 or 0.6)
			else
				gl.Color(1, 0.9, 0.35, h and 1 or 0.6)
			end
			gl.Text(tostring(a.cost), bx2 - 5 * s, by2 - 9 * s, 11 * s, "rvo")
		end
		-- the cooldown, top left
		if h and h.act > 0 then
			gl.Color(1, 1, 1, 1)
			gl.Text(h.act .. " s", bx1 + 5 * s, by2 - 9 * s, 12 * s, "vo") -- (the effect: the seconds left count down here too)
		elseif h and h.cool > 0 then
			-- while it cools down the number counts down here, from the cooldown to 0, then the normal text is back
			gl.Color(1, 1, 1, 1)
			gl.Text(h.cool .. " s", bx1 + 5 * s, by2 - 9 * s, 12 * s, "vo")
		else
			gl.Color(0.8, 0.85, 0.95, h and 0.9 or 0.5)
			gl.Text(a.cool .. " s", bx1 + 5 * s, by2 - 9 * s, 10 * s, "vo")
		end
		o.slots[i] = { bx1, by1, bx2, by2 }
		if mx >= bx1 and mx <= bx2 and my >= by1 and my <= by2 then
			hover, hoverX = i, cx
		end
	end
	if hover then
		-- the explanation above the button
		local a, h = ABILITIES[hover], have[hover]
		local lines = { a.tip }
		if a.info then
			lines[#lines + 1] = a.info -- (an extra line of the tooltip, e.g. what Cloak does to the fire state)
		end
		lines[#lines + 1] = "Cost " .. a.cost .. " energy, cooldown " .. a.cool .. " s"
		lines[#lines + 1] = not h and ("Not yet yours: drive over a beacon of this color") or (h.act > 0 and ("Working: " .. h.act .. " s left")) or (h.cool > 0 and ("Ready again in " .. h.cool .. " s"))
			or (a.key == "repair" and healthy and "Not needed now: full health") or (energy < a.cost and "Not enough energy") or "Click to use"
		local tw = 0
		for _, l in ipairs(lines) do
			tw = math.max(tw, gl.GetTextWidth(l) * 13 * s)
		end
		tw = math.max(tw, gl.GetTextWidth(a.name) * 16 * s) + 20 * s
		local th = 26 * s + #lines * 17 * s
		local vsx = Spring.GetViewGeometry()
		local tx1 = math.max(4 * s, math.min(vsx - tw - 4 * s, hoverX - tw / 2))
		local ty1 = y2 + 22 * s
		local tx2, ty2 = tx1 + tw, ty1 + th
		U.box(tx1, ty1, tx2, ty2, 6 * s, { 0.02, 0.03, 0.05, 0.92 }, { 0.08, 0.09, 0.13, 0.92 }, { a.color[1], a.color[2], a.color[3], 0.8 })
		gl.Color(a.color[1], a.color[2], a.color[3], 1)
		gl.Text(a.name, tx1 + 10 * s, ty2 - 15 * s, 16 * s, "vo")
		gl.Color(0.9, 0.92, 0.97, 1)
		for k, l in ipairs(lines) do
			gl.Text(l, tx1 + 10 * s, ty2 - 22 * s - k * 17 * s + 4 * s, 13 * s, "vo")
		end
	end
	gl.Color(1, 1, 1, 1)
end

-- the beacons of the abilities: a column of light in the color of the ability and a pulsing ring on the ground, only where the own team sees
-- (a spectator sees all)
function U.drawBeacons(rule)
	local text = Spring.GetGameRulesParam(rule)
	if not text or text == "" then
		return
	end
	local spec, fullView = Spring.GetSpectatingState()
	local ally = Spring.GetMyAllyTeamID()
	local f = Spring.GetGameFrame() + (Spring.GetFrameTimeOffset and Spring.GetFrameTimeOffset() or 0)
	local pulse = 0.6 + 0.4 * math.sin(f * 0.15)
	gl.DepthTest(true)
	gl.Blending(GL.SRC_ALPHA, GL.ONE) -- (adding light)
	for x, z, k in text:gmatch("(%d+),(%d+),(%d+)") do
		x, z = tonumber(x), tonumber(z)
		local a = ABILITIES[tonumber(k)]
		local y = Spring.GetGroundHeight(x, z)
		if a and ((spec and fullView) or Spring.IsPosInLos(x, y, z, ally)) and Spring.IsSphereInView(x, y + 100, z, 220) then
			local r, g, b = a.color[1], a.color[2], a.color[3]
			-- the column: two crossed quads, bright at the bottom, fading to the top
			gl.BeginEnd(GL.QUADS, function()
				for _, d in ipairs({ { 14, 0 }, { 0, 14 } }) do
					gl.Color(r, g, b, 0.75 * pulse)
					gl.Vertex(x - d[1], y, z - d[2])
					gl.Vertex(x + d[1], y, z + d[2])
					gl.Color(r, g, b, 0)
					gl.Vertex(x + d[1], y + 320, z + d[2])
					gl.Vertex(x - d[1], y + 320, z - d[2])
				end
			end)
			gl.LineWidth(3)
			gl.Color(r, g, b, 0.9 * pulse)
			gl.DrawGroundCircle(x, y, z, 40 + 10 * pulse, 32)
			gl.Color(r, g, b, 0.5)
			gl.DrawGroundCircle(x, y, z, 80, 32)
		end
	end
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
	gl.DepthTest(false)
end

return U
