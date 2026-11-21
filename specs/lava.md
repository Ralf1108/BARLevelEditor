# Volcano, Lava Generator and Carrier

- A proof of concept: a **Volcano** placed in the Level Editor gives both resources:
  - a **Lava Generator** built on it makes energy at once and fills its own **metal stock**;
  - **Carriers** bring that metal to a factory; only there does the team get it;
  - a normal geothermal plant built on a Volcano makes its normal energy (the engine: the Volcano is a geothermal feature).
- The looks are stand-ins (a rock of BAR, the crack of BAR's geothermal vent, glowing rings; the generator looks like the metal extractor, the Carrier like the light bot); models of their own come later.
- User view: [Level Editor manual](../LevelEditor/README.md), "Volcano, Lava Generator and Carrier".

## 1. Parts

| File (repository) | In the extra games as | What it does |
|---|---|---|
| `LevelEditor/scripts/lava_volcano_def.lua` | `features/lava_volcano.lua` | the feature `lava_volcano` ("Volcano") |
| `LevelEditor/scripts/lava_generator_defs.lua` | `gamedata/unitdefs_pre.lua` | the units Lava Generator and Carrier and their place in the build lists |
| `LevelEditor/scripts/lava_generator.lua` | `luarules/gadgets/lava_generator.lua` | energy and metal stock on a Volcano, the hauling of the Carriers, the order Haul, the glow and the numbers |

- All three are in `$ScenarioGameFiles` (`shared/bar_common.ps1`), so they are in both extra games: "Level Editor" (`Get-EditorGameEntries` also takes the entries under `gamedata/` and `features/`) and "Level Editor Scenarios" (scenarios, LAN Play with the extra game).
- In the official game alone (without an extra game) none of them exists.

## 2. The Volcano (`lava_volcano`)

- BAR's `gamedata/featuredefs.lua` loads every `features/*.lua` of all game archives, also of the extra game.
- `geothermal = true`: the engine lets only buildings with a `g` in their yardmap stand on it and puts the geothermal smoke on it.
- `indestructible`, not reclaimable, not blocking; footprint 4 x 4.
- Model `rocks30/rocks30_def_01.s3o`, ground decal `editor_geovent_crack.dds` (6 x 6; both are files of BAR).
- `customparams.lavavolcano = 1`: the mark the gadget and the editor look for.
- Editor: its own kind **Volcano** in the Features tab (`M.FEATURE_KINDS`, `featureKind` in `editor_common.lua`: a feature with `customParams.lavavolcano`); saved in the level file like every feature.

## 3. The units (`gamedata/unitdefs_pre.lua`)

- BAR's `gamedata/unitdefs.lua` runs this file (if it exists) before it loads the unit files, with the still empty table of the unit definitions as `UnitDefs`.
  - BAR has no file of this name (game version test-31986); if BAR ships one later, the file of the extra game hides it: check after updates of BAR.
  - It sets a metatable with `__newindex` on that table: `unitdefs.lua` stores every unit with `unitDefs[name] = def`, so the hook sees each one.
  - `COPIES`: when a base unit is stored, its copy is stored next to it; a unit whose `buildoptions` hold the base unit gets the copy appended.
  - Legion copies exist only when Legion is on (its units are loaded only then).

| Copy | Base | Built by | Name |
|---|---|---|---|
| `armlavagen`, `corlavagen`, `leglavagen` | `armmex`, `cormex`, `legmex` | every builder of the extractor (constructors, commanders ...) | Lava Generator |
| `armlavacarrier`, `corlavacarrier`, `leglavacarrier` | `armpw` (Pawn), `corak` (Grunt), `leggob` | the bot labs (`armlab`, `corlab`, `leglab`) | Carrier |

- **Lava Generator** (`generator`): the model, script and corpse of the extractor; `extractsmetal = 0`, `energyupkeep = 0`, `energymake = 0`, `onoffable = false`, no metal storage.
  - Values of the proof of concept: metal 250, energy 2000, build time 6000, health 1200.
  - Yardmap `h cbbbbbbc bgbggbgb ...` (high resolution, with `g`): the engine requires a geothermal feature under it (`needGeo`). A constructor can place it only on a Volcano (or on a geothermal vent of the map: there it makes nothing).
  - `customparams.lavagenerator = 1`, `unitgroup = "energy"`; `metal_extractor` and `standardextractor` removed (BAR's metal spot tools leave it alone).
- **Carrier** (`carrier`): the light bot without weapons (`weapondefs`, `weapons` empty); metal 40, energy 600, build time 1500; `customparams.lavacarrier = 1`, `unitgroup = "util"`.
- Names: `name`, `description` and `i18n_en/de_humanname` / `_tooltip`.
- In the editor's unit list: the generator under its faction, **Buildings**, T1; the Carrier under **Bots**, T1 (the editor places units anywhere, also beside a Volcano).

## 4. The gadget `lava_generator.lua`

### 4.1 Generator

- Every second (`GameFrame`, `f % 30 == 7`) every Lava Generator is checked: finished and its middle at most `ON_RADIUS` = 40 Elmo from the middle of a Volcano?
  - yes → `Spring.SetUnitResourcing(u, "ume", LAVA_ENERGY)` (200 energy per second at once; a geothermal plant of tech 1 makes 300) and `LAVA_METAL` = 2 metal per second into its stock (`stock`, at most `STOCK_MAX` = 200; more is lost);
  - no → 0 energy, the stock does not grow.
  - Unit rules parameters (public): `lavaEnergy`, `lavaMetal` (what it makes now), `lavaStock`.
  - A Volcano placed or deleted later (editor, undo) counts within a second (`FeatureCreated` / `FeatureDestroyed` keep the list `volcanoes`).

### 4.2 Carrier and the order Haul

- `CMD_HAUL` = 39761, an order of its own (`InsertUnitCmdDesc` in `UnitCreated`: button "Haul", cursor Guard, type `ICON_UNIT`).
- Right click: the unsynced `DefaultCommand` returns `CMD_HAUL` when a Carrier is selected and the mouse is on a Lava Generator or a finished factory of the own team.
- `AllowCommand` (registered only for `CMD_HAUL` and the orders of `HAUL_STOP`: BAR's gadget handler gives an order only to the gadgets registered for its id):
  - Haul on a Lava Generator of its team → hauling from it (`src`; unit rules `lavaHauling` = 1);
  - Haul on a factory of its team → it delivers there (`dst`; unit rules `lavaDst`), also before the hauling;
  - the order Haul is used up there (returns false), it never stands in the queue;
  - Move, Stop, Patrol, Fight, Guard, Attack, Reclaim, Repair, Wait of a player (not `fromSynced`) end the hauling; the load stays.
- `haul` (every half second, `f % 15 == 3`):
  - empty: walk to the generator (`CMD.MOVE`, again when the queue is empty); at it (edge + `REACH` = 70 Elmo) take `LOAD` = 20 metal when the stock has 20, otherwise wait there;
  - loaded: walk to the chosen factory, otherwise the nearest finished factory of its team; at it the team gets the metal (`AddTeamResource`; team rules `lavaDelivered` counts all), then back;
  - no factory: it waits with its load; the generator gone: it stops.
  - Unit rules `lavaLoad`: the metal it carries.
- A Carrier given to another team forgets its generator and factory (`UnitGiven`).

### 4.3 Drawing (unsynced)

- `DrawWorldPreUnit`: six rings in red and orange around every Volcano in view, slowly pulsing (radius 25 to 80).
- `DrawScreen`: "Metal 34 / 200" over every working Lava Generator, the load ("20") over every loaded Carrier (light blue, `gl.Text`).
- Without a Lava Generator in the game (no extra game definitions) the gadget removes itself.

## 5. Tests

- `test-data/tools/zz_lava.lua` (`arena_test.ps1 -Widget zz_lava.lua`, one instance, about 2 minutes of game time):
  - the definitions (feature geothermal, `needGeo`, `extractsMetal` 0, the Carrier without weapons) and the build lists of `armck`, `armcv`, `armcom`, `corck`, `legck` and of the bot labs;
  - two Volcanoes and two generators placed through the editor messages: 200 energy and 2 metal on the Volcano, 0 beside it;
  - `TestBuildOrder`: allowed on the free Volcano, refused on plain ground; the geothermal plant `armgeo` allowed on the Volcano; a picture;
  - a Carrier has the button Haul; Haul on the generator: three loads of 20 to the near bot lab; Haul on the far lab: the next loads go there; `lavaDelivered` 100.
- Checked 2026-11-21: all of it as expected; the picture shows "Metal 12 / 200" over the generator.
- **Not checked:** a real right click (the test gives the order with `GiveOrderToUnit`); a constructor of a player really building a generator; several Carriers at one generator; a scenario or LAN game with it; the BAR build menu (where the buttons appear).

## 6. Open

- Models of their own (Volcano, Lava Generator, Carrier); the names in BAR's language files (the log says "not translated").
- Balance (costs, energy, metal, stock, load).
- A Lava Generator may also be placed on a geothermal vent of the map: there it makes nothing (the engine knows only "geothermal").

## 7. Tried and rejected

- **The order Guard as the right click of a Carrier** (caught in `AllowCommand`): with `RegisterAllowCommand(CMD.ANY)` and also with the id of Guard registered, the order never reached the gadget in the editor; the order Haul of its own works.
