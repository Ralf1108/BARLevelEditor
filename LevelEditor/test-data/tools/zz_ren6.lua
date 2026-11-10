function widget:GetInfo() return { name = "zz ren6", desc = "test only: Renegade shot latency, two buttons, turret, menu, energy", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren6.lua: frames from the click to the weapon target, left / right button with a unit of several weapons, a turret,
-- the unit menu (picture), energy. Lines "[zzren6]".
local function log(...) Spring.Echo("[zzren6] " .. table.concat({ ... }, " ")) end
local function fmt(...) local t = {} for _, v in ipairs({ ... }) do t[#t + 1] = type(v) == "number" and string.format("%.0f", v) or tostring(v) end return table.concat(t, " ") end
local R
local started
local function targets()
	local t = {}
	for i = 1, #(UnitDefs[Spring.GetUnitDefID(R.unit)].weapons) do
		local a = Spring.GetUnitWeaponTarget(R.unit, i)
		t[#t + 1] = i .. ":" .. tostring(a)
	end
	return table.concat(t, " ")
end
local multi
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, -10 end
	if f == 100 then local e = Spring.GetTeamResources(Spring.GetMyTeamID(), "energy"); log("energy", fmt(e), "main weapon", tostring(Spring.GetUnitRulesParam(R.unit, "renMain"))) end
	if f == 130 then R.fire = 1; started = f end
	if started and f > started and f < started + 30 then
		local a = Spring.GetUnitWeaponTarget(R.unit, 1)
		if a and a ~= 0 then log("the weapon had its target", fmt(f - started), "frames after the click"); started = nil end
	end
	if f == 170 then log("firing left: reloadFrame", tostring(Spring.GetUnitWeaponState(R.unit, 1, "reloadFrame")), "frame", fmt(f), "energy", fmt(Spring.GetTeamResources(Spring.GetMyTeamID(), "energy"))); R.fire = 0 end
	if f == 200 then
		for _, n in ipairs({ "armraz", "armbanth", "corkarg", "corshiva", "corkorg", "armthor", "armmav", "legkeres" }) do
			local d = UnitDefNames[n]
			if d and #d.weapons >= 2 and not multi then multi = n end
		end
		log("unit with several weapons:", tostring(multi))
		Spring.SendLuaRulesMsg("ren|unit|" .. (multi or "armraz"))
	end
	if f == 230 then
		local d = UnitDefs[Spring.GetUnitDefID(R.unit)]
		log("now", d.name, "weapons", fmt(#d.weapons), "main", tostring(Spring.GetUnitRulesParam(R.unit, "renMain")))
		R.fire = 2
	end
	if f == 280 then log("right button:", targets()); R.fire = 1 end
	if f == 310 then log("left button:", targets()); R.fire = 3 end
	if f == 340 then log("both:", targets()); R.fire = 0 end
	if f == 360 then log("released:", targets()) end
	if f == 370 then Spring.SendLuaRulesMsg("ren|unit|armllt") end
	if f == 400 then
		local d = UnitDefs[Spring.GetUnitDefID(R.unit)]
		log("turret:", d.name, "view follows", tostring(R.unit == (Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit"))), "height", fmt(Spring.GetUnitHeight(R.unit)))
		R.keys = 1; R.fire = 1
	end
	if f == 440 then log("turret fires:", targets(), "speed", fmt(Spring.GetUnitVelocity(R.unit)), "hit", R.hit and R.hit.kind or "sky", R.hit and ("in range " .. fmt(R.hit.udist)) or ""); R.keys = 0; R.fire = 0 end
	if f == 460 then R.menu, R.list = true, true; R.picker = nil end
	if f == 480 then Spring.SendCommands("screenshot png") end
	if f == 500 then R.menu, R.list = false, false end
	if f == 520 then Spring.SendCommands("quitforce") end
end
