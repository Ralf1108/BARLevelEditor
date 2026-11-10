function widget:GetInfo() return { name = "zz ren16", desc = "test only: Renegade commander: laser left, Disintegrator (D-gun) right", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren16.lua: turns into the Armada Commander, an enemy Pawn stands 150 Elmo ahead (hook 1); the right button fires the D-gun at it. Lines "[zzren16]".
local function log(...) Spring.Echo("[zzren16] " .. table.concat({ ... }, " ")) end
local R, enemy
local function rf(i) return Spring.GetUnitWeaponState(R.unit, i, "reloadFrame") or 0 end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armcom") end
	if f == 140 then log("slots", tostring(Spring.GetUnitRulesParam(R.unit, "renSlots")), "weapon 3 reloadFrame", rf(3)); Spring.SendLuaRulesMsg("ren|test|1") end
	if f == 170 then
		for _, id in ipairs(Spring.GetTeamUnits(1)) do if UnitDefs[Spring.GetUnitDefID(id)].name == "armpw" then enemy = id end end
		log("enemy", tostring(enemy), "health", enemy and string.format("%.0f", (Spring.GetUnitHealth(enemy))) or "?")
		if enemy then
			local px, py, pz = Spring.GetUnitViewPosition(R.unit)
			py = py + Spring.GetUnitHeight(R.unit) * 0.85
			local x, y, z = Spring.GetUnitPosition(enemy, true)
			R.yaw = math.deg(math.atan2(x - px, z - pz)) % 360
			R.pitch = math.deg(math.atan2(y - py, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)))
		end
	end
	if f == 200 then R.fire = 2 end
	if f == 230 then log("right button held: weapon 3 reloadFrame", rf(3), "frame", f, "target", tostring((Spring.GetUnitWeaponTarget(R.unit, 3))), "enemy health", enemy and string.format("%.0f", (Spring.GetUnitHealth(enemy) or -1)) or "?"); R.fire = 0 end
	if f == 260 then log("after: enemy health", enemy and string.format("%.0f", (Spring.GetUnitHealth(enemy) or -1)) or "?", "(-1 = gone)") end
	if f == 270 then R.fire = 1 end
	if f == 300 then log("left button: weapon 1 reloadFrame", rf(1), "frame", f); R.fire = 0 end
	if f == 330 then Spring.SendCommands("quitforce") end
end
