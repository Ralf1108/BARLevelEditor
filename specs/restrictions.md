# Restrictions of the level

What the player may not build in the game. One list for the whole level, for every game mode and for plain levels. The editor itself can always place everything. User view: [Level Editor manual](../LevelEditor/README.md) (Placing, Restrictions).

## 1. The list

- `rst` (`led_restrictions.lua`, a module of its own because `lvl_level_editor.lua` is at the limit of 200 locals): `rst.data = { banned = { "armllt", ... } }`, names only, sorted by code. Every X of the Place menu and of the Tower Defense page puts single units into this list. `rst.set` is the set of the names.
- Functions: `isBanned`, `setBanned(names, on)` (makes a new list table on each change), `toggle`, `allBanned(names)`, `payload()` ("name,name", "-" for none), `start()` / `stop()` (messages `rst|start|payload`, `rst|stop`).
- Saved in the section `restrictions` of the level file (only when not empty); `rst.load(data.restrictions)` reads it.
- The Tower Defense page (`td.isBanned`, `td.techBanned`, the corner buttons) and the Place menu use the same object: what is restricted in one is restricted in the other. The restrictions hold for everybody; there is no restriction per team.

## 2. Place menu (Units tab)

`Shared.newUnits({ restrict = { isBanned, setBanned, allBanned } })` (only the Level Editor passes it; the BluePrinter does not).

- Every symbol has an X box in the upper right corner (`u:xBox`, `u:xAt`; click = `rst.toggle`). A restricted unit is dimmed with a big red X and has "- restricted" in the title line of the info block. Empty faction, group and tech buttons are slightly red; restricted ones stronger.
- `u:filterRects` adds an X box (kind `factionx` / `groupx` / `techx`, `label = "X"`, red when set) to every faction, group and tech button; the button keeps room for it (`reserve`). `u:applyFilter` handles them:
  - faction = all units of it (`u:namesOf`: all groups and tech levels),
  - group = all tech levels of that group of the chosen faction,
  - tech = all units of that level in all factions and groups (`u:namesOf("tech", t)`; the level as the Place menu counts it: `clamp(floor(techLevel(ud)), 1, 3)`, Epic = 3, half levels count down).
  Each ban all or allow all (`rst.allBanned`).
- The state of every X button (and the red tint of its button) is computed with `rst.allBanned(names)` at every drawing: restricting the last unit of a group turns its X on, allowing one unit turns it off.
- Header clicks and tooltips take the last rectangle under the mouse (the X lies over its button). The Recent tab has no X.
- Drawing and derived state: [Shared code](shared-code.md), "Restriction marks".

## 3. Window of the restricted units (button R)

- `restr`, right of the X (clear search) button of the search row; red as soon as at least one unit is restricted, lighter red while the window is open.
- `rst.drawWindow` (`led_restrictions.lua`): a window left of the menu and its team strip, only while the Place menu is shown. One row per restricted unit: symbol of the faction (Scavengers have none), unit picture, "Name (code)". Order: faction (`M.FACTIONS`), group (`M.GROUPS`), name (`M.sortUnitNames`). The mouse wheel scrolls.
- Buttons: Clear (left of Close; allows every unit again) and Close (also R again).
- A click on a row shows the unit in the Units list like the crosshair button ([Level Editor](level-editor.md), "Finding a unit").

## 4. Gadget `unit_restrictions.lua`

Synced; in the extra game `LevelEditorMod.sdz` and in every scenario package with restrictions.

- Input: message `rst|start|name,name,...` (only with cheats or in the editor game), or at frame 5 the game option `restrictions` (base64url of the same payload, read in `GamePreload`).
- It turns the names into a set of unitDefIDs and
  - tells `GG.BuildBlocking.AddBlockedUnit(unitDefID, team, "level_restrictions")` of BAR for every team except Gaia (BAR then greys the units out in the build menu and refuses the build order itself; `rst|stop` removes the block),
  - refuses build orders itself in `AllowCommand` (cmdID < 0; builders and factories; also orders inserted into a queue with `CMD.INSERT`). Without `GG.BuildBlocking` only this part works.
- It holds for every team, also for computer players (they do not know it and may get stuck trying; accepted). Only a human team gets the message "Not allowed in this level: name (reason)" (`Spring.SendMessageToTeam`), at most once per unit type every 5 seconds; refused orders of AI teams and Gaia stay silent.
- The editor sends `rst|start` when a Tower Defense or Capture the Flag test starts and `rst|stop` when it stops; the Reclaim the Fame start does the same. In the editor itself nothing is blocked.

## 5. Scenario

`Read-Restrictions` in `scenario_builder.ps1` reads the section. With a non-empty list the package gets the game option `restrictions`, the gadget file and `bar_rules.lua`; the starter starts it, like every scenario, with the extra game "Level Editor Scenarios <version>" ([Scenario builder](scenario-builder.md)).

## 6. Not checked

A real mouse click on an X; the greyed-out build menu in a real game.
