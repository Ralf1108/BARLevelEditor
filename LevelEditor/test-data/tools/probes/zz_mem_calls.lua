function widget:GetInfo() return { name = "zz mem calls", desc = "test only: Lua memory allocated by every call-in of the Level Editor", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_mem_calls.lua: wraps the call-ins of the widget "Level Editor" and adds up what each one allocates
-- (garbage collector stopped while measuring, 3 seconds per page), with the level demo_td_serpentine (2460 units) loaded. Logs "[zzar]" lines.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local acc, calls
local function wrap() acc, calls = W():DebugProfile() end
local t0
local function measure() for n in pairs(acc) do acc[n], calls[n] = 0, 0 end collectgarbage("collect") collectgarbage("stop") t0 = os.clock() end
local function finish(label)
	collectgarbage("restart")
	local dt = os.clock() - t0
	local out = {}
	for n, v in pairs(acc) do if v > 0 then out[#out + 1] = string.format("%s %.0f KB/s (%d calls)", n, v / dt, calls[n]) end end
	table.sort(out)
	log(label, ":", table.concat(out, "; "))
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
steps[20] = function() wrap() local _, _, load = W():DebugTeams() load(nil, nil, { "demo_td_serpentine" }) end
steps[1000] = function() measure() end
steps[1090] = function() finish("Place menu") clickKind("teams") end
steps[1110] = function() measure() end
steps[1200] = function() finish("page T") clickKind("ar") end
steps[1220] = function() measure() end
steps[1310] = function() finish("page Arena") clickKind("td") end
steps[1330] = function() measure() end
steps[1420] = function() finish("page Tower Defense") log("END") Spring.SendCommands("quitforce") end
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
