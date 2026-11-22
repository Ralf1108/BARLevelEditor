function widget:GetInfo() return { name = "zz ren60", desc = "test only: which missiles count as arc weapons (R.lobbed)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren60.lua: R.lobbed (direct or indirect) for some missile weapons ("[zzren60]").
local function log(...) Spring.Echo("[zzren60] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	local R = WG.renegade
	if not R or f ~= 60 then return end
	for _, spec in ipairs({ "corkarg#1", "corkarg#2", "armrock#1", "corstorm#1", "armjanus#1", "corban#1", "armmerl#1", "corvroc#1", "armbanth#3", "cortron#1", "armsilo#1", "armmship#2", "armmart#1", "armbull#1", "armpw#1", "armamd#1" }) do
		local name, i = spec:match("^(%w+)#(%d+)$")
		local ud = UnitDefNames[name]
		local wp = ud and ud.weapons[tonumber(i)]
		local wd = wp and WeaponDefs[wp.weaponDef]
		if wd then log(spec, wd.type, "arc", tostring(R.lobbed(wd))) end
	end
	Spring.SendCommands("quitforce")
end
