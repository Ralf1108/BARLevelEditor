-- Evolution (LAN Play): the window in which a player on stage 10 chooses a gift. A game widget of the extra game "Level Editor Scenarios" (no "Allow user
-- widgets" needed); active only in an Evolution game (game option lanevolution=1). The gadget evo_game.lua sets the team rules parameter evoGift = 1 while the
-- own team may choose; a click on a gift (or the key 1, 2, 3) sends "evo|gift|<n>". Without a choice the gadget gives a random gift after 30 s.
function widget:GetInfo()
	return {
		name = "Evolution: gift of level 10",
		desc = "Choose the gift of level 10 in an Evolution game of LAN Play",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1000,
		enabled = true,
	}
end

-- name, two lines of text, colors of the button (below, above, border) and its symbol
local GIFTS = {
	{ "Hell on Earth", "8 tier 3 units rise; a lost one", "is replaced, one more every 30 s.", { 0.22, 0.02, 0.02 }, { 0.75, 0.13, 0.04 }, { 1, 0.55, 0.2 }, "flame" },
	{ "Heaven on Earth", "8 Dragons around you; a lost one", "is replaced, one more every 30 s.", { 0.03, 0.10, 0.32 }, { 0.22, 0.52, 0.98 }, { 0.7, 0.88, 1 }, "wings" },
	{ "Gates of Hell", "Nuclear missiles without end,", "ever closer to the enemies.", { 0.07, 0.07, 0.01 }, { 0.38, 0.34, 0.03 }, { 1, 0.9, 0.1 }, "atom" },
}

local sent = nil -- the frame a choice was sent (the window waits for the gadget then)

function widget:Initialize()
	local mo = Spring.GetModOptions() or {}
	if mo.lanevolution ~= "1" then
		widgetHandler:RemoveWidget(self)
	end
end

local function open()
	if Spring.GetSpectatingState() then
		return false
	end
	local on = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoGift") == 1
	if not on then
		sent = nil
	end
	return on and not sent
end

-- the window and its three buttons: x1, y1, x2, y2 of the window and a list of button rectangles
local function layout()
	local vsx, vsy = Spring.GetViewGeometry()
	local s = math.max(0.6, math.min(1.6, vsy / 1080))
	local w, h = 1080 * s, 390 * s
	local x1, y1 = (vsx - w) / 2, vsy * 0.3
	local buttons = {}
	local bw, gap = (w - 80 * s) / 3, 20 * s
	for i = 1, 3 do
		local bx = x1 + 20 * s + (i - 1) * (bw + gap)
		buttons[i] = { x1 = bx, y1 = y1 + 34 * s, x2 = bx + bw, y2 = y1 + 300 * s }
	end
	return x1, y1, x1 + w, y1 + h, buttons, s
end

local function choose(i)
	Spring.SendLuaRulesMsg("evo|gift|" .. i)
	sent = Spring.GetGameFrame()
end

-- a rectangle with a vertical gradient (below -> above) and a border
local function panel(x1, y1, x2, y2, bottom, top, line, width, k)
	gl.BeginEnd(GL.QUADS, function()
		gl.Color(bottom[1] * k, bottom[2] * k, bottom[3] * k, 0.96); gl.Vertex(x1, y1); gl.Vertex(x2, y1)
		gl.Color(top[1] * k, top[2] * k, top[3] * k, 0.96); gl.Vertex(x2, y2); gl.Vertex(x1, y2)
	end)
	gl.Color(line[1], line[2], line[3], 1)
	gl.LineWidth(width)
	gl.BeginEnd(GL.LINE_LOOP, function() gl.Vertex(x1, y1); gl.Vertex(x2, y1); gl.Vertex(x2, y2); gl.Vertex(x1, y2) end)
	gl.LineWidth(1)
end

local function fan(cx, cy, r, a1, a2, steps)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Vertex(cx, cy)
		for i = 0, steps do
			local a = math.rad(a1 + (a2 - a1) * i / steps)
			gl.Vertex(cx + r * math.cos(a), cy + r * math.sin(a))
		end
	end)
end

local function tri(x1, y1, x2, y2, x3, y3)
	gl.BeginEnd(GL.TRIANGLES, function() gl.Vertex(x1, y1); gl.Vertex(x2, y2); gl.Vertex(x3, y3) end)
end

-- the symbols: a flame (Hell on Earth), wings with a halo (Heaven on Earth), the radiation trefoil (Gates of Hell); r = size
local function symbol(kind, cx, cy, r, color)
	if kind == "flame" then
		gl.Color(1, 0.35, 0.05, 1)
		tri(cx - 0.55 * r, cy - 0.8 * r, cx + 0.55 * r, cy - 0.8 * r, cx, cy + 1.0 * r)
		tri(cx - 0.9 * r, cy - 0.8 * r, cx - 0.2 * r, cy - 0.8 * r, cx - 0.75 * r, cy + 0.2 * r)
		tri(cx + 0.9 * r, cy - 0.8 * r, cx + 0.2 * r, cy - 0.8 * r, cx + 0.75 * r, cy + 0.2 * r)
		fan(cx, cy - 0.8 * r, 0.55 * r, 0, 180, 12)
		gl.Color(1, 0.85, 0.2, 1)
		tri(cx - 0.3 * r, cy - 0.7 * r, cx + 0.3 * r, cy - 0.7 * r, cx, cy + 0.35 * r)
		fan(cx, cy - 0.7 * r, 0.3 * r, 0, 180, 10)
	elseif kind == "wings" then
		gl.Color(0.95, 0.98, 1, 1)
		for side = -1, 1, 2 do
			for f = 0, 3 do -- four feathers fanned out
				local a = math.rad(15 + f * 16)
				local len = (1.15 - f * 0.12) * r
				tri(cx + side * 0.12 * r, cy - 0.15 * r, cx + side * (0.12 * r + len * math.cos(a)), cy - 0.15 * r + len * math.sin(a),
					cx + side * (0.12 * r + len * math.cos(a + math.rad(14))), cy - 0.15 * r + len * math.sin(a + math.rad(14)))
			end
		end
		gl.Color(0.8, 0.9, 1, 1)
		fan(cx, cy - 0.2 * r, 0.2 * r, 0, 360, 16)
		gl.Color(1, 0.95, 0.5, 1)
		gl.LineWidth(3)
		gl.BeginEnd(GL.LINE_LOOP, function()
			for i = 0, 23 do
				local a = math.rad(i * 15)
				gl.Vertex(cx + 0.36 * r * math.cos(a), cy + 0.95 * r + 0.12 * r * math.sin(a))
			end
		end)
		gl.LineWidth(1)
	else
		-- the radiation trefoil: three blades of 60 degrees, a black ring and a yellow centre
		gl.Color(1, 0.9, 0.1, 1)
		for k = 0, 2 do
			local c = 90 + k * 120
			fan(cx, cy, r, c - 30, c + 30, 10)
		end
		gl.Color(0.07, 0.07, 0.02, 1)
		fan(cx, cy, 0.3 * r, 0, 360, 20)
		gl.Color(1, 0.9, 0.1, 1)
		fan(cx, cy, 0.17 * r, 0, 360, 16)
	end
end

function widget:DrawScreen()
	if not open() then
		return
	end
	local x1, y1, x2, y2, buttons, s = layout()
	local mx, my = Spring.GetMouseState()
	gl.Color(0.03, 0.03, 0.05, 0.9)
	gl.Rect(x1, y1, x2, y2)
	gl.Color(1, 0.4, 0.2, 1)
	gl.Text("Level 10! Choose your gift", (x1 + x2) / 2, y2 - 36 * s, 34 * s, "co")
	for i, b in ipairs(buttons) do
		local g = GIFTS[i]
		local over = mx >= b.x1 and mx <= b.x2 and my >= b.y1 and my <= b.y2
		panel(b.x1, b.y1, b.x2, b.y2, g[4], g[5], g[6], over and 5 or 2, over and 1.25 or 1)
		symbol(g[7], (b.x1 + b.x2) / 2, b.y2 - 80 * s, 46 * s)
		gl.Color(g[6][1], g[6][2], g[6][3], 1)
		gl.Text(g[1], (b.x1 + b.x2) / 2, b.y2 - 160 * s, 28 * s, "co")
		gl.Color(1, 1, 1, 1)
		gl.Text(g[2], (b.x1 + b.x2) / 2, b.y2 - 204 * s, 17 * s, "co")
		gl.Text(g[3], (b.x1 + b.x2) / 2, b.y2 - 228 * s, 17 * s, "co")
	end
	gl.Color(0.8, 0.8, 0.8, 1)
	gl.Text("Click a gift or press 1, 2 or 3 (a random one in 30 seconds)", (x1 + x2) / 2, y1 + 10 * s, 18 * s, "co")
	gl.Color(1, 1, 1, 1)
end

function widget:IsAbove(x, y)
	if not open() then
		return false
	end
	local x1, y1, x2, y2 = layout()
	return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

function widget:MousePress(x, y, button)
	if not open() then
		return false
	end
	local x1, y1, x2, y2, buttons = layout()
	if x < x1 or x > x2 or y < y1 or y > y2 then
		return false
	end
	for i, b in ipairs(buttons) do
		if button == 1 and x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2 then
			choose(i)
		end
	end
	return true
end

function widget:KeyPress(key)
	if open() and key >= 49 and key <= 51 then -- the keys 1, 2, 3
		choose(key - 48)
		return true
	end
	return false
end
