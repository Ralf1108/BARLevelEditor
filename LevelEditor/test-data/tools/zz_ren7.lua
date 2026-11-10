function widget:GetInfo() return { name = "zz ren7", desc = "test only: Renegade search field and a ship on land", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren7.lua: types into the search field of the unit menu (picture) and turns into a ship on the land. Lines "[zzren7]".
local function log(...) Spring.Echo("[zzren7] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.menu, R.list = true, true end
	if f == 100 then
		local g = R.picker
		if g then g:setFocus(true); for c in ("pawn"):gmatch(".") do g:textInput(c) end; log("search", g.query, "results", tostring(#g:list())) else log("no picker yet") end
	end
	if f == 120 then Spring.SendCommands("screenshot png") end
	if f == 130 then R.picker:setFocus(false); R.picker.query = ""; R.menu, R.list = false, false; Spring.SendLuaRulesMsg("ren|unit|armroy") end
	if f == 170 then
		local u = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit")
		local d = UnitDefs[Spring.GetUnitDefID(u) or -1]
		log("now", d and d.name or "none", "on land height", string.format("%.1f", select(2, Spring.GetUnitPosition(u))))
		R.fire = 1
	end
	if f == 220 then log("ship fires: weapon target", tostring(Spring.GetUnitWeaponTarget(R.unit, 1)), "reloadFrame", tostring(Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame")), "frame", f); R.fire = 0 end
	if f == 240 then Spring.SendCommands("quitforce") end
end
