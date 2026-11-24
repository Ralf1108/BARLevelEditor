# Level Editor: the Place menu, placing, Generate and blueprints

Part of the specification of the [Level Editor](level-editor.md) (structure, keys, menus, button column and strip, editing, levels, gadget, files).

What puts things onto the map: the Place menu with its preview, placing with the mouse, Generate with the maze and the delete tools, the blueprints. The sections keep the numbers they have in `level-editor.md` (6 to 9), so "see 6.1" means the same in both documents.

## 6. The Place menu

- **Search** (one field for Recent, Units, Features and Blueprints at once): the `search` table in the widget; `searchSet(q)` copies the query into `uGrid`, `fGrid`, `bpGrid` and `fav`.
  - Click and type words of the description or the code; all words must match; each tab shows its hits across all factions, groups and tech levels (features by code and description, blueprints also by the units inside, Recent by both of its parts; `fav:matchCount()`).
  - Enter ends the input, Esc clears, Backspace deletes a character.
  - The input runs through `OwnText` and `KeyPress`.
  - The field and its X button (`searchclear`, clears all lists) turn reddish while there is a text.
  - All lists have a scrollbar at the right edge.
- **Features tab:** kinds trees / rocks / crystals / volcano / wrecks / rest (volcano: `customParams.lavavolcano`, [Volcano, Lava Extractor and Carrier](lava.md); the others by name: `pilha_crystal*` = crystal (the nodes of [Reclaim the Fame](reclaim-the-fame.md)), `_dead` / `_heap` = wreck, tree / pine / palm … = tree, rock / stone … = rock; `burnable` = tree).
  - Pictures only, no names (section 6.1).
  - Clicking arms the feature: left click places (`led|feature|name|x|z|rot`, rotation = facing), right click ends, Del deletes the one at the mouse pointer.
  - Preview: circle (green / red).
  - Shift + drag places a row, Shift+Alt a rectangle (at most 2000, feature size from `FeatureDefs.radius` plus spacing).
- **Tweaks tab:** units with changed values from a `tweakunits` text: [tweaks.md](tweaks.md). It arms the normal unit stamp, so everything of section 7 applies.
- **Recent tab:** on top the recently chosen blueprints (up to 6 rows), below the recently placed units (symbols), at the bottom the recently placed features (two rows of picture tiles with their own scrolling; noted when a feature is placed, also by a row or rectangle).
  - File `LuaUI/Config/LevelEditorRecent.lua` (up to 24 names each).
  - A click arms the blueprint, unit or feature.
- **Finding a unit (crosshair button, `locate`, left of the search field):** a click starts the pick mode: a green crosshair hangs at the mouse pointer (`search.pick`, drawn in `widget:DrawScreen`).
  - A left click on a unit on the map (`Spring.TraceScreenRay`; on a wreck or heap the unit it came from, found by cutting `_dead` / `_heap` from the feature name) shows its tile in the Units list (`search.locate(name)` → `u:locate(name)` in `editor_common.lua`): the Place menu switches to Units, the search is cleared, faction, group and tech are set to those of the unit, the next draw scrolls the list so the tile is in the middle and its frame flashes green for two seconds.
  - Right click, Esc, the button again or any other mode ends the pick mode; a click without a unit says so in the chat and stays in the pick mode.
  - The window of the [restricted units](restrictions.md) (button R) uses the same `search.locate`.
- **Tooltips:** all buttons show an explanation when hovered. `Shared.drawTip` only notes the tooltip, `Shared.flushTip` draws it at the end of the frame so it lies above every panel and window ([Shared code](shared-code.md)).
- **Help button `?`** (action `led_helpbox`): the help board with keys and short explanations in sections; every click closes it.
  - The chat topics are `HELP.topics`, the board `HELP.sections` (both from `help_texts.lua`); the board shrinks its font to fit the screen and stays below the minimap.

### 6.1 3D preview and pictures

- **3D preview for all lists** (`Shared.drawUnitPreview`, `drawBlueprintPreview`, `drawFeaturePreview`; place `previewPos`: left of the team strip, otherwise right of the menu, at the height of the tile): hovering over a unit, a blueprint (all units in place, rotated by `h`), a feature or an item of the Recent tab shows a rotating 3D picture.
  - Units and blueprints need a small shader of their own (fixed lighting, team color from the texture alpha, `rawState = true`), otherwise they turn out dark; features run with the engine rendering (`gl.FeatureShape`, own projection with a large depth, texture `%-<id>:0`; blending off and no alpha writing because the texture alpha is a mask).
- Under the preview the info block ([Shared code](shared-code.md)); for a feature: code name, "Metal x   Energy y" and the description (`translatedDescription` or `description`).
  - For a blueprint tile: name, count and the sums of its units with the Eco time.
- **Feature pictures:** square tiles (`0.4 × UCELL`), per feature a 96 px picture rendered once into a texture when it first becomes visible (`featureThumb`, at most 3 new per frame, cache until quitting, `freeThumbs` in shutdown).
  - The texture output is upside down in this engine, so it is rendered with reversed height (`Ortho` with swapped edges).
- The 3D preview of units uses the BAR widget "DrawUnitShape GL4" or, as a fallback, `gl.UnitShape` (`/led_ghost` shows state and mode; for blueprints at most 150 models, the ones closest to the center).
  - The fallback is not finally confirmed in the real game.

## 7. Placing

- **Stamp modes** (mutually exclusive): unit, feature and blueprint. All end with a right click on the map; switching mode or settings ends them.
- **Rotation** in steps of 90°: unit stamp through `facing`, blueprint stamp through `bpRot` (offset and facing of all units rotate along; heading + 16384 per step).
  - Works the same in the preview and when placing.
  - The blueprint rotation is kept when the blueprint changes.
- **Painting:** an armed unit or feature (also the towers of the Tower Defense list) is placed on a left click and then after every footprint of pointer movement (footprint + spacing · 16 Elmo, per axis; chain along the straight line so fast moves leave no gaps) while the left button is held (`paintStart` / `paintSample` / `paintPlace`; `Shared.paintChain`).
  - One `led|step` per stroke, so Ctrl+Z takes the whole stroke back.
  - Blueprints are not painted.
- **Rows and rectangles:** Shift + left drag = row, Shift+Alt = rectangle (all placed on release as `led|place|…` messages in packets of 50 per update; at most 2000 units, 100 blueprint copies).
  - Spacing: footprint (or blueprint hull) plus spacing.
  - The preview shows all copies (models limited).
- **Spacing** (0 to 20, default 0): Alt+Z / Alt+X (a handler in front of the BAR build menu `gridmenu_key` catches the keys), the BAR action `buildspacing inc/dec`, mouse side buttons 4 / 5 with Shift, Shift + mouse wheel.
  - Shown in the hint above the menu.
- **Write (W) and occupied spots:** `makeRoom(name, x, z, face, isFeature)` decides for every spot.
  - W **on** (default): what is in the way is deleted (`collectBlockers`: ground units and features overlapping the footprint, not what was placed a moment ago, `recentPlaced`, 2 s; `led|clearids|u12,u13,f7` in packets of 100, the gadget deletes them with `clearThese`, quietly, in the step opened by `ledStep`, so Ctrl+Z brings them back) and the new thing is placed.
  - W **off**: `blocked()` refuses an occupied spot (the footprint overlaps another ground unit or a unit placed a moment ago; a feature also overlaps other features by radius; aircraft are not checked, units may stand on features): single clicks and strokes say "Occupied ...", rows and rectangles skip the spots and report how many, a blueprint or paste (`placeBlueprintUnits`) is placed only partly, corridor wall pieces (`td.buildWalls`, `td.wallCell`) skip them.
  - **Generate** is independent of W: the gadget (`generate`) rejects a spot where a ground unit stands (radius test, buildings also `TestBuildOrder`) and tries another one in the area.

## 8. Generate, maze and delete

- **Generate menu** (button G; `gen.open`, `genLayout`): two sub-tabs.
- At the bottom of both is the **Area** row (Rectangle / Circle): pressing one starts the generating (`gen.arm(shape)`; there is no Generate button; the same shape again ends it; the pressed shape is shown as active only while armed).
- The team comes from the strip (N for neutral).
- Right click or arming something else ends the mode, the page stays open.

- **Units:** faction (Armada / Cortex / Legion / Scavengers / Raptors, single choice; the gadget picks the `_scav` copies or the `raptor_` units, which exist only with switch 7 of the start menu), type (units, buildings, turrets, air, ships; toggle buttons, multiple choice, default Units; none chosen = message), tech T1 / T2 / T3 (toggles; none = all), count (input field: click, type, Enter or a click elsewhere accepts, Esc discards; 1 to 2000, default 100; the total is split over the chosen types, the remainder goes to the first ones).
  - After pressing the shape drag the area (yellow frame; for a circle the press point is the center and the distance to the mouse the radius).
  - On release the widget sends per chosen type `led|generaterect|team|x1|z1|x2|z2|count|techs|faction|kind|neutral` or `led|generate|team|x|z|count|radius|techs|faction|kind|neutral`; the gadget distributes the units randomly and evenly (same pool, ground and spacing rules as above) and notes them in the history (one step).
- **Maze:** faction (shared with the Units sub-tab; only Armada, Cortex and Legion have dragon teeth and walls, with Scavengers or Raptors chosen the maze is Armada's, `gen.mazeFaction`), material (**dragon teeth** `<faction>drag` or **walls** `armfort` / `corfort` / `legforti`; a click only chooses it, `gen.mazeSel`) and the corridor width (2, 4, 8, 10 or 12 tiles = 32, 64, 128, 160 or 192 Elmo, the widths of the Tower Defense corridors; default 64; `gen.mazePath`).
  - The Area row switches the maze mode on (the same shape again off), then drag the area.
  - With a circle the maze is built in the bounding square and walls outside the circle are left out.
  - Key M cycles the mode (off → teeth → walls → off).
  - A random fully connected maze appears on release (depth-first search, `Shared.mazeWalls`; no cycle; tile 16 Elmo; walls 1 tile; entrance top left, exit bottom right).
  - The rectangle is cut to whole cells (preview frame green, red = too small: at least 2 × 2 cells, i.e. 2·(corridor tiles + 1) + 1 tiles per side, 11 for the default corridor of 4 tiles) and capped at about 12000 wall units (about 190 × 190 tiles).
  - Team and neutral as when placing; one step for Ctrl+Z; right click ends, and so does arming anything else (`widget:Update` checks that).
- The maze mode, the Generate mode and the delete modes exclude each other.

- **Delete in a line, rectangle or circle** (buttons DL, DR, DC; key D = DR): drag the shape with the left button (red frame; for the line the corridor of `DEL_HALF_WIDTH` = 40 Elmo to each side is shown, for the circle the press point is the center).
- On release the widget sends `led|clearrect|x1|z1|x2|z2`, `led|clearcircle|x|z|radius` or `led|clearline|x1|z1|x2|z2|halfwidth`; the gadget (`clearThese`) deletes all units (any team, also Gaia) and all features in it and notes everything in the history (one step).
- The state is `delMode` = false | "line" | "rect" | "circle".
- Right click, D again or arming a unit, blueprint or feature ends the mode.

## 9. Blueprints

- **Create** writes the selected units (all kinds, with team, neutral flag and the indestructible flag) as a layout, positions relative to the center of the selection, `rot` = heading, `h` = height above ground.
  - After saving: re-read the list, choose the blueprint, add it to the index.
- Placing runs through a load queue (50 units per update) and the gadget.
  - Sorting (`_order.txt`), deleting into the trash (never for good) and renaming (copy under the new name, original into the trash): [Shared code](shared-code.md).
  - A saved blueprint contains only the units you selected.
  - A blueprint does not carry the tweak of a [tweaked unit](tweaks.md): it is placed as the normal unit.
