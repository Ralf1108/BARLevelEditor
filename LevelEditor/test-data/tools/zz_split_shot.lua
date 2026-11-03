function widget:GetInfo() return { name = "zz split shot", desc = "test only: the picture of the split attack for the README", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_split_shot.lua: the Arena generates 20 light units (team 0) and 10 heavier ones (team 1) 600 Elmo apart,
-- team 0 is selected and attacks team 1 with the split attack. Right after the order every unit keeps only its first target (the plan of the
-- split attack without the surplus target at the end of every queue), so the command lines of the selected units show who is aimed at whom;
-- the circle is drawn by this widget. Two screenshots: with the interface and without. Logs "[zzsp]" lines (units per enemy), ends with quitforce.
local lines = {}
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	lines[#lines + 1] = "[zzsp] " .. table.concat(t, " ")
end
local function W() return WG.LevelEditorWidget end
local Shared = VFS.Include("luaui/Include/editor_common.lua", nil, VFS.ZIP_FIRST)
local MX, MZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local LIGHT, HEAVY = "armpw", "corcan"
local ar, area, ring
local assign = {} -- unit -> its target (drawn as a colored line, one color per enemy)
local colorOf = {}
local PALETTE = { { 1, 0.25, 0.2 }, { 0.2, 0.9, 0.3 }, { 1, 0.85, 0.1 }, { 0.2, 0.8, 1 }, { 1, 0.4, 0.9 }, { 1, 0.6, 0.1 }, { 0.6, 0.5, 1 }, { 0.1, 1, 0.8 }, { 0.9, 0.9, 0.9 }, { 0.6, 1, 0.2 } }
local mouse = { 0, 0 }
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
local function camera(cx, cz, dist)
	local st = Spring.GetCameraState()
	st.name, st.mode = "spring", 2
	st.px, st.py, st.pz, st.dist, st.rx, st.ry, st.rz, st.fov = cx, Spring.GetGroundHeight(cx, cz), cz, dist, 2.3, 0, 0, 45
	Spring.SetCameraState(st, 0)
end

local later = {} -- { at = frame, fn }: steps after the order (the orders of the units arrive one frame later)
local function after(n, fn) later[#later + 1] = { at = Spring.GetGameFrame() + n, fn = fn } end
local steps = {}
steps[40] = function()
	ar = W():DebugArena()
	click(rect("ar", "ar"))
	local c = ar.cfg(true)
	c.radius = 300
	for i = 1, 10 do c.rows[i].allowed, c.rows[i].count, c.rows[i].on = {}, (i == 1) and 20 or 10, i <= 2 end
	ar.setAllowed(1, { LIGHT }, true)
	ar.setAllowed(2, { HEAVY }, true)
	camera(MX, MZ, 1800)
end
steps[100] = function() ar.startPick("gen"); ar.click(MX, MZ) end
steps[220] = function()
	click(rect("ar", "ar")) -- the page closes
	ar.cfg(true).point = nil -- no marker of the Arena Point in the picture
	local mine, foe = army(0), army(1)
	log("armies", #mine, #foe)
	Spring.SelectUnitArray(mine)
	local cx, cz = 0, 0
	for _, id in ipairs(foe) do local x, _, z = Spring.GetUnitPosition(id); cx, cz = cx + x, cz + z end
	cx, cz = cx / #foe, cz / #foe
	local mx, mz = 0, 0
	for _, id in ipairs(mine) do local x, _, z = Spring.GetUnitPosition(id); mx, mz = mx + x, mz + z end
	mx, mz = mx / #mine, mz / #mine
	local r = 230
	area = Shared.newAreaAttack({ say = function(s) log("say:", s) end, mouseGround = function() return mouse[1], mouse[2] end })
	area:toggle("split")
	mouse = { cx, cz }
	area:press(1)
	mouse = { cx + r, cz }
	area:release()
	ring = { x = cx, z = cz, r = r }
	after(3, function()
		-- only the first target of every unit stays, then count the units per enemy
		local per = {}
		for _, id in ipairs(mine) do
			local _, _, _, tid = Spring.GetUnitCurrentCommand(id, 1)
			if tid then
				Spring.GiveOrderToUnit(id, CMD.ATTACK, { tid }, {})
				per[tid] = (per[tid] or 0) + 1
				assign[id] = tid
			end
		end
		for i, id in ipairs(foe) do colorOf[id] = PALETTE[(i - 1) % #PALETTE + 1] end
		Spring.SelectUnitArray({}) -- no selection: the lines of the engine are gone, the colored ones show the plan
		local hist = {}
		for _, id in ipairs(foe) do hist[#hist + 1] = tostring(per[id] or 0) end
		log("units per enemy:", table.concat(hist, " "))
		camera((cx + mx) / 2, (cz + mz) / 2, 900)
	end)
	after(30, function() Spring.SendCommands("screenshot png"); log("screenshot with the interface") end)
	after(45, function() Spring.SendCommands("hideinterface 1") end)
	after(110, function() Spring.SendCommands("screenshot png"); log("screenshot without the interface") end)
	after(130, function()
		log("END")
		for _, l in ipairs(lines) do Spring.Echo(l) end
		Spring.SendCommands("quitforce")
	end)
end
local function ringAround(x, z, r, c)
	gl.Color(c[1], c[2], c[3], 0.95)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for k = 0, 23 do
			local px, pz = x + r * math.cos(k * math.pi / 12), z + r * math.sin(k * math.pi / 12)
			gl.Vertex(px, Spring.GetGroundHeight(px, pz) + 10, pz)
		end
	end)
end
function widget:DrawWorld()
	if not ring then return end
	gl.DepthTest(false)
	gl.LineWidth(3)
	for id, tid in pairs(assign) do
		local x, y, z = Spring.GetUnitPosition(id)
		local tx, ty, tz = Spring.GetUnitPosition(tid)
		local c = colorOf[tid]
		if x and tx and c then
			gl.Color(c[1], c[2], c[3], 0.95)
			gl.BeginEnd(GL.LINES, function()
				gl.Vertex(x, y + 14, z)
				gl.Vertex(tx, ty + 14, tz)
			end)
			ringAround(x, z, 22, c)
		end
	end
	for tid, c in pairs(colorOf) do
		local tx, _, tz = Spring.GetUnitPosition(tid)
		if tx then ringAround(tx, tz, 40, c) end
	end
	gl.LineWidth(3)
	gl.Color(1, 0.7, 0.2, 0.95)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for k = 0, 71 do
			local x, z = ring.x + ring.r * math.cos(k * math.pi / 36), ring.z + ring.r * math.sin(k * math.pi / 36)
			gl.Vertex(x, Spring.GetGroundHeight(x, z) + 8, z)
		end
	end)
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
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
