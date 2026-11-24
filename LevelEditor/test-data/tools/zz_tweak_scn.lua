function widget:GetInfo() return { name = "zz tweak scenario", desc = "test only: a tweaked unit in a scenario game (game options ledtweaks / ledtweakunits)", layer = 1000000, enabled = true } end
-- Test widget of pve_test.ps1 -Tweaks -Quick -Widget zz_tweak_scn.lua: the game of the scenarios with the game options a scenario with a tweaked unit has
-- (a Pawn at 5200, 5900 with health 2000 and range 500). The widget gives two Pawns with /give, one at that place and one elsewhere, as a scenario would
-- have them at its start: the gadget unit_tweaks.lua must tweak the first one and leave the second one alone. Logs "[zzpve]" lines (OK / WRONG), ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzpve] " .. table.concat(t, " "))
end
local function ok(cond) return cond and "OK" or "WRONG" end
local function pawnAt(x, z)
	for _, id in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID()) or {}) do
		local ux, _, uz = Spring.GetUnitPosition(id)
		if UnitDefs[Spring.GetUnitDefID(id)].name == "armpw" and math.abs(ux - x) < 40 and math.abs(uz - z) < 40 then return id end
	end
end
local done = {}
function widget:GameFrame(f)
	if f >= 3 and not done.cheat then
		done.cheat = true
		Spring.SendCommands("cheat 1")
	end
	if f >= 10 and not done.give then
		done.give = true
		local team = Spring.GetMyTeamID()
		Spring.SendCommands("give 1 armpw " .. team .. " @5200,0,5900", "give 1 armpw " .. team .. " @5600,0,5900")
	end
	if f >= 110 and not done.check then
		done.check = true
		local a, b = pawnAt(5200, 5900), pawnAt(5600, 5900)
		log("the two Pawns exist:", tostring(a), tostring(b), ok(a ~= nil and b ~= nil))
		if a and b then
			local ha, hb = select(2, Spring.GetUnitHealth(a)), select(2, Spring.GetUnitHealth(b))
			log("the Pawn at the place of the scenario: health", ha, "id", tostring(Spring.GetUnitRulesParam(a, "ledtweak")), "name", tostring(Spring.GetUnitRulesParam(a, "ledtweakname")),
				ok(ha == 2000 and Spring.GetUnitRulesParam(a, "ledtweak") == "armpw_boss1" and Spring.GetUnitRulesParam(a, "ledtweakname") == "Boss Pawn"))
			log("its weapon range:", Spring.GetUnitWeaponState(a, 1, "range"), ok(math.abs(Spring.GetUnitWeaponState(a, 1, "range") - 500) < 1))
			log("the other Pawn is the normal one: health", hb, "range", Spring.GetUnitWeaponState(b, 1, "range"), ok(hb ~= 2000 and Spring.GetUnitRulesParam(b, "ledtweak") == nil))
		end
		log("END")
		Spring.SendCommands("quitforce")
	end
end
