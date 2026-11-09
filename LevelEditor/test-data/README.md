# Test data

Levels for **testing and screenshots**, not for playing. When something in a game mode changes, load one of these levels (or build a scenario from it) and check that the mode still works.

All levels are on the flat map "Full Metal Plate 1.7" (no mountains, no water): the bases are 2700 Elmo apart in the middle of the map, so units never get stuck.

| Level | Mode | Content |
| --- | --- | --- |
| `levels/ctf_test.lua` | Capture the Flag | Armada (west) and Cortex (east) with a commander and three fast units each, three neutral flags in the middle, one collection point per team, 3 flags win |
| `levels/rtf_test.lua` | Reclaim the Fame | the same bases with four construction bots each, seven crystals in the middle (4 small, 2 medium, 1 large), 2000 points win |
| `levels/td_test.lua` | Tower Defense | Armada's commander and three LLT in the east, two small waves walk from the west to the goal |
| `levels/scav_test.lua` | none | twelve Scavenger and Raptor units in the team of the human (see the end of this page) |

Use them in the editor by copying a file to `LevelEditor\levels`, or build a scenario without touching your own levels:

```
powershell -File scenario\scenario_builder.ps1 -Level ctf_test -LevelDir ..\test-data\levels -Auto -BundleDir <folder>
```

The LAN Play test (two instances of the game, host and joiner, real lobby) takes the `scenario.txt` of such a bundle as the scenario of the host.

## Demo levels (`tools\make_demo_levels.py`)

`python tools\make_demo_levels.py [folder]` writes the three playable demo levels `demo_td_serpentine.lua`, `demo_ctf_crossroads.lua` and `demo_rtf_crystal_fields.lua` into `LevelEditor\levels` (they are the only files of that folder that git keeps, `.gitignore`). Base map: *Full Metal Plate 1.7* (flat metal map). Positions, waves and settings are at the top of each function in the script: change them there and run it again. Checked 2026-10-27 in a sandbox game: all three load in the editor, the Tower Defense waves walk the whole corridor to the goal, the flags and crystals appear when the test is started, and the scenario builder packs all three.

## LAN Play test (`tools`)

`tools\lan_test.ps1 -Mode ctf|rtf|td|cp|teams|page|boss` (`boss` = the host chooses "Make Boss" and then "Disable Boss" for the joiner, the log shows `isBoss` true and false; `-AlongsideGame` = run next to a game you play, but not while that game hosts a LAN room (same port 8453); `page` = one instance with the LAN Play page opened and left alone, for pictures of the page with `-Shots`; `teams` = the host presses the room's buttons "3 teams" and "2 per team", a joiner comes in: log of the teams, game options and the middle column in `lan_status.txt`; `-Shots 20,50` = pictures of the host's window `shot_<s>.png` in the work folder, taken with PrintWindow, so the window may stay behind others; more: `-Sync same|missing|other` = the joiner has the host's extra game, none, or an own other version; `-Lobby same|other` = the joiner's lobby widget is the host's or has one more line; `-NoMap` = the joiner has an empty maps folder and no online download (`-KeepOnline`: the lobby may download), the map comes from the host; `-MapList none|official|wrong` = the list of official map md5 of the joiners (none, fetched online, or with a wrong md5); `-Clients 1|2`; each joiner is another instance and about 4-9 GB of RAM) starts two instances of the game (host "PlayerA", joiner "PlayerB") with the real lobby on this computer, in two small framed windows, plays the test level as a LAN scenario (`cp` = Copilot on an official map) and quits by itself. Everything is built in a work folder (default `%TEMP%\lan_test`, own write dir per instance, junctions to the installed engine and game): the installed game is not changed, but it must not be running. The widget `zz_lantest.lua` logs `[zzlan]` lines (teams, units, scores, commander positions) into `infolog.txt` of both instances (`<work>\sbx_H\data`, `<work>\sbx_J\data`); both logs must show the same state. Results of 2026-10-27: CTF (PlayerA and PlayerB as opponents, flags taken and held, score equal on both), Reclaim the Fame (both teams earn points, equal on both), Tower Defense (both humans in one team, waves, state "won"), Copilot (both humans in team 0, one commander, orders of both arrive).

What went wrong in earlier runs and how to avoid it: [TESTING.md](TESTING.md).

## Mock tests (`tools\mock_test.py`)

`python tools\mock_test.py [name]` runs the mock tests `tools\mock_*.lua` with Lua 5.1 (Python package lupa, like `lua_check.py`) without the game: each fakes the part of the Spring API that a shared module needs and checks what it does. `mock_area_attack.lua` drags the attacks of `shared\area_attack.lua` on a flat fake map: XS spreads the tanks over the enemies and never targets own, allied or Gaia units, a turret only takes targets in its range, XF takes the dangerous targets first, plans again when a target died, leaves a unit alone that the player stopped and ends when the enemies are dead; XL, XR and XC give every unit its own ground target in the shape, bombers form up first and anti-air units stay out. `mock_editor_common.lua` loads `shared\editor_common.lua` with dummies for the game and checks the rows and rectangles dragged with Shift / Shift+Alt (`dragStamp`, `unitFootprint`: the key states cannot be given in a test game) and the undo history of the points of a page (`newPointHistory`).

## Shared parts of the test tools (`tools\test_common.ps1`)

`arena_test.ps1`, `bp_test.ps1`, `pve_test.ps1`, `lan_test.ps1` and `console_test.ps1` dot-source `test_common.ps1`: `New-SandboxData` (a new sandbox data folder with junctions to the game files of the installation and its archive cache; `-NoMaps` = an empty maps folder), `Write-SandboxSettings` (window size and position, other settings lines), `Start-SandboxProcess` / `Push-SandboxWindow` (the game window stays behind the other windows), `Invoke-SandboxGame` (start, wait until the game ends itself, close it after the time limit, print the matching log lines), `Resolve-TestData` (the data folder of the installation: `-Data` or `Find-Bar`) and `Get-SandboxLobby` (the name of the installed lobby package for `--menu`). `arena_test.ps1` builds the extra game with `Write-EditorGame` of `editor_manifest.ps1`, as the setup does.

## Arena test (`tools`)

`tools\arena_test.ps1` starts one sandbox game of the Level Editor (built from the repository files, ten teams like the editor game, flat map) with `zz_arena.lua`, which plays through the Arena page (Generate, moving the setup, undo and redo, Start, Stop, Clear) and logs `[zzar]` lines; the game ends itself. Details and what to look at: [TESTING.md](TESTING.md).

## Teams and alliances test (`tools`, 2026-10-28)

`tools\arena_test.ps1 -Widget zz_teams.lua` starts the same sandbox game (ten teams) with a widget that plays through the page T and the alliances (right click menu, Alliance cell, Human / AI, AI list, number field, save and load, `Spring.AreTeamsAllied`) and takes the picture of the README. `-Widget zz_modes.lua` loads `td_test`, `ctf_test` and `rtf_test` from `levels` (the tool copies them into the sandbox), puts the teams into alliances and starts each game mode. Both log `[zzar]` lines with OK / WRONG and end themselves. `-AlongsideGame` lets the test run next to a running game (it only closes the processes it started). Details: [TESTING.md](TESTING.md).

## Evolution test (`tools`, 2026-11-07)

`tools\lan_test.ps1 -Mode evo` plays Evolution over LAN Play on an official map (`-Map`, default Comet Catcher Remake 1.8): the host switches it on with the button of the room (`evolution=1` in `lanlobby_cfg.txt`), PlayerA, PlayerB and a BARb computer in ally team 2 play; `zz_lantest.lua` logs stages, points, kills and deaths of every team every 10 s and sends the units of the two humans to random places in the middle; the game ends at frame 9000. `tools\arena_test.ps1 -Widget zz_dpsdump.lua` writes one `[zzdps]` line per armed ground unit (faction, name, tech level, damage per second, health, metal, speed, range, name, move class) and ends: the numbers behind the ladders of `evo_game.lua`.

## Split attack test (`tools`)

`tools\arena_test.ps1 -Widget zz_split.lua` starts the same sandbox game; the Arena generates 30 units of team 0 and 10 of team 1 (no fight), team 0 is selected and attacks team 1 with the focus attack XF (`Shared.newAreaAttack`; `MODE` at the top of the file: `"focus"` or `"split"` for XS). `zz_split_shot.lua` takes the pictures of the two attacks (`MODE` too). `zz_split_ally.lua` checks that XF and XS never take own or allied units as targets (teams 0 and 2 in one group, a circle over all three armies: only team 1 is attacked; the old code took the allied team too). `zz_area_shot.lua` takes the picture of the area attack XR (16 artillery tanks and rocket launchers, a rectangle in front of them). It logs `[zzsp]` lines (enemies left, health, idle units, queue of one unit) and ends the game itself 90 frames after "Split attack finished". Checked: visible enemies (`Spring.GetUnitsInCylinder`), queues of attack orders, new plan when units are idle, end message. The units of team 1 shoot back, so a fair fight can be lost; 30 against 10 is won.

`tools\arena_test.ps1 -Widget zz_export.lua` starts the same sandbox game with a widget that opens the settings page (O), presses Export Units Info and Export Comparison and checks the two files (the name of the first one carries the game version, the file has it too) in `LevelEditor\Other` (valid JSON, about 1600 units, values and weapons of `armllt`, faction of Scavenger and raptor units, comparison ids; a corrected id survives the next export). Logs `[zzar]` lines.

`tools\arena_test.ps1 -Widget zz_save.lua` starts the same sandbox game with a widget that works the Save page (button S): the order of the button column, the suggested name, a typed name (characters that are not allowed are dropped), a taken name is refused, twelve more levels so that the list scrolls, the mouse wheel, the sort buttons A-Z / Recent, Save on a row (no question), Load (second click) and that the settings page O no longer shows the list. It logs `[zzar] OK` / `[zzar] FAIL` lines and takes screenshots (`<Work>\data\screenshots`). Run it in the background like every test.

`tools\pve_test.ps1 [-Ai Raptors|Scavengers] [-Hold 1|0] [-Layout ally|separate] [-Enemy 1]` starts a sandbox game of the extra game of the scenarios (with the gadget `lan_pve_hold.lua`) with a human and a Raptors or Scavengers AI and the widget `zz_pve.lua`: it speeds the game up, counts the units of the AI that have an order of the AI (with `-Hold 1` there must be none) and gives some units a move order as the human (it must stay). With `-Hold 0` (control) the AI's units have orders. Use `-Enemy 1` so the waves have a target; a game with the AI in the human's ally team needs it for the mobile Scavenger units.

`tools\pve_test.ps1 -Brood -Widget zz_brood.lua` (the Raptor Brood Chamber): the game option `tweakdefs9` = `lan_lobby\raptor_brood_defs.lua` (as the LAN lobby sets it); the widget gives a healer to the Raptors team (`/give`), orders it as the human to build a `raptor_brood_chamber`, orders the chamber to grow two swarmers and a brawler and sends them away. Expected `[zzbrood]` lines: `raptor_brood_chamber defined: OK factory true`, `the healer can build the chamber: OK`, `name in the game: Raptor Brood Chamber OK`, `the healer started the chamber: OK`, `the chamber is finished: OK`, `orders in the chamber: 3 of 3 OK` and `RESULT raptors that walked out of the chamber: 3 of 3 OK`.

`tools\pve_test.ps1 -Evo -EvoStage 4 -Widget zz_evoshot.lua -Map "Comet Catcher Remake 1.8"`: an Evolution game without the lobby (the human and a NullAI, window 1600 x 900); the widget points the camera at the own unit and takes a picture of the panels at frame 900 (`<Work>\data\screenshots`). `tools\pve_test.ps1 -Evo -EvoTest [-NoAim] [-Mult n] -Widget zz_aim.lua` (game options `lanevoaim=0`, `lanevomult=n`; the widget creates an enemy unit next to the own one and logs the fire state and the health of the enemy: without auto-aim fire state 0 and the enemy stays whole; `zz_aitake.lua`: the computer takes radars). `tools\pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_gates.lua` (game option `lanevodebug=1`: the widget presses the debug buttons by game message, chooses Gates of Hell and logs the rings: how close to the enemy, how far from the own unit; the enemy is destroyed after about 2 minutes). `tools\pve_test.ps1 -Evo -EvoTest -Widget zz_cloak.lua` (one instance; game option `lanevotest=1`: the message `evo|test|1` gives the player all abilities, `evo|test|3` creates an enemy unit next to the player's unit, `evo|test|2` logs `[Evolution] test: ... sees los ...`): the widget uses Cloak at frame 120 and logs what the enemy unit sees before and after (`[zzcloak]`, `[Evolution] test:`). `$env:BAR_GAME_VERSION = 'Beyond All Reason test-31836-b250a16'` forces the game version when the lobby has announced a newer one that is not downloaded yet (`Get-GameVersion`). `lan_test.ps1 -Mode evo -Solo` did not start the game in the room (the host never pressed Start; open).

`tools\bp_test.ps1 -Widget zz_bpfaction.lua [-Side Cortex]` starts a sandbox game of the official BAR (own write folder) with the BluePrinter of this repository, in which the player is Cortex; the widget queues a blueprint of Armada buildings with the faction switch F on and off and checks the names of the plans. It runs next to a game you are playing and only ever stops its own process.

`tools\arena_test.ps1 -Widget zz_cmdbuttons.lua` selects the commander, looks for the three buttons Area / Split / Focus Attack in the command menu (`Spring.GetActiveCmdDescs`), presses each (`Spring.SetActiveCommand`) and checks the mode of the area attack; the screenshot shows the menu. It logs `[zzar] OK` / `[zzar] FAIL` lines.

`tools\arena_test.ps1 -Widget zz_scenario.lua` works the Scenario info page (button I): types a title (Enter accepts), cycles the win condition, types a grace period, switches to the page T and back, and checks the values through `DebugScenario()`. It logs `[zzar] OK` / `[zzar] FAIL` lines. Run it in the background like every test.

## Other test widgets (`tools`)

| Widget | Started with | What it checks |
| --- | --- | --- |
| `zz_arena_fight.lua` | `arena_test.ps1 -Widget` | two armies of the Arena after Start: the targets of their weapons, the units left, the queue of one unit |
| `zz_arena_shots.lua` | `arena_test.ps1 -Shots` | the two pictures of the Arena (three armies) |
| `zz_copy.lua` | `arena_test.ps1 -Widget` | copy and paste (Ctrl+C / Ctrl+V through the KeyPress of the editor, the pointer moved with `Spring.WarpMouse`), a second paste on the same spot (W on: replaced, not doubled), save, clear and load of a level (`led_place.lua`, `led_level.lua`) |
| `zz_features.lua` | `arena_test.ps1 -Widget` | moving a feature (`led\|movefeatures`, what Alt + drag sends), undo and redo |
| `zz_keep.lua` | `arena_test.ps1 -Widget` | changes of the pages made while the Arena runs stay after Stop |
| `zz_cycle.lua` | `arena_test.ps1 -Widget` | Ctrl + mouse wheel chooses the next / previous blueprint (`grid:cycle`), also with a search filter |
| `zz_menu.lua` | `arena_test.ps1 -Widget` | all side buttons switched pairwise (exactly the chosen page is active) |
| `zz_mem.lua`, `zz_mem_big.lua`, `zz_mem_calls.lua` | `arena_test.ps1 -Widget` | Lua memory allocated per second by the editor (`_big`: with the demo level of 2460 units), and per call-in |
| `zz_shots_all.lua` | `arena_test.ps1 -Widget` (map Full Metal Plate 1.7) | the pictures of `docs\screenshots.md`, one scene after the other |
| `zz_bpt.lua`, `zz_bpo.lua`, `zz_bpg.lua` | `bp_test.ps1 -Widget` | BluePrinter plans: select, order, rotate, remove, undo; plans placed on plans and buildings; the ghosts after undo ([TESTING.md](TESTING.md)) |

## Console lobby test (`tools\console_test.ps1`)

`tools\console_test.ps1 -Mode ctf|rtf|td` does the same for the console lobby of the scenario packages (`Host Game` / `Join Game`, `start_scenario.ps1 -Lobby`): two starters in minimized console windows, each with its own BAR folder in the work folder (`%TEMP%\console_test\barH`, `barJ`), the host starts when two players are in. Results of 2026-10-27: Capture the Flag (PlayerA team 0, PlayerB team 1, 2:0 on both), Reclaim the Fame (1564 : 1638 on both), Tower Defense ("won" on both; the lobby put PlayerB in team 1, the team of the enemy AI slot, because the lobby simply gives the joiner the free team, the host could move them in the lobby).

`levels/scav_test.lua` (not a game mode): twelve Scavenger and Raptor units in the team of the human (`armpw_scav`, `armck_scav`, `raptor_land_swarmer_basic_t1_v1`, `raptor_hive`, ...). `tools\lan_test.ps1 -Mode scav` checks that they exist in a LAN game and that nothing gives them orders (the `[zzlan] census` lines at frame 60 and 900 show the same positions and no commands). Result of 2026-10-27: all twelve there, none moved.
