function widget:GetInfo() return { name = "zz mix", desc = "test only: Raptors vs Scavengers", layer = 1000000, enabled = true } end
local function log(...) local t = {} for i, v in ipairs({ ... }) do t[i] = tostring(v) end Spring.Echo("[zzmix] " .. table.concat(t, " ")) end
local ai = {}   -- teamID -> name
local kills = {}  -- "a>b" -> n
local MAX = 30000
function widget:Initialize()
	for _, t in ipairs(Spring.GetTeamList()) do
		local ok, a = pcall(Spring.GetTeamLuaAI, t)
		if ok and a and a ~= "" then ai[t] = a end
		log("allied 1-2", tostring(Spring.AreTeamsAllied(1, 2)), "team", t, "ally", select(6, Spring.GetTeamInfo(t, false)), "luaAI", tostring(a), "players", #Spring.GetPlayerList(t))
	end
end
function widget:UnitDamaged(id, def, team, dmg, para, wdef, proj, attacker, attDef, attTeam)
	if attTeam and attTeam ~= team and dmg and dmg > 0 then local k = tostring(ai[attTeam] or attTeam) .. ">" .. tostring(ai[team] or team); kills[k] = (kills[k] or 0) + 1 end
end
function widget:UnitDestroyed(id, def, team, attacker, attDef, attTeam)
	if ai[team] then local k = "dead:" .. ai[team] .. " by " .. tostring(attTeam and (ai[attTeam] or ("team" .. attTeam)) or "nobody"); kills[k] = (kills[k] or 0) + 1 end
end
local lastUn = 0
function widget:Update()
	local _, _, paused = Spring.GetGameSpeed()
	if paused and os.clock() - lastUn > 1 then lastUn = os.clock(); Spring.SendCommands("pause 0") end
end
function widget:GameFrame(n)
	if n == 3 then Spring.SendCommands("cheat 1"); Spring.SendCommands("globallos"); Spring.SendCommands("setspeed 20") end
	if n % 1800 == 0 then
		local parts = {}
		for t, a in pairs(ai) do parts[#parts + 1] = a .. "=" .. #(Spring.GetTeamUnits(t) or {}) end
		local ks = {}
		for k, v in pairs(kills) do ks[#ks + 1] = k .. ":" .. v end
		log("frame", n, "units", table.concat(parts, " "), "cross kills", table.concat(ks, " "))
	end
	if n % 1800 == 0 and n > 9000 then
		local rt, st
		for t2, a2 in pairs(ai) do if a2:find("Raptors") then rt = t2 else st = t2 end end
		local best, bi = 1e9
		local sx, sz, sn = 0, 0, 0
		for _, u in ipairs(Spring.GetTeamUnits(st) or {}) do local x, _, z = Spring.GetUnitPosition(u); if x then sx, sz, sn = sx + x, sz + z, sn + 1 end end
		local ru = Spring.GetTeamUnits(rt) or {}
		local near, tgt = 0, {}
		for _, r in ipairs(ru) do
			local rx, _, rz = Spring.GetUnitPosition(r)
			for _, u in ipairs(Spring.GetTeamUnits(st) or {}) do
				local x, _, z = Spring.GetUnitPosition(u)
				if x and rx then local d = math.sqrt((x - rx) ^ 2 + (z - rz) ^ 2); if d < best then best = d end; if d < 600 then near = near + 1; break end end
			end
			if #tgt < 3 then local c = Spring.GetUnitCommands(r, 1); if c and c[1] and c[1].params then tgt[#tgt + 1] = (c[1].id or "?") .. ":" .. math.floor(c[1].params[1] or 0) .. "," .. math.floor(c[1].params[3] or 0) end end
		end
		log("distance raptor-scav min", math.floor(best), "raptors within 600 of a scav unit", near, "scav center", sn > 0 and (math.floor(sx / sn) .. "," .. math.floor(sz / sn)) or "-", "raptor orders", table.concat(tgt, " "))
	end
	if n >= MAX then log("END"); Spring.SendCommands("quitforce") end
end
