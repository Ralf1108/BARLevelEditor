-- Level Editor (stage 1), synchronized part: places, deletes and undoes. Only with /cheat.
function gadget:GetInfo()
	return {
		name = "Level Editor",
		desc = "Places and removes units for the level editor widget (cheat mode only)",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	function gadget:Initialize()
		gadgetHandler:AddSyncAction("led_marker", function(_, x, y, z, text)
			Spring.MarkerAddPoint(x, y, z, text, true)
		end)
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveSyncAction("led_marker")
	end

	return
end

-- History for undo / redo: a list of steps (one step = one action of the user, e.g. a whole row, a blueprint, a delete of the
-- selection). Every step has operations:
--   add   unit placed                del  unit deleted or blown up (boom, wrecks = wrecks that appeared)
--   swap  unit moved/rotated (before / after)      team  team change (old / new)
--   fadd  feature placed             fdel feature deleted
-- The widget sends "led|step" before every action; everything else up to the next "led|step" belongs to this step.
-- Units are created anew on undo/redo (new ID); replaceId then swaps the ID in all steps.
local history, redoStack = {}, {}
local HISTORY_MAX = 300
local current, sticky = nil, false
local suppress = 0 -- > 0: actions are not recorded (undo, redo, loading a level)
local capture -- list into which the wrecks that appear during a blow-up are entered
local inflight -- the step that is being undone or redone right now
local record, destroyRecorded -- defined below

-- Editor mode (game option leveleditor=1, set by start_level_editor.bat): then no /cheat is needed
local opt = Spring.GetModOptions().leveleditor
local EDITOR_MODE = (opt == "1" or opt == 1 or opt == true)

-- Units that stockpile missiles (nuclear silos and the like) start loaded in the editor. The stockpile is not part
-- of the level file, so a scenario built from the level starts with empty silos.
-- A new unit only takes the stockpile in a later frame (the same call at once after CreateUnit has no effect), so the
-- IDs wait in a list and GameFrame fills them.
local STOCKPILE_START = 10
local pendingStockpile = {}
local function fillStockpile(id)
	pendingStockpile[#pendingStockpile + 1] = id
end
local function fillPendingStockpiles()
	for i = #pendingStockpile, 1, -1 do
		local id = pendingStockpile[i]
		pendingStockpile[i] = nil
		if Spring.ValidUnitID(id) then
			local stock, queued = Spring.GetUnitStockpile(id) -- nil for units that cannot stockpile
			if stock then
				Spring.SetUnitStockpile(id, math.max(STOCKPILE_START, queued or 0))
			end
		end
	end
end

local function tell(playerID, text)
	if playerID then
		Spring.SendMessageToPlayer(playerID, "[Level Editor] " .. text)
	else
		Spring.Echo("[Level Editor] " .. text)
	end
end

-- Air units: without a saved height (y = nil or negative) they appear in the air at cruise height.
-- With a saved height: if it was close to the ground the air unit stays landed, otherwise it starts at exactly that height.
local function airHeight(ud, x, z, y)
	local ground = Spring.GetGroundHeight(x, z)
	if y and y >= 0 then
		if y > ground + 30 then
			return y, false
		end
		return ground, true -- landed
	end
	local cruise = ud.cruiseAltitude
	if not cruise or cruise < 50 then
		cruise = 150
	end
	cruise = math.min(cruise, 400) -- some types have extremely high cruise heights
	return ground + cruise, false
end

local function place(name, team, x, z, facing, playerID, y)
	if not UnitDefNames[name] then
		tell(playerID, "unknown unit: " .. tostring(name))
		return nil
	end
	if not team or not Spring.GetTeamInfo(team) then
		tell(playerID, "unknown team: " .. tostring(team))
		return nil
	end
	facing = (facing or 0) % 4
	local ud = UnitDefNames[name]
	local py = Spring.GetGroundHeight(x, z)
	local landed = false
	if ud.canFly then
		py, landed = airHeight(ud, x, z, y)
	end
	local id = Spring.CreateUnit(name, x, py, z, facing, team)
	if id then
		if ud.canFly then
			-- IDLEMODE: 0 = stay in the air, 1 = land
			Spring.GiveOrderToUnit(id, CMD.IDLEMODE, { landed and 1 or 0 }, 0)
		end
		Spring.GiveOrderToUnit(id, CMD.STOP, {}, 0)
		fillStockpile(id)
		record({ k = "add", id = id, name = name })
	else
		tell(playerID, "could not place " .. name .. " there")
	end
	return id
end

local function nearest(x, z, radius)
	local best, bd = nil, radius * radius
	for _, id in ipairs(Spring.GetAllUnits()) do
		local ux, _, uz = Spring.GetUnitPosition(id)
		local d = (ux - x) ^ 2 + (uz - z) ^ 2
		if d <= bd then
			best, bd = id, d
		end
	end
	return best
end

local function remove(x, z, radius)
	local id = nearest(x, z, radius or 64)
	if id then
		destroyRecorded(id, false)
	end
	return id
end

-- Create a random group: count pieces within radius around (x, z). techs = set of tech levels (nil = all),
-- faction = "arm" / "cor" / "leg" (nil = faction of the team). kind:
--   "units"     mobile land combat units
--   "buildings" buildings without weapons (economy, factories, radar, walls ...)
--   "turrets"   buildings with weapons (turrets, flak, rocket launchers ...)
--   "air"       air units (in the air, in flight mode)
--   "ships"     armed ships and submarines (water only)
local MAX_GENERATE = 2000
local BUCKET = 160 -- grid width for the spacing check (larger than the largest minimum spacing)
local function factionOfTeam(team)
	local _, _, _, _, side = Spring.GetTeamInfo(team)
	side = tostring(side or ""):lower()
	if side:find("cor") then
		return "cor"
	elseif side:find("leg") then
		return "leg"
	end
	return "arm"
end

local function generatePool(faction, techs, kind)
	local pool = {}
	for name, ud in pairs(UnitDefNames) do
		local cp = ud.customParams or {}
		if name:sub(1, 3) == faction and not name:find("scav") and not name:find("decom") and not name:find("dummy")
			and not name:find("drone") and not cp.iscommander and not cp.isdrone then
			local mc = ud.modCategories or {}
			local armed = #ud.weapons > 0
			local ok = false
			if kind == "units" then
				ok = ud.canMove and not ud.canFly and not ud.isBuilder and not ud.isFactory and ud.speed and ud.speed > 0
					and armed and not (mc.ship or mc.underwater)
			elseif kind == "buildings" then
				ok = ud.isBuilding and not armed
			elseif kind == "turrets" then
				ok = ud.isBuilding and armed
			elseif kind == "air" then
				ok = ud.canFly and not ud.isBuilder and ud.canMove
			elseif kind == "ships" then
				ok = ud.canMove and not ud.canFly and not ud.isBuilder and armed and (mc.ship or mc.underwater) and true or false
			end
			if ok then
				local tech = tonumber(cp.techlevel) or 1
				if not techs or techs[tech] then
					pool[#pool + 1] = ud
				end
			end
		end
	end
	table.sort(pool, function(a, b) return a.name < b.name end)
	return pool
end

local function generate(team, x, z, count, radius, techs, faction, kind, playerID, rect, neutral)
	kind = kind or "units"
	if not team or not Spring.GetTeamInfo(team) then
		tell(playerID, "unknown team: " .. tostring(team))
		return 0
	end
	count = math.min(math.floor(tonumber(count) or 0), MAX_GENERATE)
	radius = math.max(30, math.min(tonumber(radius) or 200, 3000))
	if count <= 0 then
		tell(playerID, "Count must be greater than 0")
		return 0
	end
	faction = faction or factionOfTeam(team)
	local pool = generatePool(faction, techs, kind)
	if #pool == 0 then
		tell(playerID, "no matching units (" .. kind .. ", faction " .. faction .. ")")
		return 0
	end
	local buckets, made, tries = {}, 0, 0
	while made < count and tries < count * 40 do
		tries = tries + 1
		local ud = pool[math.random(#pool)]
		local px, pz
		if rect then
			px, pz = rect[1] + math.random() * (rect[3] - rect[1]), rect[2] + math.random() * (rect[4] - rect[2])
		else
			local ang, r = math.random() * 2 * math.pi, radius * math.sqrt(math.random())
			px, pz = x + math.cos(ang) * r, z + math.sin(ang) * r
		end
		if px > 48 and pz > 48 and px < Game.mapSizeX - 48 and pz < Game.mapSizeZ - 48 then
			local py = Spring.GetGroundHeight(px, pz)
			local facing = math.random(0, 3)
			local ok = true
			local gap = math.max(ud.radius or 16, 16) * 1.6
			if kind == "units" or kind == "ships" then
				ok = Spring.TestMoveOrder(ud.id, px, py, pz, 0, 0, 0, true, false)
			elseif kind == "buildings" or kind == "turrets" then
				-- snap to the build grid and check whether building is allowed there (free, no water, no steep slopes)
				if Spring.Pos2BuildPos then
					px, py, pz = Spring.Pos2BuildPos(ud.id, px, py, pz, facing)
				end
				ok = Spring.TestBuildOrder(ud.id, px, py, pz, facing) >= 2 -- 0 = blocked, 1 = unit in the way, 2 = free
				gap = 0 -- the build spot check already knows existing buildings
			end
			if ok and gap > 0 then
				-- check only the neighboring cells (otherwise too slow with 1000 units)
				local bx, bz = math.floor(px / BUCKET), math.floor(pz / BUCKET)
				for i = bx - 1, bx + 1 do
					for j = bz - 1, bz + 1 do
						local cell = buckets[i * 100003 + j]
						if cell then
							for _, q in ipairs(cell) do
								local g = math.max(gap, q[3])
								if (q[1] - px) ^ 2 + (q[2] - pz) ^ 2 < g * g then
									ok = false
									break
								end
							end
						end
						if not ok then
							break
						end
					end
					if not ok then
						break
					end
				end
			end
			if ok then
				local id
				if kind == "air" then
					local ay = airHeight(ud, px, pz, nil)
					id = Spring.CreateUnit(ud.name, px, ay, pz, facing, team)
					if id then
						Spring.GiveOrderToUnit(id, CMD.IDLEMODE, { 0 }, 0)
					end
				else
					id = Spring.CreateUnit(ud.name, px, py, pz, facing, team)
				end
				if id then
					Spring.GiveOrderToUnit(id, CMD.STOP, {}, 0)
					if neutral then
						Spring.SetUnitNeutral(id, true)
					end
					fillStockpile(id)
					record({ k = "add", id = id, name = ud.name })
					local key = math.floor(px / BUCKET) * 100003 + math.floor(pz / BUCKET)
					buckets[key] = buckets[key] or {}
					table.insert(buckets[key], { px, pz, gap })
					made = made + 1
				end
			end
		end
	end
	if made < count then
		tell(playerID, string.format("%d of %d placed (not enough free space)", made, count))
	end
	return made
end

-- Assign units to another team (ids = "12,13,14"); returns the number of units changed
local function assignTeam(team, ids, playerID)
	if not team or not Spring.GetTeamInfo(team) then
		tell(playerID, "unknown team: " .. tostring(team))
		return 0
	end
	local n = 0
	for idStr in tostring(ids):gmatch("%d+") do
		local id = tonumber(idStr)
		if Spring.ValidUnitID(id) and Spring.GetUnitTeam(id) ~= team then
			local old = Spring.GetUnitTeam(id)
			local defID = Spring.GetUnitDefID(id)
			-- capture path (given=false): locks of other gadgets against gifts (no cheat mode) do not apply then
			Spring.TransferUnit(id, team, false)
			if Spring.GetUnitTeam(id) == team then
				n = n + 1
				record({ k = "team", id = id, name = UnitDefs[defID].name, old = old, new = team })
			end
		end
	end
	return n
end

-- Blow up the nearest unit/building at the mouse pointer: normal death with explosion, a wreck (scrap heap) remains
local function boom(x, z, radius)
	local id = nearest(x, z, radius or 80)
	if id then
		destroyRecorded(id, true)
	end
	return id
end

-- Delete or blow up several units at once (ids = "12,13,14"); boom = true: normal death with explosion and wreck
local function removeIds(ids, boom)
	local n = 0
	for idStr in tostring(ids):gmatch("%d+") do
		local id = tonumber(idStr)
		if Spring.ValidUnitID(id) then
			destroyRecorded(id, boom and true or false)
			n = n + 1
		end
	end
	return n
end

-- Features (wrecks, trees, rocks): create one by one and remove all
local function placeFeature(name, x, z, rot, playerID)
	if not FeatureDefNames[name] then
		return nil
	end
	local id = Spring.CreateFeature(name, x, Spring.GetGroundHeight(x, z), z, tonumber(rot) or 0)
	-- Wrecks ("<unit>_dead") should be resurrectable, even if they do not come from a dying unit
	local unit = id and name:match("^(.+)_dead$")
	if unit and UnitDefNames[unit] then
		Spring.SetFeatureResurrect(id, unit)
	end
	if id then
		record({ k = "fadd", fid = id, name = name })
	end
	return id
end

local function resetHistory()
	history, redoStack, current = {}, {}, nil
end

local function clearFeatures()
	resetHistory()
	local n = 0
	for _, fid in ipairs(Spring.GetAllFeatures()) do
		Spring.DestroyFeature(fid)
		n = n + 1
	end
	return n
end

-- Data of a unit with which it can be set up again
local function snapshot(id)
	local defID = Spring.GetUnitDefID(id)
	if not defID then
		return nil
	end
	local x, y, z = Spring.GetUnitPosition(id)
	return {
		name = UnitDefs[defID].name, team = Spring.GetUnitTeam(id), x = x, y = y, z = z,
		heading = Spring.GetUnitHeading(id), neutral = Spring.GetUnitNeutral(id),
	}
end

-- Convert the heading to the four directions, as the scenario gadget does too
local function headingToFacing(rot)
	rot = tonumber(rot) or 0
	if rot < 8192 and rot > -8192 then
		return 0
	end
	if rot > 8192 and rot < 24576 then
		return 1
	end
	if rot < -8192 and rot > -24576 then
		return 3
	end
	return 2
end

-- Remove all units, except the builder rows placed at the start
local function clearAll()
	local n = 0
	for _, id in ipairs(Spring.GetAllUnits()) do
		if Spring.GetUnitRulesParam(id, "ledbuilder") ~= 1 then
			Spring.DestroyUnit(id, false, true)
			n = n + 1
		end
	end
	resetHistory()
	return n
end

-- ---------------------------------------------------------------- History (undo / redo)
record = function(op)
	if suppress > 0 then
		return
	end
	local st
	if sticky and current then
		st = current
	else
		st = { ops = {} }
		history[#history + 1] = st
		if #history > HISTORY_MAX then
			table.remove(history, 1)
		end
		redoStack = {}
		if sticky then
			current = st
		end
	end
	st.ops[#st.ops + 1] = op
end

local function replaceId(old, new)
	if old == new then
		return
	end
	for _, list in ipairs({ history, redoStack, { inflight } }) do
		for _, st in ipairs(list) do
			for _, op in ipairs(st.ops) do
				if op.id == old then
					op.id = new
				end
			end
		end
	end
end

local function replaceFid(old, new)
	if old == new then
		return
	end
	for _, list in ipairs({ history, redoStack, { inflight } }) do
		for _, st in ipairs(list) do
			for _, op in ipairs(st.ops) do
				if op.fid == old then
					op.fid = new
				end
			end
		end
	end
end

-- The ID still belongs to a unit of this type (IDs are reused by the engine)
local function unitIs(id, name)
	if not id or not Spring.ValidUnitID(id) then
		return false
	end
	local defID = Spring.GetUnitDefID(id)
	return defID ~= nil and UnitDefs[defID].name == name
end

local function featureSnapshot(fid)
	local defID = Spring.GetFeatureDefID(fid)
	if not defID then
		return nil
	end
	local x, y, z = Spring.GetFeaturePosition(fid)
	return { name = FeatureDefs[defID].name, x = x, y = y, z = z, heading = Spring.GetFeatureHeading(fid) or 0 }
end

-- Create a unit or feature again from a snapshot, without recording anything
local function respawn(snap)
	suppress = suppress + 1
	local id = place(snap.name, snap.team, snap.x, snap.z, headingToFacing(snap.heading), nil, snap.y)
	suppress = suppress - 1
	if id and snap.neutral then
		Spring.SetUnitNeutral(id, true)
	end
	return id
end

local function respawnFeature(snap)
	suppress = suppress + 1
	local fid = placeFeature(snap.name, snap.x, snap.z, snap.heading)
	suppress = suppress - 1
	return fid
end

-- Delete a unit (boom = false) or blow it up (boom = true, a wreck remains) and note it in the history
destroyRecorded = function(id, boom)
	local snap = snapshot(id)
	if not snap then
		return
	end
	local wrecks
	if boom then
		capture = {}
	end
	Spring.DestroyUnit(id, false, not boom)
	if boom then
		wrecks, capture = capture, nil
	end
	record({ k = "del", id = id, name = snap.name, snap = snap, boom = boom, wrecks = wrecks })
end

function gadget:FeatureCreated(featureID)
	if capture then
		capture[#capture + 1] = featureID
	end
end

local function revert(op)
	local k = op.k
	if k == "add" then
		if unitIs(op.id, op.name) then
			op.snap = snapshot(op.id)
			Spring.DestroyUnit(op.id, false, true)
		end
	elseif k == "del" then
		local nid = respawn(op.snap)
		if nid then
			replaceId(op.id, nid)
			op.id = nid
		end
		for _, fid in ipairs(op.wrecks or {}) do
			if Spring.ValidFeatureID(fid) then
				Spring.DestroyFeature(fid)
			end
		end
		op.wrecks = nil
	elseif k == "swap" then
		if unitIs(op.id, op.name) then
			Spring.DestroyUnit(op.id, false, true)
		end
		local nid = respawn(op.before)
		if nid then
			replaceId(op.id, nid)
			op.id = nid
		end
	elseif k == "team" then
		if unitIs(op.id, op.name) then
			Spring.TransferUnit(op.id, op.old, false)
		end
	elseif k == "fadd" then
		if Spring.ValidFeatureID(op.fid) then
			op.snap = featureSnapshot(op.fid)
			Spring.DestroyFeature(op.fid)
		end
	elseif k == "fdel" then
		local nf = op.snap and respawnFeature(op.snap)
		if nf then
			replaceFid(op.fid, nf)
			op.fid = nf
		end
	end
end

local function apply(op)
	local k = op.k
	if k == "add" then
		local nid = op.snap and respawn(op.snap)
		if nid then
			replaceId(op.id, nid)
			op.id = nid
		end
	elseif k == "del" then
		if unitIs(op.id, op.name) then
			op.snap = snapshot(op.id)
			if op.boom then
				capture = {}
			end
			Spring.DestroyUnit(op.id, false, not op.boom)
			if op.boom then
				op.wrecks, capture = capture, nil
			end
		end
	elseif k == "swap" then
		if unitIs(op.id, op.name) then
			Spring.DestroyUnit(op.id, false, true)
		end
		local nid = respawn(op.after)
		if nid then
			replaceId(op.id, nid)
			op.id = nid
		end
	elseif k == "team" then
		if unitIs(op.id, op.name) then
			Spring.TransferUnit(op.id, op.new, false)
		end
	elseif k == "fadd" then
		local nf = op.snap and respawnFeature(op.snap)
		if nf then
			replaceFid(op.fid, nf)
			op.fid = nf
		end
	elseif k == "fdel" then
		if Spring.ValidFeatureID(op.fid) then
			op.snap = featureSnapshot(op.fid)
			Spring.DestroyFeature(op.fid)
		end
	end
end

-- Undo the last step
local function undo()
	local st = table.remove(history)
	if not st then
		return nil
	end
	if current == st then
		current = nil
	end
	inflight = st
	suppress = suppress + 1
	for i = #st.ops, 1, -1 do
		revert(st.ops[i])
	end
	suppress = suppress - 1
	inflight = nil
	redoStack[#redoStack + 1] = st
	return true
end

-- Redo the step undone last
local function redo()
	local st = table.remove(redoStack)
	if not st then
		return nil
	end
	inflight = st
	suppress = suppress + 1
	for i = 1, #st.ops do
		apply(st.ops[i])
	end
	suppress = suppress - 1
	inflight = nil
	history[#history + 1] = st
	return true
end

-- Provide new unit IDs for the widget (game rules parameter, readable by everyone)
local newIdsCounter = 0
local function publishIds(ids)
	newIdsCounter = newIdsCounter + 1
	Spring.SetGameRulesParam("led_newids", table.concat(ids, ","))
	Spring.SetGameRulesParam("led_newids_n", newIdsCounter)
end

local function parseIds(str)
	local ids = {}
	for idStr in tostring(str):gmatch("%d+") do
		local id = tonumber(idStr)
		if Spring.ValidUnitID(id) then
			ids[#ids + 1] = id
		end
	end
	return ids
end

-- Move, rotate or mirror units: they are set up again (the blocking of buildings stays correct),
-- team, neutral flag and height stay. mode: "move" (dx, dz), "l"/"r" (90 degrees around the center), "m" (mirror left-right).
local function transformUnits(ids, mode, dx, dz)
	local list = {}
	local minX, maxX, minZ, maxZ
	for _, id in ipairs(ids) do
		local r = snapshot(id)
		if r then
			r.old = id
			list[#list + 1] = r
			minX, maxX = math.min(minX or r.x, r.x), math.max(maxX or r.x, r.x)
			minZ, maxZ = math.min(minZ or r.z, r.z), math.max(maxZ or r.z, r.z)
		end
	end
	if #list == 0 then
		return {}
	end
	local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
	local made = {}
	for _, r in ipairs(list) do
		local f = headingToFacing(r.heading)
		local nx, nz = r.x, r.z
		if mode == "move" then
			nx, nz = r.x + (dx or 0), r.z + (dz or 0)
		elseif mode == "r" or mode == "l" then
			local k = (mode == "r") and 1 or 3
			local ox, oz = r.x - cx, r.z - cz
			for _ = 1, k do
				ox, oz = oz, -ox
			end
			nx, nz = cx + ox, cz + oz
			f = (f + k) % 4
		elseif mode == "m" then
			nx = cx - (r.x - cx)
			if f == 1 then
				f = 3
			elseif f == 3 then
				f = 1
			end
		end
		Spring.DestroyUnit(r.old, false, true)
		suppress = suppress + 1
		local id = place(r.name, r.team, nx, nz, f, nil, r.y)
		suppress = suppress - 1
		if id then
			if r.neutral then
				Spring.SetUnitNeutral(id, true)
			end
			replaceId(r.old, id) -- earlier steps should hit the new unit
			record({ k = "swap", id = id, name = r.name, before = r, after = snapshot(id) })
			made[#made + 1] = id
		end
	end
	publishIds(made)
	return made
end

-- rec = true: note in the history (blueprint, paste); otherwise (loading a level) not
local function loadUnit(name, team, x, z, heading, neutral, playerID, y, rec)
	if not rec then
		suppress = suppress + 1
	end
	local id = place(name, team, x, z, headingToFacing(heading), playerID, y)
	if not rec then
		suppress = suppress - 1
	end
	if id and neutral then
		Spring.SetUnitNeutral(id, true)
	end
	return id
end

-- Deletes the given units and features (wrecks, trees, rocks) and notes everything in the history (one step)
local function clearThese(units, features, playerID)
	local nu, nf = 0, 0
	for _, id in ipairs(units) do
		destroyRecorded(id, false)
		nu = nu + 1
	end
	for _, fid in ipairs(features) do
		local snap = featureSnapshot(fid)
		Spring.DestroyFeature(fid)
		if snap then
			record({ k = "fdel", fid = fid, name = snap.name, snap = snap })
		end
		nf = nf + 1
	end
	tell(playerID, nu .. " units and " .. nf .. " features deleted")
end

function gadget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 4) ~= "led|" then
		return
	end
	if not (Spring.IsCheatingEnabled() or EDITOR_MODE) then
		tell(playerID, "Cheat mode is off: please type /cheat")
		return true
	end
	local parts = {}
	for p in msg:gmatch("[^|]+") do
		parts[#parts + 1] = p
	end
	local cmd = parts[2]
	if cmd == "place" then
		local id = place(parts[3], tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6]), tonumber(parts[7]) or 0, playerID)
		if id and parts[8] == "1" then
			Spring.SetUnitNeutral(id, true)
		end
	elseif cmd == "delete" then
		-- first the nearest unit; if there is none, the nearest wreck or feature in range
		local dx, dz, dr = tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5])
		if not remove(dx, dz, dr) then
			local best, bd
			if dx and dz then
				for _, fid in ipairs(Spring.GetAllFeatures()) do
					local fx, _, fz = Spring.GetFeaturePosition(fid)
					local d = (fx - dx) ^ 2 + (fz - dz) ^ 2
					if d <= (dr or 64) ^ 2 and (not bd or d < bd) then
						best, bd = fid, d
					end
				end
			end
			if best then
				local snap = featureSnapshot(best)
				Spring.DestroyFeature(best)
				if snap then
					record({ k = "fdel", fid = best, name = snap.name, snap = snap })
				end
			else
				tell(playerID, "nothing nearby")
			end
		end
	elseif cmd == "clearrect" then
		-- led|clearrect|x1|z1|x2|z2: delete all units and features (wrecks, trees, rocks) in the rectangle, note in the history
		local x1, z1, x2, z2 = tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6])
		if x1 and z1 and x2 and z2 then
			clearThese(Spring.GetUnitsInRectangle(x1, z1, x2, z2), Spring.GetFeaturesInRectangle(x1, z1, x2, z2), playerID)
		end
	elseif cmd == "clearcircle" then
		-- led|clearcircle|x|z|radius: the same for a circle
		local x, z, r = tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5])
		if x and z and r then
			clearThese(Spring.GetUnitsInCylinder(x, z, r), Spring.GetFeaturesInCylinder(x, z, r), playerID)
		end
	elseif cmd == "clearline" then
		-- led|clearline|x1|z1|x2|z2|halfwidth: the same for a corridor along the line from (x1, z1) to (x2, z2)
		local x1, z1, x2, z2, hw = tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6]), tonumber(parts[7])
		if x1 and z1 and x2 and z2 and hw then
			local dx, dz = x2 - x1, z2 - z1
			local len2 = dx * dx + dz * dz
			local function near(x, z)
				local t = 0
				if len2 > 0 then
					t = math.max(0, math.min(1, ((x - x1) * dx + (z - z1) * dz) / len2))
				end
				local px, pz = x1 + dx * t, z1 + dz * t
				return (x - px) ^ 2 + (z - pz) ^ 2 <= hw * hw
			end
			local ax, bx = math.min(x1, x2) - hw, math.max(x1, x2) + hw
			local az, bz = math.min(z1, z2) - hw, math.max(z1, z2) + hw
			local units, features = {}, {}
			for _, id in ipairs(Spring.GetUnitsInRectangle(ax, az, bx, bz)) do
				local x, _, z = Spring.GetUnitPosition(id)
				if x and near(x, z) then
					units[#units + 1] = id
				end
			end
			for _, fid in ipairs(Spring.GetFeaturesInRectangle(ax, az, bx, bz)) do
				local x, _, z = Spring.GetFeaturePosition(fid)
				if x and near(x, z) then
					features[#features + 1] = fid
				end
			end
			clearThese(units, features, playerID)
		end
	elseif cmd == "clear" then
		clearAll()
	elseif cmd == "load" then
		loadUnit(parts[3], tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6]), tonumber(parts[7]), parts[8] == "1", playerID, tonumber(parts[9]), parts[10] == "1")
	elseif cmd == "deleteids" then
		removeIds(parts[3] or "", false)
	elseif cmd == "boomids" then
		removeIds(parts[3] or "", true)
	elseif cmd == "generaterect" then
		-- led|generaterect|team|x1|z1|x2|z2|count|techs|faction|kind|neutral   (like generate, but evenly in the rectangle)
		local techs
		if parts[9] and parts[9] ~= "-" then
			techs = {}
			for t in parts[9]:gmatch("%d+") do
				techs[tonumber(t)] = true
			end
		end
		local rect = { tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6]), tonumber(parts[7]) }
		if rect[1] and rect[2] and rect[3] and rect[4] then
			local made = generate(tonumber(parts[3]), nil, nil, tonumber(parts[8]), nil, techs, (parts[10] ~= "-" and parts[10]) or nil, parts[11] or "units",
				playerID, rect, parts[12] == "1")
			tell(playerID, made .. " created")
		end
	elseif cmd == "generate" then
		-- led|generate|team|x|z|count|radius|techs|faction|kind[|neutral]   (techs: "1,2" or "-" = all; faction: "arm"/"cor"/"leg" or "-")
		local techs
		if parts[8] and parts[8] ~= "-" then
			techs = {}
			for t in parts[8]:gmatch("%d+") do
				techs[tonumber(t)] = true
			end
		end
		local made = generate(tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6]), tonumber(parts[7]),
			techs, (parts[9] ~= "-" and parts[9]) or nil, parts[10] or "units", playerID, nil, parts[11] == "1")
		tell(playerID, made .. " created")
	elseif cmd == "builders" then
		if GG.LevelEditorSpawnBuilders and parts[3] and parts[4] then
			GG.LevelEditorSpawnBuilders(tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5]) or 0)
		end
	elseif cmd == "feature" then
		placeFeature(parts[3], tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6]), playerID)
	elseif cmd == "loadfeature" then
		-- Loading a level: do not note in the history
		suppress = suppress + 1
		placeFeature(parts[3], tonumber(parts[4]), tonumber(parts[5]), tonumber(parts[6]), playerID)
		suppress = suppress - 1
	elseif cmd == "step" then
		-- new action of the user: everything up to the next "step" belongs to one step (undo takes it back as a whole)
		current = nil
		sticky = true
	elseif cmd == "clearfeatures" then
		clearFeatures()
	elseif cmd == "assign" then
		local moved = assignTeam(tonumber(parts[3]), parts[4] or "", playerID)
		tell(playerID, moved .. " units changed team")
	elseif cmd == "boom" then
		if not boom(tonumber(parts[3]), tonumber(parts[4]), tonumber(parts[5])) then
			tell(playerID, "no unit nearby")
		end
	elseif cmd == "move" then
		-- led|move|dx|dz|ids
		transformUnits(parseIds(parts[5] or ""), "move", tonumber(parts[3]) or 0, tonumber(parts[4]) or 0)
	elseif cmd == "xform" then
		-- led|xform|l|r|m|ids
		local mode = parts[3]
		if mode == "l" or mode == "r" or mode == "m" then
			transformUnits(parseIds(parts[4] or ""), mode)
		end
	elseif cmd == "redo" then
		local any = false
		for _ = 1, math.max(1, math.min(1000, tonumber(parts[3]) or 1)) do
			if redo() then
				any = true
			end
		end
		if not any then
			tell(playerID, "nothing to redo")
		end
	elseif cmd == "undo" then
		-- led|undo|N undoes the last N steps (one step = one action, e.g. a whole row)
		local any = false
		for _ = 1, math.max(1, math.min(1000, tonumber(parts[3]) or 1)) do
			if undo() then
				any = true
			end
		end
		if not any then
			tell(playerID, "nothing to undo")
		end
	end
	return true
end

function gadget:Initialize()
	GG.LevelEditor = {
		place = place, remove = remove, undo = undo, clear = clearAll, load = loadUnit, boom = boom, assign = assignTeam, removeIds = removeIds, generate = generate, feature = placeFeature, clearFeatures = clearFeatures,
		recv = function(msg, playerID) return gadget:RecvLuaMsg(msg, playerID) end, -- for tests
	}
end

function gadget:Shutdown()
	GG.LevelEditor = nil
end

-- Build mode for the editor: only active with the game option leveleditor=1 (set by start_level_editor.bat).
-- Builders build practically instantly, the resources are always full, so nothing costs anything.
if EDITOR_MODE then
	local BIG = 1e6

	function gadget:UnitCreated(unitID, unitDefID, teamID, builderID)
		local ud = UnitDefs[unitDefID]
		if ud and ud.buildSpeed and ud.buildSpeed > 0 then
			Spring.SetUnitBuildSpeed(unitID, BIG, BIG, BIG, BIG)
		end
		-- Resurrected units (the builder is executing the RESURRECT command) stay put: Hold Position
		if builderID and CMD.RESURRECT and Spring.GetUnitCurrentCommand(builderID) == CMD.RESURRECT then
			Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
		end
	end

	-- At the start, all mobile builders of every faction in groups next to the commander of team 0:
	-- one block per faction, in it one row per kind (bot, vehicle, hover, air), T1 left, T2 right.
	local FACTION_PREFIX = { { "arm", "ARMADA" }, { "cor", "CORTEX" }, { "leg", "LEGION" } }
	local KINDS = { "bot", "vehicle", "hover", "air" }

	local function builderKind(ud)
		local mc = ud.modCategories or {}
		if mc.ship or mc.underwater then
			return nil -- Ships and submarines need water
		end
		if ud.canFly then
			return "air"
		end
		-- the movement class tells them apart (bot2, tank3, hover2 ...); the categories "bot" and "hover" do not exist in BAR
		local move = ud.moveDef and ud.moveDef.name or ""
		if mc.hover or move:find("hover") then
			return "hover"
		end
		if mc.bot or move:find("bot") then
			return "bot"
		end
		return "vehicle"
	end

	-- Reachability: grid around the commander, cells count when TestMoveOrder fits the movement type
	-- and the cell is connected to the commander through neighboring cells (flood fill, 8 neighbors).
	local STEP = 32
	local RADIUS = 1600
	local DIRS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 }, { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }

	local function reachableCells(defID, sx, sz)
		local maxI = math.floor(RADIUS / STEP)
		local seen, cells, queue, head = {}, {}, {}, 1
		local function key(i, j) return i * 4096 + j end
		local function passable(i, j)
			local x, z = sx + i * STEP, sz + j * STEP
			if x < 16 or z < 16 or x > Game.mapSizeX - 16 or z > Game.mapSizeZ - 16 then
				return false
			end
			return Spring.TestMoveOrder(defID, x, Spring.GetGroundHeight(x, z), z, 0, 0, 0, true, false)
		end
		seen[key(0, 0)] = true
		queue[1] = { 0, 0 }
		cells[1] = { sx, sz } -- The start cell always counts (the commander stands there)
		while head <= #queue do
			local c = queue[head]
			head = head + 1
			for _, d in ipairs(DIRS) do
				local i, j = c[1] + d[1], c[2] + d[2]
				if math.abs(i) <= maxI and math.abs(j) <= maxI and not seen[key(i, j)] then
					seen[key(i, j)] = true
					if passable(i, j) then
						queue[#queue + 1] = { i, j }
						cells[#cells + 1] = { sx + i * STEP, sz + j * STEP }
					end
				end
			end
		end
		return cells
	end

	-- ox/oz set (Ctrl+Alt+B): builders of all factions around this point for team teamArg, otherwise at the start next to the commander
	local function spawnBuilders(ox, oz, teamArg)
		local cx, cz
		if ox then
			cx, cz = ox, oz
		else
			local com
			for _, id in ipairs(Spring.GetTeamUnits(0)) do
				com = com or id
			end
			if not com then
				return
			end
			local _
			cx, _, cz = Spring.GetUnitPosition(com)
		end
		teamArg = teamArg or 0
		local total, missing = 0, 0
		local placed = {} -- positions already taken, so units do not overlap
		local reachCache = {} -- movement type -> reachable cells

		local function cellsFor(ud)
			if ud.canFly then
				return cellsFor(UnitDefNames["armck"] or ud) -- Air units: the land cells of the bots are enough (the air is free)
			end
			local mdName = ud.moveDef and ud.moveDef.name or "none"
			if not reachCache[mdName] then
				reachCache[mdName] = reachableCells(ud.id, cx, cz)
			end
			return reachCache[mdName]
		end

		local function free(x, z)
			for _, p in ipairs(placed) do
				if (p[1] - x) ^ 2 + (p[2] - z) ^ 2 < 52 * 52 then
					return false
				end
			end
			return true
		end

		for fi, f in ipairs(FACTION_PREFIX) do
			local prefix, label = f[1], f[2]
			local rows = { bot = {}, vehicle = {}, hover = {}, air = {} }
			for name, ud in pairs(UnitDefNames) do
				local cp = ud.customParams or {}
				if name:sub(1, 3) == prefix and not name:find("scav") and not name:find("decom") and not name:find("assistdrone")
					and ud.isBuilder and ud.canMove and #ud.buildOptions > 0 and not ud.isFactory
					and not cp.iscommander and not cp.isdrone then
					local kind = builderKind(ud)
					if kind then
						local list = rows[kind]
						list[#list + 1] = { name = name, tech = tonumber(cp.techlevel) or 1, ud = ud }
					end
				end
			end
			local anchorX, anchorZ = cx + 220, cz + (fi - 2) * 420
			local sumX, sumZ, n = 0, 0, 0
			for ki, kind in ipairs(KINDS) do
				local list = rows[kind]
				table.sort(list, function(a, b)
					if a.tech ~= b.tech then
						return a.tech < b.tech
					end
					return a.name < b.name
				end)
				-- every kind gets its own anchor, so the groups lie side by side
				local ax, az = anchorX, anchorZ + (ki - 2.5) * 90
				local sortedFor = {}
				for _, u in ipairs(list) do
					local cells = cellsFor(u.ud)
					local sorted = sortedFor[cells]
					if not sorted then
						sorted = {}
						for i, c in ipairs(cells) do
							sorted[i] = c
						end
						table.sort(sorted, function(p, q)
							return (p[1] - ax) ^ 2 + (p[2] - az) ^ 2 < (q[1] - ax) ^ 2 + (q[2] - az) ^ 2
						end)
						sortedFor[cells] = sorted
					end
					local spot
					for _, c in ipairs(sorted) do
						if free(c[1], c[2]) then
							spot = c
							break
						end
					end
					if spot then
						local bid = Spring.CreateUnit(u.name, spot[1], Spring.GetGroundHeight(spot[1], spot[2]), spot[2], 3, teamArg)
						if bid then
							Spring.SetUnitRulesParam(bid, "ledbuilder", 1, { public = true })
							placed[#placed + 1] = { spot[1], spot[2] }
							sumX, sumZ, n = sumX + spot[1], sumZ + spot[2], n + 1
							total = total + 1
						end
					else
						missing = missing + 1
					end
				end
			end
			if n > 0 and not ox then
				local mx, mz = sumX / n, sumZ / n
				SendToUnsynced("led_marker", mx, Spring.GetGroundHeight(mx, mz), mz, label)
			end
		end
		Spring.Echo("[Level Editor] " .. total .. " builders placed (reachable spots)" .. (missing > 0 and (", " .. missing .. " without a reachable spot") or ""))
	end

	GG.LevelEditorSpawnBuilders = spawnBuilders

	function gadget:GameFrame(n)
		if #pendingStockpile > 0 then
			fillPendingStockpiles()
		end
		if n == 5 then
			-- full vision for everyone: this way the widget sees all units when saving (no /globallos needed)
			for _, at in ipairs(Spring.GetAllyTeamList()) do
				Spring.SetGlobalLos(at, true)
			end
		end
		if n % 15 ~= 0 then
			return
		end
		for _, t in ipairs(Spring.GetTeamList()) do
			Spring.SetTeamResource(t, "ms", 1e9)
			Spring.SetTeamResource(t, "es", 1e10)
			Spring.SetTeamResource(t, "m", 1e9)
			Spring.SetTeamResource(t, "e", 1e10)
		end
	end
end
