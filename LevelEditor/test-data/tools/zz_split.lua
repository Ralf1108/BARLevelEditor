function widget:GetInfo() return { name = "zz split", desc = "test only: the split attack (XS) on two Arena armies", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_split.lua: the Arena generates two armies (30 units of team 0, 10 of team 1, no fight), team 0 is selected and
-- attacks team 1 with the split attack (Shared.newAreaAttack in the mode "split"). Logs "[zzsp]" lines every 150 frames (enemies left, health,
-- idle units, queue of one unit) and ends with quitforce 90 frames after "Split attack finished" (or after frame 6000).
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzsp] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local Shared = VFS.Include("luaui/Include/editor_common.lua", nil, VFS.ZIP_FIRST)
local MX, MZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local MODE = "focus" -- "split" (XS, even) or "focus" (XF, one target after the other); a copy with the other word tests the other mode
local ar, area
local mouse = { 0, 0 }
local endAt
local started
local function army(team)
	local out = {}
	for _, id in ipairs(Spring.GetAllUnits()) do
		if Spring.GetUnitRulesParam(id, "arena") == 1 and Spring.GetUnitTeam(id) == team then out[#out + 1] = id end
	end
	return out
end
local function report(label)
	local mine, foe = army(0), army(1)
	local hp, idle = 0, 0
	for _, id in ipairs(foe) do hp = hp + (Spring.GetUnitHealth(id) or 0) end
	for _, id in ipairs(mine) do if Spring.GetUnitCommandCount(id) == 0 then idle = idle + 1 end end
	local q = {}
	for _, c in ipairs(mine[1] and Spring.GetUnitCommands(mine[1], 6) or {}) do q[#q + 1] = c.id .. ":" .. tostring(c.params[1]) end
	log(label, "mine", #mine, "enemies", #foe, "enemy health", math.floor(hp), "idle", idle, "queue of one:", table.concat(q, " "))
end
local steps = {}
steps[40] = function()
	ar = W():DebugArena()
	for _, r in ipairs((W():DebugLayout())) do
		if r.kind == "ar" then W():MousePress((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2, 1); W():MouseRelease((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2, 1) end
	end
	local c = ar.cfg(true)
	c.radius = 1000
	for i = 1, 10 do c.rows[i].allowed, c.rows[i].count, c.rows[i].on = {}, (i == 1) and 30 or 10, i <= 2 end
	ar.setAllowed(1, { "armpw", "armham" }, true)
	ar.setAllowed(2, { "corak", "corthud" }, true)
end
steps[80] = function() ar.startPick("gen"); ar.click(MX, MZ) end
steps[200] = function()
	report("armies")
	local mine, foe = army(0), army(1)
	Spring.SelectUnitArray(mine)
	local cx, cz = 0, 0
	for _, id in ipairs(foe) do local x, _, z = Spring.GetUnitPosition(id); cx, cz = cx + x, cz + z end
	cx, cz = cx / #foe, cz / #foe
	log("enemy center", math.floor(cx), math.floor(cz), "visible to the cylinder:", #Spring.GetUnitsInCylinder(cx, cz, 1500, Spring.ENEMY_UNITS))
	area = Shared.newAreaAttack({
		say = function(s)
			log("say:", s)
			if s:find("finished") or s:find("ended") then endAt = Spring.GetGameFrame() + 90 end
		end,
		mouseGround = function() return mouse[1], mouse[2] end,
	})
	area:toggle(MODE)
	mouse = { cx, cz }
	area:press(1)
	mouse = { cx + 1500, cz }
	area:release()
	started = true
	report("after the order")
end
for k = 1, 40 do
	steps[200 + k * 150] = function() report("frame " .. (200 + k * 150)) end
end
steps[6000] = function() log("END (time)"); Spring.SendCommands("quitforce") end
local done = {}
function widget:GameFrame(n)
	if area and started then area:step(n) end
	if endAt and n >= endAt then
		report("final")
		log("END")
		Spring.SendCommands("quitforce")
		endAt = nil
	end
end
function widget:Update()
	local f0 = Spring.GetGameFrame()
	local keys = {}
	for k in pairs(steps) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		if k <= f0 and not done[k] then
			done[k] = true
			local ok2, err = pcall(steps[k])
			if not ok2 then log("TEST ERROR at", k, tostring(err)) end
			break
		end
	end
end
