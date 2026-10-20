function widget:GetInfo()
	return {
		name = "Scenario briefing",
		desc = "Shows the title, summary and briefing of a scenario built with the scenario maker",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 100000,
		enabled = true,
	}
end

-- The mission display of the game only finds scenarios that lie in the game archive. This widget therefore reads the title,
-- summary and briefing directly from the game option scenariooptions. It shows the window at the
-- start; click, Esc or Enter close it, /briefing opens it again. With a grace period it also chooses the start position.

local decode = require("common/luaUtilities/modoption_payload").Decode

local info
local show = true
local font
local lines = {}
local px, py, pw, ph = 0, 0, 0, 0
local fontSize = 16

local function wrap(text, maxW, out, kind)
	for para in (tostring(text or "") .. "\n"):gmatch("(.-)\r?\n") do
		if para == "" then
			out[#out + 1] = { "", kind }
		else
			local cur = ""
			for word in para:gmatch("%S+") do
				local try = (cur == "") and word or (cur .. " " .. word)
				if cur ~= "" and font:GetTextWidth(try) * fontSize > maxW then
					out[#out + 1] = { cur, kind }
					cur = word
				else
					cur = try
				end
			end
			out[#out + 1] = { cur, kind }
		end
	end
end

local function layout()
	local vsx, vsy = Spring.GetViewGeometry()
	fontSize = math.max(14, math.floor(vsy / 66))
	pw = math.min(vsx * 0.6, fontSize * 48)
	lines = {}
	wrap(info.title or "Scenario", pw - 2 * fontSize, lines, "title")
	if info.author and info.author ~= "" then
		wrap("by " .. info.author, pw - 2 * fontSize, lines, "dim")
	end
	lines[#lines + 1] = { "", "body" }
	if info.summary and info.summary ~= "" then
		wrap(info.summary, pw - 2 * fontSize, lines, "body")
		lines[#lines + 1] = { "", "body" }
	end
	if info.briefing and info.briefing ~= "" and info.briefing ~= info.summary then
		wrap(info.briefing, pw - 2 * fontSize, lines, "body")
	end
	local grace = tonumber(info.grace) or 0
	if grace > 0 then
		local total = math.floor(grace * 60 + 0.5)
		lines[#lines + 1] = { "", "body" }
		wrap(string.format("Grace period: %d:%02d minutes. Until then every side stays in its start area and is safe from damage there.",
			math.floor(total / 60), total % 60), pw - 2 * fontSize, lines, "body")
	end
	if type(info.tiers) == "table" then
		local parts = {}
		for team, allowed in pairs(info.tiers) do
			local t = {}
			for k in tostring(allowed):gmatch("[123]") do
				t[#t + 1] = "T" .. k
			end
			parts[#parts + 1] = { tonumber(team) or 0, "Team " .. team .. ": " .. (#t > 0 and ("only " .. table.concat(t, "+")) or "nothing") }
		end
		table.sort(parts, function(a, b) return a[1] < b[1] end)
		local txt = {}
		for _, p in ipairs(parts) do
			txt[#txt + 1] = p[2]
		end
		lines[#lines + 1] = { "", "body" }
		wrap("Tech restriction: " .. table.concat(txt, "; ") .. " (the other teams have no restriction).", pw - 2 * fontSize, lines, "body")
	end
	lines[#lines + 1] = { "", "body" }
	lines[#lines + 1] = { "Click, Esc or Enter closes. /briefing shows it again.", "dim" }
	local lh = fontSize * 1.3
	ph = math.min(vsy * 0.85, #lines * lh + 2 * fontSize)
	px = (vsx - pw) / 2
	py = (vsy + ph) / 2 -- upper edge
end

function widget:Initialize()
	local opts = decode(Spring.GetModOptions().scenariooptions)
	if type(opts) ~= "table" or not opts.scenariomaker then
		widgetHandler:RemoveWidget(widget)
		return
	end
	info = opts
	font = { GetTextWidth = function(_, s) return gl.GetTextWidth(s) end }
	widgetHandler:AddAction("briefing", function() show = not show return true end, nil, "t")
	layout()
end

-- The Mission button at the top and the mission display of the game should open this window instead of the empty
-- display of the game. That is why WG.missioninfo is replaced (and again if needed, in case it is set anew later).
local mine
local function takeOver()
	local orig = WG.missioninfo
	if orig == mine then
		return
	end
	if orig and orig.toggle then
		orig.toggle(false)
	end
	mine = {
		toggle = function(state)
			if state ~= nil then
				show = state and true or false
			else
				show = not show
			end
		end,
		isvisible = function()
			return show
		end,
	}
	WG.missioninfo = mine
end

-- Grace period: the game then demands the choice of the start position (start mode "choose in the game"). The scenario already has
-- its units, so this widget does the choice itself: start position in the middle of the own
-- start area, then "ready". The choice takes only a second this way.
local autoStartAt
local autoStartDone = false
local function autoStart()
	if autoStartDone or Spring.GetGameFrame() > 0 then
		return
	end
	autoStartAt = autoStartAt or (os.clock() + 1.5)
	if os.clock() < autoStartAt then
		return
	end
	autoStartDone = true
	local myTeam = Spring.GetMyTeamID()
	local allyTeam = select(6, Spring.GetTeamInfo(myTeam, false))
	local x0, z0, x1, z1 = Spring.GetAllyTeamStartBox(allyTeam)
	if x0 and x1 then
		local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
		Spring.RequestStartPosition(cx, Spring.GetGroundHeight(cx, cz), cz, false)
	end
	Spring.SendLuaRulesMsg("ready_to_start_game")
end

-- Tech restriction per team (info.tiers[team] = allowed tiers, e.g. "12"). The game only knows a global
-- lock; per team it works through the chat command "luarules buildblock", which needs cheats. The widget turns
-- cheats on only for a few frames at the start of the game, sets the locks and turns them off again.
-- Tier 1.5 (seaplane, hover and amphibious factories) counts as T2.
local tierPhase = 0
local weEnabledCheats = false

-- BAR files some Epic units under a lower tech level (Epic Grunt: T1, Epic Skater: T2): every Epic unit counts as T3
local function techLevel(ud)
	local t = tonumber(ud.customParams and ud.customParams.techlevel) or 1
	if t < 3 then
		local human = ud.translatedHumanName or ud.humanName or ""
		local mv = ud.moveDef and ud.moveDef.name or ""
		if human:find("^Epic") or tostring(mv):find("epic", 1, true) then
			return 3
		end
	end
	return t
end

local function tierOf(def)
	local t = techLevel(def)
	if t >= 3 then
		return "3"
	elseif t > 1 then
		return "2"
	end
	return "1"
end

local function applyTierBlocks()
	for teamStr, allowed in pairs(info.tiers) do
		local names = {}
		for _, def in pairs(UnitDefs) do
			if not tostring(allowed):find(tierOf(def), 1, true) then
				names[#names + 1] = def.name
			end
		end
		table.sort(names)
		local i = 1
		while i <= #names do
			local j = math.min(i + 39, #names)
			Spring.SendCommands("luarules buildblock " .. teamStr .. " scenario_tech " .. table.concat(names, " ", i, j))
			i = j + 1
		end
	end
end

function widget:GameFrame(f)
	if not info or type(info.tiers) ~= "table" or tierPhase >= 3 then
		return
	end
	if tierPhase == 0 and f >= 2 then
		tierPhase = 1
		if not Spring.IsCheatingEnabled() then
			weEnabledCheats = true
			Spring.SendCommands("cheat 1")
		end
	elseif tierPhase == 1 and f >= 8 then
		tierPhase = 2
		applyTierBlocks()
	elseif tierPhase == 2 and f >= 16 then
		tierPhase = 3
		if weEnabledCheats then
			Spring.SendCommands("cheat 0")
		end
	end
end

function widget:Update()
	if info then
		takeOver()
		if info.grace and tonumber(info.grace) and tonumber(info.grace) > 0 and Game.startPosType == 2 then
			autoStart()
		end
	end
end

-- Resurrected units of the player (the builder is executing the RESURRECT command) should hold position
-- (Hold Position), otherwise they run off after standing up. This only applies to own units, which a widget may control.
function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if builderID and unitTeam == Spring.GetMyTeamID() and Spring.GetUnitCurrentCommand(builderID) == CMD.RESURRECT then
		Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
	end
end

function widget:Shutdown()
	if WG.missioninfo == mine then
		WG.missioninfo = nil
	end
end

function widget:ViewResize()
	if info then
		layout()
	end
end

-- Small display of the grace period at the top center: remaining time, then briefly "over".
local function drawGrace()
	local grace = tonumber(info.grace) or 0
	if grace <= 0 then
		return
	end
	local left = grace * 60 - Spring.GetGameSeconds()
	if left < -6 then
		return
	end
	local vsx, vsy = Spring.GetViewGeometry()
	local fs = math.max(14, math.floor(vsy / 60))
	local text, r, g, b
	if left > 0 then
		local s = math.ceil(left)
		text = string.format("Grace period  %d:%02d", math.floor(s / 60), s % 60)
		r, g, b = 1, 0.85, 0.4
	else
		text = "Grace period over"
		r, g, b = 1, 0.35, 0.3
	end
	local w = gl.GetTextWidth(text) * fs + fs * 2
	local x, y = vsx / 2, vsy - fs * 5
	gl.Color(0, 0, 0, 0.6)
	gl.Rect(x - w / 2, y - fs * 0.5, x + w / 2, y + fs * 1.5)
	gl.Color(r, g, b, 1)
	gl.Text(text, x, y, fs, "oc")
	gl.Color(1, 1, 1, 1)
end

function widget:DrawScreen()
	if info then
		drawGrace()
	end
	if not show or not info then
		return
	end
	gl.Color(0, 0, 0, 0.82)
	gl.Rect(px, py - ph, px + pw, py)
	gl.Color(1, 1, 1, 0.25)
	gl.Rect(px, py - ph, px + pw, py - ph + 2)
	gl.Rect(px, py - 2, px + pw, py)
	local lh = fontSize * 1.3
	local y = py - fontSize - lh * 0.8
	local x = px + fontSize
	for _, l in ipairs(lines) do
		if y < py - ph + fontSize * 0.5 then
			break
		end
		local text, kind = l[1], l[2]
		if kind == "title" then
			gl.Color(1, 0.85, 0.4, 1)
			gl.Text(text, x, y, fontSize * 1.3, "o")
		elseif kind == "dim" then
			gl.Color(0.7, 0.7, 0.7, 1)
			gl.Text(text, x, y, fontSize * 0.9, "o")
		else
			gl.Color(1, 1, 1, 1)
			gl.Text(text, x, y, fontSize, "o")
		end
		y = y - lh
	end
	gl.Color(1, 1, 1, 1)
end

local function inside(x, y)
	return x >= px and x <= px + pw and y >= py - ph and y <= py
end

function widget:IsAbove(x, y)
	return show and inside(x, y)
end

function widget:MousePress(x, y, button)
	if show and info then
		show = false
		return inside(x, y)
	end
	return false
end

function widget:KeyPress(key)
	if show and info and (key == 27 or key == 13 or key == 271) then
		show = false
		return true
	end
	return false
end
