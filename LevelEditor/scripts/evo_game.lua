-- Evolution (synchronized part), a game mode of LAN Play on any map: the room's button Evo (menu LAN Play) sets the game option lanevolution=1. Every
-- team that starts with a commander gets one weak unit instead (stage 1) and nothing else. Kills give points; with enough points the unit is replaced by a
-- unit of the next stage (10 stages, the last one a big tier 3 unit), of a random faction each time. A destroyed unit comes back after 5 s at a random
-- place, one stage lower. Every unit spawns on the land the commanders stand on (one connected piece of land: everybody can reach everybody). Wild units
-- (stage 1 units of Gaia with little health) stand around the map; they only shoot back. Computer players (teams without a human) are steered by this
-- gadget: their unit attacks only enemies of its own stage or higher and otherwise only shoots back; the orders of the AI itself are dropped.
-- Armageddon: the first unit on stage 10 ends the fog of war for everybody, and from then on a lost unit does not come back; the last alliance standing
-- wins. Every player who reaches stage 10 chooses a gift (window of the game widget evo_gift.lua, message "evo|gift|<n>"; a computer player chooses at
-- once, a human after 30 s at the latest): 1 Hell on Earth (strong ground units rise all over the map, they belong to the player), 2 Heaven on Earth
-- (gunships come down around the player's unit), 3 Gates of Hell (nuclear missiles rain on the map, far from the player's unit).
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

	local function teamName(team)
		local _, leader, _, isAI = Spring.GetTeamInfo(team, false)
		if isAI then
			local _, name = Spring.GetAIInfo(team)
			return (name and name ~= "") and name or ("AI " .. team)
		end
		local name = leader and Spring.GetPlayerInfo(leader, false)
		return (name and name ~= "") and name or ("Team " .. team)
	end

	function gadget:DrawScreen()
		local state = Spring.GetGameRulesParam("evoState") or ""
		if state == "" then
			return
		end
		local vsx, vsy = Spring.GetViewGeometry()
		local mine = Spring.GetMyTeamID()
		local y = vsy - 130
		local arma = Spring.GetGameRulesParam("evoArmageddon") or 0
		gl.Color(1, 0.9, 0.5, 1)
		gl.Text("Evolution" .. (arma > 0 and "   -   ARMAGEDDON" or "") .. (state ~= "running" and ("   (" .. state .. ")") or ""), vsx * 0.5, y, 20, "co")
		for t in tostring(Spring.GetGameRulesParam("evoTeams") or ""):gmatch("%d+") do
			local team = tonumber(t)
			y = y - 20
			local function p(k) return Spring.GetTeamRulesParam(team, k) or 0 end
			local unit = Spring.GetTeamRulesParam(team, "evoName") or ""
			local need = p("evoNeed")
			local text
			if p("evoOut") == 1 then
				text = string.format("%s: out   kills %d   deaths %d", teamName(team), p("evoKills"), p("evoDeaths"))
			else
				text = string.format("%s: stage %d/10 %s   %s   kills %d   deaths %d", teamName(team), p("evoStage"), NAMES[unit] or unit,
					need > 0 and string.format("points %d/%d", p("evoXp"), need) or "top stage", p("evoKills"), p("evoDeaths"))
			end
			if team == mine then
				gl.Color(1, 1, 1, 1)
			else
				local r, g, b = Spring.GetTeamColor(team)
				gl.Color(r or 1, g or 1, b or 1, 1)
			end
			gl.Text(text, vsx * 0.5, y, 16, "co")
		end
		-- the first 10 seconds of Armageddon: big letters above the middle of the screen (above the window of the gift)
		if arma > 0 and Spring.GetGameFrame() - arma < 300 then
			gl.Color(1, 0.25, 0.15, 1)
			gl.Text("ARMAGEDDON IS HERE", vsx * 0.5, vsy * 0.76, 56, "co")
			gl.Color(1, 0.85, 0.6, 1)
			gl.Text(tostring(Spring.GetGameRulesParam("evoHero") or "") .. " reached stage 10. The fog of war is gone: everybody sees everybody.", vsx * 0.5, vsy * 0.76 - 50, 24, "co")
			gl.Text("A lost unit does not come back any more. The last one standing wins.", vsx * 0.5, vsy * 0.76 - 82, 24, "co")
		end
		gl.Color(1, 1, 1, 1)
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
local WILD_HP = 0.1 -- health of a wild unit (part of the normal)
local START_AFTER, START_UNTIL = 30, 900 -- frames: the commanders are looked for from START_AFTER on (BAR creates them at the start), new ones until START_UNTIL
local CMD_FIRE_STATE, CMD_MOVE_STATE = CMD.FIRE_STATE, CMD.MOVE_STATE
local RETURN_FIRE, HOLD_POSITION = 1, 0
local CELL = 128 -- size of a cell of the land grid in Elmo
local GIFT_WAIT = 30 * FPS -- a human who does not choose a gift gets a random one after this time
local HELL_UNITS, HEAVEN_UNITS = 8, 8 -- units of the gifts Hell on Earth and Heaven on Earth
local NUKES, NUKE_GAP, NUKE_WARN, NUKE_SAFE = 12, 4 * FPS, 5 * FPS, 1600 -- Gates of Hell: missiles, frames between two, warning ring before, distance to the player's unit

-- The ladders: stage 1 to 10 per faction, ordered by damage per second times health (the strength in a fight of one against one); the last stage is
-- the biggest walking unit of the faction. Artillery, units for water and the bomb bots are left out. Every spawn takes a random faction of those
-- whose unit exists in the game (Legion only with its game option).
local LADDERS = {
	{ "armpw", "armflash", "armwar", "armzeus", "armbull", "armmar", "armmeatball", "armraz", "armthor", "armbanth" },
	{ "corak", "corgator", "corraid", "corpyro", "correap", "corcan", "corshiva", "corkarg", "cordemon", "corkorg" },
	{ "leghades", "legcen", "legkark", "leggat", "legjav", "legaheattank", "leginc", "legkeres", "legeshotgunmech", "legeheatraymech" },
}
local GUNSHIPS = { "armbrawl", "armblade", "armkam", "corape", "corcrw" } -- Heaven on Earth (those that exist in the game)
local GIFT_NAMES = { "Hell on Earth", "Heaven on Earth", "Gates of Hell" }

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
	say("Armageddon is here! " .. p.name .. " reached stage 10. The fog of war is gone: everybody sees everybody.")
	say("From now on a lost unit does not come back. The last one standing wins.")
end

-- ---------------------------------------------------------------- the gifts of stage 10
-- Hell on Earth: strong ground units (stages 6 to 8, random factions) rise at random places of the land, far from the enemies
local function giftHell(p)
	for _ = 1, HELL_UNITS do
		local name = stageUnit(math.random(6, 8))
		local x, z = spawnPoint(UnitDefNames[name].id, false, 900)
		local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, math.random(0, 3), p.team)
		if id then
			summoned[id] = p
		end
	end
end

-- Heaven on Earth: gunships come down around the player's unit
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
	for i = 1, HEAVEN_UNITS do
		local a = i / HEAVEN_UNITS * 2 * math.pi
		local ux = math.max(50, math.min(Game.mapSizeX - 50, x + math.cos(a) * 250))
		local uz = math.max(50, math.min(Game.mapSizeZ - 50, z + math.sin(a) * 250))
		local id = Spring.CreateUnit(options[math.random(1, #options)], ux, Spring.GetGroundHeight(ux, uz) + 300, uz, 0, p.team)
		if id then
			summoned[id] = p
		end
	end
end

-- Gates of Hell: NUKES nuclear missiles, one every NUKE_GAP frames, at random places of the land at least NUKE_SAFE Elmo from the player's unit; a red
-- ring warns NUKE_WARN frames before
local function giftGates(p)
	local first = Spring.GetGameFrame() + NUKE_WARN
	for k = 1, NUKES do
		local x, z
		for _ = 1, 30 do
			x, z = randomLand()
			local px, _, pz = Spring.GetUnitPosition(p.unit or -1)
			if not px or (px - x) ^ 2 + (pz - z) ^ 2 >= NUKE_SAFE ^ 2 then
				break
			end
		end
		nukes[#nukes + 1] = { frame = first + (k - 1) * NUKE_GAP, x = math.floor(x), z = math.floor(z), p = p }
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
	Spring.Echo(string.format("[Evolution] missile at %d,%d: projectile %s", nk.x, nk.z, tostring(ok and id)))
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
		say(p.name .. " reached stage 10 as well.")
	end
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
	owner[old] = nil
	remove(old)
	spawn(p, x, z, facing)
	if p.unit and not p.ai then
		for _, c in ipairs(cmds) do
			pcall(Spring.GiveOrderToUnit, p.unit, c.id, c.params, { "shift" })
		end
	end
	say(string.format("%s evolves to stage %d: %s.", p.name, p.stage, unitTitle(p.unitName)))
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
local function spawnWild()
	local name = stageUnit(1)
	local x, z = spawnPoint(UnitDefNames[name].id)
	local id = Spring.CreateUnit(name, x, Spring.GetGroundHeight(x, z), z, math.random(0, 3), Spring.GetGaiaTeamID())
	if id then
		wild[id] = true
		local _, maxHp = Spring.GetUnitHealth(id)
		local hp = math.max(1, (maxHp or 100) * WILD_HP)
		Spring.SetUnitMaxHealth(id, hp)
		Spring.SetUnitHealth(id, hp)
		Spring.GiveOrderToUnit(id, CMD_FIRE_STATE, { RETURN_FIRE }, 0)
		Spring.GiveOrderToUnit(id, CMD_MOVE_STATE, { HOLD_POSITION }, 0)
	end
end

-- The number of wild units: one per 1024 x 1024 Elmo of the land (a map of 16 x 16 without water has 64), at least 12, at most 100
local function wildCount()
	local area = land and (#land.cells * CELL * CELL) or (Game.mapSizeX * Game.mapSizeZ)
	return math.max(12, math.min(100, math.floor(area / (1024 * 1024) + 0.5)))
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

local function nameOf(team)
	local _, leader, _, isAI = Spring.GetTeamInfo(team, false)
	if isAI then
		local _, name = Spring.GetAIInfo(team)
		return (name and name ~= "") and name or ("AI " .. team)
	end
	local name = leader and Spring.GetPlayerInfo(leader, false)
	return (name and name ~= "") and name or ("Team " .. team)
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
	local p = { team = team, ally = select(6, Spring.GetTeamInfo(team, false)), stage = startStage, xp = 0, kills = 0, deaths = 0, spawns = 1, ai = not hasHuman(team), name = nameOf(team) }
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
	local best, bestD = nearest(x, z, owner, function(q) return q.ally ~= p.ally and (armageddon or q.stage >= p.stage) end)
	if p.stage == 1 and not armageddon then
		local w, wd = nearest(x, z, wild, function() return true end)
		if w and wd < bestD then
			best = w
		end
	end
	if best then
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
			local target = x and nearest(x, z, owner, function(q) return q.ally ~= p.ally end)
			if target then
				attackOrWalk(id, p.ally, target)
			end
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
					say(string.format("Evolution: kill to evolve (10 stages, a random faction each time); a lost unit comes back 5 s later at another place, one stage lower. %d wild units only shoot back. Stage 10 brings Armageddon.", wildCount()))
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
	if n % 15 == 0 then
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
		-- Gates of Hell: launch what is due, show the rings of the next ones
		local left, rings = {}, {}
		for _, nk in ipairs(nukes) do
			if n >= nk.frame then
				launch(nk)
			else
				left[#left + 1] = nk
				if nk.frame - n <= NUKE_WARN then
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
	if killer and killer ~= victim and (wasWild or killer.ally ~= victim.ally) then
		if not wasWild then
			killer.kills = killer.kills + 1
		end
		gain(killer, wasWild and 1 or worth(victim.stage, killer.stage))
	end
	if wasWild then
		wildDue[#wildDue + 1] = Spring.GetGameFrame() + WILD_BACK
		return
	end
	victim.unit, victim.xp = nil, 0
	victim.deaths = victim.deaths + 1
	if armageddon then
		-- no respawn any more: the player is out, the units of its gifts go with it
		victim.out = true
		victim.giftAt = nil
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
function gadget:RecvLuaMsg(msg, playerID)
	local n = msg:match("^evo|gift|(%d)$")
	if not n then
		return false
	end
	local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
	local p = team and not spec and byTeam[team]
	if p then
		giveGift(p, tonumber(n))
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

function gadget:Initialize()
	if gadgetHandler.RegisterAllowCommand then
		gadgetHandler:RegisterAllowCommand(CMD.ANY) -- otherwise the engine registers it and warns
	end
	Spring.SetGameRulesParam("evoState", "")
	Spring.SetGameRulesParam("evoArmageddon", 0)
	Spring.SetGameRulesParam("evoNukes", "")
end
