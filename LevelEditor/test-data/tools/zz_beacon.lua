function widget:GetInfo() return { name = "zz beacon", desc = "test only: Evolution power-up beacons of powerups.lua: a unit drives over one, takes the power-up, the beacon comes back", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Widget zz_beacon.lua: the own unit drives to the nearest beacon (game rule evoBeacons); lines "[zzbeacon]": the beacons at the start, the
-- distance on the way, the power-ups of the team (team rule evoAbilities) after the pick-up, the number of beacons after the taken one has come back (45 s later).
local function log(...) Spring.Echo("[zzbeacon] " .. table.concat({ ... }, " ")) end
local function beacons()
	local list = {}
	for x, z, k in tostring(Spring.GetGameRulesParam("evoBeacons") or ""):gmatch("(%d+),(%d+),(%d+)") do list[#list + 1] = { x = tonumber(x), z = tonumber(z), kind = tonumber(k) } end
	return list
end
local goal, kindWanted, before
function widget:GameFrame(f)
	local team = Spring.GetMyTeamID()
	local unit = Spring.GetTeamRulesParam(team, "evoUnit")
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10") end
	if f == 60 then
		local list = beacons()
		before = #list
		local ux, _, uz = Spring.GetUnitPosition(unit)
		local best
		for _, b in ipairs(list) do
			local d = math.sqrt((b.x - ux) ^ 2 + (b.z - uz) ^ 2)
			if not best or d < best.d then best = { b = b, d = d } end
		end
		log("beacons at the start", tostring(#list), "unit at", string.format("%.0f %.0f", ux, uz), "nearest", best and string.format("%d %d kind %d distance %.0f", best.b.x, best.b.z, best.b.kind, best.d) or "none")
		if best then
			goal, kindWanted = best.b, best.b.kind
			Spring.GiveOrderToUnit(unit, CMD.MOVE, { goal.x, Spring.GetGroundHeight(goal.x, goal.z), goal.z }, 0)
		end
	end
	if goal and f > 60 and f % 300 == 0 then
		local ux, _, uz = Spring.GetUnitPosition(unit)
		log("frame", tostring(f), "distance to the beacon", ux and string.format("%.0f", math.sqrt((goal.x - ux) ^ 2 + (goal.z - uz) ^ 2)) or "?", "abilities", tostring(Spring.GetTeamRulesParam(team, "evoAbilities")), "beacons", tostring(#beacons()))
	end
	if goal and f % 30 == 0 and not goal.done then
		local have = tostring(Spring.GetTeamRulesParam(team, "evoAbilities") or "")
		if have:find("^" .. kindWanted .. ":") or have:find("," .. kindWanted .. ":") then
			goal.done = f
			log("took the power-up", tostring(kindWanted), "at frame", tostring(f), "abilities", have, "beacons now", tostring(#beacons()))
		end
	end
	if goal and goal.done and f == goal.done + 1500 then
		log("45 s later: beacons", tostring(#beacons()), "(at the start", tostring(before) .. ")")
		Spring.SendCommands("quitforce")
	end
	if f > 6000 then log("timeout: the unit did not reach the beacon") Spring.SendCommands("quitforce") end
end
