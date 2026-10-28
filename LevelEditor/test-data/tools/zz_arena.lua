function widget:GetInfo() return { name = "zz arena", desc = "test only: plays through the Arena page", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1: works the Arena page through WG.LevelEditorWidget (DebugArena returns the page) and logs "[zzar]" lines.
-- One step per game frame number (steps[frame]); ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local ar
local before = {}

local function arenaUnits(team)
	local out = {}
	for _, id in ipairs(Spring.GetAllUnits()) do
		if Spring.GetUnitRulesParam(id, "arena") == 1 and (team == nil or Spring.GetUnitTeam(id) == team) then out[#out + 1] = id end
	end
	return out
end
local function stats(team)
	local ids = arenaUnits(team)
	local sx, sz, m = 0, 0, 0
	for _, id in ipairs(ids) do
		local x, _, z = Spring.GetUnitPosition(id)
		sx, sz = sx + x, sz + z
		m = m + (UnitDefs[Spring.GetUnitDefID(id)].metalCost or 0)
	end
	local n = #ids
	return n, n > 0 and sx / n or 0, n > 0 and sz / n or 0, m
end
local function report(label)
	for t = 0, 3 do
		local n, x, z, m = stats(t)
		log(label, "team", t, "arena units", n, string.format("center %.0f,%.0f metal %d", x, z, m))
	end
	local c = ar.cfg()
	log(label, "point", c.point and (c.point.x .. "," .. c.point.z) or "none", "armies", #c.armies, "state", ar.state())
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
local function pageRect(kind, field, row)
	local _, content = W():DebugLayout()
	local rects = ar.layout(content)
	for _, r in ipairs(rects) do
		if r.kind == kind and (field == nil or r.field == field) and (row == nil or r.row == row) then return r end
	end
end
local function shot(name)
	Spring.SendCommands("screenshot png")
	log("screenshot", name)
end

local steps = {}
local MX, MZ = Game.mapSizeX / 2, Game.mapSizeZ / 2

steps[40] = function()
	ar = W() and W():DebugArena()
	log("widget", tostring(W()), "arena page", tostring(ar))
	local r = rect("ar", "ar")
	log("button A", r and string.format("%.0f,%.0f active=%s", r.x1, r.y1, tostring(r.active)) or "missing")
	local td, g = rect("td", "td"), rect("top", "gen")
	if r and td and g then log("order top->bottom: G", g.y1, "A", r.y1, "TD", td.y1, g.y1 > r.y1 and r.y1 > td.y1 and "OK" or "WRONG") end
	click(r)
	log("page open", ar.open)
end

steps[50] = function()
	-- the editor game has ten teams; only teams 0 and 1 keep their start commander
	local out = {}
	for t = 0, 9 do out[#out + 1] = t .. ":" .. #Spring.GetTeamUnits(t) end
	log("units per team at the start", table.concat(out, " "))
	log("max units of team 0 / 1 / Gaia:", Spring.GetTeamMaxUnits(0), Spring.GetTeamMaxUnits(1), Spring.GetTeamMaxUnits(Spring.GetGaiaTeamID()))
end

steps[60] = function()
	local c = ar.cfg(true)
	c.radius = 3000
	for i = 1, 4 do c.rows[i].allowed = {} end
	c.rows[1].on, c.rows[2].on, c.rows[3].on, c.rows[4].on = true, true, true, false
	ar.setAllowed(1, { "armpw" }, true); c.rows[1].count = 30
	ar.setAllowed(2, { "corak", "corthud" }, true); c.rows[2].count = 30
	ar.setAllowed(3, { "armflash", "armstump" }, true); c.rows[3].metal = 12000; c.rows[3].count = nil
	ar.setAllowed(4, { "armpw" }, true)
	log("rows set", #c.rows[1].allowed, #c.rows[2].allowed, #c.rows[3].allowed, "isAllowed armpw/corak", ar.isAllowed(1, "armpw"), ar.isAllowed(1, "corak"))
	-- the text of the buttons
	local u1 = pageRect("arunits", nil, 1)
	log("Units button row 1:", u1 and u1.label, "tint", u1 and u1.tint and "green" or "gray")
	local u4 = pageRect("arunits", nil, 5)
	log("Units button row 5:", u4 and u4.label, "tint", u4 and u4.tint and "green" or "gray")
	shot("page")
end

steps[100] = function()
	before.total = Spring.GetGameFrame()
	ar.startPick("gen")
	log("pick", ar.pick)
	ar.click(MX, MZ) -- the click on the map
	log("generate clicked at", MX, MZ)
end

steps[260] = function()
	report("after Generate")
	local n1 = stats(0)
	log("army 1 count 30:", n1 == 30 and "OK" or "WRONG (" .. n1 .. ")")
	local _, _, _, m3 = stats(2)
	log("army 3 budget (12000 minus the commander):", m3 > 0 and m3 <= 12000 and "OK" or "WRONG (" .. m3 .. ")")
	local n4 = stats(3)
	log("row 4 off:", n4 == 0 and "OK" or "WRONG (" .. n4 .. ")")
	-- distance of the armies from the point (radius 3000, three armies)
	for t = 0, 2 do
		local n, x, z = stats(t)
		log("distance of army", t, string.format("%.0f", math.sqrt((x - MX) ^ 2 + (z - MZ) ^ 2)))
	end
	before.n = #arenaUnits()
	before.state = ar.state()
	before.x0 = ar.cfg().point.x
	local _, tx0, tz0 = stats(0)
	before.tx0, before.tz0 = tx0, tz0
	-- the window of the units of army 1
	ar.winRow = 1
	local list = ar.units:list()
	log("unit window row 1: group", ar.units.group, "tiles", #list, "rect", ar.winRect() and "ok" or "nil")
end

steps[275] = function()
	-- a few frames after the window was opened: it has been drawn
	local c = ar.cfg()
	local w = ar.winRect()
	log("window rect", w and string.format("%.0f..%.0f x %.0f..%.0f", w.x1, w.x2, w.y0, w.top) or "none", "allowed in row 1:", #c.rows[1].allowed)
	shot("window")
end

steps[300] = function()
	ar.winRow = nil
	-- the whole setup moves 600 Elmo east (Shift + Alt + drag, on release)
	local c = ar.cfg(true)
	local old = ar.state()
	local x0, z0 = c.point.x, c.point.z
	c.point.x = x0 + 600
	ar.moveSetup({ before = old, x0 = x0, z0 = z0, whole = true })
	log("moveSetup done")
end

steps[400] = function()
	report("after move")
	local n, x, z = stats(0)
	log("army 1 flag kept:", n == 30 and "OK" or "WRONG (" .. n .. " units with the flag)", string.format("moved by %.0f, %.0f (expected 600, 0 unless pushed back at the map edge)", x - before.tx0, z - before.tz0))
	Spring.SendLuaRulesMsg("led|undo|1")
	log("undo move sent")
end

steps[470] = function()
	report("after undo of the move")
	log("point back at", ar.cfg().point and ar.cfg().point.x or "none", "expected", before.x0)
	Spring.SendLuaRulesMsg("led|undo|1")
	log("undo Generate sent")
end

steps[560] = function()
	report("after undo of Generate")
	log("units gone:", #arenaUnits() == 0 and "OK" or "WRONG", "point gone:", ar.cfg().point == nil and "OK" or "WRONG")
	Spring.SendLuaRulesMsg("led|redo|1")
	log("redo Generate sent")
end

steps[700] = function()
	report("after redo of Generate")
	log("units back with the flag:", #arenaUnits() == before.n and "OK" or "WRONG (" .. #arenaUnits() .. " of " .. before.n .. ")", "state same:", ar.state() == before.state and "OK" or "DIFFERENT")
end

steps[740] = function()
	-- Start
	ar.toggle()
	log("Start: arenaState", Spring.GetGameRulesParam("arenaState"))
	local f = io.open("LevelEditor/_beforeplay.lua", "r")
	log("_beforeplay saved:", f and "yes" or "NO")
	if f then f:close() end
end

steps[790] = function()
	local ids = arenaUnits()
	local fight, other = 0, 0
	for _, id in ipairs(ids) do
		local cmds = Spring.GetUnitCommands(id, 3) or {}
		local f = false
		local atk = false
		for _, c in ipairs(cmds) do
			if c.id == CMD.FIGHT then f = true end
			if c.id == CMD.ATTACK then atk = true end
		end
		if f then fight = fight + 1 else other = other + 1 end
		if f and atk then before.attackQueued = (before.attackQueued or 0) + 1 end
	end
	log("units with the fight order:", fight, "without:", other, "(the area attack is queued in phase 2, not at the start):", before.attackQueued or 0)
	before.march = {}
	for t = 0, 2 do before.march[t] = { stats(t) } end
	shot("running")
end

steps[1000] = function()
	-- the armies shall walk at the same speed (slowest unit) and keep their rectangle: distance walked per team in 7 seconds
	for t = 0, 2 do
		local _, x, z = stats(t)
		local m = before.march[t]
		log("march team", t, string.format("walked %.0f Elmo", math.sqrt((x - m[2]) ^ 2 + (z - m[3]) ^ 2)))
	end
end

steps[1300] = function()
	report("fight")
	log("units left", #arenaUnits(), "of", before.n)
	shot("fight")
	ar.toggle() -- Stop
	log("Stop sent, arenaState", Spring.GetGameRulesParam("arenaState"))
end

steps[1500] = function()
	report("after Stop")
	log("restored:", #arenaUnits() == before.n and "OK" or "WRONG (" .. #arenaUnits() .. " of " .. before.n .. ")", "arenaState", tostring(Spring.GetGameRulesParam("arenaState")))
	ar.clear()
	log("Clear sent")
end

steps[1650] = function()
	report("after Clear")
	log("cleared:", #arenaUnits() == 0 and ar.cfg().point == nil and "OK" or "WRONG")
	-- a button that must not fail: copy to table, switch a row, a field
	-- the menu "Copy to": click the team number of row 2, then team 3 (value 4)
	click(pageRect("arteam", nil, 2))
	local _, content = W():DebugLayout()
	local pop = ar.copyPopup(ar.layout(content))
	log("copy menu items", pop and #pop or "none")
	for _, r in ipairs(pop or {}) do
		if r.value == 4 then click(r) end
	end
	local r4 = ar.cfg().rows[4]
	log("copy row 2 to team 3:", (#r4.allowed == 2 and r4.on) and "OK" or "WRONG", #r4.allowed, tostring(r4.on))
	click(pageRect("arcol"))
	click(pageRect("aron", nil, 4))
	log("copy / on buttons clicked, row 4 on:", ar.cfg().rows[4].on)
	log("END")
	Spring.SendCommands("quitforce")
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
