function widget:GetInfo() return { name = "zz ren5", desc = "test only: Renegade bots, debug unit menu, respawn", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -RenBots 3 -Widget zz_ren5.lua: counts the bots and how close they come, turns the unit into a Grunt (debug message), shows the debug
-- menu with its list (picture), kills the own unit and looks whether it comes back. Lines "[zzren5]".
local function log(...) Spring.Echo("[zzren5] " .. table.concat({ ... }, " ")) end
local function fmt(...) local t = {} for _, v in ipairs({ ... }) do t[#t + 1] = type(v) == "number" and string.format("%.0f", v) or tostring(v) end return table.concat(t, " ") end
local R
local function mine() return Spring.GetTeamRulesParam(Spring.GetMyTeamID(), "renUnit") or 0 end
local function name(id) local d = UnitDefs[Spring.GetUnitDefID(id) or -1] return d and d.name or "none" end
local function bots()
	local n, near = 0, 1e9
	local u = mine()
	local ux, _, uz = Spring.GetUnitPosition(u)
	for _, id in ipairs(Spring.GetTeamUnits(1)) do
		if name(id) == "armpw" then
			n = n + 1
			local x, _, z = Spring.GetUnitPosition(id)
			if ux then near = math.min(near, math.sqrt((x - ux) ^ 2 + (z - uz) ^ 2)) end
		end
	end
	return n, near
end
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true end
	if f % 300 == 200 then local n, near = bots() log("frame", f, "bots", n, "nearest", fmt(near), "own", name(mine()), "health", fmt(Spring.GetUnitHealth(mine()))) end
	if f == 300 then Spring.SendLuaRulesMsg("ren|unit|corak") end
	if f == 330 then log("after the debug message: own unit", name(mine()), "view follows", tostring(R.unit == mine()), "hidden", tostring(R.hidden)) end
	if f == 340 then R.menu, R.list, R.scroll = true, true, 0 end
	if f == 350 then log("list entries", tostring(R.units and #R.units), "first", R.units and R.units[1].name, "last", R.units and R.units[#R.units].name); Spring.SendCommands("screenshot png") end
	if f == 360 then R.menu, R.list = false, false end
	if f == 400 then Spring.SendLuaRulesMsg("ren|test|2") end
	if f == 420 then log("killed: renUnit", tostring(mine())) end
	if f == 560 then log("later: renUnit", tostring(mine()), name(mine())) end
	if f == 420 then Spring.SendCommands("quitforce") end
end
