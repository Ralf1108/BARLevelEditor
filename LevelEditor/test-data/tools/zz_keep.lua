function widget:GetInfo() return { name = "zz keep", desc = "test only: settings changed while the Arena runs stay after Stop", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_keep.lua: Start of the Arena, changes of the Arena page and of the teams while it runs, Stop (the level before
-- the Start is loaded again): the changes must still be there. Logs "[zzar]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local function ok(c) return c and "OK" or "WRONG" end
local ar, tm
local MX, MZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
local n0
local function arenaUnits()
	local n = 0
	for _, id in ipairs(Spring.GetAllUnits()) do
		if Spring.GetUnitRulesParam(id, "arena") == 1 then n = n + 1 end
	end
	return n
end
local steps = {}
steps[40] = function()
	ar = W():DebugArena()
	tm = W():DebugTeams()
	local c = ar.cfg(true)
	c.radius = 800
	for i = 1, 10 do c.rows[i].allowed, c.rows[i].count, c.rows[i].on = {}, 10, i <= 2 end
	ar.setAllowed(1, { "armpw" }, true)
	ar.setAllowed(2, { "corak" }, true)
	ar.startPick("gen")
	ar.click(MX, MZ)
end
steps[200] = function()
	n0 = arenaUnits()
	log("units of the arena:", n0)
	ar.toggle() -- Start
end
steps[260] = function()
	log("running:", tostring(Spring.GetGameRulesParam("arenaState")))
	-- changes while it runs
	tm.setGroup(5, 3)
	tm.data[6].metal = 4321
	tm.data[3].ai = "BARb"
	ar.cfg(true).rows[3].count = 77
	ar.cfg(true).radius = 1234
	ar.cfg(true).formation = false
end
steps[300] = function() ar.toggle() end -- Stop
steps[500] = function()
	log("units back:", arenaUnits(), ok(arenaUnits() == n0))
	log("kept: group of team 5", tm.group(5), ok(tm.group(5) == 3), "metal of team 5", tm.row(5).metal, ok(tm.row(5).metal == 4321), "AI of team 2", tm.row(2).ai, ok(tm.row(2).ai == "BARb"))
	log("kept: count of row 3", ar.cfg().rows[3].count, ok(ar.cfg().rows[3].count == 77), "radius", ar.cfg().radius, ok(ar.cfg().radius == 1234), "formation", tostring(ar.cfg().formation), ok(ar.cfg().formation == false))
	log("kept: allowed row 1", #ar.cfg().rows[1].allowed, ok(#ar.cfg().rows[1].allowed == 1))
	log("alliance 5 applied: allied 5/5", "n/a")
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
			local ok2, err = pcall(steps[k])
			if not ok2 then log("TEST ERROR at", k, tostring(err)) end
			break
		end
	end
end
