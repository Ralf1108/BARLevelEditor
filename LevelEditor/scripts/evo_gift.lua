-- Evolution (LAN Play): the windows in which a player chooses. A game widget of the extra game "Level Editor Scenarios" (no "Allow user widgets" needed); active only in an
-- Evolution game (game option lanevolution=1).
--   unit of the next level   team rules evoChoice = "name1,name2,name3" (evoChoiceAt = the frame): three cards (picture, name, faction, health, damage per second, range, speed);
--                            a click or the key 1, 2, 3 sends "evo|pick|<n>"; without a choice the gadget takes a random one after 10 s. It comes before the gift.
--   gift of level 10         team rules evoGift = 1 while the own team may choose; a click on a gift (or the key 1, 2, 3) sends "evo|gift|<n>"; a random gift after 30 s.
-- WG.evoWindowOpen is true while one of them is open (the Renegade widget leaves the keys 1 to 3 to it then).
function widget:GetInfo()
	return {
		name = "Evolution: choices",
		desc = "Choose the unit of the next level and the gift of level 10 in an Evolution game of LAN Play",
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
local pickSent = nil -- the frame of the unit choice (evoChoiceAt) that was answered

-- the units of the choice of the next level (nil when none is open) and the frame it began
local function choiceOpen()
	if Spring.GetSpectatingState() then return nil end
	local team = Spring.GetMyTeamID()
	local raw = tostring(Spring.GetTeamRulesParam(team, "evoChoice") or "")
	if raw == "" then pickSent = nil return nil end
	local at = Spring.GetTeamRulesParam(team, "evoChoiceAt") or 0
	if pickSent == at then return nil end
	local names = {}
	for n in raw:gmatch("[^,]+") do names[#names + 1] = n end
	return names, at
end

-- the values of a card: faction (by the prefix of the name), health, damage per second of all weapons (default damage x salvo x projectiles / reload), longest range, speed
local FACTIONS = { arm = { "Armada", { 0.35, 0.6, 1 } }, cor = { "Cortex", { 1, 0.4, 0.3 } }, leg = { "Legion", { 0.45, 0.95, 0.45 } } }
local function cardValues(ud)
	local dps, range = 0, 0
	for _, w in ipairs(ud.weapons or {}) do
		local wd = WeaponDefs[w.weaponDef]
		if wd and (tonumber(wd.range) or 0) > 0 then
			local dmg = wd.damages and (wd.damages[0] or wd.damages.default) or 0
			local reload = math.max(0.03, tonumber(wd.reload) or 1)
			dps = dps + dmg * (tonumber(wd.salvoSize) or 1) * (tonumber(wd.projectiles) or 1) / reload
			range = math.max(range, tonumber(wd.range) or 0)
		end
	end
	local f = FACTIONS[ud.name:sub(1, 3)] or { "", { 0.8, 0.8, 0.8 } }
	return f[1], f[2], math.floor(ud.health or 0), math.floor(dps + 0.5), math.floor(range), math.floor(ud.speed or 0)
end

function widget:Initialize()
	local mo = Spring.GetModOptions() or {}
	if mo.lanevolution ~= "1" then
		widgetHandler:RemoveWidget(self)
	end
end

local function open()
	if Spring.GetSpectatingState() or choiceOpen() then
		return false -- (the choice of the unit comes first)
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

-- the three cards of the units of the next level (the same layout as the gifts)
local function drawChoice(names, at)
	local x1, y1, x2, y2, buttons, s = layout()
	local mx, my = Spring.GetMouseState()
	local level = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoStage") or 0
	gl.Color(0.03, 0.03, 0.05, 0.9)
	gl.Rect(x1, y1, x2, y2)
	gl.Color(0.45, 0.85, 1, 1)
	gl.Text(string.format("Level %d! Choose your unit", level), (x1 + x2) / 2, y2 - 36 * s, 34 * s, "co")
	for i, b in ipairs(buttons) do
		local ud = names[i] and UnitDefNames[names[i]]
		if ud then
			local fname, fc, hp, dps, range, speed = cardValues(ud)
			local over = mx >= b.x1 and mx <= b.x2 and my >= b.y1 and my <= b.y2
			panel(b.x1, b.y1, b.x2, b.y2, { fc[1] * 0.12, fc[2] * 0.12, fc[3] * 0.12 }, { fc[1] * 0.4, fc[2] * 0.4, fc[3] * 0.4 }, fc, over and 5 or 2, over and 1.25 or 1)
			local cx, pic = (b.x1 + b.x2) / 2, 92 * s
			gl.Color(1, 1, 1, 1)
			gl.Texture("#" .. ud.id)
			gl.TexRect(cx - pic / 2, b.y2 - 16 * s - pic, cx + pic / 2, b.y2 - 16 * s)
			gl.Texture(false)
			gl.Color(1, 1, 1, 1)
			gl.Text(i .. "  " .. (ud.translatedHumanName or ud.name), cx, b.y2 - 140 * s, 24 * s, "co")
			gl.Color(fc[1], fc[2], fc[3], 1)
			gl.Text(fname, cx, b.y2 - 166 * s, 17 * s, "co")
			gl.Color(0.9, 0.9, 0.9, 1)
			gl.Text(string.format("Health %d    DPS %d", hp, dps), cx, b.y2 - 200 * s, 17 * s, "co")
			gl.Text(string.format("Range %d    Speed %d", range, speed), cx, b.y2 - 224 * s, 17 * s, "co")
		end
	end
	local left = math.max(0, math.ceil((at + 10 * 30 - Spring.GetGameFrame()) / 30))
	gl.Color(0.8, 0.8, 0.8, 1)
	gl.Text(string.format("Click a unit or press 1, 2 or 3 (a random one in %d seconds)", left), (x1 + x2) / 2, y1 + 10 * s, 18 * s, "co")
	gl.Color(1, 1, 1, 1)
end

local function pick(i, at)
	Spring.SendLuaRulesMsg("evo|pick|" .. i)
	pickSent = at
end

function widget:Update()
	WG.evoWindowOpen = (choiceOpen() ~= nil) or open()
end

function widget:Shutdown()
	WG.evoWindowOpen = nil
end

function widget:DrawScreen()
	local names, at = choiceOpen()
	if names then
		drawChoice(names, at)
		return
	end
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
	if not open() and not choiceOpen() then
		return false
	end
	local x1, y1, x2, y2 = layout()
	return x >= x1 and x <= x2 and y >= y1 and y <= y2
end

function widget:MousePress(x, y, button)
	local names, at = choiceOpen()
	if not names and not open() then
		return false
	end
	local x1, y1, x2, y2, buttons = layout()
	if x < x1 or x > x2 or y < y1 or y > y2 then
		return false
	end
	for i, b in ipairs(buttons) do
		if button == 1 and x >= b.x1 and x <= b.x2 and y >= b.y1 and y <= b.y2 then
			if names then pick(i, at) else choose(i) end
		end
	end
	return true
end

function widget:KeyPress(key)
	if key < 49 or key > 51 then return false end -- the keys 1, 2, 3
	local names, at = choiceOpen()
	if names then
		pick(key - 48, at)
		return true
	end
	if open() then
		choose(key - 48)
		return true
	end
	return false
end
