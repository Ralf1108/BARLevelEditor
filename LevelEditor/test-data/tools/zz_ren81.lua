function widget:GetInfo() return { name = "zz ren81", desc = "test only: Renegade take-over mode with Evolution: the player takes over the evolved unit", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTake -Evo -EvoTest -Widget zz_ren81.lua: the player takes over its Evolution unit (the message of the mode key), switches to the third person view
-- (R.third), then "evo|test|4" gives it level 10 at once (the unit evolves: a new unit). Lines "[zzren81]": the unit, the view and the camera before and after.
local function log(...) Spring.Echo("[zzren81] " .. table.concat({ ... }, " ")) end
local R
local function state(tag)
	local team = Spring.GetMyTeamID()
	local function rp(k) return tostring((Spring.GetTeamRulesParam(team, k))) end
	local cs = Spring.GetCameraState()
	log(tag, "R.on", tostring(R and R.on), "third", tostring(R and R.third), "waiting", tostring(R and R.waiting), "renUnit", rp("renUnit"), "evoUnit", rp("evoUnit"), "stage", rp("evoStage"), "follow", rp("renFollow"), "camera", tostring(cs and cs.name), "unit def", tostring((R and R.unit and Spring.GetUnitDefID(R.unit) and UnitDefs[Spring.GetUnitDefID(R.unit)].name) or "-"))
end
function widget:GameFrame(f)
	R = WG.renegade
	if not R then return end
	local team = Spring.GetMyTeamID()
	if f == 100 then state("start") end
	if f == 120 then
		local id = Spring.GetTeamRulesParam(team, "evoUnit")
		if id and id > 0 then Spring.SendLuaRulesMsg("ren|possess|" .. id) end
	end
	if f == 180 then state("took over"); R.third = true; R.fake = true end
	if f == 200 then state("third person"); Spring.SendLuaRulesMsg("evo|test|4") end
	for _, k in ipairs({ 202, 215, 240, 300, 400 }) do if f == k then state("after the evolution, frame " .. f) end end
	if f == 420 then Spring.SendCommands("quitforce") end
end
