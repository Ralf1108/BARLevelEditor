function widget:GetInfo() return { name = "zz ren41", desc = "test only: a bomber drops only up to its attack altitude", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren41.lua: the player becomes a Tsunami (armsb, attack altitude 210); after the take-off (about 400) the left button is clicked: nothing may fall
-- and the weapon row is red; then it sinks (Ctrl) to under 200 and the click must drop the bombs (row green). Logs the height, the colour of the row (R.states) and the gadget's "bombs:" lines. Lines "[zzren41]".
local function log(...) Spring.Echo("[zzren41] " .. table.concat({ ... }, " ")) end
local R
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 0, -10 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armsb") end
	if f == 140 then R.keys = 1 end
	if f == 330 then R.fire = 1; log("click 1 at the take-off height") end
	if f == 336 then R.fire = 0 end
	if f == 360 then R.keys = 33 end
	if f >= 360 and f < 520 and f % 2 == 0 and R.unit and R.keys == 33 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		if y - Spring.GetGroundHeight(x, z) < 185 then R.keys = 1; log("ctrl released at", f) end
	end
	if f == 560 then R.fire = 1; log("click 2 low") end
	if f == 566 then R.fire = 0 end
	if f >= 300 and f % 20 == 0 and f <= 700 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("f", f, "above ground", string.format("%.0f", y - Spring.GetGroundHeight(x, z)), "row", R.states and tostring(R.states[1]) or "-")
	end
	if f == 720 then Spring.SendCommands("quitforce") end
end
