function widget:GetInfo() return { name = "zz ren29", desc = "test only: what height does a gunship fly at with a plain move order (no Renegade height control)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren29.lua: the player becomes a Roughneck (armbrawl); the widget gives it a plain move order across the map (no key, so the
-- gadget's height control is not used), then a stop. Logs the height above the ground, the ground height and the height above the sea level; also the height fields of the definition. Lines "[zzren29]".
local function log(...) Spring.Echo("[zzren29] " .. table.concat({ ... }, " ")) end
local R
local idle = 0
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then R.fake = true; R.yaw, R.pitch = 270, 0 end
	if f == 100 then
		Spring.SendLuaRulesMsg("ren|unit|armbrawl")
		local ud = UnitDefNames.armbrawl
		for k, v in pairs(ud) do
			local key = tostring(k):lower()
			if (key:find("alt") or key:find("height") or key:find("hover") or key:find("cruise") or key:find("fly") or key:find("vertical")) and type(v) ~= "table" and type(v) ~= "function" then log("def", k, tostring(v)) end
		end
		for k, v in pairs(ud.customParams or {}) do log("custom", k, tostring(v)) end
	end
	if f == 130 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		Spring.GiveOrderToUnit(R.unit, CMD.MOVE, { x + 3000, y, z + 1500 }, {})
		log("move order from", string.format("%.0f %.0f %.0f", x, y, z))
	end
	if f == 600 and R.unit then Spring.GiveOrderToUnit(R.unit, CMD.STOP, {}, 0); log("stop") end
	if f >= 120 and f % 30 == 0 and R.unit then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		local g = Spring.GetGroundHeight(x, z)
		log("f", f, "above ground", string.format("%.0f", y - g), "ground", string.format("%.0f", g), "sea level", string.format("%.0f", y), "x", string.format("%.0f", x), "z", string.format("%.0f", z))
	end
	if f == 800 then Spring.SendCommands("quitforce") end
end
