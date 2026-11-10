-- Renegade (LAN Play, planned game mode; spec: specs/renegade.md): the first person view of the own unit. A game widget of the extra game "Level Editor
-- Scenarios", active only with the game option lanrenegade=1.
--   camera   on the eye of the unit (team rules parameter renUnit of the gadget renegade_game.lua), looking along yaw / pitch; the engine camera "fps"
--   mouse    the cursor is kept in the middle (Spring.WarpMouse), its movement turns yaw / pitch; the mouse buttons are taken (no selecting, no orders)
--   keys     W A S D are taken from the game (no camera scrolling) and sent to the gadget as a bit mask with the view and the shot:
--            "ren|yaw|pitch|keys|fire|x|y|z|unit" (fire: 1 left button = main weapon, 2 right button = the other weapons; x y z the point under the crosshair
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
		h and math.floor(h.x) or 0, h and math.floor(h.y) or 0, h and math.floor(h.z) or 0, h and h.unit or -1)
	if msg == R.sent then return end
	if not force and f - R.sentAt < SEND_GAP then return end
	Spring.SendLuaRulesMsg(msg)
	R.sent, R.sentAt = msg, f
end

-- The weapons of the unit: R.main = the weapon of the left button (the gadget chooses the strongest one and publishes its number as the unit rules parameter
-- renMain), the others are fired with the right button; R.mainRange / R.maxRange = the ranges.
local function weaponsOf(u)
	local ud = UnitDefs[Spring.GetUnitDefID(u) or -1]
	local main = Spring.GetUnitRulesParam(u, "renMain") or 1
	local mainRange, maxRange = 0, 0
	for i, wp in ipairs(ud and ud.weapons or {}) do
		local wd = WeaponDefs[wp.weaponDef]
		if wd and wd.range then
			maxRange = math.max(maxRange, wd.range)
			if i == main then mainRange = wd.range end
		end
	end
	return ud, main, mainRange, maxRange
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
	if not R.fake and not R.menu then
		-- mouse look: the cursor goes back to the middle every frame, the way it moved is the turn
		local vsx, vsy = Spring.GetViewGeometry()
		local cx, cy = math.floor(vsx / 2), math.floor(vsy / 2)
		local mx, my = Spring.GetMouseState()
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
	if button == 1 then R.fire = R.fire - (R.fire % 2) + 1 end -- the left button: the main weapon (bit 1)
	if button == 3 then R.fire = (R.fire >= 2) and R.fire or R.fire + 2 end -- the right button: the other weapons (bit 2)
	if R.shot then send(Spring.GetGameFrame(), true) end -- at once, not with the next frame
	prevFire = R.fire
	return true
end

function widget:MouseRelease(x, y, button)
	if not R.on then return end
	if button == 1 and R.fire % 2 == 1 then R.fire = R.fire - 1 end
	if button == 3 and R.fire >= 2 then R.fire = R.fire - 2 end
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
	if R.on and key == 9 and R.debug then -- Tab: the mouse is free for the debug menu, again: back to the view
		R.menu = not R.menu
		R.list = false
		if R.picker then R.picker:setFocus(false) end
		return true
	end
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
-- the range rings on the ground round the unit: the main weapon thick and red, the others thin and yellow
function widget:DrawWorld()
	if not R.on or not R.unit then return end
	local x, y, z = Spring.GetUnitViewPosition(R.unit)
	if not x then return end
	local ud, main = weaponsOf(R.unit)
	if not ud then return end
	gl.DepthTest(false)
	local drawn = {}
	for i, wp in ipairs(ud.weapons or {}) do
		local wd = WeaponDefs[wp.weaponDef]
		if wd and wd.range and wd.range > 0 and not drawn[math.floor(wd.range)] then
			drawn[math.floor(wd.range)] = true
			if i == main then
				gl.LineWidth(5)
				gl.Color(1, 0.2, 0.15, 0.95)
			else
				gl.LineWidth(2.5)
				gl.Color(1, 0.85, 0.2, 0.8)
			end
			gl.DrawGroundCircle(x, y, z, wd.range, 64)
		end
	end
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

-- the panel at the bottom: health, then the weapons with their reload bars (LMB = the main weapon, RMB = the others)
local function panel(vsx, vsy)
	local u = R.unit
	local ud, main = weaponsOf(u)
	if not ud then return end
	local frame = Spring.GetGameFrame()
	local s = math.max(0.7, vsy / 1080)
	local w, h = 320 * s, 62 * s
	local rows = {}
	for i, wp in ipairs(ud.weapons or {}) do
		local wd = WeaponDefs[wp.weaponDef]
		if wd and (wd.damages and wd.range and wd.range > 0) then
			local at = Spring.GetUnitWeaponState(u, i, "reloadFrame") or 0
			local time = Spring.GetUnitWeaponState(u, i, "reloadTime") or wd.reload or 1
			local ready = at <= frame
			local fill = ready and 1 or math.max(0, math.min(1, 1 - (at - frame) / math.max(1, time * 30)))
			rows[#rows + 1] = { name = (wd.description and wd.description ~= "" and wd.description) or wd.name or "weapon", range = wd.range, fill = fill, ready = ready, time = time, main = i == main }
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
		gl.Color(r.main and 1 or 0.9, r.main and 0.45 or 0.8, r.main and 0.3 or 0.3, 1)
		gl.Text(r.main and "LMB" or "RMB", x1 + w - 10 * s, ry + 41 * s, 13 * s, "ro")
		gl.Color(0.7, 0.7, 0.7, 0.95)
		gl.Text(string.format("range %d   reload %.1f s   %s", r.range, r.time, r.ready and "READY" or "reloading"), x1 + 10 * s, ry + 24 * s, 12 * s, "o")
		gl.Color(0.15, 0.15, 0.15, 0.9)
		gl.Rect(x1 + 10 * s, ry + 6 * s, x1 + w - 10 * s, ry + 18 * s)
		if r.ready then gl.Color(0.3, 0.85, 0.35, 1) else gl.Color(0.95, 0.65, 0.15, 1) end
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

function widget:DrawScreen()
	if not R.on then return end
	local vsx, vsy = Spring.GetViewGeometry()
	local cx, cy, s = vsx / 2, vsy / 2, math.max(8, vsy / 90)
	-- what the crosshair points at and whether the main weapon reaches it: green = within reach, red = too far, white = the sky
	local h = R.hit
	local _, _, mainRange = weaponsOf(R.unit)
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
	gl.Color(1, 1, 1, 1)
	local x1, top, w, ps = panel(vsx, vsy)
	if R.debug and x1 then
		debugButton(x1, top, w, ps)
		if R.menu and R.list then drawPicker() else R.win = nil end
	end
end
