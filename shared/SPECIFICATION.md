# Specification: Shared code (`editor_common.lua`)

Status: 2026-10-18 (with the search helpers, the scrollbar, the filtered blueprint grid, the maze generator and the English interface).

Status of the specification: everything that has been defined so far for the Level Editor and the BluePrinter and is implemented in `editor_common.lua`.
Related specifications: `..\LevelEditor\SPECIFICATION.md`, `..\BluePrinter\SPECIFICATION.md`.

## 1. Purpose and basic rules

- All visible texts of the shared code are English (since 2026-10-18); no umlauts in texts drawn into the game.
- A single file `shared\editor_common.lua` contains everything the Level Editor and the BluePrinter need in common. A change there affects both widgets.
- The module does not know any widget. Everything widget-specific comes in as options or callback functions (folders, texts, `say`, `ownText`, `onSelect`, `onArm`, `wg`).
- The module returns a table `M` and is loaded with `VFS.Include`. It only uses the Lua 5.1 environment present in BAR (`Spring`, `gl`, `GL`, `UnitDefs`, `UnitDefNames`, `WeaponDefs`, `VFS`, `io`, `os`, `math`, `string`, `table`). `WG` is not used globally but passed in through the option `wg`.
- Source code, texts and file names contain no reference to persons or private matters.

## 2. Loading and installation

| Widget | Load call | Source at runtime |
|---|---|---|
| Level Editor | `VFS.Include("luaui/Include/editor_common.lua", nil, VFS.ZIP_FIRST)` | in the extra game `LevelEditorMod.sdz` under `luaui/Include/editor_common.lua` |
| BluePrinter | `VFS.Include("LuaUI/Include/editor_common.lua", nil, VFS.RAW_FIRST)` | `data\LuaUI\Include\editor_common.lua` in the BAR write folder |

- `LevelEditor\install_editor.ps1` packs `shared\editor_common.lua` into the `.sdz`. `BluePrinter\install_blueprinter.ps1` copies the file to `data\LuaUI\Include`.
- Both scripts look for the file first in `..\shared\editor_common.lua` (next to the widget folder), otherwise as a copy in the widget folder, otherwise they abort with an error message.
- The two load paths are deliberately separate (ZIP_FIRST and RAW_FIRST) so the copy in the extra game is never covered by the copy for the BluePrinter.
- On a second computer the folders `shared`, `LevelEditor` and `BluePrinter` must lie next to each other.
- After every change to `editor_common.lua` run both installations again.

- **File access:** the code reads and writes files through `io.open` and `VFS.DirList`. User widgets (BluePrinter) may only read under `LuaUI/` and only write under `LuaUI/Config/` in BAR; the folders of the library (`dirs`) must lie there. Game widgets (Level Editor) are not restricted.

## 3. Scaling and dimensions (`M.rescale`, `M.m`, `M.S`)

- Base dimensions (at `ui_scale = 1` and 4K height 2160): `TILE = 190`, `LABEL = 80`, `PAD = 8`, `UCELL = 284`, `UICON = 270`, `UPAD = 7`, `HB = 58`, `XSIZE = 52`.
- `M.rescale()` reads `ui_scale` from the BAR settings, multiplies it by screen height / 2160 (limited to 0.3 to 3), recomputes all dimensions in `M.m` and returns the factor `S`. The widgets call it in every draw and input event.
- Every font size and every dimension in the menu is a multiple of `S` so the interface grows along on large monitors.

## 4. Helper functions

- `M.rotateOffset(dx, dz, k)`: rotates an offset by `k` quarter turns. Order south → east → north → west, formula `(dx, dz) → (dz, -dx)`.
- `M.headingToFacing(h)`: Spring heading (−32768 to 32767) → facing 0 to 3 (`floor((h + 8192) / 16384) % 4`).
- `M.parseBlueprint(text)`: reads the text of a blueprint file. A Lua table `{ blueprint = { ... } }` is valid.
- `M.fileText(path)`, `M.teamColor(t)`, `M.isBuildingDef(ud)` (building = `isBuilding` or not mobile).
- `M.FACING_NAME = South, East, North, West`.

## 5. Settings in a config file (`M.newConfig`)

- An object with `v` (values), `sync()`, `save()`, `load()`, `change(key, delta)`.
- Format of the file (Lua, in the write folder): `return { bpCols = 3, bpRows = 4, uCols = 3, uRows = 4 }` with a comment line in front.
- Keys: `bpCols`, `bpRows` (blueprint grid), `uCols`, `uRows` (units or buildings grid); the Level Editor adds `grid` and `unitLimit` (see `steps` below).
- Default: 3 columns and 4 rows for both. Limits: columns 1 to 6, rows 1 to 8. Values are limited on every change and saved at once.
- Level Editor: `LuaUI/Config/LevelEditorUI.lua`; BluePrinter: `LuaUI/Config/BluePrinterUI.lua`.
- Unknown keys in the file are ignored, missing ones stay at the default.
- `cfg.steps[key] = { v1, v2, ... }` (optional, set by the widget): `change(key, delta)` then moves along this list instead of adding the delta (used by the Level Editor for the grid size and the unit limit, keys `grid` and `unitLimit`).

## 6. Settings page (`M.newOptions`)

- Reachable through the small button **O** (gear substitute) at the top right of the menu. It replaces the content with the settings; a second click on **O** (or on a mode button) leads back.
- Structure: one title per block (e.g. "Blueprints", "Units"/"Buildings") and below it the rows "Columns" and "Rows" with **−**, value and **+**. The Level Editor adds a block "Placing" with the rows "Grid (1 = free)" and "Unit limit (scenario)" (block list passed to `M.newOptions(cfg, blocks)`, stepping through `cfg.steps`).
- Width 460·S. Height: per block 40·S plus two rows of (HB + 10·S), plus 2·PAD.
- The mouse wheel does not scroll on this page.

## 7. Blueprint library (`M.newLibrary`)

Options: `dirs` (list of folders with `/` at the end), `say`, `buildingsOnly`, `writeIndex`.
`lib.list` always stays the same table (emptied and refilled when scanning). Entry: `{ name, units, count, thumb, dir }`.

### 7.1 Files and format
- Blueprint = file `<name>.lua` in one of the folders. Content: `return { blueprint = { { name = 'armsolar', dx = -52, dz = 172, h = 0, rot = 32767, team = 0, neutral = false }, ... } }`.
- `dx`, `dz`: offset from the center of the selection (rounded), `h`: height above ground, `rot`: Spring heading, `team`, `neutral`: saved values of the Level Editor.
- Names: only `[A-Za-z0-9_-]`, file names with `_` at the start are reserved (`_order.txt`, `_index.txt`, `_trash`).
- Files with unreadable content or without units are skipped. With `buildingsOnly` only buildings count; a blueprint without buildings disappears from the list.

### 7.2 Scanning and order
- Sources per folder: `VFS.DirList(dir, "*.lua", VFS.RAW)` and additionally the names from `_index.txt` (fallback if the directory is not readable; a name from the index file only counts if the file exists).
- With the same name in several folders the first folder wins.
- Order: first the names from `_order.txt` in the **first** folder in that order, then all others alphabetically (case does not matter).
- `saveOrder()` writes `_order.txt` (and with `writeIndex` also `_index.txt`) in the first folder. Level Editor: `writeIndex = true`; BluePrinter: `false`.

### 7.3 Managing
- `remove(name)`: copy the file to the trash `<dir>_trash/` (with a timestamp if the name exists), delete the original with `os.remove`, rescan, save the order. Nothing is deleted for good.
- `rename(old, new)`: the name is cleaned (`[^%w_%-]` → `_`), empty or unchanged → abort, name conflict → message "Name already taken". The file is written under the new name, the old one moved to the trash, the order takes the new name at the old place.
- `move(from, to)`: moves in the list and saves the order.
- `nextName()`: next free name `bp_001`, `bp_002` … in the first folder.
- `write(name, lines, header)`: writes the file into the first folder (creates the folder), with a comment header.
- `linesFromUnits(ids, opts)`: creates the lines from selected units, position relative to the center of the selection, sorted. Options `onlyBuildings`, `withTeam` (team and neutral from the unit, otherwise `team = 0, neutral = false`).

### 7.4 Preview picture (thumbnail)
- Per blueprint, points with a relative position (0 to 1), size and unit ID are computed; size = half the footprint of the building (at least 10), otherwise radius.
- At most about 150 units per preview (step size for more). Large buildings are drawn first, small ones lie on top.
- The unit pictures from above are drawn (`gl.Texture("#" .. unitDefID)`), not rotated. Without a unit picture a dot in team color stays, air units with a white border.

## 8. Tile grid for blueprints (`M.newGrid`)

Options: `lib`, `cfg`, `unitWord` ("Units" or "Buildings"), `ownText(on)`, `onSelect(index, moved)`, `onArm(on)`.
State: `selected` (chosen blueprint, 0 = none), `armed` (stamp mode), `scroll`, `drag`, `editing`, `confirmDel`, `query` and `focus` (search).
`g:list()` returns the tiles shown: the whole library, or with a non-empty `query` a cached filtered view (all words of the query must appear in `M.blueprintSearchText(bp)`); `selected` and the indices passed to `onSelect` are always library indices, `scrollTo(rect, i)` takes one too. While a query is active, sorting by dragging is switched off. `g:filterRowCount()`, `g:filterRects(x1, x2, top, hb)`, `g:applyFilter(r)`, `g:setFocus(on)`, `g:textInput`, `g:key` provide a search row (used by the BluePrinter; the Level Editor feeds `g.query` from its global search). The grid draws a scrollbar (see 9.7).
On every call the host passes the rectangle `rect = { x1, y0, x2, top }` of the content area.

### 8.1 Structure
- Tile: preview `TILE × TILE`, below it a label `LABEL` high; cell width `TILE + 2·PAD`, cell height `TILE + LABEL + PAD`.
- Label: name (font 32·S) and below it "N units" or "N buildings" (24·S); names from 13 characters on are shortened with "~".
- The chosen tile has a blue background, unchosen ones are dark gray.
- At the top right of every tile the **x** for deleting: 52·S large, character 36·S.

### 8.2 Growing, columns and rows
- The grid grows **from top to bottom**: first a column fills up to `bpRows` tiles, then the next column is added, up to `bpCols`.
- Tile count 1 to `bpRows`: one column. After that more columns. More than `bpCols × bpRows`: fixed column count `bpCols`, the columns get longer (`ceil(n / bpCols)` tiles per column), and it scrolls.
- The width of the menu follows the column count, the height the row count (at most `bpRows`). With few blueprints the menu stays small so more of the playing field stays free.
- If the menu is wider than the grid (minimum width of the host), the grid is centered.

### 8.3 Controls
- A single click on the tile chooses it and switches on stamp mode (`armed`); `onSelect` reports the selection. A click into the empty part of the panel changes nothing.
- **Deleting:** a click on the x turns it red and shows "x again" / "(trash)"; a second click on the same x deletes (trash). Any other click cancels.
- **Renaming:** double click (within 0.5 s) on the name area of the tile. Input through the text functions of the widget (`ownText`), `[A-Za-z0-9_-]` allowed, at most 40 characters. Enter accepts (keys 13 and 271), Esc cancels, Backspace deletes. A click elsewhere accepts the name. Display "Name_" with the hint "Enter / Esc".
- **Sorting by dragging:** hold the mouse on the tile and move more than 8 pixels, the tile hangs on the mouse pointer as a semi-transparent ghost tile. A yellow horizontal line shows the insertion point (below the target tile when moving back, above it when moving forward). At the top and bottom edge the list scrolls along. A target in an empty cell of the last column means "to the end". After releasing, the order is saved.
- **Mouse wheel:** scrolls by 234·S per notch (three times the speed of earlier versions, then raised by 30 %).
- After deleting and renaming, stamp mode is ended.

## 9. Unit catalog and selection grid (`M.newUnits`)

Options: `cfg`, `groups` (offer only these groups; default all), `faction`, `canUse(unitDefID)` (unusable units are dimmed but remain selectable).

### 9.1 Selection
- Factions: Armada (`arm`), Cortex (`cor`), Legion (`leg`) – by the name prefix.
- Groups in this order: **Buildings, Bots, Vehicles, Hover, Air, Ships**. Tech: T1 to T3 (`customParams.techlevel`, limited to 1 to 3, default 1).
- Excluded: names with "scav", "decom", "dummy", "drone", `customParams.isdrone`, and also decoration (names with `_` at the fourth position like `arm_leftshoulder_nationwars_*`, `cor_hat_*`, and names with `_wings`).
- The catalog is built once from `UnitDefs`: `[faction][group][tech]`.

### 9.2 Group assignment (order of the checks)
1. Buildings: `isBuilding` or not mobile.
2. Ships: category `ship` or `underwater`.
3. Air: `canFly`.
4. Hover: category `hover`.
5. Bots: category `bot`.
6. Otherwise by movement type (`moveDef.name`, upper case): contains "BOAT" → ships, "HOVER" → hover, "BOT" → bots (all `BOT2`, `ABOT3`, `HABOT5`, `COMMANDERBOT` …).
7. Everything else: vehicles.

Background: the category `BOT` no longer exists in BAR; bots are therefore sorted in by movement type.

### 9.3 Sorting within group and tech
Sort key `rank = (filler 1000) + (water 100) + kind`, then alphabetically by name. Smaller = further front.

- **Buildings:** kind 0 economy (`unitgroup` energy/metal, metal extractors; storage belongs here), 1 factories (`isFactory`), 2 turrets (weapons, not `explo`), 3 other (radar, mines, nano turrets, shields …). **Land first, then water** (water buildings: `minWaterDepth > 0` or floating with `minWaterDepth >= 0`). **Fillers** (dragon teeth, walls: `customParams.objectify`) at the very back.
- **Bots:** 0 construction bots (everything that can build), 1 combat bots (with weapons), 2 support bots (without weapons: radar, jammers …), 3 commander bots.
- **Vehicles, hover, ships:** 0 builders, 1 rest (combat).
- **Air:** land aircraft first: 0 construction aircraft, 1 scouts and radar aircraft (`lightairscout` or `unitgroup = util`), 2 interceptors (`unitgroup = aa`), 3 attack aircraft (other armed ones), 4 transport aircraft (transport capacity > 0 and no weapons, at the very back). **After that the seaplanes** (`maxWaterDepth > 0`) in the same structure: construction aircraft first, then combat aircraft.
- Commander note: units with `customParams.iscommander` belong to the commander bots (kind 3).

### 9.4 Grid and display
- Symbol size `UICON = 270·S`, cell size `UCELL = 284·S`, margin `UPAD = 7·S`. Default 3 columns and 4 rows (setting `uCols`, `uRows`), width `uCols·UCELL + 2·UPAD + 4`, height `uRows·UCELL + 2·UPAD`.
- At most 4 rows visible at the same time (adjustable); below that there is room for the info lines. The mouse wheel scrolls by 234·S per notch.
- Filter buttons (faction, possibly group, tech; no tooltips) above the grid; the **faction buttons carry the faction symbol on the left** (`sidepics/armada.png`, `cortex.png`, `Legion.png` from the game, 72 % of the button height), the name stands centered in the remaining area; the group row is omitted if only one group is offered.
- When hovering, up to four lines stand **below the panel** (distances 40·S, 78·S, 116·S, 152·S below the lower edge of the panel):
  1. name (code) and, for armed units, in an additional bracket `(<seconds> s/shot - <damage> damage)` (details in 9.5), font 29·S,
  2. the description (`tooltip`), one line, shortened with "~" if too long, font 24·S,
  3. `Metal <n>   Energy <n>`, font 26·S,
  4. only for **buildings**: `Explosion <damage> damage, radius <Elmo>` (death explosion, `deathExplosion`), and if different, `|  Self-destruct <damage>, radius <Elmo>` (`selfDExplosion`), font 22·S. Damage in the default armor class, radius = effect radius of the explosion in Elmo (`M.explosionInfo`). Examples: solar collector 89 / 90, fusion reactor 2650 / 240 (self-destruct 8300 / 384), advanced fusion 10600 / 640.
- The **hint text** ("Click a unit …" / "Left click places …") no longer stands below the info lines but **above the menu** and is drawn by the host (24·S, special line for row/rectangle in 20·S above it). The parameter `hint` of `draw` remains for hosts that want it below the info lines (then 190·S below the lower edge).
- The chosen unit (stamp mode) has a blue frame, the one under the mouse a light frame.
- Unusable units (`canUse` false) are drawn at 30 % opacity.

### 9.4a Dragging a row and rectangle (`M.stampPositions`)
- **Maze:** `M.mazeWalls(cols, rows, path, rnd)` returns the wall tiles `{i, j}` (0-based) of a random maze (cells of `path` × `path` tiles, one tile of wall between them, depth-first search, entrance top left, exit bottom right) as well as width and height in tiles. Used by the key M and the Maze sub-tab of the Level Editor.
- **Also for whole blueprints:** `M.blueprintExtent(units, k)` returns width/depth of the blueprint hull (after `k` quarter turns), `M.stampPositionsSized(fx, fz, …)` lays out the copies (at most 100) in the same grid with spacing; `M.stampPositions` is the variant for one unit.
- For the single stamp (unit or building): `Shift` + left click drags a **row** (straight line from the start point to the mouse pointer), `Shift+Alt` a filled **rectangle**. On release all positions are placed or queued.
- Spacing between two units: footprint (swapped for east/west) plus `spacing × 16` Elmo. Row: step size along the longer axis of the mouse movement; rectangle: step size per axis. At most 2000 pieces (the default of `maxN` in `stampPositionsSized`; the widgets pass 2000 for single units and 100 for blueprints).
- Changing the spacing (0 to 20, `M.clampSpacing`): **Alt+Z / Alt+X** (also with Shift; BAR default for `buildspacing inc/dec`), mouse side buttons 4/5 with Shift, Shift + mouse wheel and the chat command `/bp_spacing` (`<n>`, `+`, `-`). The keys Alt+Z/X are caught by a handler in front of the BAR build menu (`gridmenu_key`), because the build menu otherwise eats them when a builder is selected; in addition the action `buildspacing` is registered. The preview shows frames and models (at most 150) for all positions.

### 9.5 Damage and time per shot (`M.shotInfo`)
- For every weapon of the unit: damage per projectile = damage in the default armor class (`default`). **Anti-air weapons** carry only 1 (or a fraction) there in BAR and the actual damage in the armor class `vtol`; if the `vtol` damage is higher, it counts, the weapon is anti-air and the display gets the suffix "air" (e.g. `(0.9 s/shot - 125 damage air)`). If a unit has ground and air weapons, the ground weapons take priority. Projectiles per second = `projectiles × salvoSize / reload` (as with the DPS figure).
- The **reciprocal** is shown, that is the **seconds per shot** (`reload / (projectiles × salvoSize)`), because then you do not have to convert in your head and the numbers get larger and smoother.
- The weapon with the highest damage per projectile counts; its time per shot is shown. Units without weapons show no bracket.
- Rounding: from 10 seconds a whole number, from 1 second one decimal place, below that two, each without superfluous zeros.
- Examples: Armada fighter 0.9 s − 125 damage air, Peewee 0.1 s/shot − 9 damage, Hammer 1.7 s − 104, Bulldog 1.1 s − 270, Vulcan 0.6 s − 1625, Banth laser 7.5 s − 6000.

### 9.6 Search, features, recent items, tooltips
- `Units:textInput/key/setFocus`: search field as the top filter row (`searchOn`, can be switched off with `search = false`); `Units:list()` returns the hits across all factions/groups/tech tiers when `query` is not empty (all words must appear in `M.unitSearchText(name)` = code, human name and description); `override` replaces the list (recent items). `filterRowCount()` counts the search row. A host with its own search field (the Level Editor) sets `query` directly and drops the grid's search rects.
- `M.newFeatures(o)` / `M.buildFeatureCache()`: selection grid for features (tabs trees, rocks, wrecks, rest by name; `query` searches `M.featureSearchText` = code and description), pictures only, cell height `HB` (small pictures are rendered once per feature into a texture, a few per frame).
- `M.newRecent(file, maxN)`: list of the most recently used names per kind (`bp`, `unit`, `feature`), stored in a Lua file. `M.newFav(o)`: the "Recent" view (blueprint rows and unit symbols); its `query` filters both parts and `matchCount()` returns the number of entries shown.
- `M.tooltipBox(text, x, y)` and `M.drawTip(rects, mx, my)`: tooltip for buttons with the field `tip`. `M.drawButtons` respects a field `fs` (own font size per button), `icon` (symbol left in the button) and `tint = { r, g, b }` (fixed color instead of the active/inactive colors, e.g. reddish for a search field with text).
- `M.drawHelp(title, sections, footer)`: help board over the screen; `sections = { { "Title", { { "Key", "Explanation" }, ... } }, ... }`. Two columns (sections distributed by line count), key column at most 45 % of the column width, long explanations are wrapped, font `max(19·S, screen height · 0.0155)`. If the board would be too tall for the screen the font is shrunk step by step until it fits; if the minimap frame (top left, drawn by BAR above the widgets) would overlap, the board stays below it. The host calls it last in `DrawScreen` (above the menu) and closes it with every click.
- `M.drawButtons` shrinks the font of a button if the text does not fit.
- `M.blueprintCost(units)`: sum of metal, energy, build effort and count of all units of a blueprint (computed once per table). When hovering over a tile the tile grid shows name, count and cost below the panel (29·S / 26·S, distances 40/78·S below the panel).

### 9.7 Search helpers and scrollbar
- `M.matches(query, text)`: true if every word of `query` (split at spaces, case-insensitive) occurs in the lower-case `text`.
- `M.unitSearchText(name)`, `M.featureSearchText(name, id)`, `M.blueprintSearchText(bp)`: the lower-case texts the lists are searched in (code and human name and description; for a blueprint its name plus the texts of its units). Results are cached.
- Scrollbar (`M.scrollbarDraw(grid, rect)`, `M.scrollbarPress(grid, rect, mx, my)`, `M.scrollbarMove(mx, my)`, `M.scrollbarRelease()`): 24·S wide at the right edge of `rect`, drawn only if `grid:maxScroll(rect) > 0`. A click on the thumb keeps the grip, a click on the track centers the thumb under the pointer; the drag runs until the release. The three grids (blueprints, units, features) draw it themselves; hosts call press, move and release (the widgets do this before handling tile clicks).

## 10. Buttons (`M.drawButtons`)
- Uniform look: active light blue (0.5 / 0.75 / 1, so the blue Armada symbol on the faction button stays visible), otherwise dark gray; text centered. The hosts pass font size and button height.

## 11. 3D preview (`M.newGhost`)

- Draws the real unit models semi-transparent (60 %) in team color at the mouse pointer, for single stamps and for blueprints.
- Path 1 (default `auto`): the BAR widget "DrawUnitShape GL4" through `WG.DrawUnitShapeGL4` / `WG.StopDrawUnitShapeGL4`. Path 2 (fallback): directly `gl.UnitShape` in the world drawing (`gl.PushMatrix/Translate/Rotate`, `gl.DepthTest(true)`).
- Rotation as in BAR itself: `facing × 90°` or `heading × π / 32768 (+ stamp rotation)`.
- Management per model with a key; models no longer drawn are removed at the end of the frame (`endFrame`), `stop` removes all (on quitting, leaving the menu).
- At most 150 models per preview (`ghost.max`): for large blueprints the units closest to the center.
- Diagnosis: `command(mode, name)` returns the state as text and switches the mode: `gl`, `wg`, `auto` (chat commands `/led_ghost`, `/bp_ghost`). If the BAR widget is missing or returns nothing, a message is shown once and it switches to `gl.UnitShape`.

## 12. Tests and quality assurance

- The module is checked in the real game (headless engine): compiling under Lua 5.1, building the unit catalog, sorting, damage per shot.
- The UI logic is checked with mocks for `Spring`, `gl`, `VFS` and `UnitDefs` (clicking, dragging, renaming, deleting, quick blueprint, settings, mouse wheel, 3D preview, rotating).
- The maze generator is checked with a mock test: every corridor is reachable from the entrance, the exit is reachable, exactly cells−1 passages (no cycle).
- Before every hand-over: check both widgets with the test runs and run both installations again.

## 13. Rule for changes

Changes to the blueprint/unit interface are made **in `editor_common.lua`** so the Level Editor and the BluePrinter stay in sync. Only what one widget alone needs stays in the widget.
