-- Renegade, the mode Survival (synchronized; loaded by renegade_game.lua with the game option lanrenemode=survival, luaui/Include/renegade_survival.lua).
-- All humans are allied and fight together against WAVES waves of units of Gaia that hunt them; the computer teams of the room are removed.
--   waves      wave n: count(n) units of the levels of LADDERS (the ladders of Evolution) n - 4 to n - 2 (at least 1), with WAVE_HP of their health, at places far from the
--              players; wave 5 and wave 10 bring a boss of level n. Every 4 s every unit of the wave gets a fight order toward the nearest player unit.
--   players    every player keeps one faction; at the start of wave n its unit becomes the unit of level n + 1 of that faction (full health at the start of each wave).
--              A lost unit does not come back during the wave: at its end every dead player comes back next to a living mate.
--   end        all waves beaten: the humans win; all players dead at the same time: the waves win ("you lasted until wave n"). rounds.finish ends the game.
--   state      game rules renSurvWave (the wave, 0 before the first), renSurvWaves, renSurvLeft (units of the wave left), renSurvNext (the frame the next wave comes, 0 during one)
-- ctx: units (team -> unit), kind (team -> unit name), say(text), rounds (renegade_rounds.lua), place(defName, list, wanted) -> x, y, z, others(team) (list of player units but
-- this team), giveUnit(team, defName, x, y, z, face), turnInto(team, defName), testing. Returns S.
return function(ctx)
	local S = {}
	local WAVES, BREAK, FIRST_AT, WAVE_HP, STEER = 10, 15 * 30, 15 * 30, 0.5, 4 * 30
	local LADDERS = {
		{ "armpw", "armflash", "armwar", "armzeus", "armbull", "armmar", "armmeatball", "armraz", "armthor", "armbanth" },
		{ "corak", "corgator", "corraid", "corpyro", "correap", "corcan", "corshiva", "corkarg", "cordemon", "corkorg" },
	}
	local wave, nextAt, done = 0, FIRST_AT, false
	local enemies = {} -- unit id -> true: the units of the wave
	local left = 0
	local faction = {} -- team -> index of LADDERS
	local dead = {} -- team -> true: lost its unit during the wave
	local allied = false

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

	local function publish()
		Spring.SetGameRulesParam("renSurvWave", wave)
		Spring.SetGameRulesParam("renSurvWaves", WAVES)
		Spring.SetGameRulesParam("renSurvLeft", left)
		Spring.SetGameRulesParam("renSurvNext", nextAt or 0)
	end
	publish()

	local function ladderUnit(f, level)
		local l = LADDERS[f] or LADDERS[1]
		local name = l[math.max(1, math.min(#l, level))]
		return UnitDefNames[name] and name or "armpw"
	end

	-- the humans are one alliance; the units of the computer teams go (the start: until frame 300, every 15 frames)
	local function setup(f)
		local humans = humanTeams()
		local isHuman = {}
		for _, t in ipairs(humans) do isHuman[t] = true end
		if not allied then
			allied = true
			for _, a in ipairs(humans) do
				for _, b in ipairs(humans) do
					local aa, ab = Spring.GetTeamAllyTeamID(a), Spring.GetTeamAllyTeamID(b)
					if aa ~= ab then pcall(Spring.SetAlly, aa, ab, true) end
				end
			end
		end
		for _, team in ipairs(Spring.GetTeamList()) do
			if team ~= Spring.GetGaiaTeamID() and not isHuman[team] then
				for _, u in ipairs(Spring.GetTeamUnits(team)) do Spring.DestroyUnit(u, false, true) end
			end
		end
		for _, t in ipairs(humans) do
			if not faction[t] then faction[t] = math.random(1, #LADDERS) end
		end
	end

	local function count(n)
		local humans = math.max(1, #humanTeams())
		return math.floor((2 + 1.5 * n) * (0.6 + 0.4 * humans) + 0.5)
	end

	local function spawnEnemy(name)
		local x, y, z = ctx.place(name, ctx.others(-1), 1600)
		if not x then return end
		local id = Spring.CreateUnit(name, x, y, z, math.random(0, 3), Spring.GetGaiaTeamID())
		if id then
			enemies[id] = true
			left = left + 1
			local _, mhp = Spring.GetUnitHealth(id)
			if mhp then Spring.SetUnitHealth(id, mhp * WAVE_HP) end
		end
	end

	-- the players of the next wave: a dead one comes back next to a living mate (or at a free place), every unit becomes the unit of level n + 1 at full health
	local function readyPlayers(n)
		local alive
		for _, t in ipairs(humanTeams()) do
			if ctx.units[t] then alive = ctx.units[t] break end
		end
		for _, t in ipairs(humanTeams()) do
			local name = ladderUnit(faction[t] or 1, n + 1)
			if not ctx.units[t] and (dead[t] or ctx.kind[t]) then
				local x, y, z
				if alive then
					local ax, _, az = Spring.GetUnitPosition(alive)
					x, z = ax + math.random(-150, 150), az + math.random(-150, 150)
					y = Spring.GetGroundHeight(x, z)
				else
					x, y, z = ctx.place(name, {}, nil)
				end
				if x then ctx.giveUnit(t, name, x, y, z, 0) end
			elseif ctx.units[t] and ctx.kind[t] ~= name then
				ctx.turnInto(t, name)
			end
			dead[t] = nil
			local u = ctx.units[t]
			if u then
				local _, mhp = Spring.GetUnitHealth(u)
				if mhp then Spring.SetUnitHealth(u, mhp) end
			end
		end
	end

	local function startWave(f)
		wave = wave + 1
		nextAt = nil
		readyPlayers(wave)
		local n = count(wave)
		for i = 1, n do
			local level = math.max(1, wave - 2 - (i % 3))
			spawnEnemy(ladderUnit(math.random(1, #LADDERS), level))
		end
		if wave == 5 or wave == WAVES then
			spawnEnemy(ladderUnit(math.random(1, #LADDERS), wave)) -- (a boss)
		end
		ctx.say(string.format("Wave %d of %d: %d enemies!", wave, WAVES, left))
		publish()
	end

	local function steer()
		local players = ctx.others(-1)
		if #players == 0 then return end
		for id in pairs(enemies) do
			local x, _, z = Spring.GetUnitPosition(id)
			if x then
				local best, bx, bz
				for _, u in ipairs(players) do
					local ux, _, uz = Spring.GetUnitPosition(u)
					local d = ux and (ux - x) ^ 2 + (uz - z) ^ 2
					if d and (not best or d < best) then best, bx, bz = d, ux, uz end
				end
				if bx then Spring.GiveOrderToUnit(id, CMD.FIGHT, { bx, Spring.GetGroundHeight(bx, bz), bz }, 0) end
			end
		end
	end

	-- the wave is beaten: the last one wins the game, otherwise a break
	local function waveOver(f)
		if wave >= WAVES then
			done = true
			local humans = humanTeams()
			local allies = {}
			for _, t in ipairs(humans) do allies[#allies + 1] = Spring.GetTeamAllyTeamID(t) end
			ctx.rounds.finish(humans[1] or 0, string.format("You survived all %d waves!", WAVES), allies)
			return
		end
		nextAt = f + BREAK
		readyPlayers(wave) -- (the dead come back now, with the unit of this wave)
		ctx.say(string.format("Wave %d beaten! The next one comes in %d seconds.", wave, BREAK / 30))
		publish()
	end

	function S.frame(f)
		if done or ctx.rounds.over() then return end
		if f >= 30 and f <= 300 and f % 15 == 0 then setup(f) end
		if nextAt and f >= nextAt then startWave(f) end
		if wave > 0 and not nextAt and f % STEER == 0 then steer() end
		if f % 30 == 0 then publish() end
	end

	-- a unit was lost: one of the wave (the wave may be over), or a player's (it waits for the end of the wave; all dead: the waves win)
	function S.destroyed(u, team, playerUnit)
		if enemies[u] then
			enemies[u] = nil
			left = math.max(0, left - 1)
			if left == 0 and not nextAt then waveOver(Spring.GetGameFrame()) end
			publish()
		elseif playerUnit and wave > 0 and not done then
			dead[team] = true
			for _, t in ipairs(humanTeams()) do
				if ctx.units[t] and t ~= team then return end
			end
			done = true
			ctx.rounds.finish(-1, string.format("The waves won: you lasted until wave %d of %d.", wave, WAVES))
		end
	end

	-- tests: every unit of the wave is destroyed
	function S.clear()
		for id in pairs(enemies) do
			if Spring.ValidUnitID(id) then Spring.DestroyUnit(id, false, true) end
		end
	end

	return S
end
