function widget:GetInfo() return { name = "zz ren9", desc = "test only: Renegade respawn with countdown, barrel lines", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren9.lua: turns into a ship (on the land), kills the unit, looks at the countdown and whether it comes back;
-- GetUnitWeaponVectors of the unit. Lines "[zzren9]".
local function log(...) Spring.Echo("[zzren9] " .. table.concat({ ... }, " ")) end
local R
local function mine() return Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit") or 0 end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, -10 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armroy") end
	if f == 110 then R.yaw, R.pitch = 270, -3; R.fire = 1 end
	if f >= 110 and f <= 150 and f % 8 == 0 and R.unit then
		local v = { Spring.GetUnitWeaponVectors(R.unit, 1) }
		local fx, _, fz = Spring.GetUnitDirection(R.unit)
		log("frame", f, "weapon dir", string.format("%.2f %.2f %.2f", v[4] or 0, v[5] or 0, v[6] or 0), "unit facing", string.format("%.2f %.2f", fx or 0, fz or 0), "target", tostring(Spring.GetUnitWeaponTarget(R.unit, 1)))
	end
	if f == 130 then
		local v = { Spring.GetUnitWeaponVectors(R.unit, 1) }
		local s = {}
		for i, x in ipairs(v) do s[#s + 1] = type(x) == "number" and string.format("%.2f", x) or tostring(x) end
		log("ship", tostring(UnitDefs[Spring.GetUnitDefID(R.unit)].name), "GetUnitWeaponVectors:", table.concat(s, " "))
		Spring.SendCommands("screenshot png")
	end
	if f == 160 then R.fire = 0; R.back = nil; Spring.SendLuaRulesMsg("ren|test|2") end
	if f == 170 then log("dead: renUnit", tostring(mine()), "respawn at frame", tostring(Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renRespawn")), "now", f); Spring.SendCommands("screenshot png") end
	if f == 250 then log("still dead", tostring(mine())) end
	if f > 165 and mine() > 0 and not R.back then R.back = true; log("the unit is back at frame", f, "(", f - 160, "frames after the kill)", UnitDefs[Spring.GetUnitDefID(mine())].name) end
	if f == 400 then Spring.SendCommands("quitforce") end
end
