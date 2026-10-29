# Shared code (`shared\`)

`editor_common.lua` is the code the [Level Editor](level-editor.md) and the [BluePrinter](blueprinter.md) have in common; `bar_rules.lua` holds the rules about unit definitions that gadgets and widgets need alike; `bar_common.ps1` holds the shared parts of the setup scripts and the scenario starter. A change in `editor_common.lua` affects both widgets: changes to the blueprint / unit interface are made there, only what one widget alone needs stays in the widget.

## 1. Rules

- All visible texts are English, without umlauts in texts drawn in the game; no names or private matters of persons.
- The module does not know any widget. Everything widget-specific comes in as options or callbacks (folders, texts, `say`, `ownText`, `onSelect`, `onArm`, `wg`). It returns a table `M` and uses only the Lua 5.1 environment of BAR (`Spring`, `gl`, `GL`, `UnitDefs`, `UnitDefNames`, `WeaponDefs`, `VFS`, `io`, `os`, `math`, `string`, `table`). `WG` is not used globally but passed in through the option `wg`.
- On a second computer the folders `shared`, `LevelEditor` and `BluePrinter` must lie next to each other.

## 2. Loading and installation

| Widget | Load call | Source at runtime |
|---|---|---|
| Level Editor | `VFS.Include("luaui/Include/editor_common.lua", nil, VFS.ZIP_FIRST)` | in the extra game `LevelEditorMod.sdz` |
| BluePrinter | `VFS.Include("LuaUI/Include/editor_common.lua", nil, VFS.RAW_FIRST)` | `data\LuaUI\Include\editor_common.lua` in the BAR write folder |

- The two load paths are deliberately separate so the copy in the extra game is never covered by the copy for the BluePrinter.
- `install_editor.ps1` packs `editor_common.lua` and `bar_rules.lua` into the `.sdz` ([Setup](level-editor-setup.md); the list is `editor_manifest.ps1` and `$ScenarioGameFiles`); `install_blueprinter.ps1` copies them to `data\LuaUI\Include`. Both scripts take the files from the folder `shared` next to the widget folder and abort with a message if it is missing.
- After a change: the Level Editor updates itself at the next start with `start_level_editor.bat` (stamp); for the BluePrinter in a normal game run `BluePrinter\install_blueprinter.bat` (or its start scripts, which compare hashes).
- **File access:** the code reads and writes files through `io.open` and `VFS.DirList`. User widgets (BluePrinter) may only read under `LuaUI/` and only write under `LuaUI/Config/`; the folders of the library (`dirs`) must lie there. Game widgets (Level Editor) are not restricted.

### `bar_common.ps1`

Dot-sourced by `install_editor.ps1`, `uninstall_editor.ps1`, `check_links.ps1`, `ensure_installed.ps1`, `install_lan_play.ps1`, `install_blueprinter.ps1`, `uninstall_blueprinter.ps1`, `start_blueprinter.ps1` and the scenario starter `start_scenario.ps1`. The scenario builder copies it into every package (next to `start_scenario.ps1`, which looks there first and in the editor in `..\..\..\shared`), so there is only one copy of the search.

- `Fail`, `Step` (heading of a setup step), `Read-Yes` (y/n), `Write-GameZip` (a zip through a temporary file),
- `Write-ScenarioGame` and `$ScenarioGameFiles` (the extra game of the scenarios, [Scenario builder](scenario-builder.md)), `$ScenarioGamePointer`,
- `Update-MapHashes` and `$MapHashesFile` (the official map checksums for [LAN Play](lan-play.md)),
- `Find-Bar` (optional folders to try first and a memo file of the last folder found; searches all fixed drives, asks if BAR is not found), `Get-Engine` (the newest engine folder, sorted by the numbers in its name), `Get-GameVersion` (byar:test, otherwise byar:stable, the first whose package is installed),
- `Set-Junction` (creates a junction, points a stale one to the new target, leaves a real folder alone, prints only changes) and `Remove-Junction` (removes only the link).

### `bar_rules.lua`

Installed as `luaui/Include/bar_rules.lua` in the extra games and in `LuaUI\Include` for the BluePrinter. `editor_common.lua`, all gadgets (through `led_gadgets.lua`) load it. Functions: `techLevel(ud)` (1 to 3; every unit named "Epic ..." or with an epic movement class counts as 3, because BAR files a few of them under T1 / T2), `buildClass(ud)` ("economy", "tower", "radar" or nil, for the Tower Defense build restriction and its list), `decode64(text)` (base64url game options), `hitsGround(ud)` (a weapon that can attack the ground), `headingToFacing(h)`. `editor_common.lua` exposes `M.techLevel` and `M.buildClass`.

## 3. Scaling and dimensions (`M.rescale`, `M.m`, `M.S`)

Base dimensions (at `ui_scale = 1` and 4K height 2160): `TILE = 190`, `LABEL = 138`, `PAD = 8`, `UCELL = 284`, `UICON = 270`, `UPAD = 7`, `HB = 58`, `XSIZE = 52`. `M.rescale()` reads `ui_scale`, multiplies it by screen height / 2160 (limited to 0.3 to 3), recomputes `M.m` and returns the factor `S`; the widgets call it in every draw and input event. Every font size and dimension in the menu is a multiple of `S`.

## 4. Helpers

- `M.rotateOffset(dx, dz, k)`: rotates an offset by `k` quarter turns (south → east → north → west, `(dx, dz) → (dz, -dx)`). `M.headingToFacing(h)`: Spring heading → facing 0 to 3 (`floor((h + 8192) / 16384) % 4`). `M.FACING_NAME = South, East, North, West`.
- `M.loadData(text)`: runs the text of a data file (`return { ... }`) in an **empty environment** (`setfenv(chunk, {})`), so a level, blueprint or settings file from elsewhere cannot call anything; returns the value or nil and the error. Used for blueprints, levels, settings and the recent list. `M.parseBlueprint(text)` reads a blueprint (`{ blueprint = { ... } }` is valid).
- `M.writeFile(path, text)`: writes a whole file safely (first `<path>.tmp`, then it replaces the old file). `M.fileText(path)`, `M.teamColor(t)`, `M.isBuildingDef(ud)` (building = `isBuilding` or not mobile).
- `M.matches(query, text)`: every word of the query (split at spaces, case-insensitive) occurs in the lower-case text. `M.unitSearchText(name)`, `M.featureSearchText(name, id)`, `M.blueprintSearchText(bp)` (blueprint name plus the texts of its units) are the lower-case texts the lists are searched in (code, human name, description); results are cached.
- `M.spacingFromWords(spacing, words)` / `M.spacingFromKey(spacing, key)`: new row spacing for `buildspacing inc|dec` and Alt+Z / Alt+X (`M.clampSpacing`, 0 to 20); both widgets use them. `M.paintChain(d, x, z, place)`: painting in both widgets; `d = { x, z, sx, sz }` is the last point of the stroke and the distance to the next; moves `d` towards (x, z) in steps of exactly that distance along the straight line and calls `place(px, pz)` for every step (at most 200 per call), so a fast mouse leaves no gaps.
- `M.shortNumber(n)`: 950, 12.4k, 250k.

## 5. Settings in a config file (`M.newConfig`)

- An object with `v` (values), `sync()`, `save()`, `load()`, `change(key, delta)`. Format: `return { bpCols = 3, bpRows = 4, uCols = 3, uRows = 4 }` with a comment line. Keys `bpCols`, `bpRows` (blueprint grid), `uCols`, `uRows` (units or buildings grid); the Level Editor adds `grid` and `unitLimit`. Default 3 columns and 4 rows; limits columns 1–6, rows 1–8; limited on every change and saved at once. Unknown keys are ignored, missing ones stay default.
- Files: `LuaUI/Config/LevelEditorUI.lua`, `LuaUI/Config/BluePrinterUI.lua`.
- `cfg.transient[key] = true`: the key is neither written nor read (the Level Editor's `unitLimit` belongs to the level). `cfg.steps[key] = { v1, v2, ... }`: `change` moves along this list instead of adding the delta (grid size and unit limit).

### Settings page (`M.newOptions`)

Reachable through the button **O**; replaces the content; a second click on O (or a mode button) leads back. One title per block ("Blueprints", "Units" / "Buildings") with the rows "Columns" and "Rows" (**−**, value, **+**). The Level Editor adds a block "Placing" ("Grid (1 = free)", "Unit limit (scenario)"; `M.newOptions(cfg, blocks)`). Width 460·S; height per block 40·S plus two rows of (HB + 10·S), plus 2·PAD. The mouse wheel does not scroll this page.

## 6. Blueprint library (`M.newLibrary`)

Options: `dirs` (folders with `/` at the end), `say`, `buildingsOnly`, `writeIndex`. `lib.list` always stays the same table (emptied and refilled on scanning). Entry: `{ name, units, count, thumb, dir }`.

- **Format:** a blueprint is a file `<name>.lua`: `return { blueprint = { { name = 'armsolar', dx = -52, dz = 172, h = 0, rot = 32767, team = 0, neutral = false, indestructible = true }, ... } }`. `dx`, `dz`: offset from the center of the selection (rounded); `h`: height above ground; `rot`: Spring heading; `team`, `neutral`: values of the Level Editor. Names `[A-Za-z0-9_-]`; file names with `_` at the start are reserved (`_order.txt`, `_index.txt`, `_trash`). Files with unreadable content or without units are skipped; with `buildingsOnly` a blueprint without buildings disappears.
- **Scanning:** per folder `VFS.DirList(dir, "*.lua", VFS.RAW)` plus the names from `_index.txt` (fallback if the directory is not readable; a name from the index only counts if the file exists). The same name in several folders: the first folder wins. Order: first the names from `_order.txt` of the first folder in that order, then all others alphabetically. `saveOrder()` writes `_order.txt` (with `writeIndex` also `_index.txt`) in the first folder (Level Editor `writeIndex = true`, BluePrinter `false`).
- **Managing:** `remove(name)` copies the file to the trash `<dir>_trash/` (with a timestamp if the name exists), deletes the original, rescans, saves the order; nothing is deleted for good. `rename(old, new)`: name cleaned (`[^%w_%-]` → `_`), empty or unchanged → abort, conflict → "Name already taken"; the file is written under the new name, the old one moved to the trash, the order takes the new name at the old place. `move(from, to)`; `nextName()` (`bp_001`, `bp_002` ... in the first folder); `write(name, lines, header)`; `linesFromUnits(ids, opts)` (lines from selected units relative to the center, sorted; options `onlyBuildings`, `withTeam`, `withFlags` (`indestructible = true` for a unit marked with FX)). The Level Editor's Create uses `withTeam` + `withFlags`, the BluePrinter `onlyBuildings`.
- **Thumbnails:** per blueprint points with a relative position (0 to 1), size and unit ID; size = half the footprint of the building (at least 10), otherwise radius; at most about 150 units per preview; large buildings first. The unit pictures from above (`gl.Texture("#" .. unitDefID)`), not rotated; without a picture a dot in team color, air units with a white border.
- `M.blueprintCost(units)`: sum of metal, energy, build effort, health and count (once per table). `M.blueprintExtent(units, k)`: width / depth of the hull after `k` quarter turns.

## 7. Tile grid for blueprints (`M.newGrid`)

Options: `lib`, `cfg`, `unitWord` ("Units" or "Buildings"), `ownText(on)`, `onSelect(index, moved)`, `onArm(on)`. State: `selected` (0 = none), `armed` (stamp mode), `scroll`, `drag`, `editing`, `confirmDel`, `query`, `focus`. The host passes the rectangle `rect = { x1, y0, x2, top }` on every call.

- `g:list()` returns the tiles shown: the whole library, or with a non-empty `query` a cached filtered view; `selected` and the indices passed to `onSelect` are always library indices. `g:filterRowCount()`, `g:filterRects`, `g:applyFilter`, `g:setFocus`, `g:textInput`, `g:key` provide a search row (BluePrinter; the Level Editor feeds `g.query` from its global search).
- **Tile:** preview `TILE × TILE`, below it a label `LABEL` high; cell width `TILE + 2·PAD`, height `TILE + LABEL + PAD`. Label: name (32·S; from 13 characters shortened with "~"), "N units" / "N buildings" (24·S), the total cost (22·S: "M <metal>" light blue left, "E <energy>" yellow right) and, in the BluePrinter, a fourth line `Eco <time>` (green). The chosen tile is blue, others dark gray. At the top right the **x** for deleting (52·S, character 36·S).
- **Menu width:** with a setting of more than 3 columns the pictures get smaller instead of the menu wider: `g:tile()` = `floor(3 · (TILE + 2·PAD) / bpCols) - 2·PAD`, its texts shrink with it. Grid grows from top to bottom: first a column fills up to `bpRows` tiles, then the next column, up to `bpCols`; beyond that fixed `bpCols` columns of `ceil(n / bpCols)` tiles and scrolling. The menu width follows the column count, the height the row count. If the menu is wider than the grid the grid is centered.
- **Controls:** a click chooses the tile and arms the stamp (`onSelect`); a click into the empty part changes nothing. *Deleting:* a click on the x turns it red and shows "x again" / "(trash)"; a second click on the same x deletes; any other click cancels. *Renaming:* double click (within 0.5 s) on the name; input through `ownText`; `[A-Za-z0-9_-]`, at most 40 characters; Enter (13, 271) accepts, Esc cancels, Backspace deletes, a click elsewhere accepts; shown as "Name_" with the hint "Enter / Esc". *Sorting:* hold on the tile and move more than 8 pixels, the tile hangs on the pointer as a ghost; a yellow line shows the insertion point; at the top and bottom edge the list scrolls; a target in an empty cell of the last column means "to the end"; the order is saved on release. Off while a search is active. *Mouse wheel:* 234·S per notch. Deleting and renaming end the stamp mode.

## 8. Unit catalog and selection grid (`M.newUnits`)

Options: `cfg`, `groups` (offer only these groups; default all), `factions` (offer only these; default all five), `factionUsable(factionId)` (a faction for which it returns false gets no button; the chosen faction moves to the first shown one), `faction`, `canUse(unitDefID)` (unusable units are dimmed (30 % opacity) but remain selectable), `restrict` (only the Level Editor: functions `isBanned`, `setBanned`, `allBanned`; the Arena passes an allow variant), `filter(ud, name)` (own cache of accepted units), `searchLabel`, `search = false`, `noPreview`.

### 8.1 Catalog

- `M.buildUnitCache()` builds `[faction][group][tech] = { { name, id, filler, rank } ... }` once from `UnitDefs`. `M.FACTIONS`, `M.GROUPS`, `M.TECHS` are the button name lists, `M.unitGroup` the group assignment, `M.FACTION_ICONS` the faction symbols.
- **Factions:** Armada (`arm`), Cortex (`cor`), Legion (`leg`) by the name prefix, **Scavengers** (`scv`: every name ending in `_scav`, the copies of all units of the three factions and the units of their own) and **Raptors** (`rap`: names starting with `raptor_`). `M.factionOf(name)`. The last two exist only with the game option `forceallunits` (the lists are empty otherwise and say so); no AI steers them.
- **Groups** in this order: Buildings, Turrets, Bots, Vehicles, Hover, Air, Ships. **Tech** T1 to T3 (`customParams.techlevel`, limited to 1 to 3, default 1; `techLevel(ud)`).
- **Excluded** (for Scavengers the name without `_scav` is tested): names with "scav" (except the `_scav` copies), "decom", "comlvl<digit>", "dummy", "drone", `customParams.isdrone`, decoration (names with `_` at the fourth position like `arm_leftshoulder_nationwars_*`, `cor_hat_*`, and names with `_wings`).

### 8.2 Group assignment (order of the checks)

1. Buildings: `isBuilding` or not mobile. Of these the **Turrets** are those with a weapon (not factories, not `unitgroup` `explo` such as mines); the rest stays in Buildings.
2. Ships: category `ship` or `underwater`.
3. Air: `canFly`.
3a. Raptors (names starting with `raptor_`): bots (their movement classes are called `RAPTORSMALLHOVER` and so on although they walk).
4. Hover: category `hover`.
5. Bots: category `bot`.
6. Otherwise by movement type (`moveDef.name`, upper case; the category BOT no longer exists in BAR): contains "BOAT" → ships, "HOVER" → hover, "BOT" → bots (`BOT2`, `ABOT3`, `HABOT5`, `COMMANDERBOT` ...).
7. Everything else: vehicles.

### 8.3 Sorting

Sort key `rank = (faction block 10000) + (filler 1000) + (water 100) + kind`, then by name; smaller = further front. The faction block is 0 except for Scavengers, whose list holds the units of all three factions: 1 for `arm...`, 2 for `cor...`, 3 for `leg...`, 4 for their own units (`dice`, `lootboxbronze`, ...), each in the usual order one after the other.

- **Turrets:** all the same kind (2); land before water.
- **Buildings:** kind 0 economy (`unitgroup` energy / metal, metal extractors; storage), 1 factories (`isFactory`), 3 other (radar, mines, nano turrets, shields ...). Land first, then water (`minWaterDepth > 0` or floating with `minWaterDepth >= 0`). Fillers (dragon teeth, walls: `customParams.objectify`) at the very back.
- **Bots:** 0 construction bots (everything that can build), 1 combat bots (with weapons), 2 support bots (radar, jammers ...), 3 commander bots (`customParams.iscommander`).
- **Vehicles, hover, ships:** 0 builders, 1 the rest.
- **Air:** land aircraft first: 0 construction, 1 scouts and radar aircraft (`lightairscout` or `unitgroup = util`), 2 interceptors (`unitgroup = aa`), 3 attack aircraft, 4 transports (capacity > 0 and no weapons); after that the seaplanes (`maxWaterDepth > 0`) in the same structure.
- `M.sortUnitNames(names)`: a copy sorted by faction (`M.FACTIONS`), group (`M.GROUPS`), lower-case display name, then code (used by the window of the restricted units).

### 8.4 Display

- Symbol size `UICON = 270·S`, cell `UCELL = 284·S`, margin `UPAD = 7·S`. Default 3 × 4 (`uCols`, `uRows`); width `uCols·UCELL + 2·UPAD + 4`, height `uRows·UCELL + 2·UPAD`. With more than 3 columns the pictures shrink, the menu keeps the width of 3: `u:cell()` = `floor(3 · UCELL / uCols)`, `u:icon()` = cell − (`UCELL` − `UICON`). Mouse wheel 234·S per notch. The chosen unit has a blue frame, the one under the mouse a light frame.
- **Filter buttons** (faction, group (omitted if only one group is offered), tech; no tooltips) above the grid. The faction buttons carry the faction symbol on the left (`sidepics/armada.png`, `cortex.png`, `Legion.png`; 72 % of the button height), the name centered in the rest. **Empty buttons are slightly red** (`u:emptyButton`): a faction with no unit in any group and tech, a group with none for the chosen faction, a tech with none for the chosen faction and group (chosen: light red, others dark red; restricted is stronger red and wins).
- **Search:** `Units:textInput/key/setFocus`, `Units:list()` returns the hits across all factions, groups and tech levels when `query` is not empty; `override` replaces the list (Recent). A host with its own search field (the Level Editor) sets `query` directly.
- **Finding:** `u:locate(name)` sets faction, group and tech to those of the unit, clears `query` and `override`, sets `locateName`; returns true, or nil and "<name> is not in the list". The next `u:draw` scrolls so the row is in the middle and flashes the frame green for 2 s (pulsing `gl.Color(0.1, 1, 0.2, ...)`).
- **Restriction marks** (option `restrict`): `u:xBox(ix, iy)` = 0.3 of the symbol in the upper right corner, `u:xAt(rect, mx, my)`; a restricted unit is dimmed with a big red X and a red box and has "- restricted" in its title line. `u:filterRects` adds after every faction, group and tech button a small X rectangle (kinds `factionx`, `groupx`, `techx`, tinted red when everything it stands for is restricted; the button keeps room with `reserve`). `u:namesOf(kind, value)` lists the names a button stands for right now. `u:applyFilter` turns these kinds into `setBanned(names, not allBanned(names))`. The state is never stored: it is computed at every drawing. The host passes the rectangles to `M.drawButtons` / `M.drawTip` and tests clicks from the last to the first, so the X wins over its button. See [Restrictions](restrictions.md).

### 8.5 Info block (hover)

Under the 3D preview (`M.infoLayout` and `M.infoDraw`, dark ground, as wide as the preview; `M.previewPos` moves the picture up so the block stays on the screen). A line that is too long wraps at words and following lines are indented. Font sizes 26 / 20 / 22 / 22 / 18 · S, enlarged by 1.25. Lines, in this order:

1. name (code); "- restricted" if restricted.
2. the description (`tooltip`), grey, wrapped.
3. `Metal <n>`, `Energy <n>`, `Eco time <time>`, `Health <n>` (`M.costItems`). **Eco time** (`M.ecoTime`) = how long the **stable** income needs to produce this cost, **worst case: the stock is not counted**: for metal and energy `cost / income`, the larger of the two. The income (`M.stableIncome`, recomputed once a second) is the sum of `metalMake` and `energyMake` of all own units (`Spring.GetUnitResources`); what comes in once (reclaim, gifts) is not in it. No income of a needed resource gives `-`. Format: `45 s`, `1:25`, `1:02:10`. In the Level Editor the income is mostly 0, so it shows `-`. The explanation of "Eco time" is deliberately not shown in the game, only in the manuals.
4. only for armed units: `DPS <dps> = <shots/s> shots/s x <damage> dmg` (suffix "(air)" for anti-air; example `DPS 41 = 0.26 shots/s x 157 dmg`), then, if above 0, `Metal per shot <n>` and `Energy per shot <n>` (`metalCost`, `energyCost` of that weapon).
4a. one line each, only if above 0 (`M.reachItems`): `Range <n>` (longest range of a weapon that does damage, `M.weaponRange`), `LoS <n>` (`losRadius`), `Speed <n>`, `Radar <n>` (`radarRadius`), `Radar jammer <n>` (`jammerRadius`), `Sonar <n>` (`sonarRadius`), `Sonar jammer <n>` (`sonarJamRadius`), in Elmo.
5. for buildings and units, one line each if above 0: `Destroyed: <damage> dmg, radius <Elmo>` (`deathExplosion`) and `Self-destruct: <damage> dmg, radius <Elmo>` (`selfDExplosion`); damage in the default armor class (`M.explosionInfo`).

The hover block of a **blueprint** shows name, the sums of metal, energy and health (marked `(Sum)`; Eco time of the sums) and the lines of 4a with the largest value of each over all its units; only `Speed` is the smallest value of the units that move, marked `(Min)`. It shows no Destroyed / Self-destruct. The same block serves a blueprint tile hover (name, count, cost) and **features** (name, cost, description).

**Damage per shot (`M.shotInfo`):** for every weapon the damage per projectile in the default armor class. Anti-air weapons carry only 1 (or a fraction) there and the real damage in the armor class `vtol`; if that is higher, it counts, the weapon is anti-air and the line gets "(air)". With ground and air weapons the ground weapons take priority; the weapon with the highest damage per projectile counts. Shots per second = `projectiles × salvoSize / reload`. Rounding: from 10 a whole number, from 1 one decimal, below that two, without superfluous zeros. Special effects (area damage, slowing) are not considered.

### 8.6 Rows and rectangles (`M.stampPositions`)

`Shift` + drag a row (straight line from the start point to the pointer), `Shift+Alt` a filled rectangle; on release all positions are placed or queued. Spacing between two units: footprint (swapped for east / west) plus `spacing × 16` Elmo; row: step along the longer axis of the mouse movement; rectangle: step per axis. At most 2000 pieces (`maxN` default; the widgets pass 2000 for single units and 100 for blueprints). `M.stampPositionsSized(fx, fz, …)` does it for a whole blueprint hull (`M.blueprintExtent`). Alt+Z / Alt+X are caught by a handler in front of the BAR build menu (`gridmenu_key`), plus the action `buildspacing`. The preview shows frames and models (at most 150).

## 9. Features, recent items, scrollbar

- `M.newFeatures(o)` / `M.buildFeatureCache()`: selection grid for features (kinds trees, rocks, crystals (`pilha_crystal*`), wrecks, rest, by name); `query` searches `M.featureSearchText`; pictures only, cell height `0.4 · UCELL` (small pictures rendered once per feature into a texture, a few per frame); `override` replaces the list (Recent).
- `M.newRecent(file, maxN)`: the most recently used names per kind (`bp`, `unit`, `feature`) in a Lua file. `M.newFav(o)`: the Recent view (blueprint rows, unit symbols and feature tiles); its `query` filters all parts, `matchCount()` returns the number of entries shown.
- Scrollbar (`M.scrollbarDraw(grid, rect)`, `scrollbarPress`, `scrollbarMove`, `scrollbarRelease`): 24·S wide at the right edge of `rect`, drawn only if `grid:maxScroll(rect) > 0`. A click on the thumb keeps the grip, a click on the track centers the thumb under the pointer. The three grids draw it themselves; hosts call press, move and release before handling tile clicks.

## 10. Buttons, tooltips, help board

- `M.drawButtons(rects, fontSize, hb)`: active light blue (0.5 / 0.75 / 1, so the blue Armada symbol stays visible), otherwise dark gray; text centered in the button itself (its own height, so the small X boxes are centered too); the font shrinks if the text does not fit. Fields of a rect: `fs` (own font size), `icon` (symbol left in the button), `tint = { r, g, b }` (fixed color, e.g. reddish for a search field with text or the R button), `reserve` (room kept free at the right end), `tick` (check mark), `cross` (crosshair ring with four lines).
- **Tooltips:** `M.drawTip(rects, mx, my)` notes the tooltip (field `tip`) of the last rectangle under the mouse (the one drawn on top) in `M.pendingTip`; the last one noted in a frame wins. `M.flushTip(skip)` draws it at the very end of `widget:DrawScreen` (both widgets; `skip` while the help board is open) with `gl.Scissor(false)`, so a tooltip always lies on top of every panel and window. A tooltip with its own look (the team strip of the Level Editor) is noted as `M.pendingTip = { fn = function() ... end }`. `M.tooltipBox(text, x, y)` draws it: below left of the pointer, stays on the screen, lines wider than 30 % of the screen (at most 700 px) wrap, explicit line breaks stay.
- `M.drawHelp(title, sections, footer)`: the help board; `sections = { { "Title", { { "Key", "Explanation" }, ... } }, ... }`. Two columns (sections distributed by line count), key column at most 45 % of the column width, long explanations wrapped, font `max(19·S, screen height · 0.0155)`, shrunk step by step if too tall; stays below the minimap frame. The host calls it last in `DrawScreen` and closes it with every click.
- `M.drawRangeCircles(x, z, unitDefID)`: on the ground around (x, z), following the terrain, a red ring for the weapon range and a blue ring for the line of sight (none for 0; returns whether anything was drawn).

## 11. Movable menu (`M.newPanelMover`)

`mv:place(x1, y0, x2, y1, marginLeft, marginRight, marginBottom)` returns the rectangle moved by the offset and kept on the screen (the margins are the room for strips next to the menu). `mv:press(mx, my)` starts a drag, `mv:move(mx, my)` (true while dragging), `mv:release()`, `mv:reset()`; `mv:save()` / `mv:load(t)` give and take the offset as a fraction of the screen size. Both widgets pass their `panelRect()` through it.

## 12. 3D preview

- **Ghosts** (`M.newGhost`): the real unit models semi-transparent (60 %) in team color at the mouse pointer, for single stamps and blueprints. Path 1 (default `auto`): the BAR widget "DrawUnitShape GL4" through `WG.DrawUnitShapeGL4` / `WG.StopDrawUnitShapeGL4`; path 2: directly `gl.UnitShape` in the world drawing. Rotation as in BAR: `facing × 90°` or `heading × π / 32768 (+ stamp rotation)`. Management per model with a key; models no longer drawn are removed at the end of the frame (`endFrame`), `stop` removes all. At most 150 models (`ghost.max`), for large blueprints the units closest to the center. `command(mode, name)` returns the state and switches the mode (`/led_ghost`, `/bp_ghost`); if the BAR widget is missing a message is shown once and it switches to `gl.UnitShape`.
- **Rotating pictures in the lists** (hover over a tile): `M.drawUnitPreview(defID, x1, y1, size, team)`, `M.drawBlueprintPreview(bp, x1, y1, size)`, `M.drawFeaturePreview(defID, x1, y1, size, thumb)`. Units and blueprints use a small shader of their own (fixed lighting, team color from the texture alpha), features the engine rendering (`gl.FeatureShape`). `M.previewPos(rect, tileY, tileH, size)`: left of the team strip if there is room, otherwise right of the menu, at the height of the tile.
- `M.featureThumb(defID)` renders a 96 px picture once into a texture (at most 3 new per frame, `M.featureThumbFrame()` resets the budget, the cache lasts until quitting, `M.freeThumbs()` frees the textures).

## 13. Maze and area attack

- `M.mazeWalls(cols, rows, path, rnd)` returns the wall tiles `{i, j}` (0-based) of a random maze (cells of `path` × `path` tiles, one tile of wall between them, depth-first search, entrance top left, exit bottom right) and width and height in tiles. Used by key M and the Maze sub-tab of the Level Editor. Property: every corridor is reachable from the entrance, the exit is reachable, exactly cells−1 passages (no cycle).
- `M.newAreaAttack(o)` (`o = { say, mouseGround, inPanel, onArm }`): methods `toggle(mode)` ("line" | "rect" | "circle" | nil = off), `armed()`, `mode()`, `press(button)` (map click while armed; true if used), `release()` (starts the attack), `draw()`, `step(frame)` (every frame; synchronized bomber waves), `disarm()`. The logic is described in [BluePrinter](blueprinter.md), "Area attacks".

## 14. Tests

Checked in the real game (compiling under Lua 5.1, building the unit catalog, sorting, damage per shot) and with mocks for `Spring`, `gl`, `VFS` and `UnitDefs` (clicking, dragging, renaming, deleting, settings, mouse wheel, 3D preview, rotating). The mocks do not detect engine limits. Before every hand-over check both widgets and run both installations again ([Testing](testing.md)).
