-- Evolution (synchronized part), a game mode of LAN Play on any map: the button Evolution of the room (menu LAN Play) sets the game option lanevolution=1. Every
-- team that starts with a commander gets one weak unit instead (stage 1) and nothing else. Kills give points; with enough points the unit is replaced by a
-- unit of the next stage (10 stages, the last one a big tier 3 unit), of a random faction each time. A destroyed unit comes back after 5 s at a random
-- place, one stage lower. Every unit spawns on the land the commanders stand on (one connected piece of land: everybody can reach everybody). Wild units
-- (stage 1 units of Gaia with little health) stand around the map; they only shoot back. Computer players (teams without a human) are steered by this
-- gadget: their unit attacks only enemies of its own stage or higher and otherwise only shoots back; the orders of the AI itself are dropped.
-- Armageddon: the first unit on stage 10 ends the fog of war for everybody, and from then on a lost unit does not come back; the last alliance standing
-- wins. Every player who reaches stage 10 chooses a gift (window of the game widget evo_gift.lua, message "evo|gift|<n>"; a computer player chooses at
-- once, a human after 30 s at the latest): 1 Hell on Earth (strong ground units rise all over the map, they belong to the player), 2 Heaven on Earth
-- (Dragons come down around the player's unit), 3 Gates of Hell (nuclear missiles that never stop and come ever closer to the enemies).
-- Points: from stage s to s + 1 it takes need(s) = round(3 * 1.6^(s - 1)) points (3, 5, 8, 12, 20, 31, 50, 81, 129). A wild unit gives 1 point; a
-- player unit of stage v gives need(v), times (1 + v - k) when it is above the stage k of the killer.
-- Test only: the game option lanevolutionstage=<n> lets every player start on stage n.
-- State for the display: game rules parameters evoState ("" / "running" / "won by alliance N"), evoTeams (the player teams), evoArmageddon (frame of its
-- start, 0 = not yet), evoHero (who brought it), evoNukes ("x,z/..." the targets of the missiles of the next seconds); team rules parameters evoStage, evoXp,
-- evoNeed (points to the next stage, 0 on the last), evoKills, evoDeaths, evoOut (1 = out), evoUnit (the unit, 0 = none), evoSpawn (counts the spawns: the
-- unsynced part points the camera at a new unit), evoName (unit definition name; shown with its name from NAMES), evoGift (1 = the player chooses a gift now).
function gadget:GetInfo()
	return {
		name = "Evolution",
		desc = "LAN Play game mode: one unit per team that evolves with every kill",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local opt = (Spring.GetModOptions() or {}).lanevolution
if opt ~= "1" and opt ~= 1 then
	return false -- not an Evolution game: the gadget is not loaded
end

-- The names of the units of the ladders (the translated names are not known in every Lua state of the game)
local NAMES = {
	armpw = "Pawn", armflash = "Blitz", armwar = "Centurion", armzeus = "Welder", armbull = "Bull", armmar = "Marauder", armmeatball = "Meatball",
	armraz = "Razorback", armthor = "Thor", armbanth = "Titan",
	corak = "Grunt", corgator = "Incisor", corraid = "Brute", corpyro = "Fiend", correap = "Tiger", corcan = "Sumo", corshiva = "Shiva",
	corkarg = "Karganeth", cordemon = "Demon", corkorg = "Juggernaut",
	leghades = "Alaris", legcen = "Phobos", legkark = "Karkinos", leggat = "Decurion", legjav = "Javelin", legaheattank = "Prometheus", leginc = "Incinerator",
	legkeres = "Keres", legeshotgunmech = "Praetorian", legeheatraymech = "Sol Invictus",
}

-- (used by both parts: the ladders and the help window)
-- The ladders: stage 1 to 10 per faction, ordered by damage per second times health (the strength in a fight of one against one); the last stage is
-- the biggest walking unit of the faction. Artillery, units for water and the bomb bots are left out. Every spawn takes a random faction of those
-- whose unit exists in the game (Legion only with its game option).
local LADDERS = {
	{ "armpw", "armflash", "armwar", "armzeus", "armbull", "armmar", "armmeatball", "armraz", "armthor", "armbanth" },
	{ "corak", "corgator", "corraid", "corpyro", "correap", "corcan", "corshiva", "corkarg", "cordemon", "corkorg" },
	{ "leghades", "legcen", "legkark", "leggat", "legjav", "legaheattank", "leginc", "legkeres", "legeshotgunmech", "legeheatraymech" },
}
local GUNSHIPS = { "corcrw" } -- Heaven on Earth: the Dragon (without it in the game: Hell on Earth)
local GIFT_NAMES = { "Hell on Earth", "Heaven on Earth", "Gates of Hell" }

-- The abilities: a beacon of the color of an ability lies on the map; a player's unit that drives over it gets the ability until it dies (a button in the
-- order menu: energy cost, time it lasts, cooldown in seconds). Used by both parts (the beacons and the display).
local ABILITIES = {
	{ key = "sprint", name = "Sprint", color = { 0.3, 0.65, 1 }, cost = 200, time = 8, cool = 30, tip = "Your unit is 50 % faster for 8 s" },
	{ key = "repair", name = "Repair", color = { 0.3, 1, 0.35 }, cost = 500, time = 0, cool = 60, tip = "Heals 20 % of the health of your unit at once" },
	{ key = "pulse", name = "Radar Pulse", color = { 1, 0.55, 0.1 }, cost = 250, time = 5, cool = 45, tip = "Your unit sees everything within 2500 Elmo for 5 s" },
	{ key = "cloak", name = "Cloak", color = { 1, 0.9, 0.2 }, cost = 400, time = 15, cool = 60, tip = "Your unit is invisible to the enemy for 15 s (until it fires)" },
	{ key = "jammer", name = "Jammer", color = { 0.75, 0.35, 1 }, cost = 300, time = 20, cool = 60, tip = "Hides your unit from the enemy radar for 20 s" },
}

-- The name of a team: the AI's name or the name of its leader (used by both parts)
local function teamName(team)
	local _, leader, _, isAI = Spring.GetTeamInfo(team, false)
	if isAI then
		local _, name = Spring.GetAIInfo(team)
		return (name and name ~= "") and name or ("AI " .. team)
	end
	local name = leader and Spring.GetPlayerInfo(leader, false)
	return (name and name ~= "") and name or ("Team " .. team)
end

if not gadgetHandler:IsSyncedCode() then
	-- ---------------------------------------------------------------- unsynced: the score lines, Armageddon, the missile targets, the selection and the camera
	local lastUnit, lastSpawn = nil, nil

	function gadget:Update()
		if (Spring.GetGameRulesParam("evoState") or "") == "" or Spring.GetSpectatingState() then
			return
		end
		local team = Spring.GetMyTeamID()
		local id = Spring.GetTeamRulesParam(team, "evoUnit")
		if id and id > 0 and id ~= lastUnit then
			lastUnit = id
			Spring.SelectUnitArray({ id }) -- the new unit (evolved or back) is selected: no new click needed
		end
		local spawn = Spring.GetTeamRulesParam(team, "evoSpawn")
		if spawn and spawn ~= lastSpawn then
			lastSpawn = spawn
			local x, y, z = Spring.GetUnitPosition(id or -1)
			if x then
				Spring.SetCameraTarget(x, y, z, 0.5) -- the unit is at a new place of the map
			end
		end
	end

	-- ---------------------------------------------------------------- the panel at the top (drawn with plain shapes: rounded boxes, badges, bars, symbols)
	local H = {}

	-- the outline of a box with round corners (a list of points, counterclockwise)
	function H.outline(x1, y1, x2, y2, r)
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
	function H.box(x1, y1, x2, y2, r, bottom, top, line, width)
		local pts = H.outline(x1, y1, x2, y2, r)
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

	function H.disc(x, y, r, c)
		gl.Color(c[1], c[2], c[3], c[4] or 1)
		gl.BeginEnd(GL.TRIANGLE_FAN, function()
			gl.Vertex(x, y)
			for k = 0, 24 do
				local a = k / 24 * 2 * math.pi
				gl.Vertex(x + r * math.cos(a), y + r * math.sin(a))
			end
		end)
	end

	function H.ring(x, y, r, c)
		gl.Color(c[1], c[2], c[3], c[4] or 1)
		gl.BeginEnd(GL.LINE_LOOP, function()
			for k = 0, 23 do
				local a = k / 24 * 2 * math.pi
				gl.Vertex(x + r * math.cos(a), y + r * math.sin(a))
			end
		end)
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

	-- the symbol of an ability, white lines in a square of radius r around x, y: sprint a double arrow, repair a plus, cloak a crossed out eye, the pulse a dot
	-- with radar waves, the jammer a zigzag wave
	function H.icon(key, x, y, r, alpha)
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
			H.box(x - w, y - 0.8 * r, x + w, y + 0.8 * r, w * 0.4, { 1, 1, 1, alpha }, { 1, 1, 1, alpha })
			H.box(x - 0.8 * r, y - w, x + 0.8 * r, y + w, w * 0.4, { 1, 1, 1, alpha }, { 1, 1, 1, alpha })
		elseif key == "cloak" then
			gl.BeginEnd(GL.LINE_LOOP, function()
				for k = 0, 15 do
					local a = k / 16 * 2 * math.pi
					gl.Vertex(x + 0.9 * r * math.cos(a), y + 0.45 * r * math.sin(a))
				end
			end)
			H.disc(x, y, 0.22 * r, { 1, 1, 1, alpha })
			gl.BeginEnd(GL.LINES, function()
				gl.Vertex(x - 0.8 * r, y - 0.8 * r)
				gl.Vertex(x + 0.8 * r, y + 0.8 * r)
			end)
		elseif key == "pulse" then
			H.disc(x - 0.55 * r, y - 0.55 * r, 0.2 * r, { 1, 1, 1, alpha })
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

	-- the abilities of a team as small squares in their colors, each in its own column (the order of ABILITIES; an empty frame where the team does not have
	-- it): its symbol, dimmed with the seconds while it cools down, a bright border while it works
	function H.abilities(team, x, y, size)
		local have = {}
		local list = Spring.GetTeamRulesParam(team, "evoAbilities")
		if type(list) == "string" then
			for i, cool, act in list:gmatch("(%d+):(%d+):(%d+)") do
				have[tonumber(i)] = { cool = tonumber(cool), act = tonumber(act) }
			end
		end
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

	-- The buttons of the own abilities in the rectangle x1, y1 - x2, y2: five in the order of ABILITIES, each with its color and symbol; grey and pale while the
	-- team does not have it, dimmed with the seconds while it cools down, a bright border while it works; a click uses it (game message "evo|use|<n>"), the
	-- mouse over a button shows what it does (above it). H.slots: the rectangles of the buttons for the mouse.
	H.slots = {}
	function H.bar(x1, y1, x2, y2, s)
		local mine = Spring.GetMyTeamID()
		local have = {}
		local list = Spring.GetTeamRulesParam(mine, "evoAbilities")
		if type(list) == "string" then
			for i, cool, act in list:gmatch("(%d+):(%d+):(%d+)") do
				have[tonumber(i)] = { cool = tonumber(cool), act = tonumber(act) }
			end
		end
		local energy = Spring.GetTeamResources(mine, "energy") or 0
		local gap = 6 * s
		local fw = math.max(2, 4 * s) -- the thickness of the frames
		local hp, maxHp = 0, 0
		local unit = Spring.GetTeamRulesParam(mine, "evoUnit")
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
				H.box(bx1, by1, bx2, by2, 7 * s, { 0.07, 0.07, 0.09, 0.9 }, { 0.12, 0.12, 0.15, 0.9 }, { c[1] * 0.7, c[2] * 0.7, c[3] * 0.7, 0.8 }, fw)
				H.icon(a.key, cx, iy, 14 * s, 0.25)
				gl.Color(0.5, 0.5, 0.55, 1)
			else
				local cooling = h.cool > 0 and h.act == 0
				local k = cooling and 0.3 or 1
				local pulse = 0.6 + 0.4 * math.sin(Spring.GetGameFrame() * 0.25)
				H.box(bx1, by1, bx2, by2, 7 * s, { c[1] * 0.35 * k, c[2] * 0.35 * k, c[3] * 0.35 * k, 0.95 }, { c[1] * 0.85 * k, c[2] * 0.85 * k, c[3] * 0.85 * k, 0.95 },
					h.act > 0 and { 1, 1, 1, pulse } or { c[1], c[2], c[3], cooling and 0.55 or 1 }, fw)
				H.icon(a.key, cx, iy, 14 * s, cooling and 0.45 or 1)
				if cooling then
					-- the cooldown as a grey fill that runs down like a status bar (full at the start, empty when ready)
					local top2 = by1 + (by2 - by1) * math.min(1, h.cool / a.cool)
					H.box(bx1 + 2, by1 + 2, bx2 - 2, math.max(by1 + 6 * s, top2), 6 * s, { 0.25, 0.25, 0.28, 0.8 }, { 0.38, 0.38, 0.42, 0.8 })
					H.icon(a.key, cx, iy, 14 * s, 0.35)
				end
				if h.act > 0 then
					-- the time the effect still lasts: a bright fill in the color of the ability runs down like the cooldown (full at the start)
					local top3 = by1 + (by2 - by1) * math.min(1, h.act / a.time)
					H.box(bx1 + 2, by1 + 2, bx2 - 2, math.max(by1 + 6 * s, top3), 6 * s, { c[1], c[2], c[3], 0.45 }, { c[1], c[2], c[3], 0.7 })
					H.icon(a.key, cx, iy, 14 * s, 1)
				end
				gl.Color(1, 1, 1, cooling and 0.6 or 1)
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
			H.slots[i] = { bx1, by1, bx2, by2 }
			if mx >= bx1 and mx <= bx2 and my >= by1 and my <= by2 then
				hover, hoverX = i, cx
			end
		end
		if hover then
			-- the explanation above the button
			local a, h = ABILITIES[hover], have[hover]
			local lines = { a.tip, "Cost " .. a.cost .. " energy, cooldown " .. a.cool .. " s",
				not h and ("Not yet yours: drive over a beacon of this color") or (h.act > 0 and ("Working: " .. h.act .. " s left")) or (h.cool > 0 and ("Ready again in " .. h.cool .. " s"))
					or (a.key == "repair" and healthy and "Not needed now: full health") or (energy < a.cost and "Not enough energy") or "Click to use" }
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
			H.box(tx1, ty1, tx2, ty2, 6 * s, { 0.02, 0.03, 0.05, 0.92 }, { 0.08, 0.09, 0.13, 0.92 }, { a.color[1], a.color[2], a.color[3], 0.8 })
			gl.Color(a.color[1], a.color[2], a.color[3], 1)
			gl.Text(a.name, tx1 + 10 * s, ty2 - 15 * s, 16 * s, "vo")
			gl.Color(0.9, 0.92, 0.97, 1)
			for k, l in ipairs(lines) do
				gl.Text(l, tx1 + 10 * s, ty2 - 22 * s - k * 17 * s + 4 * s, 13 * s, "vo")
			end
		end
		gl.Color(1, 1, 1, 1)
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
		gl.Text("UNITS: the levels, in the three factions", x1 + 24 * s, top + 30 * s, 16 * s, "vo")
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

	function gadget:DrawScreen()
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

	-- the beacons of the abilities: a column of light in the color of the ability and a pulsing ring on the ground, only where the own team sees
	-- (a spectator sees all)
	function gadget:DrawWorld()
		local text = Spring.GetGameRulesParam("evoBeacons")
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
	return
end

-- ---------------------------------------------------------------- synced
local FPS = 30
local STAGES = 10
local FIRST, FACTOR = 3, 1.6 -- points from stage 1 to 2, and how much more every further stage costs
local RESPAWN = 5 * FPS -- frames until a destroyed unit comes back
local WILD_BACK = 10 * FPS -- frames until a destroyed wild unit comes back
local REGEN, REGEN_STEP, REGEN_WAIT = 0.002, 30, 150 -- the unit of a player regenerates 0.2 % of its health per second (1 % in 5 s), 5 s after the last damage
local WILD_HP = math.max(0.1, math.min(1, (tonumber((Spring.GetModOptions() or {}).lanevohp) or 50) / 100)) -- the health of a wild unit at the start (part of the normal maximum: the bar shows it; game option lanevohp 10 - 100, default 50)
local REGEN_ON = (Spring.GetModOptions() or {}).lanevoregen ~= "0" -- game option lanevoregen=0: the units of the players do not regenerate
local START_AFTER, START_UNTIL = 30, 900 -- frames: the commanders are looked for from START_AFTER on (BAR creates them at the start), new ones until START_UNTIL
local CMD_FIRE_STATE, CMD_MOVE_STATE = CMD.FIRE_STATE, CMD.MOVE_STATE
local EXP_STEP = 0.1 -- the experience of the unit (the game's own: more health, damage, reload) for a kill of a player unit, minus it for a death
local RETURN_FIRE, HOLD_POSITION = 1, 0
local CELL = 128 -- size of a cell of the land grid in Elmo
local GIFT_WAIT = 30 * FPS -- a human who does not choose a gift gets a random one after this time
local HELL_UNITS, HEAVEN_UNITS, HELL_GAP, HEAVEN_GAP = 8, 8, 30 * FPS, 30 * FPS -- units of the gifts Hell on Earth and Heaven on Earth; one more of each every 30 s
local NUKE_WARN, NUKE_SAFE = 5 * FPS, 900 -- Gates of Hell: warning ring before a missile, distance to the units of the player who chose it
-- Further rules in one table (Lua 5.1 allows only so many locals):
--   energy: every player team gets ENERGY_BASE + ENERGY per level per second and a storage of STORE (the commanders are gone; laser weapons need energy);
--     more comes from the solar collectors and wind turbines (GENERATORS, one per GEN_AREA x GEN_AREA Elmo of the land, GEN_MIN to GEN_MAX), taken like the radars
--   wild units: the lowest stage of the players who are still in; TOWER = chance that a wild spawn is a tower; TOWER_DAMAGE = part of the damage of a wild
--     tower; every CHECK frames the number is topped up; every UPGRADE frames one wild unit two or more stages away from that stage is replaced by one of it
--   catching up: the points of a kill times 1 + CATCH_UP x (the highest stage of the players who are in - the stage of the killer)
--   radars: neutral, cannot be destroyed, placed until COVER of the land is in their range; a player's unit within RANGE for TAKE frames (no enemy player
--     unit as near) takes one; when more than half of the players are on stage T2_STAGE or higher they become T2 radars one by one
local R = {
	ENERGY_BASE = 5, ENERGY = 3, STORE = 1000,
	GENERATORS = { "armsolar", "corsolar", "legsolar", "armwin", "corwin", "legwin" }, GEN_AREA = 1536, GEN_MIN = 6, GEN_MAX = 30,
	TOWER = 0.15, TOWER_DAMAGE = 0.5, CHECK = 10 * FPS, UPGRADE = 3 * FPS, CATCH_UP = 0.5,
	WANDER = 5 * FPS, WANDER_SHARE = 0.6, WANDER_DIST = 700, STILL = 0.2, -- every WANDER frames a part of the idle walking wild units goes to a place nearby;
	-- STILL = part of the wild units that never walk (towers never do)
	COVER = 0.95, RANGE = 200, TAKE = 5 * FPS, T2_STAGE = 5, MAX_RADARS = 60,
	-- the towers of a stage per faction (ground targets; anti air, nuclear and anti nuclear buildings left out), ordered by cost
	TOWERS = {
		{ "armllt", "armbeamer", "armclaw", "armhlt", "armpb", "armguard", "armamb", "armanni", "armanni", "armannit3" },
		{ "corllt", "corhllt", "cormaw", "corhlt", "corvipe", "corpun", "cortoast", "cordoom", "corbhmth", "cordoomt3" },
		{ "leglht", "legdtr", "leghive", "legmg", "legapopupdef", "legcluster", "legperdition", "legbastion", "legbastion", "leggatet3" },
	},
	RADAR1 = { "armrad", "corrad", "legrad" },
	RADAR2 = { armrad = "armarad", corrad = "corarad", legrad = "legarad" },
}
local radars = {} -- unitID -> { team = owner team (Gaia at first), name, take = { team, frames } while a player takes it }

local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST) -- what the gadgets of the editor share (led_gadgets.lua)
local say = G.sayer("Evolution")

local players = {} -- list of player records { team, ally, stage, xp, kills, deaths, unit, unitName, spawns, respawnAt, ai, name, out, top, giftAt }
local byTeam = {} -- team -> player record
local owner = {} -- unitID -> player record (the unit of a player team)
local wild = {} -- unitID -> true: wild units
local summoned = {} -- unitID -> player record: the units of the gifts Hell on Earth and Heaven on Earth
local removing = {} -- unitID -> true: destroyed by this gadget (no points, no respawn)
local wildDue = {} -- frames at which a wild unit comes back
local nukes = {} -- { frame, x, z, p }: the missiles of Gates of Hell still to come
local land = nil -- the land grid: { cols, rows, cells = list of cell numbers of the land everybody stands on, onLand = cell -> true }
local running, armageddon, finished = false, false, false
local armaFrame, hero = 0, "" -- the frame Armageddon began and who brought it
local alliancesAtStart = 0
local startStage = math.max(1, math.min(STAGES, tonumber((Spring.GetModOptions() or {}).lanevolutionstage) or 1)) -- test only

local function need(s)
	return math.max(1, math.floor(FIRST * FACTOR ^ (s - 1) + 0.5))
end

-- The worth of a kill of a player unit of stage v by a unit of stage k
local function worth(v, k)
	return need(v) * math.max(1, 1 + v - k)
end

-- A unit of the stage, of a random faction whose unit exists in the game
local function stageUnit(s)
	local options = {}
	for _, ladder in ipairs(LADDERS) do
		if UnitDefNames[ladder[s]] then
			options[#options + 1] = ladder[s]
		end
	end
	return options[math.random(1, math.max(1, #options))] or "armpw"
end

local function unitTitle(name)
	return NAMES[name] or name
end

local function publish()
	local teams = {}
	local pub = { public = true }
	for _, p in ipairs(players) do
		teams[#teams + 1] = p.team
		Spring.SetTeamRulesParam(p.team, "evoStage", p.stage, pub)
		Spring.SetTeamRulesParam(p.team, "evoXp", p.xp, pub)
		Spring.SetTeamRulesParam(p.team, "evoNeed", p.stage < STAGES and need(p.stage) or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoKills", p.kills, pub)
		Spring.SetTeamRulesParam(p.team, "evoDeaths", p.deaths, pub)
		Spring.SetTeamRulesParam(p.team, "evoOut", p.out and 1 or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoUnit", p.unit or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoSpawn", p.spawns, pub)
		Spring.SetTeamRulesParam(p.team, "evoName", p.unitName or "", pub)
		Spring.SetTeamRulesParam(p.team, "evoExp", p.exp or 0, pub)
		Spring.SetTeamRulesParam(p.team, "evoGift", p.giftAt and 1 or 0, pub)
	end
	Spring.SetGameRulesParam("evoTeams", table.concat(teams, ","))
	-- (set again with every publish: a value set only once at that moment did not reach the unsynced part and the widgets in the test)
	Spring.SetGameRulesParam("evoArmageddon", armaFrame)
	Spring.SetGameRulesParam("evoHero", hero)
	if not finished then
		Spring.SetGameRulesParam("evoState", running and "running" or "")
	end
end

-- Can a unit of this kind stand and move at x, z (land, not too steep)? Without TestMoveOrder: not under water. objects = false: features and units do not count
local function fits(defID, x, z, objects)
	local y = Spring.GetGroundHeight(x, z)
	local ud = UnitDefs[defID]
	if ud and ud.isBuilding then
		-- a building (tower, radar): where it can be built (2 = free; with objects == false also places with a unit or feature in the way)
		local r = Spring.TestBuildOrder(defID, x, y, z, 0)
		return y > -5 and (r == 2 or (objects == false and r ~= 0))
	end
	if Spring.TestMoveOrder then
		local ok, res = pcall(Spring.TestMoveOrder, defID, x, y, z, 0, 0, 0, true, objects ~= false, true)
		if ok then
			return res and y > -5
		end
	end
	return y > 0
end

-- The land grid: every cell of CELL x CELL Elmo where a heavy tank can drive (the ladders' most demanding units on slopes), and of those the connected piece
-- (8 neighbours) that holds the most commanders (on a tie the bigger one). Every unit of the game spawns there: nobody is cut off by water or cliffs.
local function buildLand(starts)
	local ref = UnitDefNames.armbull or UnitDefNames.corraid or UnitDefNames.armpw
	local cols, rows = math.floor(Game.mapSizeX / CELL), math.floor(Game.mapSizeZ / CELL)
	local pass = {}
	for r = 0, rows - 1 do
		for c = 0, cols - 1 do
			if fits(ref.id, (c + 0.5) * CELL, (r + 0.5) * CELL, false) then
				pass[r * cols + c] = true
			end
		end
	end
	local comp, sizes, n = {}, {}, 0
	for start in pairs(pass) do
		if not comp[start] then
			n = n + 1
			local stack, size = { start }, 0
			comp[start] = n
			while #stack > 0 do
				local i = table.remove(stack)
				size = size + 1
				local r, c = math.floor(i / cols), i % cols
				for dr = -1, 1 do
					for dc = -1, 1 do
						local rr, cc = r + dr, c + dc
						local j = rr * cols + cc
						if rr >= 0 and rr < rows and cc >= 0 and cc < cols and pass[j] and not comp[j] then
							comp[j] = n
							stack[#stack + 1] = j
						end
					end
				end
			end
			sizes[n] = size
		end
	end
	local votes = {}
	for _, s in ipairs(starts) do
		local c = comp[math.floor(s[2] / CELL) * cols + math.floor(s[1] / CELL)]
		if c then
			votes[c] = (votes[c] or 0) + 1
		end
	end
	local best
	for c = 1, n do
		if not best or (votes[c] or 0) > (votes[best] or 0) or ((votes[c] or 0) == (votes[best] or 0) and sizes[c] > sizes[best]) then
			best = c
		end
	end
	land = { cols = cols, rows = rows, cells = {}, onLand = {} }
	for i, c in pairs(comp) do
		if c == best then
			land.cells[#land.cells + 1] = i
			land.onLand[i] = true
		end
	end
	table.sort(land.cells) -- (pairs has no fixed order: the list must be the same on every computer)
	Spring.Echo(string.format("[Evolution] land: %d of %d cells (%d x %d Elmo) in the piece with %d of %d commanders", #land.cells, cols * rows, CELL, CELL, votes[best] or 0, #starts))
end

local function onLand(x, z)
	return not land or land.onLand[math.floor(z / CELL) * land.cols + math.floor(x / CELL)] == true
end

-- A random place on the land
local function randomLand()
	if land and #land.cells > 0 then
		local i = land.cells[math.random(1, #land.cells)]
		return (i % land.cols + math.random()) * CELL, (math.floor(i / land.cols) + math.random()) * CELL
	end
	return math.random(200, Game.mapSizeX - 200), math.random(200, Game.mapSizeZ - 200)
end

local function nearestPlayer(x, z)
	local d = math.huge
	for id in pairs(owner) do
		local ux, _, uz = Spring.GetUnitPosition(id)
		if ux then
			d = math.min(d, (ux - x) ^ 2 + (uz - z) ^ 2)
		end
	end
	return d
end

-- A random place on the land for a new unit. A player's unit (far = true): of 24 tries the one farthest from the units of the players. Otherwise the first
-- try at least minGap Elmo from every player unit (default 600: the wild units are spread over the whole land, not only at its edges)
local function spawnPoint(defID, far, minGap)
	local gap2 = (minGap or 600) ^ 2
	local best, bestD = nil, -1
	for _ = 1, 24 do
		local x, z = randomLand()
		if fits(defID, x, z) then
			local d = nearestPlayer(x, z)
			if not far and d >= gap2 then
				return x, z
			end
			if d > bestD then
				best, bestD = { x, z }, d
			end
		end
	end
	if best then
		return best[1], best[2]
	end
	return randomLand()
end

local function remove(id)
	if id and Spring.ValidUnitID(id) then
		removing[id] = true
		Spring.DestroyUnit(id, false, true) -- no explosion, no wreck
	end
end

-- ---------------------------------------------------------------- abilities and their beacons (one table: Lua 5.1 allows only so many locals and upvalues)
-- A player record keeps p.abilities (index -> true), p.cool (index -> frame it is ready again) and p.active (index -> { frame it ends, unit }).
local A = {
	beacons = {}, -- { x, z, kind = index of ABILITIES }
	due = {}, -- frames at which a taken beacon lies somewhere else
	PICK = 80, -- Elmo: a player's unit this near takes a beacon
	BACK = 45 * FPS, -- frames until a taken beacon comes back somewhere else (a new random color)
	SPEED = 1.5, HEAL = 0.2, PULSE = 2500, JAM = 500, -- sprint factor, part of the health, sight of the pulse, jammer radius
}

-- one beacon per 2048 x 2048 Elmo of the land, 5 to 20
-- beacons of every ability at the start: one per 3000 x 3000 Elmo of the land and at least one per two players, 2 to 6 of each kind
function A.count()
	local area = land and (#land.cells * CELL * CELL) or (Game.mapSizeX * Game.mapSizeZ)
	return math.max(2, math.min(6, math.max(math.floor(area / (3000 * 3000) + 0.5), math.ceil((#Spring.GetTeamList() - 1) / 2)))) -- (all teams but Gaia: the players are not all joined yet)
end

-- a beacon of the ability kind at a random place of the land; false when no free place was found
function A.place(kind)
	local ref = UnitDefNames.armpw
	for _ = 1, 10 do
		local x, z = randomLand()
		if not ref or fits(ref.id, x, z, false) then
			A.beacons[#A.beacons + 1] = { x = x, z = z, kind = kind }
			return true
		end
	end
	return false
end

-- the beacons for the unsynced part: game rule evoBeacons "x,z,kind" separated by /; the abilities of the players: team rule evoAbilities "index:seconds of
-- cooldown left:seconds the effect still lasts" separated by ,
function A.publish()
	local t = {}
	for _, b in ipairs(A.beacons) do
		t[#t + 1] = string.format("%d,%d,%d", b.x, b.z, b.kind)
	end
	Spring.SetGameRulesParam("evoBeacons", table.concat(t, "/"))
	local n = Spring.GetGameFrame()
	for _, p in ipairs(players) do
		local list = {}
		for i in ipairs(ABILITIES) do
			if p.abilities and p.abilities[i] then
				local act = p.active and p.active[i]
				list[#list + 1] = string.format("%d:%d:%d", i, math.max(0, math.ceil((((p.cool and p.cool[i]) or 0) - n) / FPS)), act and math.max(0, math.ceil((act.frame - n) / FPS)) or 0)
			end
		end
		Spring.SetTeamRulesParam(p.team, "evoAbilities", table.concat(list, ","), { public = true })
	end
end

local function sensor(id, kind, value)
	pcall(Spring.SetUnitSensorRadius, id, kind, value)
end

-- Cloak for every unit: the engine cloaks only a unit whose definition can cloak (checked: SetUnitCloak does nothing for the others), so the unit is also
-- hidden by forcing its line of sight state to nothing (mask 15 = los, radar, previous los, contradar) for every other ally team
function A.hide(id, on)
	local mine = Spring.GetUnitAllyTeam(id)
	for _, a in ipairs(Spring.GetAllyTeamList()) do
		if a ~= mine then
			pcall(Spring.SetUnitLosMask, id, a, on and 15 or 0)
			if on then
				pcall(Spring.SetUnitLosState, id, a, 0)
			end
		end
	end
end

-- the effect of ability i on the player's unit begins / ends
function A.start(p, i)
	local id, a = p.unit, ABILITIES[i]
	local ud = UnitDefs[Spring.GetUnitDefID(id)]
	if a.key == "jammer" then
		sensor(id, "radarJammer", A.JAM)
		pcall(Spring.SetUnitStealth, id, true) -- (invisible to radar and sonar)
		pcall(Spring.SetUnitSonarStealth, id, true)
	elseif a.key == "cloak" then
		pcall(Spring.SetUnitCloak, id, true, 75)
		pcall(Spring.SetUnitCloak, id, 1) -- (script cloak: also a unit that cannot cloak by itself)
		A.hide(id, true)
	elseif a.key == "sprint" then
		pcall(Spring.MoveCtrl.SetGroundMoveTypeData, id, { maxSpeed = ud.speed * A.SPEED, maxWantedSpeed = ud.speed * A.SPEED })
	elseif a.key == "repair" then
		local hp, maxHp = Spring.GetUnitHealth(id)
		Spring.SetUnitHealth(id, math.min(maxHp, hp + maxHp * A.HEAL))
	elseif a.key == "pulse" then
		sensor(id, "los", A.PULSE)
		sensor(id, "airLos", A.PULSE)
	end
	if a.time > 0 then
		p.active = p.active or {}
		p.active[i] = { frame = Spring.GetGameFrame() + a.time * FPS, unit = id }
	end
end

function A.stop(p, i)
	local act = p.active[i]
	p.active[i] = nil
	p.cool = p.cool or {}
	p.cool[i] = Spring.GetGameFrame() + ABILITIES[i].cool * FPS -- the cooldown begins when the effect is over
	local id, key = act.unit, ABILITIES[i].key
	if not Spring.ValidUnitID(id) or Spring.GetUnitIsDead(id) then
		return
	end
	local ud = UnitDefs[Spring.GetUnitDefID(id)]
	if key == "jammer" then
		sensor(id, "radarJammer", ud.jammerRadius or 0)
		pcall(Spring.SetUnitStealth, id, ud.stealth or false)
		pcall(Spring.SetUnitSonarStealth, id, ud.sonarStealth or false)
	elseif key == "cloak" then
		pcall(Spring.SetUnitCloak, id, false)
		pcall(Spring.SetUnitCloak, id, 0)
		A.hide(id, false)
	elseif key == "sprint" then
		pcall(Spring.MoveCtrl.SetGroundMoveTypeData, id, { maxSpeed = ud.speed, maxWantedSpeed = ud.speed })
	elseif key == "pulse" then
		sensor(id, "los", ud.losRadius or ud.sightDistance or 400)
		sensor(id, "airLos", ud.airLosRadius or ud.airSightDistance or 400)
	end
end

-- ability i of the player: when it has it, it is ready and the team has the energy; true when it began
function A.use(p, i)
	local a, n = ABILITIES[i], Spring.GetGameFrame()
	if not (a and p.abilities and p.abilities[i]) or not p.unit or p.out or ((p.cool and p.cool[i]) or 0) > n or (p.active and p.active[i]) then
		return false
	end
	if a.key == "repair" then
		local hp, maxHp = Spring.GetUnitHealth(p.unit)
		if not hp or hp >= maxHp - 0.5 then
			return false -- full health: nothing happens, no energy is spent
		end
	end
	if not Spring.UseTeamResource(p.team, "energy", a.cost) then
		return false
	end
	p.cool = p.cool or {}
	if a.time <= 0 then
		p.cool[i] = n + a.cool * FPS -- (an effect that lasts: the cooldown starts when it ends, see A.stop)
	end
	A.start(p, i)
	A.publish()
	return true
end

-- a computer player uses what it has: repair below 40 % health, sprint toward a target that is far, jammer and cloak when it has a target, the pulse when not
function A.ai(p, target)
	if not p.abilities or not p.unit then
		return
	end
	local hp, maxHp = Spring.GetUnitHealth(p.unit)
	local far = false
	if target then
		local x, _, z = Spring.GetUnitPosition(p.unit)
		local tx, _, tz = Spring.GetUnitPosition(target)
		far = x and tx and (tx - x) ^ 2 + (tz - z) ^ 2 > 600 * 600
	end
	for i, a in ipairs(ABILITIES) do
		if p.abilities[i] then
			local want = (a.key == "repair" and hp and maxHp and hp < maxHp * 0.4) or (a.key == "sprint" and far) or ((a.key == "jammer" or a.key == "cloak") and target ~= nil)
				or (a.key == "pulse" and not target)
			if want then
				A.use(p, i)
			end
		end
	end
end

-- the player loses its abilities (its unit died)
function A.lose(p)
	p.abilities, p.cool, p.active = {}, {}, {}
end

-- every 15 frames: effects that end, beacons that are taken or come back, the cooldown in the captions
function A.update(n)
	local changed = false
	for _, p in ipairs(players) do
		for i, act in pairs(p.active or {}) do
			if n >= act.frame or act.unit ~= p.unit then
				A.stop(p, i)
			elseif ABILITIES[i].key == "cloak" then
				-- firing shows the unit: a weapon whose reload began since the last look ends the cloak
				local since = act.seen or act.frame - ABILITIES[i].time * FPS
				act.seen = n
				local ud = UnitDefs[Spring.GetUnitDefID(act.unit)]
				for w = 1, #(ud and ud.weapons or {}) do
					local r = Spring.GetUnitWeaponState(act.unit, w, "reloadFrame")
					if r and r > since then
						A.stop(p, i)
						say(p.name .. " is seen: the cloak ends when the unit fires.")
						break
					end
				end
			end
		end
		if p.cool and n % FPS == 0 then
			for i, f in pairs(p.cool) do
				if f >= n - 3 * FPS then
					changed = true -- (a cooldown runs or ended in the last seconds: the bar shows it)
					break
				end
			end
		end
	end
	local keep = {}
	for _, b in ipairs(A.beacons) do
		local taker
		for _, uid in ipairs(Spring.GetUnitsInCylinder(b.x, b.z, A.PICK)) do
			local p = owner[uid]
			if p and not p.out and not (p.abilities and p.abilities[b.kind]) then
				taker = p
				break
			end
		end
		if taker then
			taker.abilities = taker.abilities or {}
			taker.abilities[b.kind] = true
			A.due[#A.due + 1] = { n + A.BACK, b.kind } -- (the same kind comes back somewhere else)
			say(string.format("%s found %s.", taker.name, ABILITIES[b.kind].name))
			changed = true
		else
			keep[#keep + 1] = b
		end
	end
	A.beacons = keep
	local due = {}
	for _, d in ipairs(A.due) do
		if n < d[1] then
			due[#due + 1] = d
		elseif A.place(d[2]) then
			changed = true
		else
			due[#due + 1] = { n + 5 * FPS, d[2] } -- (no free place: again in 5 s)
		end
	end
	A.due = due
	if changed or n % FPS == 0 then
		A.publish()
	end
end

-- The unit of a player: at x, z (a random place when nil), a unit of its stage. A computer team's unit only shoots back (it attacks what the
-- gadget chooses).
local function spawn(p, x, z, facing)
	local name = stageUnit(p.stage)
	if not x then
		x, z = spawnPoint(UnitDefNames[name].id, true)
		p.spawns = p.spawns + 1 -- (the camera of the player goes to the new place)
	end
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, facing or 0, p.team)
	p.unit, p.unitName, p.respawnAt = id, name, nil
	if id then
		owner[id] = p
		if (p.exp or 0) > 0 then
			Spring.SetUnitExperience(id, p.exp)
		end
		if p.ai then
			Spring.GiveOrderToUnit(id, CMD_FIRE_STATE, { RETURN_FIRE }, 0)
		end
	end
	publish()
end

-- The last alliance with a player that is not out wins (after Armageddon; only when the game began with two alliances or more)
local function checkWin()
	if finished or not armageddon then
		return
	end
	local left, n, last = {}, 0, nil
	for _, p in ipairs(players) do
		if not p.out and not left[p.ally] then
			left[p.ally] = true
			n, last = n + 1, p.ally
		end
	end
	if alliancesAtStart >= 2 and n <= 1 and last then
		finished = true
		local names = {}
		for _, p in ipairs(players) do
			if p.ally == last then
				names[#names + 1] = p.name
			end
		end
		Spring.SetGameRulesParam("evoState", "won by " .. table.concat(names, ", "))
		say(table.concat(names, ", ") .. " is the last one standing: the game is won!")
		Spring.GameOver({ last })
	end
end

-- Armageddon: the first unit on stage 10. No fog of war for anybody, no respawn any more
local function startArmageddon(p)
	armageddon = true
	for _, a in ipairs(Spring.GetAllyTeamList()) do
		pcall(Spring.SetGlobalLos, a, true)
	end
	armaFrame, hero = Spring.GetGameFrame(), p.name
	publish()
	say("Armageddon is here! " .. p.name .. " reached level 10. The fog of war is gone: everybody sees everybody.")
	say("From now on a lost unit does not come back. The last one standing wins.")
end

-- Enemies of each other: not the same alliance and not allied for the time being (the alliance against level 10, setCoalition)
local function enemies(p, q)
	return p.ally ~= q.ally and not Spring.AreTeamsAllied(p.team, q.team)
end

-- The alliance against level 10: as long as a player on level 10 is in, every alliance without such a player is allied with every other one of them
-- (Spring.SetAlly both ways); when no player on level 10 is left, everybody is on their own again. Called when a player reaches level 10 and when one is out.
-- The game is still won by the last alliance of the start (checkWin): when the players on level 10 are gone, the others fight each other.
local coalitionOn = false
local function setCoalition()
	local top, names = {}, {}
	for _, p in ipairs(players) do
		if not p.out and p.stage >= STAGES then
			top[p.ally] = true
			names[#names + 1] = p.name
		end
	end
	local on = #names > 0
	local list, seen, pairsAllied = {}, {}, 0
	for _, p in ipairs(players) do
		if not seen[p.ally] then
			seen[p.ally] = true
			list[#list + 1] = p.ally
		end
	end
	for i = 1, #list do
		for j = i + 1, #list do
			local together = on and not top[list[i]] and not top[list[j]]
			pairsAllied = pairsAllied + (together and 1 or 0)
			pcall(Spring.SetAlly, list[i], list[j], together)
			pcall(Spring.SetAlly, list[j], list[i], together)
		end
	end
	if on and pairsAllied > 0 then
		say("Everybody else is allied now against " .. table.concat(names, ", ") .. " (level 10)!")
	elseif coalitionOn then
		say("Nobody on level 10 is left: the alliance is over, everybody fights on their own again.")
	end
	coalitionOn = on and pairsAllied > 0
end

-- ---------------------------------------------------------------- the gifts of stage 10
-- Hell on Earth: strong ground units (stages 6 to 8, random factions) rise at random places of the land, far from the enemies
local hells = {} -- { p, nextAt, pending }: the players whose Hell on Earth runs
local hellOf = {} -- unitID -> the record in hells (to replace a unit that dies)
-- one random tier 3 unit (levels 8 to 10 of a random faction) somewhere on the land, the player's own
local function hellUnit(g)
	local name = stageUnit(math.random(8, 10))
	local x, z = spawnPoint(UnitDefNames[name].id, false, 900)
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, math.random(0, 3), g.p.team)
	if id then
		summoned[id] = g.p
		hellOf[id] = g
	end
end

-- Hell on Earth: HELL_UNITS tier 3 units at once; a unit that is lost is replaced by a new one somewhere (it never ends), and one more comes every
-- HELL_GAP frames (until the game is won or the player is out)
local function giftHell(p)
	local g = { p = p, nextAt = Spring.GetGameFrame() + HELL_GAP, pending = 0 }
	hells[#hells + 1] = g
	for _ = 1, HELL_UNITS do
		hellUnit(g)
	end
end

local function hellStep(n)
	for i = #hells, 1, -1 do
		local g = hells[i]
		if finished or g.p.out then
			table.remove(hells, i)
		else
			while g.pending > 0 do
				g.pending = g.pending - 1
				hellUnit(g)
			end
			if n >= g.nextAt then
				g.nextAt = n + HELL_GAP
				hellUnit(g)
			end
		end
	end
end

-- Heaven on Earth: Dragons come down on a hexagon round the player's unit
local heavens = {} -- { p, nextAt, pending, options }: the players whose Heaven on Earth runs
local heavenOf = {} -- unitID -> the record in heavens
local function dragon(g, x, z)
	x, z = math.max(50, math.min(Game.mapSizeX - 50, x)), math.max(50, math.min(Game.mapSizeZ - 50, z))
	local id = Spring.CreateUnit(g.options[math.random(1, #g.options)], x, Spring.GetGroundHeight(x, z) + 300, z, 0, g.p.team)
	if id then
		summoned[id] = g.p
		heavenOf[id] = g
	end
end

-- Heaven on Earth: HEAVEN_UNITS Dragons evenly spread on a hexagon round the unit (corners at 0, 60, 120 ... degrees, 320 Elmo from the unit); a lost one is
-- replaced by a new one near the player's unit, and one more comes at a random place every HEAVEN_GAP frames
local function giftHeaven(p)
	local options = {}
	for _, n in ipairs(GUNSHIPS) do
		if UnitDefNames[n] then
			options[#options + 1] = n
		end
	end
	local x, _, z = Spring.GetUnitPosition(p.unit or -1)
	if not x or #options == 0 then
		return giftHell(p)
	end
	local g = { p = p, nextAt = Spring.GetGameFrame() + HEAVEN_GAP, pending = 0, options = options }
	heavens[#heavens + 1] = g
	for i = 1, HEAVEN_UNITS do
		local e = (i - 1) / HEAVEN_UNITS * 6
		local k, f = math.floor(e), e - math.floor(e)
		local a1, a2 = math.rad(k * 60), math.rad((k + 1) * 60)
		local hx = math.cos(a1) * (1 - f) + math.cos(a2) * f
		local hz = math.sin(a1) * (1 - f) + math.sin(a2) * f
		dragon(g, x + hx * 320, z + hz * 320)
	end
end

local function heavenStep(n)
	for i = #heavens, 1, -1 do
		local g = heavens[i]
		if finished or g.p.out then
			table.remove(heavens, i)
		else
			local x, _, z = Spring.GetUnitPosition(g.p.unit or -1)
			while g.pending > 0 and x do
				g.pending = g.pending - 1
				local a = math.random() * 2 * math.pi
				dragon(g, x + math.cos(a) * 320, z + math.sin(a) * 320) -- (a new one near the player)
			end
			if n >= g.nextAt then
				g.nextAt = n + HEAVEN_GAP
				local rx, rz = randomLand()
				dragon(g, rx, rz)
			end
		end
	end
end

-- Gates of Hell: missiles at a growing rate (see gatesStep); a red ring warns NUKE_WARN frames before each one
local gates = {} -- { p, start, nextAt, follow = team -> frame }: the players whose Gates of Hell run
local FOLLOW_AI = (Spring.GetModOptions() or {}).lanevotest == "1" -- test only: the computer players are followed too (a test has no second human)
local GATES_PER_PLAYER = 10 -- the first barrage: this many missiles per player (not per map size), all at once
local function giftGates(p)
	local now = Spring.GetGameFrame()
	gates[#gates + 1] = { p = p, start = now, nextAt = now + 10 * FPS }
	-- the first barrage: at once (all after the warning time) at random places of the land, only not near the units of the player who chose the gate or of
	-- his alliance; the others see the rings and know what is coming
	local safe = {}
	for _, q in ipairs(players) do
		if q.ally == p.ally and q.unit and Spring.ValidUnitID(q.unit) then
			local ux, _, uz = Spring.GetUnitPosition(q.unit)
			if ux then
				safe[#safe + 1] = { ux, uz }
			end
		end
	end
	for _ = 1, math.max(20, GATES_PER_PLAYER * #players) do
		for _ = 1, 30 do
			local x, z = randomLand()
			local free = true
			for _, s in ipairs(safe) do
				if (s[1] - x) ^ 2 + (s[2] - z) ^ 2 < NUKE_SAFE ^ 2 then
					free = false
				end
			end
			if free then
				nukes[#nukes + 1] = { frame = now + NUKE_WARN, x = math.floor(x), z = math.floor(z), p = p }
				break
			end
		end
	end
end

-- Gates of Hell never ends and gets worse (after the first barrage of giftGates). Every human enemy has missiles of his own that follow him: a volley at him
-- every `interval` (10 s at the start, 3 s after four minutes) of 1 + t / 120 s missiles (one at the start, two after two minutes, then one more every two
-- minutes), at 2000 Elmo (+ up to 200) from his unit at first, 12 Elmo less per second down to 120, so they come closer and closer. Computer players are not
-- followed. Besides that one missile at a random place of the land at every volley rhythm of the gate, so the map fills up. Never within NUKE_SAFE Elmo of a unit
-- of the player who chose the gate or of his alliance.
local function gatesStep(n)
	for gi = #gates, 1, -1 do
		local g = gates[gi]
		if finished or g.p.out then
			table.remove(gates, gi)
		else
			local t = (n - g.start) / FPS
			local interval = math.floor(math.max(3, 10 - 7 * t / 240) * FPS) -- 10 s at the start, 3 s after four minutes
			local safe = {}
			for _, q in ipairs(players) do
				if q.ally == g.p.ally and q.unit and Spring.ValidUnitID(q.unit) then
					local ux, _, uz = Spring.GetUnitPosition(q.unit)
					if ux then
						safe[#safe + 1] = { ux, uz }
					end
				end
			end
			local function ok(x, z)
				for _, s in ipairs(safe) do
					if (s[1] - x) ^ 2 + (s[2] - z) ^ 2 < NUKE_SAFE ^ 2 then
						return false
					end
				end
				return x > 100 and z > 100 and x < Game.mapSizeX - 100 and z < Game.mapSizeZ - 100
			end
			local function add(x, z, k)
				nukes[#nukes + 1] = { frame = n + NUKE_WARN + (k - 1) * 20, x = math.floor(x), z = math.floor(z), p = g.p }
			end
			g.follow = g.follow or {}
			for _, q in ipairs(players) do
				if enemies(g.p, q) and (not q.ai or FOLLOW_AI) and not q.out and q.unit and Spring.ValidUnitID(q.unit) and n >= (g.follow[q.team] or 0) then
					g.follow[q.team] = n + interval
					local qx, _, qz = Spring.GetUnitPosition(q.unit)
					for k = 1, 1 + math.floor(t / 120) do
						for _ = 1, 20 do
							local d = math.max(120, 2000 - t * 12) + math.random() * 200
							local a = math.random() * 2 * math.pi
							local x, z = qx + math.cos(a) * d, qz + math.sin(a) * d
							if ok(x, z) then
								add(x, z, k)
								break
							end
						end
					end
				end
			end
			if n >= g.nextAt then
				g.nextAt = n + interval
				for _ = 1, 20 do
					local x, z = randomLand()
					if ok(x, z) then
						add(x, z, 1)
						break
					end
				end
			end
		end
	end
end

local function nukeWeapon()
	for _, n in ipairs({ "armsilo", "corsilo", "legsilo" }) do
		local ud = UnitDefNames[n]
		if ud and ud.weapons and ud.weapons[1] then
			return ud.weapons[1].weaponDef
		end
	end
end

-- A missile of Gates of Hell: falls from high above onto its target (the explosion of the game's nuclear missile)
local function launch(nk)
	local wd = nukeWeapon()
	if not wd then
		return
	end
	local y = Spring.GetGroundHeight(nk.x, nk.z)
	local src = (nk.p.unit and Spring.ValidUnitID(nk.p.unit)) and nk.p.unit or -1 -- (the kills count for the player)
	local ok, id = pcall(Spring.SpawnProjectile, wd, { pos = { nk.x, y + 2500, nk.z }, ["end"] = { nk.x, y, nk.z }, speed = { 0, -30, 0 }, owner = src, team = nk.p.team, ttl = 900 })
	if not ok or not id then
		-- (no projectile: the explosion itself)
		pcall(Spring.SpawnExplosion, nk.x, y, nk.z, 0, 0, 0, { weaponDef = wd, owner = src })
	end
end

local function giveGift(p, n)
	if not p.giftAt then
		return
	end
	n = (n >= 1 and n <= 3) and n or math.random(1, 3)
	p.giftAt = nil
	say(p.name .. " chose " .. GIFT_NAMES[n] .. "!")
	if n == 1 then
		giftHell(p)
	elseif n == 2 then
		giftHeaven(p)
	else
		giftGates(p)
	end
	publish()
end

-- A player reaches stage 10 for the first time: Armageddon (the first one) and the choice of a gift
local function reachTop(p)
	if p.top then
		return
	end
	p.top = true
	if not armageddon then
		startArmageddon(p)
	else
		say(p.name .. " reached level 10 as well.")
	end
	setCoalition() -- the others ally against the players on level 10
	p.giftAt = Spring.GetGameFrame()
	if p.ai then
		giveGift(p, math.random(1, 3))
	end
end

-- The unit of the next stage replaces the unit where it stands (full health; the orders are kept)
local function evolve(p)
	local old = p.unit
	local x, _, z = Spring.GetUnitPosition(old)
	if not x then
		return
	end
	local facing = Spring.GetUnitBuildFacing(old) or 0
	local cmds = Spring.GetUnitCommands(old, 16) or {}
	local ohp, omax = Spring.GetUnitHealth(old)
	owner[old] = nil
	remove(old)
	spawn(p, x, z, facing)
	if p.unit and ohp and omax and omax > 0 then
		-- level up: 20 % of the new unit's health come back, not a full heal (the health fraction of the old unit plus 20 %)
		local _, nmax = Spring.GetUnitHealth(p.unit)
		if nmax then
			Spring.SetUnitHealth(p.unit, math.min(nmax, nmax * (ohp / omax + 0.2)))
		end
	end
	if p.unit and not p.ai then
		for _, c in ipairs(cmds) do
			pcall(Spring.GiveOrderToUnit, p.unit, c.id, c.params, { "shift" })
		end
	end
	say(string.format("%s evolves to level %d: %s.", p.name, p.stage, unitTitle(p.unitName)))
end

local function gain(p, points)
	if p.out then
		return
	end
	p.xp = p.xp + points
	local up = false
	while p.stage < STAGES and p.xp >= need(p.stage) do
		p.xp = p.xp - need(p.stage)
		p.stage = p.stage + 1
		up = true
	end
	if p.stage >= STAGES then
		p.xp = 0 -- the top stage: nothing left to collect
	end
	if up and p.unit then
		evolve(p)
	end
	if p.stage >= STAGES then
		reachTop(p)
	end
	publish()
end

-- A wild unit: a stage 1 unit of a random faction, of Gaia, with WILD_HP of its health, at a random place; it holds its position and only shoots back
-- The number of wild units: one per 1024 x 1024 Elmo of the land (a map of 16 x 16 without water has 64), at least 12, at most 100
local function wildCount()
	local area = land and (#land.cells * CELL * CELL) or (Game.mapSizeX * Game.mapSizeZ)
	local mult = math.max(1, math.min(10, tonumber((Spring.GetModOptions() or {}).lanevomult) or 1)) -- the unit multiplier of the room (1 - 10)
	return math.floor(math.max(12, math.min(100, math.floor(area / (1024 * 1024) + 0.5))) * mult)
end

-- The stage of a new wild unit: the lowest stage of the players who are still in (the weakest player can always catch up on them)
local function wildStage()
	local low
	for _, p in ipairs(players) do
		if not p.out and (not low or p.stage < low) then
			low = p.stage
		end
	end
	return low or 1
end

-- A tower of the stage, of a random faction whose tower exists in the game
local function stageTower(s)
	local options = {}
	for _, ladder in ipairs(R.TOWERS) do
		if UnitDefNames[ladder[s]] then
			options[#options + 1] = ladder[s]
		end
	end
	return options[math.random(1, math.max(1, #options))]
end

-- The points of a wild unit of stage s: a third of what stage s needs (about three of them for the next stage), at least 1
local function wildWorth(s)
	return math.max(1, math.floor(need(s) / 3 + 0.5))
end

-- A wild unit (Gaia): of stage s (default: wildStage()), a tower with the chance R.TOWER (tower = true / false forces it), at x, z (default: a random place
-- away from the players)
local function spawnWild(s, tower, x, z, facing)
	s = s or wildStage()
	if tower == nil then
		tower = math.random() < R.TOWER
	end
	local name = tower and stageTower(s) or stageUnit(s)
	tower = tower and name ~= nil
	name = name or stageUnit(s)
	if not x then
		x, z = spawnPoint(UnitDefNames[name].id)
	end
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, facing or math.random(0, 3), Spring.GetGaiaTeamID())
	if id then
		wild[id] = { stage = s, tower = tower, still = tower or math.random() < R.STILL }
		local _, maxHp = Spring.GetUnitHealth(id)
		Spring.SetUnitHealth(id, math.max(1, (maxHp or 100) * WILD_HP)) -- (the maximum stays: the health bar shows the fraction)
		Spring.GiveOrderToUnit(id, CMD_FIRE_STATE, { RETURN_FIRE }, 0)
		Spring.GiveOrderToUnit(id, CMD_MOVE_STATE, { HOLD_POSITION }, 0)
	end
	return id
end

-- Every R.WANDER frames: a part (R.WANDER_SHARE) of the idle wild units that walk (not the towers and not the R.STILL that stand) go to a random place of the
-- land within R.WANDER_DIST
local function wanderWild()
	for id, w in pairs(wild) do
		if not w.still and math.random() < R.WANDER_SHARE and Spring.ValidUnitID(id) then
			local n = Spring.GetUnitCommands(id, 0)
			local x, _, z = Spring.GetUnitPosition(id)
			if x and type(n) == "number" and n == 0 then
				for _ = 1, 4 do
					local a, d = math.random() * 2 * math.pi, R.WANDER_DIST * (0.3 + 0.7 * math.random())
					local tx, tz = x + d * math.cos(a), z + d * math.sin(a)
					if tx > 64 and tz > 64 and tx < Game.mapSizeX - 64 and tz < Game.mapSizeZ - 64 and onLand(tx, tz) then
						Spring.GiveOrderToUnit(id, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
						break
					end
				end
			end
		end
	end
end

-- Every R.CHECK frames: as many wild units as wildCount() (living ones and those due to come back); a wild unit that is gone without UnitDestroyed is dropped
local function topUpWild()
	local n = #wildDue
	for id in pairs(wild) do
		if Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then
			n = n + 1
		else
			wild[id] = nil
		end
	end
	for _ = n + 1, wildCount() do
		spawnWild()
	end
end

-- Every R.UPGRADE frames: one wild unit above the lowest stage of the players who are still in, or two or more below it (the weakest player
-- went down after a death) becomes one of that stage, at its place
local function upgradeWild()
	local low = wildStage()
	for id, w in pairs(wild) do
		if w.stage > low or low - w.stage >= 2 then -- (above the weakest player at all: he must have a chance; below: two or more)
			local x, _, z = Spring.GetUnitPosition(id)
			if x then
				local facing = Spring.GetUnitBuildFacing(id)
				wild[id] = nil
				remove(id)
				spawnWild(low, w.tower, x, z, facing)
				return
			end
		end
	end
end


-- A team steered by a human: an active player who is not a spectator plays it
local function hasHuman(team)
	for _, pid in ipairs(Spring.GetPlayerList(team, true) or {}) do
		local _, active, spec = Spring.GetPlayerInfo(pid, false)
		if active and not spec then
			return true
		end
	end
	return false
end

local function commanderOf(team)
	for _, id in ipairs(Spring.GetTeamUnits(team)) do
		local ud = UnitDefs[Spring.GetUnitDefID(id)]
		if ud and ud.customParams and ud.customParams.iscommander then
			return id
		end
	end
end

-- A team whose commander is there: it becomes a player; its units are removed and its first unit stands where the commander stood (somewhere else on the
-- land when the commander stands off it, e.g. on another island)
local function join(team)
	local com = commanderOf(team)
	if not com then
		return false
	end
	local x, _, z = Spring.GetUnitPosition(com)
	for _, id in ipairs(Spring.GetTeamUnits(team)) do
		remove(id)
	end
	local p = { team = team, ally = select(6, Spring.GetTeamInfo(team, false)), stage = startStage, xp = 0, kills = 0, deaths = 0, spawns = 1, ai = not hasHuman(team), name = teamName(team) }
	players[#players + 1] = p
	byTeam[team] = p
	if onLand(x, z) then
		spawn(p, x, z)
	else
		spawn(p)
	end
	if p.stage >= STAGES then
		reachTop(p)
	end
	return true
end

local function idle(id)
	local n = Spring.GetUnitCommands(id, 0)
	return type(n) == "number" and n == 0
end

local function attackOrWalk(unitID, ally, target)
	-- an attack order needs a target the team sees (or has on the radar): otherwise the unit walks there first
	if Spring.IsUnitInLos(target, ally) or Spring.IsUnitInRadar(target, ally) then
		Spring.GiveOrderToUnit(unitID, CMD.ATTACK, { target }, 0)
	else
		local tx, _, tz = Spring.GetUnitPosition(target)
		Spring.GiveOrderToUnit(unitID, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
	end
end

-- The nearest unit of the list (unitID -> anything) for which want(record) is true
local function nearest(x, z, list, want)
	local best, bestD = nil, math.huge
	for id, rec in pairs(list) do
		if want(rec) then
			local ux, _, uz = Spring.GetUnitPosition(id)
			local d = ux and (ux - x) ^ 2 + (uz - z) ^ 2
			if d and d < bestD then
				best, bestD = id, d
			end
		end
	end
	return best, bestD
end

-- Computer teams: the unit attacks the nearest enemy player unit of its own stage or higher (at stage 1 also the wild units, they are stage 1; in
-- Armageddon every enemy player unit); with nothing to attack it walks to a random place. The units of its gifts attack the nearest enemy player unit.
local function steer(p)
	local x, _, z = Spring.GetUnitPosition(p.unit)
	if not x then
		return
	end
	local best, bestD = nearest(x, z, owner, function(q) return enemies(p, q) and (armageddon or q.stage >= p.stage) end)
	if not armageddon then
		-- wild units of its own stage or lower (they give points)
		local w, wd = nearest(x, z, wild, function(rec) return rec.stage <= p.stage end)
		if w and wd < bestD then
			best = w
		end
	end
	A.ai(p, best)
	-- radars and collectors: as long as its team holds fewer than its share (all of them divided by the players, at least 2) the nearest one that is not its
	-- team's comes first unless an enemy player unit is within 600 Elmo; it stands within the range until the radar is taken (R.TAKE), then the next one
	local owned, total = 0, 0
	for _, rd in pairs(radars) do
		total = total + 1
		if rd.team == p.team then
			owned = owned + 1
		end
	end
	local r, d
	if owned < math.max(2, math.ceil(total / math.max(1, #players))) then
		r, d = nearest(x, z, radars, function(rd) return rd.team ~= p.team and not Spring.AreTeamsAllied(rd.team, p.team) end)
	end
	local urgent = best and bestD < 600 * 600 and owner[best]
	if r and not urgent then
		if d <= (R.RANGE * 0.6) ^ 2 then
			if not idle(p.unit) then
				Spring.GiveOrderToUnit(p.unit, CMD.STOP, {}, 0)
			end
		elseif idle(p.unit) or p.goal ~= r then
			local rx, _, rz = Spring.GetUnitPosition(r)
			p.goal = r
			Spring.GiveOrderToUnit(p.unit, CMD.MOVE, { rx, Spring.GetGroundHeight(rx, rz), rz }, 0)
		end
	elseif best then
		p.goal = nil
		attackOrWalk(p.unit, p.ally, best)
	elseif idle(p.unit) then
		local tx, tz = randomLand()
		Spring.GiveOrderToUnit(p.unit, CMD.MOVE, { tx, Spring.GetGroundHeight(tx, tz), tz }, 0)
	end
end

local function steerSummoned()
	for id, p in pairs(summoned) do
		if p.ai and Spring.ValidUnitID(id) then
			local x, _, z = Spring.GetUnitPosition(id)
			local target = x and nearest(x, z, owner, function(q) return enemies(p, q) end)
			if target then
				attackOrWalk(id, p.ally, target)
			end
		end
	end
end

-- Every second: R.ENERGY_BASE + R.ENERGY per level for every player team that is still in, and a storage of at least R.STORE (the commanders and their storage are gone)
local function giveEnergy()
	for _, p in ipairs(players) do
		if not p.out then
			local _, store = Spring.GetTeamResources(p.team, "energy")
			if (store or 0) < R.STORE then
				Spring.SetTeamResource(p.team, "es", R.STORE)
			end
			Spring.AddTeamResource(p.team, "energy", R.ENERGY_BASE + R.ENERGY * p.stage)
		end
	end
end

-- A radar of the game (Gaia at first): neutral (nobody shoots at it on its own), cannot be destroyed (UnitPreDamaged, and GG.Indestructible of
-- unit_indestructible.lua against reclaiming)
local function newRadar(name, x, z, team)
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, 0, team)
	if id then
		Spring.SetUnitNeutral(id, true)
		radars[id] = { team = team, name = name }
		if GG.Indestructible then
			GG.Indestructible[id] = true
		end
	end
	return id
end

-- At the start: radars until R.COVER of the land is in their range. Each new one stands in a random cell that no radar reaches yet: they keep their distance
-- (a circle of the radar's range around each) and cover the land evenly
local function placeRadars()
	local kinds = {}
	for _, name in ipairs(R.RADAR1) do
		if UnitDefNames[name] then
			kinds[#kinds + 1] = name
		end
	end
	if not land or #land.cells == 0 or #kinds == 0 then
		return
	end
	local ud = UnitDefNames[kinds[1]]
	local range = ud.radarDistance or ud.radarRadius or 2100
	local covered, skip, left, count = {}, {}, #land.cells, 0
	local goal = math.floor(#land.cells * (1 - R.COVER))
	local gaia = Spring.GetGaiaTeamID()
	while left > goal and count < R.MAX_RADARS do
		local open = {}
		for _, i in ipairs(land.cells) do
			if not covered[i] and not skip[i] then
				open[#open + 1] = i
			end
		end
		if #open == 0 then
			break
		end
		local i = open[math.random(1, #open)]
		local name = kinds[math.random(1, #kinds)]
		local px, pz
		for _ = 1, 8 do
			local x, z = (i % land.cols + math.random()) * CELL, (math.floor(i / land.cols) + math.random()) * CELL
			if fits(UnitDefNames[name].id, x, z) then
				px, pz = x, z
				break
			end
		end
		if px and newRadar(name, px, pz, gaia) then
			count = count + 1
			for _, j in ipairs(land.cells) do
				if not covered[j] and ((j % land.cols + 0.5) * CELL - px) ^ 2 + ((math.floor(j / land.cols) + 0.5) * CELL - pz) ^ 2 <= range * range then
					covered[j] = true
					left = left - 1
				end
			end
		else
			skip[i] = true
		end
	end
	Spring.Echo(string.format("[Evolution] %d radars (range %d), %d of %d land cells in range", count, range, #land.cells - left, #land.cells))
end

-- Every half second (step frames): a radar with units of exactly one alliance of players within R.RANGE, not its owner's, is being taken; after R.TAKE frames
-- it belongs to the team of the unit that began. The progress goes to the game rule evoTaking ("x,z,seconds,team" separated by /) for the display.
local function takeRadars(step)
	local gaia = Spring.GetGaiaTeamID()
	local shown = {}
	for id, rd in pairs(radars) do
		local x, _, z = Spring.GetUnitPosition(id)
		if not x then
			radars[id] = nil
		else
			local here, allies = {}, 0
			for _, uid in ipairs(Spring.GetUnitsInCylinder(x, z, R.RANGE)) do
				local p = owner[uid] or summoned[uid]
				if p and not p.out and not here[p.ally] then
					here[p.ally] = p
					allies = allies + 1
				end
			end
			local ownerAlly = rd.team ~= gaia and select(6, Spring.GetTeamInfo(rd.team, false))
			local taker
			if allies == 1 then
				for ally, p in pairs(here) do
					if ally ~= ownerAlly then
						taker = p
					end
				end
			end
			if not taker then
				rd.take = nil
			else
				if not rd.take or rd.take.team ~= taker.team then
					rd.take = { team = taker.team, frames = 0 }
				end
				rd.take.frames = rd.take.frames + step
				if rd.take.frames >= R.TAKE then
					Spring.TransferUnit(id, taker.team, false)
					Spring.SetUnitNeutral(id, true)
					rd.team, rd.take = taker.team, nil
					say(taker.name .. " took " .. (rd.name:find("solar", 1, true) and "a solar collector" or (rd.name:find("win", 1, true) and "a wind turbine" or "a radar")) .. ".")
				else
					shown[#shown + 1] = string.format("%d,%d,%d,%d", x, z, math.floor(rd.take.frames / FPS), taker.team)
				end
			end
		end
	end
	Spring.SetGameRulesParam("evoTaking", table.concat(shown, "/"))
end

-- When more than half of the players who are still in are on stage R.T2_STAGE or higher: one radar (every R.UPGRADE frames) becomes the T2 radar of its
-- faction, at its place, for the same owner
local function upgradeRadars()
	local active, high = 0, 0
	for _, p in ipairs(players) do
		if not p.out then
			active = active + 1
			if p.stage >= R.T2_STAGE then
				high = high + 1
			end
		end
	end
	if active == 0 or high * 2 <= active then
		return
	end
	for id, rd in pairs(radars) do
		local to = R.RADAR2[rd.name]
		local x, _, z = Spring.GetUnitPosition(id)
		if to and UnitDefNames[to] and x then
			radars[id] = nil
			if GG.Indestructible then
				GG.Indestructible[id] = nil
			end
			remove(id)
			newRadar(to, x, z, rd.team)
			return
		end
	end
end

-- The radars of a player who is out go back to Gaia (nobody's)
-- At the start: neutral solar collectors and wind turbines of level 1 (a random faction each) at random places of the land, at least 300 Elmo apart; they
-- cannot be destroyed and are taken like the radars (the same table radars): then they give their energy to the team that took them
local function placeGenerators()
	local kinds = {}
	for _, name in ipairs(R.GENERATORS) do
		if UnitDefNames[name] then
			kinds[#kinds + 1] = name
		end
	end
	if not land or #land.cells == 0 or #kinds == 0 then
		return
	end
	local area = #land.cells * CELL * CELL
	local want = math.max(R.GEN_MIN, math.min(R.GEN_MAX, math.floor(area / (R.GEN_AREA * R.GEN_AREA) + 0.5)))
	local placed, gaia = {}, Spring.GetGaiaTeamID()
	for _ = 1, want * 10 do
		if #placed >= want then
			break
		end
		local name = kinds[math.random(1, #kinds)]
		local x, z = randomLand()
		local free = fits(UnitDefNames[name].id, x, z)
		for _, q in ipairs(placed) do
			if free and (q[1] - x) ^ 2 + (q[2] - z) ^ 2 < 300 * 300 then
				free = false
			end
		end
		if free and newRadar(name, x, z, gaia) then
			placed[#placed + 1] = { x, z }
		end
	end
	Spring.Echo(string.format("[Evolution] %d solar collectors and wind turbines", #placed))
end

local function freeRadars(p)
	local gaia = Spring.GetGaiaTeamID()
	for id, rd in pairs(radars) do
		if rd.team == p.team then
			Spring.TransferUnit(id, gaia, false)
			Spring.SetUnitNeutral(id, true)
			rd.team, rd.take = gaia, nil
		end
	end
end

function gadget:GameFrame(n)
	if n >= START_AFTER and n <= START_UNTIL and n % 15 == 0 then
		local gaia = Spring.GetGaiaTeamID()
		if not land then
			local starts = {}
			for _, team in ipairs(Spring.GetTeamList()) do
				local com = team ~= gaia and commanderOf(team)
				if com then
					local x, _, z = Spring.GetUnitPosition(com)
					starts[#starts + 1] = { x, z }
				end
			end
			if #starts > 0 then
				buildLand(starts)
			end
		end
		for _, team in ipairs(Spring.GetTeamList()) do
			if land and team ~= gaia and not byTeam[team] then
				local _, _, dead = Spring.GetTeamInfo(team, false)
				if not dead and join(team) and not running then
					running = true
					for _ = 1, wildCount() do
						spawnWild()
					end
					placeRadars()
					placeGenerators()
					for kind = 1, #ABILITIES do
						for _ = 1, A.count() do
							A.place(kind)
						end
					end
					A.publish()
					say(string.format("Evolution: kill to evolve (10 levels, a random faction each time); a lost unit comes back 5 s later at another place, one level lower. %d wild units and towers only shoot back; they grow with the players. Stand next to a radar for 5 s to take it; drive over a glowing beacon to get an ability. Level 10 brings Armageddon.", wildCount()))
				end
			end
		end
		local allies = {}
		alliancesAtStart = 0
		for _, p in ipairs(players) do
			if not allies[p.ally] then
				allies[p.ally] = true
				alliancesAtStart = alliancesAtStart + 1
			end
		end
		publish()
	end
	if not running then
		return
	end
	if n % FPS == 0 then
		giveEnergy()
	end
	if n % R.CHECK == 0 then
		topUpWild()
	end
	if n % R.WANDER == 75 then
		wanderWild()
	end
	if n % R.UPGRADE == 0 then
		upgradeWild()
		upgradeRadars()
	end
	if REGEN_ON and n % REGEN_STEP == 0 then
		-- the units regenerate: REGEN of the health every REGEN_STEP frames, not for REGEN_WAIT frames after the last damage
		for _, p in ipairs(players) do
			local id = p.unit
			if id and not p.out and n - (p.hurtAt or -REGEN_WAIT) >= REGEN_WAIT and Spring.ValidUnitID(id) and not Spring.GetUnitIsDead(id) then
				local hp, maxHp = Spring.GetUnitHealth(id)
				if hp and maxHp and hp < maxHp then
					Spring.SetUnitHealth(id, math.min(maxHp, hp + maxHp * REGEN))
				end
			end
		end
	end
	if n % 15 == 0 then
		takeRadars(15)
		A.update(n)
		for _, p in ipairs(players) do
			if p.respawnAt and n >= p.respawnAt and not p.out then
				spawn(p)
			end
			if p.giftAt and n - p.giftAt >= GIFT_WAIT then
				giveGift(p, 0) -- (no choice: a random gift)
			end
		end
		local due = {}
		for _, f in ipairs(wildDue) do
			if n >= f then
				spawnWild()
			else
				due[#due + 1] = f
			end
		end
		wildDue = due
		-- Gates of Hell: new volleys, launch what is due, show the rings of the next ones
		gatesStep(n)
		hellStep(n)
		heavenStep(n)
		local left, rings = {}, {}
		for _, nk in ipairs(nukes) do
			if n >= nk.frame then
				launch(nk)
			else
				left[#left + 1] = nk
				if nk.frame - n <= NUKE_WARN and #rings < 250 then
					rings[#rings + 1] = nk.x .. "," .. nk.z
				end
			end
		end
		nukes = left
		Spring.SetGameRulesParam("evoNukes", table.concat(rings, "/"))
		Spring.SetGameRulesParam("evoArmageddon", armaFrame)
		Spring.SetGameRulesParam("evoHero", hero)
	end
	if n % 90 == 45 then
		for _, p in ipairs(players) do
			if p.ai and p.unit and Spring.ValidUnitID(p.unit) then
				steer(p)
			end
		end
		steerSummoned()
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	summoned[unitID] = nil
	if hellOf[unitID] then
		hellOf[unitID].pending = hellOf[unitID].pending + 1 -- (a lost unit of Hell on Earth is replaced)
		hellOf[unitID] = nil
	end
	if heavenOf[unitID] then
		heavenOf[unitID].pending = heavenOf[unitID].pending + 1
		heavenOf[unitID] = nil
	end
	radars[unitID] = nil
	if removing[unitID] then
		removing[unitID] = nil
		return
	end
	local victim, wasWild = owner[unitID], wild[unitID]
	owner[unitID], wild[unitID] = nil, nil
	if not (victim or wasWild) then
		return
	end
	local killer = attackerTeam and byTeam[attackerTeam]
	if killer and killer ~= victim and (wasWild or enemies(killer, victim)) then
		if not wasWild then
			killer.kills = killer.kills + 1
			killer.exp = (killer.exp or 0) + EXP_STEP -- (the experience of the unit: kept when the unit evolves)
			if killer.unit and Spring.ValidUnitID(killer.unit) then
				Spring.SetUnitExperience(killer.unit, killer.exp)
			end
		end
		-- catching up: a player below the best one gets more (R.CATCH_UP per stage below it)
		local best = killer.stage
		for _, q in ipairs(players) do
			if not q.out and q.stage > best then
				best = q.stage
			end
		end
		local base = wasWild and wildWorth(wasWild.stage) or worth(victim.stage, killer.stage)
		gain(killer, math.floor(base * (1 + R.CATCH_UP * (best - killer.stage)) + 0.5))
	end
	if wasWild then
		wildDue[#wildDue + 1] = Spring.GetGameFrame() + WILD_BACK
		return
	end
	victim.unit, victim.xp = nil, 0
	victim.deaths = victim.deaths + 1
	victim.exp = math.max(0, (victim.exp or 0) - EXP_STEP) -- (a death costs the same experience)
	A.lose(victim) -- the abilities are gone with the unit
	A.publish()
	if armageddon then
		-- no respawn any more: the player is out, the units of its gifts go with it
		victim.out = true
		victim.giftAt = nil
		freeRadars(victim)
		setCoalition() -- (when the last player on level 10 is out, the alliance against level 10 ends)
		for id, p in pairs(summoned) do
			if p == victim then
				summoned[id] = nil
				if Spring.ValidUnitID(id) then
					Spring.DestroyUnit(id, true, false)
				end
			end
		end
		say(victim.name .. " is out.")
	else
		victim.stage = math.max(1, victim.stage - 1)
		victim.respawnAt = Spring.GetGameFrame() + RESPAWN
	end
	publish()
	checkWin()
end

-- The gift of a player on stage 10: "evo|gift|<1..3>" from the game widget evo_gift.lua of that player
-- debug mode (the star button) and the test hook: random values for every player that is in (level 1 to 9 with its unit, points, power-ups, experience, kills
-- and deaths), so the overview can be photographed
local function randomize()
	for _, q in ipairs(players) do
		if not q.out and q.unit and Spring.ValidUnitID(q.unit) then
			q.stage, q.xp = math.random(1, STAGES - 1), 0
			q.xp = math.random(0, math.max(0, need(q.stage) - 1))
			q.exp = math.random(0, 15) / 10
			q.kills, q.deaths = math.random(0, 14), math.random(0, 9)
			q.abilities = {}
			for i = 1, #ABILITIES do
				q.abilities[i] = math.random() < 0.5
			end
			evolve(q)
			Spring.SetUnitExperience(q.unit or -1, q.exp)
		end
	end
	A.publish()
	publish()
end

local test = {} -- (test only)
function gadget:RecvLuaMsg(msg, playerID)
	local kind, n = msg:match("^evo|(%a+)|(%d+)$")
	if kind == "test" and (Spring.GetModOptions() or {}).lanevotest == "1" then
		-- test only (game option lanevotest=1): "evo|test|1" gives the player all abilities, "evo|test|2" logs whether its unit is cloaked
		local _, _, _, team = Spring.GetPlayerInfo(playerID, false)
		local p = team and byTeam[team]
		if p and n == "1" then
			p.abilities = {}
			for i = 1, #ABILITIES do p.abilities[i] = true end
			A.publish()
		elseif p and n == "5" then
			randomize()
		elseif p and p.unit and n == "4" then
			gain(p, 1000000) -- (level 10 at once: Armageddon, for the pictures of the manual)
		elseif p and p.unit and n == "3" then
			-- an enemy unit next to the player's unit sees it (or not, when it is hidden)
			local x, _, z = Spring.GetUnitPosition(p.unit)
			for _, q in ipairs(players) do
				if q.ally ~= p.ally then
					test.spy = Spring.CreateUnit("armpw", x + 120, Spring.GetGroundHeight(x + 120, z), z, 0, q.team)
					test.spyAlly = Spring.GetTeamAllyTeamID(q.team)
					Spring.SetGameRulesParam("evoTestSpy", test.spy or 0, { public = true })
					break
				end
			end
		elseif p and p.unit then
			local ud = UnitDefs[Spring.GetUnitDefID(p.unit)]
			local los = test.spy and Spring.GetUnitLosState(p.unit, test.spyAlly, false)
			Spring.Echo("[Evolution] test: spy " .. tostring(test.spy) .. " sees " .. (los and ("los " .. tostring(los.los) .. " radar " .. tostring(los.radar)) or "?") .. " | " .. ud.name .. " canCloak " .. tostring(ud.canCloak) .. " cloaked " .. tostring(Spring.GetUnitIsCloaked(p.unit)) .. " stealth " .. tostring(Spring.GetUnitStealth and Spring.GetUnitStealth(p.unit)))
		end
		return true
	end
	if kind == "debug" and (Spring.GetModOptions() or {}).lanevodebug == "1" then
		-- debug mode: 1 = Armageddon (level 10 at once), 2 = one level up (level 10 brings Armageddon), 3 = one level down (not below 1), 4 = XP up, 5 = XP down (0.1 each), 6 to 10 = that power-up
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		local p = team and not spec and byTeam[team]
		if p and not p.out and p.unit then
			if n == "11" then
				randomize() -- (the star button)
			elseif tonumber(n) >= 6 and ABILITIES[tonumber(n) - 5] then
				p.abilities = p.abilities or {}
				local ai = tonumber(n) - 5 -- (the power-up buttons of the debug mode: the ability, and when it is there already, ready again: no cooldown)
				p.abilities[ai] = true
				if p.cool then
					p.cool[ai] = nil
				end
				A.publish()
			elseif n == "4" or n == "5" then
				p.exp = math.max(0, (p.exp or 0) + (n == "4" and EXP_STEP or -EXP_STEP)) -- (XP up / down)
				Spring.SetUnitExperience(p.unit, p.exp)
				publish()
			elseif n == "1" or n == "2" then
				if p.stage < STAGES then
					gain(p, n == "1" and 1000000 or need(p.stage))
				end
			elseif p.stage > 1 then
				p.stage, p.xp = p.stage - 1, 0
				evolve(p)
				publish()
			end
		end
		return true
	end
	if kind ~= "gift" and kind ~= "use" then
		return false
	end
	local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
	local p = team and not spec and byTeam[team]
	if p and kind == "gift" then
		giveGift(p, tonumber(n))
	elseif p then
		A.use(p, tonumber(n)) -- a button of the bar of abilities (the unsynced part)
	end
	return true
end

-- orders that only switch a state: they stay allowed for every unit
local STATES = { [CMD_FIRE_STATE] = true, [CMD_MOVE_STATE] = true, [CMD.REPEAT] = true, [CMD.IDLEMODE] = true }

-- The unit of a player cannot destroy itself (it would come back elsewhere at once) and is not given away; the units of a computer team only take the
-- orders of this gadget (the AI of the team would steer them otherwise)
function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	local p = owner[unitID] or summoned[unitID]
	if not p then
		return true
	end
	if cmdID == CMD.SELFD and owner[unitID] then
		return false
	end
	-- (measured: the orders of BARb come with player 0 and fromSynced true, the orders of this gadget with player -1 and fromLua true)
	if p.ai and not (fromLua and (playerID or -1) < 0) and not STATES[cmdID] then
		return false
	end
	return true
end

function gadget:AllowUnitTransfer(unitID)
	return not owner[unitID]
end

-- the radars cannot be destroyed (also not by the missiles of Gates of Hell); a wild tower does only R.TOWER_DAMAGE of its damage
function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID)
	local hurt = owner[unitID]
	if hurt and damage > 0 then
		hurt.hurtAt = Spring.GetGameFrame() -- (the regeneration waits REGEN_WAIT after the last hit)
	end
	if radars[unitID] then
		return 0, 0
	end
	local w = attackerID and wild[attackerID]
	if w and w.tower then
		return damage * R.TOWER_DAMAGE, 1
	end
end

function gadget:Initialize()
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- otherwise the engine registers it and warns
	end
	Spring.SetGameRulesParam("evoState", "")
	Spring.SetGameRulesParam("evoArmageddon", 0)
	Spring.SetGameRulesParam("evoNukes", "")
	Spring.SetGameRulesParam("evoTaking", "")
	Spring.SetGameRulesParam("evoBeacons", "")
end
