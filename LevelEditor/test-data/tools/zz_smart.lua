function widget:GetInfo() return { name = "zz smart", desc = "test only: units with smart weapon selection (priority / backup trajectory weapons)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Widget zz_smart.lua (without -Quick: Legion and the extra units are listed too): "[zzsmart]" lists every unit with customParams.weapons_smart_select and the numbers of its priority,
-- backup and trajectory checker weapons.
local function log(...) Spring.Echo("[zzsmart] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f ~= 40 then return end
	local n = 0
	for _, ud in pairs(UnitDefs) do
		if (ud.customParams or {}).weapons_smart_select and not ud.name:find("_scav$") then
			local pr, bk, ck = {}, {}, {}
			for i, wp in ipairs(ud.weapons) do
				local cp = WeaponDefs[wp.weaponDef].customParams or {}
				if cp.smart_priority then pr[#pr + 1] = i elseif cp.smart_backup then bk[#bk + 1] = i elseif cp.smart_trajectory_checker then ck[#ck + 1] = i end
			end
			n = n + 1
			log(ud.name, ud.translatedHumanName or "", "weapons", #ud.weapons, "priority", table.concat(pr, ","), "backup", table.concat(bk, ","), "checker", table.concat(ck, ","))
		end
	end
	log("units with smart weapon selection:", n)
	Spring.SendCommands("quitforce")
end
