function widget:GetInfo() return { name = "zz camreset", desc = "test only: a game without Renegade starts with the normal camera", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_camreset.lua: the camera a Renegade game left (the first person view "fps", config CamMode 0) is set in
-- Initialize (after the first start setup of BAR in a fresh sandbox, which sets CamMode 3 itself). In a game without Renegade the gadget
-- renegade_game.lua sets the normal camera of BAR at its first Update. Checks after one second: the camera is not "fps" and the config CamMode is 3;
-- a picture. Logs "[zzcam]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzcam] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local first
function widget:Initialize()
	Spring.SetConfigInt("CamMode", 0)
	Spring.SendCommands("viewfps")
	log("Initialize: CamMode 0 and the camera fps set, camera now", Spring.GetCameraState().name)
end
function widget:Update()
	if not first then
		first = true
		log("first Update of the widget: camera", Spring.GetCameraState().name, "CamMode", Spring.GetConfigInt("CamMode", -1))
	end
end
function widget:GameFrame(f)
	if f == 30 then
		local cs = Spring.GetCameraState()
		local mode = Spring.GetConfigInt("CamMode", -1)
		log("after one second: camera", cs.name, ok(cs.name ~= "fps"), "CamMode", mode, ok(mode == 3))
		Spring.SendCommands("screenshot png")
	elseif f == 60 then
		log("done"); Spring.SendCommands("quitforce")
	end
end
