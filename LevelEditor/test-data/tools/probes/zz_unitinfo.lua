function widget:GetInfo() return { name = "zz unitinfo", desc = "test only: facts of some unit definitions (movement, building flags)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Widget zz_unitinfo.lua (without -Quick: Legion must be loaded): "[zzunit]" logs canMove, speed, isBuilding, the movement class, the weapons and the custom parameters of some units.
local function log(...) Spring.Echo("[zzunit] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f ~= 40 then return end
	local ok, Shared = pcall(VFS.Include, "luaui/Include/editor_common.lua")
	if ok and Shared and Shared.unitGroup then
		for _, n in ipairs({ "leghive", "legfhive", "armllt", "armtarg", "armamb", "armpw", "armbull", "armsb", "armhaap", "legmex" }) do
			if UnitDefNames[n] then log("group of", n, "=", tostring(Shared.unitGroup(UnitDefNames[n]))) end
		end
	else
		log("editor_common not loaded", tostring(Shared))
	end
	for _, n in ipairs({ "leghive", "legfhive", "armllt", "armtarg", "armamb", "legctl", "legdtr", "armmercury" }) do
		local ud = UnitDefNames[n]
		if ud then
			local mv = ud.moveDef
			local cp = {}
			for k, v in pairs(ud.customParams or {}) do cp[#cp + 1] = k .. "=" .. tostring(v) end
			table.sort(cp)
			log(n, "canMove", tostring(ud.canMove), "speed", tostring(ud.speed), "isBuilding", tostring(ud.isBuilding), "isFactory", tostring(ud.isFactory), "moveDef", tostring(type(mv) == "table" and mv.name or ud.movementClass), "weapons", #ud.weapons, "canFly", tostring(ud.canFly), "isGroundUnit", tostring(ud.isGroundUnit), "cats", (function() local t = {} for k in pairs(ud.modCategories or {}) do t[#t + 1] = k end table.sort(t) return table.concat(t, ",") end)(), "custom", table.concat(cp, ","))
		else
			log(n, "not found")
		end
	end
	Spring.SendCommands("quitforce")
end
