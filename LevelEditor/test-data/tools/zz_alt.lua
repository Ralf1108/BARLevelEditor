function widget:GetInfo() return { name = "zz alt", desc = "test only: cruise altitude of all aircraft definitions, lines [zzalt]", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 (a normal game): prints name, cruiseAltitude and speed of every unit definition that can fly.
local function log(...) Spring.Echo("[zzalt] " .. table.concat({ ... }, " ")) end
local lastUnpause = 0
function widget:Update()
	local _, _, paused = Spring.GetGameSpeed()
	if paused and os.clock() - lastUnpause > 1 then lastUnpause = os.clock(); Spring.SendCommands("pause 0") end
end
function widget:GameFrame(f)
	if f == 10 then
		local n = 0
		for id, ud in pairs(UnitDefs) do
			if ud.canFly then
				n = n + 1
				log("def", ud.name, "|", tostring(ud.humanName), "| cruise", tostring(ud.cruiseAltitude), "| hover", tostring(ud.hoverAttack), "| speed", string.format("%.0f", ud.speed or 0), "| bomber", tostring(ud.isBomberAirUnit), "| fighter", tostring(ud.isFighterAirUnit), "| name", tostring(ud.translatedHumanName), "| transport", tostring(ud.transportCapacity and ud.transportCapacity > 0))
			end
		end
		log("count", n)
	end
	if f == 20 then Spring.SendCommands("quitforce") end
end
