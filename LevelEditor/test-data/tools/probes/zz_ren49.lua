function widget:GetInfo() return { name = "zz ren49", desc = "test only: firing cone (mainDir, maxAngleDif) of the weapons", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren49.lua: logs mainDir and maxAngleDif of the weapons of a few units ("[zzren49]").
local function log(...) Spring.Echo("[zzren49] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f ~= 60 then return end
	for k, v in pairs(UnitDefNames["armmart"].weapons[1]) do log("key", tostring(k), tostring(v)) end
	for _, name in ipairs({ "armmart", "armpw", "armbull", "corban", "armfido", "armmav" }) do
		local ud = UnitDefNames[name]
		for i, wp in ipairs(ud and ud.weapons or {}) do
			local md = wp.mainDir
			local mdt = type(md) == "table" and ("{" .. tostring(md[1]) .. "," .. tostring(md[2]) .. "," .. tostring(md[3]) .. "}") or tostring(md)
			log(name, i, WeaponDefs[wp.weaponDef].name, "mainDir", mdt, "maxAngleDif", tostring(wp.maxAngleDif), "onlyTargetCats", tostring(wp.onlyTargets))
		end
	end
	Spring.SendCommands("quitforce")
end
