-- Renegade (LAN Play, planned game mode; spec: specs/renegade.md): the first person view of the own unit. A game widget of the extra game "Level Editor
-- Scenarios", active only with the game option lanrenegade=1.
--   camera   on the eye of the unit (team rules parameter renUnit of the gadget renegade_game.lua), looking along yaw / pitch; the engine camera "fps"
--   mouse    the cursor is kept in the middle (Spring.WarpMouse), its movement turns yaw / pitch; the mouse buttons are taken (no selecting, no orders)
--   keys     W A S D are taken from the game (no camera scrolling) and sent to the gadget as a bit mask with the view and the shot:
--            "ren|yaw|pitch|keys|fire|x|y|z|unit" (fire: 1 left button, 2 right button, 4 middle button, each fires a group of weapons; x y z the point under the crosshair
--            while firing, unit the enemy unit there or -1, not used by the gadget any more)
--   HUD      crosshair (green: a weapon that is valid for what it points at reaches it, yellow: at the limit, red: none reaches it), what it points at and how far, health and
--            weapons with their reload bars and the same colours on their rows (range rings only with /renegade rings)
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
local K = { W = 119, A = 97, S = 115, D = 100, SPACE = 32 } -- key codes (the same as KEYSYMS)

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
	if R.third then
		-- third person (Shift): the camera orbits the unit at the same look direction: behind it and above, the unit stays where it is on the screen whatever the pitch; the aim (the
		-- crosshair in the middle of the screen) works as before, the unit shoots at the point the crosshair points at
		local yaw, pit = math.rad(R.yaw), math.rad(R.pitch)
		local fx, fz = math.sin(yaw), math.cos(yaw) -- (yaw 0 looks along +z, as the camera rotation ry = YAW0 - yaw says)
		local cp, sp = math.cos(pit), math.sin(pit)
		local dist = math.max(100, (Spring.GetUnitRadius(u) or 30) * 3.5)
		local up = dist * 0.12 -- (low: the unit stays above the panel at the bottom of the screen)
		px = px - cp * fx * dist - sp * fx * up
		py = py - sp * dist + cp * up
		pz = pz - cp * fz * dist - sp * fz * up
		py = math.max(py, Spring.GetGroundHeight(px, pz) + 8)
	end
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
	local h = R.shot -- (always: the turret follows the view even when nothing is fired)
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
	local hyText = Spring.GetUnitRulesParam(u, "renHY") or ""
	local txt = (Spring.GetUnitRulesParam(u, "renSlots") or ";;") .. "|" .. aaText .. "|" .. hyText -- (a Pawn and an anti-air turret both have "1;;")
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
	v.hy = {}
	for n in hyText:gmatch("%d+") do v.hy[tonumber(n)] = true end
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

-- The guns of a gunship are fixed to its body: they point (almost) along its nose and can only turn down by MAX_DOWN degrees (measured with the Roughneck: whatever
-- the view, the barrel stays at about 27 degrees down). A point on the ground that lies steeper below the aircraft cannot be hit. fixedGun tells whether the unit is such an
-- aircraft; the radius of the dead zone on the ground under the aircraft is its height / tan(MAX_DOWN). A point under the crosshair that lies in the dead zone is moved out
-- along the ground to the edge of the zone (correctShot): the shot goes there, the crosshair says so and a marker shows the point; the unit keeps its free movement.
local MAX_DOWN = 27
local function fixedGun(ud, slots)
	if not (ud.canFly and (ud.isHoveringAirUnit or ud.hoverAttack)) then return false end
	for _, key in ipairs({ "L", "R", "M" }) do
		local i = slots[key] and slots[key][1]
		local wd = i and ud.weapons[i] and WeaponDefs[ud.weapons[i].weaponDef]
		if wd and not wd.turret and wd.type ~= "AircraftBomb" then return true end
	end
	return false
end
local function deadRadius(u)
	local x, y, z = Spring.GetUnitPosition(u, true)
	if not x then return 0 end
	return math.max(0, y - Spring.GetGroundHeight(x, z)) / math.tan(math.rad(MAX_DOWN))
end

local function correctShot(u)
	R.corrected = nil
	local ud, slots = weaponsOf(u)
	local h = R.hit
	if not ud or not h or not R.shot or not fixedGun(ud, slots) then return end
	local ux, uy, uz = Spring.GetUnitPosition(u, true)
	if not ux then return end
	local dx, dz = h.x - ux, h.z - uz
	local hd = math.sqrt(dx * dx + dz * dz)
	if hd >= 1 and math.deg(math.atan2(uy - h.y, hd)) <= MAX_DOWN then return end -- reachable: as aimed
	if hd < 1 then
		local fx, _, fz = Spring.GetUnitDirection(u)
		dx, dz = fx or 0, fz or 1
		hd = math.sqrt(dx * dx + dz * dz)
		if hd < 0.01 then return end
	end
	local nx, nz = dx / hd, dz / hd
	local d, x, z, g = hd
	for _ = 1, 4 do
		x = math.max(1, math.min(Game.mapSizeX - 1, ux + nx * d))
		z = math.max(1, math.min(Game.mapSizeZ - 1, uz + nz * d))
		g = Spring.GetGroundHeight(x, z)
		d = math.max(1, (uy - g) / math.tan(math.rad(MAX_DOWN)))
	end
	R.shot = { kind = "ground", x = x, y = g, z = z, unit = -1, dist = R.shot.dist, udist = d }
	R.corrected = { x = x, y = g, z = z, d = d }
end


-- Which weapons shoot in an arc (they need the impact preview and can be fired at the sky, see aim): the missiles, starburst rockets and artillery (by type), a cannon that is always
-- fired high (highTrajectory 1) and a cannon whose shell has to leave at 20 degrees or more to reach its maximum range (sin 2a = range x gravity / speed^2 from 0.64: the Mauser 29 degrees, the
-- tank guns 18 to 21, a Pawn 2); cannons, gauss, heat rays and the like that shoot flat have only the crosshair.
local LOB = { MissileLauncher = true, StarburstLauncher = true, ArtilleryShell = true }
local function lobbed(wd)
	if LOB[wd.type] then return true end
	if wd.type ~= "Cannon" then return false end
	if (tonumber(wd.highTrajectory) or 0) == 1 then return true end
	local g = (tonumber(wd.myGravity) or 0) > 0 and wd.myGravity or (Game.gravity or 120) / 900
	local v = tonumber(wd.projectilespeed) or 0
	return v > 0 and (tonumber(wd.range) or 0) * g / (v * v) >= 0.64
end
-- whether every weapon group of the unit (the anti-air ones aside) shoots in an arc, and the longest range of them: a unit like that can be fired at the sky (a point on the ground at that range)
local function lobbedAll(ud, slots)
	local n, range = 0, 0
	for _, key in ipairs({ "L", "R", "M" }) do
		local list = slots[key]
		local i = list and list[1]
		local wd = i and not slots.aa[i] and ud.weapons[i] and WeaponDefs[ud.weapons[i].weaponDef]
		if wd then
			if not lobbed(wd) then return false, 0 end
			n = n + 1
			range = math.max(range, slotRange(ud, list))
		end
	end
	return n > 0, range
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
	R.skyShot = nil
	if not hit then
		-- looking at the sky with a unit that only has arc weapons (the Mauser, an artillery tower): the shot goes to a point on the ground at the maximum range, in the direction of the view
		local ud0, sl0 = weaponsOf(u)
		local ux, uy, uz = Spring.GetUnitPosition(u, true)
		if ud0 and ux then
			local all, range = lobbedAll(ud0, sl0)
			if all and range > 50 then
				local hl = math.sqrt(dx * dx + dz * dz)
				local nx, nz
				if hl > 0.05 then nx, nz = dx / hl, dz / hl else nx, nz = Spring.GetUnitDirection(u) end
				nx, nz = nx or 0, nz or 1
				local d = range * 0.95
				local x = math.max(1, math.min(Game.mapSizeX - 1, ux + nx * d))
				local z = math.max(1, math.min(Game.mapSizeZ - 1, uz + nz * d))
				R.skyShot = { kind = "ground", x = x, y = Spring.GetGroundHeight(x, z), z = z, unit = -1, dist = d, udist = d }
			end
		end
	end
	R.shot = hit or R.skyShot or { kind = "air", x = px + dx * FAR, y = py + dy * FAR, z = pz + dz * FAR, unit = -1, dist = FAR, udist = FAR }
end

-- Anti-air: a unit with anti-air weapons gets an orange circle round the crosshair (R.AA_RADIUS of the screen height, generous: aircraft are fast). The enemy aircraft in
-- range whose picture is nearest to the middle inside the circle is the lock (R.aaTarget): the anti-air weapons get it as their target when the button is pressed (their
-- missiles home in on it). Without an aircraft in the circle they do not fire.
-- An aircraft that is shot down is no target any more: no health left, dead, or crashing (the aircraft state "crashing" of its move type: it is on its way down and falls)
local function shotDown(id)
	if Spring.GetUnitIsDead(id) then return true end
	local hp = Spring.GetUnitHealth(id)
	if hp and hp <= 0 then return true end
	local ok, md = pcall(Spring.GetUnitMoveTypeData, id)
	return ok and type(md) == "table" and md.aircraftState == "crashing"
end
local function aaPick(u)
	R.aaTarget, R.aaScreen, R.aaCircle = nil, nil, nil
	local ud, slots = weaponsOf(u)
	if not ud or (next(slots.aa) == nil and next(slots.hy) == nil) then return end
	local range = 0
	for _, set in ipairs({ slots.aa, slots.hy }) do
		for i in pairs(set) do
			local wp = ud.weapons[i]
			local wd = wp and WeaponDefs[wp.weaponDef]
			if wd and wd.range then range = math.max(range, wd.range) end
		end
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
		if d and d.canFly and not Spring.IsUnitAllied(id) and not shotDown(id) then
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
	if Spring.GetKeyState(K.SPACE) then k = k + 16 end -- higher (an aircraft that hovers)
	if select(2, Spring.GetModKeyState()) then k = k + 32 end -- Ctrl: lower
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
		Spring.SetUnitNoDraw(u, not R.third)
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
	-- Alt switches the mode "FULL FIRE" on and off: the left button then fires every weapon at once
	local alt = Spring.GetModKeyState()
	if alt and not R.altWas then R.full = not R.full end
	R.altWas = alt
	-- Shift switches between the first person view and the third person view (the camera behind and above the unit; the unit is drawn then); not while the menu has the keyboard (capital letters)
	local shift = select(4, Spring.GetModKeyState())
	if shift and not R.shiftWas and not R.menu and R.on then
		R.third = not R.third
		Spring.SetUnitNoDraw(u, not R.third)
	end
	R.shiftWas = shift
	if not R.fake and not R.menu then
		-- mouse look: the cursor goes back to the middle every frame, the way it moved is the turn
		local vsx, vsy = Spring.GetViewGeometry()
		local cx, cy = math.floor(vsx / 2), math.floor(vsy / 2)
		local mx, my, left, middle, right = Spring.GetMouseState()
		-- the buttons are read every frame too: a release that did not come must not keep the unit firing
		R.fire = (left and 1 or 0) + (right and 2 or 0) + (middle and 4 or 0)
		if left and R.full then R.fire = 7 end -- FULL FIRE: the left button fires every weapon
		if mx ~= cx or my ~= cy then
			-- A jump of the cursor is not a turn (the bug "suddenly looking straight up"): after the menu, after a pause of the game or the window (the cursor was somewhere else, the
			-- warp did not take effect while the window was not in front) and a jump of more than 40% of the screen in one frame only put the cursor back; the first frame after
			-- one of these is skipped too.
			local now = os.clock()
			local gap = now - (R.lookClock or now)
			R.lookClock = now
			local jump = math.abs(mx - cx) > vsx * 0.4 or math.abs(my - cy) > vsy * 0.4
			if R.skipLook or gap > 0.25 or jump then
				R.lookSkipped = (R.lookSkipped or 0) + 1 -- (for the tests)
				R.skipLook = false
			else
				R.yaw = (R.yaw - (mx - cx) * SENS) % 360
				R.pitch = math.max(-89, math.min(89, R.pitch + (my - cy) * SENS))
			end
			Spring.WarpMouse(cx, cy)
		else
			R.lookClock = os.clock()
		end
		R.keys = keysNow()
	elseif R.menu then
		R.keys, R.fire = 0, 0 -- the menu: the mouse is free, nothing is steered or fired
		R.skipLook = true -- (the cursor is somewhere else when the menu closes: no turn from that)
	end
	if not R.menu then Spring.SetMouseCursor("none") end
	setCamera(u)
	aim(u)
	correctShot(u)
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
	g:draw(grid, mx, my, R.pickMode ~= "enemy" and ud and ud.name or nil, nil, true)
	-- the name of the unit under the mouse pointer, under the pictures
	local i = g:at(grid, mx, my)
	local e = i and g:list()[i]
	gl.Color(1, 1, 1, 1)
	if e then
		local d = UnitDefs[e.id]
		gl.Text((d.translatedHumanName or d.humanName or e.name) .. "  (" .. e.name .. ")  " .. (d.tooltip or ""), win.x1 + 10 * S, win.y0 + 6 * S, 14 * S, "o")
	else
		gl.Text(R.pickMode == "enemy" and "Click a unit: it appears as an enemy 1000 Elmo ahead. Search: type words or the code. Tab: back to the game."
			or "Click a unit: you turn into it. Search: type words or the code. Tab: back to the game.", win.x1 + 10 * S, win.y0 + 6 * S, 14 * S, "o")
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
		if R.pickMode == "enemy" then
			Spring.SendLuaRulesMsg("ren|spawn|" .. e.name) -- an enemy 1000 Elmo ahead; the menu stays open for more
		else
			Spring.SendLuaRulesMsg("ren|unit|" .. e.name)
			g:setFocus(false)
			R.list, R.menu = false, false
		end
	end
end

---------------------------------------------------------------- the mouse and the keys: taken from the game while the view is on
local BUTTON_BIT = { [1] = 1, [3] = 2, [2] = 4 } -- left, right, middle

local function setBit(bit, on)
	local has = R.fire % (bit * 2) >= bit
	if on and not has then R.fire = R.fire + bit elseif not on and has then R.fire = R.fire - bit end
	if bit == 1 and on and R.full then R.fire = 7 end -- FULL FIRE: the left button fires every weapon
end

function widget:MousePress(x, y, button)
	if not R.on then return end
	if R.menu then
		if button == 1 then
			if R.list and R.win and x >= R.win.x1 and x <= R.win.x2 and y >= R.win.y0 and y <= R.win.top then
				pickerClick(x, y)
			elseif inRect(x, y, R.btn3) then
				R.rings = not R.rings -- (the debug button Range: the range rings on the ground on and off; off at the start)
			elseif inRect(x, y, R.btn) or inRect(x, y, R.btn2) then
				local mode = inRect(x, y, R.btn) and "self" or "enemy"
				if R.list and R.pickMode == mode then R.list = false else R.list, R.pickMode = true, mode end
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
	if R.on and (key == K.W or key == K.A or key == K.S or key == K.D or key == K.SPACE) then
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
	elseif a == "rings" then
		R.rings = not R.rings
		say("range rings", R.rings and "on" or "off")
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
-- on the ground: the range rings round the unit (on request); where the vehicle and the weapons point is shown by the compass on the screen (`compass`)
local function groundLine(x, z, dx, dz, len)
	gl.BeginEnd(GL.LINE_STRIP, function()
		for k = 0, 16 do
			local px, pz = x + dx * len * k / 16, z + dz * len * k / 16
			gl.Vertex(px, Spring.GetGroundHeight(px, pz) + 6, pz)
		end
	end)
end
-- Impact preview of the weapons that lob their shots (artillery, rockets, missiles): where the shot comes down. The point under the crosshair on the ground, shortened to
-- the reach of the weapon, as a filled disc of the size of the explosion with a ring, a cross and a tall beam (like a laser pointer, only bigger), in the color of the
-- button, and a line from the unit to it. Not for beams, plasma lines and flames: they hit what is on the line, the barrel lines show them.
local function impactPreview(ux, uy, uz, wd, color, bomb)
	local x, z, dx, dz, d
	if bomb then
		-- a bomb keeps the speed of the aircraft and falls: where it lands if it were dropped now (the fall time from the height over the ground, a few passes)
		local vx, vy, vz = Spring.GetUnitVelocity(R.unit)
		if not vx then return end
		local g = (tonumber(wd.myGravity) or 0) > 0 and wd.myGravity or (Game.gravity or 120) / 900 -- Elmo per frame per frame (the bomb's own gravity, measured 0.4 for the Tsunami)
		x, z = ux, uz
		for _ = 1, 4 do
			local gy = Spring.GetGroundHeight(x, z)
			local drop = uy - gy
			local tt = (vy + math.sqrt(vy * vy + 2 * g * math.max(0, drop))) / g -- frames
			x, z = ux + vx * tt, uz + vz * tt
		end
		dx, dz = x - ux, z - uz
		d = math.sqrt(dx * dx + dz * dz)
		if d < 1 then dx, dz, d = 0, 1, 1 end
	else
		local h = R.hit or R.skyShot
		if not h then return end
		local range = (tonumber(wd.range) or 0) - 8
		dx, dz = h.x - ux, h.z - uz
		d = math.sqrt(dx * dx + dz * dz)
		if d < 1 then return end
		if d > range then dx, dz, d = dx * range / d, dz * range / d, range end
		x, z = ux + dx, uz + dz
	end
	local y = Spring.GetGroundHeight(x, z)
	local aoe = math.max(16, tonumber(wd.damageAreaOfEffect) or 16)
	gl.Color(color[1], color[2], color[3], 0.22)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Vertex(x, y + 4, z)
		for k = 0, 32 do
			local a = k / 32 * 2 * math.pi
			gl.Vertex(x + math.cos(a) * aoe, Spring.GetGroundHeight(x + math.cos(a) * aoe, z + math.sin(a) * aoe) + 4, z + math.sin(a) * aoe)
		end
	end)
	gl.Color(0, 0, 0, 0.7)
	gl.LineWidth(7)
	gl.DrawGroundCircle(x, y, z, aoe, 40)
	gl.Color(color[1], color[2], color[3], 1)
	gl.LineWidth(4)
	gl.DrawGroundCircle(x, y, z, aoe, 40)
	gl.BeginEnd(GL.LINES, function()
		gl.Vertex(x - aoe * 0.5, y + 6, z); gl.Vertex(x + aoe * 0.5, y + 6, z)
		gl.Vertex(x, y + 6, z - aoe * 0.5); gl.Vertex(x, y + 6, z + aoe * 0.5)
	end)
	if bomb then
		-- (a bomber: the line to the landing point)
		gl.LineWidth(2)
		gl.Color(color[1], color[2], color[3], 0.6)
		groundLine(ux, uz, dx / d, dz / d, d)
	end
end

function widget:DrawWorld()
	if not R.on or not R.unit then return end
	local x, y, z = Spring.GetUnitViewPosition(R.unit)
	if not x then return end
	local ud, slots = weaponsOf(R.unit)
	if not ud then return end
	gl.DepthTest(false)
	for k = 1, #SLOTS do
		local sl = SLOTS[k]
		local list = slots[sl[1]]
		if list and #list > 0 then
			local range = slotRange(ud, list)
			gl.Color(sl[4][1], sl[4][2], sl[4][3], 0.95)
			gl.LineWidth(sl[5])
			if R.rings then gl.DrawGroundCircle(x, y, z, range, 64) end -- (the range rings only on request: /renegade rings)
		end
	end
	for k = #SLOTS, 1, -1 do
		local list = slots[SLOTS[k][1]]
		local wp = list and list[1] and ud.weapons[list[1]]
		local wd = wp and WeaponDefs[wp.weaponDef]
		if wd and not slots.aa[list[1]] then
			if wd.type == "AircraftBomb" then impactPreview(x, y, z, wd, SLOTS[k][4], true)
			elseif lobbed(wd) then impactPreview(x, y, z, wd, SLOTS[k][4]) end
		end
	end
	if fixedGun(ud, slots) then
		-- the dead zone of the fixed guns: the ground right under the aircraft that is too steep to hit
		local rad = deadRadius(R.unit)
		if rad > 20 then
			gl.Color(1, 0.2, 0.15, 0.9)
			gl.LineWidth(4)
			gl.DrawGroundCircle(x, y, z, rad, 48)
			gl.Color(1, 0.2, 0.15, 0.25)
			gl.BeginEnd(GL.TRIANGLE_FAN, function()
				gl.Vertex(x, Spring.GetGroundHeight(x, z) + 3, z)
				for k = 0, 48 do
					local a = k / 48 * 2 * math.pi
					local px, pz = x + math.cos(a) * rad, z + math.sin(a) * rad
					gl.Vertex(px, Spring.GetGroundHeight(px, pz) + 3, pz)
				end
			end)
		end
		if R.corrected then
			-- where the shot goes when the aim is too steep: a ring, a cross and a beam at the edge of the zone
			local c = R.corrected
			gl.Color(0, 0, 0, 0.7)
			gl.LineWidth(7)
			gl.DrawGroundCircle(c.x, c.y, c.z, 36, 32)
			gl.Color(1, 0.75, 0.2, 1)
			gl.LineWidth(4)
			gl.DrawGroundCircle(c.x, c.y, c.z, 36, 32)
			gl.BeginEnd(GL.LINES, function()
				gl.Vertex(c.x - 24, c.y + 6, c.z); gl.Vertex(c.x + 24, c.y + 6, c.z)
				gl.Vertex(c.x, c.y + 6, c.z - 24); gl.Vertex(c.x, c.y + 6, c.z + 24)
				gl.Vertex(c.x, c.y, c.z); gl.Vertex(c.x, c.y + 300, c.z)
			end)
		end
	end
	gl.LineWidth(1)
	gl.Color(1, 1, 1, 1)
end

-- the panel at the bottom: health, then the weapons with their reload bars (LMB = the main weapon, RMB = the others)
-- Which weapons reach what the crosshair points at (R.hit): for each group of weapons its first weapon is checked: is it valid for the target (an aircraft: only anti-air weapons and
-- the ones that can fire at both; anything else: not the anti-air-only ones) and the distance from the unit against its range: green = well within it (up to 90% of the range),
-- yellow = at the limit (up to 110%), red = out of reach or no weapon for this target. nil = nothing to say (the sky, an aircraft or a bomber: it drops, no range).
local EDGE = 0.1
local function dropper(ud, slots)
	local i0 = slots.L and slots.L[1]
	local wd0 = i0 and ud.weapons[i0] and WeaponDefs[ud.weapons[i0].weaponDef]
	return (ud.canFly or (wd0 and wd0.type == "AircraftBomb")) and true or false
end
local function reach(ud, slots, list, h)
	if not h then return nil end
	local i = list[1]
	local wp = ud.weapons[i]
	local wd = wp and WeaponDefs[wp.weaponDef]
	if not wd then return nil end
	local range = slotRange(ud, list)
	local air = false
	if h.kind == "unit" then
		local d = UnitDefs[Spring.GetUnitDefID(h.unit) or -1]
		air = d and d.canFly or false
	end
	local valid
	if air then valid = slots.aa[i] or slots.hy[i] else valid = not slots.aa[i] end
	if not valid or range <= 0 then return "red" end
	if h.udist <= range * (1 - EDGE) then return "green" end
	if h.udist <= range * (1 + EDGE) then return "yellow" end
	return "red"
end
-- The firing cone of a weapon (a turret that cannot turn all the way round, e.g. the Mauser's artillery: +-90 degrees): maxAngleDif of the weapon is the cosine of the angle it may differ
-- from its main direction mainDir (in the frame of the unit: z = forward, x = right); -1 = no limit. The aim is the look direction (the camera). Returns whether the aim is outside the cone and on
-- which side the vehicle has to turn (1 = right, -1 = left).
local function outOfCone(u, ud, i)
	local wp = ud.weapons[i]
	local lim = wp and tonumber(wp.maxAngleDif) or -1
	if lim <= -0.999 then return false end
	local fv, uv, rv = Spring.GetUnitVectors(u) -- (three tables { x, y, z })
	local fx, fy, fz = fv and fv[1], fv and fv[2], fv and fv[3]
	local ux, uy, uz = uv and uv[1], uv and uv[2], uv and uv[3]
	local rx, ry, rz = rv and rv[1], rv and rv[2], rv and rv[3]
	local cam = Spring.GetCameraVectors()
	local a = cam and cam.forward
	if not (fx and ux and rx and a) then return false end
	local mx, my, mz = tonumber(wp.mainDirX) or 0, tonumber(wp.mainDirY) or 0, tonumber(wp.mainDirZ) or 1
	local dx, dy, dz = rx * mx + ux * my + fx * mz, ry * mx + uy * my + fy * mz, rz * mx + uz * my + fz * mz
	local dl = math.sqrt(dx * dx + dy * dy + dz * dz)
	local al = math.sqrt(a[1] * a[1] + a[2] * a[2] + a[3] * a[3])
	if dl < 0.01 or al < 0.01 then return false end
	local cosA = (dx * a[1] + dy * a[2] + dz * a[3]) / (dl * al)
	if cosA >= lim - 0.01 then return false end
	return true, ((a[1] * rx + a[2] * ry + a[3] * rz) >= 0) and 1 or -1
end
local REACH_COLOR = { green = { 0.25, 0.85, 0.3 }, yellow = { 0.95, 0.8, 0.15 }, red = { 0.9, 0.2, 0.15 } }

-- The pictures of the weapons: the gadget publishes "<weapon number>=<picture>,..." (renPics); a picture is the file LuaUI/Images/renegade/weapons/weapon_<picture>.png of the game
local picCache = {}
local function picName(u, i)
	local txt = Spring.GetUnitRulesParam(u, "renPics") or ""
	return txt:match("%f[%d]" .. i .. "=([%w%-_]+)")
end
local function weaponPicture(u, i)
	local name = picName(u, i)
	if not name then return nil end
	local path = "LuaUI/Images/renegade/weapons/weapon_" .. name .. ".png"
	if picCache[path] == nil then picCache[path] = VFS.FileExists(path) and path or false end
	return picCache[path] or nil
end

-- The name of a weapon on the panel: the name of its picture ("laser-light" = "Light Laser"); a weapon without a picture keeps its technical name
local SIZE_NAMES = { light = "Light", medium = "Medium", heavy = "Heavy", ultra = "Ultra" }
local NICE_NAMES = { ["d-gun"] = "D-Gun", ["emp-grenade"] = "EMP Grenade", ["aa-missile"] = "Anti-Air Missile", ["anti-nuke"] = "Anti-Nuke Missile", ["self-destruct"] = "Self-Destruct" }
local function niceName(pic)
	local base, size = pic:match("^(.-)%-(%a+)$")
	if size and SIZE_NAMES[size] then pic = base else size = nil end
	local n = NICE_NAMES[pic]
	if not n then
		n = pic:gsub("%-", " ")
		n = n:gsub("(%a)(%a*)", function(a, b) return a:upper() .. b end)
	end
	return size and (SIZE_NAMES[size] .. " " .. n) or n
end

-- damage of one shot (all the projectiles of a shot) and damage per second of a group (its weapons fire together; a salvo counts all its shots) against the default armor
-- (an anti-air weapon: against aircraft)
local function weaponStats(ud, slots, list, time)
	local i = list[1]
	local wd = WeaponDefs[ud.weapons[i].weaponDef]
	local armor = (Game.armorTypes or {}).default or 0
	local vtol = (Game.armorTypes or {}).vtol or 14
	local d = tonumber(wd.damages and wd.damages[armor]) or 0
	if slots.aa[i] then d = math.max(d, tonumber(wd.damages and wd.damages[vtol]) or 0) end
	local dmg = d * math.max(1, tonumber(wd.projectiles) or 1)
	local dps = dmg * math.max(1, tonumber(wd.salvoSize) or 1) * #list / math.max(0.1, time)
	return dmg, dps, math.max(1, tonumber(wd.salvoSize) or 1) / math.max(0.1, time)
end
local function num(v)
	if v >= 10000 then return string.format("%.0fk", v / 1000) end
	if v >= 1000 then return string.format("%.1fk", v / 1000) end
	return string.format("%d", math.floor(v + 0.5))
end

-- drawing helpers: a card with a vertical gradient and an edge, and the small symbols of the values (range: a target ring, reload: a clock, damage: a burst, dps: rising bars)
local function card(x1, y1, x2, y2, top, bot, edge, width)
	gl.BeginEnd(GL.QUADS, function()
		gl.Color(bot[1], bot[2], bot[3], bot[4]); gl.Vertex(x1, y1); gl.Vertex(x2, y1)
		gl.Color(top[1], top[2], top[3], top[4]); gl.Vertex(x2, y2); gl.Vertex(x1, y2)
	end)
	if edge then
		gl.Color(edge[1], edge[2], edge[3], edge[4])
		gl.LineWidth(width or 1.5)
		gl.BeginEnd(GL.LINE_LOOP, function()
			gl.Vertex(x1, y1); gl.Vertex(x2, y1); gl.Vertex(x2, y2); gl.Vertex(x1, y2)
		end)
		gl.LineWidth(1)
	end
end
local function ring(x, y, r)
	gl.BeginEnd(GL.LINE_LOOP, function()
		for a = 0, 17 do gl.Vertex(x + r * math.cos(a * math.pi / 9), y + r * math.sin(a * math.pi / 9)) end
	end)
end
local function disc(x, y, r)
	gl.BeginEnd(GL.TRIANGLE_FAN, function()
		gl.Vertex(x, y)
		for a = 0, 16 do gl.Vertex(x + r * math.cos(a * math.pi / 8), y + r * math.sin(a * math.pi / 8)) end
	end)
end
-- the symbols of kills (a crosshair) and deaths (a skull), as in the overview of Evolution
local function crosshair(x, y, r)
	gl.Color(1, 0.45, 0.35, 1)
	gl.LineWidth(2)
	ring(x, y, r * 0.7)
	gl.BeginEnd(GL.LINES, function()
		for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
			gl.Vertex(x + d[1] * r * 0.35, y + d[2] * r * 0.35); gl.Vertex(x + d[1] * r, y + d[2] * r)
		end
	end)
	gl.LineWidth(1)
end
local function skull(x, y, r)
	gl.Color(0.85, 0.85, 0.85, 1)
	disc(x, y + r * 0.15, r * 0.75)
	gl.Rect(x - r * 0.4, y - r * 0.8, x + r * 0.4, y - r * 0.2)
	gl.Color(0.1, 0.1, 0.12, 1)
	disc(x - r * 0.3, y + r * 0.1, r * 0.2)
	disc(x + r * 0.3, y + r * 0.1, r * 0.2)
end
-- the symbols of the values: range = a target ring, rate = a bullet with speed lines, damage = an explosion (a jagged star), dps = damage over time (a rising curve over its axes)
local function icon(kind, x, y, r, c)
	gl.Color(c[1], c[2], c[3], 1)
	gl.LineWidth(1.8)
	if kind == "range" then
		ring(x, y, r); ring(x, y, r * 0.3)
		gl.BeginEnd(GL.LINES, function()
			gl.Vertex(x - r * 1.3, y); gl.Vertex(x - r * 0.6, y); gl.Vertex(x + r * 0.6, y); gl.Vertex(x + r * 1.3, y)
			gl.Vertex(x, y - r * 1.3); gl.Vertex(x, y - r * 0.6); gl.Vertex(x, y + r * 0.6); gl.Vertex(x, y + r * 1.3)
		end)
	elseif kind == "rate" then
		gl.BeginEnd(GL.TRIANGLES, function() -- the bullet: a point at the right
			gl.Vertex(x + r * 1.2, y); gl.Vertex(x + r * 0.2, y + r * 0.55); gl.Vertex(x + r * 0.2, y - r * 0.55)
		end)
		gl.Rect(x - r * 0.5, y - r * 0.55, x + r * 0.25, y + r * 0.55)
		gl.BeginEnd(GL.LINES, function()
			gl.Vertex(x - r * 1.3, y + r * 0.55); gl.Vertex(x - r * 0.7, y + r * 0.55)
			gl.Vertex(x - r * 1.3, y - r * 0.55); gl.Vertex(x - r * 0.7, y - r * 0.55)
			gl.Vertex(x - r * 1.0, y); gl.Vertex(x - r * 0.7, y)
		end)
	elseif kind == "damage" then
		gl.BeginEnd(GL.TRIANGLE_FAN, function()
			gl.Vertex(x, y)
			for a = 0, 20 do
				local k = (a % 2 == 0) and 1.3 or 0.55
				gl.Vertex(x + math.cos(a * math.pi / 10) * r * k, y + math.sin(a * math.pi / 10) * r * k)
			end
		end)
	else
		gl.BeginEnd(GL.LINE_STRIP, function() -- the axes
			gl.Vertex(x - r, y + r); gl.Vertex(x - r, y - r); gl.Vertex(x + r * 1.2, y - r)
		end)
		gl.BeginEnd(GL.LINE_STRIP, function() -- the curve that rises faster and faster
			for a = 0, 8 do
				local u = a / 8
				gl.Vertex(x - r + u * r * 2.2, y - r + (u * u) * r * 2.1)
			end
		end)
		gl.BeginEnd(GL.TRIANGLES, function() -- the arrowhead at its end
			gl.Vertex(x + r * 1.2, y + r * 1.1); gl.Vertex(x + r * 0.5, y + r * 0.9); gl.Vertex(x + r * 1.1, y + r * 0.3)
		end)
	end
	gl.LineWidth(1)
end

local function panel(vsx, vsy)
	local u = R.unit
	local ud, slots = weaponsOf(u)
	if not ud then return end
	local drops = dropper(ud, slots)
	local frame = Spring.GetGameFrame()
	local s = math.max(0.7, vsy / 1080)
	local w, h = 432 * s, 80 * s
	local tagW = 54 * s -- (the column of the buttons at the right of the cards)
	local rows = {}
	R.states = {} -- (for the tests: the colour of every row)
	local allAtOnce = R.full -- FULL FIRE (Alt switches it): the left button fires every weapon
	for _, sl in ipairs(SLOTS) do
		local list = slots[sl[1]]
		if list and #list > 0 then
			local i = list[1]
			local wd = WeaponDefs[ud.weapons[i].weaponDef]
			if wd then
				local at = Spring.GetUnitWeaponState(u, i, "reloadFrame") or 0
				local time = Spring.GetUnitWeaponState(u, i, "reloadTime") or wd.reload or 1
				local ready = at <= frame or at >= 500000 -- (500000 and more: the gadget holds the reload of a weapon that only aims)
				local fill = ready and 1 or math.max(0, math.min(1, 1 - (at - frame) / math.max(1, time * 30)))
				local pn = picName(u, i)
				local name = (pn and niceName(pn)) or (wd.description and wd.description ~= "" and wd.description) or wd.name or "weapon"
				if #list > 1 then name = name .. "  x" .. #list end
				local state = (not drops) and reach(ud, slots, list, R.hit) or nil
				local cone, coneSide = outOfCone(u, ud, i)
				if cone and not slots.aa[i] then state = "red" else cone = false end
				local attack, height
				if wd.type == "AircraftBomb" then
					-- a bomber drops only up to its attack altitude: green up to it, yellow up to 15% above, red higher (nothing is dropped)
					attack = tonumber(Spring.GetUnitRulesParam(u, "renAttackAlt"))
					local ux, uy, uz = Spring.GetUnitPosition(u)
					if attack and ux then
						height = uy - Spring.GetGroundHeight(ux, uz)
						state = height <= attack and "green" or (height <= attack * 1.15 and "yellow" or "red")
					end
				end
				local dmg, dps, rate = weaponStats(ud, slots, list, time)
				rows[#rows + 1] = { name = name, range = slotRange(ud, list), fill = fill, ready = ready, time = time, tag = allAtOnce and "LMB" or sl[2], color = allAtOnce and SLOTS[1][4] or sl[4], aa = slots.aa[i], hy = slots.hy[i], state = state, attack = attack, height = height, pic = weaponPicture(u, i), dmg = dmg, dps = dps, rate = rate, cone = cone, coneSide = coneSide, ord = #rows + 1 }
			end
		end
	end
	table.sort(rows, function(a, b) -- the shortest range on top
		if a.range ~= b.range then return a.range < b.range end
		return a.ord < b.ord
	end)
	do
		-- the weapons that fire by themselves (anti-nuke launchers): a row with the tag AUTO, the player cannot fire them
		local seen = {}
		for n in (Spring.GetUnitRulesParam(u, "renAuto") or ""):gmatch("%d+") do
			local i = tonumber(n)
			local wd = ud.weapons[i] and WeaponDefs[ud.weapons[i].weaponDef]
			if wd and not seen[wd.id] then
				seen[wd.id] = true
				local pn = picName(u, i)
				local name = (pn and niceName(pn)) or (wd.description and wd.description ~= "" and wd.description) or wd.name or "weapon"
				rows[#rows + 1] = { name = name, range = tonumber(wd.range) or 0, fill = 1, ready = true, time = wd.reload or 1, tag = "AUTO", color = { 0.62, 0.64, 0.7 }, auto = true, pic = weaponPicture(u, i) }
			end
		end
	end
	for _, r in ipairs(rows) do if r.pic then w = 502 * s; break end end -- (with a picture the card of a row is 6 : 1)
	local hh = 40 * s -- the health row
	local x1, y1 = (vsx - w) / 2 + 140 * s, 18 * s -- right of the middle: the buttons of the game are at the bottom left of it
	local total = #rows * h + hh + 8 * s
	R.panel = { x1, y1, x1 + w, y1 + total }
	card(x1, y1, x1 + w, y1 + total, { 0.05, 0.06, 0.08, 0.7 }, { 0.02, 0.02, 0.03, 0.7 }, { 0.5, 0.55, 0.65, 0.5 }, 1.5)
	gl.Color(1, 0.3, 0.2, 1)
	gl.Text("Alt: FULL FIRE " .. (R.full and "ON" or "off"), x1 + w - 6 * s, y1 + total + 6 * s, 13 * s, "ro") -- (above the panel, right)
	gl.Color(0.7, 0.85, 1, 1)
	gl.Text("Shift: 3rd person " .. (R.third and "ON" or "off"), x1 + 6 * s, y1 + total + 6 * s, 13 * s, "o") -- (above the panel, left)
	-- a row: a card with the picture of the weapon over the whole width as the background, the cooldown like the one of the abilities of Evolution (a grey fill from the right
	-- that runs down, the seconds left), the colour of the range on top of the picture, a strip and the tag in the colour of the button, the name, and the values with their symbols
	for i, r in ipairs(rows) do
		local ry = y1 + 6 * s + (#rows - i) * h
		local cx1, cx2, cy1, cy2 = x1 + 4 * s, x1 + w - 4 * s - tagW, ry + 2 * s, ry + h - 2 * s
		R.states[i] = r.state or "-"
		card(cx1, cy1, cx2, cy2, { 0.16, 0.17, 0.21, 0.97 }, { 0.07, 0.07, 0.09, 0.97 })
		if r.pic then
			local ph = (cx2 - cx1) / 6
			local py = (cy1 + cy2) / 2 - ph / 2
			gl.Color(1, 1, 1, 0.92)
			gl.Texture(r.pic)
			gl.TexRect(cx1, py, cx2, py + ph)
			gl.Texture(false)
			-- a dark veil behind the text: strong at the left, gone at the right (the beam stays bright)
			gl.BeginEnd(GL.QUADS, function()
				gl.Color(0, 0, 0, 0.7); gl.Vertex(cx1, cy1); gl.Vertex(cx1, cy2)
				gl.Color(0, 0, 0, 0); gl.Vertex(cx1 + (cx2 - cx1) * 0.8, cy2); gl.Vertex(cx1 + (cx2 - cx1) * 0.8, cy1)
			end)
			-- and a darker strip behind the values (they must stay readable over the picture)
			gl.BeginEnd(GL.QUADS, function()
				gl.Color(0, 0, 0, 0.6); gl.Vertex(cx1, cy1); gl.Vertex(cx1, cy1 + 38 * s)
				gl.Color(0, 0, 0, 0.45); gl.Vertex(cx1 + (cx2 - cx1) * 0.95, cy1 + 38 * s); gl.Vertex(cx1 + (cx2 - cx1) * 0.95, cy1)
			end)
		end
		if r.state then
			-- the weapon reaches what the crosshair points at (green), is at its limit (yellow) or does not reach it / cannot hit it (red)
			local c = REACH_COLOR[r.state]
			gl.Color(c[1], c[2], c[3], 0.30)
			gl.Rect(cx1, cy1, cx2, cy2)
		end
		local left = 1 - r.fill -- the part of the reload that is left
		if not r.ready then
			gl.Color(0.22, 0.22, 0.25, 0.80)
			gl.Rect(cx2 - (cx2 - cx1) * left, cy1, cx2, cy2)
		end
		local rc = { 0.55, 0.62, 0.78 } -- (one neutral colour for every row: the colours of the buttons made the panel too colourful; the tint of the reach stays)
		card(cx1, cy1, cx2, cy2, { 0, 0, 0, 0 }, { 0, 0, 0, 0 }, { rc[1] * 0.8, rc[2] * 0.8, rc[3] * 0.8, 0.75 }, 1.5)
		gl.Color(rc[1], rc[2], rc[3], 1)
		gl.Rect(cx1, cy1, cx1 + 5 * s, cy2)
		local tx = cx1 + 14 * s
		-- the button (or AUTO) in a column at the right of the card, in its colour; an anti-air weapon says AIR ONLY under it
		local bx1, bx2 = cx2 + 4 * s, x1 + w - 4 * s
		card(bx1, cy1, bx2, cy2, { rc[1] * 0.9, rc[2] * 0.9, rc[3] * 0.9, 1 }, { rc[1] * 0.45, rc[2] * 0.45, rc[3] * 0.45, 1 }, { rc[1], rc[2], rc[3], 1 }, 1.5)
		gl.Color(1, 1, 1, 1)
		gl.Text(r.tag, (bx1 + bx2) / 2, (cy1 + cy2) / 2 - (r.aa and 0 or 8 * s), 16 * s, "co")
		if r.aa then
			gl.Color(1, 0.85, 0.4, 1) -- (anti-air only: fires only at an aircraft in the circle)
			gl.Text("AIR", (bx1 + bx2) / 2, (cy1 + cy2) / 2 - 18 * s, 11 * s, "co")
			gl.Text("ONLY", (bx1 + bx2) / 2, (cy1 + cy2) / 2 - 29 * s, 11 * s, "co")
		end
		local name = r.name
		local room = cx2 - tx - 8 * s
		while #name > 4 and gl.GetTextWidth(name) * 20 * s > room do name = name:sub(1, -2) end
		gl.Color(1, 1, 1, 1)
		gl.Text(name, tx, cy2 - 26 * s, 20 * s, "o")
		if r.cone then
			gl.Color(1, 0.3, 0.25, 1)
			gl.Text(r.coneSide > 0 and "TURN VEHICLE >>" or "<< TURN VEHICLE", cx2 - 8 * s, cy2 - 24 * s, 14 * s, "ro")
		end
		-- the values: symbol, a small label above the number; the damage per second in orange
		local cols = {}
		if r.auto then
			cols[#cols + 1] = { "range", "RANGE", r.range >= 20000 and "map" or num(r.range), false, 100 * s }
		elseif r.attack then
			cols[#cols + 1] = { "range", "DROPS BELOW", num(r.attack) .. " m", false, 104 * s }
			cols[#cols + 1] = { "range", "NOW", num(r.height or 0) .. " m", false, 80 * s }
		else
			cols[#cols + 1] = { "range", "RANGE", num(r.range) }
		end
		if r.auto then
			cols[#cols + 1] = { nil, "", "fires by itself" }
		else
			cols[#cols + 1] = { "rate", "SHOTS / S", r.rate >= 10 and string.format("%.0f", r.rate) or (r.rate >= 0.1 and string.format("%.1f", r.rate) or string.format("%.2f", r.rate)) }
			cols[#cols + 1] = { "damage", "DAMAGE", num(r.dmg) }
			cols[#cols + 1] = { "dps", "DPS", num(r.dps), true }
		end
		local colw = (#cols >= 5 and 76 or 98) * s
		local cx = tx
		for k, c in ipairs(cols) do
			local hot = c[4]
			local ic = hot and { 1, 0.7, 0.2 } or { 0.6, 0.75, 0.95 }
			if c[1] then icon(c[1], cx + 8 * s, cy1 + 21 * s, 7 * s, ic) end
			local vx = c[1] and cx + 22 * s or cx
			gl.Color(0.65, 0.7, 0.8, 1)
			gl.Text(c[2], vx, cy1 + 36 * s, 10 * s, "o")
			if hot then gl.Color(1, 0.72, 0.25, 1) else gl.Color(0.95, 0.97, 1, 1) end
			gl.Text(c[3], vx, cy1 + 11 * s, 17 * s, "o")
			cx = cx + (c[5] or colw)
		end
		if not r.ready then
			gl.Color(1, 1, 1, 1)
			gl.Text(string.format("%.1f s", left * r.time), cx2 - 8 * s, cy1 + 10 * s, 18 * s, "ro") -- (the seconds left count down here)
		end
	end
	-- health: a bar from red to green, the name of the unit in front of it and the numbers at the right
	local hp, mhp = Spring.GetUnitHealth(u)
	hp, mhp = hp or 0, math.max(1, mhp or 1)
	local frac = math.max(0, math.min(1, hp / mhp))
	local hy = y1 + 8 * s + #rows * h
	local bx1, bx2 = x1 + 8 * s, x1 + w - 8 * s
	card(bx1, hy + 4 * s, bx2, hy + 32 * s, { 0.2, 0.2, 0.22, 0.95 }, { 0.08, 0.08, 0.09, 0.95 }, { 0.5, 0.55, 0.65, 0.6 }, 1.5)
	if frac > 0 then
		local fx = bx1 + (bx2 - bx1) * frac
		local r0, g0 = 1 - frac, 0.25 + 0.65 * frac
		card(bx1, hy + 4 * s, fx, hy + 32 * s, { r0, g0, 0.25, 1 }, { r0 * 0.45, g0 * 0.45, 0.1, 1 })
	end
	gl.Color(1, 1, 1, 1)
	gl.Text(ud.translatedHumanName or ud.name or "?", bx1 + 8 * s, hy + 11 * s, 16 * s, "o")
	gl.Text(string.format("%d / %d", math.ceil(hp), math.floor(mhp)), bx2 - 8 * s, hy + 11 * s, 16 * s, "ro")
	gl.Color(1, 1, 1, 1)
	return x1, y1 + total, w, s
end

-- the debug buttons above the panel, side by side: "Unit" (you turn into a unit) and "Spawn" (an enemy 1000 Elmo ahead) open the unit menu, "Range" switches the range rings (green = on, red = off)
local function debugButton(x1, top, w, s)
	local bh = 28 * s
	local gap = 6 * s
	local bw = (w - 2 * gap) / 3
	local by = top + 26 * s
	R.btn = { x1, by, x1 + bw, by + bh }
	R.btn2 = { x1 + bw + gap, by, x1 + 2 * bw + gap, by + bh }
	R.btn3 = { x1 + 2 * (bw + gap), by, x1 + w, by + bh }
	local function button(r, label, on, c)
		c = c or { 0.35, 0.45, 0.65 }
		local k = on and 1 or 0.45
		card(r[1], r[2], r[3], r[4], { c[1] * k + 0.1, c[2] * k + 0.1, c[3] * k + 0.1, 0.95 }, { c[1] * k * 0.4, c[2] * k * 0.4, c[3] * k * 0.4, 0.95 }, { c[1], c[2], c[3], on and 1 or 0.6 }, 1.5)
		gl.Color(1, 1, 1, 1)
		gl.Text(label, (r[1] + r[3]) / 2, r[2] + 8 * s, 15 * s, "co")
	end
	button(R.btn, "Unit", R.list and R.pickMode ~= "enemy")
	button(R.btn2, "Spawn", R.list and R.pickMode == "enemy")
	button(R.btn3, "Range", R.rings, R.rings and { 0.25, 0.8, 0.3 } or { 0.85, 0.25, 0.2 })
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

-- The altimeter (always shown): a vertical scale at the right edge, fixed from 0 (the sea level) to 500 m above the sea level (ALT_MAX; everything plays inside it), a tick every 100 m. The ground is
-- the yellow part at the bottom (its top is the height of the ground under the unit), above it the height in the air (blue; orange when an aircraft is near the ground), a marker with the
-- height, the number on top (the height above the ground for an aircraft, the height of the ground for any other unit), GROUND and its height below.
local ALT_MAX = 500
local function altimeter(vsx, vsy)
	local u = R.unit
	local ud = UnitDefs[Spring.GetUnitDefID(u) or -1]
	if not ud then return end
	local x, y, z = Spring.GetUnitPosition(u, true)
	if not x then return end
	local flies = ud.canFly
	local ground = Spring.GetGroundHeight(x, z)
	local air = math.max(0, flies and (y - ground) or 0)
	local lo, top = 0, ALT_MAX -- (a fixed scale: 0 = the sea level to 500 m above it; what is higher or lower stays at the edge)
	local span = top - lo
	local step = 100
	local s = math.max(0.7, vsy / 1080)
	local bx, h = vsx - 70 * s, 320 * s
	local y0 = (vsy - h) / 2
	local function at(a) return y0 + h * math.max(0, math.min(1, (a - lo) / span)) end
	card(bx - 46 * s, y0 - 52 * s, bx + 48 * s, y0 + h + 32 * s, { 0.05, 0.06, 0.08, 0.7 }, { 0.02, 0.02, 0.03, 0.7 }, { 0.5, 0.55, 0.65, 0.5 }, 1.5)
	gl.Color(0.15, 0.15, 0.15, 0.9)
	gl.Rect(bx - 6 * s, y0, bx + 6 * s, y0 + h)
	gl.Color(0.85, 0.68, 0.2, 1) -- the ground (up to its height)
	gl.Rect(bx - 6 * s, y0, bx + 6 * s, at(ground))
	local low = flies and air < 40
	if low then gl.Color(1, 0.55, 0.15, 1) else gl.Color(0.45, 0.85, 1, 1) end
	if y > ground then gl.Rect(bx - 6 * s, at(ground), bx + 6 * s, at(y)) end -- the air between the ground and the unit
	gl.Color(0.8, 0.8, 0.8, 0.9)
	for a = math.ceil(lo / step) * step, top, step do
		gl.Rect(bx + 6 * s, at(a) - 1, bx + 16 * s, at(a) + 1)
		gl.Text(tostring(a), bx + 20 * s, at(a) - 5 * s, 11 * s, "o")
	end
	local my = at(y)
	if low then gl.Color(1, 0.55, 0.15, 1) else gl.Color(1, 1, 1, 1) end
	gl.BeginEnd(GL.TRIANGLES, function()
		gl.Vertex(bx - 7 * s, my); gl.Vertex(bx - 24 * s, my + 8 * s); gl.Vertex(bx - 24 * s, my - 8 * s)
	end)
	gl.Text(string.format("%d m", flies and air or math.max(0, y)), bx - 8 * s, y0 + h + 10 * s, 15 * s, "ro")
	gl.Color(1, 0.85, 0.3, 1)
	gl.Text(string.format("GROUND %d m", ground), bx - 8 * s, y0 - 16 * s, 12 * s, "ro")
	gl.Color(0.7, 0.7, 0.7, 0.95)
	if flies then
		gl.Text("Space up", bx - 36 * s, y0 - 30 * s, 10 * s, "o")
		gl.Text("Ctrl down", bx - 36 * s, y0 - 42 * s, 10 * s, "o")
	end
end

-- The players at the right (like the overview of Evolution): the colour of the team, the name, the unit and the kills (K) and deaths (D); the one with the most kills on top, a player
-- without a unit (waiting for the respawn) is dimmed. As many rows as fit above the altimeter, the rest is counted ("+N more"). Kills and deaths: team rules parameters renKills, renDeaths.
local function teamName(team)
	local _, leader, _, isAI = Spring.GetTeamInfo(team, false)
	if isAI then
		local _, n = Spring.GetAIInfo(team)
		if n and n ~= "" then return n end
	elseif leader then
		local n = Spring.GetPlayerInfo(leader, false)
		if n and n ~= "" then return n end
	end
	return "Team " .. team
end
local function scoreboard(vsx, vsy)
	local rows = {}
	local gaia = Spring.GetGaiaTeamID()
	for _, team in ipairs(Spring.GetTeamList()) do
		local uid = Spring.GetTeamRulesParam(team, "renUnit")
		if team ~= gaia and uid ~= nil then
			local ud = uid > 0 and UnitDefs[Spring.GetUnitDefID(uid) or -1] or nil
			rows[#rows + 1] = { team = team, name = teamName(team), unit = ud and (ud.translatedHumanName or ud.name) or "", alive = uid > 0, kills = Spring.GetTeamRulesParam(team, "renKills") or 0, deaths = Spring.GetTeamRulesParam(team, "renDeaths") or 0 }
		end
	end
	if #rows == 0 then return end
	table.sort(rows, function(a, b)
		if a.kills ~= b.kills then return a.kills > b.kills end
		if a.deaths ~= b.deaths then return a.deaths < b.deaths end
		return a.team < b.team
	end)
	local s = math.max(0.7, vsy / 1080)
	local w, rowH, head = 300 * s, 40 * s, 28 * s
	local x2 = vsx - 8 * s
	local x1 = x2 - w
	local top = vsy - 72 * s
	local altTop = (vsy - 320 * s) / 2 + 320 * s + 32 * s
	local maxRows = math.max(1, math.floor((top - head - 8 * s - (altTop + 10 * s)) / rowH))
	local shown = math.min(#rows, maxRows)
	local more = #rows - shown
	local y1 = top - head - shown * rowH - 6 * s - (more > 0 and 16 * s or 0)
	card(x1, y1, x2, top, { 0.05, 0.06, 0.08, 0.75 }, { 0.02, 0.02, 0.03, 0.75 }, { 0.5, 0.55, 0.65, 0.5 }, 1.5)
	gl.Color(0.7, 0.78, 0.9, 1)
	gl.Text("PLAYERS", x1 + 10 * s, top - 20 * s, 14 * s, "o")
	crosshair(x2 - 62 * s, top - 14 * s, 8 * s)
	skull(x2 - 22 * s, top - 14 * s, 8 * s)
	local me = Spring.GetMyTeamID()
	for i = 1, shown do
		local r = rows[i]
		local ry2 = top - head - (i - 1) * rowH
		local ry1 = ry2 - rowH + 3 * s
		local a = r.alive and 1 or 0.5
		if r.team == me then card(x1 + 3 * s, ry1, x2 - 3 * s, ry2 - 2 * s, { 0.25, 0.3, 0.4, 0.8 }, { 0.12, 0.15, 0.22, 0.8 }, { 0.6, 0.75, 1, 0.8 }, 1.5) end
		local cr, cg, cb = Spring.GetTeamColor(r.team)
		gl.Color(cr or 1, cg or 1, cb or 1, a)
		gl.Rect(x1 + 8 * s, ry1 + 3 * s, x1 + 15 * s, ry2 - 5 * s)
		local name = r.name
		while #name > 3 and gl.GetTextWidth(name) * 15 * s > 150 * s do name = name:sub(1, -2) end
		gl.Color(1, 1, 1, a)
		gl.Text(name, x1 + 22 * s, ry2 - 18 * s, 15 * s, "o")
		gl.Color(0.65, 0.7, 0.8, a)
		local unit = r.alive and r.unit or "respawning"
		while #unit > 3 and gl.GetTextWidth(unit) * 11 * s > 150 * s do unit = unit:sub(1, -2) end
		gl.Text(unit, x1 + 22 * s, ry1 + 5 * s, 11 * s, "o")
		gl.Color(1, 0.8, 0.3, a)
		gl.Text(tostring(r.kills), x2 - 62 * s, ry1 + 10 * s, 17 * s, "co")
		gl.Color(0.9, 0.5, 0.45, a)
		gl.Text(tostring(r.deaths), x2 - 22 * s, ry1 + 10 * s, 17 * s, "co")
	end
	if more > 0 then
		gl.Color(0.7, 0.78, 0.9, 1)
		gl.Text("+" .. more .. " more", x2 - 10 * s, y1 + 4 * s, 12 * s, "ro")
	end
	gl.Color(1, 1, 1, 1)
end

-- The compass at the bottom right, between the panel of the weapons and the music player: a round dial; the green arrow is the way the vehicle drives (where W takes it), the coloured arrowheads at the
-- rim are the barrels of the groups of weapons (the colour of their buttons; the turrets turn slower than you look round). Up = the way you look: an arrow that points up means the
-- vehicle drives where you look. (It replaces the two arrows on the ground.)
local function compass(vsx, vsy)
	local u = R.unit
	local ud, slots = weaponsOf(u)
	local cam = Spring.GetCameraVectors()
	if not (ud and cam and cam.forward and cam.right) then return end
	local fw, rt = cam.forward, cam.right
	local fl = math.sqrt(fw[1] * fw[1] + fw[3] * fw[3])
	local rl = math.sqrt(rt[1] * rt[1] + rt[3] * rt[3])
	if fl < 0.01 or rl < 0.01 then return end
	-- a world direction on the dial: x to the right, y up (the way you look)
	local function onDial(dx, dz)
		local l = math.sqrt(dx * dx + dz * dz)
		if l < 0.01 then return nil end
		dx, dz = dx / l, dz / l
		return (dx * rt[1] + dz * rt[3]) / rl, (dx * fw[1] + dz * fw[3]) / fl
	end
	local s = math.max(0.7, vsy / 1080)
	local r = 62 * s
    -- at the bottom, between the panel of the weapons and the music player of the game (about 190 wide at the right edge): not in the way there
    local left = (R.panel and R.panel[3] or (vsx * 0.7)) + 14 * s
    local cx, cy = (left + vsx - 190 * s) / 2, 18 * s + r + 8 * s
	gl.Color(0, 0, 0, 0.45)
	disc(cx, cy, r)
	gl.Color(0.6, 0.7, 0.85, 0.9)
	gl.LineWidth(2)
	ring(cx, cy, r)
	gl.LineWidth(1)
	gl.BeginEnd(GL.LINES, function() -- the ticks: front, right, back, left
		gl.Vertex(cx, cy + r); gl.Vertex(cx, cy + r * 0.82)
		gl.Vertex(cx + r, cy); gl.Vertex(cx + r * 0.88, cy)
		gl.Vertex(cx, cy - r); gl.Vertex(cx, cy - r * 0.88)
		gl.Vertex(cx - r, cy); gl.Vertex(cx - r * 0.88, cy)
	end)
	-- the barrels (a weapon that is not aiming reports straight up: then the facing of the unit counts)
	local ffx, _, ffz = Spring.GetUnitDirection(u)
	for _, sl in ipairs(SLOTS) do
		local list = slots[sl[1]]
		if list and #list > 0 then
			local _, _, _, wx, _, wz = Spring.GetUnitWeaponVectors(u, list[1])
			if not wx or wx * wx + wz * wz < 0.04 then wx, wz = ffx or 0, ffz or 1 end
			local sx, sy = onDial(wx, wz)
			if sx then
				local px, py = -sy, sx -- (across)
				local tip, base, w = r * 1.0, r * 0.6, r * 0.22
				gl.Color(sl[4][1], sl[4][2], sl[4][3], 1)
				gl.BeginEnd(GL.TRIANGLES, function()
					gl.Vertex(cx + sx * tip, cy + sy * tip)
					gl.Vertex(cx + sx * base + px * w, cy + sy * base + py * w)
					gl.Vertex(cx + sx * base - px * w, cy + sy * base - py * w)
				end)
			end
		end
	end
	-- the way the vehicle drives: a turret does not drive, its arrow shows where its first weapon points
	local fx, fz = ffx, ffz
	if not ud.canMove then
		for _, sl in ipairs(SLOTS) do
			local l1 = slots[sl[1]]
			if l1 and l1[1] then
				local _, _, _, wx, _, wz = Spring.GetUnitWeaponVectors(u, l1[1])
				if wx and wx * wx + wz * wz > 0.04 then fx, fz = wx, wz end
				break
			end
		end
	end
	local ax, ay = onDial(fx or 0, fz or 1)
	if ax then
		local px, py = -ay, ax
		local len, hw = r * 0.72, r * 0.2
		gl.Color(0, 0, 0, 0.7)
		gl.LineWidth(9)
		gl.BeginEnd(GL.LINES, function() gl.Vertex(cx, cy); gl.Vertex(cx + ax * len * 0.6, cy + ay * len * 0.6) end)
		gl.Color(0.2, 1, 0.3, 1)
		gl.LineWidth(5)
		gl.BeginEnd(GL.LINES, function() gl.Vertex(cx, cy); gl.Vertex(cx + ax * len * 0.6, cy + ay * len * 0.6) end)
		gl.BeginEnd(GL.TRIANGLES, function()
			gl.Vertex(cx + ax * len, cy + ay * len)
			gl.Vertex(cx + ax * len * 0.55 + px * hw, cy + ay * len * 0.55 + py * hw)
			gl.Vertex(cx + ax * len * 0.55 - px * hw, cy + ay * len * 0.55 - py * hw)
		end)
		gl.LineWidth(1)
	end
	gl.Color(1, 1, 1, 1)
end

function widget:DrawScreen()
	local vsx0, vsy0 = Spring.GetViewGeometry()
	if not Spring.GetSpectatingState() then countdown(vsx0, vsy0) end
	if not R.on then return end
	local vsx, vsy = Spring.GetViewGeometry()
	local cx, cy, s = vsx / 2, vsy / 2, math.max(8, vsy / 90)
	-- what the crosshair points at and whether the main weapon reaches it: green = within reach, red = too far, white = the sky
	local h = R.hit
	local text
	-- (an aircraft has no range display: it moves too fast for it, a bomber has the impact preview; the crosshair stays green)
	-- the colour: green as soon as one weapon that is valid for the target reaches it, yellow when the best is at its limit, red when none reaches it (the panel shows which)
	local dropped, best = false, nil
	do
		local ud0, sl0 = weaponsOf(R.unit)
		if ud0 then
			dropped = dropper(ud0, sl0)
			if h and not dropped then
				for _, sl in ipairs(SLOTS) do
					local list = sl0[sl[1]]
					local st = list and #list > 0 and reach(ud0, sl0, list, h) or nil
					if st == "green" or (st == "yellow" and best ~= "green") or (st == "red" and not best) then best = st end
				end
			end
		end
	end
	-- a turret that cannot turn all the way round: when no weapon can point where you look, the vehicle has to turn (the crosshair says so and on which side)
	local coneAll, coneSide = false, 0
	do
		local ud0, sl0 = weaponsOf(R.unit)
		if ud0 then
			local n, out = 0, 0
			for _, sl in ipairs(SLOTS) do
				local list = sl0[sl[1]]
				if list and #list > 0 and not sl0.aa[list[1]] then
					n = n + 1
					local o, sd = outOfCone(R.unit, ud0, list[1])
					if o then out = out + 1; coneSide = sd end
				end
			end
			coneAll = n > 0 and out == n
		end
	end
	R.coneOut = coneAll -- (for the tests)
	R.best = best -- (for the tests)
	local inReach = h and (dropped or best == "green")
	if not h then
		text = "sky"
	elseif h.kind == "unit" then
		local d = UnitDefs[Spring.GetUnitDefID(h.unit) or -1]
		local hp, mhp = Spring.GetUnitHealth(h.unit)
		text = string.format("%s%s  %d%%  %d m", d and (d.translatedHumanName or d.name) or "unit", Spring.IsUnitAllied(h.unit) and " (ally)" or "", hp and mhp and math.floor(100 * hp / mhp) or 0, math.floor(h.udist))
	else
		text = string.format("ground  %d m", math.floor(h.udist))
	end
	-- a gunship with fixed guns: an aim point steeper below it than the guns can turn is moved out to the edge of the dead zone (correctShot)
	local steep = R.corrected ~= nil
	if coneAll then text = (coneSide > 0 and "TURN THE VEHICLE >>  " or "<<  TURN THE VEHICLE  ") .. "(outside of the turret angle)" end
	if steep then text = text .. string.format("  STEEP: the shot lands %d m out (guns reach %d deg down)", math.floor(R.corrected.d), MAX_DOWN) end
	local r, g, b = 1, 1, 1
	if h then
		if steep then r, g, b = 1, 0.75, 0.2
		elseif inReach then r, g, b = 0.35, 1, 0.4
		elseif best == "yellow" then r, g, b = 1, 0.9, 0.2
		else r, g, b = 1, 0.3, 0.25 end
	end
	if coneAll then r, g, b = 1, 0.25, 0.2 end
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
		local function ring(radius)
			gl.BeginEnd(GL.LINE_LOOP, function()
				for a = 0, 63 do
					gl.Vertex(cx + radius * math.cos(a * math.pi / 32), cy + radius * math.sin(a * math.pi / 32))
				end
			end)
		end
		if R.aaTarget then
			-- an aircraft is locked: the circle glows (bright, thick, with a soft halo that pulses): fire now
			local k = 0.75 + 0.25 * math.sin(os.clock() * 9)
			for i, w in ipairs({ 14, 9, 5 }) do
				gl.Color(1, 0.65, 0.1, 0.10 * k * i)
				gl.LineWidth(w)
				ring(R.aaCircle)
			end
			gl.Color(1, 0.95, 0.45, 1)
			gl.LineWidth(3.5)
			ring(R.aaCircle)
		else
			gl.Color(1, 0.6, 0.1, 0.9)
			gl.LineWidth(2.5)
			ring(R.aaCircle)
		end
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
	altimeter(vsx, vsy)
	scoreboard(vsx, vsy)
	compass(vsx, vsy)
	local x1, top, w, ps = panel(vsx, vsy)
	if R.debug and x1 then
		debugButton(x1, top, w, ps)
		if R.menu and R.list then drawPicker() else R.win = nil end
	end
end
