# Volcano and Lava Generator

- A proof of concept: a **Volcano** placed in the Level Editor gives both resources:
  - a **Lava Generator** built on it makes energy and metal from the lava;
  - a normal geothermal plant built on it makes its normal energy (the engine: the Volcano is a geothermal feature).
- The looks are stand-ins (a rock of BAR, the crack of BAR's geothermal vent, glowing rings); models of their own come later.
- User view: [Level Editor manual](../LevelEditor/README.md), "Volcano and Lava Generator".

## 1. Parts

| File (repository) | In the extra games as | What it does |
|---|---|---|
| `LevelEditor/scripts/lava_volcano_def.lua` | `features/lava_volcano.lua` | the feature `lava_volcano` ("Volcano") |
| `LevelEditor/scripts/lava_generator_defs.lua` | `gamedata/unitdefs_pre.lua` | the units `armlavagen`, `corlavagen`, `leglavagen` ("Lava Generator") and their place in the build lists |
| `LevelEditor/scripts/lava_generator.lua` | `luarules/gadgets/lava_generator.lua` | the energy and metal on a Volcano; the glow of the lava |

- All three are in `$ScenarioGameFiles` (`shared/bar_common.ps1`), so they are in both extra games: "Level Editor" (`Get-EditorGameEntries` also takes the entries under `gamedata/` and `features/`) and "Level Editor Scenarios" (scenarios, LAN Play with the extra game).
- In the official game alone (without an extra game) neither exists.

## 2. The Volcano (`lava_volcano`)

- BAR's `gamedata/featuredefs.lua` loads every `features/*.lua` of all game archives, also of the extra game.
- `geothermal = true`: the engine lets only buildings with a `g` in their yardmap stand on it and puts the geothermal smoke on it.
- `indestructible`, not reclaimable, not blocking; footprint 4 x 4.
- Model `rocks30/rocks30_def_01.s3o`, ground decal `editor_geovent_crack.dds` (6 x 6; both are files of BAR).
- `customparams.lavavolcano = 1`: the mark the gadget and the editor look for.
- Editor: its own kind **Volcano** in the Features tab (`M.FEATURE_KINDS`, `featureKind` in `editor_common.lua`: a feature with `customParams.lavavolcano`); saved in the level file like every feature.

## 3. The Lava Generator (`armlavagen`, `corlavagen`, `leglavagen`)

- `gamedata/unitdefs_pre.lua`: BAR's `gamedata/unitdefs.lua` runs this file (if it exists) before it loads the unit files, with the still empty table of the unit definitions as `UnitDefs`.
  - BAR has no file of this name (game version test-31986); if BAR ships one later, the file of the extra game hides it: check after updates of BAR.
  - It sets a metatable with `__newindex` on that table: `unitdefs.lua` stores every unit with `unitDefs[name] = def`, so the hook sees each one.
  - When `armmex`, `cormex` or `legmex` is stored, its copy (`lavaCopy`) is stored next to it.
  - A unit whose `buildoptions` hold one of these extractors gets the Lava Generator of that faction appended (constructors, commanders ...).
  - `leglavagen` exists only when Legion is on (`legmex` is loaded only then).
- The copy: the model, script and corpse of the extractor; name "Lava Generator" (also `i18n_en/de_humanname`); `extractsmetal = 0`, `energyupkeep = 0`, `energymake = 0`, `onoffable = false`, no metal storage.
  - Values of the proof of concept: metal 250, energy 2000, build time 6000, health 1200.
  - Yardmap `h cbbbbbbc bgbggbgb ...` (high resolution, with `g`): the engine requires a geothermal feature under it (`needGeo`). A constructor can place it only on a Volcano (or on a geothermal vent of the map: there it makes nothing).
  - `customparams.lavagenerator = 1`, `unitgroup = "energy"`; `metal_extractor` and `standardextractor` removed (BAR's metal spot tools leave it alone).
- In the editor's unit list it is under its faction, **Buildings**, T1 (the editor places units anywhere, also beside a Volcano).

## 4. The gadget `lava_generator.lua`

- Synced: every second (`GameFrame`, `f % 30 == 7`) every Lava Generator is checked:
  - finished and its middle at most `ON_RADIUS` = 40 Elmo from the middle of a Volcano → `Spring.SetUnitResourcing(u, "ume", LAVA_ENERGY)` and `(u, "umm", LAVA_METAL)` (200 energy and 2 metal per second; a geothermal plant of tech 1 makes 300 energy, a metal extractor of tech 1 on a spot of 2.0 about 2 metal);
  - otherwise 0 of both.
  - Unit rules parameters `lavaEnergy` and `lavaMetal` (public): what it makes now.
  - A Volcano placed or deleted later (editor, undo) counts within a second (`FeatureCreated` / `FeatureDestroyed` keep the list `volcanoes`).
- Unsynced: `DrawWorldPreUnit` draws six rings in red and orange around every Volcano in view, slowly pulsing (radius 25 to 80).
- Without a Lava Generator in the game (no extra game definitions) the gadget removes itself.

## 5. Tests

- `test-data/tools/zz_lava.lua` (`arena_test.ps1 -Widget zz_lava.lua`, one instance):
  - the definitions (feature geothermal, `needGeo`, `extractsMetal` 0) and the build lists of `armck`, `armcv`, `armcom`, `corck`, `legck`;
  - two Volcanoes and two generators placed through the editor messages: 200 energy and 2 metal on the Volcano, 0 beside it;
  - `TestBuildOrder`: allowed on the free Volcano, refused on plain ground; the geothermal plant `armgeo` allowed on the Volcano; a picture.
- Checked 2026-11-21: all of it as expected.
- **Not checked:** a constructor of a player really building one; a scenario or LAN game with it; the BAR build menu (where the button appears).

## 6. Open

- Models of their own (Volcano, Lava Generator); the name in BAR's language files (the log says "not translated").
- Balance (cost, energy).
- A Lava Generator may also be placed on a geothermal vent of the map: there it makes nothing (the engine knows only "geothermal").
