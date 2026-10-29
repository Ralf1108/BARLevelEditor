# Reclaim the Fame

Button **RF** (gadget `rtf_game.lua`, page `led_rtf.lua`). Crystals stand on the map. A construction unit of an allowed kind (ground and ships by default) that reclaims a crystal earns points for its ally team: 1 point per second for every 100 build power, times the rate of the level and times the factor of the crystal size (small 100 %, medium 200 %, large 400 % by default); linear, no diminishing returns. The crystal is never used up and gives no resources. The first ally team at the score limit (default 100000; 0 = never) wins. Idea and open questions: issue 2 of the repository. User view: [Reclaim the Fame manual](../LevelEditor/game-modes/reclaim-the-fame.md).

## 1. The nodes are features

- The crystals `pilha_crystal1` (small), `pilha_crystal2` (medium) and `pilha_crystal3` (large) of the game, each also in ten colors (`pilha_crystal_blue1` ... `_violet3`: 33 feature defs). Every feature of the map whose name matches `^pilha_crystal[%a_]*([123])$` is a node (the digit is the size), so crystals are placed, moved, deleted and saved like any other feature and the crystals a map brings itself count too. There is no list of nodes in the level file.
- Place menu, tab Features, kind **Crystals**: `featureKind` in `editor_common.lua` puts `pilha_crystal*` there before the rule for rocks; `M.FEATURE_KINDS` has the entry between Rocks and Wrecks.

## 2. Widget

- `led_rtf.lua` (`luaui/Include/led_rtf.lua`, loaded like `led_ctf.lua`; the widget keeps one local variable `rtf`) gets a `host` with `Shared`, `cfg` (settings of the widget, for the size of the lists), `S()`, `say`, `canEdit`, `serialize` (= `td.lua`), `armFeature(name)` (arms placing of a feature like a click on its tile in the Features list), `armedFeature()`, `disarmAll`, `excludeOthers`, `restrictStart` / `restrictStop`, `beforePlay` / `afterPlay`.
- The page: `rtf.layout(rect)`, `draw`, `press`, `key`, `text`, `finish`, `height`, `payload`, `toggle`, `counts`, `grid`, `cfg`, `lua`. Hooks in the widget as for `ctf`: header button (`kind = "rtf"`), panel size, title "Level Editor - Reclaim the Fame", press, text and key input, mouse wheel, saving and loading, `DebugRtf`. No pick mode, no undo of its own (the crystals are features and have the undo of features).
- **Exclusive** with the other two game modes (`host.excludeOthers()` switches Tower Defense and Capture the Flag off; `tdon` and `ctfon` switch Reclaim the Fame off).

## 3. Data and page

Section `reclaim` of the level file (`saveLevel` through `td.lua`, `load_level` into `rtf.data` with `knownFields`):

| Field | Meaning |
|---|---|
| `enabled` | the mode is on |
| `score` | 0 to 9999999, default 100000 |
| `rate` | percent, 1 to 10000, default 100 |
| `f1`, `f2`, `f3` | factor of a small / medium / large crystal in percent, 0 to 100000; defaults 100 / 200 / 400 |
| `visible` | default true |
| `statics` | buildings (nano turrets) score, default false |
| `ground`, `ships` | default true |
| `air` | default false |

Page, top to bottom: checkbox `rtfon`; the line "On the map: n small, n medium, n large" (`rtf.counts()`, counted at most twice a second) and, in orange, a hint when the number of crystals is even and above 1 (both sides could farm in peace); the three factor fields; score limit; rate; box `rtfvisible` (crystals always visible) and the four buttons "Builders that score" (`rtfcat`: Buildings, Ground, Ships, Air, in that order, each a switch); `rtfplay` (Start / Stop / Reset); at the very bottom the crystals: the size filter All / Small / Medium / Large (`rtfsize`, `rtf.sizeFilter`) and a tile list (a `Shared.newFeatures` instance with `kind = "crystal"` and its `list` replaced: ordered by size, then by name). The tiles are those of the Features tab (3D preview at the mouse pointer, the armed crystal is blue); a click arms placing, left click on the map places, right click ends, Del deletes. The list has no scrolling: `rtf.layout` computes its height (`colsFor`, `geom`) and keeps the rectangle in `rtf.gridRect`; the panel is as high as the page. Number fields: `rtfedit`, up to 7 digits.

## 4. Gadget `rtf_game.lua`

- **Input:** payload `rate;score;f1;f2;f3;visible;cats` (`cats` = four digits for buildings, ground, ships, air; "0110" by default) by message `rtf|start|...` (`rtf|stop`; only with cheats or in the editor) or the game option `rtfconfig` (base64url, `decode64` of `bar_rules.lua`; starts at frame 30 so that the features of a scenario exist).
- **New feature IDs:** `start` collects the crystals of the map, destroys every one and **creates it again** (same place and heading) with 0 metal and energy: BAR's widget `gui_reclaim_field_highlight` shows the metal and the energy of a reclaimable feature (two numbers, as soon as a reclaimer is selected), reads them when the feature is created and ignores features below 9 (`minFeatureValue`); setting 0 afterwards on the old feature only changed the numbers to "0". The old values are kept and given back by `clear`. In the editor the gadget tells the editor gadget the new IDs (`GG.LevelEditor.replaceFid(old, new)`), so the undo steps (placing, deleting, moving of a crystal) still find the crystal after a test. The unsynced part writes one number over each crystal instead: its factor ("x5" = 5 points per second for every 100 build power at the basic rate, billboard text from `DrawWorld`).
- **Reclaim counting:** `AllowFeatureBuildStep(builder, team, feature, defID, part)` with `part < 0` on a node returns `false` (no resources move, the crystal is not used up) and records the frame of that builder. **It also sets the reclaim fraction back to 1** (`Spring.SetFeatureReclaim`): the engine lowers the fraction even when the step is refused, and at 0 the reclaim order ends. `GameFrame` gives every builder whose last step is at most 3 frames old `buildSpeed / 100 * rate / 100 * factor / 30` points (the engine reports the step every frame while the builder reclaims, so only active reclaiming counts). `FeaturePreDamaged` returns 0, 0 for nodes. The points belong to the ally team of the builder's team (`g.score[ally]`).
- **Which builders count** (`category(ud)`): **static** = `speed` 0 (nano turrets; `isBuilding` is false for them), **air** = `canFly` (builder aircraft, seaplanes), **ship** = movement class `boat*` or `uboat*`, otherwise **ground** (bots, vehicles, hovercraft `hover*`, amphibious `atank*`, commanders). Ground and ships are on by default: a ring of cheap nano turrets (range 400) would farm a crystal without any builder to hunt, and builder aircraft reach a crystal from anywhere and ignore the space around it.
- **Win:** score limit reached: `finish(ally)`: every ally team that is not the winner loses, its units blow up (and what it builds later, every second), `Spring.GameOver` outside the editor.
- **Display:** game rules parameters `rtfState` ("", "running", "won by alliance N"), `rtfScore<ally>`, `rtfRate<ally>` (points per second, published twice a second), `rtfTarget`, `rtfTeams`, `rtfOut`, `rtfNodes` ("x,z,size,factor/..."), `rtfVisible`. The unsynced part draws a gold ring around every crystal (the area from which a builder with a reach of 130 Elmo reaches it, plus a thin inner ring), gold diamonds on the minimap (bigger for bigger crystals; with `visible` off only where a unit or radar sees, `IsPosInLos` / `IsPosInRadar`; the crystals are `SetFeatureAlwaysVisible` with `visible`) and the score line "Alliance 0: 123/100000 (+21.0/s)" (`DrawScreen`, 175 pixels below the top edge), so a finished scenario needs no widget.
- **Start of the page** as for the other modes: `beforePlay` (saves `_beforeplay`), `restrictStart`, `rtf|start|...`; Stop sends `rtf|stop`, `restrictStop` and `afterPlay` (loads `_beforeplay`: crystals a builder may have used up, and the settings, come back).

## 5. Scenario

`Read-Reclaim` in `scenario_builder.ps1` reads the section (on only; the crystals must exist in `$level.features`, otherwise a note and the scenario is built without the mode). `rtfconfig` (base64url of the payload), `rtf_game.lua` and `bar_rules.lua` go into the package; the computer opponents get NullAI and the win condition is "no end" (the gadget decides); the starter starts it with the extra game "Level Editor Scenarios <version>" ([Scenario builder](scenario-builder.md)). The crystals are normal features of the level, so the scenario mechanism of the game creates them. A level with another mode on as well is refused by the script.

## 6. Not tested

Real ships on water (the test ship stood on land; its movement class `boat3` is what counts); several builders of different teams on one crystal in the same moment; a very large number of builders; play with two human clients over the network (the gadget does not depend on who gives the orders); builders with a modified build speed (the points use `UnitDefs[..].buildSpeed`); crystals a map brings itself.

## 7. Open

Balance (default factors 1 : 2 : 4, rate, score limit); whether nano turrets should score; random places for the crystals at the start (the issue wants an odd number in the middle third of the map; today the level maker places them); a computer opponent that farms crystals; a custom crystal model.
