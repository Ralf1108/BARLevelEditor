function widget:GetInfo() return { name = "zz ren55", desc = "test only: the third person camera (Shift)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren55.lua: a Pawn and a Behemoth in the third person view (R.third, as Shift sets it), looking level and down; pictures; "[zzren55]" logs the camera.
local function log(...) Spring.Echo("[zzren55] " .. table.concat({ ... }, " ")) end
local list = { "armpw", "corjugg" }
function widget:GameFrame(f)
	local R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	for i, name in ipairs(list) do
		local b = 70 + (i - 1) * 120
		if f == b then Spring.SendLuaRulesMsg("ren|unit|" .. name) end
		if f == b + 20 then R.third = true; Spring.SetUnitNoDraw(R.unit, false) end
		if f == b + 50 then
			local px, py, pz = Spring.GetCameraPosition()
			local ux, uy, uz = Spring.GetUnitPosition(R.unit)
			log(name, "camera", math.floor(px), math.floor(py), math.floor(pz), "unit", math.floor(ux), math.floor(uy), math.floor(uz))
			Spring.SendCommands("screenshot png")
		end
		if f == b + 70 then R.pitch = -20 end
		if f == b + 100 then Spring.SendCommands("screenshot png") end
	end
	if f == 70 + 120 * #list + 20 then Spring.SendCommands("quitforce") end
end
