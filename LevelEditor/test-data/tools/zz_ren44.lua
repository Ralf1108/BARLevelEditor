function widget:GetInfo() return { name = "zz ren44", desc = "test only: weapon pictures of the Pulsar and the Juggernaut", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren44.lua: the player becomes a Pulsar (armanni), a picture is taken; then a Juggernaut (corkorg), a picture is taken. Lines "[zzren44]".
local function log(...) Spring.Echo("[zzren44] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armanni") end
	if f == 180 and R.unit then log("pulsar", tostring(Spring.GetUnitRulesParam(R.unit, "renPics"))); Spring.SendCommands("screenshot png") end
	if f == 200 then Spring.SendLuaRulesMsg("ren|unit|corkorg") end
	if f == 280 and R.unit then log("juggernaut", tostring(Spring.GetUnitRulesParam(R.unit, "renPics"))); Spring.SendCommands("screenshot png") end
	if f == 300 then Spring.SendCommands("quitforce") end
end
