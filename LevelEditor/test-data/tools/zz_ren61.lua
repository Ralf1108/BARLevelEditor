function widget:GetInfo() return { name = "zz ren61", desc = "test only: all turrets follow the view (the D-gun too)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren61.lua: the player becomes a Behemoth (corjugg) and looks along yaw 0, 90, 180 in turn without firing; "[zzren61]" logs the direction of every weapon
-- (yaw of its aim vector) and its reload frame (1000000 = held: aims, does not fire) a second after each turn.
local function log(...) Spring.Echo("[zzren61] " .. table.concat({ ... }, " ")) end
local yaws = { 0, 90, 180 }
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|corjugg") end
	for k, y in ipairs(yaws) do
		local b = 100 + (k - 1) * 100
		if f == b then R.yaw = y end
		if f == b + 80 then
			local u = R.unit
			local ud = UnitDefs[Spring.GetUnitDefID(u)]
			local parts = {}
			for i = 1, #ud.weapons do
				local _, _, _, dx, _, dz = Spring.GetUnitWeaponVectors(u, i)
				local wy = dx and (math.deg(math.atan2(dx, dz)) % 360) or -1
				parts[#parts + 1] = string.format("w%d(%s) %d reload %s", i, WeaponDefs[ud.weapons[i].weaponDef].type, wy, tostring(Spring.GetUnitWeaponState(u, i, "reloadFrame")))
			end
			log("look yaw", y, "weapons:", table.concat(parts, " | "))
		end
	end
	if f == 420 then Spring.SendCommands("quitforce") end
end
