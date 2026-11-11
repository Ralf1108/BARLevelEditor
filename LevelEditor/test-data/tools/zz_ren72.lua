function widget:GetInfo() return { name = "zz ren72", desc = "test only: the information line of the unit menu", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren72.lua: opens the unit menu (the debug button Unit), the group Bots, Armada; the first and a later unit are "hovered" (R.testHover); pictures.
local function log(...) Spring.Echo("[zzren72] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 80 then R.menu = true; R.list = true; R.pickMode = "self" end
	if f == 100 then R.testHover = 1 end
	if f == 110 then Spring.SendCommands("screenshot png") end
	if f == 120 then R.testHover = 9 end
	if f == 130 then Spring.SendCommands("screenshot png") end
	if f == 140 then R.testHover = nil end
	if f == 150 then Spring.SendCommands("screenshot png") end
	if f == 160 then Spring.SendCommands("quitforce") end
end
