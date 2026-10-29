# Level Editor

Level editor for Beyond All Reason (BAR): place units and buildings on the map with the mouse, create and place blueprints (layouts), save and load levels, build Tower Defense, Capture the Flag or Reclaim the Fame levels, restrict units for the player. The result is a `unitloadout` list for scenarios. This document is the core of the editor (widget, gadget, menus, editing). User view: [Level Editor manual](../LevelEditor/README.md).

Related specifications:

- [Setup, start menu and game start](level-editor-setup.md)
- Pages: [Tower Defense](tower-defense.md), [Capture the Flag](capture-the-flag.md), [Reclaim the Fame](reclaim-the-fame.md), [Arena](arena.md), [Teams](teams.md), [Restrictions](restrictions.md)
- [Scenario builder](scenario-builder.md), [Scenarios with several players](scenario-multiplayer.md), [LAN Play](lan-play.md)
- [Shared code](shared-code.md), sister project [BluePrinter](blueprinter.md)

## 1. Goals and structure

- **Language:** all visible texts in the game are English (widget and gadget messages, tooltips, help board, help topics, chat messages), without umlauts in texts drawn in the game. Console menus, scripts, comments, documents, file and folder names are English as well.
- No names or private matters of persons in code, texts or file names.
- **No backward compatibility:** old fields in level files are dropped when loading (`knownFields`, section 10); old names and formats are not read.
- **Parts:** the widget `lvl_level_editor.lua` (controls, menu, saving and loading); the gadget `unit_level_editor.lua` (places, deletes, blows up, build mode, orders for units of other teams); the shared code `editor_common.lua` and `bar_rules.lua`; the pages and games `td_waves.lua` + `led_td.lua`, `ctf_game.lua` + `led_ctf.lua`, `rtf_game.lua` + `led_rtf.lua`, `led_arena.lua`, `led_teams.lua`, `unit_restrictions.lua` + `led_restrictions.lua`, `unit_indestructible.lua` (the buildings marked with FX), `led_gadgets.lua` (what the gadgets share). Texts of the help board: `help_texts.lua`.
- **Lua limit:** a function has at most 200 local variables, `lvl_level_editor.lua` has 195 at top level. New things go into a page module or into an existing table. A load error shows as `Failed to load: lvl_level_editor.lua` in `infolog.txt`. The mock tests do not detect engine limits (also at most 60 upvalues per function: the Generate state lives in one table `gen`).

## 2. Controls

### 2.1 Keys (the mouse points at the map)

| Key | Effect |
|---|---|
| `[` and `]` (BAR "build rotation", `buildfacing inc/dec`) | rotate the unit or blueprint stamp by 90 degrees (south, east, north, west) while one is armed; BAR gets the key as well |
| Del | delete the selection, without a selection the unit, wreck or feature at the mouse pointer (radius 64–80; unit first; not over the menu); on the Tower Defense page first the waypoint under the mouse pointer |
| Ctrl+B | blow up (normal death with explosion, wreck stays), selection or unit at the mouse pointer |
| Ctrl+C / Ctrl+V / Ctrl+X | copy / paste / cut (selection, otherwise the unit at the mouse pointer; pasting centered at the mouse pointer with team, rotation, height; any number of times; the clipboard lasts until quitting) |
| Ctrl+Z / Ctrl+Y (also Ctrl+Shift+Z) | undo / redo the last action (section 5) |
| Ctrl+S | save the level (`saveCurrentLevel`: under the current name, otherwise as a new `level_NNN`; same as "Save" on the settings page) |
| Ctrl+D | create the builders of all factions at the mouse pointer for the current team |
| D | delete rectangle on / off (same as DR) |
| M | cycle the maze mode: off → dragon teeth → walls → off (section 8) |
| Alt+Z / Alt+X (also with Shift) | build spacing larger / smaller (BAR default, only with an armed stamp) |
| Right click | ends every mode (stamp, delete, maze, generate, area attack, Tower Defense drawing and picking, find-a-unit) and every drag in progress; with no mode active it is left to the game (the order for the selected units; a left click on the ground clears the selection). Works anywhere on the screen, also over the menu (`gen.cancelModes`). Starting a Tower Defense or Capture the Flag test calls `gen.disarmAll()` |
| Left click and hold, move (armed unit or feature) | paint (section 7) |
| Shift + left drag / Shift+Alt + drag | row / rectangle (section 7) |
| Alt + left drag on a selected unit | move the selection (section 5) |
| Alt + left drag on a feature (no selected unit within 48 Elmo) | move that feature in grid steps (`led\|movefeatures\|dx\|dz\|fid`: the gadget deletes the feature and makes it again at the new place, rotation stays; both steps are one history step) |
| Alt + left drag on a waypoint, spawn point, goal, collection or flag point | move it (`td.dragAt`, `ctf.grab`; also with the page closed) |
| Left click or drag a rectangle | select units of every team |
| Arrow keys | move the selected units by one grid step (default 16; up = north (−z); a held key repeats; `ARROW_STEP`, key codes 273–276, sends `led\|move\|dx\|dz\|ids`). Without a selection, with Shift/Ctrl/Alt or with the help open the key stays free for the camera |

**Selecting units of every team.** BAR only lets you select your own units, unless the god mode is on. `widget:Update` sends `cheat 1` and `godmode 3` once (frame 6 or later, only with the game option `leveleditor`; `godmode 1` = allied teams only, `2` = enemies only, `3` = all); then `Spring.SelectUnitArray` takes units of other teams. The engine sends no orders for units of other teams, so `widget:CommandNotify` forwards every order for selected units of other teams as `led|order|cmdID|options|params|ids` and the gadget gives it with `Spring.GiveOrderToUnit`. Delete, blow up, team assignment, copy and saving a blueprint use the selection of the game; without a selection delete / blow up still act on the unit at the mouse pointer (any team). There is no selection of its own.

**Ctrl shortcuts.** `ctrlEdit(key, shift, isRepeat)` is called by the action handler `gridmenu_key` (in front of the BAR build menu) and by `widget:KeyPress` when Ctrl is held without Alt; search fields and chat take precedence. BAR uses Z X C V / A S D F for the build menu and eats Ctrl letters as soon as a builder or factory is selected (`actionHandler:KeyAction` runs before `widget:KeyPress`), so the widget runs at layer −1 with its own handler for `gridmenu_key` that passes Ctrl (without Alt) + C/V/X/Z/Y/B/S on to `ctrlEdit` (a held key does not repeat). The BAR bind `Ctrl+v = pastetext` stays untouched because the editor consumes the key first. The editor sets no Alt-letter binding that overrides BAR default keys.

### 2.2 Chat commands (prefix `/led_`)

Only for diagnosis: `help [topic]` (short version or the topics `start`, `keys`, `place`, `units`, `blueprint`, `save`, `team`, `edit`, `features`, `search`, `scenario`, `delete`, `build`), `clear` (clears the map; undoable), `ghost [gl|wg|auto]` (state and mode of the 3D preview). Everything else runs through keys, buttons and the menu. The grid is a setting (button O).

**Team assignment** (a click on a team button with selected units) runs as a takeover (`Spring.TransferUnit(id, team, false)`, "capture"), because several BAR rules block gifts to enemies or teams without a player when no cheat is on. The message "N units changed team" comes from the game and counts only units that really changed.

## 3. Menu at the right screen edge

### 3.1 Structure

- **Position:** right edge, top edge at 94 % of the screen height (below the game's menu bar), bottom edge at most at 12 % (for settings, scenario, Generate and the pages 5 %). The collapsed menu sits at the same height. Minimum width 560·S, at most half the screen width.
- **Movable:** the title row is the handle (`panelPress`: left button starts, right click resets; `MouseMove` / `MouseRelease` end it). `basePanelRect()` is the place at the right edge, `panelRect()` = `basePanelRect()` moved by the offset of `panelMover` (`Shared.newPanelMover`) and kept on the screen (room `2·HB + 12` for the strip on the left and `HB + 2·PAD` for the button column on the right). Everything (strip, button column, content, 3D preview) is built from `panelRect()`. The offset is stored as a fraction of the screen size (`widget:GetConfigData` / `SetConfigData`).
- **Scaling:** factor = `ui_scale` (BAR setting) times screen height / 2160 (designed for 4K; Full HD is half as big), limited to 0.3 to 3.
- **Title row** "Level Editor" at the top left (`titleH()`, 44·S, not shown when collapsed). The two main menus Place and Generate are the buttons P and G of the button column (`kind = "top"`).
- **Place:** row 2 is the search row (section 6), row 3 the sub-tabs **Recent | Units | Features | Blueprints** (`kind = "mode"`, font 22·S) with the number of matches while a query is active, below them the rows of the chosen tab (faction, group and tech for Units; the feature kinds for Features; the button **Create** for Blueprints). A click on a faction, group, tech or feature-kind button ends the search. At the start the Place menu is open on the Units tab.
- **Generate:** a page of its own with the sub-tabs Units | Maze (section 8).
- The hint text is above the menu (24·S): "Click a unit, then place it on the map" or in stamp mode "Left click places, right click ends, [ and ] rotate", above it in 20·S "Shift = row, Shift+Alt = rectangle, Shift+Mouse wheel = spacing (N)"; for blueprints "Click a tile, drag = sort" / "Left click places, right click ends".

### 3.2 Units view

Faction, group (Buildings, Turrets, Bots, Vehicles, Hover, Air, Ships), tech, pictures, sorting and the info block: [Shared code](shared-code.md), "Unit catalog and selection grid". Specific to the editor:

- A click on a unit arms the stamp; a left click on the map places it (`led|place|<name>|<team>|<x>|<z>|<facing>`), right click ends. The team is the one chosen on the left, the grid comes from the settings (`cfg.v.grid`).
- Preview: blue outline (footprint, swapped for odd rotations) and the 3D model at the mouse pointer. Around it two circles on the ground (`Shared.drawRangeCircles`): **red** = weapon range (`M.weaponRange`), **blue** = line of sight (`losRadius`); none for a value of 0. Row / rectangle: for the first 40 copies. Blueprint: the circles of every unit at its place (together they show what the whole blueprint covers; at most 120 units with circles, the ones nearest the center first).
- The grid is created with the option `restrict` ([Restrictions](restrictions.md)): X marks on every symbol and filter button. A click on such an X does not arm a unit.

### 3.3 Blueprint view

Tiles, sorting, renaming, trash and format: [Shared code](shared-code.md), "Tile grid for blueprints". Specific to the editor:

- The label shows "N units" and below it the total cost (`M` metal in light blue, `E` energy in yellow).
- A left click on the map places the chosen blueprint (frame preview in team colors and 3D models), right click ends.
- Blueprints are placed with the team chosen on the left. Air units keep their height, landed air units stay landed. The layout is not checked for passability.
- The order is in `blueprints\_order.txt` (and `_index.txt`), the trash in `blueprints\_trash`. The list reads the folder `LevelEditorBlueprints/` (junction to `blueprints`).
- The query comes from the global search; the grid's own search row is only used by the BluePrinter. The blueprint grid shows a filtered view of `lib.list`; indices handed to the host are always library indices. Dragging to sort is off while a search is active.

### 3.4 Settings (button O)

- Columns and rows for the blueprint view (`bpCols`, `bpRows`) and the units view (`uCols`, `uRows`), default 3 and 4, limits 1–6 and 1–8, stored in `LuaUI\Config\LevelEditorUI.lua`, immediately on every change.
- **Placing block:** the **grid** (1 = free, 4, 8, 16, 32, 64 Elmo; default 16; used for placing, moving, arrow keys and snapping) and the **unit limit** (500 to 32000; default 32000). The values move along fixed lists (`cfg.steps`, `M.newConfig`). The unit limit belongs to the level: it is written into the level file as `unitlimit = N,` (next to `mapsize`) and read when a level is loaded (a level without it gets 32000), but never into `LevelEditorUI.lua` (`cfg.transient.unitLimit`); the scenario builder uses it as the game option `maxunits`. The editor game itself always starts with `maxunits=32000` (it cannot be changed while the game runs).
- **Levels:** below the columns / rows stands the list of all `LevelEditor/*.lua` (without internal files with `_`, except `_last`). Per level `Load` and `Save` (a second click confirms), on top `Save as new` (creates `level_001`, `level_002` ...). The mouse wheel scrolls from 8 entries.

## 4. Button column and strip

### 4.1 Button column (far right; `headerRects`, rectangles with `side = true`; clicks through `sideAt`)

Top to bottom: **V** (collapse / expand the menu; with a collapsed menu V stays in the corner), **O** (settings), **I** ([scenario info](scenario-builder.md)), **T** ([teams](teams.md)), **?** (help), a free slot, **P** (Place), **G** (Generate), **A** ([Arena](arena.md)), **TD**, **CF**, **RF** (the game modes; green while the mode is on, lighter when its page is open), a free slot, the experimental area attacks **XL**, **XR**, **XC** (line, rectangle, circle; `Shared.newAreaAttack`, [Shared code](shared-code.md); the editor ends other modes when one is armed and the other way round), a free slot, **FX** / **FD** (rectangle: buildings become indestructible / destructible again; `delMode = "fix"` or `"unfix"`, `led|fix|x1|z1|x2|z2|on`, one history step, operation `fix`; only buildings, i.e. units with speed 0).

The Place / Generate menus are `kind = "top"` rectangles; `headerRowCount` knows only the rows of the menu.

### 4.2 Strip at the left of the menu (`teamRects`)

Top to bottom, with a free slot (one button high) between the groups: **W**, a free slot, **DL, DR, DC**, a free slot, **L, R, S** (only while units are selected; then a free slot), **N**, one button per team, **G**. With a collapsed menu the strip is gone.

- **W** (Write, `writeOn`, default on, green when on): decides what happens when something is placed where something already stands (section 7). Not stored in the level.
- **DL, DR, DC** (red, `del` = "line" | "rect" | "circle"): the delete modes (section 8); the active one has a white frame.
- **L, R, S** (blue): rotate the selection left or right, mirror it (section 5).
- **Team buttons:** number = team number, team color, without Gaia. The chosen team (`team`) is marked by the full color inside and a bright number; a left click chooses it, a right click opens the menu of the alliance colors ([Teams](teams.md)). Newly placed units (single, row, rectangle, painted) belong to this team, blueprints too (stamp, row, rectangle, paste); the saved team only appears in level files. If units are selected (also foreign ones), a click on a team button additionally assigns them to that team. **Left of every team button (except N) the current number of units** of that team is shown (`Spring.GetTeamUnitCount`, also for G).
- **N** (toggle): newly placed units and blueprints are neutral (neutral flag, the team stays the chosen one).
- **G** at the very bottom, if the engine knows a Gaia team: chooses the Gaia team (no owner, enemy to everyone; the tooltip names the unit limit 500).
- Every button has a tooltip to its left; the tooltip of a team button also shows the unit count and the limit.

## 5. Editing the selection

- **Edit buttons** (L, R, S, only while units are selected): rotate the selection 90° left / right, mirror left-right, each around the center of the selection. The gadget sets the units up again (team, neutral flag, height stay), replaces their IDs in the undo stack and reports the new IDs through the game rules parameters `led_newids` / `led_newids_n`; the widget selects them again. At most 2000 units per operation (rotating, mirroring, moving).
- **Moving:** hold Alt, click a selected unit (radius 48 Elmo), drag, release; the offset is rounded to the grid (`led|move|dx|dz|ids`). Preview: green frames at the target.
- **Selection info:** at the top center the number of selected units, up to four types with count and the sum of metal and energy.
- **Undo / redo (history in the gadget):** the gadget keeps a history of steps (at most 300); a step is an action of the user (a row, a blueprint, a delete of the selection ...). Before every action the widget sends `led|step`; everything up to the next `led|step` belongs to this step. All messages run in order through the queue (`led()`) so nothing overtakes a not yet sent part of a row. Operations of a step: `add`, `del` (deleted or blown up; wrecks that appear are noted through `gadget:FeatureCreated` and removed on undo), `swap` (moved, rotated, mirrored: state before / after), `team`, `fadd` / `fdel` (feature placed / deleted), `tdroute`, `ctfpts`, `arena`, `fix`. Units are created anew on undo and redo and get new IDs; `replaceId` swaps the ID in all steps (through the indexes `opsByUnit` / `opsByFeature`), and before every access it is checked whether the ID still belongs to a unit of this type. A new action empties redo. Not in the history: loading a level (`led|load` without suffix, `led|loadfeature`), `led|clear` (empties the history), creating builders. Blueprints and paste send `led|load|…|1` (suffix 1 = remember in the history). `led|undo|N` undoes N steps; units of a row not yet sent are discarded.

## 6. The Place menu

- **Search** (one field for Recent, Units, Features and Blueprints at once): the `search` table in the widget; `searchSet(q)` copies the query into `uGrid`, `fGrid`, `bpGrid` and `fav`. Click and type words of the description or the code; all words must match; each tab shows its hits across all factions, groups and tech levels (features by code and description, blueprints also by the units inside, Recent by both of its parts; `fav:matchCount()`). Enter ends the input, Esc clears, Backspace deletes a character. The input runs through `OwnText` and `KeyPress`. The field and its X button (`searchclear`, clears all lists) turn reddish while there is a text. All lists have a scrollbar at the right edge.
- **Features tab:** kinds trees / rocks / crystals / wrecks / rest (by name: `pilha_crystal*` = crystal (the nodes of [Reclaim the Fame](reclaim-the-fame.md)), `_dead` / `_heap` = wreck, tree / pine / palm … = tree, rock / stone … = rock; `burnable` = tree). Pictures only, no names (section 6.1). Clicking arms the feature: left click places (`led|feature|name|x|z|rot`, rotation = facing), right click ends, Del deletes the one at the mouse pointer. Preview: circle (green / red). Shift + drag places a row, Shift+Alt a rectangle (at most 2000, feature size from `FeatureDefs.radius` plus spacing).
- **Recent tab:** on top the recently chosen blueprints (up to 6 rows), below the recently placed units (symbols), at the bottom the recently placed features (two rows of picture tiles with their own scrolling; noted when a feature is placed, also by a row or rectangle). File `LuaUI/Config/LevelEditorRecent.lua` (up to 24 names each). A click arms the blueprint, unit or feature.
- **Finding a unit (crosshair button, `locate`, left of the search field):** a click starts the pick mode: a green crosshair hangs at the mouse pointer (`search.pick`, drawn in `widget:DrawScreen`). A left click on a unit on the map (`Spring.TraceScreenRay`; on a wreck or heap the unit it came from, found by cutting `_dead` / `_heap` from the feature name) shows its tile in the Units list (`search.locate(name)` → `u:locate(name)` in `editor_common.lua`): the Place menu switches to Units, the search is cleared, faction, group and tech are set to those of the unit, the next draw scrolls the list so the tile is in the middle and its frame flashes green for two seconds. Right click, Esc, the button again or any other mode ends the pick mode; a click without a unit says so in the chat and stays in the pick mode. The window of the [restricted units](restrictions.md) (button R) uses the same `search.locate`.
- **Tooltips:** all buttons show an explanation when hovered. `Shared.drawTip` only notes the tooltip, `Shared.flushTip` draws it at the end of the frame so it lies above every panel and window ([Shared code](shared-code.md)).
- **Help button `?`** (action `led_helpbox`): the help board with keys and short explanations in sections; every click closes it. The chat topics are `HELP.topics`, the board `HELP.sections` (both from `help_texts.lua`); the board shrinks its font to fit the screen and stays below the minimap.

### 6.1 3D preview and pictures

- **3D preview for all lists** (`Shared.drawUnitPreview`, `drawBlueprintPreview`, `drawFeaturePreview`; place `previewPos`: left of the team strip, otherwise right of the menu, at the height of the tile): hovering over a unit, a blueprint (all units in place, rotated by `h`), a feature or an item of the Recent tab shows a rotating 3D picture. Units and blueprints need a small shader of their own (fixed lighting, team color from the texture alpha, `rawState = true`), otherwise they turn out dark; features run with the engine rendering (`gl.FeatureShape`, own projection with a large depth, texture `%-<id>:0`; blending off and no alpha writing because the texture alpha is a mask).
- Under the preview the info block ([Shared code](shared-code.md)); for a feature: code name, "Metal x   Energy y" and the description (`translatedDescription` or `description`). For a blueprint tile: name, count and the sums of its units with the Eco time.
- **Feature pictures:** square tiles (`0.4 × UCELL`), per feature a 96 px picture rendered once into a texture when it first becomes visible (`featureThumb`, at most 3 new per frame, cache until quitting, `freeThumbs` in shutdown). The texture output is upside down in this engine, so it is rendered with reversed height (`Ortho` with swapped edges).
- The 3D preview of units uses the BAR widget "DrawUnitShape GL4" or, as a fallback, `gl.UnitShape` (`/led_ghost` shows state and mode; for blueprints at most 150 models, the ones closest to the center). The fallback is not finally confirmed in the real game.

## 7. Placing

- **Stamp modes** (mutually exclusive): unit, feature and blueprint. All end with a right click on the map; switching mode or settings ends them.
- **Rotation** in steps of 90°: unit stamp through `facing`, blueprint stamp through `bpRot` (offset and facing of all units rotate along; heading + 16384 per step). Works the same in the preview and when placing. The blueprint rotation is kept when the blueprint changes.
- **Painting:** an armed unit or feature (also the towers of the Tower Defense list) is placed on a left click and then after every footprint of pointer movement (footprint + spacing · 16 Elmo, per axis; chain along the straight line so fast moves leave no gaps) while the left button is held (`paintStart` / `paintSample` / `paintPlace`; `Shared.paintChain`). One `led|step` per stroke, so Ctrl+Z takes the whole stroke back. Blueprints are not painted.
- **Rows and rectangles:** Shift + left drag = row, Shift+Alt = rectangle (all placed on release as `led|place|…` messages in packets of 50 per update; at most 2000 units, 100 blueprint copies). Spacing: footprint (or blueprint hull) plus spacing. The preview shows all copies (models limited).
- **Spacing** (0 to 20, default 0): Alt+Z / Alt+X (a handler in front of the BAR build menu `gridmenu_key` catches the keys), the BAR action `buildspacing inc/dec`, mouse side buttons 4 / 5 with Shift, Shift + mouse wheel. Shown in the hint above the menu.
- **Write (W) and occupied spots:** `makeRoom(name, x, z, face, isFeature)` decides for every spot.
  - W **on** (default): what is in the way is deleted (`collectBlockers`: ground units and features overlapping the footprint, not what was placed a moment ago, `recentPlaced`, 2 s; `led|clearids|u12,u13,f7` in packets of 100, the gadget deletes them with `clearThese`, quietly, in the step opened by `ledStep`, so Ctrl+Z brings them back) and the new thing is placed.
  - W **off**: `blocked()` refuses an occupied spot (the footprint overlaps another ground unit or a unit placed a moment ago; a feature also overlaps other features by radius; aircraft are not checked, units may stand on features): single clicks and strokes say "Occupied ...", rows and rectangles skip the spots and report how many, a blueprint or paste (`placeBlueprintUnits`) is placed only partly, corridor wall pieces (`td.buildWalls`, `td.wallCell`) skip them.
  - **Generate** is independent of W: the gadget (`generate`) rejects a spot where a ground unit stands (radius test, buildings also `TestBuildOrder`) and tries another one in the area.

## 8. Generate, maze and delete

**Generate menu** (button G; `gen.open`, `genLayout`): two sub-tabs. At the bottom of both is the **Area** row (Rectangle / Circle): pressing one starts the generating (`gen.arm(shape)`; there is no Generate button; the same shape again ends it; the pressed shape is shown as active only while armed). The team comes from the strip (N for neutral). Right click or arming something else ends the mode, the page stays open.

- **Units:** faction (Armada / Cortex / Legion / Scavengers / Raptors, single choice; the gadget picks the `_scav` copies or the `raptor_` units, which exist only with switch 7 of the start menu), type (units, buildings, turrets, air, ships; toggle buttons, multiple choice, default Units; none chosen = message), tech T1 / T2 / T3 (toggles; none = all), count (input field: click, type, Enter or a click elsewhere accepts, Esc discards; 1 to 2000, default 100; the total is split over the chosen types, the remainder goes to the first ones). After pressing the shape drag the area (yellow frame; for a circle the press point is the center and the distance to the mouse the radius). On release the widget sends per chosen type `led|generaterect|team|x1|z1|x2|z2|count|techs|faction|kind|neutral` or `led|generate|team|x|z|count|radius|techs|faction|kind|neutral`; the gadget distributes the units randomly and evenly (same pool, ground and spacing rules as above) and notes them in the history (one step).
- **Maze:** faction (shared with the Units sub-tab; only Armada, Cortex and Legion have dragon teeth and walls, with Scavengers or Raptors chosen the maze is Armada's, `gen.mazeFaction`), material (**dragon teeth** `<faction>drag` or **walls** `armfort` / `corfort` / `legforti`; a click only chooses it, `gen.mazeSel`) and the corridor width (2, 4, 8, 10 or 12 tiles = 32, 64, 128, 160 or 192 Elmo, the widths of the Tower Defense corridors; default 64; `gen.mazePath`). The Area row switches the maze mode on (the same shape again off), then drag the area. With a circle the maze is built in the bounding square and walls outside the circle are left out. Key M cycles the mode (off → teeth → walls → off). A random fully connected maze appears on release (depth-first search, `Shared.mazeWalls`; no cycle; tile 16 Elmo; walls 1 tile; entrance top left, exit bottom right). The rectangle is cut to whole cells (preview frame green, red = too small: at least 2 × 2 cells, i.e. 2·(corridor tiles + 1) + 1 tiles per side, 11 for the default corridor of 4 tiles) and capped at about 12000 wall units (about 190 × 190 tiles). Team and neutral as when placing; one step for Ctrl+Z; right click ends, and so does arming anything else (`widget:Update` checks that).
- The maze mode, the Generate mode and the delete modes exclude each other.

**Delete in a line, rectangle or circle** (buttons DL, DR, DC; key D = DR): drag the shape with the left button (red frame; for the line the corridor of `DEL_HALF_WIDTH` = 40 Elmo to each side is shown, for the circle the press point is the center). On release the widget sends `led|clearrect|x1|z1|x2|z2`, `led|clearcircle|x|z|radius` or `led|clearline|x1|z1|x2|z2|halfwidth`; the gadget (`clearThese`) deletes all units (any team, also Gaia) and all features in it and notes everything in the history (one step). The state is `delMode` = false | "line" | "rect" | "circle". Right click, D again or arming a unit, blueprint or feature ends the mode.

## 9. Blueprints

- **Create** writes the selected units (all kinds, with team, neutral flag and the indestructible flag) as a layout, positions relative to the center of the selection, `rot` = heading, `h` = height above ground. After saving: re-read the list, choose the blueprint, add it to the index.
- Placing runs through a load queue (50 units per update) and the gadget. Sorting (`_order.txt`), deleting into the trash (never for good) and renaming (copy under the new name, original into the trash): [Shared code](shared-code.md). A saved blueprint contains only the units you selected.

## 10. Levels

- Ctrl+S writes `levels\<name>.lua`: all units (position, height, team, neutral, rotation, `indestructible = true` and the `arena` flag where set) **and all features** (wrecks, trees, rocks; resurrectable wrecks with `resurrectas`). The file states which game options (e.g. extra pack) must be on in the main game.
- **Sections:** besides the units the file has the scenario info block ([Scenario builder](scenario-builder.md)), `unitlimit`, `mapsize`, and the sections `teams` ([Teams](teams.md)), `towerdefense`, `capture`, `reclaim`, `arena` and `restrictions`, written when the page has been used or the list is not empty. When loading only the known fields of each section are taken over (`knownFields`: the keys of the defaults, plus `spawn` / `goal`); a missing field gets its default, everything else is dropped and not saved again.
- **Loading** a level (level list in the settings) clears the map (except the builder rows) and sets the level up again (features are replaced if the file contains any). `/led_clear` only clears units. Air units in the air are loaded in the air (saved height, otherwise cruise height) and stay in flight mode; air units saved on the ground are loaded landed. The gadget places factories anywhere.
- **Autosave:** every 120 seconds and when leaving as `_last`, only when editing is allowed, the load queue is empty and from game frame 100. It saves to `_last`, not to the named level (that changes only with Ctrl+S or "Save"). `_last` is the state at that moment: units destroyed in a fight meanwhile are gone (wrecks and heaps remain as features). `_beforeplay` is the state before a test run of a page. Both are listed like levels.
- Builders created with Ctrl+D are tools and are not saved.

## 11. Gadget `unit_level_editor.lua`

- **Messages** through `Spring.SendLuaRulesMsg` with the prefix `led|`: `step`, `place`, `delete`, `deleteids`, `boomids`, `boom`, `undo`, `redo`, `clear`, `clearrect`, `clearcircle`, `clearline`, `clearids` (units `u<id>` and features `f<id>` in the way), `fix`, `tdroute`, `ctfpts`, `arenastate`, `arenastart`, `arenastop`, `teams`, `order`, `load`, `generate`, `generaterect`, `builders`, `assign`, `feature`, `loadfeature`, `clearfeatures`, `move`, `movefeatures`, `xform`. Only with cheat or in editor mode; otherwise the message "Cheat mode is off: please type /cheat".
- `GG.LevelEditor` offers the same functions for tests; `GG.LevelEditorSpawnBuilders(x, z, team)` creates the builders (manually without markers, in the team of the call).
- **No gravestone when a unit is taken away:** moving, rotating, mirroring, deleting and undoing set the unit rules parameter `remove_decorations = 1` before `Spring.DestroyUnit` (`destroyUnit`); the game's gadget `unit_tombstones.lua` leaves a tombstone feature next to every destroyed commander unless that parameter is 1. A real explosion (`boom`) keeps wreck and tombstone.
- **Loaded stockpile:** units that can stockpile (nuclear silos, anti-nuke ...) get `max(10, queued)` missiles through `Spring.SetUnitStockpile` when the editor places them (`place`, `generate`; also after undo / redo and when a level is loaded). The call only works in a later frame than `CreateUnit`, so the IDs wait in `pendingStockpile` and `gadget:GameFrame` fills them. The stockpile is not part of the level file; a scenario starts with empty silos.
- **Resurrected units: Hold Position.** When a unit is resurrected (the builder executes `RESURRECT`), it gets `CMD.MOVE_STATE` 0 (`gadget:UnitCreated` with `builderID`, only in editor mode).
- **Unit limit:** `maxunits=32000` (engine upper limit) is divided over the teams: 3150 per team with ten teams, 500 for Gaia ([Teams](teams.md)).
- Handovers (`assign`) by takeover, message with the actual count.

## 12. Files

| File / folder | Content |
|---|---|
| `scripts\lvl_level_editor.lua` | widget |
| `scripts\unit_level_editor.lua` | gadget |
| `scripts\td_waves.lua`, `ctf_game.lua`, `rtf_game.lua` | gadgets of the game modes |
| `scripts\unit_restrictions.lua`, `unit_indestructible.lua` | gadgets of the restrictions and the indestructible buildings (also in scenario packages) |
| `scripts\led_td.lua`, `led_ctf.lua`, `led_rtf.lua`, `led_arena.lua`, `led_teams.lua`, `led_restrictions.lua` | pages of the widget (packed as `luaui/Include/<name>`) |
| `scripts\led_gadgets.lua` | what the gadgets share (`luaui/Include/led_gadgets.lua` in both extra games): `EDITOR_MODE`, `Rules` (bar_rules), `sayer`, `split`, `fields`, `allyOf` and the alliance functions, `builtDef` (also `CMD.INSERT`), `teamMessenger` (a message only to a human team, at most once per unit type every 5 s), `handleMessage` (the messages `<tag>\|<command>\|<payload>` of the widget, only with cheats or in the editor), `option` (a base64url game option of a scenario) |
| `scripts\pve_supply_drops_stub.lua` | replaces BAR's lootbox gadget inside the extra games ([Capture the Flag](capture-the-flag.md)) |
| `scripts\help_texts.lua` | texts of the help board and the chat help (packed as `luaui/Include/led_help_texts.lua`) |
| `scripts\choose_map.ps1`, `map_preview.ps1` | start menu, map picture |
| `scripts\install_editor.ps1`, `editor_manifest.ps1`, `ensure_installed.ps1`, `check_links.ps1`, `uninstall_editor.ps1` and the `.bat` files | setup ([Setup](level-editor-setup.md)) |
| `scenario\` | scenario builder and template ([Scenario builder](scenario-builder.md)) |
| `lan_lobby\` | LAN Play: `lan_lobby.lua`, `install_lan_play.ps1` ([LAN Play](lan-play.md)) |
| `levels\`, `blueprints\` | saved levels; blueprints, `_order.txt`, `_index.txt`, `_trash\` |
| `game-modes\`, `sandbox\` | user manuals of the game modes and the Arena |
| `test-data\` | test levels (`ctf_test`, `rtf_test`, `td_test`, `scav_test`; flat map Full Metal Plate 1.7), the LAN Play test tools, `TESTING.md` (what got in the way); not for playing |
| `%LOCALAPPDATA%\BAR-Level-Editor\` | `Last Map.txt`, `Online Maps Cache.json`, `Scav Units.txt` |
| `data\games\LevelEditorScenarios_<version>.sdz`, `LevelEditorScenarios.txt`, `data\LevelEditorScenarios` | the extra game of the scenarios, the file with its name, the junction to `scenario\scenarios` |

The main folder holds only the `.bat` files, `README.md` and what the setup creates (`start_level_editor.bat`, `editor_script_installed.txt`).

## 13. Quality assurance

See [Testing](testing.md). Short: Lua changes are checked in the real game (there is no Lua interpreter on the development machine); before every hand-over run both installers, start the editor and check the log for errors.

## 14. Known limitations and open points

- The look of the menu was mostly checked with mocks and screenshots; acceptance happens in the game.
- LAN Play: see [LAN Play](lan-play.md), "Tests and findings".
- All side buttons were switched pairwise in a sandbox game (56 pairs, each time exactly the chosen page active; `test-data\tools\zz_menu.lua`). G does not close on a second click (leave with P). Esc closes the help board; the Place button closes the I, O and T pages.
- No AI can be given to a team during the game ([Teams](teams.md)).
- Damage per shot uses the default armor class and ignores special effects (area damage, slowing).
- The editor does not install or update the BluePrinter; the BluePrinter has its own start scripts.
