function widget:GetInfo() return { name = "zz area shot", desc = "test only: the picture of the area attack (XR) for the README", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_area_shot.lua: the Arena generates one army of artillery and long range rocket launchers (team 0), then the area
-- attack XR (Shared.newAreaAttack, mode "rect") is dragged over a rectangle in front of them. Right after the order the widget reads the target point
-- of every unit and draws the rectangle (orange), the target points (red squares) and a thin line from every unit to its point; the shells come while the
-- pictures are taken (interface hidden). Logs "[zzarea]" lines, ends with quitforce.
local lines = {}
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	lines[#lines + 1] = "[zzarea] " .. table.concat(t, " ")
end
local function W() return WG.LevelEditorWidget end
local Shared = VFS.Include("luaui/Include/editor_common.lua", nil, VFS.ZIP_FIRST)
local MX, MZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local UNITS = { "armart", "armmerl" } -- artillery tank, long range rocket launcher
local ar, area
local mouse = { 0, 0 }
local box, targets, mine = nil, {}, {}
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
local function camera(cx, cz, dist)
	local st = Spring.GetCameraState()
	st.name, st.mode = "spring", 2
	st.px, st.py, st.pz, st.dist, st.rx, st.ry, st.rz, st.fov = cx, Spring.GetGroundHeight(cx, cz), cz, dist, 2.3, 0, 0, 45
	Spring.SetCameraState(st, 0)
end

local steps = {}
steps[40] = function()
	ar = W():DebugArena()
	click(rect("ar", "ar"))
	local c = ar.cfg(true)
	c.radius = 450
	for i = 1, 10 do c.rows[i].allowed, c.rows[i].count, c.rows[i].on = {}, 16, i <= 1 end
	ar.setAllowed(1, UNITS, true)
	camera(MX, MZ, 1800)
end
steps[100] = function() ar.startPick("gen"); ar.click(MX, MZ) end
steps[220] = function()
	click(rect("ar", "ar")) -- the page closes
	ar.cfg(true).point = nil
	Spring.SendCommands("hideinterface 1")
	mine = army(0)
	log("army", #mine)
	Spring.SelectUnitArray(mine)
	local ax, az = 0, 0
	for _, id in ipairs(mine) do local x, _, z = Spring.GetUnitPosition(id); ax, az = ax + x, az + z end
	ax, az = ax / #mine, az / #mine
	local dz = (MZ > az) and 1 or -1 -- the army faces the middle of the map
	local cx, cz = ax, az + dz * 620
	box = { x1 = cx - 330, z1 = cz - 190, x2 = cx + 330, z2 = cz + 190 }
	area = Shared.newAreaAttack({ say = function(s) log("say:", s) end, mouseGround = function() return mouse[1], mouse[2] end })
	area:toggle("rect")
	mouse = { box.x1, box.z1 }
	area:press(1)
	mouse = { box.x2, box.z2 }
	area:release()
	camera(ax * 0.55 + cx * 0.45, az * 0.55 + cz * 0.45, 1500)
	after(3, function()
		for _, id in ipairs(mine) do
			local cmd, _, _, tx, ty, tz = Spring.GetUnitCurrentCommand(id, 1)
			if cmd == CMD.ATTACK and tz then targets[#targets + 1] = { id = id, x = tx, y = ty, z = tz } end
		end
		Spring.SelectUnitArray({})
		log("targets", #targets)
	end)
	after(120, function() Spring.SendCommands("screenshot png"); log("screenshot 1") end)
	after(140, function() Spring.SendCommands("screenshot png"); log("screenshot 2") end)
	after(160, function() Spring.SendCommands("screenshot png"); log("screenshot 3") end)
	after(180, function() Spring.SendCommands("screenshot png"); log("screenshot 4") end)
	after(200, function() Spring.SendCommands("screenshot png"); log("screenshot 5") end)
	after(230, function()
		log("END")
		for _, l in ipairs(lines) do Spring.Echo(l) end
		Spring.SendCommands("quitforce")
	end)
end

function widget:DrawWorld()
	if not box then return end
	gl.DepthTest(false)
	gl.LineWidth(3)
	gl.Color(1, 0.7, 0.2, 0.95)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for _, c in ipairs({ { box.x1, box.z1 }, { box.x2, box.z1 }, { box.x2, box.z2 }, { box.x1, box.z2 } }) do
			gl.Vertex(c[1], Spring.GetGroundHeight(c[1], c[2]) + 8, c[2])
		end
	end)
	for _, t in ipairs(targets) do
		local x, y, z = Spring.GetUnitPosition(t.id)
		if x then
			gl.LineWidth(1)
			gl.Color(1, 1, 1, 0.35)
			gl.BeginEnd(GL.LINES, function()
				gl.Vertex(x, y + 12, z)
				gl.Vertex(t.x, Spring.GetGroundHeight(t.x, t.z) + 8, t.z)
			end)
		end
		gl.LineWidth(2)
		gl.Color(1, 0.3, 0.2, 0.95)
		local gy = Spring.GetGroundHeight(t.x, t.z) + 8
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(t.x - 14, gy, t.z - 14)
			gl.Vertex(t.x + 14, gy, t.z - 14)
			gl.Vertex(t.x + 14, gy, t.z + 14)
			gl.Vertex(t.x - 14, gy, t.z + 14)
		end)
	end
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
