-- Renegade (LAN Play, planned game mode; spec: specs/renegade.md): the first person view of the own unit. A game widget of the extra game "Level Editor
-- Scenarios", active only with the game option lanrenegade=1.
--   camera   on the eye of the unit (team rules parameter renUnit of the gadget renegade_game.lua), looking along yaw / pitch; the engine camera "fps"
--   mouse    the cursor is kept in the middle (Spring.WarpMouse), its movement turns yaw / pitch; the mouse buttons are taken (no selecting, no orders)
--   keys     W A S D are taken from the game (no camera scrolling) and sent to the gadget as a bit mask with the view and the shot:
--            "ren|yaw|pitch|keys|fire|x|y|z|unit" (fire: 1 left button, 2 right button, 4 middle button, each fires a group of weapons; x y z the point under the crosshair
--            while firing, unit the enemy unit there or -1, not used by the gadget any more)
--   HUD      crosshair (green: the point under it is within reach of the main weapon, red: not), what it points at, health and weapons with their reload bars,
--            range rings round the unit
--   debug    (game option lanrenedebug=1) the button "Debug unit" over the panel opens the unit menu of the Level Editor (faction, group, tech level, pictures)
--   toggle   the key Insert or /renegade gives the normal camera back and forth; Tab frees the mouse for the debug menu
-- Test hooks for the test widget: WG.renegade.
function widget:GetInfo()
	return {
		name = "Renegade",
		desc = "First person view and steering of the own unit (game mode Renegade of LAN Play)",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 100,
		enabled = true,
	}
end

local SENS = 0.15 -- degrees per pixel of mouse movement
local EYE = 0.85 -- the eye at this part of the height of the unit
local SEND_GAP = 3 -- frames between two messages (a change of keys or buttons is sent at once)
local prevKeys, prevFire = 0, 0
local FAR = 3000 -- Elmo: the point of a shot into the sky
local K = { W = 119, A = 97, S = 115, D = 100 } -- key codes (the same as KEYSYMS)

local R = {
	on = false, -- first person view active
	unit = nil,
	yaw = 0, pitch = 0, -- degrees: yaw 0 looks along +z, 90 along +x; pitch up positive
	YAW0 = math.pi, -- ry of the camera when yaw is 0
	keys = 0, fire = 0,
	hit = nil, -- what the crosshair points at: { kind = "unit" | "ground", x, y, z, unit, dist (from the eye), udist (from the unit) }
	shot = nil, -- where a shot goes: the hit, or a far point along the view ray
	sentAt = -100, sent = nil,
	MARCH = 24, -- Elmo: step of the own ray over the heightmap
	AA_RADIUS = 0.15, -- the anti-air circle: its radius as a part of the screen height
	fake = false, -- the test widget steers (no mouse, no keys of the player)
}

local function say(...)
	Spring.Echo("[Renegade] " .. table.concat({ ... }, " "))
end

function widget:Initialize()
	local mo = Spring.GetModOptions() or {}
	if mo.lanrenegade ~= "1" then
		widgetHandler:RemoveWidget(self)
		return
	end
	WG.renegade = R
	R.debug = mo.lanrenedebug == "1"
end

function widget:Shutdown()
	if R.unit and R.hidden then Spring.SetUnitNoDraw(R.unit, false); Spring.SetUnitNoSelect(R.unit, false) end
	WG.renegade = nil
end

local function myUnit()
	local u = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit")
	if u and u > 0 and Spring.ValidUnitID(u) then return u end
	return nil
end

local function eye(u)
	local x, y, z = Spring.GetUnitViewPosition(u)
	if not x then return nil end
	return x, y + Spring.GetUnitHeight(u) * EYE, z
end

-- The camera "fps" takes its direction from the rotations rx (angle from straight up: pi / 2 = horizontal, less = looking up) and ry (0 looks along -z,
-- pi along +z); dx, dy, dz of the state are ignored (measured with zz_cam.lua). The camera names "free" and "ta" did not take over in a test.
local function setCamera(u)
	local px, py, pz = eye(u)
	if not px then return end
	Spring.SetCameraState({ name = "fps", mode = 0, oldHeight = 0, px = px, py = py, pz = pz, rx = math.pi / 2 - math.rad(R.pitch), ry = R.YAW0 - math.rad(R.yaw), rz = 0 }, 0)
end

local function enable(u)
	R.on = true
	R.unit = u
	R.hidden = true
	Spring.SetUnitNoDraw(u, true) -- the own model is not drawn and the screen ray and the mouse skip it (local only)
	Spring.SetUnitNoSelect(u, true)
	Spring.SelectUnitArray({}) -- the game draws the range rings of selected units: ours are drawn instead
	say("first person view on, unit", u, "camera fps")
end

local function disable()
	if R.unit and R.hidden then Spring.SetUnitNoDraw(R.unit, false); Spring.SetUnitNoSelect(R.unit, false) end
	R.hidden = false
	R.on = false
	R.keys, R.fire = 0, 0
	say("normal camera")
end

local function send(f, force)
	local yaw, pitch = math.floor(R.yaw + 0.5) % 360, math.floor(R.pitch + 0.5)
	local h = R.fire ~= 0 and R.shot
	local msg = string.format("ren|%d|%d|%d|%d|%d|%d|%d|%d", yaw, pitch, R.keys, R.fire,
		h and math.floor(h.x) or 0, h and math.floor(h.y) or 0, h and math.floor(h.z) or 0, R.aaTarget or (h and h.unit) or -1)
	if msg == R.sent then return end
	if not force and f - R.sentAt < SEND_GAP then return end
	Spring.SendLuaRulesMsg(msg)
	R.sent, R.sentAt = msg, f
end

-- The weapons of the unit in the groups of the three buttons (the gadget works them out, slotsFor, and publishes them as the unit rules parameter renSlots
-- "left;right;middle", each a list of weapon numbers, and renAA): slots = { L = {1, 3}, R = {2}, M = {} }. The colors: left red, right yellow, middle green;
-- the lines get thicker from red to green, so all three can be seen when they lie on each other.
local SLOTS = { { "L", "LMB", 1, { 1, 0.25, 0.2 }, 3 }, { "R", "RMB", 2, { 1, 0.85, 0.2 }, 5 }, { "M", "MMB", 4, { 0.3, 1, 0.35 }, 7 } } -- key, tag, bit, color, line width
local slotsText, slotsVal
local function slotsOf(u)
	local aaText = Spring.GetUnitRulesParam(u, "renAA") or ""
	local txt = (Spring.GetUnitRulesParam(u, "renSlots") or ";;") .. "|" .. aaText -- (a Pawn and an anti-air turret both have "1;;")
	if txt == slotsText then return slotsVal end
	local v = {}
	local k = 0
	for part in ((txt:match("^([^|]*)")) .. ";"):gmatch("([^;]*);") do
		k = k + 1
		local l = {}
		for n in part:gmatch("%d+") do l[#l + 1] = tonumber(n) end
		v[({ "L", "R", "M" })[k] or "x"] = l
	end
	v.aa = {}
	for n in aaText:gmatch("%d+") do v.aa[tonumber(n)] = true end
	slotsText, slotsVal = txt, v
	return v
end

-- the range of a group of weapons (the longest of them)
local function slotRange(ud, list)
	local best = 0
	for _, i in ipairs(list or {}) do
		local wp = ud.weapons[i]
		local wd = wp and WeaponDefs[wp.weaponDef]
		if wd and wd.range then best = math.max(best, wd.range) end
	end
	return best
end

local function weaponsOf(u)
	local ud = UnitDefs[Spring.GetUnitDefID(u) or -1]
	if not ud then return nil end
	local slots = slotsOf(u)
	return ud, slots, slotRange(ud, slots.L)
end

-- What the crosshair points at, and where a shot goes. R.hit = what is under the crosshair (a unit, the ground; nil = nothing), R.shot = where the shot goes:
-- the hit, or a far point along the view ray in the sky; the gadget shortens it to the reach of each weapon, so the unit can fire anywhere (sky, far
-- mountains, beyond its range), like in a shooter. The engine's ray TraceScreenRay answers "sky" for terrain it does not know (the scenery beyond the edge of
-- the map); then the ray is followed over the heightmap in steps (R.MARCH Elmo) as long as it stays inside the map.
local function march(px, py, pz, dx, dy, dz, maxDist)
	local step = R.MARCH
	local d = step
	local sx, sz = Game.mapSizeX, Game.mapSizeZ
	while d <= maxDist do
		local x, y, z = px + dx * d, py + dy * d, pz + dz * d
		if x < 0 or z < 0 or x > sx or z > sz then return nil end
		if y <= Spring.GetGroundHeight(x, z) then
			-- between the last two samples: bisect
			local lo, hi = d - step, d
			for _ = 1, 6 do
				local m = (lo + hi) / 2
				if py + dy * m <= Spring.GetGroundHeight(px + dx * m, pz + dz * m) then hi = m else lo = m end
			end
			return px + dx * hi, py + dy * hi, pz + dz * hi, hi
		end
		d = d + step
	end
	return nil
end

local function aim(u)
	local vsx, vsy = Spring.GetViewGeometry()
	local cx, cy = vsx / 2, vsy / 2
	local px, py, pz = Spring.GetCameraPosition()
	local dx, dy, dz = Spring.GetCameraDirection()
	-- measured: TraceScreenRay returns "unit", id or "ground", { x, y, z } (also with onlyCoords, which ignores units)
	local kind, v = Spring.TraceScreenRay(cx, cy, false, false, true)
	R.rayKind = kind
	local hit
	if kind == "unit" and v ~= u then
		local x, y, z = Spring.GetUnitPosition(v, true)
		if x then hit = { kind = "unit", x = x, y = y, z = z, unit = v } end
	end
	if not hit then
		local gx, gy, gz
		if kind == "ground" and type(v) == "table" then
			gx, gy, gz = v[1], v[2], v[3]
		else
			gx, gy, gz = march(px, py, pz, dx, dy, dz, 6000)
		end
		if gx then hit = { kind = "ground", x = gx, y = gy, z = gz, unit = -1 } end
	end
	if hit then
		hit.dist = math.sqrt((hit.x - px) ^ 2 + (hit.y - py) ^ 2 + (hit.z - pz) ^ 2)
		local ux, uy, uz = Spring.GetUnitPosition(u, true)
		hit.udist = ux and math.sqrt((hit.x - ux) ^ 2 + (hit.y - uy) ^ 2 + (hit.z - uz) ^ 2) or hit.dist
	end
	R.hit = hit
	R.shot = hit or { kind = "air", x = px + dx * FAR, y = py + dy * FAR, z = pz + dz * FAR, unit = -1, dist = FAR, udist = FAR }
end

-- Anti-air: a unit with anti-air weapons gets an orange circle round the crosshair (R.AA_RADIUS of the screen height, generous: aircraft are fast). The enemy aircraft in
-- range whose picture is nearest to the middle inside the circle is the lock (R.aaTarget): the anti-air weapons get it as their target when the button is pressed (their
-- missiles home in on it). Without an aircraft in the circle they do not fire.
local function aaPick(u)
	R.aaTarget, R.aaScreen, R.aaCircle = nil, nil, nil
	local ud, slots = weaponsOf(u)
	if not ud or next(slots.aa) == nil then return end
	local range = 0
	for i in pairs(slots.aa) do
		local wp = ud.weapons[i]
		local wd = wp and WeaponDefs[wp.weaponDef]
		if wd and wd.range then range = math.max(range, wd.range) end
	end
	local vsx, vsy = Spring.GetViewGeometry()
	local cx, cy = vsx / 2, vsy / 2
	local radius = vsy * R.AA_RADIUS
	R.aaCircle = radius
	local ux, uy, uz = Spring.GetUnitPosition(u, true)
	local px, py, pz = Spring.GetCameraPosition()
	local dx, dy, dz = Spring.GetCameraDirection()
	local best, bestD
	for _, id in ipairs(Spring.GetVisibleUnits(Spring.ENEMY_UNITS or -4, nil, true)) do
		local d = UnitDefs[Spring.GetUnitDefID(id) or -1]
		if d and d.canFly and not Spring.IsUnitAllied(id) then
			local x, y, z = Spring.GetUnitPosition(id, true)
			if x and ux and (x - ux) ^ 2 + (y - uy) ^ 2 + (z - uz) ^ 2 <= range * range and (x - px) * dx + (y - py) * dy + (z - pz) * dz > 0 then
				local sx, sy = Spring.WorldToScreenCoords(x, y, z)
				if sx then
					local dist = math.sqrt((sx - cx) ^ 2 + (sy - cy) ^ 2)
					if dist <= radius and (not bestD or dist < bestD) then best, bestD = id, dist; R.aaScreen = { sx, sy } end
				end
			end
		end
	end
	R.aaTarget = best
	if not best then R.aaScreen = nil end
end

local function keysNow()
	local k = 0
	if Spring.GetKeyState(K.W) then k = k + 1 end
	if Spring.GetKeyState(K.A) then k = k + 2 end
	if Spring.GetKeyState(K.S) then k = k + 4 end
	if Spring.GetKeyState(K.D) then k = k + 8 end
	return k
end

function widget:Update()
	if Spring.GetSpectatingState() then return end
	local u = myUnit()
	if not u then
		if R.on then disable() end
		return
	end
	if not R.on and not R.off then enable(u) end
	if not R.on then return end
	if u ~= R.unit then
		if R.hidden and Spring.ValidUnitID(R.unit or -1) then Spring.SetUnitNoDraw(R.unit, false); Spring.SetUnitNoSelect(R.unit, false) end
		R.unit = u
		Spring.SetUnitNoDraw(u, true)
		Spring.SetUnitNoSelect(u, true)
	end
	-- Tab: polled, not taken from KeyPress (as a commander the game's own use of the key came first and the press never reached this widget)
	local tab = Spring.GetKeyState(9)
	if tab and not R.tabWas and R.debug then
		R.menu = not R.menu
		R.list = false
		if R.picker then R.picker:setFocus(false) end
	end
	R.tabWas = tab
	if not R.fake and not R.menu then
		-- mouse look: the cursor goes back to the middle every frame, the way it moved is the turn
		local vsx, vsy = Spring.GetViewGeometry()
		local cx, cy = math.floor(vsx / 2), math.floor(vsy / 2)
		local mx, my, left, middle, right = Spring.GetMouseState()
		-- the buttons are read every frame too: a release that did not come must not keep the unit firing
		R.fire = (left and 1 or 0) + (right and 2 or 0) + (middle and 4 or 0)
		if mx ~= cx or my ~= cy then
			R.yaw = (R.yaw - (mx - cx) * SENS) % 360
			R.pitch = math.max(-89, math.min(89, R.pitch + (my - cy) * SENS))
			Spring.WarpMouse(cx, cy)
		end
		R.keys = keysNow()
	elseif R.menu then
		R.keys, R.fire = 0, 0 -- the menu: the mouse is free, nothing is steered or fired
	end
	if not R.menu then Spring.SetMouseCursor("none") end
	setCamera(u)
	aim(u)
	aaPick(u)
	send(Spring.GetGameFrame(), R.keys ~= prevKeys or R.fire ~= prevFire)
	prevKeys, prevFire = R.keys, R.fire
end

---------------------------------------------------------------- the unit menu of the Level Editor (debug): faction, group, tech level, pictures
-- editor_common.lua (shared with the Level Editor and the BluePrinter, in the extra game as luaui/Include/editor_common.lua) makes the list: Shared.newUnits
local Shared
local function picker()
	if R.picker then return R.picker end
	if Shared == nil then
		local ok, s = pcall(VFS.Include, "luaui/Include/editor_common.lua", nil, VFS.ZIP_FIRST)
		Shared = ok and s or false
		if not ok then say("the unit menu is not available:", tostring(s)) end
	end
	if not Shared then return nil end
	local cfg = Shared.newConfig("LuaUI/Config/RenegadeUnits.lua", "Renegade unit menu (not saved)", { uCols = 5, uRows = 4 }, { uCols = { 1, 8 }, uRows = { 1, 8 } })
	R.picker = Shared.newUnits({
		cfg = cfg, noPreview = true, factions = { "arm", "cor", "leg" },
		ownText = function(on) -- the search field: the typed text comes to widget:TextInput
			if on then widgetHandler:OwnText() else widgetHandler:DisownText() end
		end,
		groups = { "turrets", "bot", "vehicle", "hover", "air", "ships" },
		filter = function(ud) return #(ud.weapons or {}) > 0 end, -- what shoots: units and turrets
	})
	R.picker.group = "bot"
	return R.picker
end

-- the window of the menu: x1, x2, y0, top, the filter buttons, the area of the pictures
local function pickerLayout()
	local g = picker()
	if not g then return nil end
	Shared.rescale()
	local m = Shared.m
	local vsx, vsy = Spring.GetViewGeometry()
	local cw, ch = g:size()
	local hb = m.HB
	local filterH = g:filterRowCount() * (hb + 3) + m.PAD
	local w, h = cw + 2 * m.PAD, filterH + ch + 28 * Shared.S
	local x1 = math.max(4, (vsx - w) / 2)
	local y0 = math.max(4, (vsy - h) / 2)
	local win = { x1 = x1, x2 = x1 + w, y0 = y0, top = y0 + h }
	local grid = { x1 = win.x1 + m.PAD, x2 = win.x2 - m.PAD, y0 = win.y0 + 24 * Shared.S, top = win.top - filterH }
	local filters = g:filterRects(win.x1, win.x2, win.top - m.PAD, hb)
	return g, win, filters, grid, hb
end

local function drawPicker()
	local g, win, filters, grid, hb = pickerLayout()
	if not g then return end
	local S = Shared.S
	gl.Color(0, 0, 0, 0.85)
	gl.Rect(win.x1, win.y0, win.x2, win.top)
	Shared.drawButtons(filters, hb * 0.4, hb)
	local mx, my = Spring.GetMouseState()
	local ud = UnitDefs[Spring.GetUnitDefID(R.unit or -1) or -1]
	g:draw(grid, mx, my, ud and ud.name, nil, true)
	-- the name of the unit under the mouse pointer, under the pictures
	local i = g:at(grid, mx, my)
	local e = i and g:list()[i]
	gl.Color(1, 1, 1, 1)
	if e then
		local d = UnitDefs[e.id]
		gl.Text((d.translatedHumanName or d.humanName or e.name) .. "  (" .. e.name .. ")  " .. (d.tooltip or ""), win.x1 + 10 * S, win.y0 + 6 * S, 14 * S, "o")
	else
		gl.Text("Click a unit: you turn into it. Search: type words or the code. Tab: back to the game.", win.x1 + 10 * S, win.y0 + 6 * S, 14 * S, "o")
	end
	R.win = win
end

local function inRect(x, y, r) return r and x >= r[1] and x <= r[3] and y >= r[2] and y <= r[4] end

local function pickerClick(x, y)
	local g, win, filters, grid = pickerLayout()
	if not g then return end
	for _, r in ipairs(filters) do
		if x >= r.x1 and x <= r.x2 and y >= r.y0 and y <= r.y1 then
			g:applyFilter(r)
			return
		end
	end
	local i = g:at(grid, x, y)
	local e = i and g:list()[i]
	if e then
		Spring.SendLuaRulesMsg("ren|unit|" .. e.name)
		g:setFocus(false)
		R.list, R.menu = false, false
	end
end

---------------------------------------------------------------- the mouse and the keys: taken from the game while the view is on
local BUTTON_BIT = { [1] = 1, [3] = 2, [2] = 4 } -- left, right, middle

local function setBit(bit, on)
	local has = R.fire % (bit * 2) >= bit
	if on and not has then R.fire = R.fire + bit elseif not on and has then R.fire = R.fire - bit end
end

function widget:MousePress(x, y, button)
	if not R.on then return end
	if R.menu then
		if button == 1 then
			if R.list and R.win and x >= R.win.x1 and x <= R.win.x2 and y >= R.win.y0 and y <= R.win.top then
				pickerClick(x, y)
			elseif inRect(x, y, R.btn) then
				R.list = not R.list
			else
				R.list = false
			end
		end
		return true
	end
	if BUTTON_BIT[button] then setBit(BUTTON_BIT[button], true) end
	if R.shot then send(Spring.GetGameFrame(), true) end -- at once, not with the next frame
	prevFire = R.fire
	return true
end

function widget:MouseRelease(x, y, button)
	if not R.on then return end
	if BUTTON_BIT[button] then setBit(BUTTON_BIT[button], false) end
	if R.shot then send(Spring.GetGameFrame(), true) end
	prevFire = R.fire
	return true
end

function widget:MouseWheel(up, value)
	if R.on and R.menu and R.list and R.picker and R.win then
		local g, win, filters, grid = pickerLayout()
		if g then g:wheel(grid, up) end
	end
	return R.on
end

function widget:KeyPress(key, mods, isRepeat)
	if key == 277 then -- Insert
		if R.on then R.off = true; disable() else R.off = false end
		return true
	end
	if R.on and R.picker and R.picker.focus and key ~= 9 then
		return R.picker:key(key) -- typing in the search field (Enter: done, Esc: clear, Backspace)
	end
	if R.on and key == 9 and R.debug then return true end -- Tab: the mouse is free for the debug menu, again: back to the view (switched in Update)
	if R.on and (key == K.W or key == K.A or key == K.S or key == K.D) then
		return true
	end
end

function widget:TextInput(ch)
	if R.on and R.picker and R.picker.focus then return R.picker:textInput(ch) end
end

function widget:TextCommand(cmd)
	local a = cmd:match("^renegade%s*(%S*)")
	if not a then return end
	if a == "flip" then
		R.YAW0 = R.YAW0 + math.pi
		say("yaw offset", R.YAW0)
	elseif a == "log" then
		local st = Spring.GetCameraState()
		local t = {}
		for k, v in pairs(st) do t[#t + 1] = k .. "=" .. tostring(type(v) == "number" and string.format("%.3f", v) or v) end
		table.sort(t)
		say("camera", table.concat(t, " "))
	else
		if R.on then R.off = true; disable() else R.off = false end
	end
	return true
end

---------------------------------------------------------------- drawing
-- on the ground: the range rings round the unit and, for each group of weapons, a line from the unit in the direction its barrel points now (it turns
-- slower than you look round: fire when the line points where you look). Colors and widths as above; the thickest is drawn first.
local function groundLine(x, z, dx, dz, len)
	gl.BeginEnd(GL.LINE_STRIP, function()
		for k = 0, 16 do
			local px, pz = x + dx * len * k / 16, z + dz * len * k / 16
			gl.Vertex(px, Spring.GetGroundHeight(px, pz) + 6, pz)
		end
	end)
end

function widget:DrawWorld()
	if not R.on or not R.unit then return end
	local x, y, z = Spring.GetUnitViewPosition(R.unit)
	if not x then return end
	local ud, slots = weaponsOf(R.unit)
	if not ud then return end
	gl.DepthTest(false)
	for k = #SLOTS, 1, -1 do
		local sl = SLOTS[k]
		local list = slots[sl[1]]
		if list and #list > 0 then
			local range = slotRange(ud, list)
			gl.Color(sl[4][1], sl[4][2], sl[4][3], 0.95)
			gl.LineWidth(sl[5])
			gl.DrawGroundCircle(x, y, z, range, 64)
			-- the barrel
			-- (a weapon that is not aiming reports straight up: then the unit's facing counts)
			local _, _, _, dx, _, dz = Spring.GetUnitWeaponVectors(R.unit, list[1])
			local l = dx and math.sqrt(dx * dx + dz * dz) or 0
			if l < 0.2 then
				local fx, _, fz = Spring.GetUnitDirection(R.unit)
				dx, dz = fx or 0, fz or 1
				l = math.sqrt(dx * dx + dz * dz)
			end
			if l > 0.01 then
				gl.LineWidth(sl[5])
				groundLine(x, z, dx / l, dz / l, math.min(range, 260))
			end
		end
	end
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

-- the panel at the bottom: health, then the weapons with their reload bars (LMB = the main weapon, RMB = the others)
local function panel(vsx, vsy)
	local u = R.unit
	local ud, slots = weaponsOf(u)
	if not ud then return end
	local frame = Spring.GetGameFrame()
	local s = math.max(0.7, vsy / 1080)
	local w, h = 320 * s, 62 * s
	local rows = {}
	for _, sl in ipairs(SLOTS) do
		local list = slots[sl[1]]
		if list and #list > 0 then
			local i = list[1]
			local wd = WeaponDefs[ud.weapons[i].weaponDef]
			if wd then
				local at = Spring.GetUnitWeaponState(u, i, "reloadFrame") or 0
				local time = Spring.GetUnitWeaponState(u, i, "reloadTime") or wd.reload or 1
				local ready = at <= frame
				local fill = ready and 1 or math.max(0, math.min(1, 1 - (at - frame) / math.max(1, time * 30)))
				local name = (wd.description and wd.description ~= "" and wd.description) or wd.name or "weapon"
				if #list > 1 then name = name .. "  x" .. #list end
				rows[#rows + 1] = { name = name, range = slotRange(ud, list), fill = fill, ready = ready, time = time, tag = sl[2], color = sl[4], aa = slots.aa[i] }
			end
		end
	end
	local hh = 40 * s -- the health row
	local x1, y1 = (vsx - w) / 2 + 140 * s, 18 * s -- right of the middle: the buttons of the game are at the bottom left of it
	local total = #rows * h + hh + 8 * s
	R.panel = { x1, y1, x1 + w, y1 + total }
	gl.Color(0, 0, 0, 0.55)
	gl.Rect(x1, y1, x1 + w, y1 + total)
	for i, r in ipairs(rows) do
		local ry = y1 + 6 * s + (#rows - i) * h
		local name = r.name
		while #name > 4 and gl.GetTextWidth(name) * 15 * s > w - 70 * s do name = name:sub(1, -2) end
		gl.Color(1, 1, 1, 0.95)
		gl.Text(name, x1 + 10 * s, ry + 40 * s, 15 * s, "o")
		gl.Color(r.color[1], r.color[2], r.color[3], 1)
		gl.Text(r.tag, x1 + w - 10 * s, ry + 41 * s, 13 * s, "ro")
		gl.Color(0.7, 0.7, 0.7, 0.95)
		gl.Text(string.format("range %d   reload %.1f s   %s%s", r.range, r.time, r.ready and "READY" or "reloading", r.aa and "   (anti-air: look at the aircraft)" or ""), x1 + 10 * s, ry + 24 * s, 12 * s, "o")
		gl.Color(0.15, 0.15, 0.15, 0.9)
		gl.Rect(x1 + 10 * s, ry + 6 * s, x1 + w - 10 * s, ry + 18 * s)
		if r.ready then gl.Color(r.color[1], r.color[2], r.color[3], 1) else gl.Color(r.color[1] * 0.55, r.color[2] * 0.55, r.color[3] * 0.55, 1) end
		gl.Rect(x1 + 10 * s, ry + 6 * s, x1 + 10 * s + (w - 20 * s) * r.fill, ry + 18 * s)
	end
	-- health: a bar from red to green with the numbers
	local hp, mhp = Spring.GetUnitHealth(u)
	hp, mhp = hp or 0, math.max(1, mhp or 1)
	local frac = math.max(0, math.min(1, hp / mhp))
	local hy = y1 + 8 * s + #rows * h
	gl.Color(0.15, 0.15, 0.15, 0.9)
	gl.Rect(x1 + 10 * s, hy + 4 * s, x1 + w - 10 * s, hy + 26 * s)
	gl.Color(1 - frac, 0.25 + 0.65 * frac, 0.2, 1)
	gl.Rect(x1 + 10 * s, hy + 4 * s, x1 + 10 * s + (w - 20 * s) * frac, hy + 26 * s)
	gl.Color(1, 1, 1, 1)
	gl.Text(string.format("HEALTH  %d / %d", math.ceil(hp), math.floor(mhp)), x1 + w / 2, hy + 10 * s, 14 * s, "co")
	gl.Color(1, 1, 1, 1)
	return x1, y1 + total, w, s
end

-- the debug button above the panel: the unit; a click opens the unit menu
local function debugButton(x1, top, w, s)
	local ud = UnitDefs[Spring.GetUnitDefID(R.unit or -1) or -1]
	local bh = 28 * s
	local by = top + 8 * s
	R.btn = { x1, by, x1 + w, by + bh }
	gl.Color(R.list and 0.35 or 0.2, R.list and 0.35 or 0.2, R.menu and 0.5 or 0.2, 0.9)
	gl.Rect(x1, by, x1 + w, by + bh)
	gl.Color(1, 1, 1, 1)
	gl.Text("Debug unit: " .. (ud and (ud.translatedHumanName or ud.name) or "?") .. "  v", x1 + 10 * s, by + 8 * s, 14 * s, "o")
	if not R.menu then
		gl.Color(0.8, 0.8, 0.5, 1)
		gl.Text("Tab: free the mouse for the menu", x1 + w, by + bh + 4 * s, 11 * s, "ro")
	end
	gl.Color(1, 1, 1, 1)
end

-- after a loss: the countdown to the respawn (the gadget publishes the frame as the team rules parameter renRespawn)
local function countdown(vsx, vsy)
	local at = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renRespawn") or 0
	local frame = Spring.GetGameFrame()
	if at <= frame then return end
	local sec = math.ceil((at - frame) / 30)
	gl.Color(1, 0.25, 0.2, 1)
	gl.Text("YOU DIED", vsx / 2, vsy * 0.62, vsy / 14, "co")
	gl.Color(1, 1, 1, 1)
	gl.Text("respawn in " .. sec, vsx / 2, vsy * 0.52, vsy / 18, "co")
end

function widget:DrawScreen()
	local vsx0, vsy0 = Spring.GetViewGeometry()
	if not Spring.GetSpectatingState() then countdown(vsx0, vsy0) end
	if not R.on then return end
	local vsx, vsy = Spring.GetViewGeometry()
	local cx, cy, s = vsx / 2, vsy / 2, math.max(8, vsy / 90)
	-- what the crosshair points at and whether the main weapon reaches it: green = within reach, red = too far, white = the sky
	local h = R.hit
	local _, _, mainRange = weaponsOf(R.unit)
	mainRange = mainRange or 0
	local text
	local inReach = h and mainRange > 0 and h.udist <= mainRange
	if not h then
		text = "sky"
	elseif h.kind == "unit" then
		local d = UnitDefs[Spring.GetUnitDefID(h.unit) or -1]
		local hp, mhp = Spring.GetUnitHealth(h.unit)
		text = string.format("%s%s  %d%%  %d m", d and (d.translatedHumanName or d.name) or "unit", Spring.IsUnitAllied(h.unit) and " (ally)" or "", hp and mhp and math.floor(100 * hp / mhp) or 0, math.floor(h.udist))
	else
		text = string.format("ground  %d m", math.floor(h.udist))
	end
	if h then text = text .. (inReach and "  IN RANGE" or string.format("  OUT OF RANGE (%d)", mainRange)) end
	local r, g, b = 1, 1, 1
	if h then
		if inReach then r, g, b = 0.35, 1, 0.4 else r, g, b = 1, 0.3, 0.25 end
	end
	gl.Color(r, g, b, 0.95)
	gl.LineWidth(3)
	gl.BeginEnd(GL.LINES, function()
		gl.Vertex(cx - s, cy); gl.Vertex(cx - s / 3, cy)
		gl.Vertex(cx + s / 3, cy); gl.Vertex(cx + s, cy)
		gl.Vertex(cx, cy - s); gl.Vertex(cx, cy - s / 3)
		gl.Vertex(cx, cy + s / 3); gl.Vertex(cx, cy + s)
	end)
	gl.LineWidth(1)
	gl.Text(text, cx, cy - s * 2.2, math.max(12, vsy / 70), "co")
	-- anti-air: the orange circle (put the aircraft in it and press the button) and the lock on the aircraft
	if R.aaCircle then
		gl.Color(1, 0.6, 0.1, 0.9)
		gl.LineWidth(2.5)
		gl.BeginEnd(GL.LINE_LOOP, function()
			for a = 0, 63 do
				gl.Vertex(cx + R.aaCircle * math.cos(a * math.pi / 32), cy + R.aaCircle * math.sin(a * math.pi / 32))
			end
		end)
		if R.aaTarget and R.aaScreen then
			local sx, sy, q = R.aaScreen[1], R.aaScreen[2], math.max(14, vsy / 45)
			gl.Color(1, 0.7, 0.1, 1)
			gl.BeginEnd(GL.LINE_LOOP, function()
				gl.Vertex(sx - q, sy - q); gl.Vertex(sx + q, sy - q); gl.Vertex(sx + q, sy + q); gl.Vertex(sx - q, sy + q)
			end)
			local d = UnitDefs[Spring.GetUnitDefID(R.aaTarget) or -1]
			gl.Text("AA LOCK " .. (d and (d.translatedHumanName or d.name) or ""), sx, sy - q - 14, math.max(12, vsy / 75), "co")
		end
		gl.LineWidth(1)
	end
	gl.Color(1, 1, 1, 1)
	local x1, top, w, ps = panel(vsx, vsy)
	if R.debug and x1 then
		debugButton(x1, top, w, ps)
		if R.menu and R.list then drawPicker() else R.win = nil end
	end
end
