-- Reclaim the Fame (synchronized part): crystals stand on the map (the features pilha_crystal1/2/3 in every color, placed with the Level Editor).
-- A crystal is a reclaim node: it can be reclaimed but never loses anything, it gives no resources and is never used up. A mobile construction
-- unit that is reclaiming a node earns points for its ally team: 1 point per second for every 100 build power, times the rate and times the factor
-- of the crystal (small, medium, large). The first ally team that reaches the score limit wins. Rings, minimap markers and the score are drawn by
-- this gadget, so a finished scenario needs no widget.
-- Configuration: from the Level Editor with the message "rtf|start|<payload>" (stop: "rtf|stop"), or from the game option
-- rtfconfig (same payload as base64url) for a finished scenario. Payload, fields separated by ";":
--   rate;score;f1;f2;f3;visible;cats
--   rate    = percent of the basic rate (100 = 1 point per second for every 100 build power), 1 to 10000
--   score   = points an ally team needs to win (0 = never ends)
--   f1..f3  = factor in percent of a small (pilha_crystal1), medium (2) and large (3) crystal: the digit at the end of the name of the feature
--   visible = 1 (default) | 0: the crystals are drawn on the minimap and seen on the whole map, also without radar or a unit in sight
--   cats    = four digits 0 | 1 for the kinds of builder that earn points: buildings (nano turrets), ground (bots, vehicles, hovercraft, amphibious),
--             ships (surface ships and submarines), air (builder aircraft, seaplanes); default "0110": ground and ships
-- Every feature of the map whose name is pilha_crystal[_color]<1|2|3> is a node (those placed by the editor, but also those of the map).
-- State for the display: game rules parameters rtfState ("", "running", "won by alliance N"), rtfScore<ally>, rtfRate<ally> (points per second now),
-- rtfTarget, rtfTeams (ally team ids), rtfOut (lost), rtfNodes ("x,z,size,factor in percent/..."), rtfVisible (1/0).
function gadget:GetInfo()
	return {
		name = "Reclaim the Fame",
		desc = "Crystals that award score points to the construction units that reclaim them",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local CATEGORIES = { "static", "ground", "ship", "air" } -- the order of the digits of cats
local REACH = 130 -- reclaim range of an ordinary construction unit (Elmo): the ring around a node reaches that far from its edge

-- 1, 2 or 3 for the name of a crystal feature; nil for every other feature
local function crystalSize(name)
	local d = tostring(name):match("^pilha_crystal[%a_]*([123])$")
	return d and tonumber(d) or nil
end

if not gadgetHandler:IsSyncedCode() then
	-- ---------------------------------------------------------------- unsynced: rings on the ground, minimap and the score
	-- the nodes of the game rules text "x,z,size,factor/..."; it changes only at the start, so the list is kept (drawn every frame)
	local lastText, lastList = nil, {}
	local function list(text)
		text = tostring(text or "")
		if text ~= lastText then
			lastText, lastList = text, {}
			for x, z, s, f in text:gmatch("(-?[%d%.]+),(-?[%d%.]+),(%d),(%d+)") do
				lastList[#lastList + 1] = { tonumber(x), tonumber(z), tonumber(s), tonumber(f) }
			end
		end
		return lastList
	end

	-- gold ring of the area from which a construction unit reaches the node
	function gadget:DrawWorldPreUnit()
		local state = Spring.GetGameRulesParam("rtfState")
		if not state or state == "" then
			return
		end
		gl.DepthTest(false)
		for pass = 1, 2 do
			gl.LineWidth(pass == 1 and 3 or 1.5)
			gl.Color(1, 0.8, 0.2, pass == 1 and 0.85 or 0.45)
			for _, p in ipairs(list(Spring.GetGameRulesParam("rtfNodes"))) do
				gl.DrawGroundCircle(p[1], Spring.GetGroundHeight(p[1], p[2]), p[2], (pass == 1 and 1 or 0.5) * (REACH + 12 * p[3]), 40)
			end
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
	end

	-- One number above every crystal: its points factor ("x5" = 5 points per second for every 100 build power at the basic rate)
	function gadget:DrawWorld()
		local state = Spring.GetGameRulesParam("rtfState")
		if not state or state == "" then
			return
		end
		gl.DepthTest(false)
		gl.Color(1, 0.85, 0.3, 1)
		for _, p in ipairs(list(Spring.GetGameRulesParam("rtfNodes"))) do
			gl.PushMatrix()
			gl.Translate(p[1], Spring.GetGroundHeight(p[1], p[2]) + 45 + 20 * p[3], p[2])
			gl.Billboard()
			gl.Text(string.format("x%g", p[4] / 100), 0, 0, 34, "co")
			gl.PopMatrix()
		end
		gl.Color(1, 1, 1, 1)
	end

	-- Marker of every node on the minimap (gold diamond, bigger for bigger crystals); see ctf_game.lua for why this is drawn from DrawScreenPost
	local function drawMiniMap(px, py, sx, sy)
		local mapX, mapZ = Game.mapSizeX, Game.mapSizeZ
		local unit = mapX / sx
		gl.PushMatrix()
		gl.Translate(px, py + sy, 0)
		gl.Scale(sx / mapX, -sy / mapZ, 1)
		local always = Spring.GetGameRulesParam("rtfVisible") == 1
		local _, fullView = Spring.GetSpectatingState()
		local ally = Spring.GetMyAllyTeamID()
		for _, p in ipairs(list(Spring.GetGameRulesParam("rtfNodes"))) do
			local x, z = p[1], p[2]
			local los = always or fullView
			if not los then
				local y = Spring.GetGroundHeight(x, z)
				los = Spring.IsPosInLos(x, y, z, ally) or Spring.IsPosInRadar(x, y, z, ally)
			end
			if los then
				local h = (3 + 2 * p[3]) * unit
				gl.Color(0, 0, 0, 1)
				gl.BeginEnd(GL.QUADS, function()
					gl.Vertex(x, z - h - unit); gl.Vertex(x + h + unit, z); gl.Vertex(x, z + h + unit); gl.Vertex(x - h - unit, z)
				end)
				gl.Color(1, 0.8, 0.2, 1)
				gl.BeginEnd(GL.QUADS, function()
					gl.Vertex(x, z - h); gl.Vertex(x + h, z); gl.Vertex(x, z + h); gl.Vertex(x - h, z)
				end)
			end
		end
		gl.Color(1, 1, 1, 1)
		gl.PopMatrix()
	end

	function gadget:DrawScreenPost()
		local state = Spring.GetGameRulesParam("rtfState")
		if not state or state == "" then
			return
		end
		local mx, my, msx, msy = Spring.GetMiniMapGeometry()
		if mx and msx and msx > 0 then
			drawMiniMap(mx, my, msx, msy)
		end
	end

	function gadget:DrawScreen()
		local state = Spring.GetGameRulesParam("rtfState")
		if not state or state == "" then
			return
		end
		local vsx, vsy = Spring.GetViewGeometry()
		local target = Spring.GetGameRulesParam("rtfTarget") or 0
		local parts = {}
		for a in tostring(Spring.GetGameRulesParam("rtfTeams") or ""):gmatch("%d+") do
			local lost = (("," .. tostring(Spring.GetGameRulesParam("rtfOut") or "") .. ","):find("," .. a .. ",", 1, true)) and " (lost)" or ""
			parts[#parts + 1] = string.format("Alliance %s: %d%s (+%.1f/s)%s", a, Spring.GetGameRulesParam("rtfScore" .. a) or 0, target > 0 and ("/" .. target) or "",
				Spring.GetGameRulesParam("rtfRate" .. a) or 0, lost)
		end
		local text = "Reclaim the Fame   " .. table.concat(parts, "   ")
		if state ~= "running" then
			text = text .. "   (" .. state .. ")"
		end
		gl.Color(1, 0.85, 0.3, 1)
		gl.Text(text, vsx * 0.5, vsy - 175, 20, "co") -- lower than the line of Capture the Flag: the chat lines at the top would cover it
		gl.Color(1, 1, 1, 1)
	end
	return
end

-- ---------------------------------------------------------------- synced
local FPS = 30
local ACTIVE_FRAMES = 3 -- a builder counts as reclaiming for this many frames after the last reclaim step the engine reported

local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST) -- what the gadgets of the editor share (led_gadgets.lua)
local EDITOR_MODE = G.EDITOR_MODE

local g = nil -- running game: nil = none
local pendingCfg = nil -- configuration waiting for the start (finished scenario)
local START_FRAME = 30 -- finished scenario: starts this frame (the features of the scenario exist by then)
local nodeSet = {} -- featureID -> factor (1 = basic rate): the nodes
local reclaiming = {} -- builder unitID -> { frame of its last reclaim step on a node, factor of that node }

local say = G.sayer("Reclaim the Fame")

local function parse(payload)
	local f = G.fields(payload)
	local function pct(v, default)
		return math.max(0, math.min(100000, tonumber(v) or default)) / 100
	end
	local cfg = {
		rate = math.max(1, math.min(10000, tonumber(f[1]) or 100)), score = math.max(0, tonumber(f[2]) or 0),
		factor = { pct(f[3], 100), pct(f[4], 200), pct(f[5], 400) }, visible = f[6] ~= "0", cats = {},
	}
	local digits = tostring(f[7] or "") ~= "" and f[7] or "0110"
	for i, name in ipairs(CATEGORIES) do
		cfg.cats[name] = digits:sub(i, i) == "1"
	end
	return cfg
end

local allyOf = G.allyOf

local function publish()
	if not g then
		Spring.SetGameRulesParam("rtfState", "")
		return
	end
	local teams = {}
	for _, a in ipairs(g.teams) do
		teams[#teams + 1] = a
		Spring.SetGameRulesParam("rtfScore" .. a, math.floor(g.score[a] or 0))
		Spring.SetGameRulesParam("rtfRate" .. a, g.rate[a] or 0)
	end
	Spring.SetGameRulesParam("rtfState", g.state)
	Spring.SetGameRulesParam("rtfTarget", g.cfg.score)
	Spring.SetGameRulesParam("rtfTeams", table.concat(teams, ","))
	local out = {}
	for a in pairs(g.out) do
		out[#out + 1] = a
	end
	Spring.SetGameRulesParam("rtfOut", table.concat(out, ","))
end

local function clear()
	if g then
		for id, saved in pairs(g.saved) do
			if Spring.ValidFeatureID(id) then
				Spring.SetFeatureResources(id, saved[1], saved[2], saved[3], 1) -- the resources the game shows on the crystal come back
				if Spring.SetFeatureAlwaysVisible then
					Spring.SetFeatureAlwaysVisible(id, false)
				end
			end
		end
	end
	g, nodeSet, reclaiming = nil, {}, {}
	Spring.SetGameRulesParam("rtfNodes", "")
end

local function stop()
	if g then
		clear()
		publish()
		say("Stopped.")
	end
end

local function blowUp(ally)
	for _, t in ipairs(G.teamsOfAlliance(ally)) do
		for _, id in ipairs(Spring.GetTeamUnits(t)) do
			Spring.DestroyUnit(id, true, false)
		end
	end
end

-- The level is won: every ally team that is not the winner loses (its units blow up)
local function finish(ally)
	g.state = "won by alliance " .. ally
	for _, a in ipairs(g.teams) do
		if a ~= ally and not g.out[a] then
			g.out[a] = true
			blowUp(a)
		end
	end
	publish()
	say("Alliance " .. ally .. " has " .. g.cfg.score .. " points: level won!")
	if not EDITOR_MODE then
		Spring.GameOver({ ally })
	end
end

local function start(cfg)
	clear()
	local gaia = Spring.GetGaiaTeamID()
	g = { cfg = cfg, state = "running", score = {}, rate = {}, out = {}, teams = {}, count = { 0, 0, 0 }, saved = {} }
	local seen = {}
	for _, t in ipairs(Spring.GetTeamList()) do
		local a = allyOf(t)
		if t ~= gaia and not seen[a] and #(Spring.GetTeamUnits(t) or {}) > 0 then -- an alliance without units takes no part (the editor game has ten teams)
			seen[a] = true
			g.teams[#g.teams + 1] = a
			g.score[a] = 0
			g.rate[a] = 0
		end
	end
	table.sort(g.teams)
	local pos = {}
	local found = {}
	for _, id in ipairs(Spring.GetAllFeatures()) do
		local fd = FeatureDefs[Spring.GetFeatureDefID(id)]
		local size = fd and crystalSize(fd.name)
		if size then
			found[#found + 1] = { id = id, name = fd.name, size = size }
		end
	end
	for _, c in ipairs(found) do
		local x, y, z = Spring.GetFeaturePosition(c.id)
		local heading = Spring.GetFeatureHeading(c.id)
		local rm, _, re, _, _, rt = Spring.GetFeatureResources(c.id)
		-- BAR's reclaim fields show the metal and energy of a reclaimable feature on it (two numbers), read when the feature is created and
		-- ignored below 9: the crystal pays nothing, so it is made again with 0 of both (the number on it is our own: the points factor)
		Spring.DestroyFeature(c.id)
		local id = Spring.CreateFeature(c.name, x, y, z, heading) or nil
		if id then
			if GG.LevelEditor and GG.LevelEditor.replaceFid then
				GG.LevelEditor.replaceFid(c.id, id) -- in the editor: undo and redo find the crystal under its new ID
			end
			Spring.SetFeatureResources(id, 0, 0, rt, 1)
			g.saved[id] = { rm, re, rt }
			nodeSet[id] = cfg.factor[c.size]
			g.count[c.size] = g.count[c.size] + 1
			if cfg.visible and Spring.SetFeatureAlwaysVisible then
				Spring.SetFeatureAlwaysVisible(id, true)
			end
			pos[#pos + 1] = string.format("%d,%d,%d,%d", x, z, c.size, math.floor(cfg.factor[c.size] * 100 + 0.5))
		end
	end
	local total = g.count[1] + g.count[2] + g.count[3]
	if total == 0 then
		g = nil
		publish()
		say("Cannot start: there are no crystals (features pilha_crystal1, 2, 3) on the map. Place some with the Place menu, Features, Crystals.")
		return
	end
	Spring.SetGameRulesParam("rtfNodes", table.concat(pos, "/"))
	Spring.SetGameRulesParam("rtfVisible", cfg.visible and 1 or 0)
	publish()
	say(string.format("Started: %d crystals (%d small, %d medium, %d large), %d%% rate%s%s.", total, g.count[1], g.count[2], g.count[3], cfg.rate,
		cfg.score > 0 and (", " .. cfg.score .. " points win") or "", total % 2 == 0 and ", note: an even number of crystals lets both sides farm in peace" or ""))
end

-- The kind of a builder: "static" (speed 0: nano turrets), "air" (canFly: builder aircraft and seaplanes), "ship" (movement class boat* or uboat*:
-- surface ships and submarines), otherwise "ground" (bots, vehicles, hovercraft, amphibious vehicles)
local function category(ud)
	if (ud.speed or 0) <= 0 then
		return "static"
	end
	if ud.canFly then
		return "air"
	end
	local md = ud.moveDef
	if md and md.name and (md.name:find("^boat") or md.name:find("^uboat")) then
		return "ship"
	end
	return "ground"
end

-- Points per frame of a construction unit at a node with that factor: build power / 100 per second times the rate; nil if it does not count
local function pointsPerFrame(unitID, factor)
	local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
	if not ud or Spring.GetUnitIsDead(unitID) then
		return nil
	end
	if not g.cfg.cats[category(ud)] then
		return nil
	end
	return (ud.buildSpeed or 0) / 100 * (g.cfg.rate / 100) * factor / FPS
end

function gadget:GameFrame(n)
	if pendingCfg and n >= START_FRAME then
		local cfg = pendingCfg
		pendingCfg = nil
		start(cfg)
	end
	if not g or g.state ~= "running" then
		return
	end
	local rate = {}
	for builder, r in pairs(reclaiming) do
		if n - r[1] > ACTIVE_FRAMES or not Spring.ValidUnitID(builder) then
			reclaiming[builder] = nil
		else
			local p = pointsPerFrame(builder, r[2])
			local team = Spring.GetUnitTeam(builder)
			if p and team then
				local a = allyOf(team)
				if g.score[a] ~= nil and not g.out[a] then
					g.score[a] = g.score[a] + p
					rate[a] = (rate[a] or 0) + p * FPS
				end
			end
		end
	end
	if n % 15 == 0 then
		for _, a in ipairs(g.teams) do
			g.rate[a] = math.floor((rate[a] or 0) * 10 + 0.5) / 10
		end
		publish()
	end
	if g.cfg.score > 0 then
		for _, a in ipairs(g.teams) do
			if g.score[a] >= g.cfg.score and g.state == "running" then
				publish()
				finish(a)
			end
		end
	end
	if n % FPS == 0 then
		for a in pairs(g.out) do
			blowUp(a) -- what a lost team builds afterwards blows up too
		end
	end
end

function gadget:UnitDestroyed(unitID)
	reclaiming[unitID] = nil
end

-- A node cannot be used up: every reclaim step of the engine is refused and the reclaim fraction is put back to 1, so the crystal loses nothing
-- and pays nothing; the refused step tells which builder is reclaiming it. Damage does nothing to it either.
function gadget:AllowFeatureBuildStep(builderID, builderTeamID, featureID, featureDefID, part)
	local factor = nodeSet[featureID]
	if factor and part < 0 then
		reclaiming[builderID] = { Spring.GetGameFrame(), factor }
		Spring.SetFeatureReclaim(featureID, 1) -- the engine lowers the reclaim fraction of the feature even when the step is refused; at 0 the reclaim would end
		return false
	end
	return true
end

function gadget:FeaturePreDamaged(featureID)
	if nodeSet[featureID] then
		return 0, 0
	end
end

function gadget:FeatureDestroyed(featureID)
	nodeSet[featureID] = nil
end

local messages = { start = function(payload) start(parse(payload)) end, stop = function() stop() end }

function gadget:RecvLuaMsg(msg, playerID)
	return G.handleMessage("rtf", messages, msg, playerID)
end

function gadget:Initialize()
	Spring.SetGameRulesParam("rtfState", "")
end

-- Finished scenario: the settings come in the game option rtfconfig (the payload as base64url)
function gadget:GamePreload()
	local text = G.option("rtfconfig")
	if text then
		pendingCfg = parse(text)
	end
end
