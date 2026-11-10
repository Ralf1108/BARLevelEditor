-- Renegade (LAN Play, planned game mode; spec: specs/renegade.md): the first person view of the own unit. A game widget of the extra game "Level Editor
-- Scenarios", active only with the game option lanrenegade=1. Proof of concept 1 and 2:
--   camera   on the eye of the unit (team rules parameter renUnit of the gadget renegade_game.lua), looking along yaw / pitch; the engine camera "fps" "fps" (state logged with /renegade log)
--   mouse    the cursor is kept in the middle (Spring.WarpMouse), its movement turns yaw / pitch; the mouse buttons are taken (no selecting, no orders)
--   keys     W A S D are taken from the game (no camera scrolling) and sent to the gadget as a bit mask with the view: "ren|yaw|pitch|keys|fire"
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
	sentAt = -100, sent = nil,
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
	if R.unit and R.hidden then Spring.SetUnitNoDraw(R.unit, false) end
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
	Spring.SetUnitNoDraw(u, true) -- the own model is not drawn (local only)
	say("first person view on, unit", u, "camera fps")
end

local function disable()
	if R.unit and R.hidden then Spring.SetUnitNoDraw(R.unit, false) end
	R.hidden = false
	R.on = false
	R.keys, R.fire = 0, 0
	say("normal camera")
end

local function send(f, force)
	local yaw, pitch = math.floor(R.yaw + 0.5) % 360, math.floor(R.pitch + 0.5)
	local msg = string.format("ren|%d|%d|%d|%d", yaw, pitch, R.keys, R.fire)
	if msg == R.sent then return end
	if not force and f - R.sentAt < SEND_GAP then return end
	Spring.SendLuaRulesMsg(msg)
	R.sent, R.sentAt = msg, f
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
		if R.hidden and Spring.ValidUnitID(R.unit or -1) then Spring.SetUnitNoDraw(R.unit, false) end
		R.unit = u
		Spring.SetUnitNoDraw(u, true)
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
	gl.Color(1, 1, 1, 1)
end
