-- Volcano and Lava Generator (proof of concept): a Lava Generator (unit with customparams.lavagenerator, lava_generator_defs.lua) that stands on a
-- Volcano (feature with customparams.lavavolcano, lava_volcano_def.lua) makes LAVA_ENERGY energy and LAVA_METAL metal per second (the Volcano gives
-- both; a normal geothermal plant on it makes only its own energy, by the engine); anywhere else nothing (the Level Editor
-- places units anywhere). Checked every second, so a Volcano placed or deleted later counts at once. The unsynced part draws the glow of the lava
-- around every Volcano (stand-in for a model of its own).
function gadget:GetInfo()
	return {
		name = "Lava Generator",
		desc = "Lava Generators on a Volcano make energy and metal",
		author = "",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true,
	}
end

local LAVA_ENERGY = 200 -- energy per second of a Lava Generator on a Volcano (a geothermal plant of tech 1 makes 300)
local LAVA_METAL = 2 -- metal per second of a Lava Generator on a Volcano (a metal extractor of tech 1 on a spot of 2.0 makes about 2)
local ON_RADIUS = 40 -- the middle of the generator at most so far from the middle of a Volcano (Elmo)

local volcanoDef = {} -- featureDefID -> true
for id, fd in pairs(FeatureDefs) do
	if fd.customParams and fd.customParams.lavavolcano then
		volcanoDef[id] = true
	end
end
local volcanoes = {} -- featureID -> { x, y, z }

local function addFeature(fid, defID)
	if volcanoDef[defID] then
		local x, y, z = Spring.GetFeaturePosition(fid)
		if x then
			volcanoes[fid] = { x, y, z }
		end
	end
end

function gadget:FeatureCreated(fid)
	addFeature(fid, Spring.GetFeatureDefID(fid))
end

function gadget:FeatureDestroyed(fid)
	volcanoes[fid] = nil
end

if gadgetHandler:IsSyncedCode() then
	local genDef = {} -- unitDefID -> true
	for id, ud in pairs(UnitDefs) do
		if ud.customParams and ud.customParams.lavagenerator then
			genDef[id] = true
		end
	end
	local gens = {} -- unitID -> true while it makes energy and metal (on a Volcano), false while not, -1 = not checked yet

	local function onVolcano(u)
		local x, _, z = Spring.GetUnitPosition(u)
		if not x then
			return false
		end
		for _, p in pairs(volcanoes) do
			if (p[1] - x) ^ 2 + (p[3] - z) ^ 2 <= ON_RADIUS * ON_RADIUS then
				return true
			end
		end
		return false
	end

	local function check(u)
		local _, _, _, _, built = Spring.GetUnitHealth(u)
		local on = (built or 0) >= 1 and onVolcano(u)
		if gens[u] ~= on then
			gens[u] = on
			Spring.SetUnitResourcing(u, "ume", on and LAVA_ENERGY or 0) -- (unconditional make energy)
			Spring.SetUnitResourcing(u, "umm", on and LAVA_METAL or 0) -- (unconditional make metal)
			Spring.SetUnitRulesParam(u, "lavaEnergy", on and LAVA_ENERGY or 0, { public = true })
			Spring.SetUnitRulesParam(u, "lavaMetal", on and LAVA_METAL or 0, { public = true })
		end
	end

	function gadget:Initialize()
		if not next(genDef) then
			gadgetHandler:RemoveGadget(self) -- (a game without the Lava Generator)
			return
		end
		for _, fid in ipairs(Spring.GetAllFeatures()) do
			addFeature(fid, Spring.GetFeatureDefID(fid))
		end
		for _, u in ipairs(Spring.GetAllUnits()) do
			if genDef[Spring.GetUnitDefID(u)] then
				gens[u] = -1
			end
		end
	end

	function gadget:UnitCreated(u, defID)
		if genDef[defID] then
			gens[u] = -1
		end
	end

	function gadget:UnitFinished(u, defID)
		if genDef[defID] then
			check(u)
		end
	end

	function gadget:UnitDestroyed(u)
		gens[u] = nil
	end

	function gadget:GameFrame(f)
		if f % 30 == 7 then
			for u in pairs(gens) do
				check(u)
			end
		end
	end
else
	-- the glow of the lava: rings in red and orange around every Volcano in sight, slowly pulsing
	function gadget:Initialize()
		if not next(volcanoDef) then
			gadgetHandler:RemoveGadget(self)
			return
		end
		for _, fid in ipairs(Spring.GetAllFeatures()) do
			addFeature(fid, Spring.GetFeatureDefID(fid))
		end
	end

	function gadget:DrawWorldPreUnit()
		if not next(volcanoes) then
			return
		end
		local t = Spring.GetGameSeconds() + Spring.GetFrameTimeOffset() / 30
		gl.DepthTest(false)
		for _, p in pairs(volcanoes) do
			if Spring.IsSphereInView(p[1], p[2], p[3], 120) then
				for i = 1, 6 do
					local a = (0.25 + 0.2 * math.sin(t * 2 + i)) * (1 - i / 8)
					gl.LineWidth(9 - i)
					gl.Color(1, 0.15 + i * 0.1, 0, a)
					gl.DrawGroundCircle(p[1], p[2], p[3], 14 + i * 11, 32)
				end
			end
		end
		gl.LineWidth(1)
		gl.Color(1, 1, 1, 1)
		gl.DepthTest(true)
	end
end
