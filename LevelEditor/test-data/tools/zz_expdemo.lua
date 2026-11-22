function widget:GetInfo() return { name = "zz expdemo", desc = "test only: the test start of the Experimental Units (lanexpdemo=1)", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_expdemo.lua -ModOptions 'lanexpdemo=1;' (what start_experimental.bat starts): at frame 5 the gadget
-- lava_generator.lua places a Volcano with a Lava Extractor, a Carrier, a Cargo Truck, a Forklift and a vehicle plant for team 0. The widget checks
-- them, takes a picture from above, gives all three vehicles the order Haul and counts the metal brought. Logs "[zzdemo]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i = 1, select("#", ...) do t[i] = tostring((select(i, ...))) end
	Spring.Echo("[zzdemo] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local found = {}
local steps = {}
steps[60] = function()
	for _, u in ipairs(Spring.GetTeamUnits(0)) do
		local n = UnitDefs[Spring.GetUnitDefID(u)].name
		found[n] = u
	end
	local vol
	for _, f in ipairs(Spring.GetAllFeatures()) do
		if FeatureDefs[Spring.GetFeatureDefID(f)].name == "lava_volcano" then vol = f end
	end
	log("Volcano", ok(vol ~= nil))
	for _, n in ipairs({ "armlavagen", "armlavacarrier", "armlavatruck", "armlavafork", "armvp" }) do
		local u = found[n]
		local x, _, z = 0, 0, 0
		if u then x, _, z = Spring.GetUnitPosition(u) end
		log(n, ok(u ~= nil), u and ("at " .. math.floor(x) .. " " .. math.floor(z)) or "")
	end
	local gx, _, gz = Spring.GetUnitPosition(found.armlavagen)
	Spring.SetCameraState({ name = "ta", mode = 1, px = gx + 220, py = 0, pz = gz + 60, height = 1100, angle = 0.9, flipped = -1 }, 0)
end
steps[120] = function() Spring.SendCommands("screenshot png"); log("picture: the test start") end
steps[700] = function()
	for _, n in ipairs({ "armlavacarrier", "armlavatruck", "armlavafork" }) do
		if found[n] then Spring.GiveOrderToUnit(found[n], 39761, { found.armlavagen }, 0) end
	end
	log("Haul for all three, stock", Spring.GetUnitRulesParam(found.armlavagen, "lavaStock"))
end
steps[3000] = function()
	local gx, _, gz = Spring.GetUnitPosition(found.armlavagen)
	Spring.SetCameraState({ name = "ta", mode = 1, px = gx + 200, py = 0, pz = gz + 60, height = 700, angle = 0.9, flipped = -1 }, 0)
end
steps[3030] = function() Spring.SendCommands("screenshot png"); log("picture: after 100 seconds") end
steps[4200] = function()
	local d = Spring.GetTeamRulesParam(0, "lavaDelivered") or 0
	log("delivered", d, ok(d >= 100))
	local gx, _, gz = Spring.GetUnitPosition(found.armlavagen)
	for _, n in ipairs({ "armlavacarrier", "armlavatruck", "armlavafork" }) do
		local u = found[n]
		local x, _, z = Spring.GetUnitPosition(u)
		local q = Spring.GetUnitCommands(u, 3) or {}
		log("at the end", n, "hauling", Spring.GetUnitRulesParam(u, "lavaHauling"), "load", Spring.GetUnitRulesParam(u, "lavaLoad"), "at", math.floor(x - gx), math.floor(z - gz), "from the extractor, orders", #q, q[1] and q[1].id or "")
	end
	log("done"); Spring.SendCommands("quitforce")
end
local last = {}
function widget:GameFrame(f)
	if steps[f] then steps[f]() end
	if f > 60 and f % 15 == 4 then -- (every load and every delivery of the three, with the stock)
		for _, n in ipairs({ "armlavacarrier", "armlavatruck", "armlavafork" }) do
			local u = found[n]
			local load = u and Spring.GetUnitRulesParam(u, "lavaLoad") or 0
			if (load == 0) ~= ((last[n] or 0) == 0) then
				log("frame", f, n, load > 0 and "loaded" or "delivered", "stock", Spring.GetUnitRulesParam(found.armlavagen, "lavaStock"))
			end
			last[n] = load
		end
	end
end
