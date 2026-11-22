function widget:GetInfo() return { name = "zz weapon dump", desc = "test only: every weapon of every Armada, Cortex and Legion unit", layer = 0, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -Widget zz_weapondump.lua: one line "[zzwep] ..." (fields separated by ;) per weapon of every unit of Armada, Cortex and Legion that has a
-- weapon: unit code; faction; human name; weapon number; weapon definition name; description; type; range; reload; default damage; anti-air (vtol) damage; projectiles; salvo;
-- can attack ground (1/0); water weapon (1/0); flags (paralyzer, stockpile, interceptor, commandfire, shield). Also one line "[zzwepkeys]" with the keys of a weapon definition.
-- Then the game ends (quitforce). Used by renegade_weapons.py to make the table of game-modes/renegade-weapons.md.
local done = false
local function b(v) return v and 1 or 0 end
function widget:GameFrame(f)
	if done or f < 30 then return end
	done = true
	local types = Game.armorTypes or {}
	local defIdx, vtolIdx = types.default or 0, types.vtol or 14
	local one
	for _, ud in pairs(UnitDefs) do
		local n = ud.name
		local fac = n:sub(1, 3)
		if (fac == "arm" or fac == "cor" or fac == "leg") and not n:find("scav") and not n:find("raptor") and #(ud.weapons or {}) > 0 then
			for i, wp in ipairs(ud.weapons) do
				local wd = WeaponDefs[wp.weaponDef]
				one = one or wd
				if wd then
					local flags = {}
					if wd.paralyzer then flags[#flags + 1] = "paralyzer" end
					if (tonumber(wd.stockpile) or 0) ~= 0 and wd.stockpile then flags[#flags + 1] = "stockpile" end
					if (tonumber(wd.interceptor) or 0) ~= 0 then flags[#flags + 1] = "interceptor" end
					if wd.commandfire then flags[#flags + 1] = "commandfire" end
					if wd.type == "Shield" then flags[#flags + 1] = "shield" end
					Spring.Echo(string.format("[zzwep] %s;%s;%s;%d;%s;%s;%s;%d;%.2f;%.0f;%.0f;%d;%d;%d;%d;%s", n, fac, (ud.translatedHumanName or ud.humanName or n):gsub(";", ","), i,
						tostring(wd.name), tostring(wd.description or ""):gsub(";", ","), tostring(wd.type), wd.range or 0, wd.reload or 0,
						wd.damages and wd.damages[defIdx] or 0, wd.damages and wd.damages[vtolIdx] or 0, wd.projectiles or 1, wd.salvoSize or 1,
						b(wd.canAttackGround ~= false), b(wd.waterWeapon), table.concat(flags, ",") .. ";" .. (ud.canFly and string.format("%.0f", ud.cruiseAltitude or 0) or "")))
				end
			end
		end
	end
	if one then
		local keys = {}
		for k in pairs(one) do keys[#keys + 1] = tostring(k) end
		table.sort(keys)
		Spring.Echo("[zzwepkeys] " .. table.concat(keys, " "))
	end
	Spring.Echo("[zzwep] done")
	Spring.SendCommands("quitforce")
end
