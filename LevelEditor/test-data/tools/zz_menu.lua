function widget:GetInfo() return { name = "zz menu", desc = "temporary: menu switching", layer = 1000000, enabled = true } end
local function log(t) Spring.Echo("zz: " .. t) end
local function W() return WG.LevelEditorWidget end
local function allRects()
	local out = {}
	for _, v in pairs({ W():DebugLayout() }) do
		if type(v) == "table" then for _, r in ipairs(v) do if type(r) == "table" and r.kind and r.x1 and r.side then out[#out + 1] = r end end end
	end
	return out
end
local BTN = { { "gear", "gear" }, { "info", "info" }, { "ai", "ai" }, { "top", "place" }, { "top", "gen" }, { "td", "td" }, { "ctf", "ctf" }, { "rtf", "rtf" } }
local function find(b) for _, r in ipairs(allRects()) do if r.kind == b[1] and r.value == b[2] then return r end end end
local function click(b)
	local r = find(b)
	if not r then log("NO BUTTON " .. b[2]) return end
	local x, y = (r.x1 + r.x2) / 2, (r.y0 + r.y1) / 2
	W():MousePress(x, y, 1); W():MouseRelease(x, y, 1)
end
local function activeSet()
	local s = {}
	for _, b in ipairs(BTN) do local r = find(b) if r and r.active then s[#s + 1] = b[2] end end
	return table.concat(s, ",")
end
local function reset() click({ "top", "place" }); click({ "top", "place" }) end
local steps = {}
local done = {}
local queue, bad, n = {}, 0, 0
for _, a in ipairs(BTN) do for _, b in ipairs(BTN) do if a[2] ~= b[2] then queue[#queue + 1] = { a, b } end end end
for _, a in ipairs(BTN) do queue[#queue + 1] = { a } end
steps[40] = function()
	local q = table.remove(queue, 1)
	if not q then
		log("pairs " .. n .. " mismatches " .. bad)
		Spring.SendCommands("quitforce") return
	end
	reset()
	if q[2] then
		click(q[1]); click(q[2]); n = n + 1
		local got = activeSet()
		if got ~= q[2][2] then bad = bad + 1; log("MISMATCH " .. q[1][2] .. " -> " .. q[2][2] .. ": active=" .. got) end
	else
		click(q[1]); click(q[1])
		local got = activeSet()
		if got ~= "place" and q[1][2] ~= "place" then log("TOGGLE " .. q[1][2] .. " twice: active=" .. got) end
	end
	collectgarbage()
	done[40] = nil
end
function widget:Update()
	local f0 = Spring.GetGameFrame()
	for _, k in ipairs({ 40, 60 }) do
		if k <= f0 and not done[k] then
			done[k] = true
			local ok, err = pcall(steps[k])
			if not ok then log("TEST ERROR at " .. k .. ": " .. tostring(err)) end
			break
		end
	end
end
