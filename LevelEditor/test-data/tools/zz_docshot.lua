function widget:GetInfo() return { name = "zz docshot", desc = "test only: pictures of Evolution for the manual", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Shot <mode> -Widget zz_docshot.lua (one instance, -Bots n computer players): takes one picture with the engine
-- (<Work>\data\screenshots) and ends the game. The mode is the game option lanevoshot:
--   help        the help window of the start of the game (picture at frame 600)
--   game        speed 20 until frame 3000, then random levels, power-ups, experience, kills and deaths for everybody (evo|test|5, the star button of the debug mode); speed 1, the picture
--   armageddon  random values (evo|test|5), then Armageddon at once (evo|test|4) and the window of the gifts (picture 150 frames later)
-- The camera is pointed at the own unit. Lines "[zzdoc]".
local mode = (Spring.GetModOptions() or {}).lanevoshot or "game"
local function log(...) Spring.Echo("[zzdoc] " .. table.concat({ ... }, " ")) end
local function look()
	local id = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoUnit")
	local x, y, z = Spring.GetUnitPosition(id or -1)
	if x then Spring.SetCameraTarget(x, y, z, 0); Spring.SelectUnitArray({ id }) end
end
local shot, quit = 600, 700
if mode == "game" then shot, quit = 3300, 3400 elseif mode == "armageddon" then shot, quit = 750, 800 end
function widget:GameFrame(f)
	if f == 5 and mode == "game" then Spring.SendCommands("setmaxspeed 20", "setminspeed 20") end
	if f == 3000 and mode == "game" then Spring.SendLuaRulesMsg("evo|test|5") end
	if f == 3050 and mode == "game" then Spring.SendCommands("setmaxspeed 1", "setminspeed 1") end
	if f == 400 and mode == "armageddon" then Spring.SendLuaRulesMsg("evo|test|5") end
	if f == 600 and mode == "armageddon" then Spring.SendLuaRulesMsg("evo|test|4") end
	if f > 30 and f % 30 == 0 and f < shot then look() end
	if f == shot then Spring.SendCommands("screenshot png"); log("picture taken", mode, "frame", f) end
	if f == quit then Spring.SendCommands("quitforce") end
end
