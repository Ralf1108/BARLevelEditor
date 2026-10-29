# Level Editor: setup, start menu and game start

How the editor gets onto the computer, how it starts and what the start menu does. The editor itself: [Level Editor](level-editor.md). User view: [Level Editor manual](../LevelEditor/README.md) (Setup, Starting).

## 1. Extra game and basic rules

- The official game stays unchanged. The editor is an **extra game** `data\games\LevelEditorMod.sdz` (name "Level Editor", short "LevelEd", game "LevelEditorMod", depends on the installed BAR), plus a start file and folders for levels and blueprints.
- In editor mode (game option `leveleditor=1`) no /cheat and no /globallos are needed (the editor switches on the cheat mode and the god mode itself). Everything is free and finished instantly. Legion, the extra pack and release candidates are switched on. The unit limit is raised (`maxunits=32000`).
- After a change to the widget, gadget or shared code, or a BAR update, the extra game has to be built again. `start_level_editor.bat` does it by itself (section 3).
- Source code and texts contain no reference to persons or private matters. Player name in the start script: "Player".

## 2. Setup (`install_editor.bat` → `scripts\install_editor.ps1`)

All scripts live in `scripts\` (`$root` = the main folder is their parent, the repository folder their grandparent). Requirements: BAR installed and the launcher started once; the folder `shared` must lie next to `LevelEditor`.

- **Finds BAR** on all fixed drives (`C:\Games`, `D:\Games`, Program Files, `%LOCALAPPDATA%\Programs`), the engine and the game version (`Find-Bar`, `Get-Engine`, `Get-GameVersion` in `shared\bar_common.ps1`).
- **Builds `LevelEditorMod.sdz`** from one list of files, `scripts\editor_manifest.ps1`: `$EditorGameFiles` (folder key, file, path in the sdz), the gadgets of `$ScenarioGameFiles` (`shared\bar_common.ps1`, the files of the extra game of the scenarios), `$StampExtraFiles`; `Get-EditorGameEntries`, `Get-EditorSourceFiles` and `Get-EditorStamp` read them. A missing file stops the setup with its path. Contents: `modinfo.lua`, the gadgets (`unit_level_editor`, `td_waves`, `ctf_game`, `rtf_game`, `unit_restrictions`, `unit_indestructible`, the lootbox stub), the widget (with `enabled = true`) and in `luaui/Include`: `editor_common.lua`, `bar_rules.lua`, `led_gadgets.lua`, `led_td.lua`, `led_ctf.lua`, `led_rtf.lua`, `led_arena.lua`, `led_teams.lua`, `led_restrictions.lua`, `led_help_texts.lua`.
- The widget is switched on in the extra game by replacing only the first `enabled = false,` of `lvl_level_editor.lua` (the line in `GetInfo`); the same text also appears in the code as data, which stays untouched.
- **The stamp** `data\games\LevelEditorMod.stamp`: SHA-256 over the game version and every source file of the setup (the packed files, the setup scripts and the LAN Play files), written after building.
- Replaces the extra game of a previous setup; creates the junctions `data\LevelEditor` → `levels` and `data\LevelEditorBlueprints` → `blueprints`; creates `blueprints\_trash`; writes `start_level_editor.bat` and the desktop shortcut "BAR Level Editor" (no other shortcut). It checks for and downloads no map: maps are chosen in the start menu.
- **The extra game of the scenarios** "Level Editor Scenarios <version>" is built by the same setup (`Write-ScenarioGame`, [Scenario builder](scenario-builder.md)); the setup also makes the junction `data\LevelEditorScenarios` → `scenario\scenarios`, runs `lan_lobby\install_lan_play.ps1` ([LAN Play](lan-play.md)) and (full run only) saves the official map checksums. The files of the older fixed names (`LevelEditorScenarios.sdz`, `TowerDefenseScenario.sdz`) are removed.
- **`-Quick`** (called by `ensure_installed.ps1`): builds only the extra games and the stamp and brings LAN Play up to date; it does not rewrite the start file, because the batch file is running.
- `editor_script_installed.txt` (start script for the engine, written by `choose_map.ps1`): player "Player", game "Level Editor 1", game options including `maxunits=32000` and `forceallunits=1` when key 7 is on or the level needs it.

### Removing (`uninstall_editor.bat` → `uninstall_editor.ps1`)

Finds BAR like the setup, refuses while the game runs, lists what is there, asks (`-Yes` skips) and removes:

- `data\games\LevelEditorMod.sdz` and its stamp, the editor's own `LevelEditorScenarios_<version>.sdz` and the pointer file;
- the junctions `data\LevelEditor`, `data\LevelEditorBlueprints`, `data\LevelEditorScenarios` (only unhooked with `rmdir`: the content of `levels` and `blueprints` stays; a real folder at one of the places is skipped);
- the LAN Play widget `LuaMenu\Widgets\lan_lobby.lua`, the game widgets `shared_start.lua` and `scenario_briefing.lua`; at the end `install_lan_play.ps1 -Uninstall` switches `loadLocalWidgets` of the lobby off again;
- the desktop shortcut "BAR Level Editor", `start_level_editor.bat`, `editor_script_installed.txt`, and `Last Map.txt`, `Online Maps Cache.json`, `Scav Units.txt` in `%LOCALAPPDATA%\BAR-Level-Editor`.

`-WithSettings` additionally deletes `LuaUI\Config\LevelEditorRecent.lua` and `LevelEditorUI.lua`. The desktop shortcut "Beyond All Reason", the folder itself and the cache `%LOCALAPPDATA%\BAR-Scenario` (key 8 of the start menu) stay.

## 3. Start: `start_level_editor.bat`

Prints its three steps (`[1/3] Checking the installation`, `[2/3] Checking the links`, `[3/3] Loading the map list and the levels`; together about 1.5 s) and starts the start menu.

1. `ensure_installed.ps1` compares the stamp with the current files and the game version and runs `install_editor.ps1 -Quick` when they differ or the extra game is missing. While a game is running (`spring` process) the update is skipped with a note.
2. `check_links.ps1` points the two junctions to `levels` and `blueprints` again if the project folder was moved.
3. `choose_map.ps1` shows the menu.

The BluePrinter is not updated by the editor: it has its own `start_blueprinter.bat` ([BluePrinter](blueprinter.md)).

## 4. Start menu (`scripts\choose_map.ps1`)

Always a console menu. Arrow up/down (Home/End) choose the item, Enter runs it, a digit key jumps to it, Esc cancels; grayed-out items are skipped, the first possible one is preselected (normally 0).

| Key | Action |
|---|---|
| 0 | continue the last saved map (state `_last`, saved every 2 minutes and when leaving) |
| 1 | new level: map selection |
| 2 | load a level |
| 3 | build a scenario package from a level |
| 4 | start a built scenario |
| 5 | upgrade a built scenario package |
| 6 | play a level at once |
| 7 | switch Scavenger and Raptor units on / off (after an empty line) |
| 8 | clean up |

- **Map preview:** the lists of keys 1, 2 and 3 show the picture of the highlighted map on the right (window wide enough: the list keeps 55 characters, the picture gets at most 64 columns). The pictures are not downloaded: the lobby package of the game (`byar-chobby`) contains `LuaMenu/configs/gameConfig/byar/minimapThumbnail/<map name with _>.png` for about 770 maps. `map_preview.ps1` reads the newest `data\packages\*.sdp` that lists them (gzip; per file name length, lower case name, 16 bytes md5, crc, size), takes the file `data\pool\<md5 byte 1>\<rest>.gz`, unpacks it into memory and draws it with the half block character (two pixels per character, 24-bit colour with the console mode for escape sequences; 16 colours as fallback). Nothing is stored on disk: the index (name to md5) is built at the start (about 0.2 s), a picture is unpacked when its map is highlighted and kept in memory. Under it a line shows size, players and terrain. Without package, thumbnail or enough width nothing is shown. Test: `choose_map.ps1 -Data <BAR\data> -TestPreview "Map name"`.
- **Map filters (key 1):** a row above the search line with `Size`, `Players` and `Terrain` (all `all` at the start). `Tab` / `Shift+Tab` choose a filter, `Left` / `Right` change its value, typing still searches; the counter counts the maps that pass all filters and the search.
  - Size `XS` to `XXXL` (the classes of the lobby: area = `Width` x `Height` against the quantiles 0.08, 0.24, 0.40, 0.60, 0.78, 0.92 of all maps).
  - Players `2`, `3-4`, `5-6`, `7-8`, `9-12`, `13-15`, `16`, `17+`.
  - Terrain `Flat`, `Hills`, `Water` and the specials `Metal`, `Lava`, `Air`, `Asymmetrical` (a map has the special of its entry plus Flat, Hills and Water as flags).
  The data are in `configs/gameConfig/byar/mapDetails.lua` of the same lobby package (`Get-MapDetail`, parsed once, about 50 ms); a map that is not in the file is hidden as soon as a filter is set. The picture's line shows e.g. `12 x 12 (S), 4 players, Air, Hills`. The levels lists have no filters.
- **Key 1:** the list contains all BAR maps from the internet (cached in `Online Maps Cache.json`; with a cache the menu starts at once from it and a hidden background process fetches the new list for the next start, writing the cache through a temporary file; only without a cache the list is fetched at the start, 10 s at most). Missing maps are only downloaded after the selection; offline only installed maps appear. The list shows the name with its version (the title counts the maps and the installed ones).
- **Key 2:** load a level (list from `levels`, with search). Every line shows name, map, number of units and features ("195 units, 94 features"; `Read-Level` counts the entries before and after `featureloadout` separately), date and a note if the map is missing. The same format is shown for the last state in the main menu. A single level is treated as a list (`@(Get-Levels)`). The editor starts on the saved map and sets up the units automatically (`levels\_autoload.txt`).
- **Key 3:** level selection as with key 2, then `scenario\scenario_builder.ps1 -Level name -Auto -AskName` ([Scenario builder](scenario-builder.md)); back to the menu afterwards.
- **Key 4:** only if `scenario\scenarios` holds folders with a `scenario.txt`. A list of the scenarios with ID, title (first line of the `README.txt`), map, a note "Tower Defense" if the folder has `td_waves.lua`, and date (`Get-Scenarios`, `-TestScenarios`), search while typing. Enter opens a second list (Single player / Host a game / Join a game / Split screen; Esc goes back) and runs the **current** `scenario\template\start_scenario.ps1 -BarPath <BAR folder> -ScenarioDir <scenario folder> -EditorDir <LevelEditor folder>` (not the copy in the package; [Scenario builder](scenario-builder.md), "Which scripts run"). Host and Join add `-HostGame -Lobby` / `-Join -Lobby`; the split screen starts its games from the menu itself ([Scenarios with several players](scenario-multiplayer.md)). When the game ends the menu comes back; the other keys end the menu with exit code 0 to start the editor.
- **Key 5:** the same list as key 4; Enter finds the level the scenario came from (`Find-ScenarioLevel`: the level whose saved scenario info has `"sid"` = the ID, otherwise the level whose name gives that ID: lowercase letters and digits) and runs `scenario_builder.ps1 -Level <level> -Auto` (the folder and zip of that ID are replaced), then "Continue with any key". Without a matching level a message says to build it again with key 3.
- **Key 6:** play a level at once: builds a bundle without writing a package ([Scenarios with several players](scenario-multiplayer.md)).
- **Key 7:** the **Scavenger and Raptor units** of the Place menu on or off (`Scav Units.txt` in `%LOCALAPPDATA%\BAR-Level-Editor`, off at the start). Those units exist in the game only with the game option `forceallunits` (the `_scav` copies of all units are made by BAR's `unitdefs_post.lua` only when a Scavenger AI, `ruins`, `zombies` or `forceallunits` is on; the raptors load with `forceallunits`), and the option makes the game start about 10 s slower (24 s without, 34 s with). `Write-StartScript` adds `forceallunits=1` when the switch is on **or** the level to load holds such units (`Read-Level` finds `forceallunits` in the `requiredmodoptions` of the level). A level that holds such a unit carries `forceallunits = "1"` in its `requiredmodoptions` (written by `saveLevel`); the scenario builder copies it into the game options.
- **Key 8:** clean up (`Invoke-CleanMenu`, `Get-CleanItems`, `Remove-CleanItem`). A list with kind, name, size and date: own levels (`levels\*.lua` without the internal `_` files) and own built scenarios (`scenario\scenarios\<id>` with its zip), scenarios and maps from other players in the cache `%LOCALAPPDATA%\BAR-Scenario` (`Cache\<hash>`, `Cache\Maps\maps` with the `.mapinfo`), and versions of the extra game `LevelEditorScenarios_<version>.sdz` that are not the editor's own (the one in `LevelEditorScenarios.txt`). Up/Down, Page up/down move, Space marks, A marks or unmarks all of the kind under the cursor, Enter removes the marked ones (or the one under the cursor) after y, Esc goes back. Own levels and scenarios are moved into a `_trash` folder next to them (with the time in front of the name when it is taken; never deleted for good), the rest is deleted (fetched again when needed). The maps of BAR itself (`data\maps`), the game, the editor and the backups are never offered. The entry shows the size of the cache. Old things go by themselves when the menu starts (scenarios after 30 days, maps after 60 days or beyond 3 GB).
- The map list stays smooth: the filtered list is cached, only changed lines are redrawn, a backlog of key presses is discarded, resizing the window is handled.

## 5. At the start of the game

- Shortly after the start (frame 6) `widget:Update` sends `cheat 1` and `godmode 3` once, so units of every team can be selected and commanded.
- Only the commander stands there. The mobile builders of every faction are created by the user with Ctrl+D at the mouse pointer, grouped by kind, on reachable spots (check by grid and `TestMoveOrder`; no water, no cut-off mountains). `Spring.RequestPath` leads to a crash and is not used.
- The start script has ten teams (0 to 9), each in its own ally team; only teams 0 and 1 keep their start commander ([Teams](teams.md)).
- The menu is visible at the start, with the Units tab first.
