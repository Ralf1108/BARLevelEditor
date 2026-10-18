# Level Editor

Place units on the map with the mouse, blow them up, save them and load them again later. The result is a `unitloadout` list for scenarios.

## Setup (once per computer, BAR must be installed)
1. Download or clone the repository and keep the folders `LevelEditor` and `shared` next to each other.
2. Run `install_editor.bat`. It searches BAR on all fixed drives (e.g. C:\Games, D:\Games, Program Files) and finds BAR and the engine, determines the installed game version, builds the extra game `data\games\LevelEditorMod.sdz` ("Level Editor", builds on the official BAR), creates the junction `data\LevelEditor` -> `levels`, writes `start_level_editor.bat` and creates the desktop shortcut "BAR Level Editor".
3. After a BAR update run `install_editor.bat` again (the game version is stored in the extra game). Also after changes to the widget or gadget.
4. Removing it again: run `uninstall_editor.bat` (it asks first). It removes the extra game, the two junctions in the game folder, the desktop icon, `start_level_editor.bat` and the start script. Saved levels and blueprints stay in the folders `levels` and `blueprints`, the official game is not touched. With `uninstall_editor.bat -WithSettings` the settings files of the editor in the game folder are deleted too, with `-Yes` the confirmation is skipped.
The official game is not changed.

## Starting
Desktop shortcut "BAR Level Editor" (or `start_level_editor.bat`). Menu (always shown; arrow up/down and Enter or a digit key): 0 = continue the last state (the editor saves every 2 minutes and when leaving as `_last`), 1 = new level (choose a map, search while typing; the list contains all BAR maps from the internet, missing ones are only downloaded after the selection, offline only installed ones), 2 = load an existing level (list from `levels`, with search), 3 = build a scenario package (ZIP) from a level. When loading, the editor starts on the saved map and sets up the units automatically (via `levels\_autoload.txt`).

## In the game
In editor mode (game option `leveleditor=1`) no /cheat and no /globallos are needed. Everything is free and finished instantly. Legion, the extra pack and release candidates are on. At the start only the commander stands there. You create the builders of all factions yourself when needed with Ctrl+D (see below); they are tools and are not saved in the level. The unit limit is raised to 32000 (`maxunits`).
- The menu has two main parts: **Place** (sub-tabs **Recent**, **Units**, **Features**, **Blueprints**) and **Generate** (sub-tabs **Units**, **Maze**). **Recent** is the former Favorites tab.
- Chat commands are only left for diagnosis: `/led_help` shows the short version and the topics (`/led_help <topic>` explains details: `start`, `keys`, `place`, `units`, `blueprint`, `save`, `team`, `edit`, `features`, `search`, `scenario`, `build`), `/led_clear` clears the map, `/led_ghost` shows the state of the 3D preview. Everything else works through keys and buttons.
- The grid (1 = free, 16 normal) and the unit limit are set in the settings (button **O**). You choose unit and team in the menu and with the team buttons; selected units get the team with a click on a team button. Next to every team button the current number of units of that team is shown.
- **Generate menu** (button next to Place): the same, but with the mouse. Sub-tab **Units**: choose faction, type (units, buildings, turrets, air, ships; several possible), tech T1-T3 and the count (input field, 1 to 2000), choose the **Area** (rectangle, or circle: drag from the center outwards), press **Generate** and drag it on the map; random units appear in it for the team chosen on the left (N = neutral). Sub-tab **Maze**: choose faction and material (dragon teeth or walls), then press **Generate** (Area as above) and drag; a random maze appears in it (see below).
- Save the selected units as a layout with **Create** in the blueprint menu (folder `blueprints`); a click on a tile chooses it, left click places it centered at the mouse pointer (with the saved teams, or for the team chosen on the left).
- **Search**: one field at the top of the Place menu searches **recent items, units, features and blueprints at once** (words of the description or the code; all words must match; for blueprints also the units inside). The Recent, Units, Features and Blueprints tabs show the number of matches and list them. The field turns reddish while it contains a text. Enter = done, Esc or X = clear; a click on a faction/group/tech/feature-kind button ends the search. Sorting blueprints by dragging is off while a search is active. All lists have a **scrollbar** at the right edge (drag the thumb or click the track; the mouse wheel works as before).
- Blueprint menu: the **Blueprints** tab of the Place menu shows tiles with preview pictures (unit positions in team colors, air units with a white border), the name, the number of units and the total cost of the blueprint (`M` metal, `E` energy). Click a tile, then left click on the map places it (with an outline preview at the mouse pointer), right click ends, the mouse wheel scrolls. The list comes from the folder `blueprints` (and from `_index.txt` as a fallback).
- Air units appear in the air when placed and loaded (when loading with the saved height, otherwise cruise height) and stay in flight mode. Air units that stood on the ground when saving are loaded landed.
- **Shift + drag** places a row of the armed unit, feature or blueprint, **Shift + Alt + drag** a rectangle (all are placed on release); **Shift + mouse wheel** changes the spacing.
- [ and ] rotate the unit or blueprint stamp by 90 degrees. Del deletes and Ctrl+B blows up (wreck stays); both work on the selected units, without a selection on the unit, wreck or feature at the mouse pointer. Ctrl+Z undoes the last action (placing, deleting, moving, generating ...), Ctrl+Y redoes it.
- Ctrl+S writes `levels\<name>.lua` (units and features, so also wrecks and trees). The level list in the settings (button **O**) clears up (except the builder rows) and sets a level up again. `/led_clear` only clears up.
- Resurrected units are set to hold position.
- Nuclear silos and other units that stockpile missiles start **loaded** (10 missiles) when you place or generate them, so you can try them at once. The missiles are not saved in the level: a scenario built from it starts with empty silos.

## Files
- `lvl_level_editor.lua` - widget (controls, saving, loading)
- `unit_level_editor.lua` - gadget (places, deletes, blows up, build mode)
- `choose_map.ps1` - start menu and map selection (all maps, download after the selection), writes `editor_script_installed.txt`; `maps_online_cache.json` is the cached map list
- `install_editor.bat` / `install_editor.ps1` - setup
- `uninstall_editor.bat` / `uninstall_editor.ps1` - removal (levels and blueprints stay)
- `start_level_editor.bat` - start (created by the setup)
- `scenario\` - scenario builder (start menu key 3, see `scenario\README.md`)
- `levels\` - saved levels; `blueprints\` - saved layouts

## Copy and paste
**Ctrl+C** copies, **Ctrl+V** pastes, **Ctrl+X** cuts (copies and deletes), **Ctrl+Z** undoes, **Ctrl+Y** redoes, **Ctrl+B** blows up (wrecks stay), **Del** deletes. **Ctrl+S** saves the level (under the current name, otherwise as a new `level_001` ...). **Ctrl+D** creates the builders of all factions. The buttons **DL**, **DR** and **DC** at the far right delete everything along a dragged line (a corridor 80 Elmo wide), in a dragged rectangle or in a dragged circle: units, wrecks, features (key **D** = rectangle, Ctrl+Z brings it back). The experimental buttons **XL**, **XR** and **XC** below them (one slot free) start area attacks with the selected bombers, artillery, rocket launchers or nukes along a line, onto a rectangle or onto a circle (details in the BluePrinter readme). **M** (or the Maze sub-tab of the Generate tab) cycles the maze mode (dragon teeth, walls, off); then drag a rectangle, a random maze appears in it with the entrance top left and the exit bottom right (Ctrl+Z undoes it). **Ctrl + click/rectangle** also selects enemies, **Alt + drag** on a selected unit moves the selection, the **arrow keys** move it by one grid step (up = north). You delete a feature with Del. The shortcuts only work in the Level Editor; in the chat input and in the search fields of the menu they do not apply.

Ctrl+C copies the selected units/buildings (without a selection the unit at the mouse pointer). Ctrl+V pastes them centered at the mouse pointer, with team, rotation and height. Pasting works any number of times; the clipboard lasts until you quit the editor.

## Builders
Ctrl+D creates the builders of all factions (markers ARMADA, CORTEX, LEGION, grouped by kind, on reachable spots) at the mouse pointer for the team chosen on the left.

## Editing the blueprint menu
- **Sorting:** drag a tile with the mouse and drop it elsewhere. The order is stored in `blueprints\_order.txt`.
- **Deleting:** small x at the top right of the tile, click twice. The file moves to `blueprints\_trash` (trash) and can be restored by hand.
- **Renaming:** double click on the name, type, Enter. Esc cancels.

## Saving
The blueprint menu is available right at the start of the editor. You save the whole level with Ctrl+S (blueprints only contain the units you selected).

## Units menu
Open the **Units** tab of the Place menu. Below it you choose faction (Armada, Cortex, Legion), group (buildings, air, vehicles, bots, hover, ships) and tech (T1 to T3). The units appear with their pictures. Click one, then left click on the map places it (blue outline), right click ends, [ and ] rotate. You choose the team with the buttons left of the menu. When you hover over one, name and metal cost appear below the strip. The list comes straight from the game, so it also includes Legion, the extra pack and custom units.

(The menu follows the UI size slider from the BAR settings.)

## Settings
In the button column at the far right sits the button **O**. It opens the settings: the **grid** size (1 = free, 4, 8, 16, 32, 64 Elmo), the **unit limit** (500 to 32000; it is saved in the level file as `unitlimit` and used as `maxunits` by the scenario package; the editor itself always runs with 32000), columns and rows for the blueprint view and for the units view (default 3 columns and 4 rows each). The values are stored in `LuaUI\Config\LevelEditorUI.lua` in the game folder. The blueprint view only grows up to this size; with few blueprints it stays small.

## Shared code
Blueprint view, units menu, settings and 3D preview come from `..\shared\editor_common.lua` (the same in the BluePrinter).
`install_editor.bat` packs the file into the extra game. The folder `shared` must lie next to `LevelEditor` (also on the second computer).

## Help
The menu has a **?** button. It shows the keys and short explanations as a board on the screen; a click closes it.

## Making a scenario from it
In the game itself: the button **I** in the button column at the far right next to the menu opens the scenario info: title, author, summary, briefing (Shift+Enter = new line), role of each team, AI behavior, win condition, start metal/energy and ID. Click text fields and type (Enter done, Esc cancel), the other fields change with every click. The info is written when the level is saved; there is no save button on this page (Ctrl+S saves). The scenario builder does the rest (see below).
In the start menu **key 3** (create a scenario package from a level): choose a level, the script builds without questions a scenario that others can play with the official BAR (folder and zip in `scenario\scenarios`). The info (title, briefing, roles, tech, AI, win condition, resources, grace period, ID) is stored in the level and changed in the editor with the I button. Details in `scenario\README.md`.
