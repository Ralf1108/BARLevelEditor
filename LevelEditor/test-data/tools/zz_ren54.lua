function widget:GetInfo() return { name = "zz ren54", desc = "test only: which Spring functions know about crashing aircraft", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren54.lua: lists the functions of Spring with "rash" in the name and the fields of GetUnitMoveTypeData of a bomber and a gunship ("[zzren54]").
local function log(...) Spring.Echo("[zzren54] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; for k in pairs(Spring) do if tostring(k):lower():find("crash") then log("fn", k) end end end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|armthund") end
	if f == 120 then for k, v in pairs(Spring.GetUnitMoveTypeData(R.unit) or {}) do log("md bomber", k, tostring(v)) end; Spring.SendLuaRulesMsg("ren|unit|armbrawl") end
	if f == 170 then for k, v in pairs(Spring.GetUnitMoveTypeData(R.unit) or {}) do log("md gunship", k, tostring(v)) end; Spring.SendCommands("quitforce") end
end
