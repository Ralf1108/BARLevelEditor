function widget:GetInfo() return { name = "zz ren33", desc = "test only: crosshair and weapon rows colour by range", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren33.lua: the player becomes a Titan (armbanth: weapons of range 465, 800 and 860); an enemy Pawn is spawned 1000 Elmo ahead and walks
-- toward the player (the game's orders). Logs every 20 frames the distance of what is under the crosshair, the colour of the crosshair (R.best) and of the three weapon rows (R.states). Lines "[zzren33]".
local function log(...) Spring.Echo("[zzren33] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbanth") end
	if f == 120 then Spring.SendLuaRulesMsg("ren|spawn|armpw") end
	if f >= 125 and f % 3 == 0 and f <= 900 and R.unit then
		if not R.enemy or not Spring.ValidUnitID(R.enemy) then
			R.enemy = nil
			for _, id in ipairs(Spring.GetTeamUnits(1)) do if UnitDefs[Spring.GetUnitDefID(id)].name == "armpw" then R.enemy = id end end
		end
		if R.enemy then
			local x, y, z = Spring.GetUnitPosition(R.unit)
			local ex, ey, ez = Spring.GetUnitPosition(R.enemy, true)
			local dx, dy, dz = ex - x, ey - (y + 20), ez - z
			R.yaw = math.deg(math.atan2(dx, dz)) % 360
			R.pitch = math.deg(math.atan2(dy, math.sqrt(dx * dx + dz * dz)))
		end
	end
	if f >= 140 and f % 20 == 0 and f <= 900 then
		local h = R.hit
		log("f", f, "hit", h and (h.kind .. " " .. string.format("%.0f", h.udist)) or "sky", "crosshair", tostring(R.best), "rows", R.states and table.concat(R.states, ",") or "-")
	end
	if f == 920 then Spring.SendCommands("quitforce") end
end
