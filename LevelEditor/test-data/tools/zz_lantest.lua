function widget:GetInfo() return { name = "zz LAN test", desc = "test only", layer = 0, enabled = true } end
local mo = Spring.GetModOptions() or {}
local mode = mo.lanevolution == "1" and "evo" or (mo.rtfconfig and "rtf" or (mo.ctfconfig and "ctf" or (mo.tdconfig and "td" or "cp")))
local function readFile(name)
	local txt = VFS.LoadFile(name, VFS.RAW) or VFS.LoadFile(name, VFS.RAW_FIRST)
	if not txt and io and io.open then local f = io.open(name, "rb"); if f then txt = f:read("*a"); f:close() end end
	return txt
end
local QUIT = tonumber((readFile("zz_quit.txt") or (mo.lanpvehold and "60000") or (mo.lanevolution == "1" and "9000") or "4500"):match("%d+")) -- game frames
local function log(...) Spring.Echo("[zzlan] " .. table.concat({ ... }, " ")) end
local function gp(k) local v = Spring.GetGameRulesParam(k); if v == nil then return "nil" end return tostring(v) end
local ordered = false
local lastLog = -999
local function players()
	local t = {}
	for _, pid in ipairs(Spring.GetPlayerList()) do
		local name, active, spec, team, ally = Spring.GetPlayerInfo(pid, false)
		t[#t + 1] = string.format("%s(p%d team%s ally%s%s%s)", tostring(name), pid, tostring(team), tostring(ally), spec and " SPEC" or "", active and "" or " inactive")
	end
	return table.concat(t, " ")
end
local function counts()
	local t = {}
	for _, team in ipairs(Spring.GetTeamList()) do
		local _, leader, dead, isAI, side, ally = Spring.GetTeamInfo(team, false)
		t[#t + 1] = string.format("team%d(ally%s ai=%s dead=%s units=%d)", team, tostring(ally), tostring(isAI), tostring(dead), #Spring.GetTeamUnits(team))
	end
	return table.concat(t, " ")
end
function widget:Initialize() log("widget loaded, mode", mode, "me", tostring(Spring.GetMyPlayerID()), tostring((Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)))) end
function widget:GameStart() log("GameStart") end
function widget:GameFrame(f)
	local me = select(1, Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false))
	if f % 300 == 0 and f ~= lastLog then
		lastLog = f
		log("frame", f, "me", tostring(me), "|", players())
		log("  teams:", counts())
		if mode == "ctf" then
			log("  ctf state=", gp("ctfState"), "target", gp("ctfTarget"), "teams", gp("ctfTeams"),
				"score0", gp("ctfScore0"), "score1", gp("ctfScore1"), "out", gp("ctfOut"))
		elseif mode == "evo" then
			local t = {}
			for team in tostring(gp("evoTeams")):gmatch("%d+") do
				local function tp(k) return tostring(Spring.GetTeamRulesParam(tonumber(team), k)) end
				t[#t + 1] = string.format("team%s stage=%s xp=%s/%s kills=%s deaths=%s unit=%s", team, tp("evoStage"), tp("evoXp"), tp("evoNeed"), tp("evoKills"), tp("evoDeaths"), tp("evoName"))
			end
			log("  evo state=", gp("evoState"), table.concat(t, " | "), "| gaia units", tostring(#Spring.GetTeamUnits(Spring.GetGaiaTeamID())))
		elseif mode == "td" then
			log("  td state=", gp("tdState"), "wave", gp("tdWave"), "/", gp("tdWaves"), "leaks", gp("tdLeaks"), "killed", gp("tdKilled"))
		else
			log("  rtf state=", gp("rtfState"), "target", gp("rtfTarget"), "teams", gp("rtfTeams"),
				"score0", gp("rtfScore0"), "score1", gp("rtfScore1"), "rate0", gp("rtfRate0"), "rate1", gp("rtfRate1"))
		end
	end
	-- orders: PlayerA (team 0) and PlayerB (team 1) each steer their own team
	if (me == "PlayerA" or me == "PlayerB") and not ordered and f >= 120 then
		ordered = true
		local team = Spring.GetMyTeamID()
		local sent = 0
		local fast, builder, homeX = "armflash", "armck", 4800
		if me == "PlayerB" then fast, builder, homeX = "corgator", "corck", 7488 end
		for _, u in ipairs(Spring.GetTeamUnits(team)) do
			local def = UnitDefs[Spring.GetUnitDefID(u)].name
			if mode == "ctf" and def == fast and sent < 3 then
				local z = ({ 5600, 6144, 6688 })[sent + 1]
				Spring.GiveOrderToUnit(u, CMD.MOVE, { 6144, 449, z }, {})
				Spring.GiveOrderToUnit(u, CMD.MOVE, { homeX, 449, 6144 }, { "shift" })
				sent = sent + 1
			elseif mode == "rtf" and def == builder then
				Spring.GiveOrderToUnit(u, CMD.RECLAIM, { 6144, 449, 6144, 120 }, {})
				sent = sent + 1
			end
		end
		log("orders given by", me, "to", tostring(sent), "units of team", tostring(team))
	end
	if mode == "cp" and (f == 60 or f == 900) then
		local team = Spring.GetMyTeamID()
		for _, u in ipairs(Spring.GetTeamUnits(team)) do
			local x, _, z = Spring.GetUnitPosition(u)
			local cmds = Spring.GetUnitCommands(u, 0) or 0
			log(string.format("  census f%d team%d %s at %.0f,%.0f commands=%s", f, team, UnitDefs[Spring.GetUnitDefID(u)].name, x, z, tostring(cmds)))
		end
	end
	if mode == "cp" then
		local team = Spring.GetMyTeamID()
		local com
		for _, u in ipairs(Spring.GetTeamUnits(team)) do if UnitDefs[Spring.GetUnitDefID(u)].customParams.iscommander then com = u end end
		if com and f % 150 == 0 then local x, _, z = Spring.GetUnitPosition(com); log("  commander of team", tostring(team), "at", string.format("%.0f,%.0f", x, z), "seen by", tostring(me)) end
		if com and me == "PlayerA" and f == 150 then Spring.GiveOrderToUnit(com, CMD.MOVE, { 5200, 449, 6144 }, {}); log("PlayerA orders east") end
		if com and me == "PlayerB" and f == 900 then Spring.GiveOrderToUnit(com, CMD.MOVE, { 3600, 449, 6144 }, {}); log("PlayerB orders west") end
	end
	-- Evolution: every 10 s the own unit fights its way to a random place in the middle of the map (it meets wild units and the other player there)
	if mode == "evo" and f % 300 == 150 and (me == "PlayerA" or me == "PlayerB") then
		local id = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoUnit")
		if id and id > 0 and Spring.ValidUnitID(id) then
			local x, z = Game.mapSizeX * (0.3 + 0.4 * math.random()), Game.mapSizeZ * (0.3 + 0.4 * math.random())
			Spring.GiveOrderToUnit(id, CMD.FIGHT, { x, Spring.GetGroundHeight(x, z), z }, {})
		end
	end
	-- Evolution: pictures of the host's game (the engine's own screenshot, in screenshots\ of the write dir; a picture of the window from outside comes out white)
	if mode == "evo" and me == "PlayerA" and (f == 2400 or f == 5400 or f == 8400) then
		local x, y, z = Spring.GetUnitPosition(Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoUnit") or -1)
		if x then Spring.SetCameraTarget(x, y, z, 0) end
	end
	if mode == "evo" and me == "PlayerA" and (f == 2460 or f == 5460 or f == 8460) then
		Spring.SendCommands("screenshot png")
		log("screenshot at frame", f)
	end
	if f >= QUIT then log("quit at frame", f); Spring.SendCommands("quitforce") end
end
