# Scenario builder

`LevelEditor\scenario\scenario_builder.ps1` (PowerShell 5.1, no Python; the target computer needs only PowerShell too) builds a scenario package for the official game from a saved level. Start menu key 3 runs it; key 5 rebuilds a package ([setup and start menu](level-editor-setup.md)). Playing with several people: [Scenarios with several players](scenario-multiplayer.md), [LAN Play](lan-play.md). User view: [Scenario builder manual](../LevelEditor/scenario/README.md).

## 1. Scenario info in the editor

- **Button I** (button column, below O; a page of its own like O): edits the scenario info in the widget (`scenario` table). Rows: title, author, summary, briefing (Shift+Enter = new line), win condition (`com` = commanders, `killall` = all units, `neverend` = no end), grace period (m:ss), ID (a–z, 0–9). Text fields take the input through `OwnText`; Enter accepts, Esc discards. Human or AI, alliances and start resources are on the page T ([Teams](teams.md)); the restrictions are the [restrictions](restrictions.md) of the level.
- Changed info (`scenarioDirty`) is written by `saveLevel` as a block (`Json.encode`) instead of the block from the file; loading resets it. The page has no save button: Ctrl+S (or "Save" / "Save as new" on the settings page) writes the info. `\r` in the level file is tolerated when reading the block (editor and script).
- The block is `scenario = [==[ <json> ]==],` directly after `return {` in the level file, with the keys `title`, `author`, `summary`, `briefing`, `win`, `grace`, `sid`. The editor reads the block of the target file before overwriting and writes it back; if it is missing there it takes the block of the level loaded last (`keptScenario`); autosaves `_last` and `_beforeplay` keep it unchanged. **Save as new** takes over the info of the level loaded last but not its title and ID: they are made from the new name (`level_002` → title "Level 002", ID `level002`), so the package of the new level is never built into the folder of the other one.

## 2. The script

- Called by `choose_map.ps1` with `-Level name -Auto -AskName` (key 3; key 5: `-Level <level> -Auto` without questions) or by hand without parameters (asks everything: level, title, author, summary, briefing, win condition, grace period, ID). `-Auto` asks nothing; `-LevelDir <folder>` takes the levels from another folder (the test levels); `-BundleDir <folder>` see [Scenarios with several players](scenario-multiplayer.md).
- Key 3 flow: a list "Scenario info stored in the level", then the title with `AskLine` (Enter keeps it; a changed title proposes the ID `Get-Slug <title>`), then `Confirm-ScenarioId`: shows the target `scenarios\<id>`, Enter takes the name or another one is typed (written into the block as `sid`); if folder or zip exists: y = overwrite, n = another name, c = cancel.
- `-Edit` (by hand): shows the info saved in the level numbered; choose a number and change the value, every change is saved in the block at once; Enter ends, then the question whether to rebuild.
- Console input stays on the default encoding (switched to UTF-8, `Console.ReadLine` returns NUL for umlauts).
- Result: `scenarios\<id>\` and `scenarios\<id>.zip`.

## 3. `scenario.txt`

A start script for the official game:

- Teams numbered 0..n-1 (player = 0; the engine needs gapless numbers), teams of one [alliance](teams.md) in the same `allyteam`, `startpostype=0`.
- Game options: `deathmode` (the win condition; `neverend` for every game mode), `maxunits` (the `unitlimit` stored in the level, set in the editor settings, default 32000), `startmetal` and `startenergy` (of the first team; every team also has `StartMetal` / `StartEnergy` in its `[team]` section, [Teams](teams.md)), the `requiredmodoptions` of the level (Legion, extra pack, release candidates, `forceallunits` when the level holds Scavenger or Raptor units), and `scenariooptions` = `base64url(zlib(json))` with `scenarioid`, `title`, `briefing`, `disablefactionpicker`, `unitloadout`, `featureloadout`. The game sets these up at the start and places no start commanders. The level files of the editor have exactly this format.
- The placeholders `__GAMETYPE__` and `__PLAYERNAME__` are filled by the starter.
- Gaia units are in the level with `gaia = true` (`team` is the Gaia number of the editor); in the scenario they get the number after the last real team. Gaia is an enemy to everyone and has no AI.
- Wrecks: features `<unit>_dead` get the field `resurrectas` (the game calls `Spring.SetFeatureResurrect` with it). The level file carries `resurrectas = 'unit'` at resurrectable wrecks (the editor writes it from `Spring.GetFeatureResurrect`; the builder otherwise derives it from the name); the editor gadget (`placeFeature`) sets the resurrection when creating a wreck too. Heaps cannot be resurrected.
- Resurrected units get Hold Position: in the editor the gadget (`gadget:UnitCreated` with `builderID`), in a scenario the briefing widget for the player's own units (not possible for AI teams in the official game).
- Silos start empty (the stockpile is not part of the level). Builders created with Ctrl+D are not saved in the level.
- The faction picker is switched off (`disablefactionpicker`); the side of a team follows its units.
- Unit lines carry the flag `indestructible` (read by `UNIT_RX`; without it flagged units would be skipped) and, for fixed buildings, the game option `fixedunits` ([Tower Defense](tower-defense.md), Indestructible pieces).

## 4. Grace period

Field `grace` (minutes, also fractional; input `m:ss`, `2,5` or `3`). With `grace > 0` the script writes per alliance `StartRectLeft/Top/Right/Bottom`, the game option `norushtimer = grace` (dot as decimal separator) and `startpostype=2`.

- The start area of an alliance is the frame around its units plus 300 Elmo margin (with 30 or more units without the outer 3 % of each edge), divided by the map size. Overlapping frames or ones closer than 500 Elmo are separated; the one of the alliance with the smaller number (player) stays whole. Double values are used because `[math]::Max` rounds with integers.
- The game (`game_startbox_config.lua`) widens the start boxes to the whole map for every other start mode, hence `startpostype=2`; then `game_no_rush_mode.lua` (commands and damage outside the start area) and the start position choice take effect. Until the time ends no side can leave its area and each is safe from damage there.
- `scenario_briefing.lua` does the start position choice itself (`Spring.RequestStartPosition` in the middle of the own start area, then `SendLuaRulesMsg("ready_to_start_game")`; only if `grace > 0` is in `scenariooptions`).
- The editor writes `mapsize = { x, z }` (Elmo) into the level file; without it the script stops with a message (save the level again).
- Tower Defense switches the grace period off (`$grace = 0` after saving the info): with `norushtimer` the no-rush gadget blocks orders to targets outside the start area, so wave units stood still at the spawn point. The saved value stays in the level.

## 5. Game modes in the scenario

A level with a game mode on gets that mode's game option and gadget; the modes exclude each other, a level file with two on is refused by the script (`throw`). The computer opponents get NullAI and the win condition is "no end" (the gadget decides): the BARb of a scenario would take the wave units over (Tower Defense); a destroyed start commander must not eliminate the player (`deathmode` is `neverend`).

| Mode | Game option | Gadget | Page |
|---|---|---|---|
| Tower Defense | `tdconfig` = base64url of the payload `enemyTeam;0;spawnX;spawnZ;goalX;goalZ;leaks;path;waves;restrict;fog` (team numbers as renumbered: the player is 0, the enemy the first AI team) | `td_waves.lua` | [Tower Defense](tower-defense.md) |
| Capture the Flag | `ctfconfig` | `ctf_game.lua` | [Capture the Flag](capture-the-flag.md) |
| Reclaim the Fame | `rtfconfig` (without crystals the scenario is built without the mode, with a note) | `rtf_game.lua` | [Reclaim the Fame](reclaim-the-fame.md) |
| Restrictions | `restrictions` | `unit_restrictions.lua` | [Restrictions](restrictions.md) |

Tower Defense: a level with only one team gets an extra enemy team without units (the waves belong to it). The start commander of the player is removed when the waves start, so the level needs builders. In the scenario the gadget (`not EDITOR_MODE`) reads `tdconfig` in `GamePreload` and starts the waves at frame 30.

## 6. The extra game "Level Editor Scenarios <version>"

The official game cannot load the gadgets of the modes, so `start_scenario.ps1` starts every scenario with a small extra game next to the official one (no official file is changed):

- File `data\games\LevelEditorScenarios_<version>.sdz` (`Write-ScenarioGame` in `shared\bar_common.ps1`): `modinfo.lua` with `depend = { "<installed game>" }`; the gadgets `td_waves.lua`, `ctf_game.lua`, `rtf_game.lua`, `unit_restrictions.lua`, `unit_indestructible.lua`; the lootbox stub as `pve_supply_drops.lua`; `luaui/Include/bar_rules.lua` and `luaui/Include/led_gadgets.lua`; the game widgets `scenario_briefing.lua` and `shared_start.lua`. The list is `$ScenarioGameFiles` in `shared\bar_common.ps1` (the setup, the starter, the builder, the bundle of the lobby and the LAN test take it from there).
- The version = the first 8 hex digits of a SHA-256 over the BAR version and the texts of these files; the zip entries have the fixed time 2000-01-01; an existing file of that version is not built again. Different files give a different version and a file of its own, so a version received from a host or built by an older package never replaces another one; other versions stay until key 8 of the start menu removes them.
- The gadgets switch on only by the game options of a scenario. The name of the editor's own version is in `data\games\LevelEditorScenarios.txt` (file name, game name; read by LAN Play).
- `gametype=Level Editor Scenarios <version>`. From the editor's menu the files are the current ones of the editor (the setup built the same game already), from an unpacked package the package's. The engine's data folder: every start of `spring.exe` (single player, host) gets `--write-dir <BAR>\data`, otherwise the engine used `data\engine\<version>\` and did not see maps and games ("Dependent archive ... not found").
- **Briefing:** the mission display of the game only finds scenarios in the game archive ("No additional briefing data found"), so the extra game carries the game widget `scenario_briefing.lua` (no "Allow user widgets" needed). It reads title, author, summary and briefing from `scenariooptions` (marker `scenariomaker`), shows them at the start in a window of its own (layer 100000) and replaces `WG.missioninfo` so the "Mission" button opens it as well; `/briefing` opens it again. Copies of older starters in `data\LuaUI\Widgets` are removed by the starter; `shared_start.lua` there only when LAN Play is not installed.

## 7. Which scripts run

The package is self-contained, so it can be passed on to people without the editor: `Start Scenario.bat`, `Host Game.bat`, `Join Game.bat`, `start_scenario.ps1`, `player_mapping.ps1`, `lobby.ps1` (template from `template\`), `bar_common.ps1` (from `..\shared`), `scenario.txt`, `scenario_briefing.lua`, `shared_start.lua`, `README.txt` (briefing and instructions), the gadgets the level needs and `bar_rules.lua`.

When the scenario is started from the editor's menu (key 4) nothing but `scenario.txt` is taken from the package (which gadgets it needs = which `*.lua` files its package holds, and `bar_path.txt`): `start_scenario.ps1 -BarPath <BAR folder> -ScenarioDir <package folder> -EditorDir <LevelEditor folder>` runs from `scenario\template` (so starter, lobby and briefing are the current ones) and builds the extra game from the current gadgets in `scripts\` and `shared\bar_rules.lua`. A scenario built long ago never runs outdated code. Started from the unpacked package both parameters are empty and everything comes from the package folder.

`start_scenario.ps1`: finds BAR (remembers the path in `bar_path.txt`), the newest engine and the installed game version (like `install_editor.ps1`); if the map is missing it asks (y/n) and only with "y" downloads it with `pr-downloader`; writes the start script and starts `spring.exe`. `-ScriptOnly` only writes the script. Options for several players: [Scenarios with several players](scenario-multiplayer.md).

## 8. Limitations

Without internet the map must already be installed at the recipient. The Tower Defense scenario was not played to the end (won / lost) in a scenario game.
