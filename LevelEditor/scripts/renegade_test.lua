-- Test hooks of Renegade (messages "ren|test|<n>" of the test widgets of test-data/tools): only loaded by renegade_game.lua with the game option lanrenotest=1.
-- Returns a function that takes the state of the gadget (env = { units, input, startUnit, engineBombs }) and gives back handler(msg, playerID) -> true when the message was a hook.
--   ren|test|1  an enemy unit (hold fire) 150 Elmo in front of the unit of the player
--   ren|test|2  the unit of the player is destroyed (respawn)
--   ren|test|3  an enemy gunship (hold fire) 250 Elmo ahead, 100 Elmo up
--   ren|test|4  the engine's own bomb release instead of the one of the gadget
--   ren|test|5  the unit takes more damage than it has health (a shot-down aircraft must crash)
--   ren|test|6  the unit is hurt to 30 % health and three wrecks lie 100 Elmo ahead of it (the automatic reclaim must heal it)
return function(env)
	local units, input, startUnit = env.units, env.input, env.startUnit
	local hooks = {}

	-- the unit and team of a player, nil for a spectator
	local function own(playerID)
		local _, _, spec, team = Spring.GetPlayerInfo(playerID, false)
		local u = units[team]
		if u and not spec then
			return u, team
		end
	end

	-- the first enemy team (not allied, not Gaia): a unit of the given kind is made for it ahead of the unit of the player
	local function enemyAhead(playerID, defName, dist, up, label)
		local u, team = own(playerID)
		if not u then return end
		local x, _, z = Spring.GetUnitPosition(u)
		local yaw = math.rad(input[team].yaw)
		local ex, ez = x + math.sin(yaw) * dist, z + math.cos(yaw) * dist
		for _, tm in ipairs(Spring.GetTeamList()) do
			if not Spring.AreTeamsAllied(tm, team) and tm ~= Spring.GetGaiaTeamID() then
				local e = Spring.CreateUnit(defName, ex, Spring.GetGroundHeight(ex, ez) + up, ez, 0, tm)
				if e then
					Spring.GiveOrderToUnit(e, CMD.FIRE_STATE, { 0 }, 0)
					Spring.Echo(label(e, ex, ez))
				end
				break
			end
		end
	end

	hooks["ren|test|1"] = function(playerID)
		enemyAhead(playerID, startUnit, 150, 0, function(e, ex, ez) return "[Renegade] test enemy " .. e .. " at " .. math.floor(ex) .. " " .. math.floor(ez) end)
	end
	hooks["ren|test|3"] = function(playerID)
		enemyAhead(playerID, "armbrawl", 250, 100, function(e) return "[Renegade] test gunship " .. e end)
	end
	hooks["ren|test|4"] = function()
		env.engineBombs()
	end
	hooks["ren|test|2"] = function(playerID)
		local u = own(playerID)
		if u then Spring.DestroyUnit(u, true, false) end
	end
	hooks["ren|test|6"] = function(playerID)
		local u, team = own(playerID)
		if not u then return end
		local x, _, z = Spring.GetUnitPosition(u)
		local _, mhp = Spring.GetUnitHealth(u)
		Spring.SetUnitHealth(u, mhp * 0.3)
		for k = -1, 1 do
			local fid = Spring.CreateFeature("armbull_dead", x + 100, Spring.GetGroundHeight(x + 100, z + k * 60), z + k * 60, 0, team)
			Spring.Echo("[Renegade] test wreck " .. tostring(fid) .. " metal " .. tostring(fid and (Spring.GetFeatureResources(fid))))
		end
	end
	hooks["ren|test|5"] = function(playerID)
		local u = own(playerID)
		if u and Spring.ValidUnitID(u) then
			local hp = Spring.GetUnitHealth(u)
			Spring.AddUnitDamage(u, (hp or 0) + 100000)
		end
	end

	return function(msg, playerID)
		local hook = hooks[msg]
		if hook then
			hook(playerID)
			return true
		end
		return false
	end
end
