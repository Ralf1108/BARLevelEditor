function widget:GetInfo() return { name = "zz ren63", desc = "test only: switch between Renegade and the normal game", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren63.lua: a Behemoth; the text command "renegade" (the same as the key next to Shift) switches to the normal game and back; "[zzren63]" logs R.on,
-- the camera name, the fire state of the unit (0 = hold fire in Renegade, 2 = fire at will in the normal game) and the team rule renNormal; pictures of both modes.
local function log(...) Spring.Echo("[zzren63] " .. table.concat({ ... }, " ")) end
local function state(tag)
	local R = WG.renegade
	local cs = Spring.GetCameraState()
	local st = R.unit and Spring.GetUnitStates(R.unit)
	log(tag, "on", tostring(R.on), "off", tostring(R.off), "camera", tostring(cs and cs.name), "firestate", tostring(st and st.firestate), "renNormal", tostring((Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renNormal"))))
end
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|corjugg") end
	if f == 120 then state("Renegade") end
	if f == 130 then Spring.SendCommands("renegade") end
	if f == 170 then state("normal game"); Spring.SendCommands("screenshot png") end
	if f == 180 then Spring.SendCommands("renegade") end
	if f == 230 then state("Renegade again"); Spring.SendCommands("screenshot png") end
	if f == 240 then Spring.SendCommands("quitforce") end
end
