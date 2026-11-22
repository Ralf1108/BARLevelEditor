function widget:GetInfo() return { name = "zz ren39", desc = "test only: at what height does the engine's own bomb release fire, for every bomber", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Ren -RenTest -Widget zz_ren39.lua: the gadget uses the engine's own bomb release (ren|test|4: the target is the ground under the aircraft, no bombs of our own). For every
-- aircraft of Armada, Cortex and Legion with an AircraftBomb weapon, one after the other: the player becomes it, it takes off (W), then Ctrl and the left button are held: it sinks until the engine fires.
-- The gadget logs "weapon 1 fired ... <unit> at <height> above the ground"; this widget logs the unit, its cruise altitude and the height every 20 frames. Lines "[zzren39]".
local function log(...) Spring.Echo("[zzren39] " .. table.concat({ ... }, " ")) end
local R
local list = {}
local PERIOD = 560
function widget:GameFrame(f)
	if f == 5 then Spring.SendCommands("setmaxspeed 4", "setminspeed 4") end
	R = WG.renegade
	if not R then return end
	if f == 90 then
		R.fake = true; R.yaw, R.pitch = 0, -10
		Spring.SendLuaRulesMsg("ren|test|4")
		for name, ud in pairs(UnitDefNames) do
			if ud.canFly and (name:sub(1, 3) == "arm" or name:sub(1, 3) == "cor" or name:sub(1, 3) == "leg") and not name:find("_scav") then
				for _, w in ipairs(ud.weapons or {}) do
					local wd = WeaponDefs[w.weaponDef]
					if wd and wd.type == "AircraftBomb" then list[#list + 1] = name break end
				end
			end
		end
		table.sort(list)
		log("bombers", #list, table.concat(list, " "))
	end
	if f < 120 then return end
	local k = math.floor((f - 120) / PERIOD) + 1
	local s = 120 + (k - 1) * PERIOD
	local name = list[k]
	if not name then Spring.SendCommands("quitforce") return end
	local rel = f - s
	if rel == 0 then
		R.keys, R.fire = 0, 0
		Spring.SendLuaRulesMsg("ren|unit|" .. name)
		log("unit", name, "cruise altitude", tostring(UnitDefNames[name].cruiseAltitude), "frame", f)
	end
	if rel == 30 then R.keys = 1 end
	if rel == 260 then R.keys, R.fire = 33, 1 end
	if rel > 30 and rel % 20 == 0 and R.unit and Spring.ValidUnitID(R.unit) then
		local x, y, z = Spring.GetUnitPosition(R.unit)
		log("f", f, name, "above ground", string.format("%.0f", y - Spring.GetGroundHeight(x, z)))
	end
	if rel == PERIOD - 5 then R.keys, R.fire = 0, 0 end
end
