function widget:GetInfo() return { name = "zz bpg", desc = "temporary: ghosts after undo", layer = 1000001, enabled = true } end
local function log(t) Spring.Echo("zz: " .. t) end
local function W() return WG.BluePrinterWidget end
local cid, cx, cy, cz
local steps = {}
local function at(f, fn) steps[#steps + 1] = { f = f, fn = fn } end
at(30, function()
	cid = Spring.GetTeamUnits(Spring.GetMyTeamID())[1]
	cx, cy, cz = Spring.GetUnitPosition(cid)
	Spring.SetCameraState({ name = "spring", px = cx + 400, py = cy, pz = cz, dist = 1500, rx = 2.5, ry = 0, rz = 0, fov = 45 })
	W():DebugSetAuto(true)
end)
local function spot(name, x, z)
	local id = UnitDefNames[name].id
	for r = 0, 600, 48 do
		for a = 0, 7 do
			local px, pz = x + r * math.cos(a * 0.785), z + r * math.sin(a * 0.785)
			px, pz = math.floor(px / 16) * 16, math.floor(pz / 16) * 16
			if px > 80 and pz > 80 and px < Game.mapSizeX - 80 and pz < Game.mapSizeZ - 80 and Spring.TestBuildOrder(id, px, Spring.GetGroundHeight(px, pz), pz, 0) == 2 then return px, pz end
		end
	end
	return x, z
end
at(40, function()
	local bx, bz = spot("armsolar", cx + 250, cz + 100)
	W():DebugAddBlueprint({ { name = "armsolar", dx = 0, dz = 0, rot = 0 }, { name = "armsolar", dx = 90, dz = 0, rot = 0 }, { name = "armsolar", dx = 180, dz = 0, rot = 0 }, { name = "armwin", dx = 0, dz = 90, rot = 0 } }, bx, bz)
	log("plans " .. #W():DebugState().plans)
end)
local function sites()
	local n, being = 0, 0
	for _, u in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID())) do
		local d = UnitDefs[Spring.GetUnitDefID(u)]
		if d and (d.name == "armsolar" or d.name == "armwin") then n = n + 1 if Spring.GetUnitIsBeingBuilt(u) then being = being + 1 end end
	end
	return n, being
end
at(100, function() Spring.SendCommands("screenshot png"); local n, b = sites(); local st = W():DebugState(); local p = st.plans[1]; log("shot with plans; own units " .. n .. ", unfinished " .. b .. " plans " .. #st.plans .. " claim " .. tostring(p and p.claim) .. " blocked " .. tostring(p and p.blocked) .. " cmds " .. tostring(Spring.GetUnitCommands(cid, 0)) .. " cid " .. tostring(cid)) end)
at(150, function() local n, b = sites(); log("150: before undo own units " .. n .. ", unfinished " .. b); Spring.SendCommands("bp_undo") end)
at(152, function() log("plans after undo " .. #W():DebugState().plans) end)
at(260, function() local n, b = sites(); log("170: own solar/wind units " .. n .. ", unfinished " .. b) end)
at(270, function() Spring.SendCommands("screenshot png"); log("shot after undo") end)
at(330, function() local n, b = sites(); log("200: own solar/wind units " .. n .. ", unfinished " .. b) end)
at(340, function() Spring.SendCommands("quitforce") end)
local done = {}
function widget:Update()
	local f0 = Spring.GetGameFrame()
	for i, s in ipairs(steps) do
		if s.f <= f0 and not done[i] then
			done[i] = true
			local ok, err = pcall(s.fn)
			if not ok then log("TEST ERROR " .. i .. ": " .. tostring(err)) end
			break
		end
	end
end
