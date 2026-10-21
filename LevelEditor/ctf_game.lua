-- Capture the Flag (synchronized part): flags lie at flag points on the map, units pick them up by getting close, carry them to the
-- collection point of their team and are paid for it (once, or income per second as long as the flag stays there). The level ends when
-- a team has the wanted number of flags. The flags (silver pod of the scavengers) and the collection points (small nano tower) are real,
-- indestructible, neutral units; rings on the ground and the score are drawn by the unsynced part, so a finished scenario needs no widget.
-- Configuration: from the Level Editor with the message "ctf|start|<payload>" (stop: "ctf|stop"), or from the game option
-- ctfconfig (same payload as base64url) for a finished scenario. Payload, fields separated by ";":
--   mode;reward;amount;radius;score;returnTime;homes;flags
--   mode   = "own" (every team has its own flags, only the other teams take them) | "neutral" (every team may take every flag)
--   reward = "once" (amount of metal for every delivered flag, the flag goes back to its flag point) | "income" (amount of metal per
--            second for every flag a team holds; the delivered flag stays at the collection point)
--   amount = metal, radius = capture radius in Elmo (pick up, deliver, bring back), score = flags a team needs to win (0 = never ends),
--   returnTime = seconds after which a dropped flag lies back at its flag point
--   homes  = "team,x,z/team,x,z/..." collection points, flags = "team,x,z/..." flag points (team -1: neutral)
-- State for the display: game rules parameters ctfState, ctfScore<team>, ctfTarget, ctfTeams, ctfRadius, ctfHomes, ctfSpots.
function gadget:GetInfo()
	return {
		name = "Capture the Flag",
		desc = "Flags, collection points and rewards for capture the flag levels",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local FLAG_UNIT = "lootboxsilver" -- the flag: a pod of the scavengers
local HOME_UNIT = "lootboxnano_t1_var1" -- marks a collection point

if not gadgetHandler:IsSyncedCode() then
	-- ---------------------------------------------------------------- unsynced: rings on the ground and the score
	local function list(text)
		local out = {}
		for t, x, z in tostring(text or ""):gmatch("(-?%d+),(-?[%d%.]+),(-?[%d%.]+)") do
			out[#out + 1] = { tonumber(t), tonumber(x), tonumber(z) }
		end
		return out
	end

	local function teamColor(team)
		if team and team >= 0 then
			local r, g, b = Spring.GetTeamColor(team)
			if r then
				return r, g, b
			end
		end
		return 1, 1, 1
	end

	function gadget:DrawWorldPreUnit()
		local state = Spring.GetGameRulesParam("ctfState")
		if not state or state == "" then
			return
		end
		local radius = Spring.GetGameRulesParam("ctfRadius") or 100
		gl.DepthTest(false)
		for pass = 1, 2 do
			gl.LineWidth(pass == 1 and 4 or 2)
			for _, p in ipairs(list(Spring.GetGameRulesParam(pass == 1 and "ctfHomes" or "ctfSpots"))) do
				local r, g, b = teamColor(p[1])
				gl.Color(r, g, b, pass == 1 and 0.95 or 0.6)
				gl.DrawGroundCircle(p[2], Spring.GetGroundHeight(p[2], p[3]), p[3], pass == 1 and radius or radius * 0.5, 40)
			end
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
	end

	function gadget:DrawScreen()
		local state = Spring.GetGameRulesParam("ctfState")
		if not state or state == "" then
			return
		end
		local vsx, vsy = Spring.GetViewGeometry()
		local target = Spring.GetGameRulesParam("ctfTarget") or 0
		local parts = {}
		for t in tostring(Spring.GetGameRulesParam("ctfTeams") or ""):gmatch("%d+") do
			parts[#parts + 1] = string.format("Team %s: %d%s", t, Spring.GetGameRulesParam("ctfScore" .. t) or 0, target > 0 and ("/" .. target) or "")
		end
		local text = "Capture the Flag   " .. table.concat(parts, "   ")
		if state ~= "running" then
			text = text .. "   (" .. state .. ")"
		end
		gl.Color(1, 0.9, 0.5, 1)
		gl.Text(text, vsx * 0.5, vsy - 130, 20, "co")
		gl.Color(1, 1, 1, 1)
	end
	return
end

-- ---------------------------------------------------------------- synced
local FPS = 30
local CHECK_EVERY = 5 -- frames between two checks for pick up and delivery

local opt = Spring.GetModOptions().leveleditor
local EDITOR_MODE = (opt == "1" or opt == 1 or opt == true)

local Rules = VFS.Include("luaui/Include/bar_rules.lua", nil, VFS.ZIP_FIRST)
assert(Rules, "bar_rules.lua missing (run install_editor.bat again)")
local decode64 = Rules.decode64

local g = nil -- running game: nil = none
local pendingCfg = nil -- configuration waiting for the start (finished scenario)
local START_FRAME = 30 -- finished scenario: starts this frame (the units of the scenario exist by then)
local protected = {} -- unitID -> true: flags and collection points
local carrying = {} -- carrier unitID -> flag

local function say(text)
	if Spring.SendMessage then
		Spring.SendMessage("[Capture the Flag] " .. text)
	else
		Spring.Echo("[Capture the Flag] " .. text)
	end
end

local function points(text)
	local out = {}
	for t, x, z in tostring(text or ""):gmatch("(-?%d+),(-?[%d%.]+),(-?[%d%.]+)") do
		out[#out + 1] = { team = tonumber(t), x = tonumber(x), z = tonumber(z) }
	end
	return out
end

local function parse(payload)
	local f = {}
	for p in (tostring(payload) .. ";"):gmatch("([^;]*);") do
		f[#f + 1] = p
	end
	local cfg = {
		own = f[1] ~= "neutral", income = f[2] == "income", amount = tonumber(f[3]) or 0, radius = math.max(10, tonumber(f[4]) or 100),
		score = math.max(0, tonumber(f[5]) or 0), returnTime = math.max(0, tonumber(f[6]) or 30), homes = {}, flags = points(f[8]),
	}
	cfg.homeList = points(f[7])
	for _, h in ipairs(cfg.homeList) do
		cfg.homes[h.team] = h
	end
	if #cfg.homeList == 0 or #cfg.flags == 0 then
		return nil
	end
	return cfg
end

local function allyOf(team)
	return (select(6, Spring.GetTeamInfo(team, false)))
end

local function publish()
	if not g then
		Spring.SetGameRulesParam("ctfState", "")
		return
	end
	local teams, spots = {}, {}
	for _, h in ipairs(g.cfg.homeList) do
		teams[#teams + 1] = h.team
		Spring.SetGameRulesParam("ctfScore" .. h.team, g.score[h.team] or 0)
	end
	Spring.SetGameRulesParam("ctfState", g.state)
	Spring.SetGameRulesParam("ctfTarget", g.cfg.score)
	Spring.SetGameRulesParam("ctfTeams", table.concat(teams, ","))
end

-- A unit that marks a flag or a collection point: neutral (nobody attacks it), indestructible, not saved by the editor
local function body(name, team, x, z)
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, 0, team)
	if id then
		Spring.SetUnitNeutral(id, true)
		Spring.SetUnitNoSelect(id, true)
		Spring.SetUnitRulesParam(id, "tdwave", 1, { public = true })
		protected[id] = true
	end
	return id
end

local function clear()
	if g then
		for _, f in ipairs(g.flags) do
			protected[f.id] = nil
			if Spring.ValidUnitID(f.id) then
				Spring.DestroyUnit(f.id, false, true)
			end
		end
		for _, id in ipairs(g.markers) do
			protected[id] = nil
			if Spring.ValidUnitID(id) then
				Spring.DestroyUnit(id, false, true)
			end
		end
	end
	g, carrying = nil, {}
end

local function stop()
	if g then
		clear()
		publish()
		say("Stopped.")
	end
end

local function finish(team)
	g.state = "won by team " .. team
	publish()
	say("Team " .. team .. " has " .. g.cfg.score .. " flags: level won!")
	if not EDITOR_MODE then
		Spring.GameOver({ allyOf(team) })
	end
end

local function start(cfg)
	clear()
	g = { cfg = cfg, state = "running", flags = {}, markers = {}, score = {}, parked = {} }
	local gaia = Spring.GetGaiaTeamID()
	local spots = {}
	for _, h in ipairs(cfg.homeList) do
		local id = body(HOME_UNIT, h.team, h.x, h.z)
		if id then
			g.markers[#g.markers + 1] = id
		end
		g.score[h.team] = 0
		g.parked[h.team] = 0
	end
	for _, p in ipairs(cfg.flags) do
		local owner = (cfg.own and p.team >= 0) and p.team or -1
		local id = body(FLAG_UNIT, owner >= 0 and owner or gaia, p.x, p.z)
		if id then
			g.flags[#g.flags + 1] = { id = id, owner = owner, hx = p.x, hz = p.z }
			spots[#spots + 1] = string.format("%d,%d,%d", owner, p.x, p.z)
		end
	end
	local homes = {}
	for _, h in ipairs(cfg.homeList) do
		homes[#homes + 1] = string.format("%d,%d,%d", h.team, h.x, h.z)
	end
	Spring.SetGameRulesParam("ctfHomes", table.concat(homes, "/"))
	Spring.SetGameRulesParam("ctfSpots", table.concat(spots, "/"))
	Spring.SetGameRulesParam("ctfRadius", cfg.radius)
	publish()
	say(string.format("Started: %d flags, %d collection points, %s%s.", #g.flags, #cfg.homeList, cfg.income and ("income " .. cfg.amount .. " metal per second per flag") or (cfg.amount .. " metal per flag"),
		cfg.score > 0 and (", " .. cfg.score .. " flags win") or ""))
end

local function toHome(f)
	f.carrier, f.dropped = nil, nil
	Spring.SetUnitPosition(f.id, f.hx, f.hz)
end

local function deliver(f, team)
	local cfg = g.cfg
	carrying[f.carrier] = nil
	f.carrier = nil
	g.score[team] = (g.score[team] or 0) + 1
	if cfg.income then
		-- the flag stays at the collection point and pays every second
		f.parked = team
		g.parked[team] = g.parked[team] + 1
		local h = cfg.homes[team]
		local a = g.parked[team] * 2.4
		Spring.SetUnitPosition(f.id, h.x + math.cos(a) * 60, h.z + math.sin(a) * 60)
		say(string.format("Team %d holds a flag (%d): +%d metal per second each.", team, g.parked[team], cfg.amount))
	else
		Spring.AddTeamResource(team, "metal", cfg.amount)
		toHome(f)
		say(string.format("Team %d delivered a flag (%d): +%d metal.", team, g.score[team], cfg.amount))
	end
	publish()
	if cfg.score > 0 and g.score[team] >= cfg.score then
		finish(team)
	end
end

local function canCarry(unitID, teamID)
	if protected[unitID] or carrying[unitID] or teamID == Spring.GetGaiaTeamID() then
		return false
	end
	local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
	return ud and (ud.speed or 0) > 0 and not ud.isBuilding
end

local function check(n)
	local cfg = g.cfg
	local r2 = cfg.radius * cfg.radius
	for _, f in ipairs(g.flags) do
		if not f.parked then
			if f.carrier then
				-- delivery: the carrier is within the radius of the collection point of its team
				local team = Spring.GetUnitTeam(f.carrier)
				local h = team and cfg.homes[team]
				local x, _, z = Spring.GetUnitPosition(f.carrier)
				if h and x and (x - h.x) ^ 2 + (z - h.z) ^ 2 <= r2 then
					deliver(f, team)
				end
			else
				if f.dropped and n - f.dropped >= cfg.returnTime * FPS then
					say("A dropped flag went back to its flag point.")
					toHome(f)
				end
				local x, _, z = Spring.GetUnitPosition(f.id)
				if x then
					for _, u in ipairs(Spring.GetUnitsInCylinder(x, z, cfg.radius)) do
						local team = Spring.GetUnitTeam(u)
						if team and canCarry(u, team) then
							if cfg.own and f.owner >= 0 and allyOf(team) == allyOf(f.owner) then
								if f.dropped then
									say("Team " .. team .. " brought its flag back.")
									toHome(f)
								end
							else
								f.carrier, f.dropped = u, nil
								carrying[u] = f
								say("Team " .. team .. " took a flag.")
								break
							end
						end
					end
				end
			end
		end
	end
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
	for _, f in ipairs(g.flags) do
		if f.carrier then
			local x, _, z = Spring.GetUnitPosition(f.carrier)
			if x then
				Spring.SetUnitPosition(f.id, x, z) -- the flag follows the carrier
			end
		end
	end
	if n % CHECK_EVERY == 0 then
		check(n)
	end
	if g.cfg.income and n % FPS == 0 and g.cfg.amount > 0 then
		for team, count in pairs(g.parked) do
			if count > 0 then
				Spring.AddTeamResource(team, "metal", g.cfg.amount * count)
			end
		end
	end
end

function gadget:UnitDestroyed(unitID)
	protected[unitID] = nil
	local f = carrying[unitID]
	if f then
		carrying[unitID] = nil
		f.carrier = nil
		f.dropped = Spring.GetGameFrame() -- the flag lies where the carrier died
		say("A flag was dropped.")
	end
end

-- Flags and collection points cannot be taken apart: no damage, no reclaim, capture or self destruction
function gadget:UnitPreDamaged(unitID)
	if protected[unitID] then
		return 0, 0
	end
end

function gadget:AllowUnitBuildStep(builderID, builderTeamID, unitID, unitDefID, part)
	if part < 0 and protected[unitID] then
		return false -- reclaiming
	end
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	if (cmdID == CMD.RECLAIM or cmdID == CMD.CAPTURE) and cmdParams and #cmdParams == 1 and cmdParams[1] < Game.maxUnits and protected[cmdParams[1]] then
		return false
	end
	if cmdID == CMD.SELFD and protected[unitID] then
		return false
	end
	return true
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 4) ~= "ctf|" then
		return
	end
	if not (Spring.IsCheatingEnabled() or EDITOR_MODE) then
		return true
	end
	local cmd, payload = msg:match("^ctf|(%a+)|?(.*)$")
	if cmd == "start" then
		local cfg = parse(payload)
		if cfg then
			start(cfg)
		else
			say("Cannot start: place at least one collection point and one flag point first.")
		end
	elseif cmd == "stop" then
		stop()
	end
	return true
end

function gadget:Initialize()
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- otherwise the engine registers it and warns
	end
	Spring.SetGameRulesParam("ctfState", "")
end

-- Finished scenario: the settings come in the game option ctfconfig (the payload as base64url)
function gadget:GamePreload()
	local mo = Spring.GetModOptions()
	if mo.ctfconfig and mo.ctfconfig ~= "" then
		pendingCfg = parse(decode64(mo.ctfconfig))
	end
end
