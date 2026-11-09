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

local GIFTS = {
	{ "Hell on Earth", "Strong ground units rise", "all over the map. Yours." },
	{ "Heaven on Earth", "Dragons come down", "around your unit. Yours." },
	{ "Gates of Hell", "Nuclear missiles without end,", "ever closer to the enemies." },
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
	local w, h = 1080 * s, 330 * s
	local x1, y1 = (vsx - w) / 2, vsy * 0.3
	local buttons = {}
	local bw, gap = (w - 80 * s) / 3, 20 * s
	for i = 1, 3 do
		local bx = x1 + 20 * s + (i - 1) * (bw + gap)
		buttons[i] = { x1 = bx, y1 = y1 + 30 * s, x2 = bx + bw, y2 = y1 + 210 * s }
	end
	return x1, y1, x1 + w, y1 + h, buttons, s
end

local function choose(i)
	Spring.SendLuaRulesMsg("evo|gift|" .. i)
	sent = Spring.GetGameFrame()
end

function widget:DrawScreen()
	if not open() then
		return
	end
	local x1, y1, x2, y2, buttons, s = layout()
	local mx, my = Spring.GetMouseState()
	gl.Color(0.05, 0.02, 0.02, 0.88)
	gl.Rect(x1, y1, x2, y2)
	gl.Color(1, 0.3, 0.15, 1)
	gl.Text("Level 10! Choose your gift", (x1 + x2) / 2, y2 - 50 * s, 34 * s, "co")
	for i, b in ipairs(buttons) do
		local over = mx >= b.x1 and mx <= b.x2 and my >= b.y1 and my <= b.y2
		gl.Color(over and 0.55 or 0.35, 0.08, 0.05, 0.95)
		gl.Rect(b.x1, b.y1, b.x2, b.y2)
		gl.Color(1, 0.85, 0.5, 1)
		gl.Text(i .. "   " .. GIFTS[i][1], (b.x1 + b.x2) / 2, b.y2 - 50 * s, 28 * s, "co")
		gl.Color(1, 1, 1, 1)
		gl.Text(GIFTS[i][2], (b.x1 + b.x2) / 2, b.y2 - 100 * s, 18 * s, "co")
		gl.Text(GIFTS[i][3], (b.x1 + b.x2) / 2, b.y2 - 126 * s, 18 * s, "co")
	end
	gl.Color(0.8, 0.8, 0.8, 1)
	gl.Text("Click a gift or press 1, 2 or 3 (a random one in 30 seconds)", (x1 + x2) / 2, y1 + 8 * s, 18 * s, "co")
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
