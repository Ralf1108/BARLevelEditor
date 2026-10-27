function widget:GetInfo() return { name = "zz bpt", desc = "temporary: BluePrinter plan tests", layer = 1000001, enabled = true } end
local function log(t) Spring.Echo("zz: " .. t) end
local function chk(ok, msg) log((ok and "PASS " or "FAIL ") .. msg) end
local function W() return WG.BluePrinterWidget end
local function st() return W():DebugState() end
local cx, cz, cy, cid, rotBefore, delN
local gs = 3
local function gi() return #st().plans - gs + 1 end
local function names(s)
	local o = {}
	for i, p in ipairs(s.plans) do o[#o + 1] = i .. (p.sel and "*" or "") .. ":" .. p.name:sub(4, 9) .. "@" .. math.floor(p.x) .. "," .. math.floor(p.z) .. "f" .. p.f end
	return table.concat(o, " ")
end
local function firstSel(s)
	for i, p in ipairs(s.plans) do if p.sel then return i end end
end
local clickAt
local function warpTo(i)
	local p = st().plans[i]
	local sx, sy = Spring.WorldToScreenCoords(p.x, Spring.GetGroundHeight(p.x, p.z), p.z)
	Spring.WarpMouse(sx, sy)
	clickAt = { sx, sy }
end
local function clickNow()
	local mx, my = Spring.GetMouseState()
	local what, pos = Spring.TraceScreenRay(mx, my)
	log("click: mouse " .. mx .. "," .. my .. " want " .. math.floor(clickAt[1]) .. "," .. math.floor(clickAt[2]) .. " ray " .. tostring(what) .. " " .. (type(pos) == "table" and (math.floor(pos[1]) .. "," .. math.floor(pos[3])) or tostring(pos)))
	local r = W():MousePress(clickAt[1], clickAt[2], 1)
	log("MousePress returned " .. tostring(r))
	W():MouseRelease(clickAt[1], clickAt[2], 1)
end
-- a spot where the building can be placed, searched in a ring around (x, z)
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
local steps = {}
local function at(f, fn) steps[#steps + 1] = { f = f, fn = fn } end

at(30, function()
	cid = Spring.GetTeamUnits(Spring.GetMyTeamID())[1]
	cx, cy, cz = Spring.GetUnitPosition(cid)
	Spring.SetCameraState({ name = "spring", px = cx + 400, py = cy, pz = cz, dist = 1800, rx = 2.5, ry = 0, rz = 0, fov = 45 })
	log("commander at " .. math.floor(cx) .. "," .. math.floor(cz) .. " walking: " .. tostring(W() ~= nil))
end)
at(50, function()
	-- plan 1 is far away, 2..5 are near the commander: the queue order must choose 1, the nearest rule 2..5
	W():DebugSetAuto(false)
	W():DebugSetQueue(false)
	local fx, fz = spot("armsolar", cx + 800, cz + 100)
	W():DebugAdd("armsolar", fx, fz, 0)
	for i = 0, 3 do local nx, nz = spot("armwin", cx + 150 + i * 150, cz + 250) W():DebugAdd("armwin", nx, nz, 0) end
	local bx, bz = spot("armsolar", cx + 300, cz - 350)
	local pts = { { bx, bz } }
	for k = 1, 2 do
		local nx, nz = spot("armsolar", bx + k * 110, bz)
		local fresh = true
		for _, p in ipairs(pts) do if math.abs(p[1] - nx) < 70 and math.abs(p[2] - nz) < 70 then fresh = false end end
		if fresh then pts[#pts + 1] = { nx, nz } end
	end
	local units = {}
	for _, p in ipairs(pts) do units[#units + 1] = { name = "armsolar", dx = p[1] - bx, dz = p[2] - bz, rot = 0 } end
	gs = #units
	W():DebugAddBlueprint(units, bx, bz)
	local s = st()
	chk(#s.plans == 5 + gs, "5 + group queued: " .. #s.plans .. " " .. names(s))
end)
-- auto-build is on and the commander is idle: it takes a plan; stop it before the selection tests
at(52, function() Spring.GiveOrderToUnit(cid, CMD.STOP, {}, {}) end)
at(66, function() warpTo(gi()) end)
at(70, function()
	-- the bp group at the end: click the plan 6
	clickNow()
	local s = st()
	chk(s.selected == gs, "click on a blueprint plan selects its whole group (" .. gs .. "): " .. s.selected)
	chk(firstSel(s) == gi(), "selected are the last three")
end)
at(80, function()
	W():KeyPress(280) -- Page up
	local s = st()
	chk(firstSel(s) == gi() - 1, "Page up moves the group one place forward: first selected " .. tostring((firstSel(s))))
end)
at(85, function()
	W():KeyPress(278) -- Home
	local s = st()
	chk(firstSel(s) == 1, "Home: group at the front: " .. names(s))
end)
at(90, function()
	W():KeyPress(279) -- End
	local s = st()
	chk(firstSel(s) == gi(), "End: group at the back: " .. names(s))
end)
at(95, function()
	W():KeyPress(281) -- Page down at the end: nothing
	chk(firstSel(st()) == gi(), "Page down at the end changes nothing")
	Spring.SendCommands("bp_undo") -- undoes End? it was a real move: 1 -> 6 happened from front
end)
at(100, function()
	local s = st()
	chk(firstSel(s) == 1, "Undo takes the End back (group at the front again): " .. names(s))
	Spring.SendCommands("bp_undo")
end)
at(105, function()
	local s = st()
	chk(firstSel(s) == gi() - 1, "Undo takes Home back: first selected " .. tostring((firstSel(s))))
	Spring.SendCommands("bp_undo")
end)
at(110, function()
	local s = st()
	chk(firstSel(s) == gi(), "Undo takes Page up back: " .. names(s))
end)
at(115, function()
	local before = names(st())
	W():KeyPress(93) -- ]
	local s = st()
	local allRot = true
	for _, p in ipairs(s.plans) do if p.sel and p.f ~= 1 then allRot = false end end
	chk(allRot and names(s) ~= before, "] rotates the selected plans (f=1): " .. names(s))
	Spring.SendCommands("bp_undo")
	rotBefore = before
end)
at(117, function()
	chk(names(st()) == rotBefore, "Undo takes the rotation back")
end)
at(120, function()
	local n0 = #st().plans
	W():KeyPress(127) -- Del
	chk(#st().plans == n0 - gs, "Del removes the selected group: " .. #st().plans)
	delN = n0
	Spring.SendCommands("bp_undo")
end)
at(122, function()
	local s = st()
	chk(#s.plans == delN and firstSel(s) == nil, "Undo brings them back (selection cleared): " .. names(s))
end)
at(123, function() W():KeyPress(27) warpTo(2) end)
at(125, function()
	-- a single building: click selects only it
	clickNow()
	chk(st().selected == 1, "click on a single building selects only it: " .. st().selected)
	W():KeyPress(278)
	chk(firstSel(st()) == 1, "Home puts it first")
	Spring.SendCommands("bp_undo")
end)
at(126, function()
	Spring.SelectUnitArray({ cid }); W():KeyPress(27)
	for i, p in ipairs(st().plans) do if p.grp then warpTo(i) break end end
end)
at(128, function()
	W():DebugSetAuto(false)
	local r = W():MousePress(clickAt[1], clickAt[2], 3)
	W():MouseRelease(clickAt[1], clickAt[2], 3)
	log("right click returned " .. tostring(r))
end)
at(129, function()
	local n = Spring.GetUnitCommands(cid, 0)
	local want = 0
	for _, p in ipairs(st().plans) do
		if p.grp and Spring.TestBuildOrder(UnitDefNames[p.name].id, p.x, Spring.GetGroundHeight(p.x, p.z), p.z, p.f) ~= 0 then want = want + 1 end
	end
	local mine = 0
	for _, p in ipairs(st().plans) do if p.claim == cid then mine = mine + 1 end end
	local q = Spring.GetUnitCommands(cid, 10) or {}
	local names = {}
	for _, c in ipairs(q) do names[#names + 1] = tostring(c.id) .. "@" .. tostring(c.params and c.params[1] and math.floor(c.params[1])) end
	local gp = {}
	for _, p in ipairs(st().plans) do if p.grp then gp[#gp + 1] = math.floor(p.x) .. "," .. math.floor(p.z) .. (p.claim and "c" or "") end end
	log("queue: " .. table.concat(names, " ") .. " | group plans " .. table.concat(gp, " "))
	chk(n == want and mine == want and want >= 1, "right click on a blueprint plan: the commander got the whole copy (orders and claims = buildable plans of the copy " .. want .. "): " .. tostring(n) .. " / " .. mine)
	Spring.GiveOrderToUnit(cid, CMD.STOP, {}, {})
end)
at(130, function()
	-- queue order
	for _, p in ipairs(st().plans) do p.claim = nil end
	Spring.GiveOrderToUnit(cid, CMD.STOP, {}, {})
	W():DebugSetAuto(true)
	W():DebugSetQueue(true)
	chk(st().queueOrder == true, "queue order on")
end)
at(190, function()
	local s = st()
	local claimed
	for i, p in ipairs(s.plans) do if p.claim == cid then claimed = i break end end
	log("with queue order the commander took plan " .. tostring(claimed) .. " : " .. names(s) .. " | cmds " .. tostring(Spring.GetUnitCommands(cid, 0)) .. " blocked1=" .. tostring(s.plans[1] and s.plans[1].blocked))
	chk(claimed == 1, "queue order: the commander takes plan 1 (far away) instead of the nearest")
end)
at(195, function()
	-- an enemy near the commander: it stops building
	Spring.SendCommands("cheat 1")
end)
at(200, function()
	local sx, sy = Spring.WorldToScreenCoords(cx + 150, Spring.GetGroundHeight(cx + 150, cz), cz)
	Spring.WarpMouse(sx, sy)
	Spring.SendCommands("give 1 armpw 1")
end)
at(260, function()
	local e = Spring.GetUnitsInCylinder(cx, cz, 750, Spring.ENEMY_UNITS) or {}
	local s = st()
	local mine = 0
	for _, p in ipairs(s.plans) do if p.claim == cid then mine = mine + 1 end end
	local cmds = Spring.GetUnitCommands(cid, 0) or 0
	chk(#e > 0, "enemy units near the commander: " .. #e)
	chk(mine == 0, "the commander holds no plan any more (enemy near): " .. mine .. ", orders " .. tostring(cmds))
end)
at(270, function() Spring.SendCommands("quitforce") end)

local done = {}
function widget:Update()
	local f0 = Spring.GetGameFrame()
	for i, s in ipairs(steps) do
		if s.f <= f0 and not done[i] then
			done[i] = true
			local ok, err = pcall(s.fn)
			if not ok then log("TEST ERROR at step " .. i .. " (" .. s.f .. "): " .. tostring(err)) end
			break
		end
	end
end
