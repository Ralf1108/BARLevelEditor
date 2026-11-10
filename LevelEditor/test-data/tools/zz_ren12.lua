function widget:GetInfo() return { name = "zz ren12", desc = "test only: Renegade spawn enemy button", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren12.lua: opens the unit menu in the mode "Spawn enemy" (picture), spawns a Pawn and a Brawler through the message the menu
-- sends (the gadget logs "[Renegade] spawned ..." with the distance and the height), looks for them. Lines "[zzren12]".
local function log(...) Spring.Echo("[zzren12] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, 0; R.menu, R.list, R.pickMode = true, true, "enemy" end
	if f == 120 then Spring.SendCommands("screenshot png") end
	if f == 130 then Spring.SendLuaRulesMsg("ren|spawn|armpw"); Spring.SendLuaRulesMsg("ren|spawn|armbrawl"); Spring.SendLuaRulesMsg("ren|spawn|armllt") end
	if f == 150 then R.menu, R.list = false, false end
	if f == 400 then Spring.SendCommands("quitforce") end
end
