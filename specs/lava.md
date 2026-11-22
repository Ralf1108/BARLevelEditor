# Volcano, Lava Extractor, Carrier, Cargo Truck and Forklift

- A proof of concept: a **Volcano** placed in the Level Editor gives both resources:
  - a **Lava Extractor** built on it makes energy at once and fills its own **metal stock**;
  - **Carriers** (bots), **Cargo Trucks** and **Forklifts** bring that metal to a factory; only there does the team get it;
  - a normal geothermal plant built on a Volcano makes its normal energy (the engine: the Volcano is a geothermal feature).
- The looks: the Volcano has a model of its own (a crater of dark rock; the gadget draws a moving lake and three streams of lava in it), the Carrier looks like the light bot; the Lava Extractor has a model of its own (a furnace with lava and a storage yard), the Cargo Truck and the Forklift have models of their own, made from BAR's missile truck and scout car.
- User view: [Level Editor manual](../LevelEditor/README.md), "Volcano, Lava Extractor and Carriers".

## 1. Parts

| File (repository) | In the extra games as | What it does |
|---|---|---|
| `LevelEditor/scripts/lava_volcano_def.lua` | `features/lava_volcano.lua` | the feature `lava_volcano` ("Volcano") |
| `LevelEditor/scripts/lava_generator_defs.lua` | `gamedata/unitdefs_pre.lua` | the units Lava Extractor and Carrier and their place in the build lists |
| `LevelEditor/scripts/lava_generator.lua` | `luarules/gadgets/lava_generator.lua` | energy and metal stock on a Volcano, the hauling of the Carriers, the order Haul, the glow and the numbers |
| `LevelEditor/models/armlavatruck.s3o` (made by `make_lava_truck.py`) | `objects3d/Units/armlavatruck.s3o` | the model of the Cargo Truck |
| `LevelEditor/models/armlavafork.s3o` (made by `make_lava_forklift.py`) | `objects3d/Units/armlavafork.s3o` | the model of the Forklift |
| `LevelEditor/scripts/lava_forklift_script.lua` | `scripts/Units/armlavafork.lua` | the unit script of the Forklift (wheels, the boxes) |
| `LevelEditor/models/lavavolcano.s3o`, `lavavolcano_color.png`, `lavavolcano_other.png` (made by `make_lava_volcano.py`) | `objects3d/Units/lavavolcano.s3o`, `unittextures/lavavolcano_*.png` | the model of the Volcano and its textures |
| `LevelEditor/models/lavagen.s3o` (made by `make_lava_generator.py`) | `objects3d/Units/lavagen.s3o` | the model of the Lava Extractor (all three factions) |
| `LevelEditor/scripts/lava_generator_script.lua` | `scripts/Units/lavagen.lua` | the unit script of the Lava Extractor (wheel, pistons, lava drops, the blocks of the yard) |

- The five Lua files are in `$ScenarioGameFiles` (`shared/bar_common.ps1`), so they are in both extra games: "Level Editor" (`Get-EditorGameEntries` also takes the entries under `gamedata/`, `features/` and `scripts/`) and "Level Editor Scenarios" (scenarios, LAN Play with the extra game).
- Models: every `LevelEditor/models/*.s3o` goes as it is (bytes) into both extra games as `objects3d/Units/<file>`, every `*.png` (a texture) as `unittextures/<file>` (`Get-ModelFiles` and `Get-ModelArchivePath` in `bar_common.ps1`, used by `Write-ScenarioGame` and `Write-EditorGame`; part of the version of the scenario game and of the stamp of the setup).
- In the official game alone (without an extra game) none of them exists.
- The game option `lanexpunits=0` (LAN Play, the button **Experimental Units** off while the game uses the extra game) leaves all units out: `unitdefs_pre.lua` returns before it hooks the table. `lanexpunits=1` or no option: they are in ([LAN Play](lan-play.md), "Experimental Units").

## 2. The Volcano (`lava_volcano`)

- BAR's `gamedata/featuredefs.lua` loads every `features/*.lua` of all game archives, also of the extra game.
- `geothermal = true`: the engine lets only buildings with a `g` in their yardmap stand on it and puts the geothermal smoke on it.
- `indestructible`, not reclaimable, not blocking (units walk through the rock); footprint 6 x 6 (the Lava Extractor); collision cylinder 196 x 22; no ground decal.
- Model `Units/lavavolcano.s3o` (2.1); the lava in it is drawn by the gadget (4.3).
- `customparams.lavavolcano = 1`: the mark the gadget and the editor look for.
- Editor: its own kind **Volcano** in the Features tab (`M.FEATURE_KINDS`, `featureKind` in `editor_common.lua`: a feature with `customParams.lavavolcano`); saved in the level file like every feature.

### 2.1 The model of the Volcano (`LevelEditor/models/make_lava_volcano.py`)

- Made from scratch, no file of BAR: a floor of hot rock (height 0.6, from radius 37 under the edge of the lake to under the wall) and a ring wall of rock around it, 48 parts around, rings across: inner foot (radius 62, height 0), crest (radius 72, height 20 +- 4), outer foot (radius 98); every part a little shifted (2 inwards to 4 outwards; fixed random numbers: the same model every time).
  - Four passes (0, 90, 180, 270 degrees: the four directions a building can face): the crest is flat at 0.6 (the floor of the crater) for 11 degrees to each side, then rises to 21 degrees; textured with the cold half (cooled rock, a road); the floor of the crater in front of them too. The yard of a Lava Extractor faces one of them, whichever way it was built; Carriers drive through it (4.2).
  - 72 parts around (5 degrees: the flat road of a pass is 20 degrees wide, 21 Elmo at the inner foot, 34 at the outer).
  - Two breaches (45 and 225 degrees from +x towards +z, between the passes, 14 degrees to each side): the crest goes down to 2.5 in their middle; the streams of lava run through them.
  - Nine boulders on the outer slope (five-sided, 3.5 to 7 wide), not in the breaches or the passes.
  - The lake (radius 40) is small enough for the platform of a Lava Extractor (88 x 80, corners at radius 59.5) to cover it; the wall stands just outside those corners (it does not look as if the extractor swam in the lava).
- Textures of its own (512 x 512, made by the script with numpy and Pillow): plates of dark rock with cracks between them (a Voronoi pattern that tiles).
  - Upper half: the cracks glow orange (also the red channel of `lavavolcano_other.png`: they shine); the inner wall of the crater uses it.
  - Lower half: the cracks are darker than the rock; the outer slopes and the boulders use it.
  - Green channel of the second texture 0: the rock does not reflect the sky; color alpha 0 (no team color).
  - The engine reads a PNG texture of a model upside down compared with BAR's DDS textures: the script saves the images flipped, the texture areas count v from the top like those of the units.
- Header: radius 95, height 24, middle (0, 8, 0).

## 3. The units (`gamedata/unitdefs_pre.lua`)

- BAR's `gamedata/unitdefs.lua` runs this file (if it exists) before it loads the unit files, with the still empty table of the unit definitions as `UnitDefs`.
  - BAR has no file of this name (game version test-31986); if BAR ships one later, the file of the extra game hides it: check after updates of BAR.
  - It sets a metatable with `__newindex` on that table: `unitdefs.lua` stores every unit with `unitDefs[name] = def`, so the hook sees each one.
  - `COPIES`: when a base unit is stored, its copy is stored next to it; a unit whose `buildoptions` hold the base unit gets the copy appended.
  - Legion copies exist only when Legion is on (its units are loaded only then).

| Copy | Base | Built by | Name |
|---|---|---|---|
| `armlavagen`, `corlavagen`, `leglavagen` | `armmex`, `cormex`, `legmex` | every builder of the extractor (constructors, commanders ...) | Lava Extractor |
| `armlavacarrier`, `corlavacarrier`, `leglavacarrier` | `armpw` (Pawn), `corak` (Grunt), `leggob` | the bot labs (`armlab`, `corlab`, `leglab`) | Carrier |
| `armlavatruck` | `armsam` (Samson, missile truck) | the vehicle plant `armvp` | Cargo Truck |
| `armlavafork` | `armfav` (Rover, scout car) | the vehicle plant `armvp` | Forklift |

- **Lava Extractor** (`generator`): a copy of the extractor with `objectname = "Units/lavagen.s3o"`, `script = "Units/lavagen.lua"` (3.4, 3.5), the corpse of the extractor; `extractsmetal = 0`, `energyupkeep = 0`, `energymake = 0`, `onoffable = false`, no metal storage.
  - Footprint 6 x 6 (the extractor: 4 x 4; the yard needs the room), collision box 88 x 40 x 80 (offset y 18).
  - Values of the proof of concept: metal 250, energy 2000, build time 6000, health 1200.
  - Yardmap 12 x 12 in high resolution: `o` blocked, `g` in a checker pattern on the side of the furnace (geothermal: the engine requires a geothermal feature under it, `needGeo`; within 6 * 8 - 4 = 44 Elmo of its middle), `y` the yard: the five columns on the right (+x of the model, rows 1 to 10), free while the yard is open (the unit script opens it at once): Carriers drive in. A constructor can place it only on a Volcano (or on a geothermal vent of the map: there it makes nothing).
  - `customparams.lavagenerator = 1`, `unitgroup = "energy"`; `metal_extractor` and `standardextractor` removed (BAR's metal spot tools leave it alone).
- **Carrier** (`carrier`): the light bot without weapons (`weapondefs`, `weapons` empty); metal 40, energy 600, build time 1500; `customparams.lavacarrier = 1`, `unitgroup = "util"`; 20 metal per trip.
- **Cargo Truck** (`truck`): armsam without weapons (also `airsightdistance` and `maxrange` removed), `objectname = "Units/armlavatruck.s3o"`; the script of armsam (`ARMSAM.cob`: the wheels turn; it names the emptied launcher pieces, which stay); metal 90, energy 900, build time 2500, health 900; `customparams.lavacarrier = 1`, `lavaload = 60` (60 metal per trip), `unitgroup = "util"`.
- **Forklift** (`forklift`): armfav without weapons, `objectname = "Units/armlavafork.s3o"`, `script = "Units/armlavafork.lua"` (a Lua unit script, see 3.3); slow (speed 45, armsam 55, armfav 168), turn rate 400, sight 300; metal 120, energy 1200, build time 3000, health 1000; collision box 16 x 22 x 32; `customparams.lavacarrier = 1`, `lavaload = 90`, `lavabox = 30` (up to 3 boxes of 30 metal), `unitgroup = "util"`.
- Names: `name`, `description` and `i18n_en/de_humanname` / `_tooltip`.
- The ids and file names keep "lavagen" / `lava_generator` (the unit was first called Lava Generator; the shown name is Lava Extractor, like BAR's Metal Extractor).
- In the editor's unit list: the generator under its faction, **Buildings**, T1; the Carrier under **Bots**, T1; the Cargo Truck and the Forklift under Armada, **Vehicles**, T1 (the editor places units anywhere, also beside a Volcano).

### 3.1 The model of the Cargo Truck (`LevelEditor/models/make_lava_truck.py`)

- Reads `objects3d/units/armsam.s3o` from the newest BAR package of the installation (`packages/*.sdp`, `pool/`), writes `armlavatruck.s3o` next to itself (committed; run it again after a change of the script or of armsam).
- S3O read and written by the script itself (header, pieces with vertices of 8 floats and triangle indices).
- The pieces `turret` and `mlauncher` (the rocket launcher) lose their vertices; they stay as pieces because the script of armsam names them.
- A new piece `cargo` (child of `base`): a box x -10.5 to 10.5, y 12 to 22, z -21 to 6.5 (the cab ends at z 8) and a stripe 1.6 high a little outside both walls.
  - Texture areas of `Arm_color.dds` (u, v from the top; s3o t = 1 - v): walls and ends `PLATE` (the large grey plate with panels), roof `GRATE` (the grate with the yellow frame), stripe `TEAM` (a bar of the team color mask: the stripe shows the team color).
- Header: height 22, radius 25, middle (0, 9, -2).
- The model of armsam is a work of the BAR team (author in its definition: Beherith); the copy is under the same licence.

### 3.2 The model of the Forklift (`LevelEditor/models/make_lava_forklift.py`)

- Reads `objects3d/units/armfav.s3o` the same way (it imports the reader, writer and `box` of `make_lava_truck.py`), writes `armlavafork.s3o`.
- The piece `gun` (with `flare`) is removed (the unit script of the Forklift is its own, nothing names them).
- New pieces, children of `base` (the front is +z; the front wheels end at z 12.5):

| Piece | Where | Looks |
|---|---|---|
| `guard` | four posts and a roof over the seat, y 10 to 19.8, z -7 to 5 | dark plate, roof the grate |
| `weight` | a counterweight at the back, z -12.5 to -8.5 | `PLATE`, a stripe in team color |
| `mast` (offset z 12.6) | two rails y 2 to 25, a bar on top in team color | dark plate |
| `fork` (child of `mast`, offset y 2.6) | the carriage and two tines 11 long | dark plate |
| `box1`, `box2`, `box3` (children of `fork`) | 8 x 4.6 x 9.4 each, one above the other (offsets y 0.8, 5.6, 10.4) | sides `CRATE` (the yellow panel with a dark frame), top the grate |

- Texture areas: `CRATE = (0.7552, 0.6671, 0.8016, 0.6960)`, `DARK = (0.255, 0.695, 0.278, 0.745)` of `Arm_color.dds`.
- Header: height 25, radius 22, middle (0, 10, 1).
- The model of armfav is a work of the BAR team (author in its definition: Flaka); the copy is under the same licence.

### 3.3 The unit script of the Forklift (`lava_forklift_script.lua`)

- A Lua unit script: BAR's gadget `unit_script.lua` loads every `scripts/**/*.lua` of the game archives and runs the one whose name the unit definition gives (`script`).
- `Create`: no box. `StartMoving` / `StopMoving`: the three wheels turn. `Killed`: the mast flies off; the wreck of armfav, when hit hard its heap.
- `SetBoxes(n)` (a global of the script): shows `box1` .. `boxn`, hides the others; the fork goes up 2.5 while it carries, down when empty.
- The gadget calls it: `Spring.UnitScript.GetScriptEnv(u).SetBoxes` with `Spring.UnitScript.CallAsUnit` (both of `unit_script.lua`; `callScript` of the gadget).

### 3.4 The model of the Lava Extractor (`LevelEditor/models/make_lava_generator.py`)

- Made from scratch (no BAR model is read): boxes and eight-sided prisms (`face`, `box`, `prism_y`, `prism_x`), texture `Arm_color.dds` / `Arm_other.dds` for all three factions; the team color shows on a band of the furnace and on the posts and rails of the yard.
- The middle of the model stands on the Volcano; the front is +z.

| Piece | What | Texture areas |
|---|---|---|
| `base` | platform 88 x 80; furnace (8 sides, radius 14, up to y 30, two copper bands), a band in team color, a cone up to y 39, a short stack (glowing top); a chimney up to y 60 behind it; the spout and the basin of the pool in front; the axle of the wheel; the cylinders of the pistons; a copper pipe to the yard; the yard (x 10 to 44): floor, 8 posts, rails | `PLATE`, `DARK`, `COPPER`, `TEAM`, `MATTE` (floors), `LAVA` |
| `lava` | streams down the cone, the band and the furnace (five sides; the front goes into the spout), the fall at the front, the pool | `LAVA` |
| `drop1` .. `drop3` | small drops at the spout (they fall) | `LAVA` |
| `wheel` | a gear wheel (16 teeth, 4 spokes) on the left, axis x | `COPPER`, `DARK` |
| `piston1`, `piston2` | rods behind the furnace | `SILVER`, `COPPER` |
| `block1` .. `block15` | metal blocks 6.8 x 4.2 x 8.8 in the yard: 3 columns, 5 rows | `SILVER` |

- Texture areas (u0, v0, u1, v1): `LAVA = (0.540, 0.021, 0.551, 0.039)` (orange; red channel of `Arm_other.dds` 247: it glows), `COPPER = (0.630, 0.262, 0.645, 0.280)`, `SILVER = (0.690, 0.078, 0.740, 0.108)`, `MATTE = (0.665, 0.471, 0.925, 0.489)` (a dark belt; green channel of `Arm_other.dds` 0: it does not reflect the sky), `DARK`, `PLATE`, `TEAM` as for the trucks.
- Header: height 60, radius 50, middle (0, 18, 0).

### 3.5 The unit script of the Lava Extractor (`lava_generator_script.lua`)

- `Create`: `SetUnitValue(COB.YARD_OPEN, 1)` (the cells `y` of the yardmap free), no block, no drop.
- `SetActive(on)` (called when the generator starts or stops working on a Volcano): on = the wheel turns (60 degrees per second), the pistons go up 4 and down (half a second apart), the drops fall 22 from the spout to the pool one after another (thread per part, signal `SIG_WORK`); off = all stops, the drops hide.
- `SetBlocks(n)`: shows `block1` .. `blockn`.
- `Killed`: the wheel flies off; the wreck of the extractor, when hit hard its heap.

## 4. The gadget `lava_generator.lua`

### 4.1 Generator

- Every second (`GameFrame`, `f % 30 == 7`) every Lava Extractor is checked: finished and its middle at most `ON_RADIUS` = 44 Elmo from the middle of a Volcano (as far as the engine lets it stand)?
  - yes → `Spring.SetUnitResourcing(u, "ume", LAVA_ENERGY)` (200 energy per second at once; a geothermal plant of tech 1 makes 300) and `LAVA_METAL` = 2 metal per second into its stock (`stock`, at most `STOCK_MAX` = 200; more is lost);
  - no → 0 energy, the stock does not grow.
  - Unit rules parameters (public): `lavaEnergy`, `lavaMetal` (what it makes now), `lavaStock`.
  - A Volcano placed or deleted later (editor, undo) counts within a second (`FeatureCreated` / `FeatureDestroyed` keep the list `volcanoes`).
  - Its looks (`showGen`, after every check and after a Carrier took metal; only on a change): `SetActive(on)` and `SetBlocks(ceil(stock * BLOCKS / STOCK_MAX))` of its unit script (`BLOCKS` = 15: a full stock shows all, any metal at least one).

### 4.2 Carrier and the order Haul

- `CMD_HAUL` = 39761, an order of its own (`InsertUnitCmdDesc` in `UnitCreated`: button "Haul", cursor Guard, type `ICON_UNIT`).
- Right click: the unsynced `DefaultCommand` returns `CMD_HAUL` when a Carrier is selected and the mouse is on a Lava Extractor or a finished factory of the own team.
- `AllowCommand` (registered only for `CMD_HAUL` and the orders of `HAUL_STOP`: BAR's gadget handler gives an order only to the gadgets registered for its id):
  - Haul on a Lava Extractor of its team → hauling from it (`src`; unit rules `lavaHauling` = 1);
  - Haul on a factory of its team → it delivers there (`dst`; unit rules `lavaDst`), also before the hauling;
  - the order Haul is used up there (returns false), it never stands in the queue;
  - Move, Stop, Patrol, Fight, Guard, Attack, Reclaim, Repair, Wait of a player (not `fromSynced`) end the hauling; the load stays.
- `haul` (every half second, `f % 15 == 3`):
  - empty: drive into the yard of the extractor (`toYard`); there (at most `AT_YARD` = 30 from the place of the piece `block8`, the middle of the yard, also when the extractor is turned) take its load per trip (`cap`: `customparams.lavaload`, otherwise `LOAD` = 20) when the stock has that much, otherwise wait there;
  - loaded: to the chosen factory, otherwise the nearest finished factory of its team (`toFactory`; at the factory: its edge + `REACH` = 70); there the team gets the metal (`AddTeamResource`; team rules `lavaDelivered` counts all), then back;
  - the way at an extractor on a Volcano (`ROUTE`; never over the wall or through a stream):
    - the pass: the one the yard faces; its direction is the direction from the middle of the extractor to the yard, rounded to one of the four;
    - the gate: outside the pass, `DETOUR` = 185 from the middle (the streams end at 160);
    - empty: not in the pass (more than `PASS_ANGLE` = 14 degrees off its direction and more than `ROAD` = 16 off its middle line) = to the gate, around the Volcano if needed; in the pass = along its middle line to the entrance of the yard (`ENTRY` = 46), then to the middle of the yard;
    - loaded: still nearer than `CLEAR` = 168 and at most `OUT_ANGLE` = 30 degrees off the pass = out to the gate first; then to the factory, around the Volcano if needed;
    - around (`around`): a straight way that comes nearer than `CLEAR` to the middle goes over fixed points on the circle `DETOUR` every 30 degrees (`GRID`) towards the side of the target (a point at most 10 degrees ahead counts as passed: `PAST`); the middle of a step stays 179 from the middle;
    - an extractor beside a Volcano: straight into its yard;
  - `walkPoint`: `CMD.MOVE` to a point, again when the point moves more than 16 or the queue is empty;
  - no factory: it waits with its load; the generator gone: it stops.
  - Unit rules `lavaLoad`: the metal it carries.
- A unit with `lavabox` (the Forklift) works in boxes:
  - at the generator: one box (`lavabox` metal) every half second while the stock has one and it has room (`lavaload`); it leaves when it is full or the stock has no box more and it has at least one (`go`); with no box it waits;
  - at the factory: one box every half second;
  - after every change of its load the gadget calls `SetBoxes(ceil(load / box))` of its unit script;
  - its generator gone while it has boxes: it brings them first, then it stops.
- A Carrier given to another team forgets its generator and factory (`UnitGiven`).

### 4.3 Drawing (unsynced)

- `DrawWorldPreUnit`: the lava of every Volcano in view (`LAVA`; its numbers must match the model, 2.1):
  - a lake (radius 40, 1.2 above the Volcano, on the floor of the crater; under the platform of an extractor) and a stream out of each breach (from radius 34 over the floor and through the breach to 160, 18 to 10 wide, winding outside the crater, on the rock of the breach or on the ground, fading out at the end; made once per Volcano: `streams`);
  - three layers: a dark red ground (the dark parts of BAR's lava texture `luaui/images/lava/lava7_diffuseemit.dds` are see-through), the lava texture, the same texture again moving the other way and adding light (`GL.ONE`);
  - the lake drifts slowly, the streams flow outwards (texture coordinates moved with the time), all of it pulses (0.82 to 1);
  - real time (`Spring.GetTimer`): the lava moves also while the game is paused (the editor).
- The geothermal smoke of the engine rises from the middle while nothing stands on it.
- `DrawScreen`: "Metal 34 / 200" over every working Lava Extractor, the load ("20") over every loaded Carrier (light blue, `gl.Text`).
- Without a Lava Extractor in the game (no extra game definitions) the gadget removes itself.

### 4.4 The test start (`start_experimental.bat`)

- `LevelEditor\start_experimental.bat [map]` (default `Full Metal Plate 1.7`) runs `ensure_installed.ps1`, then `scripts\start_experimental.ps1`: like `start_evolution.ps1` (`Resolve-ExtraGame`, `Start-ExtraGame`, the script in `LevelEditor\experimental_script_installed.txt`, ignored by git), you (Armada) against a NullAI (Cortex), `startpostype=0`, game options `deathmode=neverend`, `lanplay=1`, `lanexpunits=1`, `lanexpdemo=1`.
- `lanexpdemo=1`: at frame 5 the gadget places for team 0 (`placeDemo`, `Spring.CreateFeature` / `Spring.CreateUnit`, finished):
  - a Volcano with a Lava Extractor 380 from the start position towards the middle of the map;
  - a Carrier, a Cargo Truck and a Forklift 270 to the right of it, 60 apart, looking at it; a vehicle plant 470 to the right;
  - near the right edge of the map all of it to the left (the extractor turned: its yard faces the units);
  - a line in the console: select a vehicle, right-click the Lava Extractor.

## 5. Tests

- `test-data/tools/zz_lava.lua` (`arena_test.ps1 -Widget zz_lava.lua`, one instance, about 2 minutes of game time):
  - the definitions (feature geothermal, `needGeo`, `extractsMetal` 0, the Carrier without weapons) and the build lists of `armck`, `armcv`, `armcom`, `corck`, `legck` and of the bot labs;
  - two Volcanoes and two generators placed through the editor messages: 200 energy and 2 metal on the Volcano, 0 beside it;
  - `TestBuildOrder`: allowed on the free Volcano, refused on plain ground; the geothermal plant `armgeo` allowed on the Volcano; a picture;
  - a Carrier has the button Haul; Haul on the generator: three loads of 20 to the near bot lab; Haul on the far lab: the next loads go there; `lavaDelivered` 100.
- `test-data/tools/zz_lavatruck.lua` (`arena_test.ps1 -Widget zz_lavatruck.lua`, one instance): the Cargo Truck (no weapons, its model, `lavaload` 60, in the build list of `armvp`), two pictures close up (next to an armsam), then one trip: 60 metal from a Lava Extractor to the vehicle plant.
- `test-data/tools/zz_lavafork.lua` (`arena_test.ps1 -Widget zz_lavafork.lua`, one instance, about 2 minutes of game time): the Forklift (no weapons, its model and script, `lavaload` 90, `lavabox` 30, in the build list of `armvp`), two pictures of it empty (next to an armfav); the generator fills for 50 seconds, then Haul: 3 boxes loaded (picture), unloaded one by one at the vehicle plant, a second trip with what the stock has (picture).
- Checked 2026-11-21: all of it as expected; the picture shows "Metal 12 / 200" over the generator; the truck shows its container (picture `docs/lava-cargo-truck.jpg`).
- `test-data/tools/zz_lavagen.lua` (`arena_test.ps1 -Widget zz_lavagen.lua`, one instance, about 1.5 minutes of game time): the model and script of all three generators, footprint 6 x 6, `needGeo`; one on a Volcano (200 energy), one beside it (0); pictures close up at the start (from above and lower), after a minute (the yard fills), after a Forklift took 3 boxes (fewer blocks).
- `test-data/tools/zz_lavaroad.lua` (`arena_test.ps1 -Widget zz_lavaroad.lua`, one instance, 2 minutes of game time): two Volcanoes with an extractor each (build facing 0 and 1), a bot lab and a Carrier on the far side of each; the yard can be driven on (`TestMoveOrder`), the furnace side not; every half second: a Carrier over the wall (nearer than 100, not in the pass) or in a stream (12 degrees around a breach, nearer than 165) = WRONG; a picture of a Carrier loading in the yard.
- Checked 2026-11-22 (`zz_lavaroad.lua`): 8 and 11 loads, 0 times over the wall or the lava, 360 delivered (picture `docs/lava-carrier-yard.jpg`); `zz_lava.lua`, `zz_lavafork.lua` again: all OK.
- `test-data/tools/zz_expdemo.lua` (`arena_test.ps1 -Widget zz_expdemo.lua -ModOptions 'lanexpdemo=1;'`, one instance, 2 minutes of game time): what the test start places (all five, the Volcano), a picture, then Haul for all three vehicles; checked 2026-11-22: all placed, 200 delivered (a first run ended at frame 1362 without a Lua error, as if the window had been closed; the second one ran through).
- `test-data/tools/zz_volcano.lua` (`arena_test.ps1 -Widget zz_volcano.lua`, one instance, about 10 seconds of game time): the definition (model, geothermal), one Volcano alone, one with a Lava Extractor (200 energy); pictures from the angle of the game, one second later (the lava moved) and lower.
- Checked 2026-11-22 (`zz_volcano.lua`): the crater, the glowing inner wall, the lake and the streams show and move (picture `docs/lava-volcano.jpg`); `zz_lava.lua` again: all OK with the new Volcano.
- Checked 2026-11-22 (`zz_lavagen.lua`): stock 128 = 10 blocks, after the Forklift 48 = 4 blocks; the wheel, the lava and the yard show (picture `docs/lava-generator.jpg`); `zz_lava.lua` again: all OK with the footprint 6 x 6 (build rule, energy, hauling).
- Checked 2026-11-22 (`zz_lavafork.lua`): stock 102 when Haul was given, 3 boxes loaded in 1.5 seconds, unloaded 30 / 30 / 30 at the plant; the second trip again 3 boxes (the stock had refilled); 180 delivered; the boxes and the raised fork show (picture `docs/lava-forklift.jpg`).
- **Not checked:** a real right click (the test gives the order with `GiveOrderToUnit`); a constructor of a player really building a generator; several Carriers at one generator; a Forklift leaving with 1 or 2 boxes (the code path exists, the test had full stocks both times); a scenario or LAN game with it; the BAR build menu (where the buttons appear).

## 6. Open

- A model of its own for the Carrier; the Lava Extractor: its build picture is still the extractor's, the lava drops and the wheel are not checked moving (pictures only), one model for all factions; the names in BAR's language files (the log says "not translated").
- The Cargo Truck: its roof looks very bright (the grate area is shiny in the second texture); its wreck and build picture are still those of armsam; trucks for Cortex and Legion.
- The Forklift: its wreck and build picture are still those of armfav; forklifts for Cortex and Legion.
- Balance (costs, energy, metal, stock, load).
- A Lava Extractor may also be placed on a geothermal vent of the map: there it makes nothing (the engine knows only "geothermal").

## 7. Tried and rejected

- **`c` for the cells of the yard of the Lava Extractor:** not free for units (`TestMoveOrder` false, the Carriers stopped at its edge); `y` with the yard opened by the unit script works.
- **The order Guard as the right click of a Carrier** (caught in `AllowCommand`): with `RegisterAllowCommand(CMD.ANY)` and also with the id of Guard registered, the order never reached the gadget in the editor; the order Haul of its own works.
