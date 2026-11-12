function widget:GetInfo() return { name = "zz ren82", desc = "test only: the game's unit bars are off in Renegade", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren: logs whether the widget "Health Bars GL4" is active (lines "[zzren82]").
local function state(tag)
	local on = false
	for _, f in pairs(widgetHandler:GetActiveWidgetFiles()) do
		if tostring(f):find("gui_healthbars_gl4", 1, true) then on = true end
	end
	Spring.Echo("[zzren82] " .. tag .. " R.on " .. tostring(WG.renegade and WG.renegade.on) .. " bars active " .. tostring(on))
end
function widget:GameFrame(f)
	if f == 20 then state("early") end
	if f == 120 then state("in the unit") end
	if f == 180 then Spring.SendCommands("quitforce") end
end
