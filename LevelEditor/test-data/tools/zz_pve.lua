function widget:GetInfo() return { name = "zz pve", desc = "test only: orders to the units of a Scavengers / Raptors AI team", layer = 1000000, enabled = true } end
-- Test widget of pve_test.ps1: a sandbox game with one human and a Raptors or Scavengers AI. It speeds the game up, waits until the AI team has mobile units,
-- counts how many of them have an order that the AI gave (gadget lan_pve_hold.lua should drop those), then gives some of them a move order as the human
-- player and looks whether it was accepted. Logs "[zzpve]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzpve] " .. table.concat(t, " "))
end

local aiTeam, aiName
local phase = "wait"
local given = {}   -- unitID -> { x, z } the move order the human gave
local doneFrame
local best = { units = 0, queued = 0 }
local MAX_FRAME = 90000

local function findAiTeam()
	for _, t in ipairs(Spring.GetTeamList()) do
		local ok, ai = pcall(Spring.GetTeamLuaAI, t)
		if ok and ai and (ai:find("Raptors", 1, true) or ai:find("Scavengers", 1, true)) then return t, ai end
	end
end

local function mobileUnits()
	local out = {}
	for _, id in ipairs(Spring.GetTeamUnits(aiTeam) or {}) do
		local def = UnitDefs[Spring.GetUnitDefID(id)]
		if def and def.canMove and not def.isBuilding then out[#out + 1] = id end
	end
	return out
end

local function queued(id)
	local ok, n = pcall(Spring.GetUnitCommands, id, 0)
	return ok and tonumber(n) or 0
end

function widget:Initialize()
	aiTeam, aiName = findAiTeam()
	log("AI team", aiTeam, aiName, "my team", Spring.GetMyTeamID(), "ally team of the AI", aiTeam and select(6, Spring.GetTeamInfo(aiTeam, false)), "mine", select(6, Spring.GetTeamInfo(Spring.GetMyTeamID(), false)))
	log("gadget option lanpvehold =", tostring((Spring.GetModOptions() or {}).lanpvehold))
end

local lastUnpause = 0
function widget:Update()
	-- the game may pause itself (a gadget of the game); the test goes on
	local _, _, paused = Spring.GetGameSpeed()
	if paused and os.clock() - lastUnpause > 1 then
		lastUnpause = os.clock()
		log("the game is paused: unpausing")
		Spring.SendCommands("pause 0")
	end
end

function widget:GameFrame(n)
	if n == 3 then
		Spring.SendCommands("cheat 1")
		Spring.SendCommands("setspeed 20")
	end
	if n > MAX_FRAME then log("FAIL timeout: no mobile unit of the AI team appeared"); Spring.SendCommands("quitforce"); return end
	if n % 30 ~= 0 or not aiTeam then return end
	local units = mobileUnits()
	if phase == "wait" then
		local withQueue = 0
		for _, id in ipairs(units) do if queued(id) > 0 then withQueue = withQueue + 1 end end
		if #units > best.units then best.units = #units end
		if withQueue > best.queued then best.queued = withQueue end
		if n % 900 == 0 then log("frame", n, "mobile units of the AI team", #units, "with an order", withQueue, "all units", #(Spring.GetTeamUnits(aiTeam) or {})) end
		if #units >= 4 and n >= 600 then
			-- let the spawner give its orders first (a few seconds), then measure
			best.queued = 0; phase = "measure"; doneFrame = n + 900
			log("frame", n, #units, "mobile units: waiting for the AI's orders")
		end
	elseif phase == "measure" then
		local withQueue = 0
		for _, id in ipairs(units) do if queued(id) > 0 then withQueue = withQueue + 1 end end
		if withQueue > best.queued then best.queued = withQueue end
		if n < doneFrame then return end
		log("RESULT units with an order of the AI (most at one time in the last 30 s):", best.queued, "of", #units, "(mobile units of the AI team)", best.queued == 0 and "OK none" or "FAIL some")
		for i = 1, math.min(3, #units) do
			local id = units[i]
			local x, y, z = Spring.GetUnitPosition(id)
			given[id] = { x = x + 300, z = z + 300 }
			Spring.GiveOrderToUnit(id, CMD.MOVE, { x + 300, y, z + 300 }, 0)
		end
		phase = "check"; doneFrame = n + 60
	elseif phase == "check" and n >= doneFrame then
		local ok, total = 0, 0
		for id, p in pairs(given) do
			total = total + 1
			local cmds = Spring.GetUnitCommands(id, 3) or {}
			local first = cmds[1]
			local mine = first and first.id == CMD.MOVE and first.params and math.abs((first.params[1] or 0) - p.x) < 2 and math.abs((first.params[3] or 0) - p.z) < 2
			log("unit", id, "queue", #cmds, "first", first and first.id, "my move order", mine and "kept" or "NOT kept")
			if mine then ok = ok + 1 end
		end
		log("RESULT orders of the human player kept:", ok, "of", total, ok == total and total > 0 and "OK" or "FAIL")
		phase = "end"; doneFrame = n + 60
	elseif phase == "end" and n >= doneFrame then
		Spring.SendCommands("quitforce")
	end
end
