-- The level file of the Level Editor: saving (LevelEditor/<name>.lua: units, features, the sections of the pages, the scenario block), loading (units and
-- features through a queue, a few per update) and clearing the map. Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_level.lua")) as a function
-- that gets the host (the services of the widget) and returns the functions; a file of its own because the widget is close to the limit of 200 local variables.
--   host.Shared, host.OUTDIR (folder of the levels), host.say(text), host.editAllowed(), host.cfg() (settings: the unit limit), host.pages() (the pages:
--   si, td, ctf, rtf, ar, tm, rst, sv; created after this module), host.setCurrentLevel(name) (the level loaded or saved last)
-- Returns lv: lv.save(name, quiet) (count of the units or nil), lv.load(_, _, args) (the action /led_load), lv.clear() (the action /led_clear), lv.parse(text),
-- lv.loading() (units or features still waiting), lv.loadStep(n) (sends the next n), lv.stopLoading()
return function(host)
	local Shared = host.Shared

	-- Scenario info (from the scenario maker): block "scenario = [==[ ... ]==]," in the level file. The editor does not
	-- touch it, but reads it before overwriting and writes it back unchanged.
	local keptScenario = nil -- Block of the level loaded last (also applies when saving under a new name)
	local function scenarioBlockOf(text)
		return text and text:match("\n(\tscenario = %[==%[.-%]==%],)[ \t\r]*\n") or nil
	end

	local Json = Json or VFS.Include("common/luaUtilities/json.lua")

	local function decodeBlock(block)
		local body = block and block:match("%[==%[(.*)%]==%]")
		if not body then
			return nil
		end
		local ok, data = pcall(Json.decode, body)
		if ok and type(data) == "table" then
			return data
		end
	end

	local function encodeBlock(data)
		local ok, body = pcall(Json.encode, data)
		if not ok or type(body) ~= "string" then
			return nil
		end
		return "\tscenario = [==[" .. (body:gsub("%]==%]", "] ==]")) .. "]==],"
	end

	-- Writes the level (units and features) to LevelEditor/<name>.lua. quiet = no chat message (autosave).
	-- Returns the number of saved units (nil on error).
	local function saveLevel(name, quiet)
		local gaia = Spring.GetGaiaTeamID()
		local lines, count = {}, 0
		local scavOrRaptor = false -- a Scavenger or Raptor unit: the level needs the game option forceallunits
		for _, id in ipairs(Spring.GetAllUnits()) do
			local t = Spring.GetUnitTeam(id)
			-- not part of the level: the builders of Ctrl+D (ledbuilder) and the units of a running game (led_nosave: waves, flags, collection points)
			if Spring.GetUnitRulesParam(id, "ledbuilder") ~= 1 and Spring.GetUnitRulesParam(id, "led_nosave") ~= 1 then
				local x, y, z = Spring.GetUnitPosition(id)
				local ud = UnitDefs[Spring.GetUnitDefID(id)]
				scavOrRaptor = scavOrRaptor or ud.name:sub(-5) == "_scav" or ud.name:sub(1, 7) == "raptor_"
				-- Gaia units additionally carry gaia = true (the Gaia number depends on the team count)
				lines[#lines + 1] = string.format(
					"\t\t{ name = '%s', x = %d, y = %d, z = %d, rot = %d, team = %d, neutral = %s%s%s%s },",
					ud.name, x, y, z, Spring.GetUnitHeading(id), t, tostring(Spring.GetUnitNeutral(id)),
					t == gaia and ", gaia = true" or "",
					Spring.GetUnitRulesParam(id, "indestructible") == 1 and ", indestructible = true" or "",
					Spring.GetUnitRulesParam(id, "arena") == 1 and ", arena = true" or ""
				)
				count = count + 1
			end
		end
		table.sort(lines)
		-- Features: wrecks, trees, rocks ...
		local flines = {}
		for _, fid in ipairs(Spring.GetAllFeatures()) do
			local fdef = FeatureDefs[Spring.GetFeatureDefID(fid)]
			local fx, fy, fz = Spring.GetFeaturePosition(fid)
			if fdef and fx then
				-- Wrecks that can be resurrected carry the unit (resurrectas)
				local res = Spring.GetFeatureResurrect(fid)
				flines[#flines + 1] = string.format("\t\t{ name = '%s', x = %d, y = %d, z = %d, rot = %d%s },",
					fdef.name, fx, fy, fz, Spring.GetFeatureHeading(fid) or 0,
					(type(res) == "string" and res ~= "") and (", resurrectas = '" .. res .. "'") or "")
			end
		end
		table.sort(flines)
		local P = host.pages()
		local si, td, ctf, rtf, ar, tm, rst = P.si, P.td, P.ctf, P.rtf, P.ar, P.tm, P.rst
		local block = si.dirty and si.data and encodeBlock(si.data) or nil
		if not block then
			local old = io.open(host.OUTDIR .. name .. ".lua", "r")
			if old then
				block = scenarioBlockOf("\n" .. old:read("*a") .. "\n")
				old:close()
			end
		end
		if not block and keptScenario then
			block = keptScenario
			if name:sub(1, 1) ~= "_" then
				-- a level of its own, made from another one (Save as new): title and ID of the other level would build its scenario into
				-- the folder of the other one, so they come from the name of this level
				local sc = decodeBlock(keptScenario)
				if sc then
					sc.title = (name:gsub("_", " "):gsub("^%l", string.upper))
					sc.sid = (name:lower():gsub("[^a-z0-9]", ""))
					block = encodeBlock(sc) or block
				end
			end
		end
		-- the whole text is built first and written in one go (Shared.writeFile: a temporary file that replaces the old one), so an error
		-- on the way never leaves a half written level
		local out = { "-- Level Editor: saved for scenariooptions.unitloadout and featureloadout\n" }
		local function w(s)
			out[#out + 1] = s
		end
		-- Game options that must be on in the main game so the placed units exist there
		local needed = {}
		local mo = Spring.GetModOptions()
		for _, key in ipairs({ "experimentallegionfaction", "experimentalextraunits", "releasecandidates" }) do
			local v = mo[key]
			if v == "1" or v == 1 or v == true then
				needed[#needed + 1] = key .. ' = "1"'
			end
		end
		-- Scavenger and Raptor units (the *_scav copies, raptor_*) exist only with forceallunits: the level asks for it only when it holds such a unit
		if scavOrRaptor then
			needed[#needed + 1] = 'forceallunits = "1"'
		end
		w(string.format("return {\n\tmap = %q,\n", Game.mapName))
		-- Map size in Elmo: the scenario builder needs it for the grace period (start boxes as a fraction of the map)
		w(string.format("\tmapsize = { %d, %d },\n", Game.mapSizeX or 0, Game.mapSizeZ or 0))
		w(string.format("\tunitlimit = %d,\n", host.cfg().v.unitLimit))
		if block then
			w(block .. "\n")
		end
		if td.data then
			w("\ttowerdefense = " .. td.lua(td.data, "\t") .. ",\n")
		end
		if ctf.data then
			w("\tcapture = " .. ctf.lua() .. ",\n")
		end
		if rtf.data then
			w("\treclaim = " .. rtf.lua() .. ",\n")
		end
		if ar.data then
			w("\tarena = " .. ar.lua() .. ",\n")
		end
		if tm.data then
			w("\tteams = " .. tm.lua() .. ",\n")
		end
		if not rst.empty() then
			w("\trestrictions = " .. rst.lua() .. ",\n")
		end
		w("\t-- to be enabled in the main game (game options), otherwise some units are missing:\n")
		w("\trequiredmodoptions = { " .. table.concat(needed, ", ") .. " },\n\tunitloadout = {\n")
		w(table.concat(lines, "\n"))
		w("\n\t},\n\tfeatureloadout = {\n")
		w(table.concat(flines, "\n"))
		w("\n\t},\n}\n")
		local ok, err = Shared.writeFile(host.OUTDIR .. name .. ".lua", table.concat(out))
		if not ok then
			if not quiet then
				host.say("Saving failed: " .. tostring(err))
			end
			return nil
		end
		if not quiet then
			host.say(string.format("%d units and %d features saved in %s%s.lua", count, #flines, host.OUTDIR, name))
			if name:sub(1, 1) ~= "_" then
				host.setCurrentLevel(name)
				P.sv.touch(name)
			end
			if count == 0 then
				host.say("Note: 0 units saved. Are all units visible?")
			end
		end
		return count
	end

	-- Load: reads LevelEditor/<name>.lua, clears the map (except the builder rows) and places the saved units
	-- in small packets per update, so nothing overflows with large levels.
	local loadQueue = {}
	local LOAD_PER_UPDATE = 50

	-- Reads the text of a level file and returns the table (or nil, error text); the file runs in an empty environment (Shared.loadData)
	local function parseLevel(text)
		local data, err = Shared.loadData(text)
		if type(data) ~= "table" or type(data.unitloadout) ~= "table" then
			return nil, err or "not a valid level file"
		end
		return data
	end

	-- A section of the level file reduced to the fields of the defaults (and the listed extra fields): nil when it is no table
	local function knownFields(t, defaults, extra)
		if type(t) ~= "table" then
			return nil
		end
		local out = {}
		for k, v in pairs(defaults) do
			if t[k] ~= nil then
				out[k] = t[k]
			else
				out[k] = v
			end
		end
		for _, k in ipairs(extra or {}) do
			out[k] = t[k]
		end
		return out
	end

	local function load_level(_, _, args)
		if not host.editAllowed() then
			return true
		end
		local P = host.pages()
		local si, td, ctf, rtf, ar, tm, rst = P.si, P.td, P.ctf, P.rtf, P.ar, P.tm, P.rst
		local name = ((args and args[1]) or "level"):gsub("[^%w_%-]", "_")
		local f = io.open(host.OUTDIR .. name .. ".lua", "r")
		if not f then
			host.say("Level not found: " .. host.OUTDIR .. name .. ".lua")
			return true
		end
		local text = f:read("*a")
		f:close()
		local data, err = parseLevel(text)
		keptScenario = scenarioBlockOf("\n" .. text .. "\n")
		si.data = decodeBlock(keptScenario)
		si.dirty = false
		host.setCurrentLevel(name)
		if name:sub(1, 1) ~= "_" then
			P.sv.touch(name)
		end
		if not data then
			host.say("Loading failed: " .. tostring(err))
			return true
		end
		-- own sections of the level file: only the fields the editor knows are taken over (nothing old is kept and saved again)
		td.data = knownFields(data.towerdefense, td.new(), { "spawn", "goal" })
		ctf.data = knownFields(data.capture, ctf.new())
		rtf.data = knownFields(data.reclaim, rtf.new())
		ar.data = knownFields(data.arena, ar.new(), { "point" })
		ar.fix()
		tm.load(data.teams)
		rst.load(data.restrictions)
		td.scroll = 0
		host.cfg().v.unitLimit = tonumber(data.unitlimit) or 32000 -- the unit limit belongs to the level (used by the scenario builder); not written into the settings
		host.cfg():sync()
		if data.map and data.map ~= Game.mapName then
			host.say("Warning: the level was saved on map " .. tostring(data.map) .. " but the current map is " .. Game.mapName)
		end
		Spring.SendLuaRulesMsg("led|clear")
		loadQueue = {}
		for _, u in ipairs(data.unitloadout) do
			loadQueue[#loadQueue + 1] = u
		end
		local nFeatures = 0
		-- Replace features only if the file contains any (old files without featureloadout leave the map unchanged)
		if type(data.featureloadout) == "table" then
			Spring.SendLuaRulesMsg("led|clearfeatures")
			for _, ft in ipairs(data.featureloadout) do
				loadQueue[#loadQueue + 1] = { feature = true, name = ft.name, x = ft.x, z = ft.z, rot = ft.rot }
				nFeatures = nFeatures + 1
			end
		end
		host.say(string.format("Loading %s: %d units, %d features ...", name, #data.unitloadout, nFeatures))
		return true
	end

	local function clear_all()
		if not host.editAllowed() then
			return true
		end
		loadQueue = {}
		Spring.SendLuaRulesMsg("led|clear")
		host.say("Map cleared (the builder rows stay)")
		return true
	end

	-- the next n waiting units and features to the gadget
	local function loadStep(n)
		for _ = 1, n do
			local u = table.remove(loadQueue, 1)
			if not u then
				break
			end
			if u.feature then
				Spring.SendLuaRulesMsg(string.format("led|loadfeature|%s|%d|%d|%d", tostring(u.name), tonumber(u.x) or 0, tonumber(u.z) or 0, tonumber(u.rot) or 0))
			else
				Spring.SendLuaRulesMsg(string.format("led|load|%s|%d|%d|%d|%d|%s|%d%s",
					tostring(u.name), u.gaia and Spring.GetGaiaTeamID() or tonumber(u.team) or 0, tonumber(u.x) or 0, tonumber(u.z) or 0, tonumber(u.rot) or 0,
					(u.neutral == true or u.neutral == "true") and "1" or "0", tonumber(u.y) or -1,
					(u.indestructible == true or u.arena == true) and string.format("|0|%d|%d", u.indestructible == true and 1 or 0, u.arena == true and 1 or 0) or ""))
			end
			if #loadQueue == 0 then
				host.say("Loading done.")
			end
		end
	end

	return {
		save = saveLevel, load = load_level, clear = clear_all, parse = parseLevel, PER_UPDATE = LOAD_PER_UPDATE, loadStep = loadStep,
		loading = function() return #loadQueue > 0 end,
		stopLoading = function() loadQueue = {} end,
	}
end
