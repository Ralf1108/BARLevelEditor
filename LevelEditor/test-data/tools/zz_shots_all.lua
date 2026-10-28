function widget:GetInfo() return { name = "zz shots all", desc = "test only: sets up the scenes of the pictures of the README", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_shots_all.lua (with -Map "Full Metal Plate 1.7"): plays the scenes of docs\screenshots.md one after the other through
-- WG.LevelEditorWidget (clicks on the buttons, real drags on the map) and takes a screenshot per scene. The log lines "SHOT <name>" give the order of the files.
-- The lines are written at the end (a line in the chat would be in the picture). Ends with quitforce.
local lines = {}
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	lines[#lines + 1] = "[zzar] " .. table.concat(t, " ")
end
local function W() return WG.LevelEditorWidget end
local tm, saveLevel, loadLevel, td
local ar
local MX, MZ = Game.mapSizeX / 2, Game.mapSizeZ / 2

local function allRects()
	local out = {}
	for _, v in pairs({ W():DebugLayout() }) do
		if type(v) == "table" then
			for _, r in ipairs(v) do
				if type(r) == "table" and r.x1 and r.kind then out[#out + 1] = r end
			end
		end
	end
	return out
end
local function click(kind, value)
	for _, r in ipairs(allRects()) do
		if r.kind == kind and (value == nil or r.value == value) then
			local x, y = (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2
			W():MousePress(x, y, 1)
			W():MouseRelease(x, y, 1)
			return true
		end
	end
	log("NO BUTTON", kind, tostring(value))
end
local function camera(cx, cz, dist)
	local st = Spring.GetCameraState()
	st.name, st.mode = "spring", 2
	st.px, st.py, st.pz, st.dist, st.rx, st.ry, st.rz, st.fov = cx, Spring.GetGroundHeight(cx, cz), cz, dist, 2.5, 0, 0, 45
	Spring.SetCameraState(st, 0)
end
-- the camera over all units (not Gaia): center, extent
local function overUnits(extra)
	local x1, z1, x2, z2 = 1e9, 1e9, -1e9, -1e9
	local gaia = Spring.GetGaiaTeamID()
	for _, id in ipairs(Spring.GetAllUnits()) do
		if Spring.GetUnitTeam(id) ~= gaia then
			local x, _, z = Spring.GetUnitPosition(id)
			x1, z1, x2, z2 = math.min(x1, x), math.min(z1, z), math.max(x2, x), math.max(z2, z)
		end
	end
	if x1 > x2 then x1, z1, x2, z2 = MX - 500, MZ - 500, MX + 500, MZ + 500 end
	local e = math.max(x2 - x1, z2 - z1)
	camera((x1 + x2) / 2 - (extra or 0) * e * 0.25, (z1 + z2) / 2, math.min(9000, 1.15 * e + 800))
end
local function drag(x1, z1, x2, z2) -- a real drag on the map
	local ax, ay = Spring.WorldToScreenCoords(x1, Spring.GetGroundHeight(x1, z1), z1)
	local bx, by = Spring.WorldToScreenCoords(x2, Spring.GetGroundHeight(x2, z2), z2)
	W():MousePress(ax, ay, 1)
	W():MouseRelease(bx, by, 1)
end
local function shot(name)
	Spring.SendCommands("screenshot png")
	log("SHOT", name)
end
local function alliances() -- frames in the strip
	tm.setGroup(0, 2); tm.setGroup(1, 1); tm.setGroup(2, 2); tm.setGroup(3, 1); tm.setGroup(4, 4)
end

-- ---------------------------------------------------------------- the scenes, in order; every entry waits `wait` frames after the one before
local steps = {}
local function add(wait, fn) steps[#steps + 1] = { wait = wait, fn = fn } end

add(40, function()
	tm, saveLevel, loadLevel, td = W():DebugTeams()
	ar = W():DebugArena()
	alliances()
	camera(MX, MZ, 3200)
	-- some Armada units and turrets for the Place picture
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|generaterect|0|%d|%d|%d|%d|40|1|arm|units|0", MX - 900, MZ - 600, MX - 100, MZ + 600))
	Spring.SendLuaRulesMsg(string.format("led|generaterect|0|%d|%d|%d|%d|25|1,2|arm|turrets|0", MX + 100, MZ - 600, MX + 900, MZ + 600))
end)
add(150, function() shot("place-units") end)
add(20, function() click("top", "gen") end) -- (no sample blueprints in the repository: the Blueprints picture stays as it is)
-- Generate: Units
add(40, function() click("genkind", "turrets"); click("genshape", "rect") end)
add(30, function()
	drag(MX - 1400, MZ - 900, MX + 1400, MZ + 900)
end)
add(150, function() shot("generate-units") end)
-- Generate: Maze
add(20, function() click("gensub", "maze") end)
add(30, function() click("genmaze", 2); click("genmazew", 4) end)
add(30, function() click("genshape", "rect") end)
add(30, function() drag(MX - 1200, MZ - 800, MX + 1200, MZ + 800) end)
add(200, function() shot("generate-maze") end)
-- Tower Defense
add(20, function() click("top", "place"); loadLevel(nil, nil, { "demo_td_serpentine" }) end)
add(900, function() alliances(); overUnits(); click("td") end)
add(60, function() overUnits() end)
add(60, function() shot("tower-defense") end)
-- Scenario page
add(20, function() click("td"); click("info") end)
add(60, function() shot("scenario") end)
-- Capture the Flag (running)
add(20, function() click("info"); loadLevel(nil, nil, { "demo_ctf_crossroads" }) end)
add(500, function() alliances(); overUnits(); click("ctf") end)
add(60, function() click("ctfplay") end)
add(420, function() overUnits() end)
add(80, function() shot("capture-the-flag") end)
add(20, function() click("ctfplay") end)
-- Reclaim the Fame (running)
add(200, function() click("ctf"); loadLevel(nil, nil, { "demo_rtf_crystal_fields" }) end)
add(500, function() alliances(); overUnits(); click("rtf") end)
add(60, function() click("rtfplay") end)
add(800, function() overUnits() end)
add(100, function() shot("reclaim-the-fame") end)
add(20, function() click("rtfplay") end)
-- Teams
add(200, function()
	click("rtf")
	alliances()
	click("teams")
	local d = tm.data
	d[1].ai, d[2].ai, d[3].ai, d[4].ai, d[5].ai = "", "", "BARb", "CircuitAI", "NullAI"
	d[1].metal, d[1].energy, d[3].metal = 2000, 3000, 500
end)
add(60, function() shot("teams") end)
-- Arena
add(20, function()
	click("teams")
	Spring.SendLuaRulesMsg("led|clear")
	click("ar")
	camera(MX, MZ, 3400)
	local c = ar.cfg(true)
	c.radius = 1000
	for i = 1, 10 do c.rows[i].allowed, c.rows[i].count, c.rows[i].on = {}, 50, i <= 3 end
	ar.setAllowed(1, { "armpw", "armham", "armrock", "armfido", "armmav", "armjanus" }, true)
	ar.setAllowed(2, { "corak", "corthud", "corstorm", "corcan", "corwolv" }, true)
	ar.setAllowed(3, { "armflash", "armstump", "armart", "armsam", "armpw" }, true)
end)
add(100, function() ar.startPick("gen"); ar.click(MX, MZ) end)
add(220, function() shot("arena") end)
add(20, function() click("ar"); Spring.SendCommands("hideinterface 1"); camera(MX, MZ, 2600) end)
add(60, function() shot("arena-lineup") end)
add(20, function()
	log("END")
	for _, l in ipairs(lines) do Spring.Echo(l) end
	Spring.SendCommands("quitforce")
end)

local at, idx = 0, 0
function widget:Update()
	local f = Spring.GetGameFrame()
	if idx == 0 then idx, at = 1, f end
	local s = steps[idx]
	if s and f >= at + s.wait then
		at = f
		idx = idx + 1
		local ok, err = pcall(s.fn)
		if not ok then log("TEST ERROR at step", idx - 1, tostring(err)) end
	end
end
