function widget:GetInfo() return { name = "zz ren58", desc = "test only: air-only weapons and the flight of the missiles", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren58.lua: (1) every weapon whose unit definition says "only aircraft" (onlyTargets vtol, not surface) and how the old rule saw it,
-- (2) the missile weapons: trajectoryHeight, flight fields, grouped ("[zzren58]").
local function log(...) Spring.Echo("[zzren58] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f ~= 60 then return end
	local armor = (Game.armorTypes or {}).default or 0
	local vtol = (Game.armorTypes or {}).vtol or 14
	local missed, fine, shoulder, surfaceAA = {}, 0, {}, {}
	local fields = {}
	for _, ud in pairs(UnitDefs) do
		if not ud.name:find("_scav$") then
			for i, wp in ipairs(ud.weapons or {}) do
				local wd = WeaponDefs[wp.weaponDef]
				if wd and (tonumber(wd.range) or 0) > 0 and wd.type ~= "Shield" and (tonumber(wd.interceptor) or 0) == 0 then
					local d = tonumber(wd.damages and wd.damages[armor]) or 0
					local v = tonumber(wd.damages and wd.damages[vtol]) or 0
					if d > 2 or v > 2 then
						local desc = tostring(wd.description or ""):lower()
						local airTok = desc:find("[gas]2a") ~= nil and desc:find("[gas]2[gs]") == nil
						local old = (d <= 2 and v > d) or airTok
						local ot = wp.onlyTargets
						local airOnly = type(ot) == "table" and ot.vtol == true and ot.surface ~= true
						if airOnly and not old then missed[#missed + 1] = ud.name .. "#" .. i .. "(" .. wd.name .. ")" end
						if airOnly and old then fine = fine + 1 end
						if old and not airOnly then
							local keys = {}
							for k in pairs(ot or {}) do keys[#keys + 1] = k end
							surfaceAA[#surfaceAA + 1] = ud.name .. "#" .. i .. "[" .. table.concat(keys, ",") .. "]"
						end
						if tostring(wd.name):lower():find("shoulder") or tostring(wd.description):lower():find("shoulder") then shoulder[#shoulder + 1] = ud.name .. "#" .. i .. (airOnly and " airOnly" or " NOT airOnly") end
					end
				end
			end
		end
	end
	log("air only by onlyTargets and already seen as anti-air:", fine)
	log("air only by onlyTargets but MISSED by the old rule (" .. #missed .. "):", table.concat(missed, " "))
	log("old rule says anti-air but onlyTargets does not (" .. #surfaceAA .. "):", table.concat(surfaceAA, " "))
	log("shoulder weapons:", table.concat(shoulder, " "))
	Spring.SendCommands("quitforce")
end
