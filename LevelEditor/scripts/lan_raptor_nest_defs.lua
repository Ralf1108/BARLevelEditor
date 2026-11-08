-- LAN Play, Raptors played by humans (PROTOTYPE): the unit "raptor_nest", a factory of raptors, and the healers of the Raptors can build it.
-- This text is the game option tweakdefs (base64): BAR's gamedata/unitdefs_post.lua runs it on the table UnitDefs (the unit definitions before the game,
-- the same on every computer because the option is part of the start script). A copy of the hive (model, script, look) with a list of raptors to build.
local hive = UnitDefs and UnitDefs.raptor_hive
if not hive or UnitDefs.raptor_nest then
	return
end
local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and copy(v) or v
	end
	return out
end
local nest = copy(hive)
nest.unitname = "raptor_nest"
nest.name = "Raptor Nest"
nest.description = "Grows raptors"
nest.metalcost = 300
nest.energycost = 3000
nest.buildtime = 6000
nest.health = 6000
nest.workertime = 200
nest.metalmake = 3
nest.energymake = 60
nest.energystorage = 1000
nest.builddistance = 120
-- the middle of the footprint stays open (y): the raptors grow in the middle and walk out
nest.yardmap = "oyyyyo yyyyyy yyyyyy yyyyyy yyyyyy oyyyyo"
nest.customparams = nest.customparams or {}
nest.customparams.isairbase = nil
nest.customparams.raptornest = true
-- the hive's animation script knows no building: BAR's gadget unit_missing_build_scripts.lua (loaded when a tweakdefs option is set) puts such a builder into
-- the build stance (COB INBUILDSTANCE) and gives it a nano piece
nest.customparams.scriptlessbuilder = true
nest.buildoptions = {
	"raptor_land_swarmer_basic_t1_v1",
	"raptor_land_swarmer_heal_t1_v1",
	"raptor_land_kamikaze_basic_t2_v1",
	"raptor_land_assault_basic_t2_v1",
	"raptor_land_spiker_basic_t2_v1",
	"raptor_allterrain_arty_basic_t2_v1",
	"raptor_air_scout_basic_t2_v1",
	"raptor_air_fighter_basic_t1_v1",
	"raptor_air_bomber_basic_t1_v1",
}
for i = #nest.buildoptions, 1, -1 do
	if not UnitDefs[nest.buildoptions[i]] then
		table.remove(nest.buildoptions, i)
	end
end
UnitDefs.raptor_nest = nest
for _, name in ipairs({ "raptor_land_swarmer_heal_t1_v1", "raptor_land_swarmer_heal_t2_v1", "raptor_land_swarmer_heal_t3_v1", "raptor_land_swarmer_heal_t4_v1", "raptor_matriarch_healer" }) do
	local ud = UnitDefs[name]
	if ud then
		ud.buildoptions = ud.buildoptions or {}
		table.insert(ud.buildoptions, 1, "raptor_nest")
	end
end
