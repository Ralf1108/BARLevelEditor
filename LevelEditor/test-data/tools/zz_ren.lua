function widget:GetInfo() return { name = "zz ren", desc = "test only: Renegade proof of concept 1 and 2", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -Widget zz_ren.lua. Steers renegade.lua through WG.renegade (no real mouse or keys) and logs "[zzren]" lines:
-- the camera state against the wanted eye and direction, the unit's way with W / A, a mouse warp, the camera modes fps / free / ta; pictures at some steps.
local function log(...) Spring.Echo("[zzren] " .. table.concat({ ... }, " ")) end
local function fmt(...) local t = {} for _, v in ipairs({ ... }) do t[#t + 1] = type(v) == "number" and string.format("%.2f", v) or tostring(v) end return table.concat(t, " ") end

local R
local pos0
local step = {}

local function cam(tag)
	local st = Spring.GetCameraState()
	local px, py, pz = Spring.GetCameraPosition()
	local dx, dy, dz = Spring.GetCameraDirection()
	local u = R.unit
	local ex, ey, ez = Spring.GetUnitViewPosition(u)
	local y, p = math.rad(R.yaw), math.rad(R.pitch)
	log(tag, "wanted dir", fmt(math.sin(y) * math.cos(p), math.sin(p), math.cos(y) * math.cos(p)))
	log(tag, "state", st.name, "pos", fmt(px, py, pz), "dir", fmt(dx, dy, dz), "unit", fmt(ex, ey, ez), "unit height", fmt(Spring.GetUnitHeight(u)))
end

function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then
		if f == 60 then log("no WG.renegade") Spring.SendCommands("quitforce") end
		return
	end
	if f == 120 then
		log("unit", tostring(R.unit), "on", tostring(R.on), "hidden", tostring(R.hidden))
		R.fake = true
		R.yaw, R.pitch = 0, 0
	end
	if f == 150 then cam("fps yaw0 pitch0"); Spring.SendCommands("screenshot png") end
	if f == 160 then R.yaw, R.pitch = 90, 20 end
	if f == 190 then cam("fps yaw90 pitch20"); Spring.SendCommands("screenshot png") end
	-- movement: W with yaw 0 should go +z
	if f == 200 then R.yaw, R.pitch = 0, 0; pos0 = { Spring.GetUnitPosition(R.unit) }; R.keys = 1 end
	if f == 330 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("W yaw0: moved", fmt(x - pos0[1], z - pos0[3]), "(x, z; expected z>0)")
		R.keys = 0
	end
	if f == 360 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local vx, vy, vz = Spring.GetUnitVelocity(R.unit)
		log("stopped: speed", fmt(vx, vz))
		R.yaw = 90; pos0 = { x, y, z }; R.keys = 2 -- A with yaw 90 (looking east): left = north = -z
	end
	if f == 480 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("A yaw90: moved", fmt(x - pos0[1], z - pos0[3]), "(expected z<0)")
		R.keys = 0
		R.yaw = 270; pos0 = { x, y, z }; R.keys = 4 -- S with yaw 270 (looking west): back = east = +x
	end
	if f == 600 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("S yaw270: moved", fmt(x - pos0[1], z - pos0[3]), "(expected x>0)")
		R.keys = 0
	end
	if f == 620 then
		-- the mouse: warp the cursor away; renegade.lua (not fake) would turn by the way it moved
		R.fake = false
		R.yaw, R.pitch = 0, 0
		local vsx, vsy = Spring.GetViewGeometry()
		Spring.WarpMouse(vsx / 2 + 100, vsy / 2 + 50)
		log("warped to", fmt(vsx / 2 + 100, vsy / 2 + 50), "got", fmt(Spring.GetMouseState()))
	end
	if f == 630 then
		local vsx, vsy = Spring.GetViewGeometry()
		log("after one frame: yaw", fmt(R.yaw), "pitch", fmt(R.pitch), "(expected yaw ~", fmt((360 - 100 * 0.15) % 360), "pitch ~", fmt(50 * 0.15), ") mouse", fmt(Spring.GetMouseState()), "middle", fmt(vsx / 2, vsy / 2))
		R.fake = true
		R.yaw, R.pitch = 45, -10
	end
	if f == 640 then R.yaw, R.pitch = 45, -10 end
	if f == 660 then cam("fps yaw45 pitch-10"); Spring.SendCommands("screenshot png") end
	if f == 670 then R.yaw, R.pitch = 0, 0; pos0 = { Spring.GetUnitPosition(R.unit) }; R.keys = 1 end
	if f == 790 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("W yaw0 (second try): moved", fmt(x - pos0[1], z - pos0[3]), "(expected z>0)")
		R.keys = 0
	end
	if f == 800 then Spring.SendCommands("quitforce") end
end
