function widget:GetInfo() return { name = "zz split ally", desc = "test only: split and focus attack never target own or allied units", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_split_ally.lua: three armies (20 units of team 0, 10 of team 1, 10 of team 2); the teams 0 and 2 are put in one
-- group (allied, Spring.SetAlly by the gadget). Team 0 is selected and attacks with the focus attack (MODE) a circle that covers all three armies.
-- Logs "[zzal]" lines: the teams of the targets of the attack orders (only team 1 is right), ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzal] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local Shared = VFS.Include("luaui/Include/editor_common.lua", nil, VFS.ZIP_FIRST)
local MX, MZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local MODE = "focus" -- or "split"
local ar, tm, area
local mouse = { 0, 0 }
local later = {}
local function after(n, fn) later[#later + 1] = { at = Spring.GetGameFrame() + n, fn = fn } end
local function army(team)
	local out = {}
	for _, id in ipairs(Spring.GetAllUnits()) do
		if Spring.GetUnitRulesParam(id, "arena") == 1 and Spring.GetUnitTeam(id) == team then out[#out + 1] = id end
	end
	return out
end
local function rect(kind, value)
	for _, v in pairs({ W():DebugLayout() }) do
		if type(v) == "table" then
			for _, r in ipairs(v) do
				if type(r) == "table" and r.kind == kind and r.x1 and (value == nil or r.value == value) then return r end
			end
		end
	end
end
local function click(r)
	if not r then log("NO BUTTON") return end
	local x, y = (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2
	W():MousePress(x, y, 1)
	W():MouseRelease(x, y, 1)
end

local steps = {}
steps[40] = function()
	ar = W():DebugArena()
	tm = W():DebugTeams()
	tm.setGroup(0, 3)
	tm.setGroup(2, 3)
	click(rect("ar", "ar"))
	local c = ar.cfg(true)
	c.radius = 450
	for i = 1, 10 do c.rows[i].allowed, c.rows[i].count, c.rows[i].on = {}, (i == 1) and 20 or 10, i <= 3 end
	ar.setAllowed(1, { "armpw" }, true)
	ar.setAllowed(2, { "corthud" }, true)
	ar.setAllowed(3, { "armham" }, true)
end
steps[100] = function() ar.startPick("gen"); ar.click(MX, MZ) end
steps[260] = function()
	log("allied 0/2:", tostring(Spring.AreTeamsAllied(0, 2)), "allied 0/1:", tostring(Spring.AreTeamsAllied(0, 1)))
	local mine = army(0)
	log("armies", #mine, #army(1), #army(2))
	Spring.SelectUnitArray(mine)
	area = Shared.newAreaAttack({ say = function(s) log("say:", s) end, mouseGround = function() return mouse[1], mouse[2] end })
	area:toggle(MODE)
	mouse = { MX, MZ }
	area:press(1)
	mouse = { MX + 1500, MZ }
	area:release()
	after(4, function()
		local byTeam = {}
		for _, id in ipairs(mine) do
			local _, _, _, tid = Spring.GetUnitCurrentCommand(id, 1)
			local team = tid and Spring.GetUnitTeam(tid)
			byTeam[tostring(team)] = (byTeam[tostring(team)] or 0) + 1
		end
		local parts = {}
		for k, v in pairs(byTeam) do parts[#parts + 1] = "team " .. k .. ": " .. v .. " units" end
		table.sort(parts)
		log("first targets by team:", table.concat(parts, ", "))
		-- all queued targets
		local bad = 0
		for _, id in ipairs(mine) do
			for _, c in ipairs(Spring.GetUnitCommands(id, 10) or {}) do
				local tid = c.params and c.params[1]
				local team = tid and Spring.GetUnitTeam(tid)
				if team == 0 or team == 2 then bad = bad + 1 end
			end
		end
		log("orders on own or allied units:", bad, bad == 0 and "OK" or "FAILED")
		log("END")
		Spring.SendCommands("quitforce")
	end)
end

function widget:GameFrame(n)
	for i = #later, 1, -1 do
		local l = later[i]
		if n >= l.at then
			table.remove(later, i)
			local ok, err = pcall(l.fn)
			if not ok then log("TEST ERROR later", tostring(err)) end
		end
	end
end

local done = {}
function widget:Update()
	local f0 = Spring.GetGameFrame()
	local keys = {}
	for k in pairs(steps) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		if k <= f0 and not done[k] then
			done[k] = true
			local ok, err = pcall(steps[k])
			if not ok then log("TEST ERROR at", k, tostring(err)) end
			break
		end
	end
end
