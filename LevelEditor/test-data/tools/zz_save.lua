function widget:GetInfo() return { name = "zz save", desc = "test only: works the Save page (button S)", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_save.lua: opens the page S, saves levels with a typed name and with the suggested name, tries a taken name,
-- fills the list until it scrolls, scrolls it (mouse wheel), sorts it by last use, saves a row again (no question), loads a level (second click),
-- takes screenshots and logs "[zzar]" lines (OK / FAIL), ends with quitforce.
-- the lines are kept and written at the end: a line in the chat would be in the picture
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
				if type(r) == "table" and r.kind and r.x1 then out[#out + 1] = r end
			end
		end
	end
	return out
end
local function rect(kind, value)
	for _, r in ipairs(allRects()) do
		if r.kind == kind and (value == nil or r.value == value) then return r end
	end
end
local function click(r)
	if not r then log("FAIL no button") return end
	local x, y = (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2
	W():MousePress(x, y, 1)
	W():MouseRelease(x, y, 1)
end
-- the names of the rows in the order on the screen
local function rows()
	local list = {}
	for _, r in ipairs(allRects()) do
		if r.kind == "svload" then list[#list + 1] = r end
	end
	table.sort(list, function(a, b) return a.y1 > b.y1 end)
	local names = {}
	for i, r in ipairs(list) do names[i] = r.name end
	return names, list
end
local function has(names, n)
	for _, x in ipairs(names) do if x == n then return true end end
	return false
end
local function check(ok, what) log(ok and "OK" or "FAIL", what) end
-- type a name into the field: Backspace for the old one, then the characters, then Enter
local function typeName(text)
	click(rect("svname"))
	for _ = 1, 45 do W():KeyPress(8, {}, false) end
	for c in text:gmatch(".") do W():TextInput(c) end
	W():KeyPress(13, {}, false)
end

local steps = {}
local before, total = 0, 0
steps[40] = function()
	local gear, sv, info, teams = rect("gear"), rect("sv", "sv"), rect("info"), rect("teams")
	check(sv ~= nil, "button S exists")
	if sv and gear and info and teams then
		check(gear.y1 > sv.y1 and sv.y1 > info.y1 and info.y1 > teams.y1, "order of the column: O, S, I, T")
	end
	click(sv)
	check(rect("sv", "sv").active == true, "S is lit after the click")
	local names = rows()
	before = #names
	log("levels in the folder", before)
	check(rect("svnew") ~= nil and rect("svname") ~= nil, "name field and Save as new are there")
	check(rect("svsort", "name") and rect("svsort", "recent"), "sort buttons are there")
	local f = rect("svname")
	check(f.label:match("^level_%d%d%d$") ~= nil, "the field holds a suggested name: " .. tostring(f.label))
end
steps[60] = function()
	typeName("my_level_a")
	check(rect("svname").label == "my_level_a", "typed name is in the field: " .. tostring(rect("svname").label))
	typeName("bad name!")
	check(rect("svname").label == "my_level_a" or rect("svname").label == "badname", "characters that are not allowed are dropped: " .. tostring(rect("svname").label))
	typeName("my_level_a")
	click(rect("svnew"))
end
steps[80] = function()
	local names = rows()
	check(has(names, "my_level_a") or #names > before, "Save as new with a typed name: the list has it (" .. #names .. " rows shown)")
	typeName("my_level_a")
	local n0 = #(rows())
	click(rect("svnew"))
	check(#(rows()) == n0, "a taken name is refused (no new row)")
end
-- twelve more with typed names, one per step (the list then scrolls); the last one is the level saved last
for i = 1, 12 do
	steps[100 + i * 4] = function()
		typeName(string.format("lv_a_%02d", i))
		click(rect("svnew"))
	end
end
steps[152] = function()
	local f = rect("svname")
	check(f.label:match("^level_%d%d%d$") ~= nil, "after a save the field holds a new suggestion: " .. tostring(f.label))
	click(f)
	for _ = 1, 45 do W():KeyPress(8, {}, false) end
	W():KeyPress(27, {}, false)
	check(rect("svname").label ~= "", "Esc keeps the name from before the entry")
end
steps[170] = function()
	local names = rows()
	total = #names
	log("rows shown", total)
	click(rect("svsort", "name"))
	local mx, my = (rect("svsort", "name").x1 + rect("svsort", "name").x2) / 2, rect("svsort", "name").y0 - 200
	Spring.WarpMouse(mx, my)
end
steps[185] = function()
	Spring.SendCommands("screenshot png")
	log("screenshot list sorted A-Z")
end
steps[200] = function()
	local first = (rows())[1]
	W():MouseWheel(false, 1)
	W():MouseWheel(false, 1)
	W():MouseWheel(false, 1)
	local now = (rows())[1]
	check(total >= 12 and first ~= now, "the mouse wheel scrolls the list: " .. tostring(first) .. " -> " .. tostring(now))
end
steps[215] = function()
	Spring.SendCommands("screenshot png")
	log("screenshot list scrolled")
end
steps[230] = function()
	click(rect("svsort", "recent"))
	local names = rows()
	check(#names > 0 and names[1] == "lv_a_12", "sorted by last use: the level saved last is on top: " .. tostring(names[1]))
end
steps[250] = function()
	local names, list = rows()
	local second = names[2]
	click({ x1 = 0, x2 = 0, y0 = 0, y1 = 0 }) -- nothing there
	-- the Save button of the second row
	local save
	for _, r in ipairs(allRects()) do
		if r.kind == "svsave" and r.name == second then save = r end
	end
	click(save)
	local after = (rows())[1]
	check(after == second, "Save on a row overwrites at once (no question) and the level moves to the top: " .. tostring(after))
end
steps[270] = function()
	local _, list = rows()
	local r = list[3]
	click(r)
	local label
	for _, x in ipairs(allRects()) do if x.kind == "svload" and x.name == r.name then label = x.label end end
	check(label == "Sure?", "first click on Load asks: " .. tostring(label))
	click(r)
	log("second click on Load done")
end
steps[300] = function()
	Spring.SendCommands("screenshot png")
	log("screenshot after load")
	click(rect("sv", "sv"))
	check(rect("sv", "sv").active == false, "S closes with a second click")
	click(rect("gear"))
	local n = 0
	for _, r in ipairs(allRects()) do
		if r.kind == "svload" then n = n + 1 end
	end
	check(n == 0, "the options page does not show the level list any more")
	log("DONE")
end
steps[320] = function()
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
