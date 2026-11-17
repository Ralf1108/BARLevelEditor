-- Renegade, the mode Race (synchronized; loaded by renegade_game.lua with the game option lanrenemode=race, luaui/Include/renegade_race.lua).
-- Every human drives a scout of its choice (RACERS: Tick, Rover, Rascal, Wheelie; all with the same speed, acceleration and turn rate) through CHECKPOINTS checkpoints round
-- the middle of the map, LAPS laps; the first one at the finish wins. Units of players take no damage from each other; the computer teams of the room are removed.
--   track      a grid of the map where every racer can drive (G.fits for each kind of movement, also the middle between two cells), its biggest connected piece; the checkpoints
--              lie on a ring (random turn and size) on that piece, and the way between two of them on the grid may be at most DETOUR times the straight one (the best of TRIES rings)
--   pick       from the track to the start (renRaceGo) every human picks its racer (evo-like cards of the widget: "ren|race|pick|<n>"); a random one until then
--   start      at frame renRaceGo every racer is put onto the start grid next to the last checkpoint; checkpoints count only from then on
--   progress   a player's unit within PASS Elmo of its next checkpoint passes it; after the last one of a lap the next lap begins at the first one
--   results    the first player through the finish wins; the others have FINISH_WAIT; then the list of places (renRaceOver, renRaceResult) with the buttons New race
--              ("ren|race|again": a new track, the pick again, AGAIN_PICK) and Leave ("ren|race|leave": rounds.finish, the game ends)
--   state      game rules renRaceCps ("x,z/x,z/..."), renRaceLaps, renRaceGo (frame of the start), renRaceUnits ("armflea,armfav,..."), renRaceOver (frame of the results, 0 = racing),
--              renRaceResult ("team:time:unit;..." in the order of the places, time 0 = not finished), renRaceNo (the number of the race); team rules renRaceLap (1 based),
--              renRaceCp (the next checkpoint, 1 based), renRacePos (the place), renRaceTime (frames from the start to the finish, 0 = not yet), renRacePick (the racer, 1 based)
-- ctx: units (team -> unit), kind (team -> unit name), giveUnit, turnInto, say(text), rounds, testing. Returns S.
return function(ctx)
	local S = {}
	local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST)
	local CHECKPOINTS, LAPS, PASS, FINISH_WAIT = 8, 2, 140, 30 * 30
	local FIRST_GO, AGAIN_PICK = 20 * 30, 15 * 30 -- (the start of the first race; the time to pick before a new race)
	local TRIES, DETOUR = 14, 1.35 -- (rings tried for a track; the longest way on the grid between two checkpoints, against the steps of a straight way)
	local SPEED = 150 -- (Elmo per second of every racer)
	local RACERS = {}
	for _, name in ipairs({ "armflea", "armfav", "corfav", "legscout" }) do
		if UnitDefNames[name] then RACERS[#RACERS + 1] = name end
	end
	if #RACERS == 0 then RACERS[1] = "armpw" end
	-- the same acceleration and turn rate for all: the middle of the racers
	local ACC, DEC, TURN = 0, 0, 0
	for _, name in ipairs(RACERS) do
		local ud = UnitDefNames[name]
		ACC, DEC, TURN = ACC + (ud.maxAcc or 0), DEC + (ud.maxDec or 0), TURN + (ud.turnRate or 0)
	end
	ACC, DEC, TURN = ACC / #RACERS, DEC / #RACERS, TURN / #RACERS

	local cps = {}
	local state = {} -- team -> { lap, cp, time }
	local pick = {} -- team -> index into RACERS
	local equal = {} -- unit -> true when its movement is set
	local phase, go, raceNo = "wait", FIRST_GO, 0 -- (phase: wait, pick, race, results, leaving)
	local winner, finishAt = nil, nil

	local function humanTeams()
		local list = {}
		for _, team in ipairs(Spring.GetTeamList()) do
			if team ~= Spring.GetGaiaTeamID() then
				for _, p in ipairs(Spring.GetPlayerList(team, true)) do
					local _, _, spec = Spring.GetPlayerInfo(p, false)
					if not spec then list[#list + 1] = team break end
				end
			end
		end
		return list
	end

	local function name(team)
		local _, leader = Spring.GetTeamInfo(team, false)
		local n = leader and Spring.GetPlayerInfo(leader, false)
		return (n and n ~= "") and n or ("Team " .. team)
	end

	-- the grid: cells of CELL Elmo where every racer can drive, the connections to the right and down (the middle between the cells too), the biggest connected piece
	local grid
	local function buildGrid()
		local defs, seen = {}, {}
		for _, n in ipairs(RACERS) do
			local ud = UnitDefNames[n]
			local mv = (ud.moveDef and ud.moveDef.name) or n
			if not seen[mv] then seen[mv] = true; defs[#defs + 1] = ud.id end
		end
		local function ok(x, z)
			for _, id in ipairs(defs) do
				if not G.fits(id, x, z, false, 2) then return false end
			end
			return true
		end
		local cell = math.max(80, math.ceil(math.max(Game.mapSizeX, Game.mapSizeZ) / 120))
		local cols, rows = math.floor(Game.mapSizeX / cell), math.floor(Game.mapSizeZ / cell)
		local pass, right, down = {}, {}, {}
		for r = 1, rows - 2 do
			for c = 1, cols - 2 do
				if ok((c + 0.5) * cell, (r + 0.5) * cell) then pass[r * cols + c] = true end
			end
		end
		for i in pairs(pass) do
			local c, r = i % cols, math.floor(i / cols)
			if pass[i + 1] and ok((c + 1) * cell, (r + 0.5) * cell) then right[i] = true end
			if pass[i + cols] and ok((c + 0.5) * cell, (r + 1) * cell) then down[i] = true end
		end
		local function neighbours(i)
			local list = {}
			if right[i] then list[#list + 1] = i + 1 end
			if right[i - 1] then list[#list + 1] = i - 1 end
			if down[i] then list[#list + 1] = i + cols end
			if down[i - cols] then list[#list + 1] = i - cols end
			return list
		end
		local comp, best, bestN, id = {}, nil, 0, 0
		for i in pairs(pass) do
			if not comp[i] then
				id = id + 1
				comp[i] = id
				local queue, head, n = { i }, 1, 0
				while queue[head] do
					local cur = queue[head]
					head, n = head + 1, n + 1
					for _, nb in ipairs(neighbours(cur)) do
						if not comp[nb] then comp[nb] = id; queue[#queue + 1] = nb end
					end
				end
				if n > bestN then best, bestN = id, n end
			end
		end
		local main = {}
		for i, c in pairs(comp) do
			if c == best then main[#main + 1] = i end
		end
		grid = { cell = cell, cols = cols, comp = comp, main = best, list = main, neighbours = neighbours, ok = ok }
		if ctx.testing then Spring.Echo(string.format("[Renegade] race grid: cells of %d Elmo, %d of %d passable for %d kinds of movement, the biggest piece %d", cell, #main, cols * rows, #defs, bestN)) end
	end

	local function center(i)
		return (i % grid.cols + 0.5) * grid.cell, (math.floor(i / grid.cols) + 0.5) * grid.cell
	end

	local function nearestCell(x, z)
		local best, bd
		for _, i in ipairs(grid.list) do
			local cx, cz = center(i)
			local d = (cx - x) ^ 2 + (cz - z) ^ 2
			if not bd or d < bd then best, bd = i, d end
		end
		return best
	end

	-- the steps on the grid from one cell to another (nil: no way)
	local function steps(from, to)
		if from == to then return 0 end
		local dist, queue, head = { [from] = 0 }, { from }, 1
		while queue[head] do
			local cur = queue[head]
			head = head + 1
			for _, nb in ipairs(grid.neighbours(cur)) do
				if not dist[nb] then
					dist[nb] = dist[cur] + 1
					if nb == to then return dist[nb] end
					queue[#queue + 1] = nb
				end
			end
		end
		return nil
	end

	-- a track: CHECKPOINTS cells on a ring round the middle (a random turn, a radius of 0.22 to 0.36 of the smaller side of the map), each the nearest cell of the main piece;
	-- its worst stretch = the steps on the grid against the steps of a straight way (1 = straight); the best of TRIES rings, at once when it is below DETOUR
	local function makeTrack()
		if not grid then buildGrid() end
		local cx, cz = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local best
		if #grid.list > 0 then
			for try = 1, TRIES do
				local turn, rf = math.random() * 2 * math.pi, 0.22 + math.random() * 0.14
				local r = math.min(Game.mapSizeX, Game.mapSizeZ) * rf
				local cells, pts = {}, {}
				for i = 1, CHECKPOINTS do
					local a = turn + (i - 1) / CHECKPOINTS * 2 * math.pi
					cells[i] = nearestCell(cx + r * math.sin(a), cz + r * math.cos(a))
					local x, z = center(cells[i])
					pts[i] = { x = math.floor(x), z = math.floor(z) }
				end
				local worst = 0
				for i = 1, CHECKPOINTS do
					local j = i % CHECKPOINTS + 1
					local a, b = cells[i], cells[j]
					local straight = math.abs(a % grid.cols - b % grid.cols) + math.abs(math.floor(a / grid.cols) - math.floor(b / grid.cols))
					local n = straight >= 3 and steps(a, b)
					if not n then worst = math.huge break end
					worst = math.max(worst, n / straight)
				end
				if not best or worst < best.worst then best = { pts = pts, worst = worst, try = try } end
				if worst <= DETOUR then break end
			end
		end
		if best and best.worst < math.huge then
			cps = best.pts
		else
			-- (no piece of land for a ring: the points of the ring as they are)
			cps = {}
			local r = math.min(Game.mapSizeX, Game.mapSizeZ) * 0.3
			for i = 1, CHECKPOINTS do
				local a = (i - 1) / CHECKPOINTS * 2 * math.pi
				cps[i] = { x = math.floor(cx + r * math.sin(a)), z = math.floor(cz + r * math.cos(a)) }
			end
		end
		if ctx.testing then Spring.Echo(string.format("[Renegade] race track: %s after %s rings, the worst stretch %.2f of a straight way", best and "found" or "none", tostring(best and best.try), best and best.worst or -1)) end
		local t = {}
		for _, c in ipairs(cps) do t[#t + 1] = c.x .. "," .. c.z end
		Spring.SetGameRulesParam("renRaceCps", table.concat(t, "/"))
		Spring.SetGameRulesParam("renRaceLaps", LAPS)
	end

	local function publish()
		-- the places: more laps, then further checkpoints, then nearer to the next one; a finished player by its time
		local rows = {}
		for team, st in pairs(state) do
			local d = 0
			local u = ctx.units[team]
			local c = cps[st.cp]
			if u and c and not st.time then
				local x, _, z = Spring.GetUnitPosition(u)
				if x then d = math.sqrt((x - c.x) ^ 2 + (z - c.z) ^ 2) end
			end
			rows[#rows + 1] = { team = team, key = st.time and (1e9 - st.time) or ((st.lap * 100 + st.cp) * 1e5 - d) }
		end
		table.sort(rows, function(a, b) if a.key ~= b.key then return a.key > b.key end return a.team < b.team end)
		for i, r in ipairs(rows) do
			local st = state[r.team]
			st.pos = i
			Spring.SetTeamRulesParam(r.team, "renRaceLap", st.lap, { public = true })
			Spring.SetTeamRulesParam(r.team, "renRaceCp", st.cp, { public = true })
			Spring.SetTeamRulesParam(r.team, "renRacePos", i, { public = true })
			Spring.SetTeamRulesParam(r.team, "renRaceTime", st.time or 0, { public = true })
		end
		for team, n in pairs(pick) do Spring.SetTeamRulesParam(team, "renRacePick", n, { public = true }) end
		return rows
	end

	-- the movement of a racer: the same top speed, acceleration and turn rate for every kind (unit rules ledBaseSpeed: a sprint of the power-ups ends at this speed)
	local function equalize(u)
		local set = Spring.MoveCtrl and Spring.MoveCtrl.SetGroundMoveTypeData
		if not set then return end
		for key, v in pairs({ maxSpeed = SPEED, maxWantedSpeed = SPEED, accRate = ACC, decRate = DEC, turnRate = TURN }) do
			if v > 0 then pcall(set, u, key, v) end
		end
		Spring.SetUnitRulesParam(u, "ledBaseSpeed", SPEED)
		equal[u] = true
		if ctx.testing then
			local ok, md = pcall(Spring.GetUnitMoveTypeData, u)
			Spring.Echo(string.format("[Renegade] race: unit %d %s speed %s acc %s turn %s", u, tostring(UnitDefs[Spring.GetUnitDefID(u) or -1].name),
				tostring(ok and md.maxSpeed), tostring(ok and md.accRate), tostring(ok and md.turnRate)))
		end
	end

	-- every human drives its racer (a respawned unit is turned into it as well)
	local function racers()
		for _, team in ipairs(humanTeams()) do
			pick[team] = pick[team] or math.random(1, #RACERS)
			local u = ctx.units[team]
			if u and ctx.kind[team] ~= RACERS[pick[team]] then
				ctx.turnInto(team, RACERS[pick[team]])
				u = ctx.units[team]
			end
			if u and not equal[u] then equalize(u) end
		end
	end

	-- the start grid: rows of four behind the last checkpoint, looking along the track to the first one; a place where the racers cannot drive moves to the nearest cell that can
	local function startGrid()
		local last, first = cps[#cps], cps[1]
		local dx, dz = first.x - last.x, first.z - last.z
		local l = math.max(1, math.sqrt(dx * dx + dz * dz))
		dx, dz = dx / l, dz / l
		for i, team in ipairs(humanTeams()) do
			local u = ctx.units[team]
			local row, col = math.floor((i - 1) / 4), (i - 1) % 4
			local x = last.x - dx * (60 + row * 70) + (-dz) * (col - 1.5) * 60
			local z = last.z - dz * (60 + row * 70) + dx * (col - 1.5) * 60
			if grid and #grid.list > 0 and not (grid.ok(x, z) and grid.comp[nearestCell(x, z)] == grid.main) then
				x, z = center(nearestCell(x, z))
			end
			if u then
				Spring.SetUnitPosition(u, x, Spring.GetGroundHeight(x, z), z)
				Spring.SetUnitDirection(u, dx, 0, dz)
				Spring.GiveOrderToUnit(u, CMD.STOP, {}, 0)
			end
			state[team] = { lap = 1, cp = 1 }
		end
		publish()
	end

	local function remove()
		local isHuman = {}
		for _, t in ipairs(humanTeams()) do isHuman[t] = true end
		for _, team in ipairs(Spring.GetTeamList()) do
			if team ~= Spring.GetGaiaTeamID() and not isHuman[team] then
				for _, u in ipairs(Spring.GetTeamUnits(team)) do Spring.DestroyUnit(u, false, true) end
			end
		end
	end

	-- a new race: a new track, the pick, the countdown to go
	local function newRace(at)
		raceNo = raceNo + 1
		phase, go, winner, finishAt = "pick", at, nil, nil
		state = {}
		makeTrack()
		racers()
		startGrid()
		Spring.SetGameRulesParam("renRaceGo", go)
		Spring.SetGameRulesParam("renRaceOver", 0)
		Spring.SetGameRulesParam("renRaceResult", "")
		Spring.SetGameRulesParam("renRaceNo", raceNo)
		Spring.SetGameRulesParam("renRaceUnits", table.concat(RACERS, ","))
		if raceNo > 1 then ctx.say(string.format("A new race on a new track: pick your racer, the start is in %d seconds.", math.floor((at - Spring.GetGameFrame()) / 30))) end
	end

	-- the race is over: the list of places (the gadget's game rules), the buttons New race and Leave of the widget
	local function results(f)
		phase = "results"
		local t = {}
		for _, r in ipairs(publish()) do
			local st = state[r.team]
			t[#t + 1] = r.team .. ":" .. (st.time or 0) .. ":" .. (ctx.kind[r.team] or "")
		end
		Spring.SetGameRulesParam("renRaceResult", table.concat(t, ";"))
		Spring.SetGameRulesParam("renRaceOver", f)
		ctx.say(string.format("%s wins the race! New race or Leave?", name(winner)))
	end

	-- a team passes its next checkpoint
	local function pass(team, f)
		local st = state[team]
		st.cp = st.cp + 1
		if st.cp > #cps then
			if st.lap >= LAPS then
				st.time = f - go
				local secs = math.floor(st.time / 30)
				if not winner then
					winner, finishAt = team, f
					ctx.say(string.format("%s is first through the finish: %d:%02d!", name(team), math.floor(secs / 60), secs % 60))
				else
					ctx.say(string.format("%s is through the finish: %d:%02d.", name(team), math.floor(secs / 60), secs % 60))
				end
			else
				st.lap, st.cp = st.lap + 1, 1
			end
		end
		publish()
	end

	function S.frame(f)
		if phase == "leaving" or ctx.rounds.over() then return end
		if f >= 30 and f <= 300 and f % 15 == 0 then remove() end
		if f == 60 then newRace(FIRST_GO) end
		if phase == "wait" then return end
		if f % 15 == 0 then racers() end
		if phase == "pick" and f >= go then
			phase = "race"
			startGrid()
			ctx.say("GO!")
		end
		if phase ~= "race" then return end
		if f % 5 == 0 then
			for team, st in pairs(state) do
				local u = ctx.units[team]
				local c = cps[st.cp]
				if u and c and not st.time then
					local x, _, z = Spring.GetUnitPosition(u)
					if x and (x - c.x) ^ 2 + (z - c.z) ^ 2 < PASS * PASS then pass(team, f) end
				end
			end
			if f % 30 == 0 then publish() end
		end
		if winner then
			local all = true
			for _, st in pairs(state) do if not st.time then all = false end end
			if all or f >= finishAt + FINISH_WAIT then results(f) end
		end
	end

	function S.destroyed(u) equal[u] = nil end

	-- the messages of the widget: "ren|race|pick|<n>" (before the start), "ren|race|again" and "ren|race|leave" (the results; leave also during a race)
	function S.msg(team, cmd, n)
		if cmd == "pick" and phase == "pick" and n and RACERS[n] then
			pick[team] = n
			racers()
			publish()
		elseif cmd == "again" and phase == "results" then
			ctx.say(name(team) .. " starts a new race.")
			newRace(Spring.GetGameFrame() + AGAIN_PICK)
		elseif cmd == "leave" and (phase == "results" or phase == "race" or phase == "pick") then
			phase = "leaving"
			ctx.rounds.finish(winner or -1, winner and string.format("%s wins the race!", name(winner)) or (name(team) .. " left the race."))
		end
	end

	-- units of players do not hurt each other
	function S.noDamage(unitID)
		local team = Spring.GetUnitTeam(unitID)
		return team ~= nil and ctx.units[team] == unitID
	end

	-- tests: the unit of the team is put onto its next checkpoint
	function S.toNext(team)
		local st, u = state[team], ctx.units[team]
		local c = st and cps[st.cp]
		if c and u then Spring.SetUnitPosition(u, c.x, Spring.GetGroundHeight(c.x, c.z), c.z) end
	end

	return S
end
