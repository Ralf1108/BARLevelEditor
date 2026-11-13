-- The power-ups (Sprint, Repair, Radar Pulse, Cloak, Jammer): the data (P.ABILITIES, used by both parts of a gadget and by the widgets) and the logic of the synced part: beacons on the
-- map that give a power-up to the unit that drives over them, the use of a power-up, its effect and its end, the computer players. P.new(ctx) returns the table A; the game mode gives
-- it (ctx): players (the list of the player records { team, unit, name, ai, out, abilities, cool, active }), owner (unit id -> player record), say(text), randomSpot() (x, z of a free
-- place for a beacon or nil), count() (beacons of every kind at the start), testing (log lines), healMsg (the name of the message SendToUnsynced for the heal effect),
-- abilitiesRule (team rule with the state of the abilities of a team), beaconsRule (game rule with the beacons) and fireAfter(p) (the fire state a human's unit gets back when the cloak
-- ends: 2 fire at will, 0 hold fire for a unit that Renegade steers; default 2). Loaded by evo_game.lua, which also uses it unsynced for the list.
local P = {}

-- The abilities: a beacon of the color of an ability lies on the map; a player's unit that drives over it gets the ability until it dies (a button in the
-- order menu: energy cost, time it lasts, cooldown in seconds). Used by both parts (the beacons and the display).
P.ABILITIES = {
	{ key = "sprint", name = "Sprint", color = { 0.3, 0.65, 1 }, cost = 200, time = 8, cool = 30, tip = "Your unit is 50 % faster for 8 s" },
	{ key = "repair", name = "Repair", color = { 0.3, 1, 0.35 }, cost = 500, time = 0, cool = 60, tip = "Heals 20 % of the health of your unit at once" },
	{ key = "pulse", name = "Radar Pulse", color = { 1, 0.55, 0.1 }, cost = 250, time = 5, cool = 45, tip = "Your unit sees everything within 2500 Elmo for 5 s" },
	{ key = "cloak", name = "Cloak", color = { 1, 0.9, 0.2 }, cost = 400, time = 15, cool = 60, tip = "Your unit is invisible to the enemy for 15 s (until it fires)",
		info = "Hold Fire is set while you are cloaked, Fire at Will after it: flee from battle" },
	{ key = "jammer", name = "Jammer", color = { 0.75, 0.35, 1 }, cost = 300, time = 20, cool = 60, tip = "Hides your unit from the enemy radar for 20 s" },
}

function P.new(ctx)
	local ABILITIES, players, owner, say = P.ABILITIES, ctx.players, ctx.owner, ctx.say
	local G = VFS.Include("luaui/Include/led_gadgets.lua", nil, VFS.ZIP_FIRST) -- (G.setSight)
	local FPS, CMD_FIRE_STATE = 30, CMD.FIRE_STATE

	-- ---------------------------------------------------------------- abilities and their beacons (one table: Lua 5.1 allows only so many locals and upvalues)
	-- A player record keeps p.abilities (index -> true), p.cool (index -> frame it is ready again) and p.active (index -> { frame it ends, unit }).
	local A = {
		beacons = {}, -- { x, z, kind = index of ABILITIES }
		due = {}, -- frames at which a taken beacon lies somewhere else
		PICK = 80, -- Elmo: a player's unit this near takes a beacon
		BACK = 45 * FPS, -- frames until a taken beacon comes back somewhere else (a new random color)
		SPEED = 1.5, HEAL = 0.2, PULSE = 2500, JAM = 500, -- sprint factor, part of the health, sight of the pulse, jammer radius
	}

	-- beacons of every ability at the start: ctx.count() of each kind
	A.count = ctx.count

	-- a beacon of the ability kind at a random place of the land; false when no free place was found
	function A.place(kind)
		local x, z = ctx.randomSpot()
		if x then
			A.beacons[#A.beacons + 1] = { x = x, z = z, kind = kind }
			return true
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
		Spring.SetGameRulesParam(ctx.beaconsRule, table.concat(t, "/"))
		local n = Spring.GetGameFrame()
		for _, p in ipairs(players) do
			local list = {}
			for i in ipairs(ABILITIES) do
				if p.abilities and p.abilities[i] then
					local act = p.active and p.active[i]
					list[#list + 1] = string.format("%d:%d:%d", i, math.max(0, math.ceil((((p.cool and p.cool[i]) or 0) - n) / FPS)), act and math.max(0, math.ceil((act.frame - n) / FPS)) or 0)
				end
			end
			Spring.SetTeamRulesParam(p.team, ctx.abilitiesRule, table.concat(list, ","), { public = true })
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
			if not p.ai then
				-- a human player: hold fire while cloaked (a unit that fires is seen at once); fire at will again when the cloak is over
				p.holdFire = true
				Spring.GiveOrderToUnit(id, CMD_FIRE_STATE, { 0 }, 0)
				Spring.GiveOrderToUnit(id, CMD.STOP, {}, 0) -- (the weapons let go of the target they have already)
			end
		elseif a.key == "sprint" then
			pcall(Spring.MoveCtrl.SetGroundMoveTypeData, id, { maxSpeed = ud.speed * A.SPEED, maxWantedSpeed = ud.speed * A.SPEED })
		elseif a.key == "repair" then
			local hp, maxHp = Spring.GetUnitHealth(id)
			local newHp = math.min(maxHp, hp + maxHp * A.HEAL)
			Spring.SetUnitHealth(id, newHp)
			SendToUnsynced(ctx.healMsg, id, newHp - hp) -- (green plus signs and "+N" over the unit)
		elseif a.key == "pulse" then
			G.setSight(id, "pulse", { radius = A.PULSE }) -- (a mode that makes the sight larger, Renegade, keeps its own reason)
		end
		if a.time > 0 then
			p.active = p.active or {}
			p.active[i] = { frame = Spring.GetGameFrame() + a.time * FPS, unit = id }
			if a.key == "cloak" then
				-- the reload frames of the weapons now: only a shot after the start shows the unit (a shot just before it must not end the cloak)
				local base = {}
				for w = 1, #(ud and ud.weapons or {}) do
					base[w] = Spring.GetUnitWeaponState(id, w, "reloadFrame") or 0
				end
				p.active[i].base = base
				p.active[i].grace = Spring.GetGameFrame() + 60 -- (a shot that was already on its way when the cloak began does not end it)
			end
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
			if p.holdFire then
				Spring.GiveOrderToUnit(id, CMD_FIRE_STATE, { ctx.fireAfter and ctx.fireAfter(p) or 2 }, 0) -- (2 = fire at will)
				p.holdFire = nil
			end
		elseif key == "sprint" then
			pcall(Spring.MoveCtrl.SetGroundMoveTypeData, id, { maxSpeed = ud.speed, maxWantedSpeed = ud.speed })
		elseif key == "pulse" then
			G.setSight(id, "pulse", nil)
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
					local ud = UnitDefs[Spring.GetUnitDefID(act.unit)]
					for w = 1, #(ud and ud.weapons or {}) do
						local r = Spring.GetUnitWeaponState(act.unit, w, "reloadFrame")
						if r and n < (act.grace or 0) then
							act.base[w] = r -- (the first 60 frames: only note the reload frame)
						elseif r and r > ((act.base or {})[w] or 1e9) then
							if ctx.testing then
								Spring.Echo(string.format("[Evolution] test: seen by weapon %d: reload frame %s, at the start %s, frame %d", w, tostring(r), tostring(act.base[w]), n))
							end
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
			local taker, refresher
			for _, uid in ipairs(Spring.GetUnitsInCylinder(b.x, b.z, A.PICK)) do
				local p = owner[uid]
				if p and not p.out then
					if not (p.abilities and p.abilities[b.kind]) then
						taker = p
						break
					elseif not refresher and p.cool and (p.cool[b.kind] or 0) > n then
						refresher = p -- (has it already and it cools down)
					end
				end
			end
			if taker then
				taker.abilities = taker.abilities or {}
				taker.abilities[b.kind] = true
				A.due[#A.due + 1] = { n + A.BACK, b.kind } -- (the same kind comes back somewhere else)
				say(string.format("%s found %s.", taker.name, ABILITIES[b.kind].name))
				changed = true
			elseif refresher then
				-- a power-up the unit has already, while it cools down: the beacon is used up and the cooldown is gone
				refresher.cool[b.kind] = nil
				A.due[#A.due + 1] = { n + A.BACK, b.kind }
				say(string.format("%s used a beacon: %s is ready again.", refresher.name, ABILITIES[b.kind].name))
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

	return A
end

return P
