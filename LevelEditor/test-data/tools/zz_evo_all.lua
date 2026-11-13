function widget:GetInfo() return { name = "zz evo all", desc = "test only: several Evolution rules in one game", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Debug -Bots 1 -Widget zz_evo_all.lua (one instance, speed 10, ends at frame 4200). One game, several checks, lines "[zzall]":
--  A  Cloak (frame 120): the cloak works and the fire state is 0 (hold fire); the attack order at 180 ends it; fire state 2 afterwards
--  B  automatic reclaim (frame 700): the unit is hurt to 30 % with a wreck next to it (evo|test|6); the health must rise
--  C  radar (frames 1000 to 2000): level 8 by the debug button; the gadget logs IsUnitInRadar of the other ally team every 150 frames; the power-up Jammer at 1250 hides it until about 1850 (no lines then)
--  D  energy storage and the first one on level 10 (frame 2000): two level ups (level 10, Armageddon); the storage must be 2000; the bot reaches level 10 as well at 2200 (evo|test|7): without
--     the option All Be Gods the chat says it is too late, and the gift window does not open for it (evoGift of its team stays 0)
--  E  the gift Hell on Earth at 2400: +1000 energy per second (the gadget logs it), the chat has a saying
local function log(...) Spring.Echo("[zzall] " .. table.concat({ ... }, " ")) end
local me = function() return Spring.GetMyTeamID() end
local function unit() return Spring.GetTeamRulesParam(me(), "evoUnit") end
local function state(tag)
	local u = unit()
	local st = u and Spring.GetUnitStates(u)
	local hp, maxHp = Spring.GetUnitHealth(u or -1)
	local e, store = Spring.GetTeamResources(me(), "energy")
	log(tag, "frame", Spring.GetGameFrame(), "fire state", tostring(st and st.firestate), "cloaked", tostring((Spring.GetUnitIsCloaked(u or -1))), "health", tostring(hp and math.floor(hp)), "of", tostring(maxHp and math.floor(maxHp)), "energy", math.floor(e or 0), "storage", math.floor(store or 0))
end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10") end
	-- A
	if f == 60 then Spring.SendLuaRulesMsg("evo|test|1"); Spring.SendLuaRulesMsg("evo|test|3") end
	if f == 100 then state("A before the cloak") end
	if f == 120 then log("A using Cloak"); Spring.SendLuaRulesMsg("evo|use|4") end
	if f == 160 then state("A cloaked") end
	if f == 180 then
		local spy = Spring.GetGameRulesParam("evoTestSpy") or 0
		log("A ordering Attack on", tostring(spy))
		if unit() and spy > 0 then Spring.GiveOrderToUnit(unit(), CMD.ATTACK, { spy }, 0) end
	end
	if f == 300 then state("A after the attack") end
	-- B
	if f == 700 then log("B hurt + wreck"); Spring.SendLuaRulesMsg("evo|test|6") end
	if f == 730 or f == 800 or f == 1000 then state("B") end
	-- C
	if f >= 1010 and f <= 1070 and f % 10 == 0 then Spring.SendLuaRulesMsg("evo|debug|2") end   -- (seven times: level 8)
	if f == 1240 then Spring.SendLuaRulesMsg("evo|test|1") end   -- (energy for the Jammer)
	if f == 1250 then log("C using Jammer: no radar lines from the gadget until about frame 1850"); Spring.SendLuaRulesMsg("evo|use|5") end
	-- D
	if f == 2000 or f == 2010 then log("D level up to level 10"); Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 2100 then state("D level 10") end
	if f == 2200 then log("D the other player reaches level 10"); Spring.SendLuaRulesMsg("evo|test|7") end
	if f == 2300 then
		for _, t in ipairs(Spring.GetTeamList()) do
			if t ~= me() and t ~= Spring.GetGaiaTeamID() then log("D gift window of team", t, "evoGift", tostring(Spring.GetTeamRulesParam(t, "evoGift"))) end
		end
	end
	-- E
	if f == 2400 then log("E gift Heaven on Earth"); Spring.SendLuaRulesMsg("evo|gift|2") end
	if f == 2500 or f == 2600 then state("E") end
	if f == 4200 then Spring.SendCommands("quitforce") end
end
