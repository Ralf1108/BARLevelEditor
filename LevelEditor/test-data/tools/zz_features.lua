function widget:GetInfo() return { name = "zz features", desc = "test only: moves a feature (tree) and undoes it", layer = 1000000, enabled = true } end
-- Test widget of arena_test.ps1 -Widget zz_features.lua: places a feature, moves it with the message led|movefeatures (what Alt + drag sends), undo and redo.
-- Logs "[zzar]" lines, ends with quitforce.
local function log(...)
	local t = {}
	for i, v in ipairs({ ... }) do t[i] = tostring(v) end
	Spring.Echo("[zzar] " .. table.concat(t, " "))
end
local function ok(c) return c and "OK" or "WRONG" end
local MX, MZ = Game.mapSizeX / 2 + 800, Game.mapSizeZ / 2 + 800
local name
for n in pairs(FeatureDefNames) do
	if n:find("tree") or n:find("pine") then name = n break end
end
name = name or next(FeatureDefNames)
local function find()
	local out = {}
	for _, fid in ipairs(Spring.GetFeaturesInCylinder(MX, MZ, 3000) or {}) do
		local x, _, z = Spring.GetFeaturePosition(fid)
		local d = Spring.GetFeatureDefID(fid)
		if d and FeatureDefs[d].name == name then out[#out + 1] = { fid = fid, x = x, z = z } end
	end
	return out
end
local fid0, x0, z0
local steps = {}
steps[40] = function()
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|feature|%s|%d|%d|0", name, MX, MZ))
	log("placed", name)
end
steps[80] = function()
	local f = find()[1]
	fid0, x0, z0 = f.fid, f.x, f.z
	log("feature at", math.floor(x0), math.floor(z0))
	Spring.SendLuaRulesMsg("led|step")
	Spring.SendLuaRulesMsg(string.format("led|movefeatures|%d|%d|%d", 256, -128, fid0))
end
steps[130] = function()
	local f = find()
	local n = #f
	log("after the move: features", n, ok(n == 1), n == 1 and string.format("dx %d dz %d", f[1].x - x0, f[1].z - z0) or "", ok(n == 1 and math.abs(f[1].x - x0 - 256) < 2 and math.abs(f[1].z - z0 + 128) < 2))
	Spring.SendLuaRulesMsg("led|undo|1")
end
steps[180] = function()
	local f = find()
	log("after undo:", #f, ok(#f == 1 and math.abs(f[1].x - x0) < 2 and math.abs(f[1].z - z0) < 2))
	Spring.SendLuaRulesMsg("led|redo|1")
end
steps[230] = function()
	local f = find()
	log("after redo:", #f, ok(#f == 1 and math.abs(f[1].x - x0 - 256) < 2))
	log("END")
	Spring.SendCommands("quitforce")
end
local done = {}
function widget:Update()
	local f0 = Spring.GetGameFrame()
	local keys = {}
	for k in pairs(steps) do keys[#keys + 1] = k end
	table.sort(keys)
	for _, k in ipairs(keys) do
		if k <= f0 and not done[k] then
			done[k] = true
			local ok2, err = pcall(steps[k])
			if not ok2 then log("TEST ERROR at", k, tostring(err)) end
			break
		end
	end
end
