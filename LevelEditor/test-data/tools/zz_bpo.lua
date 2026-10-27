function widget:GetInfo() return { name = "zz bpo", desc = "temporary: plans on plans and buildings", layer = 1000001, enabled = true } end
local function log(t) Spring.Echo("zz: " .. t) end
local function chk(ok, msg) log((ok and "PASS " or "FAIL ") .. msg) end
local function W() return WG.BluePrinterWidget end
local steps, done = {}, {}
local function at(f, fn) steps[#steps + 1] = { f = f, fn = fn } end
local cx, cy, cz, bx, bz
local function spot(name, x, z)
	local id = UnitDefNames[name].id
	for r = 0, 600, 48 do for a = 0, 7 do
		local px, pz = x + r * math.cos(a * 0.785), z + r * math.sin(a * 0.785)
		px, pz = math.floor(px / 16) * 16, math.floor(pz / 16) * 16
		if px > 80 and pz > 80 and Spring.TestBuildOrder(id, px, Spring.GetGroundHeight(px, pz), pz, 0) == 2 then return px, pz end
	end end
	return x, z
end
local function oldPlanThere()
	for _, p in ipairs(W():DebugState().plans) do
		if math.abs(p.x - bx) < 20 and math.abs(p.z - bz) < 20 and not p.grp then return true end
	end
	return false
end
at(30, function()
	local c = Spring.GetTeamUnits(Spring.GetMyTeamID())[1]
	cx, cy, cz = Spring.GetUnitPosition(c)
	W():DebugSetAuto(false)
	Spring.SetCameraState({ name = "spring", px = cx + 400, py = cy, pz = cz, dist = 1500, rx = 2.5, ry = 0, rz = 0, fov = 45 })
	bx, bz = spot("armsolar", cx + 300, cz + 100)
	chk(W():DebugAdd("armsolar", bx, bz, 0) == true, "a solar collector is queued")
	chk(W():DebugAdd("armsolar", bx + 24, bz + 8, 0) == false, "a single building on top of a plan is refused")
	local n, skipped, blocked, replaced = W():DebugAddBlueprint({ { name = "armsolar", dx = 0, dz = 0, rot = 0 }, { name = "armsolar", dx = 90, dz = 0, rot = 0 } }, bx + 40, bz)
	chk(n >= 1 and replaced == 1, "a blueprint on top of a plan replaces it: new=" .. tostring(n) .. " left out=" .. tostring(blocked) .. " replaced=" .. tostring(replaced))
	chk(not oldPlanThere(), "the old plan is gone from the queue")
	Spring.SendCommands("bp_undo")
end)
at(40, function()
	local dd = {}
	for _, p in ipairs(W():DebugState().plans) do dd[#dd + 1] = math.floor(p.x) .. "," .. math.floor(p.z) .. (p.grp and "g" or "") end
	log("plans now: " .. table.concat(dd, " ") .. " old at " .. bx .. "," .. bz)
	chk(oldPlanThere() and #W():DebugState().plans == 1, "Undo takes the blueprint away and brings the replaced plan back: plans " .. #W():DebugState().plans)
	-- a blueprint over a real building: that building is left out, the rest is placed
	local id = UnitDefNames.armsolar.id
	local ok = W():DebugAdd("armmex", bx + 400, bz, 0)
	local n = 0
	for k = 1, 12 do
		local mx, mz = spot("armsolar", bx - 150 - k * 70, bz + k * 20)
		local nn = W():DebugAddBlueprint({ { name = "armsolar", dx = 0, dz = 0, rot = 0 } }, mx, mz)
		if nn == 1 then n = 1 break end
	end
	chk(n == 1, "a blueprint on free ground is placed")
	-- the commander stands somewhere: a blueprint on top of him is allowed (mobile units do not block)
	local nu, _, bl = W():DebugAddBlueprint({ { name = "armsolar", dx = 0, dz = 0, rot = 0 } }, cx + 4, cz + 4)
	log("on top of the commander: new=" .. tostring(nu) .. " left out=" .. tostring(bl) .. " (info)")
end)
at(60, function() Spring.SendCommands("screenshot png") end)
at(70, function() Spring.SendCommands("quitforce") end)
function widget:Update()
	local f0 = Spring.GetGameFrame()
	for i, s in ipairs(steps) do
		if s.f <= f0 and not done[i] then done[i] = true local ok, err = pcall(s.fn) if not ok then log("TEST ERROR " .. i .. ": " .. tostring(err)) end break end
	end
end
