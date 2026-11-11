function widget:GetInfo() return { name = "zz ren64", desc = "test only: the Exploiters (extractors with weapons) fire", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren64.lua: the player becomes an Advanced Exploiter (cormexp) and an Exploiter (corexp) in turn, looks at the ground, presses the left and right button;
-- "[zzren64]" logs the groups, the reload frames and the unit states.
local function log(...) Spring.Echo("[zzren64] " .. table.concat({ ... }, " ")) end
local list = { "cormexp", "corllt", "armllt" }
function widget:GameFrame(f)
	local R = WG.renegade
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 8 end
	for k, name in ipairs(list) do
		local b = 70 + (k - 1) * 200
		if f == b then Spring.SendLuaRulesMsg("ren|unit|" .. name) end
		if f == b + 40 and R.unit then
			local u = R.unit
			local ud = UnitDefs[Spring.GetUnitDefID(u)]
			log(name, "slots", tostring(Spring.GetUnitRulesParam(u, "renSlots")), "aa", tostring(Spring.GetUnitRulesParam(u, "renAA")), "canMove", tostring(ud.canMove), "isBuilding", tostring(ud.isBuilding), "weapons", #ud.weapons, "hit", tostring(R.hit and R.hit.kind), "udist", tostring(R.hit and math.floor(R.hit.udist)))
			local act = Spring.GetUnitIsActive and Spring.GetUnitIsActive(u)
			local st = Spring.GetUnitStates(u)
			log("active", tostring(act), "firestate", tostring(st and st.firestate), "stunned", tostring(Spring.GetUnitIsStunned(u)), "buildProgress", tostring(select(5, Spring.GetUnitHealth(u))))
			R.fire = 3
		end
		if f == b + 80 and R.unit then
			local u = R.unit
			local ud = UnitDefs[Spring.GetUnitDefID(u)]
			local parts = {}
			for i = 1, #ud.weapons do parts[#parts + 1] = string.format("w%d reload %s", i, tostring(Spring.GetUnitWeaponState(u, i, "reloadFrame"))) end
			log(name, "after the press (frame", f, "):", table.concat(parts, " | "))
			R.fire = 0
		end
	end
	if f == 70 + 200 * #list then Spring.SendCommands("quitforce") end
end
