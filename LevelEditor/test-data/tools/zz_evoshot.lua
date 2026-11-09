function widget:GetInfo() return { name = "zz evoshot", desc = "test only: a picture of the Evolution panels", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -Widget zz_evoshot.lua: points the camera at the own unit, takes a picture with the engine (screenshot png, in the
-- folder screenshots of the write dir) at frame 900 and ends the game. Logs "[zzevoshot]" lines.
local function log(...) Spring.Echo("[zzevoshot] " .. table.concat({ ... }, " ")) end

function widget:GameFrame(f)
	if f == 100 then Spring.SendLuaRulesMsg("evo|test|1") end -- (only with -EvoTest: all abilities, to see the buttons)
	if f == 600 or f == 870 then
		local id = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoUnit")
		local x, y, z = Spring.GetUnitPosition(id or -1)
		if x then
			Spring.SetCameraTarget(x, y, z, 0)
			Spring.SelectUnitArray({ id })
		end
		log("frame", f, "own unit", tostring(id), "level", tostring(Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoStage")))
	end
	if f == 900 then
		Spring.SendCommands("screenshot png")
		log("picture taken")
	end
	if f == 960 then
		Spring.SendCommands("quitforce")
	end
end
