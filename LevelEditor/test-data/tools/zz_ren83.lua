function widget:GetInfo() return { name = "zz ren83", desc = "test only: layout of the panels, the unit bars widget comes back", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren: takes a picture with the info panel of the game shown and logs whether "Health Bars GL4" is active again (lines "[zzren83]").
local function bars()
	for _, f in pairs(widgetHandler:GetActiveWidgetFiles()) do
		if tostring(f):find("gui_healthbars_gl4", 1, true) then return true end
	end
	return false
end
function widget:GameFrame(f)
	if f == 60 then
		local u = Spring.GetTeamUnits(Spring.GetMyTeamID())[1]
		local i = WG["info"]
		if i and u then pcall(i.setCustomHover, u) pcall(i.displayUnitID, u) end
	end
	if f == 70 or f == 75 or f == 110 then Spring.Echo("[zzren83] frame " .. f .. " bars active " .. tostring(bars())) end
	if f == 100 then Spring.SendCommands("screenshot png") end
	if f == 140 then Spring.SendCommands("quitforce") end
end
