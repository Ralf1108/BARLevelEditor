-- Renegade (LAN Play, planned game mode; spec: specs/renegade.md): the first person view of the own unit. A game widget of the extra game "Level Editor
-- Scenarios", active only with the game option lanrenegade=1. Proof of concept 1 and 2:
--   camera   on the eye of the unit (team rules parameter renUnit of the gadget renegade_game.lua), looking along yaw / pitch; the engine camera "fps" "fps" (state logged with /renegade log)
--   mouse    the cursor is kept in the middle (Spring.WarpMouse), its movement turns yaw / pitch; the mouse buttons are taken (no selecting, no orders)
--   keys     W A S D are taken from the game (no camera scrolling) and sent to the gadget as a bit mask with the view: "ren|yaw|pitch|keys|fire|x|y|z|unit" (x y z: the point under the crosshair, unit: the enemy unit there or -1; zeros while not firing)
--   toggle   the key Insert or /renegade gives the normal camera back and forth
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
local SEND_GAP = 3 -- frames between two messages
local K = { W = 119, A = 97, S = 115, D = 100 } -- key codes (the same as KEYSYMS)

local R = {
	on = false, -- first person view active
	unit = nil,
	yaw = 0, pitch = 0, -- degrees: yaw 0 looks along +z, 90 along +x; pitch up positive
	YAW0 = math.pi, -- ry of the camera when yaw is 0
	keys = 0, fire = 0,
	hit = nil, -- what the crosshair points at: { kind = "unit" | "ground", x, y, z, unit, dist }
	sentAt = -100, sent = nil,
	MARCH = 24, -- Elmo: step of the own ray over the heightmap
	fake = false, -- the test widget steers (no mouse, no keys of the player)
	log = false,
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
	R.getState = function() return Spring.GetCameraState() end
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

local function look()
	local yaw, pitch = math.rad(R.yaw), math.rad(R.pitch)
	local c = math.cos(pitch)
	return math.sin(yaw) * c, math.sin(pitch), math.cos(yaw) * c
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
	local h = R.fire == 1 and R.shot
	local msg = string.format("ren|%d|%d|%d|%d|%d|%d|%d|%d", yaw, pitch, R.keys, R.fire,
		h and math.floor(h.x) or 0, h and math.floor(h.y) or 0, h and math.floor(h.z) or 0, h and h.unit or -1)
	if msg == R.sent then return end
	if not force and f - R.sentAt < SEND_GAP then return end
	Spring.SendLuaRulesMsg(msg)
	R.sent, R.sentAt = msg, f
end

-- What the crosshair points at, and where a shot goes. R.hit = what is under the crosshair (a unit, the ground; nil = nothing), R.shot = where the shot goes:
-- always a point along the view ray, never further than the weapon reaches, so the unit can fire anywhere (sky, far mountains, beyond its range), like in a shooter.
-- The engine's ray TraceScreenRay answers "sky" for terrain it does not know (the scenery beyond the edge of the map); then the ray is followed over the heightmap
-- in steps (R.MARCH Elmo) as long as it stays inside the map.
local function range(u)
	local ud = UnitDefs[Spring.GetUnitDefID(u) or -1]
	return ud and ud.maxWeaponRange or 300
end

local function march(px, py, pz, dx, dy, dz, maxDist)
	local step = R.MARCH
	local d = step
	local sx, sz = Game.mapSizeX, Game.mapSizeZ
	local lastAbove = true
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
	local reach = range(u) - 8
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
	if hit then hit.dist = math.sqrt((hit.x - px) ^ 2 + (hit.y - py) ^ 2 + (hit.z - pz) ^ 2) end
	R.hit = hit
	-- the shot: the hit when it is within reach, otherwise the point at the reach along the ray (no unit target then)
	if hit and hit.dist <= reach then
		R.shot = hit
	else
		R.shot = { kind = "air", x = px + dx * reach, y = py + dy * reach, z = pz + dz * reach, unit = -1, dist = reach }
	end
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
	if not R.fake then
		-- mouse look: the cursor goes back to the middle every frame, the way it moved is the turn
		local vsx, vsy = Spring.GetViewGeometry()
		local cx, cy = math.floor(vsx / 2), math.floor(vsy / 2)
		local mx, my, left = Spring.GetMouseState()
		if mx ~= cx or my ~= cy then
			R.yaw = (R.yaw - (mx - cx) * SENS) % 360
			R.pitch = math.max(-89, math.min(89, R.pitch + (my - cy) * SENS))
			Spring.WarpMouse(cx, cy)
		end
		R.keys = keysNow()
	end
	Spring.SetMouseCursor("none")
	setCamera(u)
	aim(u)
	send(Spring.GetGameFrame(), false)
end

-- take the mouse and the keys of the game away while the view is on
function widget:MousePress(x, y, button)
	if R.on then
		if button == 1 then R.fire = 1 end
		return true
	end
end

function widget:MouseRelease(x, y, button)
	if R.on and button == 1 then R.fire = 0 end
	return R.on
end

function widget:MouseWheel()
	return R.on
end

function widget:KeyPress(key, mods, isRepeat)
	if key == 277 then -- Insert
		if R.on then R.off = true; disable() else R.off = false end
		return true
	end
	if R.on and (key == K.W or key == K.A or key == K.S or key == K.D) then
		return true
	end
end

function widget:TextCommand(cmd)
	local a, b = cmd:match("^renegade%s*(%S*)%s*(%S*)")
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

-- the weapons of the unit at the bottom of the screen: name, range and the reload bar (full = ready)
local function weaponPanel(vsx, vsy)
	local u = R.unit
	local ud = u and UnitDefs[Spring.GetUnitDefID(u) or -1]
	if not ud then return end
	local frame = Spring.GetGameFrame()
	local s = math.max(0.7, vsy / 1080)
	local w, h = 300 * s, 62 * s
	local rows = {}
	for i, wp in ipairs(ud.weapons or {}) do
		local wd = WeaponDefs[wp.weaponDef]
		if wd and (wd.damages and wd.range and wd.range > 0) then
			local at = Spring.GetUnitWeaponState(u, i, "reloadFrame") or 0
			local time = Spring.GetUnitWeaponState(u, i, "reloadTime") or wd.reload or 1
			local ready = at <= frame
			local fill = ready and 1 or math.max(0, math.min(1, 1 - (at - frame) / math.max(1, time * 30)))
			rows[#rows + 1] = { name = (wd.description and wd.description ~= "" and wd.description) or wd.name or "weapon", range = wd.range, fill = fill, ready = ready, time = time }
		end
	end
	local x1, y1 = (vsx - w) / 2 + 140 * s, 18 * s -- right of the middle: the buttons of the game are at the bottom left of it
	local total = #rows * h + 8 * s
	gl.Color(0, 0, 0, 0.55)
	gl.Rect(x1, y1, x1 + w, y1 + total)
	for i, r in ipairs(rows) do
		local ry = y1 + 6 * s + (#rows - i) * h
		local name = r.name
		while #name > 4 and gl.GetTextWidth(name) * 15 * s > w - 20 * s do name = name:sub(1, -2) end
		gl.Color(1, 1, 1, 0.95)
		gl.Text(name, x1 + 10 * s, ry + 40 * s, 15 * s, "o")
		gl.Color(0.7, 0.7, 0.7, 0.95)
		gl.Text(string.format("range %d   reload %.1f s   %s", r.range, r.time, r.ready and "READY" or "reloading"), x1 + 10 * s, ry + 24 * s, 12 * s, "o")
		gl.Color(0.15, 0.15, 0.15, 0.9)
		gl.Rect(x1 + 10 * s, ry + 6 * s, x1 + w - 10 * s, ry + 18 * s)
		if r.ready then gl.Color(0.3, 0.85, 0.35, 1) else gl.Color(0.95, 0.65, 0.15, 1) end
		gl.Rect(x1 + 10 * s, ry + 6 * s, x1 + 10 * s + (w - 20 * s) * r.fill, ry + 18 * s)
	end
	gl.Color(1, 1, 1, 1)
end

-- the crosshair
function widget:DrawScreen()
	if not R.on then return end
	local vsx, vsy = Spring.GetViewGeometry()
	local cx, cy, s = vsx / 2, vsy / 2, math.max(8, vsy / 90)
	gl.Color(1, 1, 1, 0.9)
	gl.LineWidth(2)
	gl.BeginEnd(GL.LINES, function()
		gl.Vertex(cx - s, cy); gl.Vertex(cx - s / 3, cy)
		gl.Vertex(cx + s / 3, cy); gl.Vertex(cx + s, cy)
		gl.Vertex(cx, cy - s); gl.Vertex(cx, cy - s / 3)
		gl.Vertex(cx, cy + s / 3); gl.Vertex(cx, cy + s)
	end)
	gl.LineWidth(1)
	-- what the crosshair points at (proof of concept 3: debug text under the crosshair)
	local h = R.hit
	local text
	if not h then
		text = "sky"
	elseif h.kind == "unit" then
		local d = UnitDefs[Spring.GetUnitDefID(h.unit) or -1]
		local hp, mhp = Spring.GetUnitHealth(h.unit)
		text = string.format("%s%s  %d%%  %d m", d and (d.translatedHumanName or d.name) or "unit", Spring.IsUnitAllied(h.unit) and " (ally)" or "", hp and mhp and math.floor(100 * hp / mhp) or 0, math.floor(h.dist))
	else
		text = string.format("ground %d / %d  %d m", h.x, h.z, math.floor(h.dist))
	end
	local enemy = h and h.kind == "unit" and not Spring.IsUnitAllied(h.unit)
	gl.Color(enemy and 1 or 0.9, enemy and 0.3 or 0.9, enemy and 0.3 or 0.9, 1)
	gl.Text(text, cx, cy - s * 2.2, math.max(12, vsy / 70), "co")
	gl.Color(1, 1, 1, 1)
	weaponPanel(vsx, vsy)
end
