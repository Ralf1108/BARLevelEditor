function widget:GetInfo() return { name = "zz evocam", desc = "test only: the camera at the start of Evolution", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -Widget zz_evocam.lua: puts the camera into the first person type before the game starts (like a setting left over from Renegade), then logs the camera
-- at frames 20 and 60 and takes a picture at 70 (lines "[zzevocam]").
local set = false
local function log() local cs = Spring.GetCameraState() Spring.Echo("[zzevocam] frame " .. Spring.GetGameFrame() .. " camera " .. tostring(cs.name) .. " mode " .. tostring(cs.mode) .. " pos " .. tostring(cs.px) .. " " .. tostring(cs.py) .. " " .. tostring(cs.pz) .. " dist " .. tostring(cs.dist)) end
function widget:Update()
	if not set and Spring.GetGameFrame() == 0 then
		set = true
		Spring.SetCameraState({ name = "fps", mode = 0, px = 300, py = 200, pz = 300, rx = 1.5, ry = 0, rz = 0 }, 0)
		log()
	end
end
function widget:GameFrame(f)
	if f == 20 or f == 60 then log() end
	if f == 70 then Spring.SendCommands("screenshot png") end
	if f == 100 then Spring.SendCommands("quitforce") end
end
