function widget:GetInfo() return { name = "zz spider", desc = "test only: the movement classes of the units (spiders)", layer = 1, enabled = true } end
-- Test widget of pve_test.ps1 -Widget zz_spider.lua (without -Quick): "[zzspider]" lists the movement classes with the number of units and some examples, and the movement fields of the Vanguard and some spiders.
local function log(...) Spring.Echo("[zzspider] " .. table.concat({ ... }, " ")) end
function widget:GameFrame(f)
	if f ~= 40 then return end
	local cls, ex = {}, {}
	for _, ud in pairs(UnitDefs) do
		if ud.canMove and not ud.canFly and (ud.speed or 0) > 0 and not ud.name:find("_scav$") and not ud.name:find("^raptor") then
			local mv = ud.moveDef
			local nm = tostring(type(mv) == "table" and mv.name or ud.moveDef)
			cls[nm] = (cls[nm] or 0) + 1
			ex[nm] = ex[nm] or {}
			if #ex[nm] < 6 then ex[nm][#ex[nm] + 1] = ud.name end
		end
	end
	for k, n in pairs(cls) do log(n, k, table.concat(ex[k], ",")) end
	for _, n in ipairs({ "armvang", "armsptk", "armspid", "corkarg", "armpw", "armbull", "armmart", "legsptk", "corsok" }) do
		local ud = UnitDefNames[n]
		if ud then
			local mv = ud.moveDef
			log(n, ud.translatedHumanName or "", "move", tostring(type(mv) == "table" and mv.name or mv), "speed", tostring(ud.speed), "turnRate", tostring(ud.turnRate), "maxReverse", tostring(ud.maxReverseSpeed), "rSpeed", tostring(ud.rSpeed), "turnInPlace", tostring(ud.turnInPlace), "turnInPlaceSpeedLimit", tostring(ud.turnInPlaceSpeedLimit), "upright", tostring(ud.upright), "cats", (function() local t = {} for k in pairs(ud.modCategories or {}) do t[#t + 1] = k end table.sort(t) return table.concat(t, ",") end)())
		end
	end
	Spring.SendCommands("quitforce")
end
