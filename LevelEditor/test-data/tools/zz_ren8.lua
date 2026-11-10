function widget:GetInfo() return { name = "zz ren8", desc = "test only: Renegade three buttons and weapon groups", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren8.lua: turns into several units, fires each button group, releases and looks whether any weapon keeps firing
-- (reloadFrame changes), takes a picture of the barrel lines and rings. Lines "[zzren8]".
local function log(...) Spring.Echo("[zzren8] " .. table.concat({ ... }, " ")) end
local R
local units = { "armbanth", "armepoch", "corkarg" }
local step = 0
local base, rel = {}, nil
local function targets(u)
	local t = {}
	for i = 1, #(UnitDefs[Spring.GetUnitDefID(u)].weapons) do t[#t + 1] = i .. ":" .. tostring(Spring.GetUnitWeaponTarget(u, i)) end
	return table.concat(t, " ")
end
local function reloads(u)
	local t = {}
	for i = 1, #(UnitDefs[Spring.GetUnitDefID(u)].weapons) do t[#t + 1] = tostring(Spring.GetUnitWeaponState(u, i, "reloadFrame")) end
	return table.concat(t, ",")
end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 90, -10 end
	-- per unit 260 frames: turn (0), slots (20), left (40-80), right (100-140), middle (160-200), released (200), check (260)
	local k = math.floor((f - 100) / 260) + 1
	local t0 = 100 + (k - 1) * 260
	local name = units[k]
	if not name or f < 100 then if f > 100 + #units * 260 then Spring.SendCommands("quitforce") end return end
	local d = f - t0
	if d == 0 then Spring.SendLuaRulesMsg("ren|unit|" .. name) end
	if d == 30 then
		log(name, "slots", tostring(Spring.GetUnitRulesParam(R.unit, "renSlots")), "aa", tostring(Spring.GetUnitRulesParam(R.unit, "renAA")))
		local v = { Spring.GetUnitWeaponVectors(R.unit, 1) }
		local s = {}
		for i, x in ipairs(v) do s[#s + 1] = type(x) == "number" and string.format("%.2f", x) or tostring(x) end
		log("GetUnitWeaponVectors:", table.concat(s, " "))
		if k == 1 then Spring.SendCommands("screenshot png") end
	end
	if d == 40 then R.fire = 1 end
	if d == 80 then log(name, "left:", targets(R.unit)); R.fire = 0 end
	if d == 100 then R.fire = 2 end
	if d == 140 then log(name, "right:", targets(R.unit)); R.fire = 0 end
	if d == 160 then R.fire = 4 end
	if d == 200 then log(name, "middle:", targets(R.unit)); R.fire = 0; rel = reloads(R.unit) end
	if d == 215 then log(name, "released; reload frames just after", rel, "15 frames later", reloads(R.unit), "targets", targets(R.unit)) end
	if d == 255 then log(name, "55 frames after release", reloads(R.unit), "frame", f) end
end
