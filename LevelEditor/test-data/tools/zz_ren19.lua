function widget:GetInfo() return { name = "zz ren19", desc = "test only: Renegade gunship fires at a ground unit", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren19.lua: turns into a gunship (UNIT below), an enemy Pawn stands 150 Elmo ahead (hook 1), the left button is held for 3 s. Lines "[zzren19]".
local UNIT = "armbrawl"
local function ts(a) return tostring(a) end
local function log(...) Spring.Echo("[zzren19] " .. table.concat({ ... }, " ")) end
local R, enemy
local function rf(i) return Spring.GetUnitWeaponState(R.unit, i or 1, "reloadFrame") or 0 end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|" .. UNIT) end
	if f == 140 then R.yaw = 90 end
	if f == 190 then Spring.SendLuaRulesMsg("ren|test|1") end
	if f == 141 then log("slots", ts(Spring.GetUnitRulesParam(R.unit, "renSlots")), "aa", ts(Spring.GetUnitRulesParam(R.unit, "renAA")), "hy", ts(Spring.GetUnitRulesParam(R.unit, "renHY")))end
	if (f == 220 or (f > 230 and f < 330 and f % 4 == 0)) and (f == 220 or enemy) then
		if f == 220 then for _, id in ipairs(Spring.GetTeamUnits(1)) do if UnitDefs[Spring.GetUnitDefID(id)].name == "armpw" then enemy = id end end end
		if enemy then
			local px, py, pz = Spring.GetUnitViewPosition(R.unit)
			local x, y, z = Spring.GetUnitPosition(enemy, true)
			R.yaw = math.deg(math.atan2(x - px, z - pz)) % 360
			R.pitch = math.deg(math.atan2(y - py, math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)))
			if f == 220 then log("enemy", ts(enemy), "dist", string.format("%.0f", math.sqrt((x - px) ^ 2 + (z - pz) ^ 2)), "height of unit", string.format("%.0f", py), "pitch", string.format("%.0f", R.pitch)) end
		end
	end
	if f == 150 then R.keys = 1 end
	if f == 185 then R.keys = 0 end
	if f == 186 then R.yaw = 180 end
	if f == 230 then R.fire = 1 end
	if f >= 230 and f <= 330 and f % 20 == 0 then
		local tt, tg = Spring.GetUnitWeaponTarget(R.unit, 1)
		log("f", f, "reloadFrame", rf(), "target", ts(tt), ts(type(tg) == "table" and string.format("%.0f %.0f %.0f", tg[1], tg[2], tg[3]) or tg), "enemy", enemy and string.format("%.0f", (Spring.GetUnitHealth(enemy) or -1)) or "?", "fire", R.fire, "dir", string.format("%.2f %.2f", select(1, Spring.GetUnitDirection(R.unit)), select(3, Spring.GetUnitDirection(R.unit))), "shot", R.shot and string.format("%s %.0f", R.shot.kind, R.shot.udist or -1) or "-")
	end
	if f == 330 then R.fire = 0; Spring.SendCommands("quitforce") end
end
