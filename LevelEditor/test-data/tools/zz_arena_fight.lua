function widget:GetInfo() return { name = "zz arena fight", desc = "test only: what the armies shoot at after the area attack", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_arena_fight.lua: two armies (radius RADIUS, 20 units each), Start, then every 150 frames the targets of the weapons
-- of the arena units (none / unit / ground), the units left and the queue of one unit. Logs "[zzar]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local ar
local RADIUS = 1500 -- set by the test (a copy of this file with another number is the test of another radius)
local FORMATION = true -- the button Formation attack (a copy with false is the test without it)
local MX, MZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local function arenaUnits()
	local out = {}
	for _, id in ipairs(Spring.GetAllUnits()) do
		if Spring.GetUnitRulesParam(id, "arena") == 1 then out[#out + 1] = id end
	end
	return out
end
local function report(label)
	local ids = arenaUnits()
	local kinds = { [0] = 0, [1] = 0, [2] = 0, [3] = 0 }
	local sample
	for _, id in ipairs(ids) do
		local t = Spring.GetUnitWeaponTarget(id, 1)
		kinds[t or 0] = (kinds[t or 0] or 0) + 1
		if not sample then sample = id end
	end
	local q = {}
	for _, c in ipairs(sample and Spring.GetUnitCommands(sample, 4) or {}) do q[#q + 1] = c.id .. "(" .. #c.params .. ")" end
	local cx, cz, n = 0, 0, 0
	for _, id in ipairs(ids) do local x, _, z = Spring.GetUnitPosition(id); cx, cz, n = cx + x, cz + z, n + 1 end
	log(label, "units", #ids, "weapon target none/unit/ground/proj:", kinds[0], kinds[1], kinds[2], kinds[3], "queue of one:", table.concat(q, " "),
		string.format("distance of the center from the point %.0f", n > 0 and math.sqrt((cx / n - MX) ^ 2 + (cz / n - MZ) ^ 2) or -1))
end
local steps = {}
steps[40] = function()
	ar = W():DebugArena()
	local b = W():DebugLayout()
	for _, r in ipairs(select(1, W():DebugLayout())) do
		if r.kind == "ar" then W():MousePress((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2, 1); W():MouseRelease((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2, 1) end
	end
	local c = ar.cfg(true)
	c.radius = RADIUS
	c.formation = FORMATION
	for i = 1, 10 do c.rows[i].allowed, c.rows[i].count, c.rows[i].on = {}, 20, i <= 2 end
	ar.setAllowed(1, { "armpw", "armham" }, true)
	ar.setAllowed(2, { "corak", "corthud" }, true)
end
steps[80] = function() ar.startPick("gen"); ar.click(MX, MZ) end
steps[240] = function() report("before the start"); ar.toggle() end
for k = 1, 14 do
	steps[240 + k * 300] = function() report("frame " .. (240 + k * 300)) end
end
steps[4500] = function() log("END"); Spring.SendCommands("quitforce") end
local done = {}
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
