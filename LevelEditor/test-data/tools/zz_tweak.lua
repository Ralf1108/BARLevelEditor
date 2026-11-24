function widget:GetInfo() return { name = "zz tweak", desc = "test only: the Tweaks tab (tweaked units): paste, place, values, undo, copy, rename, save and load", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_tweak.lua: opens the Tweaks tab of the Place menu, pastes a tweakunits text (plain and in base64; a broken text and
-- program code are refused), arms an entry and places it with a click, compares the values of the tweaked unit with a normal one (health, range, damage,
-- cost, sight, speed), moves it and undoes that, copies it (Ctrl+C / Ctrl+V), renames the entry, saves the level, clears the map and loads it again, loads the
-- test level tweak_test (its entries come into the library) and deletes an entry. A picture of the tab. Logs "[zzar]" lines (OK / WRONG), ends with quitforce.
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
local tw, pawnId, firstId
local steps = {}
steps[40] = function()
	Spring.SetCameraTarget(4000, Spring.GetGroundHeight(4000, 4000), 4000, 0)
	tw = W():DebugTweaks()
	click(rect("mode", "value", "tw"))
	log("the tab Tweaks is open:", ok(rect("twpaste") ~= nil and rect("twhelp") ~= nil and rect("twhelp").tip:find("DOES NOT WORK", 1, true) ~= nil))
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
	for _ = 1, 45 do W():KeyPress(8, {}, false) end
	for c in ("Boss Pawn!"):gmatch(".") do W():TextInput(c) end
	W():KeyPress(13, {}, false)
	log("renamed:", tw.list[2].name, ok(tw.list[2].name == "Boss Pawn"))
	local r = rect("twarm", "id", pawnId)
	Spring.WarpMouse((r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2)
end
steps[330] = function()
	Spring.SendCommands("screenshot png")
	local t = units("armpw")
	log("the placed units carry the new name:", tostring(t[1] and Spring.GetUnitRulesParam(t[1], "ledtweakname")), ok(t[1] and Spring.GetUnitRulesParam(t[1], "ledtweakname") == "Boss Pawn"))
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
steps[620] = function()
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
