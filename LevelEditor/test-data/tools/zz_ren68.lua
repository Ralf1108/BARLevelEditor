function widget:GetInfo() return { name = "zz ren68", desc = "test only: the firing cones of the Exploiters", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren68.lua: mainDir and maxAngleDif (the cosine of the firing cone) of the weapons of the extractors with weapons ("[zzren68]").
local function log(...) Spring.Echo("[zzren68] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f ~= 60 then return end
	for _, n in ipairs({ "cormexp", "corexp", "armamex", "legmex" , "legmext15", "armmmkr" }) do
		local ud = UnitDefNames[n]
		if ud then
			for i, wp in ipairs(ud.weapons) do
				local wd = WeaponDefs[wp.weaponDef]
				log(n .. "#" .. i, wd.name, "cos", tostring(wp.maxAngleDif), "mainDir", tostring(wp.mainDirX), tostring(wp.mainDirY), tostring(wp.mainDirZ), "range", tostring(wd.range), "type", wd.type, "onlyTargets", (function() local t = {} for k in pairs(wp.onlyTargets or {}) do t[#t + 1] = k end return table.concat(t, ",") end)())
			end
		end
	end
	Spring.SendCommands("quitforce")
end
