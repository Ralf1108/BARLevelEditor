function widget:GetInfo() return { name = "zz evo", desc = "test only: Evolution in the editor", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_evo.lua: loads the test level evo_test (team 0 = this player, team 1 = steered by evo_game.lua), sets
-- small numbers (1 life, 2 points to stage 2), starts Evolution at a high game speed, steers the own unit at the unit of team 1 and logs "[zzar]"
-- lines (stages, points, lives, the units). When the game is won (or after 8 minutes of game time) it stops the test and checks that the level is back.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local loadLevel
local evo
local phase, wonAt, stopAt = "load", nil, nil
local maxStage = { 0, 0 }

local function state()
	local t = {}
	for team in tostring(Spring.GetGameRulesParam("evoTeams") or ""):gmatch("%d+") do
		local function tp(k) return tostring(Spring.GetTeamRulesParam(tonumber(team), k)) end
		t[#t + 1] = string.format("team%s stage=%s xp=%s/%s lives=%s out=%s %s", team, tp("evoStage"), tp("evoXp"), tp("evoNeed"), tp("evoLeft"), tp("evoOut"), tp("evoName"))
		local s = tonumber(Spring.GetTeamRulesParam(tonumber(team), "evoStage")) or 0
		maxStage[tonumber(team) + 1] = math.max(maxStage[tonumber(team) + 1] or 0, s)
	end
	local wild = #Spring.GetTeamUnits(Spring.GetGaiaTeamID())
	return tostring(Spring.GetGameRulesParam("evoState")) .. " | " .. table.concat(t, " | ") .. " | gaia units " .. wild
end

function widget:GameFrame(f)
	if phase == "load" and f >= 40 then
		local _
		_, _, loadLevel = W():DebugTeams()
		loadLevel(nil, nil, { "evo_test" })
		log("load evo_test")
		phase = "start"
	elseif phase == "start" and f >= 200 then
		evo = W():DebugEvo()
		local c = evo.cfg(true)
		c.lives, c.first, c.wilds, c.respawn = 1, 2, 30, 3
		log("payload", tostring(evo.payload()))
		evo.toggle()
		Spring.SendCommands("setmaxspeed 8", "setminspeed 8")
		phase = "run"
	elseif phase == "run" then
		if f % 300 == 0 then
			log("frame", f, state())
		end
		if f % 300 == 150 then
			local id = Spring.GetTeamRulesParam(0, "evoUnit")
			if id and id > 0 and Spring.ValidUnitID(id) then
				local x, z = Game.mapSizeX * (0.35 + 0.3 * math.random()), Game.mapSizeZ * (0.35 + 0.3 * math.random())
				local ex, _, ez = Spring.GetUnitPosition(Spring.GetTeamRulesParam(1, "evoUnit") or -1)
				if ex then
					x, z = ex, ez -- the editor sees every unit
				end
				Spring.GiveOrderToUnit(id, CMD.FIGHT, { x, Spring.GetGroundHeight(x, z), z }, {})
			end
		end
		local st = tostring(Spring.GetGameRulesParam("evoState"))
		if (st:find("^won") or f > 200 + 30 * 60 * 8) and not wonAt then
			wonAt = f
			log("END STATE", f, state())
			log("max stage reached: team0", maxStage[1], "team1", maxStage[2])
			Spring.SendCommands("setminspeed 1", "setmaxspeed 1")
		end
		if wonAt and f > wonAt + 60 then
			evo.toggle() -- stop: the level before comes back
			phase, stopAt = "check", f
		end
	elseif phase == "check" and f > stopAt + 120 then
		local n0, n1 = #Spring.GetTeamUnits(0), #Spring.GetTeamUnits(1)
		log("after stop: evoState", tostring(Spring.GetGameRulesParam("evoState")), "units team0", n0, "team1", n1, "gaia", #Spring.GetTeamUnits(Spring.GetGaiaTeamID()),
			(Spring.GetGameRulesParam("evoState") == "" and n0 == 1 and n1 == 1) and "OK" or "WRONG")
		log("END")
		Spring.SendCommands("quitforce")
		phase = "done"
	end
end
