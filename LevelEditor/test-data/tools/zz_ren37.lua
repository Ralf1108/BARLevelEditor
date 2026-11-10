function widget:GetInfo() return { name = "zz ren37", desc = "test only: Renegade bomber, one short click", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren37.lua: the player becomes a Tsunami (armsb), takes off (W held), goes down to about 250 above the ground (Ctrl), then the left
-- button is clicked for 3 frames (a short click), later once more for 3 frames. The gadget logs "press" and "fired" with the frames. Lines "[zzren37]".
local function log(...) Spring.Echo("[zzren37] " .. table.concat({ ... }, " ")) end
local R
local CLICK = { 470, 900 }
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 0, -10 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armsb") end
	if f == 140 then R.keys = 1 end
	if f == 330 then R.keys = 33 end
	if f >= 330 and f < 440 and R.unit and f % 2 == 0 then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		if y - Spring.GetGroundHeight(x, z) < 250 and R.keys == 33 then R.keys = 1; log("ctrl released at", f) end
	end
	for _, c in ipairs(CLICK) do
		if f == c then R.fire = 1; log("button down") end
		if f == c + (c == 900 and 90 or 3) then R.fire = 0; log("button up") end
	end
	if f >= 440 and f % 10 == 0 and f <= 1200 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("f", f, "above ground", string.format("%.0f", y - Spring.GetGroundHeight(x, z)))
	end
	if f == 1220 then Spring.SendCommands("quitforce") end
end
