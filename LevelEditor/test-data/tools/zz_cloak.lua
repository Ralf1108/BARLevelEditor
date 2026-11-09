function widget:GetInfo() return { name = "zz cloak", desc = "test only: does the Cloak ability work on the own unit?", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Widget zz_cloak.lua (one instance): gives the player all abilities (game message evo|test|1, only with the
-- game option lanevotest=1), uses Cloak, and logs "[zzcloak]" lines with what the unit shows (unsynced: GetUnitIsCloaked of the own unit) and what the gadget
-- says (evo|test|2: "[Evolution] test: ..."). Ends the game at frame 300.
local function log(...) Spring.Echo("[zzcloak] " .. table.concat({ ... }, " ")) end
local function unit() return Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoUnit") end

function widget:GameFrame(f)
	if f == 60 then Spring.SendLuaRulesMsg("evo|test|1"); Spring.SendLuaRulesMsg("evo|test|3") end
	if f == 90 or f == 150 or f == 240 then
		log("frame", f, "unit", tostring(unit()), "cloaked", tostring(Spring.GetUnitIsCloaked(unit() or -1)), "abilities", tostring(Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "evoAbilities")))
		Spring.SendLuaRulesMsg("evo|test|2")
	end
	if f == 120 then
		log("using Cloak")
		Spring.SendLuaRulesMsg("evo|use|3")
	end
	if f == 300 then Spring.SendCommands("quitforce") end
end
