function widget:GetInfo() return { name = "zz scenario", desc = "test only: works the Scenario info page (button I)", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_scenario.lua: opens the page I, types a title (Enter accepts, Esc discards), cycles the win condition,
-- types a grace period and checks the values shown; page T and back. Logs "[zzar]" lines (OK / FAIL), ends with quitforce.
local lines = {}
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	lines[#lines + 1] = "[zzar] " .. table.concat(t, " ")
end
local function W() return WG.LevelEditorWidget end
local function allRects()
	local out = {}
	for _, v in pairs({ W():DebugLayout() }) do
		if type(v) == "table" then
			for _, r in ipairs(v) do
				if type(r) == "table" and r.x1 and (r.kind or r.row) then out[#out + 1] = r end
			end
		end
	end
	return out
end
local function btn(kind, value)
	for _, r in ipairs(allRects()) do
		if r.kind == kind and (value == nil or r.value == value) then return r end
	end
end
local function field(id)
	for _, r in ipairs(allRects()) do
		if type(r.row) == "table" and r.row.id == id then return r end
	end
end
local function click(r)
	if not r then log("FAIL no button") return end
	local x, y = (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2
	W():MousePress(x, y, 1)
	W():MouseRelease(x, y, 1)
end
local function typeText(text)
	for c in text:gmatch(".") do W():TextInput(c) end
end
local function check(ok, what) log(ok and "OK" or "FAIL", what) end

local steps = {}
steps[40] = function()
	click(btn("info"))
	check(field("title") ~= nil, "page I shows the rows")
	click(field("title"))
	for _ = 1, 90 do W():KeyPress(8, {}, false) end
	typeText("My Test Title")
	W():KeyPress(13, {}, false)
end
steps[60] = function()
	click(field("title"))
	for _ = 1, 20 do W():KeyPress(8, {}, false) end
	typeText("zzz")
	W():KeyPress(27, {}, false) -- Esc discards
	click(field("author"))
	W():KeyPress(27, {}, false)
	click(field("win"))
	click(field("grace"))
	for _ = 1, 8 do W():KeyPress(8, {}, false) end
	typeText("2:30x")
	W():KeyPress(13, {}, false)
end
steps[80] = function()
	-- the page T and back: the rows are still there
	click(btn("teams"))
	check(field("title") == nil, "page T does not show the scenario rows")
	click(btn("info"))
	check(field("title") ~= nil, "page I again")
end
steps[100] = function()
	-- the values are shown through the draw: ask the widget for the saved block
	local ok, text = pcall(function() return W():DebugScenario() end)
	if ok and text then
		check(text.title == "My Test Title", "title kept after Enter: " .. tostring(text.title))
		check(text.win == "killall", "win condition cycled to killall: " .. tostring(text.win))
		check(tonumber(text.grace) and math.abs(tonumber(text.grace) - 2.5) < 0.01, "grace period 2:30 = 2.5 min: " .. tostring(text.grace))
	else
		log("FAIL DebugScenario missing")
	end
	log("DONE")
	for _, l in ipairs(lines) do Spring.Echo(l) end
	Spring.SendCommands("quitforce")
end
local keys = {}
for k in pairs(steps) do keys[#keys + 1] = k end
table.sort(keys)
local nextKey = 1
function widget:Update()
	local k = keys[nextKey]
	if k and k <= Spring.GetGameFrame() then
		nextKey = nextKey + 1
		local ok, err = pcall(steps[k])
		if not ok then log("TEST ERROR at " .. k .. ": " .. tostring(err)) end
	end
end
