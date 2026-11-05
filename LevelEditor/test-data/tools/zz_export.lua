function widget:GetInfo() return { name = "zz export", desc = "test only: the export buttons of the settings page (O)", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_export.lua: opens the settings page (O), presses "Export Units Info" and "Export Comparison", reads units.json and
-- comparison.json from LevelEditor/Other/ and checks them; a hand-corrected id must survive a second export. Logs "[zzar]" lines (OK / FAIL), ends with quitforce.
local lines = {}
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	lines[#lines + 1] = "[zzar] " .. table.concat(t, " ")
end
local function check(ok, what) log(ok and "OK" or "FAIL", what) end
local function W() return WG.LevelEditorWidget end
local Json = Json or VFS.Include("common/luaUtilities/json.lua")
-- a user widget may not open files in the data folder: the files are read and written through the hooks of the export module
local function read(name) return (W():DebugOptions()).actions.read(name) end
local function click(r)
	local x, y = (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2
	W():MousePress(x, y, 1)
	W():MouseRelease(x, y, 1)
end
local function button(label)
	local ui, rect = W():DebugOptions()
	for _, r in ipairs((ui:layout(rect))) do
		if r.label == label then return r end
	end
end

local steps = {}
steps[60] = function()
	local opened
	for _, v in pairs({ W():DebugLayout() }) do
		if type(v) == "table" then
			for _, r in ipairs(v) do
				if type(r) == "table" and r.kind == "gear" then opened = r end
			end
		end
	end
	check(opened ~= nil, "the O button exists")
	if opened then click(opened) end
end
steps[90] = function()
	local b = button("Export Units Info")
	check(b ~= nil, "the page O has the button Export Units Info")
	if b then click(b) end
	local ui = W():DebugOptions()
	log("message: " .. tostring(ui.message))
	local file = ui.actions.unitsFile()
	local text = read(file)
	check(file:match("^units%-.+%.json$") ~= nil, "the file name carries the game version: " .. file)
	check(text ~= nil and #text > 1000000, file .. " is written, " .. tostring(text and #text) .. " bytes")
	local ok, data = pcall(Json.decode, text or "")
	check(ok and type(data) == "table", "units.json is valid JSON" .. (ok and "" or (": " .. tostring(data))))
	if not (ok and type(data) == "table") then return end
	local n = 0
	for _ in pairs(data.units) do n = n + 1 end
	log("loaded archives: " .. table.concat(VFS.GetLoadedArchives and VFS.GetLoadedArchives() or {}, " | "))
	check(data.gameName == "Beyond All Reason" and data.gameVersion ~= "1" and data.gameVersion ~= "unknown" and file:find((data.gameVersion:gsub("[^%w%._%-]", "_")), 1, true) ~= nil, "the file has the version of Beyond All Reason: " .. tostring(data.gameVersion) .. " (" .. tostring(data.gameName) .. ")")
	check(n == data.count and n > 500, "count " .. tostring(data.count) .. " = " .. n .. " units")
	local a, c = data.units.armllt, data.units.corllt
	check(a and a.editor.faction == "arm" and a.editor.group == "turrets" and a.editor.tech == 1, "armllt: Armada, turrets, tech 1")
	check(a and type(a.game.health) == "number" and a.game.health > 0, "armllt: health " .. tostring(a and a.game.health))
	check(a and a.game.metalCost ~= nil, "armllt: metalCost " .. tostring(a and a.game.metalCost))
	check(a and #a.editor.weapons >= 1 and a.editor.weapons[1].damages.default ~= nil, "armllt: weapon with damages")
	check(a and a.editor.model ~= "" and a.editor.buildpic ~= "", "armllt: model " .. tostring(a and a.editor.model) .. ", picture " .. tostring(a and a.editor.buildpic))
	check(a and a.editor.author ~= "", "armllt: author " .. tostring(a and a.editor.author))
	check(c and c.editor.faction == "cor", "corllt: Cortex")
	check(data.units.armllt_scav and data.units.armllt_scav.editor.faction == "scv", "armllt_scav: Scavengers")
	local raptor
	for name, u in pairs(data.units) do if u.editor.faction == "rap" then raptor = name break end end
	check(raptor ~= nil, "a raptor is there: " .. tostring(raptor))
	local builder = data.units.armck
	check(builder and #builder.editor.builds > 5, "armck builds " .. tostring(builder and #builder.editor.builds) .. " things")
	local nkeys = 0
	if a then for _ in pairs(a.game) do nkeys = nkeys + 1 end end
	log("armllt has " .. nkeys .. " raw fields")
end
steps[120] = function()
	local b = button("Export Comparison")
	if b then click(b) end
	log("message: " .. tostring((W():DebugOptions()).message))
	local text = read("comparison.json")
	local ok, data = pcall(Json.decode, text or "")
	check(ok and type(data) == "table" and type(data.units) == "table", "comparison.json is valid JSON")
	if not (ok and type(data) == "table") then return end
	check(data.units.armsolar == "solar" and data.units.corsolar == "solar" and data.units.legsolar == "solar", "armsolar, corsolar, legsolar share the id solar: " .. tostring(data.units.armsolar) .. " " .. tostring(data.units.corsolar) .. " " .. tostring(data.units.legsolar))
	check(data.units.legllt == nil, "legllt does not exist (the Legion light laser tower has another name: ids must be corrected by hand)")
	check(data.units.armllt_scav == "llt", "the Scavenger copy has the id of its unit")
	-- a hand-made change must stay
	local ui = W():DebugOptions()
	ui.actions.write("comparison.json", (text:gsub('"corllt": "llt"', '"corllt": "mine"')))
end
steps[150] = function()
	local b = button("Export Comparison")
	if b then click(b) end
	local ok, data = pcall(Json.decode, read("comparison.json") or "")
	check(ok and data.units.corllt == "mine", "the corrected id survives the next export: " .. tostring(ok and data.units.corllt))
	log("message: " .. tostring((W():DebugOptions()).message))
end
steps[180] = function()
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
		if not ok then log("TEST ERROR at " .. k .. ": " .. tostring(err)); for _, l in ipairs(lines) do Spring.Echo(l) end; Spring.SendCommands("quitforce") end
	end
end
