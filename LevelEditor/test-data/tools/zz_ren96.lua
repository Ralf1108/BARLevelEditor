function widget:GetInfo() return { name = "zz ren96", desc = "test only: the hints for beginners of Renegade (mode_ui.lua)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenPowerups -RenGoal 20 -Widget zz_ren96.lua: the hints come one after the other (each 7 s, real time): the list of the ids asked
-- for (M.hintLog) at frames 300, 900 and 1500, a hurt unit (ren|test|6) and the power-ups (ren|test|7) bring theirs; the config counter LedHint_ren_move is 1 (shown in one game).
-- Lines "[zzren96]", a picture with the box TIP at frame 200.
local function log(...) Spring.Echo("[zzren96] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	local R = WG.renegade
	if not R or not R.M then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 200 then Spring.SendCommands("screenshot png") end
	if f == 300 then log("frame 300 hints:", table.concat(R.M.hintLog, " ")) end
	if f == 400 then Spring.SendLuaRulesMsg("ren|test|6"); Spring.SendLuaRulesMsg("ren|test|7") end
	if f == 900 then log("frame 900 hints:", table.concat(R.M.hintLog, " ")) end
	if f == 1500 then
		log("frame 1500 hints:", table.concat(R.M.hintLog, " "), "config LedHint_ren_move", tostring(Spring.GetConfigInt("LedHint_ren_move", 0)))
		Spring.SendCommands("quitforce")
	end
end
