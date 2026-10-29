# Tower Defense

Button **TD** (gadget `td_waves.lua`, page `led_td.lua`). Waves of enemy land units walk from a spawn point through waypoints to a goal; the player builds towers next to the route. The level author builds corridors, sets the route and the waves and says what the player may build. The page can start a test in the editor (**Start**); the [scenario builder](scenario-builder.md) packs it for the official game. User view: [Tower Defense manual](../LevelEditor/game-modes/tower-defense.md).

## 1. Widget

- The page is the table `td` of the widget; its functions are in `led_td.lua` (`luaui/Include/led_td.lua`, a function that gets `td` and a host table `H`: getters such as `H.S()`, `H.team()` for values that change, the functions and tables of the widget, and `H.armUnit`, `H.disarmModes`, `H.restoreBeforePlay` for what changes its state).
- `td.layout` builds buttons and labels (also used by `td.press`, `td.height`, `DebugLayout`); `td.draw` / `td.drawTiles` draw; `td.press`, `td.key`, `td.text`, `td.wheel` handle input; `td.drawWorld` (also with the page closed, as soon as something is set; only the highlight of the point under the mouse needs the open page) draws spawn point (green circle), goal (red circle of 120 Elmo), the waypoints and the line spawn → waypoints → goal; `td.hud` draws the status at the top.
- The page is wider (780·S) than the others and excludes the other pages like Generate does. The title row reads "Level Editor - Tower Defense" while the mode is on or the page is open.
- Exclusive with Capture the Flag and Reclaim the Fame: ticking `tdon` sets `ctf.data.enabled` and `rtf.data.enabled` to false.

## 2. Data

Section `towerdefense` of the level file (a Lua table next to `unitloadout`; written by `saveLevel` through `td.lua`, read by `load_level` into `td.data` with `knownFields`; the scenario builder reads it with `Read-TowerDefense`). Without the section the page shows the defaults and nothing is written.

| Field | Meaning |
|---|---|
| `enabled` | the mode is on |
| `width` | corridor width in tiles of 16 Elmo: 2, 4, 8 (default), 10, 12 |
| `leaks` | enemies allowed through |
| `spawn`, `goal` | `{x, z}` |
| `waypoints` | ordered list of `{x, z}` |
| `economy`, `fog` | booleans, default on (missing counts as on) |
| `waves` | list of `{fac, kind, tech, count, gap, hp}` |

Wave fields: `fac` is a string of the chosen factions (e.g. `armcor`), `tech` e.g. `12`, `kind` e.g. `vb` (`v` vehicles, `b` bots, `h` hovercraft). `td.chosen` and `td.toggleChoice` make sure one choice per group always stays on. `gap` = seconds after the previous wave (default 0 for wave 1), `hp` = percent.

## 3. Page, top to bottom

Checkbox `tdon` (green when on); **Walls**: material `tdmat` (Teeth / Walls) and the button `tddraw` Single; **Corridor (walls on both sides)**: `tddraw` Line | Free; **Corridor width** `tdwidth`; **Route**: `Spawn X | Waypoint X | Goal X`; **Enemies allowed through** (- / number / +); **Waves** (- / number / +) and the table (wave number, three faction toggles with symbols, T1–T3, V B H, count, gap, HP %; 8 rows, the mouse wheel scrolls); **Restrictions**: toggles `tdeconomy` and `tdfog`, faction buttons `tdfac`, category buttons `tdcat`, tech buttons `tdtech` (each with a red X `tdtechx`), the tiles; a red message (`td.notice`, 6 s); at the bottom `tdplay`. All buttons have tooltips.

## 4. Corridors

`td.pick` = "corridor" | "waypoint" | "spawn" | "goal", `td.mode` = "single" | "line" | "free"; right click ends the mode (`td.cancel`; a drawn line with at least two points is built first). The mode stays on after every corridor.

- *Single* (`td.startSingle`, `td.sdrag`, `td.sample`): a press places one wall piece on the 16 Elmo grid; while the button is held a piece in every cell the pointer passes (no cell twice per stroke); one undo step per stroke.
- *Line*: clicks collect points (`td.pts`), right click or Enter builds.
- *Free*: a press starts `td.stroke`, `td.sample` adds a point whenever the mouse moved 48 Elmo, release builds.
- `td.finishDraw` simplifies the line (`td.simplify`, Douglas-Peucker, 24 Elmo) and calls `td.buildWalls`: `td.wallSpots` every 8 Elmo along both offset lines (offset = half corridor + 8, snapped to the grid, no piece inside the corridor of another section) plus an arc of pieces (radius = offset, every 8 Elmo) around every bend on the outer side, so corners are closed (only hairpins tighter than the corridor is wide stay open).
- The pieces go through `placeQueue` as one undo step with `led|place|...|1`; what is in the way is handled by W ([Level Editor](level-editor.md), "Write"). A corridor does not touch spawn point, goal and waypoints.
- The pieces are indestructible (section 9).

## 5. Route

- *Spawn* / *Goal*: click, then click the map; X deletes it.
- *Waypoint*: every click adds a point via `td.addWaypoint` (onto a drawn line between two points of the route — spawn point, waypoints, goal; within 48 Elmo, projection inside the segment — it is inserted there, otherwise behind the nearest point of the route). The mode stays on, right click ends. The X next to it deletes all waypoints.
- Alt + left mouse button over a waypoint (64 Elmo), the spawn point (64 Elmo) or the goal (goal radius) (`td.dragAt`, `td.waypointAt`, `td.wpDrag`) moves it while the button is held, also with the page closed; `widget:MouseRelease` ends it (`td.endWpDrag`, one undo step).
- Del (`td.deleteWaypoint`) removes the waypoint under the mouse pointer.
- `td.route()` is the waypoint list in order; the payload field `path` carries it, the gadget walks spawn → path → goal.
- **Undo of the route:** `td.routeState()` writes spawn, goal and waypoints as text ("sx,sz;gx,gz;x,z/x,z"); every change (`td.commit(before)`) sends `led|step` and `led|tdroute|before|after`. The gadget records the operation `tdroute` in its history (with the unit steps, so Ctrl+Z / Ctrl+Y keep the order) and on undo / redo publishes the state through the game rules parameters `led_tdroute` and `led_tdroute_n`; `td.pollRoute` (every `widget:Update`) applies it.

## 6. Start, Stop, Reset

Button `tdplay` (`td.toggle`; green "Start", red "Stop" while running, green "Reset" when won or lost).

- With no state (`tdState` empty) it needs spawn point and goal (else the red message and a chat message), saves the level as `_beforeplay` (shown in the level list like `_last`) and sends `tdw|start|<payload>`.
- With a state it sends `tdw|stop` and loads `_beforeplay` again through `load_level` (`currentLevel` stays), so destroyed towers, wave units and the removed commander are back / gone.
- The gadget marks the wave units with the public unit rules parameter `led_nosave`; `saveLevel` skips them (also the autosave). The flags and collection points of Capture the Flag carry it too.
- At the start the gadget destroys the commanders of the player team (the builders are placed by the level). The payload fields 14 `metal` and 15 `energy` (start resources of the level, default 1000) are applied three frames later by `GameFrame` in the editor (`EDITOR_MODE`): resources and storage of the player (storage at least 1000). The editor gadget does not refill that team while `tdState` is not empty (rules parameters `tdState`, `tdPlayer`); after Stop the refill (1e9 / 1e10) starts again within half a second. In a finished scenario the resources come from its game options.

## 7. Restrictions on the page

- Towers can always be built. `economy` on: also economy structures (unitgroup energy / metal or `extractsMetal`: extractors, solar, wind, geothermal, fusion, storage, converters); `fog` on: also radars (`radarDistance > 0`). Both also decide which categories the list offers (`td.cats()`: Towers, Economy, Radars).
- `Shared.buildClass` (`bar_rules.lua`; the gadget uses it as `buildClass`) sorts structures (factories: none; tower = armed and not unitgroup explo).
- The tiles (`td.turrets(fac, tech, cat)`, from `Shared.buildUnitCache`, groups buildings and turrets, land only, built once in `td.tcache`; 8 per row, at most 4 rows, the mouse wheel scrolls, `td.tscroll`): picture `#unitDefID`; hover shows the 3D model (`Shared.drawUnitPreview`) and name / cost below the panel; a click arms placing like the unit list of the Place tab (`td.armUnit`; painting, Ctrl, Alt and Shift work).
- The corner button `tdban` (red X, `rst.toggle`) restricts the tower (dimmed, big red X); `tdtechx` restricts all units of a tech level like the Place menu (`rst.setBanned(uGrid:namesOf("tech", t), ...)`, button tinted red while all are restricted). Both write the [restrictions](restrictions.md) of the level. The editor itself can always place everything.

## 8. Gadget

- **Enforcement:** payload `enemyTeam;playerTeam;spawnX;spawnZ;goalX;goalZ;leaks;path;waves;restrict;fog;metal;energy` (head of `td_waves.lua`; `restrict` = "economy" when Economy is on, else "towers"), by message `tdw|start|…` or the game option `tdconfig`. While a game runs `gadget:AllowCommand` (registered for all commands) refuses build orders of the player team (cmdID < 0, also inserted into a queue with `CMD.INSERT`) for structures outside the allowed classes (radars only with fog). The restricted units and tech levels are refused by `unit_restrictions.lua` ([Restrictions](restrictions.md)); units from factories are not restricted. The message "Not allowed in this level: name (reason)" goes only to the team of the order, at most once per unit type every 5 s. The rule holds for every human team of the ally team of the player (`playerTeams`: several humans of a LAN game, Copilots included; the AI teams there stay free).
- **Waves:** `tdw|stop`; a wave starts `gap` seconds after the previous one (the first after the start; in a scenario at frame 30, `START_FRAME`); the units of a wave appear one after the other (every 12 frames) at the spawn point, get `MOVE` orders along the path to the goal, health scaled by `hp`.
- **Unit choice:** random land unit (mobile, armed, no builder, ship or aircraft; bots and vehicles by the movement class `ud.moveDef.name`: bot*, otherwise not hover) among all that fit one of the chosen factions, tech levels and types. Units without any weapon that can hit the ground (`WeaponDefs[..].canAttackGround`, pure anti-air such as `armjeth`, `coraak`) are left out. Tech level: `techLevel(ud)` (`bar_rules.lua`; Epic units count as T3).
- **Pay and result:** a kill pays the metal and energy cost of the unit to the player team (player = first team with role Player, enemy = first with role Enemy, otherwise team 1; with the [teams](teams.md) page: player = first human team, enemy = first AI team). An enemy within 120 Elmo of the goal is removed and counts as through; more than `leaks` = lost; all waves gone and no enemy alive = won (outside the editor the gadget ends the game with `Spring.GameOver`). Status in the game rules parameters `tdState`, `tdWave`, `tdWaves`, `tdLeaks`, `tdMaxLeaks`, `tdKilled`, `tdAlive`.
- **Stuck enemies** (scenario): every 30 s (`STUCK_FRAMES`) a wave unit that has moved less than 64 Elmo gets its route again from the nearest waypoint on (`giveRoute`); after 2 such tries (`STUCK_TRIES`) it is removed with a message and counts neither as through nor as killed, so the last wave always ends.
- **Visibility:** in a finished scenario (`not EDITOR_MODE`) the gadget calls `Spring.SetGlobalLos(allyTeam, not fog)` at the start; the editor keeps its global view (it needs it to save).

## 9. Indestructible pieces

- `led|place` has a ninth field (1) and `led|load` an eleventh; the gadget (`setIndestructible`) puts the unit into the table `GG.Indestructible` (shared with the gadget `unit_indestructible.lua`) and sets the public unit rules parameter `indestructible`.
- `unit_indestructible.lua` protects the units in the table: `gadget:UnitPreDamaged` returns 0 (also crushing and any weapon), `UnitDestroyed` removes the entry. They cannot be taken apart either: `AllowCommand` (reclaim, capture, self destruction) refuses those orders on one such unit, `AllowUnitBuildStep` refuses every reclaiming step (area reclaim included). Deleting or blowing them up with the editor still works (it is not damage).
- The corridor pieces get the flag; the buttons FX / FD set and remove it for the buildings in a rectangle ([Level Editor](level-editor.md), button column). Only buildings (speed 0).
- The flag is part of the snapshot (undo, redo, rotate, mirror keep it), of blueprints and of the clipboard (`indestructible = true` in the file; placing sends the eleventh field); `saveLevel` writes it into the unit line and `load_level` sends it again.
- In every scenario (any game mode or none) the gadget protects the flagged buildings again: the scenario builder writes the game option `fixedunits` (base64url of `name:x,z,x,z|name:...`) and packs the gadget whenever the level has such a building; the gadget marks the units of the list at frames 5, 30 and 90 (unit at that position with that name within 10 Elmo). The gadget is in both extra games.

## 10. Scenario

A level with Tower Defense on becomes a Tower Defense scenario ([Scenario builder](scenario-builder.md), "Game modes in the scenario"): everything on this page is packed.

## 11. Open

The loss condition (more through than allowed) is only read, not tested in a scenario; balance of the pay and the strength; the scenario was not played to the end (won / lost).
