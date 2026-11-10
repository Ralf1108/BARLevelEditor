function widget:GetInfo() return { name = "zz ren42", desc = "test only: pictures of a shot of the Juggernaut in first person", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren42.lua: the player becomes a Juggernaut (corjugg), walks a little (W), an enemy Pawn walks up; when it is within 450 Elmo the crosshair is put on it,
-- the big gun (right button) fires and pictures are taken (screenshot png in the folder screenshots of the write dir) 6, 14 and 26 frames later. Lines "[zzren42]".
local function log(...) Spring.Echo("[zzren42] " .. table.concat({ ... }, " ")) end
local R
local fired
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 1", "setminspeed 1") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|corjugg") end
	if f == 150 then Spring.SendLuaRulesMsg("ren|spawn|armpw") end
	if f == 160 then R.keys = 1 end
	if f >= 160 and f % 3 == 0 and R.unit then
		if not R.enemy or not Spring.ValidUnitID(R.enemy) then
			R.enemy = nil
			for _, id in ipairs(Spring.GetTeamUnits(1)) do if UnitDefs[Spring.GetUnitDefID(id)].name == "armpw" then R.enemy = id end end
		end
		if R.enemy then
			local x, y, z = Spring.GetUnitViewPosition(R.unit)
			local ex, ey, ez = Spring.GetUnitPosition(R.enemy, true)
			local dx, dy, dz = ex - x, ey + 10 - y, ez - z
			R.yaw = math.deg(math.atan2(dx, dz)) % 360
			R.pitch = math.deg(math.atan2(dy, math.sqrt(dx * dx + dz * dz)))
			local d = math.sqrt(dx * dx + dz * dz)
			if not fired and d < 450 then
				fired = f
				R.keys = 0
				R.fire = 2
				log("fire at distance", string.format("%.0f", d), "frame", f, "crosshair", R.hit and R.hit.kind or "sky")
			end
		end
	end
	if fired then
		if f == fired + 4 then R.fire = 0 end
		for _, k in ipairs({ 26, 29, 33, 38, 46 }) do
			if f == fired + k then Spring.SendCommands("screenshot png"); log("picture at", f) end
		end
		if f == fired + 90 then Spring.SendCommands("quitforce") end
	end
	if f == 1500 then Spring.SendCommands("quitforce") end
end
