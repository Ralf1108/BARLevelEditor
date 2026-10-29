# Arena

Button **A** (page `led_arena.lua`). A tool like Generate, not a game mode: no scenario, no winner, no result display. It sets up armies of different teams around one point and lets them fight, so one can watch units against each other (for example 100 Behemoths against 100 Juggernauts). The settings are saved in the level, the march order is not. User view: [Arena manual](../LevelEditor/sandbox/arena.md).

## 1. Button and page

**A** sits in the button column between **G** and **TD** (same colors as the other pages: lighter while the page is open). The page is the table `ar` of the widget; its functions live in `led_arena.lua` (`luaui/Include/led_arena.lua`, a function that gets `ar` and the host table `H`, like `led_td.lua`; the widget is at the limit of 200 locals). The page exists in the editor only (the gadget part is in `unit_level_editor.lua`).

Page, top to bottom:

1. **Radius** (Elmo, default 1000): the distance of every army from the Arena Point.
2. **Budget for all rows**: Metal and Energy (inputs "M 5000", "E 5000").
3. **Table of 10 rows** (row n = team n-1, same numbers and colors as the team buttons; a team the game does not have is gray and is skipped by Generate and Start with a message; Gaia is no row):
   - **On / Off** (the first two rows are on at the start),
   - the button **Units**,
   - **Count** (input, default 50),
   - **Metal** and **Energy** (inputs),
   - the **remaining budget**.
   The **team number** of a row is a button: it opens the menu "Copy to" with the other teams; a click copies on / off, count, budget and allowed units of this row to that team. Under the column heads is a row of **C** buttons, one per column (Team has "-"): a button writes the value of its column into all other rows, also those that are off. Metal / Energy take the two budget fields; On, Count and Units take the value of the first team (Units copies its allowed list).
4. **Buttons:** **Generate**, **Arena Point** (sets / moves the point), **X** (deletes it), **Clear**; below them **Formation attack** (toggle, green when on) and **Start** (red **Stop** while it runs).

A row that is off gets nothing generated and its units get no fight order at Start.

## 2. Units button and unit window

- The button is green with the number of allowed unit types ("Units 12"), gray when 0. A new row allows nothing. A click opens the **unit window** left of the team strip, as wide as the Place menu (`uGrid:size()`); the same button closes it.
- The window is the Place menu without the tabs Recent / Features / Blueprints: the Units tab with the filters (faction, group, tech) and the search. Every unit tile has a **green check box** in the upper right corner instead of the red X of the restrictions (click = allowed / not allowed for this army; a click anywhere on the tile does the same). The check boxes of the faction, group and tech buttons allow or remove all units of that filter at once; a button of which only some units are allowed has a light green shade, all of them a stronger one (`restrict.anyBanned`). `Shared.newUnits` gets an allow variant of its `restrict` hook (green, no dimming).
- The head is a row in the team color ("Team n: allowed units"), then **Clear Allowed Units** and the reddish **Close**. Hovering a tile shows the 3D preview and the info text like the Place menu (same code).
- Only units that **move** and **turrets** (armed buildings) are offered; factories, economy buildings, walls and other buildings are hidden.
- The lists are independent of the [restrictions](restrictions.md) and of Tower Defense; while the window is open the check boxes change the army list, not the restrictions.

## 3. Arena Point

A point on the map, drawn as a thick red circle (about 64 Elmo) and, while the page is open, a thin red ring of the radius. The button **Arena Point** arms the mode (click on the map sets or moves the point; right click ends). **Alt + left mouse button** over the point (64 Elmo, also with the page closed) moves only the point, **Shift + Alt + drag** moves the whole setup (section 5). **Del** over the point and the button **X** delete it.

## 4. Generate and Clear

**Generate** arms the mode (the Arena Point hangs half transparent at the mouse pointer, `ar.drawWorld`); a click on the map sets the Arena Point there (it moves if it existed) and places all armies of the rows that are on. It is a single action; one undo step.

- **Geometry:** the armies stand on equal angles around the point at the distance radius (2 armies opposite each other, 10 like pizza slices), every army as a rectangle (rows and columns of cells of the largest footprint in the army plus the spacing), facing the point. The units of an army are ordered by type.
- **What and how many:** units are drawn at random from the allowed units of the row that still fit into its remaining budget, until the count is reached or no allowed unit fits any more. An empty budget field means unlimited (Metal and Energy separately); both empty = no budget. Count empty = no limit by count. Count empty and no budget: nothing is generated for that row and a message says so. An army never has more than 3000 units on the map (or the engine limit of the team, if lower).
- **Remaining budget:** budget minus the cost of all units of that team on the map (also those placed by hand and the commander); it may be negative. Generate fills only what is left.
- **Every unit is placed:** a unit that does not fit its spot (water depth and slope against its move definition: `minWaterDepth`, `maxWaterDepth`, `maxSlope`; ships only in water; air units anywhere; turrets by `Spring.TestBuildOrder`) goes to the nearest free ground, like a ring around the block, as long as count and budget are left. Trees, rocks and other units are ignored (the switch W does not count). Only when no fitting ground exists (for example ships on a map without water) the rest is dropped, with a message such as "Army 3: 87 of 100 placed (no fitting ground)".
- **Map edge:** an army (its rectangle) outside the map is shifted as a whole onto the map with at least 100 Elmo distance to the edge.
- **Marked units:** the units carry the flag `arena` (saved in the level file like `indestructible`, a unit rules parameter) so that Clear knows them.
- **Clear** deletes only the units Generate placed (all rows) and the Arena Point; units placed by hand stay. One undo step.

## 5. Moving the setup

Every army keeps its natural spot (point + radius * direction, as generated); its actual spot is the natural spot pushed onto the map (100 Elmo margin). **Shift + Alt + drag** moves the point and every natural spot by the same offset; the units of an army move by the change of its actual spot. An army that was pushed inward stays where it is until the point is far enough inside that its natural spot is on the map again; then it follows. One undo step.

## 6. Start and Stop

Like the Tower Defense test. **Start** needs an Arena Point (else the red message "Set the Arena Point first") and no running Tower Defense test (both use `_beforeplay`). It saves the level as `_beforeplay` and sends `led|arenastart|x|z|teams|formation` to the gadget (it sets the game rules parameter `arenaState` = `running`), which gives every unit of the teams whose row is on that can move (Gaia not) the fight order (`CMD.FIGHT`, so they attack on the way).

- **Formation:** every army keeps its rectangle. The target of a unit is its own position shifted by the vector from the center of its army to the Arena Point, so every unit walks straight ahead and the center ends on the point (a front, no heap). Targets are kept 16 Elmo inside the map.
- **Formation attack** (button; `formation` in the section `arena`, default on): the fighting is the engine's. `CMD.FIGHT` attacks everything that comes into weapon range on the way (long range and artillery stop early and fire), `CMD.PATROL` does the same between two places again and again.
  - *Phase 1* (only with the button on; `startArena` and `arenaStep` in `unit_level_editor.lua`, `arenaStep` every 10 frames): every unit walks at the speed of the slowest unit of all armies until the center of its army is at 25 % of its first distance from the point (`CMD.FIGHT` to its own place shifted by 75 % of the vector to the point). The cap is the move type data (`Spring.MoveCtrl.SetGroundMoveTypeData` / `SetGunshipMoveTypeData` / `SetAirMoveTypeData`, `maxSpeed` and `maxWantedSpeed`); `CMD.SET_WANTED_MAX_SPEED` alone does not limit the speed.
  - *Phase 2* (`arenaFight`; with the button off it starts at once, without a cap): full speed, `CMD.FIGHT` to 250 Elmo in front of the Arena Point (every unit to its own place shifted along the line of its army to the point), then a queued `CMD.PATROL` to 250 Elmo behind it (through the other army): the units go back and forth through the point and fight on the way. No unit fires at the ground (the area attack `CMD.ATTACK` with a radius did, while enemies were out of range); with the button off the first shots fall about 300 frames earlier.
- The camera stays.
- **Stop** sends `led|arenastop` and loads `_beforeplay` again (`load_level`, like `td.toggle`): everything is as before, destroyed units are back, every run starts the same. What the user changes on the pages while the fight runs is kept (settings of the pages, the teams of the page T, the restrictions, the scenario info: `reloadBeforePlay` in `lvl_level_editor.lua` takes them over after loading `_beforeplay`, the same for the Stop of Tower Defense, Capture the Flag and Reclaim the Fame); what is placed or deleted on the map meanwhile is lost.

## 7. Undo

Every action of the page is one history step (Ctrl+Z / Ctrl+Y): set / move / delete the point, Generate, Clear, move of the setup. The state of the point and the armies is written as text (`ar.state()`) and sent as `led|arenastate|before|after`; the gadget keeps it as the operation `arena` of the history next to the unit steps (as `tdroute` does for Tower Defense). Start and Stop are not in the history.

## 8. Data and messages

Section `arena` of the level file (written by `saveLevel`, read by `load_level` into `ar.data`; only the known fields):

| Field | Meaning |
|---|---|
| `radius` | Elmo |
| `budget` | `{ metal, energy }` (global fields) |
| `point` | `{ x, z }`, missing = none |
| `rows` | 10 entries by team: `on`, `count`, `metal`, `energy`, `allowed` (list of unit names) |
| `formation` | boolean |
| `armies` | list of `{ team, nx, nz, ax, az, hw, hh }`, one per team, of its last Generate: natural spot, actual spot and half width / height of the block, so moving works after loading |

The march order is not saved. The scenario builder does not read the section; the marked units are normal units in a scenario.

Messages: `led|place` has a tenth field (`1` = placed by Arena) and `led|load` a twelfth; `led|arenastart|x|z|teams|formation`, `led|arenastop`, `led|arenastate|before|after`; Clear sends the ids as `led|clearids` in one step. The gadget keeps the flag in the snapshot of a unit (undo, redo, and the move of a selection keep it).

## 9. Not checked

Clicking with the real mouse (Alt + drag, Shift + Alt + drag, the clicks in the table and the window); the number fields typed by hand; ships and air units; a fight with armies that really meet (the test armies were 3000 Elmo apart and only marched); 3000 units per army (the largest test had 55).
