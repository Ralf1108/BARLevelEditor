function widget:GetInfo() return { name = "zz ren70", desc = "test only: a spider walks backwards (S) without turning round", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren70.lua: the player becomes a Webber (armspid), looks along the way it faces and presses S for 4 s; "[zzren70]" logs the heading of the body and its
-- position every half second: does it turn round (the heading changes by 180 degrees) or walk backwards (the heading stays)?
local function log(...) Spring.Echo("[zzren70] " .. table.concat({ ... }, " ")) end
local UNIT = "armspid"
local h0
function widget:GameFrame(f)
	local R = WG.renegade
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 0, 0 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|" .. UNIT) end
	if f == 120 and R.unit then
		local fx, _, fz = Spring.GetUnitDirection(R.unit)
		R.yaw = math.deg(math.atan2(fx, fz)) % 360 -- look along the way the body faces: S then means straight back
		h0 = R.yaw
		log("facing yaw", string.format("%.0f", h0))
	end
	if f == 140 then R.keys = 4 end
	if f > 140 and f <= 300 and f % 15 == 0 and R.unit then
		local fx, _, fz = Spring.GetUnitDirection(R.unit)
		local x, _, z = Spring.GetUnitPosition(R.unit)
		local hd = math.deg(math.atan2(fx, fz)) % 360
		local back = (x - 0) -- (position along the line of sight below)
		local dirx, dirz = math.sin(math.rad(h0)), math.cos(math.rad(h0))
		local a0x, a0z = R.start and R.start[1] or x, R.start and R.start[2] or z
		R.start = R.start or { x, z }
		local along = (x - a0x) * dirx + (z - a0z) * dirz
		log("frame", f, "heading", string.format("%.0f", hd), "moved along the facing line", string.format("%.0f", along))
	end
	if f == 310 then R.keys = 0; Spring.SendCommands("quitforce") end
end
