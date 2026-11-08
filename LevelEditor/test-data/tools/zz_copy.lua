function widget:GetInfo() return { name = "zz copy", desc = "test only: copy / paste (Ctrl+C / Ctrl+V), button W, save and load of a level", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_copy.lua: places two units, copies them (Ctrl+C through the KeyPress of the editor), pastes them next to them (the
-- mouse pointer is moved there with Spring.WarpMouse), pastes them once more on the same spot (W on: the copies there are replaced, not doubled), saves the
-- level, clears the map and loads it again. Logs "[zzar]" lines (OK / WRONG) and ends with quitforce. Checks led_place.lua and led_level.lua.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local function ok(cond) return cond and "OK" or "WRONG" end
local NAME = "armpw"
local function count()
	local n = 0
	for _, id in ipairs(Spring.GetTeamUnits(0) or {}) do
		if UnitDefs[Spring.GetUnitDefID(id)].name == NAME then n = n + 1 end
	end
	return n
end
local function key(k)
	W():KeyPress(k, { ctrl = true, shift = false, alt = false, meta = false }, false)
end
local function pointAt(x, z)
	local sx, sy = Spring.WorldToScreenCoords(x, Spring.GetGroundHeight(x, z), z)
	Spring.WarpMouse(sx, sy)
end

local steps = {}
steps[40] = function()
	Spring.SetCameraTarget(4000, Spring.GetGroundHeight(4000, 4000), 4000, 0)
	Spring.SendLuaRulesMsg("led|place|" .. NAME .. "|0|3900|4000|0")
	Spring.SendLuaRulesMsg("led|place|" .. NAME .. "|0|3950|4000|0")
end
steps[80] = function()
	log("units placed:", count(), ok(count() == 2))
	local ids = {}
	for _, id in ipairs(Spring.GetTeamUnits(0) or {}) do
		if UnitDefs[Spring.GetUnitDefID(id)].name == NAME then ids[#ids + 1] = id end
	end
	Spring.SelectUnitArray(ids)
	key(99) -- Ctrl+C
end
steps[100] = function()
	pointAt(4200, 4000)
	key(118) -- Ctrl+V
end
steps[160] = function()
	log("after paste:", count(), ok(count() == 4))
	pointAt(4200, 4000)
	key(118) -- Ctrl+V on the same spot: W is on, the copies there are written over
end
steps[220] = function()
	log("after a second paste on the same spot:", count(), ok(count() == 4))
	local _, saveLevel = W():DebugTeams()
	local n = saveLevel("zz_copy_test", true)
	log("saved units:", tostring(n), ok((n or 0) >= 4))
	Spring.SendCommands("led_clear")
end
steps[260] = function()
	log("after clear:", count(), ok(count() == 0))
	local _, _, loadLevel = W():DebugTeams()
	loadLevel(nil, nil, { "zz_copy_test" })
end
steps[360] = function()
	log("after load:", count(), ok(count() == 4))
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
