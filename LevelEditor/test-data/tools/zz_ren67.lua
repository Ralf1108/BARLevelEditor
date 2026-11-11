function widget:GetInfo() return { name = "zz ren67", desc = "test only: the Rattlesnake (armamb) and its trajectory state", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren67.lua: the player becomes a Rattlesnake; the left button, then the right button, are pressed with the trajectory state "low" and "high" (the order
-- CMD.TRAJECTORY); "[zzren67]" logs the state and the reload frames of the weapons after each press.
local function log(...) Spring.Echo("[zzren67] " .. table.concat({ ... }, " ")) end
local steps = {}
local function add(f, fn) steps[#steps + 1] = { f, fn } end
function widget:GameFrame(f)
	local R = WG.renegade
	if f == 5 then Spring.SendCommands("setmaxspeed 3", "setminspeed 3") end
	if not R then return end
	local function status(tag)
		local u = R.unit
		local st = Spring.GetUnitStates(u) or {}
		local keys = {}
		for k, v in pairs(st) do keys[#keys + 1] = k .. "=" .. tostring(v) end
		table.sort(keys)
		log(tag, "targets", tostring(Spring.GetUnitWeaponTarget(u, 1)), tostring(Spring.GetUnitWeaponTarget(u, 2)), tostring(Spring.GetUnitWeaponTarget(u, 3)), "reload w1", tostring(Spring.GetUnitWeaponState(u, 1, "reloadFrame")), "w2", tostring(Spring.GetUnitWeaponState(u, 2, "reloadFrame")), "states", table.concat(keys, ","))
	end
	if f == 60 then R.fake = true; R.yaw, R.pitch = 90, -2 end
	if f == 70 then Spring.SendLuaRulesMsg("ren|unit|armamb") end
	if f == 120 then local ud = UnitDefs[Spring.GetUnitDefID(R.unit)]; for i, wp in ipairs(ud.weapons) do local wd = WeaponDefs[wp.weaponDef]; log("weapon", i, wd.name, "cos", tostring(wp.maxAngleDif), "mainDir", tostring(wp.mainDirX), tostring(wp.mainDirY), tostring(wp.mainDirZ), "turret", tostring(wd.turret), "energyCost", tostring(wd.energyCost), "metalCost", tostring(wd.metalCost), "stockpile", tostring(wd.stockpile), "interceptor", tostring(wd.interceptor), "noSelfDamage", tostring(wd.noSelfDamage), "waterWeapon", tostring(wd.waterWeapon), "range", tostring(wd.range), "coneOut", tostring(R.coneOut)) end end
	if f == 125 then local ud = UnitDefs[Spring.GetUnitDefID(R.unit)]; log("onOffable", tostring(ud.onOffable), "activateWhenBuilt", tostring(ud.activateWhenBuilt), "isBuilding", tostring(ud.isBuilding), "stealth", tostring(ud.stealth), "cloak", tostring(ud.canCloak)); Spring.GiveOrderToUnit(R.unit, CMD.FIRE_STATE, { 2 }, 0) end
	if f == 130 then local u = R.unit; log("beingBuilt", tostring(Spring.GetUnitIsBeingBuilt(u)), "stunned", tostring(Spring.GetUnitIsStunned(u)), "dead", tostring(Spring.GetUnitIsDead(u)), "neutral", tostring(Spring.GetUnitNeutral(u)), "pos", tostring(select(2, Spring.GetUnitPosition(u))), "ground", tostring(Spring.GetGroundHeight(Spring.GetUnitPosition(u))), "health", tostring(Spring.GetUnitHealth(u)), "hasLoS?") end
	if f == 130 then log("hit", tostring(R.hit and R.hit.kind), "udist", tostring(R.hit and math.floor(R.hit.udist)), "sky", tostring(R.skyShot and math.floor(R.skyShot.udist))); status("start"); log("CMD.TRAJECTORY", tostring(CMD.TRAJECTORY)) end
	-- the left button held for 5 s, then the right button held for 5 s
	if f == 140 then R.fire = 1 end
	if f == 290 then status("after 5 s of LMB"); R.fire = 0 end
	if f == 400 then R.fire = 2 end
	if f == 550 then status("after 5 s of RMB"); R.fire = 0 end
	if f == 570 then Spring.SendCommands("quitforce") end
end
