-- LAN Play, Raptors played by humans: the unit "raptor_brood_chamber" (Raptor Brood Chamber), a factory of raptors, and the healers of the Raptors can build it.
-- This text is a game option tweakdefs<N> (base64url): BAR's gamedata/unitdefs_post.lua runs it on the table UnitDefs (the unit definitions before the game,
-- the same on every computer because the option is part of the start script). lan_lobby.lua of the host reads it from LuaMenu/Config/lan_raptor_brood.txt
-- (copied there by install_lan_play.ps1) and adds it when the room has a Raptors computer. A copy of the hive (model, script, build picture) with a list of
-- raptors to build; each raptor keeps its own price and build time.
local hive = UnitDefs and UnitDefs.raptor_hive
if not hive or UnitDefs.raptor_brood_chamber then
	return
end
local function copy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = type(v) == "table" and copy(v) or v
	end
	return out
end
local NAME, TIP = "Raptor Brood Chamber", "Grows raptors (built by the healers)"
local bc = copy(hive)
bc.unitname = "raptor_brood_chamber"
bc.name = NAME
bc.description = TIP
bc.metalcost = 300
bc.energycost = 3000
bc.buildtime = 6000
bc.health = 6000
bc.workertime = 200
bc.metalmake = 3
bc.energymake = 60
bc.energystorage = 1000
bc.builddistance = 120
-- the middle of the footprint stays open (y): the raptors grow in the middle and walk out
bc.yardmap = "oyyyyo yyyyyy yyyyyy yyyyyy yyyyyy oyyyyo"
bc.customparams = bc.customparams or {}
bc.customparams.isairbase = nil
bc.customparams.raptorbroodchamber = true
-- the hive's animation script knows no building: BAR's gadget unit_missing_build_scripts.lua (loaded when a tweakdefs option is set) puts such a builder into
-- the build stance (COB INBUILDSTANCE) and gives it a nano piece
bc.customparams.scriptlessbuilder = true
-- the name in the game: BAR's widget "Tweakdefs Custom Unit Names" reads i18n_<language>_humanname / _tooltip (the same English text for English and German)
for _, lang in ipairs({ "en", "de" }) do
	bc.customparams["i18n_" .. lang .. "_humanname"] = NAME
	bc.customparams["i18n_" .. lang .. "_tooltip"] = TIP
end
bc.buildoptions = {
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
for i = #bc.buildoptions, 1, -1 do
	if not UnitDefs[bc.buildoptions[i]] then
		table.remove(bc.buildoptions, i)
	end
end
UnitDefs.raptor_brood_chamber = bc
for _, name in ipairs({ "raptor_land_swarmer_heal_t1_v1", "raptor_land_swarmer_heal_t2_v1", "raptor_land_swarmer_heal_t3_v1", "raptor_land_swarmer_heal_t4_v1", "raptor_matriarch_healer" }) do
	local ud = UnitDefs[name]
	if ud then
		ud.buildoptions = ud.buildoptions or {}
		table.insert(ud.buildoptions, 1, "raptor_brood_chamber")
	end
end
