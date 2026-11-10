function widget:GetInfo() return { name = "zz cam", desc = "test only: which camera states take a direction", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -Widget zz_cam.lua: switches the Renegade view off and tries SetCameraState variants; logs "[zzcam]" lines.
local function log(...) Spring.Echo("[zzcam] " .. table.concat({ ... }, " ")) end
local function dump(st)
	local t = {}
	for k, v in pairs(st or {}) do t[#t + 1] = k .. "=" .. (type(v) == "number" and string.format("%.3f", v) or tostring(v)) end
	table.sort(t)
	return table.concat(t, " ")
end
local function dir() local a, b, c = Spring.GetCameraDirection() return string.format("dir %.2f %.2f %.2f", a, b, c) end
local u
local tries = {
	{ "fps dxdydz", function(x, y, z) return { name = "fps", px = x, py = y, pz = z, dx = 0, dy = 0, dz = 1 } end },
	{ "fps rx ry", function(x, y, z) return { name = "fps", px = x, py = y, pz = z, rx = 1.5708, ry = 0, rz = 0 } end },
	{ "fps ry pi", function(x, y, z) return { name = "fps", px = x, py = y, pz = z, rx = 1.5708, ry = 3.1416, rz = 0 } end },
	{ "free", function(x, y, z) return { name = "free", px = x, py = y, pz = z, rx = 1.5708, ry = 0, rz = 0 } end },
	{ "spring", function(x, y, z) return { name = "spring", px = x, py = y, pz = z, dx = 0, dy = 0, dz = 1, rx = 1.5708, ry = 0, rz = 0 } end },
}
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	if f == 100 then
		Spring.SendCommands("renegade")
		u = WG.renegade and WG.renegade.unit
		log("names", table.concat(Spring.GetCameraNames and (function() local t = {} for k, v in pairs(Spring.GetCameraNames()) do t[#t + 1] = tostring(k) .. "=" .. tostring(v) end return t end)() or { "?" }, ","))
		log("state", dump(Spring.GetCameraState()))
		log(dir())
	end
	if f >= 120 and (f - 120) % 20 == 0 then
		local i = (f - 120) / 20 + 1
		local t = tries[i]
		if t then
			local x, y, z = Spring.GetUnitViewPosition(u)
			local ok = Spring.SetCameraState(t[2](x, y + 22, z), 0)
			log(t[1], "returned", tostring(ok))
			t.f = f + 10
		end
	end
	for i, t in ipairs(tries) do
		if t.f == f then log(t[1], "after", dump(Spring.GetCameraState()), dir()); if i == 3 then Spring.SendCommands("screenshot png") end end
	end
	if f == 300 then Spring.SendCommands("quitforce") end
end
