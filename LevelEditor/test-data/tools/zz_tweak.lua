function widget:GetInfo() return { name = "zz tweak", desc = "test only: the Tweaks tab (tweaked units): paste, place, values, undo, copy, rename, save and load", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_tweak.lua: opens the Tweaks tab of the Place menu, pastes a tweakunits text (plain and in base64; a broken text and
-- program code are refused), arms an entry and places it with a click, compares the values of the tweaked unit with a normal one (health, range, damage,
-- cost, sight, speed), moves it and undoes that, copies it (Ctrl+C / Ctrl+V), renames the entry, saves the level, clears the map and loads it again, loads the
-- test level tweak_test (its entries come into the library) and deletes an entry. The clipboard: the button "Copy an example" and the Paste button (the text
-- goes through the clipboard of Windows), a right click on a unit tile of the tab Units with "Copy as tweakunits" and "Copy as tweakdefs", "Modify tweakunits"
-- (the window of the values: type a value, Copy, Create clone), a right click on an entry with "Edit" (Save changes the placed units, a value set back),
-- the boxes of the entries with "Copy checked as text / as base64" (nothing checked, two entries of one unit type refused, kept in the library), every entry
-- of the list in the section tweaks of a level. When the clipboard
-- holds the text MARK at the start (put there from outside: Set-Clipboard before the run), the Paste button must take it; otherwise that check is skipped.
-- A picture of the tab. Logs "[zzar]" lines (OK / WRONG), ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function W() return WG.LevelEditorWidget end
local function ok(cond) return cond and "OK" or "WRONG" end
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
local function rect(kind, field, value)
	for _, r in ipairs(allRects()) do
		if r.kind == kind and (field == nil or r[field] == value) then return r end
	end
end
local function click(r)
	if not r then log("no button WRONG") return end
	local x, y = (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2
	W():MousePress(x, y, 1)
	W():MouseRelease(x, y, 1)
end
local function pointAt(x, z)
	local sx, sy = Spring.WorldToScreenCoords(x, Spring.GetGroundHeight(x, z), z)
	Spring.WarpMouse(sx, sy)
	return sx, sy
end
local function units(name)
	local tweaked, normal = {}, {}
	for _, id in ipairs(Spring.GetTeamUnits(0) or {}) do
		if UnitDefs[Spring.GetUnitDefID(id)].name == name then
			if Spring.GetUnitRulesParam(id, "ledtweak") then tweaked[#tweaked + 1] = id else normal[#normal + 1] = id end
		end
	end
	return tweaked, normal
end
local function maxHealth(id) return select(2, Spring.GetUnitHealth(id)) end
local function near(a, b) return a and b and math.abs(a - b) < 0.01 * math.max(1, math.abs(b)) end

local TEXT = "{ armpw = { health = 2000, speed = 174, metalcost = 10, sightdistance = 900, footprintx = 4, weapondefs = { emg = { range = 500, damage = { default = 50 } } } } }"
local B64 = "eyBhcm1sbHQgPSB7IGhlYWx0aCA9IDUwMDAsIHNpZ2h0ZGlzdGFuY2UgPSA5MDAgfSB9" -- { armllt = { health = 5000, sightdistance = 900 } }
local MARK = "{ armllt = { health = 4321 } }"
local tw, pawnId, firstId
local function clip() -- (read again when empty: another program of Windows, e.g. the clipboard history, can hold the clipboard for a moment)
	local c = ""
	for _ = 1, 200 do
		c = Spring.GetClipboard and Spring.GetClipboard() or ""
		if c ~= "" then break end
	end
	return (c:gsub("\r", ""))
end
local function rightClickTile(i)
	local _, uGrid = W():DebugRestrictions()
	local _, content = W():DebugLayout()
	local ix, iy = uGrid:geom(content, i)
	W():MousePress(ix + 12, iy + 12, 3)
	W():MouseRelease(ix + 12, iy + 12, 3)
	return uGrid:list()[i].name
end
local tileName
local function winRow(key, weapon)
	for i, r in ipairs(tw.win and tw.win.rows or {}) do
		if r.key == key and r.weapon == weapon then return i, r end
	end
end
local function typeValue(row, text)
	click(rect("twval", "row", row))
	for _ = 1, 16 do W():KeyPress(8, {}, false) end
	for c in text:gmatch(".") do W():TextInput(c) end
	W():KeyPress(13, {}, false)
end
local function rightClick(r)
	if not r then log("no button WRONG") return end
	W():MousePress((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2, 3)
	W():MouseRelease((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2, 3)
end
local steps = {}
steps[40] = function()
	Spring.SetCameraTarget(4000, Spring.GetGroundHeight(4000, 4000), 4000, 0)
	tw = W():DebugTweaks()
	click(rect("mode", "value", "tw"))
	log("the tab Tweaks is open:", ok(rect("twpaste") ~= nil and rect("twhelp") ~= nil and rect("twhelp").tip:find("DOES NOT WORK", 1, true) ~= nil))
	if clip():gsub("%s+$", "") == MARK then
		local before = #tw.list
		click(rect("twpaste"))
		log("a text put into the clipboard of Windows from outside is pasted by the button:", tostring(tw.notice and tw.notice.text),
			ok(#tw.list == before + 1 and tw.list[1].base == "armllt" and tw.list[1].tw.health == 4321))
		if #tw.list == before + 1 then table.remove(tw.list, 1) end
	else
		log("the clipboard was not set from outside: that check is skipped")
	end
	local n0 = #tw.list
	log("a broken text is refused:", ok(tw.paste("{ armpw = { health = } }") == 0 and #tw.list == n0), tostring(tw.notice and tw.notice.text))
	log("program code is refused:", ok(tw.paste("UnitDefs.armpw.health = 5") == 0 and #tw.list == n0), tostring(tw.notice and tw.notice.text))
	log("an unknown unit is refused:", ok(tw.paste("{ nosuchunit = { health = 5 } }") == 0 and #tw.list == n0), tostring(tw.notice and tw.notice.text))
	log("plain text gives one entry:", ok(tw.paste(TEXT) == 1 and #tw.list == n0 + 1), tostring(tw.notice and tw.notice.text))
	log("base64 gives one entry:", ok(tw.paste(B64) == 1 and #tw.list == n0 + 2))
	pawnId = tw.list[2].id
	log("the entries:", tw.list[1].id, tw.list[1].name, "/", tw.list[2].id, tw.list[2].name, ok(tw.list[2].base == "armpw" and tw.list[1].base == "armllt"))
	local warn = rect("twwarn")
	log("the entry with a field that cannot change has a yellow !:", ok(warn ~= nil and warn.tip:find("footprintx", 1, true) ~= nil))
end
steps[60] = function()
	click(rect("twarm", "id", pawnId))
	log("the entry is armed:", tw.placeSuffix(), ok(tw.placeSuffix() == "|0|0|" .. pawnId))
	local sx, sy = pointAt(4000, 4000)
	W():MousePress(sx, sy, 1)
	W():MouseRelease(sx, sy, 1)
	Spring.SendLuaRulesMsg("led|place|armpw|0|4200|4000|0") -- a normal Pawn next to it
end
steps[110] = function()
	local t, n = units("armpw")
	log("placed with a click: tweaked", #t, "normal", #n, ok(#t == 1 and #n == 1))
	if #t == 0 then
		Spring.SendLuaRulesMsg("led|place|armpw|0|4000|4000|0|0|0|0|" .. pawnId) -- (so the rest of the test still says something)
	end
end
steps[140] = function()
	local t, n = units("armpw")
	local a, b = t[1], n[1]
	if not (a and b) then log("no units to compare WRONG") return end
	firstId = a
	local ud = UnitDefNames.armpw
	log("health:", maxHealth(a), "normal", maxHealth(b), ok(maxHealth(a) == 2000 and near(maxHealth(b), ud.health)))
	log("health is full:", (Spring.GetUnitHealth(a)), ok((Spring.GetUnitHealth(a)) == 2000))
	local ra, rb = Spring.GetUnitWeaponState(a, 1, "range"), Spring.GetUnitWeaponState(b, 1, "range")
	log("weapon range:", ra, "normal", rb, ok(near(ra, 500) and not near(rb, 500)))
	local da, db = Spring.GetUnitWeaponDamages(a, 1, 0), Spring.GetUnitWeaponDamages(b, 1, 0)
	log("weapon damage (default class):", da, "normal", db, ok(near(da, 50) and not near(db, 50)))
	local _, ma = Spring.GetUnitCosts(a)
	local _, mb = Spring.GetUnitCosts(b)
	log("metal cost:", ma, "normal", mb, ok(near(ma, 10) and near(mb, ud.metalCost)))
	local la, lb = Spring.GetUnitSensorRadius(a, "los"), Spring.GetUnitSensorRadius(b, "los")
	log("sight:", la, "normal", lb, ok(la and lb and la > lb * 1.5))
	local sa, sb = (Spring.GetUnitMoveTypeData(a) or {}).maxSpeed, (Spring.GetUnitMoveTypeData(b) or {}).maxSpeed
	log("top speed:", sa, "normal", sb, "expected factor", 174 / ud.speed, ok(sa and sb and near(sa / sb, 174 / ud.speed)))
	log("name of the unit:", tostring(Spring.GetUnitRulesParam(a, "ledtweakname")), ok(Spring.GetUnitRulesParam(a, "ledtweakname") == tw.list[2].name))
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg("led|move|64|0|" .. a) -- moving sets the unit up again
end
steps[180] = function()
	local t = units("armpw")
	log("after moving: tweaked", #t, "a new unit", tostring(t[1] ~= firstId), "health", t[1] and maxHealth(t[1]), ok(#t == 1 and t[1] ~= firstId and maxHealth(t[1]) == 2000))
	Spring.SendLuaRulesMsg("led|undo|1")
end
steps[220] = function()
	local t = units("armpw")
	local x = t[1] and Spring.GetUnitPosition(t[1])
	log("after undo: tweaked", #t, "x", x, "health", t[1] and maxHealth(t[1]), ok(#t == 1 and x and math.abs(x - 4000) < 20 and maxHealth(t[1]) == 2000))
	Spring.SelectUnitArray(t)
	W():KeyPress(99, { ctrl = true, shift = false, alt = false, meta = false }, false) -- Ctrl+C
end
steps[240] = function()
	pointAt(4000, 4300)
	W():KeyPress(118, { ctrl = true, shift = false, alt = false, meta = false }, false) -- Ctrl+V
end
steps[300] = function()
	local t = units("armpw")
	log("after copy and paste: tweaked", #t, ok(#t == 2 and maxHealth(t[1]) == 2000 and maxHealth(t[2]) == 2000))
	-- rename the entry: the button, Backspace for the old name, the new one, Enter
	click(rect("twname", "id", pawnId))
	local box = rect("twrenbox")
	log("Rename opens a window with the whole name:", box and box.label, ok(box ~= nil and box.label == tw.list[2].name .. "_" and rect("twrenok") ~= nil))
	for _ = 1, 45 do W():KeyPress(8, {}, false) end
	for c in ("Boss Pawn!"):gmatch(".") do W():TextInput(c) end
	W():KeyPress(13, {}, false)
	log("renamed:", tw.list[2].name, ok(tw.list[2].name == "Boss Pawn" and rect("twrenbox") == nil))
	click(rect("twname", "id", pawnId))
	W():TextInput("x")
	click(rect("twrencancel"))
	log("Cancel keeps the old name:", tw.list[2].name, ok(tw.list[2].name == "Boss Pawn" and tw.edit == nil))
	click(rect("twname", "id", pawnId))
	W():TextInput("2")
	click(rect("twrenok"))
	log("OK takes the new name:", tw.list[2].name, ok(tw.list[2].name == "Boss Pawn2" and tw.edit == nil))
	click(rect("twname", "id", pawnId))
	for _ = 1, 2 do W():KeyPress(8, {}, false) end
	W():TextInput("n")
	W():MousePress(5, 5, 1)
	log("a click outside accepts:", tw.list[2].name, ok(tw.list[2].name == "Boss Pawn" and tw.edit == nil))
	local r = rect("twarm", "id", pawnId)
	Spring.WarpMouse((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2)
end
steps[326] = function()
	click(rect("twname", "id", pawnId)) -- the rename window stays open for the picture
end
steps[330] = function()
	Spring.SendCommands("screenshot png")
	local t = units("armpw")
	log("the placed units carry the new name:", tostring(t[1] and Spring.GetUnitRulesParam(t[1], "ledtweakname")), ok(t[1] and Spring.GetUnitRulesParam(t[1], "ledtweakname") == "Boss Pawn"))
end
steps[336] = function()
	W():KeyPress(27, {}, false)
	log("the rename window was drawn and Esc closes it:", ok(tw.edit == nil and tw.list[2].name == "Boss Pawn"))
end
steps[350] = function()
	local _, saveLevel = W():DebugTeams()
	local n = saveLevel("zz_tweak_saved", true)
	log("saved units:", tostring(n), ok((n or 0) >= 3))
	Spring.SendCommands("led_clear")
end
steps[390] = function()
	local t, n = units("armpw")
	log("after clear:", #t + #n, ok(#t + #n == 0))
	local _, _, loadLevel = W():DebugTeams()
	loadLevel(nil, nil, { "zz_tweak_saved" })
end
steps[480] = function()
	local t, n = units("armpw")
	log("after load: tweaked", #t, "normal", #n, "health", t[1] and maxHealth(t[1]), "range", t[1] and Spring.GetUnitWeaponState(t[1], 1, "range"),
		ok(#t == 2 and #n == 1 and maxHealth(t[1]) == 2000 and near(Spring.GetUnitWeaponState(t[1], 1, "range"), 500)))
	local _, _, loadLevel = W():DebugTeams()
	loadLevel(nil, nil, { "tweak_test" }) -- the test level: two Boss Pawns and a Watch Tower, entries the library does not have
end
steps[580] = function()
	local t, n = units("armpw")
	local lt, ln = units("armllt")
	log("the test level: Pawns tweaked", #t, "normal", #n, "towers tweaked", #lt, "normal", #ln, ok(#t == 2 and #n == 1 and #lt == 1 and #ln == 1))
	log("the tower: health", lt[1] and maxHealth(lt[1]), "normal", ln[1] and maxHealth(ln[1]), ok(lt[1] and maxHealth(lt[1]) == 5000 and ln[1] and maxHealth(ln[1]) ~= 5000))
	local have = {}
	for _, e in ipairs(tw.list) do have[e.id] = e.name end
	log("the entries of the level are in the library:", tostring(have.armpw_boss1), tostring(have.armllt_tower), ok(have.armpw_boss1 == "Boss Pawn" and have.armllt_tower == "Watch Tower"))
	-- delete an entry: the second click confirms
	local n0 = #tw.list
	click(rect("twdel", "id", "armllt_tower"))
	log("the first click on Delete asks:", ok(#tw.list == n0 and rect("twdel", "id", "armllt_tower").label == "Sure?"))
	click(rect("twdel", "id", "armllt_tower"))
	log("the second click deletes the entry:", ok(#tw.list == n0 - 1))
	log("the placed tower keeps its values:", ok(lt[1] and maxHealth(lt[1]) == 5000))
end
steps[590] = function()
	click(rect("twexample"))
	local c = clip()
	log("Copy an example writes the clipboard:", ok(c:find("armpw = {", 1, true) ~= nil and c:find("health = 2000", 1, true) ~= nil and c:find("\n", 1, true) ~= nil))
	local n0 = #tw.list
	click(rect("twpaste"))
	log("the Paste button reads it from the clipboard:", tostring(tw.notice and tw.notice.text), ok(#tw.list == n0 + 1 and tw.list[1].base == "armpw" and tw.list[1].tw.health == 2000 and #tw.list[1].info.ignored == 0))
	click(rect("mode", "value", "units"))
end
steps[600] = function()
	tileName = rightClickTile(1)
	log("a right click on a unit tile opens the menu:", tostring(tileName), ok(rect("twmenu", "value", "units") ~= nil and rect("twmenu", "value", "defs") ~= nil))
	click(rect("twmenu", "value", "units"))
	local c = clip()
	log("Copy as tweakunits:", (c:gsub("%s+", " ")):sub(1, 160), ok(rect("twmenu") == nil and c:find(tileName .. " = {", 1, true) ~= nil and c:find("health = ", 1, true) ~= nil))
	local n0 = #tw.list
	local made = tw.paste()
	local e = tw.list[1]
	log("that text is pasted again without anything ignored:", tostring(tw.notice and tw.notice.text),
		ok(made == 1 and #tw.list == n0 + 1 and e.base == tileName and #e.info.ignored == 0 and e.tw.health == UnitDefNames[tileName].health))
end
steps[615] = function()
	rightClickTile(1)
	click(rect("twmenu", "value", "defs"))
	local c = clip()
	log("Copy as tweakdefs:", (c:gsub("%s+", " ")):sub(1, 160), ok(c:find('local u = UnitDefs["' .. tileName .. '"]', 1, true) ~= nil and c:find("\nu.health = ", 1, true) ~= nil))
	local n0 = #tw.list
	log("the Tweaks tab refuses that text as program code:", ok(tw.paste() == 0 and #tw.list == n0 and tostring(tw.notice and tw.notice.text):find("tweakdefs", 1, true) ~= nil))
	rightClickTile(1)
	W():MousePress(5, 5, 3)
	log("another click closes the menu:", ok(rect("twmenu") == nil))
end
steps[625] = function()
	rightClickTile(1)
	click(rect("twmenu", "value", "modify"))
	local hi, hr = winRow("health")
	log("Modify tweakunits opens the window with the values:", tw.win and #tw.win.rows, ok(tw.win ~= nil and tw.win.base == tileName and hr ~= nil and hr.value == UnitDefNames[tileName].health and rect("twclone") ~= nil and rect("twsave") == nil))
	if not hi then return end
	click(rect("twclone"))
	log("without a change no clone is made:", tostring(tw.notice and tw.notice.text), ok(tw.win ~= nil))
	typeValue(hi, "5000")
	log("a typed value is taken:", hr.value, ok(hr.value == 5000 and rect("twreset", "row", hi) ~= nil))
	click(rect("twwcopy"))
	local c = clip():gsub("%s+", " ")
	log("Copy of the window gives only the changed value:", c, ok(c == "{ " .. tileName .. " = { health = 5000 }, } " or c:find("health = 5000", 1, true) ~= nil and c:find("metalcost", 1, true) == nil))
end
steps[629] = function()
	Spring.SendCommands("screenshot png") -- the window of the values
end
steps[634] = function()
	local n0 = #tw.list
	click(rect("twclone"))
	log("Create clone makes the entry and shows the Tweaks tab:", tostring(tw.notice and tw.notice.text),
		ok(tw.win == nil and #tw.list == n0 + 1 and tw.list[1].base == tileName and tw.list[1].tw.health == 5000 and rect("twpaste") ~= nil))
	rightClick(rect("twarm", "id", "armpw_boss1"))
	log("a right click on an entry opens its menu:", ok(rect("twmenu", "value", "edit") ~= nil))
	click(rect("twmenu", "value", "edit"))
	local hi, hr = winRow("health")
	local _, rr = winRow("range", "emg")
	log("Edit opens the window with the values of the entry:", hr and hr.value, rr and rr.value, ok(tw.win ~= nil and tw.win.id == "armpw_boss1" and hr and hr.value == 2000 and rr and rr.value == 500 and rect("twsave") ~= nil))
	if not hi then return end
	typeValue(hi, "3000")
	click(rect("twsave"))
	local e = tw.known.armpw_boss1
	log("Save changes the entry:", ok(tw.win == nil and e.tw.health == 3000 and e.tw.weapondefs.emg.range == 500))
end
steps[660] = function()
	local t, n = units("armpw")
	log("the placed units of the entry have the new health:", t[1] and maxHealth(t[1]), t[2] and maxHealth(t[2]), "normal", n[1] and maxHealth(n[1]),
		ok(#t == 2 and maxHealth(t[1]) == 3000 and maxHealth(t[2]) == 3000 and n[1] and maxHealth(n[1]) ~= 3000 and near(Spring.GetUnitWeaponState(t[1], 1, "range"), 500)))
	rightClick(rect("twarm", "id", "armpw_boss1"))
	click(rect("twmenu", "value", "edit"))
	local hi = winRow("health")
	click(rect("twreset", "row", hi))
	local n0 = #tw.list
	click(rect("twclone"))
	log("Create new clone from an entry makes another entry:", tw.list[1] and tw.list[1].name, ok(#tw.list == n0 + 1 and tw.list[1].id ~= "armpw_boss1" and tw.list[1].tw.health == nil and tw.known.armpw_boss1.tw.health == 3000))
	rightClick(rect("twarm", "id", "armpw_boss1"))
	click(rect("twmenu", "value", "edit"))
	click(rect("twreset", "row", (winRow("health"))))
	click(rect("twsave"))
end
steps[690] = function()
	local t = units("armpw")
	log("a value set back to normal and saved: the placed units have the normal health again, the range stays:", t[1] and maxHealth(t[1]), t[1] and Spring.GetUnitWeaponState(t[1], 1, "range"),
		ok(#t == 2 and near(maxHealth(t[1]), UnitDefNames.armpw.health) and near(Spring.GetUnitWeaponState(t[1], 1, "range"), 500)))
	click(rect("mode", "value", "units"))
	rightClickTile(1)
	click(rect("twmenu", "value", "modify"))
	local opened = tw.win ~= nil
	W():KeyPress(27, {}, false)
	log("Esc closes the window:", ok(opened and tw.win == nil))
end
-- the box before an entry (visible: the list scrolls to it)
local function pickBox(e)
	for i, x in ipairs(tw.list) do
		if x == e then tw.lg.scroll = math.max(0, math.min(tw.lg:maxScroll(), i - 1)) end
	end
	return rect("twpick", "id", e.id)
end
steps[700] = function()
	click(rect("mode", "value", "tw"))
	for _, e in ipairs(tw.list) do e.pick = nil end
	Spring.SetClipboard("before")
	click(rect("twcopytext"))
	log("Copy checked with nothing checked:", tostring(tw.notice and tw.notice.text), ok(clip() == "before" and tostring(tw.notice and tw.notice.text):find("Check an entry", 1, true) ~= nil))
	local boss, other, second
	for _, e in ipairs(tw.list) do
		if e.id == "armpw_boss1" then boss = e
		elseif e.base ~= "armpw" and not other then other = e
		elseif e.base == "armpw" and not second then second = e end
	end
	if not (boss and other and second) then log("entries for the boxes missing WRONG") return end
	click(pickBox(boss))
	click(pickBox(other))
	log("a click on the box checks the entry:", ok(boss.pick == true and other.pick == true and pickBox(boss).tick == true))
	click(rect("twcopytext"))
	local c = clip()
	log("Copy checked as text:", (c:gsub("%s+", " ")):sub(1, 160), ok(c:find("armpw = {", 1, true) ~= nil and c:find(other.base .. " = {", 1, true) ~= nil and c:find("range = 500", 1, true) ~= nil))
	local plain = c
	click(rect("twcopyb64"))
	c = clip()
	log("Copy checked as base64:", c:sub(1, 60), ok(c:match("^[%w_%-]+$") ~= nil and #c > 20))
	local n0 = #tw.list
	log("the base64 text is pasted again as two entries:", ok(tw.paste(c) == 2 and #tw.list == n0 + 2 and tw.list[1].pick == nil))
	click(pickBox(second))
	Spring.SetClipboard("before")
	click(rect("twcopytext"))
	log("two checked entries of one unit type are refused:", tostring(tw.notice and tw.notice.text), ok(clip() == "before" and tostring(tw.notice and tw.notice.text):find("both change armpw", 1, true) ~= nil))
	click(pickBox(second))
	log("a second click unchecks:", ok(second.pick == nil))
	local lib = tw.libraryText() or "" -- (read by the widget: the test widget cannot open the file)
	local _, picks = lib:gsub(", pick = true }", "")
	log("the boxes are kept in the library:", picks, ok(picks == 2))
	local section = tw.lua({}) or ""
	local all = true
	for _, e in ipairs(tw.list) do all = all and section:find('"' .. e.id .. '"', 1, true) ~= nil end
	log("the level keeps every entry of the list, also unplaced ones:", #tw.list, ok(all and plain ~= ""))
	tw.lg.scroll = 0
end
steps[720] = function()
	Spring.SendCommands("screenshot png") -- (a step of its own: the tab drawn with its boxes)
end
steps[750] = function()
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
			if not ok2 then log("TEST ERROR at", k, tostring(err), "WRONG") end
			break
		end
	end
end
