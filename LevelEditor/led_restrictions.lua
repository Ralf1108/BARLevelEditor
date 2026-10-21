-- Restrictions of the level (what the player may not build) for the Level Editor: one list for the whole level, written by the Place menu and
-- by the Tower Defense page alike. Loaded by lvl_level_editor.lua (VFS.Include("luaui/Include/led_restrictions.lua")) as a function that gets
-- the host (host.serialize(table)) and returns the list; a file of its own because the widget is close to the limit of 200 local variables.
-- The data (rst.data) are saved in their own section restrictions of the level file: { banned = { "armllt", ... }, bannedTech = { 2, 3 } }.
-- The game itself enforces them in the gadget unit_restrictions.lua (message "rst|start|<payload>" at the start of a test, "rst|stop").
return function(host)
	local rst = { data = nil, set = {} }

	function rst.new()
		return { banned = {}, bannedTech = {} }
	end

	-- The stored data (from the level file) or nothing; the set of the banned names is rebuilt
	function rst.load(t)
		rst.data = type(t) == "table" and t or nil
		rst.set = {}
		if rst.data then
			rst.data.banned = type(rst.data.banned) == "table" and rst.data.banned or {}
			rst.data.bannedTech = type(rst.data.bannedTech) == "table" and rst.data.bannedTech or {}
			for _, n in ipairs(rst.data.banned) do
				rst.set[n] = true
			end
		end
	end

	-- Data to change (created when missing)
	local function write()
		if not rst.data then
			rst.data = rst.new()
		end
		return rst.data
	end

	function rst.empty()
		return not rst.data or (#rst.data.banned == 0 and #rst.data.bannedTech == 0)
	end

	function rst.lua()
		return host.serialize(rst.data)
	end

	function rst.isBanned(name)
		return rst.set[name] == true
	end

	-- Ban or allow a list of unit names (all of them)
	function rst.setBanned(names, on)
		local d = write()
		for _, n in ipairs(names) do
			rst.set[n] = on and true or nil
		end
		local list = {}
		for n in pairs(rst.set) do
			list[#list + 1] = n
		end
		table.sort(list)
		d.banned = list
	end

	function rst.toggle(name)
		rst.setBanned({ name }, not rst.isBanned(name))
	end

	-- true when the list is not empty and every unit of it is banned
	function rst.allBanned(names)
		if #names == 0 then
			return false
		end
		for _, n in ipairs(names) do
			if not rst.set[n] then
				return false
			end
		end
		return true
	end

	function rst.techBanned(t)
		if rst.data then
			for _, v in ipairs(rst.data.bannedTech) do
				if v == t then
					return true
				end
			end
		end
		return false
	end

	function rst.toggleTech(t)
		local d = write()
		for i, v in ipairs(d.bannedTech) do
			if v == t then
				table.remove(d.bannedTech, i)
				return
			end
		end
		d.bannedTech[#d.bannedTech + 1] = t
		table.sort(d.bannedTech)
	end

	-- The payload of the gadget: "name,name;1,3" ("-" for none)
	function rst.payload()
		local d = rst.data or rst.new()
		return (#d.banned > 0 and table.concat(d.banned, ",") or "-") .. ";" .. (#d.bannedTech > 0 and table.concat(d.bannedTech, ",") or "-")
	end

	-- At the start of a test: the gadget blocks the build orders; at its end the block is released
	function rst.start()
		Spring.SendLuaRulesMsg("rst|start|" .. rst.payload())
	end

	function rst.stop()
		Spring.SendLuaRulesMsg("rst|stop")
	end

	return rst
end
