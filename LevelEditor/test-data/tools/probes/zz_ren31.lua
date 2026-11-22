function widget:GetInfo() return { name = "zz ren31", desc = "test only: height of fixed-wing aircraft in the normal game against their cruise altitude", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren31.lua: like zz_ren30 for armpeep (scout, cruise 180), armfig (fighter, 125) and armthund (bomber, 165): spawned as enemies (ren|spawn|,
-- they fight toward the player with the game's own orders); logs every 30 frames the height above the ground, the ground and the sea level. Lines "[zzren31]".
local function log(...) Spring.Echo("[zzren31] " .. table.concat({ ... }, " ")) end
local R
local NAMES = { "armpeep", "armfig", "armthund" }
local air = {}
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 180, 0 end
	if f == 100 then Spring.SendLuaRulesMsg("ren|unit|armbanth") end
	for k, n in ipairs(NAMES) do
		if f == 110 + k * 3 then Spring.SendLuaRulesMsg("ren|spawn|" .. n) end
	end
	if f >= 130 and f % 5 == 0 and f < 200 then
		for _, id in ipairs(Spring.GetTeamUnits(1)) do
			local n = UnitDefs[Spring.GetUnitDefID(id)].name
			if not air[n] and (n == "armpeep" or n == "armfig" or n == "armthund") then air[n] = id; log("found", n, UnitDefs[Spring.GetUnitDefID(id)].cruiseAltitude) end
		end
	end
	if f >= 135 and f % 30 == 0 and f <= 700 then
		for _, n in ipairs(NAMES) do
			local id = air[n]
			if id and Spring.ValidUnitID(id) then
				local x, y, z = Spring.GetUnitPosition(id)
				local g = Spring.GetGroundHeight(x, z)
				log("f", f, n, "above ground", string.format("%.0f", y - g), "ground", string.format("%.0f", g), "sea level", string.format("%.0f", y))
			end
		end
	end
	if f == 720 then Spring.SendCommands("quitforce") end
end
