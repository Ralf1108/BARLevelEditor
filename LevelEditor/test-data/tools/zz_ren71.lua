function widget:GetInfo() return { name = "zz ren71", desc = "test only: the binoculars and the speedometer", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren71.lua: a Sharpshooter (armsnipe, range 900: 3 zoom levels): the middle button switches the binoculars on, the wheel zooms, the field of view of the camera
-- and the zoom level are logged ("[zzren71]"), pictures at level 1 and 3; then a Behemoth (a weapon on the middle button): the middle button does not switch them on.
local function log(...) Spring.Echo("[zzren71] " .. table.concat({ ... }, " ")) end
local function fov() local cs = Spring.GetCameraState(); return cs and cs.fov and string.format("%.1f", cs.fov) or "nil" end
function widget:GameFrame(f)
	local R = WG.renegade
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 90, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|armsnipe") end
	if f == 110 then log("start: zoom", tostring(R.zoom), "fov", fov(), "baseFov", tostring(R.baseFov)) end
	if f == 115 then R.zoomStep(true) end -- the wheel forward: on -- the middle button
	if f == 125 then log("after the middle button: zoom", tostring(R.zoom), "fov", fov()); Spring.SendCommands("screenshot png") end
	if f == 130 then R.zoomStep(true) end
	if f == 131 then R.zoomStep(true) end
	if f == 132 then R.zoomStep(true) end
	if f == 145 then log("after 3 wheel steps up: zoom", tostring(R.zoom), "fov", fov()); Spring.SendCommands("screenshot png") end
	if f == 150 then R.zoomStep(false) end
	if f == 160 then log("one step down: zoom", tostring(R.zoom), "fov", fov()) end
	if f == 165 then R.zoomStep(false); R.zoomStep(false) end -- two steps back from level 2: level 1, then off
	if f == 175 then log("middle button again: zoom", tostring(R.zoom), "fov", fov()) end
	if f == 180 then Spring.SendLuaRulesMsg("ren|unit|corjugg") end
	if f == 230 then R.toggleZoom() end
	if f == 240 then log("Behemoth, middle button (has a weapon on it): zoom", tostring(R.zoom), "fov", fov(), "fire bits", tostring(R.fire)) end
	if f == 250 then Spring.SendCommands("quitforce") end
end
