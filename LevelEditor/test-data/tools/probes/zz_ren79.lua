function widget:GetInfo() return { name = "zz ren79", desc = "test only: how smooth is the reverse gear", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren79.lua (game speed 1): the Pawn drives backward (S, the view looks along -x) and then forward (W, along +x); every drawn frame
-- the view position of the unit (GetUnitViewPosition, what the camera follows) is taken. Logs per phase: the mean step of the position between two drawn frames and its spread
-- (standard deviation / mean), the same for the height, and the heading spread. Lines "[zzren79]".
local function log(...) Spring.Echo("[zzren79] " .. table.concat({ ... }, " ")) end
local R, phase, last, steps, ys, hs = nil, nil, nil, {}, {}, {}
local function stats(a)
	local n, s = #a, 0
	for _, v in ipairs(a) do s = s + v end
	local m = n > 0 and s / n or 0
	local q = 0
	for _, v in ipairs(a) do q = q + (v - m) ^ 2 end
	return m, n > 1 and math.sqrt(q / (n - 1)) or 0, n
end
local function report(name)
	local first = {}
	for i = 20, 40 do first[#first + 1] = string.format("%.2f", steps[i] or -1) end
	local yy, ss = {}, {}
	for i = 20, 40 do yy[#yy + 1] = string.format("%.2f", ys[i] or -1) end
	for i = 100, 169 , 5 do ss[#ss + 1] = string.format("%.2f", steps[i] or -1) end
	log(name, "steps 20-40:", table.concat(first, " "), "| height steps:", table.concat(yy, " "), "| steps 100-169:", table.concat(ss, " "))
	local m, sd, n = stats(steps)
	local ym, ysd = stats(ys)
	local hm, hsd = stats(hs)
	log(name, "draw frames", n, "step mean", string.format("%.3f", m), "sd", string.format("%.3f", sd), "ratio", string.format("%.2f", m > 0 and sd / m or 0), "height step sd", string.format("%.3f", ysd), "heading step sd", string.format("%.4f", hsd))
	steps, ys, hs, last = {}, {}, {}, nil
end
function widget:Update()
	R = WG.renegade
	if not (R and R.unit and phase) then return end
	local x, y, z = Spring.GetUnitViewPosition(R.unit)
	local dx, dy, dz = Spring.GetUnitDirection(R.unit)
	if last then
		steps[#steps + 1] = math.sqrt((x - last[1]) ^ 2 + (z - last[3]) ^ 2)
		ys[#ys + 1] = y - last[2]
		hs[#hs + 1] = math.atan2(dx, dz) - last[4]
	end
	last = { x, y, z, math.atan2(dx, dz) }
end
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 270, 0 end
	if f == 100 then phase = "reverse"; R.keys = 4 end
	if f == 130 then steps, ys, hs, last = {}, {}, {}, nil end -- (after the first turn)
	if f == 300 then report("reverse S"); R.keys = 0 end
	if f == 330 then R.yaw = 90; R.keys = 1 end
	if f == 400 then steps, ys, hs, last = {}, {}, {}, nil end
	if f == 560 then report("forward W"); R.keys = 0 end
	if f == 580 then Spring.SendCommands("quitforce") end
end
