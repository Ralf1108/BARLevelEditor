# Specification: BluePrinter

Status: 2026-10-18 (with the carpet attack, row and rectangle stamps, the search field and scrollbars in the lists; all texts are English).

Widget for the **official** Beyond All Reason: blueprint templates and single buildings are **queued** on the map as build plans, idle own builders nearby start **on their own** to carry them out.
Shared code: `..\shared\editor_common.lua` (see `..\shared\SPECIFICATION.md`). Sister project: `..\LevelEditor\SPECIFICATION.md`.

- **Language of the interface:** all visible texts in the game (menu, tooltips, help board, chat messages) are English; no umlauts in game texts. Comments, scripts and documents are English as well.

## 1. Goals and basic rules

- Name of the widget: **BluePrinter** (file `bluePrinter.lua`, folder `BluePrinter`).
- Runs in the normal, official game. Everything happens through **normal build orders** (`Spring.GiveOrderToUnit` with a negative UnitDefID and a position): cost and build time as usual, **no cheat** needed. The game itself is not changed.
- Only **buildings** are planned. Units in blueprints are skipped; mobile units have no build plan (they come from factories).
- The team in the blueprint does not matter, it is built for the own team.
- As a spectator the widget is pointless and removes itself.
- Note: automatic building may count as automation in ranked or tournament games. That is why there is the **Auto-build** switch.
- Source code and texts contain no reference to persons or private matters.

## 2. Installation

- `install_blueprinter.bat` → `install_blueprinter.ps1`: searches BAR on all fixed drives, copies `bluePrinter.lua` to `data\LuaUI\Widgets`, the shared code `shared\editor_common.lua` to `data\LuaUI\Include` (an old `bp_shared.lua` there is deleted) and creates the junctions `data\LuaUI\Config\BluePrinter` → `BluePrinter\blueprints` and, if the folder `LevelEditor` lies next to `BluePrinter`, `data\LuaUI\Config\LevelEditorBlueprints` → `LevelEditor\blueprints`. An old junction `data\BluePrinter` from earlier versions is removed.
- The folder `shared` must lie next to `BluePrinter` (also on a second computer). After every change to the widget or the shared code run the installation again and type `/luaui reload` in the game.
- In the game switch on "Allow user widgets" and activate the widget in the widget list (F11); `enabled = true` is set.
- The widget loads the shared code with `VFS.Include("LuaUI/Include/editor_common.lua", nil, VFS.RAW_FIRST)`.

## 3. Sources for blueprints

- Files `<name>.lua` are read from **`LuaUI/Config/BluePrinter/`** (junction to `BluePrinter\blueprints`, new blueprints are created there too) and from **`LuaUI/Config/LevelEditorBlueprints/`** (the blueprints of the Level Editor, if set up there). With the same name `BluePrinter/` wins.
- **File access of user widgets in BAR (checked in the game):** reading is only allowed under `LuaUI/`, writing only under `LuaUI/Config/` (also through junctions to it). Every other access is rejected with "is outside the read/write paths for user widgets", also for a real folder directly in the data folder. That is why the installer creates the junctions under `data\LuaUI\Config\`; `io.open`, `os.remove`, `os.date` and `VFS.DirList` work there. The Level Editor is a game widget and does not have this restriction.
- Order and trash as in the shared code: `_order.txt` in the first folder (`LuaUI/Config/BluePrinter/`), trash `<folder>_trash/` of the respective folder.
- Blueprints without buildings do not appear. The label shows "N buildings".

## 4. Interface

### 4.1 Panel
- Position: right (default) or left (chat command `/bp_side left|right`; there is no button for it), top edge at 90 % of the screen height. Width at least 270·S, at most 60 % of the screen. Bottom edge at most at 5 % of the screen height, in the buildings view at least 190·S (the info lines are below).
- The menu is visible at the start and scales with the screen height and the UI size slider (`ui_scale`), see shared/SPECIFICATION.md.
- Structure from the top: title "BluePrinter"; the buttons **V** (collapse/expand the menu: one click hides everything except the V, a second brings it back), **O** (settings), **?** (help), **A** (Auto-build on/off, default on) and **C** (commanders help build yes/no, default yes) stand in a **column at the screen edge next to the menu**, one below the other, as in the Level Editor (all buttons use `Shared.drawButtons` with the height `HB` and font 26·S of the editor). Mode row **Blueprints | Buildings**, then the button rows:
  1. **Back** | **Clear all**
  2. **Radius** | **-** | input field | **+**: the field shows the current radius; click it, type a number (digits only, up to 5), Enter accepts, Esc cancels, a click elsewhere accepts; the value is limited to 200–6000. **-** and **+** change it in steps of 200 and the number follows at once.
  3. **Carpet attack: ON/OFF**
  4. **New blueprint from selection**
  Every button of the column has a tooltip (A and C also show the current state). There are no buttons for rotating and for the side of the menu (keys `[` `]`, Alt + mouse wheel and the chat commands `/bp_rotate`, `/bp_side` remain). After that the status lines ("Open N, in progress N, done N", "<hint>" (the rotation is visible in the 3D preview at the mouse pointer) and the "Remaining: …" line) and the content (grid or catalog). Active switches are light blue.

### 4.2 Mode "Blueprints"
- Grid as in the shared code (section 8 there): thumbnails with unit pictures, grows from top to bottom up to 3 columns × 4 rows (adjustable), after that the mouse wheel scrolls (234·S per notch, that is three times the speed plus 30 %).
- Clicking a tile chooses the blueprint and switches on stamp mode; **left click on the map queues it** (any number of times), **right click ends**.
- Sorting by dragging, deleting with x (click twice, trash), renaming by double click – all as in the Level Editor.
- **Search field** above the tiles (from `shared`): all words of the query must appear in the blueprint name or in code, name and description of the buildings inside; the tiles filter at once. Enter = done, Esc or X = clear; sorting by dragging is off while a search is active. A **scrollbar** (24·S wide) at the right edge appears when the list is longer than the area.
- **New blueprint from selection** (button, **Ctrl+Alt+P**, chat `/bp_create`): saves the selected **buildings** (other units are ignored) as `bp_001`, `bp_002` … in `BluePrinter\blueprints` (position relative to the center, team 0), chooses it and switches the stamp on. Without selected buildings a message appears.
- If the list is empty: "No blueprints found".

### 4.3 Mode "Buildings" (single buildings)
- Catalog as in the Level Editor, but only the group buildings: filters for **faction** and **tech** (T1–T3), pictures, sorting (economy, factories, turrets, other; land before water; fillers at the back), info lines with name, code, seconds per shot and damage, description and cost.
- The faction is **preselected by the own builders** (until you click one yourself). Buildings that the own builders **cannot build right now** are dimmed but can still be queued (abilities are refreshed every 60 game frames from the build options of the own mobile builders).
- Click a building → stamp mode; every left click queues **one** building (at the build position snapped by the game, with the chosen rotation), right click ends. If a plan already stands there, "There is already a plan there" appears. Every queueing is a step of its own for "Back".

- **Row / rectangle:** Shift + left click drag = row, Shift+Alt = rectangle (all as **one** step for "Back"); spacing (0 to 20, default 0) with **Alt+Z / Alt+X** (handler in front of the BAR build menu `gridmenu_key`), `buildspacing` action, mouse side buttons 4/5 with Shift, Shift + mouse wheel or chat `/bp_spacing` (details in `shared`).
- **Search in the building menu:** top line above the filters (from `shared`), typing filters at once (code, name and description words); Enter ends, Esc clears. The faction, group and tech buttons have no tooltips; the list has a scrollbar.
- **Tooltips:** all buttons show an explanation when hovered.
- **Help button `?`** (title line, left of `O`; action `bp_helpbox`): shows the help board (menu, building, queueing, carpet attack, chat commands). It is drawn after the menu and lies above it; every click closes it. Content: `HELP_SECTIONS`.
- **Ghosts and manual assignment:** every open plan is also drawn as a 3D ghost (`drawPlanGhosts`, at most `ghost.max` = 150, the ones closest to the mouse pointer). **Right click on a plan** (no stamp or carpet armed) with own builders selected (`assignToPlan`): the plan under the pointer (footprint plus 8 Elmo) is given to all selected builders that can build it as a build order (`giveBuild`, with Shift behind their queue), regardless of radius, auto-build and the commander switch; `claim` is set to the first of them so auto-build does not hand it out again. Selected builders that cannot build it: message, click used; no builder selected: the click is not used. Checked in the real game: right click on a queued solar collector with the commander selected (auto-build off): claimed and built.
- **Visible queue:** a status line "Remaining: metal M, energy E, build time about T" (sum of all open plans; build time = build effort divided by the build power of the own builders, without economy; computed every 30 frames) and in the world a **number on every open plan** (order of the queue, up to 250; blue = open, yellow = in progress, red = blocked). When hovering over a blueprint tile, name, count and cost are shown below the panel.
- **Still open (suggestions):** priorities and builder assignment for plans, automatic rebuilding and repair.
- **Carpet attack** (button "Carpet attack", `/bp_carpet`, Ctrl+Alt+K; earlier "bomber carpet"): select units, switch the mode on and drag a line A→B on the map. Two groups are distinguished, each spreads evenly over the line on its own (sorted by their position along the line, every unit gets an equally long piece): (1) **bombers** (aircraft with a weapon of type `AircraftBomb`): `MOVE` to a point 900 Elmo in front of the center of the piece (against the line direction, inside the map), then `ATTACK` (appended) on the center; this way everyone approaches along the line and the bombs fall spread over the length. (2) **Artillery, rocket launchers, nukes and everything else with blast damage at long range** (`isAreaShooter`: no aircraft, weapon with `canAttackGround ~= false`, blast radius `damageAreaOfEffect` ≥ 16 Elmo and range ≥ 450 Elmo; hits e.g. mortars, Shellshocker, rocket launchers, Merl, Vulcan, Buzzsaw, all nuke silos; not: anti-air, short-range cannons, lasers): only `ATTACK` on the center of the piece (ground target), mobile units walk into range for it. A click without dragging = normal attack on a point. Preview: line, a frame per unit of both groups and the approach paths of the bombers. After the order the mode switches off; right click cancels. Checked: mock test (bomber MOVE+ATTACK, artillery/rockets/nuke only ATTACK, fighters, short-range tanks and anti-air without an order, three shooters split the line into three pieces) and the classification of all unit types in the real game (144 types, e.g. cormart, armmerl, armsilo, corint, armvulc, corbuzz yes; armpw, armflash, armsam, armham no).
- Also applies to **blueprints**: with an armed blueprint Shift + drag = copies in a row, with Shift+Alt in a rectangle (at most 2000 units as a row/rectangle of single buildings; blueprint copies at most 100, spacing as for buildings, all copies as **one** step for "Back"). The preview shows all copies (up to 500 frames).
- The hint text is **above the menu** (24·S): "Click a building, then on the map" or "Left click queues, right click ends, [ and ] rotate", above it "Shift = row, Shift+Alt = rectangle, Shift+Mouse wheel = spacing (N)".
- The faction buttons carry the faction symbol on the left; for buildings the info also contains the explosion (damage, radius).

### 4.4 Settings (button **O**)
- Columns and rows for "Blueprints" and "Buildings" (`bpCols`, `bpRows`, `uCols`, `uRows`), default 3 and 4, limits 1–6 and 1–8, stored in `LuaUI\Config\BluePrinterUI.lua`, immediately on every change.

### 4.5 Preview on the map
- **Queued plans** as frames (footprint of the building, with rotation): blue = planned, yellow = a builder is working on it, red = blocked right now (tried again later).
- **Stamp at the mouse pointer:** green frame if the spot is buildable (`Spring.TestBuildOrder` ≠ 0), otherwise red – and the **3D models** of the buildings (semi-transparent, for blueprints at most 150, the ones closest to the center). `/bp_ghost` shows/sets the mode (`gl`, `wg`, `auto`).
- Positions are snapped to the build grid with `Spring.Pos2BuildPos`; the blueprint center is set to a 16 grid.

### 4.6 Rotating
- **Alt + mouse wheel** (only with an armed stamp), BAR keys **`[` and `]`** (build rotation `buildfacing inc/dec`; BAR gets the key as well), chat `/bp_rotate`. Steps of 90° (south, east, north, west). Offset and facing of all buildings of a blueprint rotate along.

## 5. Plans and auto-build

### 5.1 Data model
A plan (`site`): `def` (UnitDefID), `name`, `x`, `y`, `z`, `f` (facing 0–3), `batch` (number of the queueing step), `done`, `blocked` (until a pass number), `claim` (builder ID), `claimFrame`, `tries`.
Steps: one blueprint or one single building = one step (`batch`).

### 5.2 Actions
- **Back** undoes the group queued last (highest still open `batch`). **Clear all** deletes all open plans.
- Duplicate plans (the same building at the same place, deviation < 4) are not created.

### 5.3 Rhythm
- Every 30 game frames a pass `workPass` (not as a spectator; on an error auto-build is switched off and a message is shown). Every 60 game frames the builder abilities are refreshed.
- In every pass:
  1. Detect finished buildings (at most 30 plans per pass, in turn): an own building of the same kind within 24 Elmo, no longer under construction → `done` (counts in "done", is struck from the list).
  2. Clean up claims: a plan loses its builder when the builder is invalid or dead or has stood without an order for at least 90 game frames.
  3. If auto-build is on and there are open plans: give orders to **every idle builder** (no commands, not building), at most 12 builders per pass.

### 5.4 Which builders
- Mobile, can build, no factory, has build options. **Commanders** only if "Commander: YES".
- A builder only gets plans that it can build (build options) and that lie at most **radius** away. Default 1000 Elmo, adjustable in steps of 200 (200–6000) with the buttons **-** and **+** next to the label "Radius" or by typing the number into the field between them.

### 5.5 Assignment
- For the idle builder the nearest free (not claimed, not blocked) plan is chosen, behind it a **chain** of up to 3 more free plans within 300 Elmo of the previous one (neighbor order), at most 4 orders in total, the first without, the others with Shift (queue).
- If all plans within range are claimed, the builder **helps** with the nearest claimed plan (same build order).
- Before every order `TestBuildOrder` is checked; if it gives 0 (occupied/not buildable), the plan is marked blocked for 10 passes and tried again later. If a plan is assigned unsuccessfully more than 8 times, it is blocked for 40 passes.
- Reclaim obstacles (wrecks, trees) and units in the way (`TestBuildOrder` 1 and 2) are allowed; the builder solves that itself.
- Several builders share the work.

### 5.6 Persistence
- Settings and queued plans are saved through the widget configuration of BAR (`GetConfigData`/`SetConfigData`): side, auto-build, radius, commander, menu visible, rotation, open plans (name, position, facing) **only for the same map**.

## 6. Commands (chat)

`/bp_menu` (menu on/off; auto-build and radius are menu buttons, the chat commands `/bp_auto` and `/bp_radius` were removed), `/bp_rotate`, `/bp_undo`, `/bp_clear`, `/bp_com`, `/bp_side left|right`, `/bp_mode bp|units` (switch between Blueprints and Buildings), `/bp_create`, `/bp_scan` (re-read the list), `/bp_ghost [gl|wg|auto]`, `/bp_spacing <n|+|->`.
Keys: **Ctrl+Alt+P** (blueprint from selection), `[`/`]` (rotate), **Alt+Z / Alt+X** (spacing when dragging).

## 7. Files

| File / folder | Content |
|---|---|
| `bluePrinter.lua` | the widget |
| `install_blueprinter.bat`, `install_blueprinter.ps1` | installation |
| `blueprints\` | own blueprints, `_order.txt`, `_trash\` |
| `README.md` | short manual |
| `SPECIFICATION.md` | this specification |
| `..\shared\editor_common.lua` | shared code |

## 8. Quality assurance

- Widget logic with mocks (Lupa): queueing, order assignment (commander excluded), finished detection, chain and help, dragging, renaming, deleting, quick blueprint, settings, buildings view, 3D preview, rotation, mouse wheel.
- Compilation of the widget and the shared code under the Lua 5.1 of the real engine (headless run). The mock does not detect engine limits (for example at most 60 upvalues per function): after a change start the game once and check the log.

## 9. Known limitations and open points

- Look and behavior in the real game are only checked with mocks (apart from the points listed under tests); acceptance happens in the game.
- Only buildings; plans for mobile units (e.g. "build in the next factory") are a possible later step.
- Whether auto-build is allowed in ranked or tournament games depends on their rules.

## Tests (status 2026-10-18)
- **Mock test** (not in the repository; Python with Lupa): plan and builder logic, stamp, row/rectangle, Alt+Z/X, collapsing/expanding the menu, carpet attack (bombers: MOVE/ATTACK per bomber; artillery, rockets and nukes: ATTACK; fighters, short-range weapons and anti-air excluded).
- **Test in the running game:** the blueprint list loads from `LuaUI/Config` without errors (7 blueprints of the Level Editor visible); a new blueprint from the selection is written and removed again (`io.open`, `os.remove`); buildings view with the search field; queueing plans; status line and queue numbers; blueprint cost when hovering; bomber carpet: both bombers get MOVE and ATTACK, the scout gets no order.
- **Found and fixed:** before the change of the folders the widget could not read or write blueprint files in BAR (see file access above).
- **Help board checked in the game:** the board was first covered by the menu; now it is drawn last.

