function widget:GetInfo() return { name = "zz ren94", desc = "test only: spawn shield and comeback bonus (Renegade and Evolution)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenPowerups -Widget zz_ren94.lua (Renegade) or pve_test.ps1 -Evo -EvoTest -Widget zz_ren94.lua (Evolution): the own unit is
-- lost three times (ren|test|2 / evo|test|8); after every return the unit rules ledShield (the frame the shield ends) is logged, and right after the third return the unit
-- takes a lethal hit (ren|test|5, Renegade only): the shield must keep it. After the third loss the comeback bonus: a free power-up (team rules renAbilities / evoAbilities)
-- and the note (team rules ledNote). Lines "[zzren94]"; a picture with the shield ring and the note.
local function log(...) Spring.Echo("[zzren94] " .. table.concat({ ... }, " ")) end
local evo = (Spring.GetModOptions() or {}).lanevolution == "1"
local rule = evo and "evoUnit" or "renUnit"
local last, backs, lostAt, nextKill, check = nil, 0, nil, 150, nil
local function mine() local u = Spring.GetTeamRulesParam(Spring.GetMyTeamID(), rule) or 0; return u > 0 and u or nil end
function widget:GameFrame(f)
	local team = Spring.GetMyTeamID()
	local u = mine()
	if u and not last then last = u end
	if u and not lostAt and backs < 3 and f >= nextKill then
		lostAt = f
		Spring.SendLuaRulesMsg(evo and "evo|test|8" or "ren|test|2")
		log("frame", f, "the unit", u, "is destroyed (loss " .. (backs + 1) .. ")")
	end
	if lostAt and u and u ~= last then
		backs, last, lostAt, nextKill = backs + 1, u, nil, f + 60
		log("frame", f, "back", backs, "unit", u, "shield until", tostring((Spring.GetUnitRulesParam(u, "ledShield"))), "note:", tostring((Spring.GetTeamRulesParam(team, "ledNote"))),
			"abilities:", tostring((Spring.GetTeamRulesParam(team, evo and "evoAbilities" or "renAbilities"))))
		if backs == 3 then
			check = f + 10
			if not evo then Spring.SendLuaRulesMsg("ren|test|5") end -- (a lethal hit during the shield)
		end
	end
	if check and f == check then
		local hp, mhp = Spring.GetUnitHealth(u or -1)
		log("10 frames after the lethal hit: unit", tostring(u), "same", tostring(u == last), "health", tostring(hp), "of", tostring(mhp), "shield until", tostring(u and (Spring.GetUnitRulesParam(u, "ledShield"))), "frame", f)
		Spring.SendCommands("screenshot png")
	end
	if check and f == check + 150 then
		log("5 s later: shield param", tostring(u and (Spring.GetUnitRulesParam(u, "ledShield"))), "frame", f)
		Spring.SendCommands("quitforce")
	end
	if f == 2400 then log("timeout, backs", backs); Spring.SendCommands("quitforce") end
end
