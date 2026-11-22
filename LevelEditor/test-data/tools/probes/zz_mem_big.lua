function widget:GetInfo() return { name = "zz mem", desc = "test only: how much Lua memory per second the Level Editor allocates", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_mem_big.lua (zz_mem.lua with the level demo_td_serpentine, 2460 units, loaded): the garbage collector is stopped for 3 seconds at a time and the growth of the Lua memory is the allocation
-- rate (KB per second) of everything in LuaUI; the same with the Level Editor switched off tells what belongs to it. Logs "[zzar]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local meas
local function measure(label)
	collectgarbage("collect")
	collectgarbage("stop")
	meas = { label = label, kb = collectgarbage("count"), t = os.clock(), frame = Spring.GetGameFrame() }
end
local function finish()
	local kb, t = collectgarbage("count"), os.clock()
	collectgarbage("restart")
	log(string.format("%-34s %6.0f KB/s  (%d frames in %.1f s)", meas.label, (kb - meas.kb) / (t - meas.t), Spring.GetGameFrame() - meas.frame, t - meas.t))
end
local function clickKind(kind)
	for _, v in pairs({ W():DebugLayout() }) do
		if type(v) == "table" then
			for _, r in ipairs(v) do
				if type(r) == "table" and r.kind == kind and r.x1 then
					W():MousePress((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2, 1)
					W():MouseRelease((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2, 1)
					return
				end
			end
		end
	end
end
local steps = {}
steps[20] = function() local _, _, load = W():DebugTeams() load(nil, nil, { "demo_td_serpentine" }) end
steps[1000] = function() measure("big level, Place menu") end
steps[1090] = function() finish() clickKind("teams") end
steps[1110] = function() measure("big level, page T") end
steps[1200] = function() finish() clickKind("ar") end
steps[1220] = function() measure("big level, page Arena") end
steps[1310] = function() finish() clickKind("td") end
steps[1330] = function() measure("big level, page Tower Defense") end
steps[1420] = function() finish() widgetHandler:DisableWidget("Level Editor") end
steps[1440] = function() measure("big level, Level Editor switched off") end
steps[1530] = function() finish() log("END") Spring.SendCommands("quitforce") end
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
