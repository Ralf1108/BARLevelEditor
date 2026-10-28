function widget:GetInfo() return { name = "zz arena shots", desc = "test only: sets up the Arena pictures of the README", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Shots: three armies (radius 1000, count 50) on the flat map, then two screenshots:
-- "menu" (the page, the armies on the map) and "lineup" (the armies only, interface hidden). Logs "[zzar]" lines, ends with quitforce.
-- the lines are kept and written at the end: a line in the chat would be in the picture
local lines = {}
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	lines[#lines + 1] = "[zzar] " .. table.concat(t, " ")
end
local function W() return WG.LevelEditorWidget end
local ar
local MX, MZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
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
local function camera(dx, dist)
	local st = Spring.GetCameraState()
	st.name, st.mode = "spring", 2
	st.px, st.py, st.pz, st.dist, st.rx, st.ry, st.rz, st.fov = MX + dx, Spring.GetGroundHeight(MX, MZ), MZ, dist, 2.5, 0, 0, 45
	Spring.SetCameraState(st, 0)
end

local steps = {}
steps[40] = function()
	ar = W() and W():DebugArena()
	log("arena page", tostring(ar))
	click(rect("ar", "ar"))
	local c = ar.cfg(true)
	c.radius = 1000
	c.rows[1].on, c.rows[2].on, c.rows[3].on, c.rows[4].on = true, true, true, false
	for i = 1, 4 do c.rows[i].allowed, c.rows[i].count = {}, 50 end
	ar.setAllowed(1, { "armpw", "armham", "armrock", "armfido", "armmav", "armjanus" }, true)
	ar.setAllowed(2, { "corak", "corthud", "corstorm", "corcan", "corwolv" }, true)
	ar.setAllowed(3, { "armflash", "armstump", "armart", "armsam", "armpw" }, true)
	camera(0, 3000)
end
steps[100] = function()
	ar.startPick("gen")
	ar.click(MX, MZ)
	log("generated")
end
steps[300] = function()
	camera(0, 3400)
end
steps[360] = function()
	Spring.SendCommands("screenshot png")
	log("screenshot menu")
end
steps[420] = function()
	click(rect("ar", "ar")) -- the page closes
	camera(0, 2600)
	Spring.SendCommands("hideinterface 1")
end
steps[480] = function()
	Spring.SendCommands("screenshot png")
	log("screenshot lineup")
end
steps[540] = function()
	log("END")
	for _, l in ipairs(lines) do Spring.Echo(l) end
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
