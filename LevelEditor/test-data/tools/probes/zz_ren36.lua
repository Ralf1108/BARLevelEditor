function widget:GetInfo() return { name = "zz ren36", desc = "test only: Renegade bomber drops bombs at which heights", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren36.lua: the player becomes a Tsunami (armsb); it takes off (W), then the left button is held at about 400, at the highest height (Space)
-- and low (Ctrl). The gadget logs "[Renegade] weapon 1 fired"; this widget logs the height every 10 frames and when the button goes down or up. Lines "[zzren36]".
local function log(...) Spring.Echo("[zzren36] " .. table.concat({ ... }, " ")) end
local R
local FIRE = { { 330, 370 }, { 520, 560 }, { 740, 780 } }
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 0, -10 end
	if f == 100 then
		Spring.SendLuaRulesMsg("ren|unit|armsb")
		local ud = UnitDefNames.armsb
		local wd = WeaponDefs[ud.weapons[1].weaponDef]
		log("weapon", wd.name, "range", tostring(wd.range), "type", tostring(wd.type), "heightmod", tostring(wd.heightmod), "myGravity", tostring(wd.myGravity), "onlyForward", tostring(wd.onlyForward), "maxAngleDif", tostring(ud.weapons[1].maxAngleDif))
	end
	if f == 140 then R.keys = 1 end
	if f == 380 then R.keys = 17 end
	if f == 500 then R.keys = 1 end
	if f == 580 then R.keys = 33 end
	if f == 700 then R.keys = 1 end
	for _, w in ipairs(FIRE) do
		if f == w[1] then R.fire = 1; log("button down") end
		if f == w[2] then R.fire = 0; log("button up") end
	end
	if f >= 300 and f % 10 == 0 and f <= 800 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("f", f, "above ground", string.format("%.0f", y - Spring.GetGroundHeight(x, z)))
	end
	if f == 820 then Spring.SendCommands("quitforce") end
end
