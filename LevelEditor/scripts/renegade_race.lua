-- Renegade, the mode Race (synchronized; loaded by renegade_game.lua with the game option lanrenemode=race, luaui/Include/renegade_race.lua).
-- Every human drives the same unit (START_UNIT of the gadget, it can jump) through CHECKPOINTS checkpoints in a ring round the middle of the map, LAPS laps; the first one at the
-- finish wins. Units of players take no damage from each other; the computer teams of the room are removed.
--   start      at frame GO_AT (a countdown of 5 s before it) every player is put onto the start grid next to the last checkpoint; checkpoints count only from then on
--   progress   a player's unit within PASS Elmo of its next checkpoint passes it; after the last one of a lap the next lap begins at the first one
--   end        the first player through the finish wins; the others have FINISH_WAIT to finish; then rounds.finish(winner) ends the game
--   state      game rules renRaceCps ("x,z/x,z/..."), renRaceLaps, renRaceGo (frame of the start); team rules renRaceLap (1 based), renRaceCp (the next checkpoint, 1 based),
--              renRacePos (the place), renRaceTime (frames from the start to the finish, 0 = not yet)
-- ctx: units (team -> unit), startUnit, say(text), rounds, testing. Returns S.
return function(ctx)
	local S = {}
	local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST)
	local CHECKPOINTS, LAPS, PASS, RADIUS, GO_AT, FINISH_WAIT = 8, 2, 140, 0.3, 20 * 30, 30 * 30
	local cps = {}
	local state = {} -- team -> { lap, cp, time }
	local winner, finishAt, ended = nil, nil, false

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

	-- the checkpoints: CHECKPOINTS places in a ring round the middle (RADIUS of the smaller side of the map), each the nearest place to its point on the ring where the unit can stand
	local function makeTrack()
		local def = UnitDefNames[ctx.startUnit]
		local cx, cz = Game.mapSizeX / 2, Game.mapSizeZ / 2
		local r = math.min(Game.mapSizeX, Game.mapSizeZ) * RADIUS
		local list = {}
		for i = 1, CHECKPOINTS do
			local a = (i - 1) / CHECKPOINTS * 2 * math.pi
			local tx, tz = cx + r * math.sin(a), cz + r * math.cos(a)
			local bx, bz
			if def and G.fits(def.id, tx, tz, false, 2) then
				bx, bz = tx, tz
			else
				local best
				for _ = 1, 60 do
					local x, z = tx + math.random(-400, 400), tz + math.random(-400, 400)
					if def and G.fits(def.id, x, z, false, 2) then
						local d = (x - tx) ^ 2 + (z - tz) ^ 2
						if not best or d < best then best, bx, bz = d, x, z end
					end
				end
			end
			list[#list + 1] = { x = math.floor(bx or tx), z = math.floor(bz or tz) }
		end
		cps = list
		local t = {}
		for _, c in ipairs(cps) do t[#t + 1] = c.x .. "," .. c.z end
		Spring.SetGameRulesParam("renRaceCps", table.concat(t, "/"))
		Spring.SetGameRulesParam("renRaceLaps", LAPS)
		Spring.SetGameRulesParam("renRaceGo", GO_AT)
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
			Spring.SetTeamRulesParam(r.team, "renRaceLap", st.lap, { public = true })
			Spring.SetTeamRulesParam(r.team, "renRaceCp", st.cp, { public = true })
			Spring.SetTeamRulesParam(r.team, "renRacePos", i, { public = true })
			Spring.SetTeamRulesParam(r.team, "renRaceTime", st.time or 0, { public = true })
		end
	end

	-- the start grid: two rows behind the last checkpoint, looking along the track to the first one
	local function startGrid()
		local last, first = cps[#cps], cps[1]
		local dx, dz = first.x - last.x, first.z - last.z
		local l = math.sqrt(dx * dx + dz * dz)
		dx, dz = dx / l, dz / l
		for i, team in ipairs(humanTeams()) do
			local u = ctx.units[team]
			local row, col = math.floor((i - 1) / 4), (i - 1) % 4
			local x = last.x - dx * (60 + row * 70) + (-dz) * (col - 1.5) * 60
			local z = last.z - dz * (60 + row * 70) + dx * (col - 1.5) * 60
			if u then
				Spring.SetUnitPosition(u, x, Spring.GetGroundHeight(x, z), z)
				Spring.SetUnitDirection(u, dx, 0, dz)
				Spring.GiveOrderToUnit(u, CMD.STOP, {}, 0)
			end
			state[team] = { lap = 1, cp = 1 }
		end
		publish()
	end

	local function remove(f)
		local isHuman = {}
		for _, t in ipairs(humanTeams()) do isHuman[t] = true end
		for _, team in ipairs(Spring.GetTeamList()) do
			if team ~= Spring.GetGaiaTeamID() and not isHuman[team] then
				for _, u in ipairs(Spring.GetTeamUnits(team)) do Spring.DestroyUnit(u, false, true) end
			end
		end
	end

	-- a team passes its next checkpoint
	local function pass(team, f)
		local st = state[team]
		st.cp = st.cp + 1
		if st.cp > #cps then
			if st.lap >= LAPS then
				st.time = f - GO_AT
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
		if ended or ctx.rounds.over() then return end
		if f >= 30 and f <= 300 and f % 15 == 0 then remove(f) end
		if f == 60 then makeTrack() end
		if f == GO_AT then
			startGrid()
			ctx.say("GO!")
		end
		if f > GO_AT and f % 5 == 0 then
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
			if all or f >= finishAt + FINISH_WAIT then
				ended = true
				ctx.rounds.finish(winner, string.format("%s wins the race!", name(winner)))
			end
		end
	end

	function S.destroyed() end

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
