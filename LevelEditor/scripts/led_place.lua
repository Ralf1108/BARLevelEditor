-- Placing in the Level Editor: what stands in the way of something placed (button W: written over or left out), units placed a moment ago, a blueprint
-- (or the clipboard) put down as one undo step, and copy / paste (Ctrl+C / Ctrl+V). Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_place.lua"))
-- as a function that gets the host (the services of the widget) and returns the functions; a file of its own because the widget is close to the limit of 200
-- local variables.
--   host.Shared, host.say(text), host.led(message), host.ledStep() (undo history of the editor gadget), host.queue(message) (the place queue: sent in packets),
--   host.team(), host.writeOn(), host.neutralOn() (buttons W and N), host.selectedUnits(), host.mouseOnMap(), host.editAllowed()
return function(host)
	local Shared = host.Shared

	-- Half width / depth (Elmo) of what is placed: footprint of a unit at a facing, radius of a feature; nil for aircraft (they fly over everything)
	local function halfSize(name, face, isFeature)
		if isFeature then
			local fd = FeatureDefNames[name]
			local rad = math.max(8, (fd and fd.radius) or 16)
			return rad, rad
		end
		local ud = UnitDefNames[name]
		if not ud or ud.canFly then
			return nil
		end
		local fx, fz = Shared.unitFootprint(ud, face)
		return fx / 2, fz / 2
	end

	local recentPlaced = {} -- { x, z, hx, hz, feature, t }: placed a moment ago, not a unit yet

	local function notePlaced(name, x, z, face, isFeature)
		local hx, hz = halfSize(name, face, isFeature)
		if hx then
			recentPlaced[#recentPlaced + 1] = { x = x, z = z, hx = hx, hz = hz, feature = isFeature or false, t = os.clock() }
		end
	end

	-- What stands in the way of a unit of this type at (x, z) (ground units and features overlapping its footprint) is added to found;
	-- things placed a moment ago (the same blueprint or stroke) are left alone
	local function collectBlockers(name, x, z, face, found, isFeature)
		local hx, hz = halfSize(name, face, isFeature)
		if not hx then
			return
		end
		local now = os.clock()
		local reach = 160
		for _, id in ipairs(Spring.GetUnitsInRectangle(x - hx - reach, z - hz - reach, x + hx + reach, z + hz + reach)) do
			local ud = UnitDefs[Spring.GetUnitDefID(id)]
			local ux, _, uz = Spring.GetUnitPosition(id)
			if ud and not ud.canFly and ux then
				local ufx, ufz = Shared.unitFootprint(ud, Shared.headingToFacing(Spring.GetUnitHeading(id) or 0))
				if math.abs(ux - x) < hx + ufx / 2 - 1 and math.abs(uz - z) < hz + ufz / 2 - 1 then
					local mine = false
					for _, q in ipairs(recentPlaced) do
						if now - q.t < 2 and math.abs(q.x - ux) < 4 and math.abs(q.z - uz) < 4 then
							mine = true
						end
					end
					if not mine then
						found.units[id] = true
					end
				end
			end
		end
		for _, fid in ipairs(Spring.GetFeaturesInRectangle(x - hx - reach, z - hz - reach, x + hx + reach, z + hz + reach)) do
			local fdef = FeatureDefs[Spring.GetFeatureDefID(fid)]
			local fx, _, fz = Spring.GetFeaturePosition(fid)
			local rad = math.max(8, (fdef and fdef.radius) or 16)
			if fx and math.abs(fx - x) < hx + rad - 1 and math.abs(fz - z) < hz + rad - 1 then
				found.features[fid] = true
			end
		end
	end

	-- True when something is already there: the footprint would overlap another unit (also one placed a moment ago); a feature also
	-- overlaps other features. Units may stand on features (they crush them).
	local function blocked(name, x, z, face, isFeature)
		local hx, hz = halfSize(name, face, isFeature)
		if not hx then
			return false
		end
		local now = os.clock()
		for i = #recentPlaced, 1, -1 do
			local q = recentPlaced[i]
			if now - q.t > 2 then
				table.remove(recentPlaced, i)
			elseif (isFeature or not q.feature) and math.abs(q.x - x) < hx + q.hx - 1 and math.abs(q.z - z) < hz + q.hz - 1 then
				return true
			end
		end
		local reach = 160
		for _, id in ipairs(Spring.GetUnitsInRectangle(x - hx - reach, z - hz - reach, x + hx + reach, z + hz + reach)) do
			local ud = UnitDefs[Spring.GetUnitDefID(id)]
			if ud and not ud.canFly then
				local ux, _, uz = Spring.GetUnitPosition(id)
				local ufx, ufz = Shared.unitFootprint(ud, Shared.headingToFacing(Spring.GetUnitHeading(id) or 0))
				if ux and math.abs(ux - x) < hx + ufx / 2 - 1 and math.abs(uz - z) < hz + ufz / 2 - 1 then
					return true
				end
			end
		end
		if isFeature then
			for _, fid in ipairs(Spring.GetFeaturesInRectangle(x - hx - reach, z - hz - reach, x + hx + reach, z + hz + reach)) do
				local fdef = FeatureDefs[Spring.GetFeatureDefID(fid)]
				local fx, _, fz = Spring.GetFeaturePosition(fid)
				local rad = math.max(8, (fdef and fdef.radius) or 16)
				if fx and math.abs(fx - x) < hx + rad - 1 and math.abs(fz - z) < hz + rad - 1 then
					return true
				end
			end
		end
		return false
	end

	-- Makes room for something at (x, z): with W on what is in the way is deleted (true), with W off the spot must be free
	-- (false when it is occupied)
	local function makeRoom(name, x, z, face, isFeature)
		if not host.writeOn() then
			return not blocked(name, x, z, face, isFeature)
		end
		local found = { units = {}, features = {} }
		collectBlockers(name, x, z, face, found, isFeature)
		local ids = {}
		for id in pairs(found.units) do
			ids[#ids + 1] = "u" .. id
		end
		for fid in pairs(found.features) do
			ids[#ids + 1] = "f" .. fid
		end
		if #ids > 0 then
			host.led("led|clearids|" .. table.concat(ids, ",", 1, math.min(#ids, 100)))
		end
		return true
	end

	-- Deletes what collectBlockers found (the same undo step as the placing that follows)
	local function clearBlockers(found)
		local ids = {}
		for id in pairs(found.units) do
			ids[#ids + 1] = "u" .. id
		end
		for fid in pairs(found.features) do
			ids[#ids + 1] = "f" .. fid
		end
		for i = 1, #ids, 100 do
			host.led("led|clearids|" .. table.concat(ids, ",", i, math.min(#ids, i + 99)))
		end
	end

	-- Puts a blueprint unit list with center (cx, cz) into the load queue
	-- A blueprint (or the clipboard) is placed as one undo step; noStep = true for rows of several blueprints
	-- (there the step is already in front). The units go through the queue with the extra "1" (remember).
	local function placeBlueprintUnits(units, cx, cz, teamOverride, label, k, noStep)
		local n = 0
		k = k or 0
		if not noStep then
			host.ledStep()
		end
		local found = { units = {}, features = {} } -- W on: what stands in the way is deleted first
		local skip = {} -- W off: occupied spots are left out
		for i, u in ipairs(units) do
			local odx, odz = Shared.rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, k)
			local rot = ((tonumber(u.rot) or 0) + 16384 * k + 32768) % 65536 - 32768
			if host.writeOn() then
				collectBlockers(tostring(u.name), cx + odx, cz + odz, Shared.headingToFacing(rot), found)
			else
				skip[i] = blocked(tostring(u.name), cx + odx, cz + odz, Shared.headingToFacing(rot))
			end
		end
		clearBlockers(found)
		local skipped = 0
		for i, u in ipairs(units) do
			if skip[i] then
				skipped = skipped + 1
			else
				local odx, odz = Shared.rotateOffset(tonumber(u.dx) or 0, tonumber(u.dz) or 0, k)
				local x, z = cx + odx, cz + odz
				local rot = ((tonumber(u.rot) or 0) + 16384 * k + 32768) % 65536 - 32768
				notePlaced(tostring(u.name), x, z, Shared.headingToFacing(rot))
				local y = Spring.GetGroundHeight(x, z) + (tonumber(u.h) or 0)
				host.queue(string.format("led|load|%s|%d|%d|%d|%d|%s|%d|1%s", tostring(u.name), teamOverride or host.team(),
					math.floor(x + 0.5), math.floor(z + 0.5), math.floor(rot + 0.5), host.neutralOn() and "1" or "0", math.floor(y + 0.5),
					u.indestructible == true and "|1" or ""))
				n = n + 1
			end
		end
		host.say(string.format("Placing blueprint '%s': %d units%s%s", label, n, teamOverride and (" for team " .. teamOverride) or "",
			skipped > 0 and (" (" .. skipped .. " occupied spots left out, switch W on to write over them)") or ""))
	end

	-- Copy/paste: Ctrl+C remembers the selected units (without a selection the one at the mouse pointer),
	-- Ctrl+V sets them up again centered at the mouse pointer (with team, rotation and height)
	local clipboard = {}

	local function copyUnits()
		local ids = {}
		for _, id in ipairs(host.selectedUnits()) do
			ids[#ids + 1] = id
		end
		if #ids == 0 then
			local x, z = Shared.mouseGround()
			if x then
				local best, bestD = nil, 1e9
				for _, id in ipairs(Spring.GetUnitsInCylinder(x, z, 80)) do
					local ux, _, uz = Spring.GetUnitPosition(id)
					local d = (ux - x) ^ 2 + (uz - z) ^ 2
					if d < bestD and Spring.GetUnitTeam(id) ~= Spring.GetGaiaTeamID() then
						best, bestD = id, d
					end
				end
				if best then
					ids[1] = best
				end
			end
		end
		local list, minX, maxX, minZ, maxZ = {}, nil, nil, nil, nil
		for _, id in ipairs(ids) do
			local x, y, z = Spring.GetUnitPosition(id)
			local defID = Spring.GetUnitDefID(id)
			if x and defID then
				list[#list + 1] = { id = id, x = x, y = y, z = z, name = UnitDefs[defID].name }
				minX, maxX = math.min(minX or x, x), math.max(maxX or x, x)
				minZ, maxZ = math.min(minZ or z, z), math.max(maxZ or z, z)
			end
		end
		if #list == 0 then
			host.say("Nothing to copy: select units first or hold the mouse over a unit.")
			return true
		end
		local cx, cz = (minX + maxX) / 2, (minZ + maxZ) / 2
		clipboard = {}
		for _, u in ipairs(list) do
			clipboard[#clipboard + 1] = {
				name = u.name,
				dx = u.x - cx,
				dz = u.z - cz,
				h = u.y - Spring.GetGroundHeight(u.x, u.z),
				rot = Spring.GetUnitHeading(u.id),
				team = Spring.GetUnitTeam(u.id),
				neutral = Spring.GetUnitNeutral(u.id),
				indestructible = Spring.GetUnitRulesParam(u.id, "indestructible") == 1,
			}
		end
		host.say(string.format("%d units copied. Paste at the cursor with Ctrl+V.", #clipboard))
		return true
	end

	local function pasteUnits()
		if not host.editAllowed() then
			return true
		end
		if #clipboard == 0 then
			host.say("The clipboard is empty. Copy with Ctrl+C first.")
			return true
		end
		local cx, cz = host.mouseOnMap()
		if not cx then
			return true
		end
		placeBlueprintUnits(clipboard, cx, cz, nil, "Copy")
		return true
	end

	return { halfSize = halfSize, notePlaced = notePlaced, makeRoom = makeRoom, placeBlueprintUnits = placeBlueprintUnits, copyUnits = copyUnits, pasteUnits = pasteUnits }
end
