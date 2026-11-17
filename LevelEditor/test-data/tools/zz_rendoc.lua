function widget:GetInfo() return { name = "zz rendoc", desc = "test only: pictures of Renegade for the manual", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest [-RenMode race|survival] [-RenBots 3] -Widget zz_rendoc.lua (one instance): pictures with the engine (<Work>\data\screenshots), then the end.
-- The debug buttons and the tips are hidden, the view is the third person view; nothing is echoed before a picture (the console would show it).
--   no mode    the view turns to the nearest enemy; it fires when one is closer than 700 Elmo, the picture 20 frames later (at the latest at frame 2400)
--   survival   the same during the first wave (the wave panel at the top)
--   race       the cards of the racers (frame 520), the start grid facing the first ring (just after GO), then 16 checkpoints by ren|test|11 and the results
-- Lines "[zzrendoc]" after the pictures.
local MODE = (Spring.GetModOptions() or {}).lanrenemode or "fight"
local function log(...) Spring.Echo("[zzrendoc] " .. table.concat({ ... }, " ")) end
local shots, steps, quitAt, overAt = {}, 0, nil, nil
local function shot(name) Spring.SendCommands("screenshot png"); shots[#shots + 1] = name .. "@" .. Spring.GetGameFrame() end
local function myUnit() local u = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit") or 0; return u > 0 and Spring.ValidUnitID(u) and u or nil end
local function lookAt(x, z, pitch)
	local R, u = WG.renegade, myUnit()
	local ux, _, uz = Spring.GetUnitPosition(u or -1)
	if not (R and ux) then return end
	R.yaw, R.pitch = math.deg(math.atan2(x - ux, z - uz)), pitch
end
local function nearestEnemy()
	local u = myUnit()
	local ux, _, uz = Spring.GetUnitPosition(u or -1)
	if not ux then return nil end
	local best, bd
	for _, e in ipairs(Spring.GetAllUnits()) do
		if not Spring.AreTeamsAllied(Spring.GetUnitTeam(e), Spring.GetMyTeamID()) then
			local x, _, z = Spring.GetUnitPosition(e)
			local d = x and math.sqrt((x - ux) ^ 2 + (z - uz) ^ 2)
			if d and (not bd or d < bd) then best, bd = e, d end
		end
	end
	return best, bd
end
function widget:GameFrame(f)
	local R = WG.renegade
	if f == 2 and R then
		R.debug = false -- (no debug buttons in the pictures)
		if R.M then R.M.hint = function() end end -- (no tips)
	end
	if f == 30 and R then R.fake = true; R.third = true; R.yaw, R.pitch = 0, -8 end
	if quitAt and f >= quitAt then log("pictures:", table.concat(shots, " ")); Spring.SendCommands("quitforce") return end
	if MODE == "race" then
		if f == 200 then Spring.SendLuaRulesMsg("ren|race|pick|3") end
		local go = Spring.GetGameRulesParam("renRaceGo") or 600
		local cx, cz = tostring(Spring.GetGameRulesParam("renRaceCps") or ""):match("^(%d+),(%d+)")
		if cx and f >= go - 60 and f <= go + 20 then lookAt(tonumber(cx), tonumber(cz), -10) end
		if f == 520 then shot("cards") end
		if f == go + 15 then shot("start") end
		if f > go + 40 and f % 20 == 0 and steps < 16 then steps = steps + 1; Spring.SendLuaRulesMsg("ren|test|11") end
		if not overAt and (Spring.GetGameRulesParam("renRaceOver") or 0) > 0 then overAt = f end
		if overAt and f == overAt + 45 then shot("results"); quitAt = f + 30 end
	else
		if f >= 600 and f % 15 == 0 and not quitAt then
			local e, d = nearestEnemy()
			if e then local x, _, z = Spring.GetUnitPosition(e); lookAt(x, z, -2) end
			if e and d < 700 and R then R.fire = 1; widget.firing = widget.firing or f end -- (the left button: the short range weapons)
			if (widget.firing and f >= widget.firing + 20) or f >= 2400 then shot(MODE); quitAt = f + 30 end
		end
	end
	if f >= 4000 and not quitAt then shot("timeout"); quitAt = f + 30 end
end
