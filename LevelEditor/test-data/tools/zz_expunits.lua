function widget:GetInfo() return { name = "zz expunits", desc = "test only: which Experimental Units the game has", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_expunits.lua [-ModOptions 'lanexpunits=0;']: logs "[zzexp]" lines: the game option lanexpunits, which of
-- the Experimental Units (lava_generator_defs.lua) exist and whether the builders still have them in their build lists; ends with quitforce.
local NAMES = { "armlavagen", "corlavagen", "leglavagen", "armlavacarrier", "corlavacarrier", "leglavacarrier", "armlavatruck", "armlavafork" }
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzexp] " .. table.concat(t, " "))
end
function widget:GameFrame(f)
	if f ~= 30 then return end
	local want = (Spring.GetModOptions() or {}).lanexpunits
	log("game option lanexpunits", tostring(want))
	local found = 0
	for _, n in ipairs(NAMES) do
		if UnitDefNames[n] then found = found + 1 end
	end
	local inLists = 0
	for _, b in ipairs({ "armck", "armcv", "armlab", "armvp", "corck" }) do
		for _, id in ipairs(UnitDefNames[b] and UnitDefNames[b].buildOptions or {}) do
			if UnitDefs[id].name:find("lava") then inLists = inLists + 1 end
		end
	end
	log("units found", found, "of", #NAMES, "in build lists", inLists, (want == "0") == (found == 0 and inLists == 0) and "OK" or "WRONG")
	log("done"); Spring.SendCommands("quitforce")
end
