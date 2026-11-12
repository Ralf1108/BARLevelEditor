function widget:GetInfo() return { name = "zz ren83", desc = "test only: the panel sits above the info panel of the game", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren: shows the info panel of the game (a unit displayed) and takes a picture (lines "[zzren83]").
function widget:GameFrame(f)
	if f == 60 then
		local u = Spring.GetTeamUnits(Spring.GetMyTeamID())[1]
		local i = WG["info"]
		if i and u then pcall(i.setCustomHover, u) pcall(i.displayUnitID, u) end
		local a, b = i.getPosition()
		Spring.Echo("[zzren83] getPosition " .. tostring(a) .. " " .. tostring(b) .. " panel " .. tostring(WG.renegade and WG.renegade.panel and WG.renegade.panel[2]))
	end
	if f == 90 then Spring.SendCommands("screenshot png") end
	if f == 130 then Spring.SendCommands("quitforce") end
end
