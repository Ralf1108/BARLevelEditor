function widget:GetInfo() return { name = "zz gates", desc = "test only: Gates of Hell and the debug buttons", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_gates.lua (one instance, speed 10): uses the debug message evo|debug|3 (level down, at level 1 nothing),
-- evo|debug|2 (level up) twice, then evo|debug|1 (Armageddon: level 10), chooses the gift Gates of Hell (evo|gift|3) and logs every 600 frames how many missile rings
-- are on the map (game rule evoNukes), the smallest distance of a ring to the enemy's unit and to the own unit. Ends at frame 8400. Lines "[zzgates]".
local function log(...) Spring.Echo("[zzgates] " .. table.concat({ ... }, " ")) end
local function level(team) return Spring.GetTeamRulesParam(team, "evoStage") end
local function pos(team)
	local u = Spring.GetTeamRulesParam(team, "evoUnit")
	if u and u > 0 then local x, _, z = Spring.GetUnitPosition(u); return x, z end
end
local seen = {}
function widget:GameFrame(f)
	local me = Spring.GetMyTeamID()
	if f == 5 then Spring.SendCommands("setmaxspeed 10", "setminspeed 10") end
	if f == 20 then for _ = 1, 3 do Spring.SendLuaRulesMsg("evo|debug|4") end end
	if f == 25 then log("XP after 3 x XP up:", tostring(Spring.GetTeamRulesParam(me, "evoExp"))); Spring.SendLuaRulesMsg("evo|debug|5") end
	if f == 28 then log("XP after XP down:", tostring(Spring.GetTeamRulesParam(me, "evoExp"))) end
	if f == 30 then Spring.SendLuaRulesMsg("evo|debug|3"); log("level after Level Down at 1:", tostring(level(me))) end
	if f == 60 then Spring.SendLuaRulesMsg("evo|debug|2") end
	if f == 90 then log("level after Level Up:", tostring(level(me))); Spring.SendLuaRulesMsg("evo|debug|3") end
	if f == 120 then log("level after Level Down:", tostring(level(me))); Spring.SendLuaRulesMsg("evo|debug|1") end
	if f == 150 then log("level after Armageddon:", tostring(level(me)), "gift window:", tostring(Spring.GetTeamRulesParam(me, "evoGift"))); Spring.SendLuaRulesMsg("evo|gift|3") end
	if f >= 300 and f % 300 == 0 then
		local rings = tostring(Spring.GetGameRulesParam("evoNukes") or "")
		local n, dEnemy, dMe = 0, math.huge, math.huge
		local ex, ez, mx, mz
		for t in ipairs(Spring.GetTeamList()) do end
		for _, team in ipairs(Spring.GetTeamList()) do
			if team ~= me and Spring.GetTeamRulesParam(team, "evoStage") then ex, ez = pos(team) end
		end
		mx, mz = pos(me)
		for x, z in rings:gmatch("(%d+),(%d+)") do
			n = n + 1
			x, z = tonumber(x), tonumber(z)
			if ex then dEnemy = math.min(dEnemy, math.sqrt((x - ex) ^ 2 + (z - ez) ^ 2)) end
			if mx then dMe = math.min(dMe, math.sqrt((x - mx) ^ 2 + (z - mz) ^ 2)) end
		end
		log("frame", f, "rings", n, "nearest to the enemy", math.floor(dEnemy), "nearest to me", math.floor(dMe), "enemy level", tostring(level(me == 0 and 1 or 0)))
	end
	if f == 8400 then Spring.SendCommands("quitforce") end
end
