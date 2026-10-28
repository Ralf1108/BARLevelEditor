# Test data

Levels for **testing and screenshots**, not for playing. When something in a game mode changes, load one of these levels (or build a scenario from it) and check that the mode still works.

All levels are on the flat map "Full Metal Plate 1.7" (no mountains, no water): the bases are 2700 Elmo apart in the middle of the map, so units never get stuck.

| Level | Mode | Content |
| --- | --- | --- |
| `levels/ctf_test.lua` | Capture the Flag | Armada (west) and Cortex (east) with a commander and three fast units each, three neutral flags in the middle, one collection point per team, 3 flags win |
| `levels/rtf_test.lua` | Reclaim the Fame | the same bases with four construction bots each, seven crystals in the middle (4 small, 2 medium, 1 large), 2000 points win |
| `levels/td_test.lua` | Tower Defense | Armada's commander and three LLT in the east, two small waves walk from the west to the goal |

Use them in the editor by copying a file to `LevelEditor\levels`, or build a scenario without touching your own levels:

```
powershell -File scenario\scenario_builder.ps1 -Level ctf_test -LevelDir ..\test-data\levels -Auto -BundleDir <folder>
```

The LAN Play test (two instances of the game, host and joiner, real lobby) takes the `scenario.txt` of such a bundle as the scenario of the host.

## Demo levels (`tools\make_demo_levels.py`)

`python tools\make_demo_levels.py [folder]` writes the three playable demo levels `demo_td_serpentine.lua`, `demo_ctf_crossroads.lua` and `demo_rtf_crystal_fields.lua` into `LevelEditor\levels` (they are the only files of that folder that git keeps, `.gitignore`). Base map: *Full Metal Plate 1.7* (flat metal map). Positions, waves and settings are at the top of each function in the script: change them there and run it again. Checked 2026-10-27 in a sandbox game: all three load in the editor, the Tower Defense waves walk the whole corridor to the goal, the flags and crystals appear when the test is started, and the scenario builder packs all three.

## LAN Play test (`tools`)

`tools\lan_test.ps1 -Mode ctf|rtf|td|cp` (more: `-Sync same|missing|other` = the joiner has the host's extra game, none, or an own other version; `-Lobby same|other` = the joiner's lobby widget is the host's or has one more line; `-NoMap` = the joiner has an empty maps folder and no online download, the map comes from the host; `-MapList none|official|wrong` = the list of official map md5 of the joiners (none, fetched online, or with a wrong md5); `-Clients 1|2`; each joiner is another instance and about 4-9 GB of RAM) starts two instances of the game (host "PlayerA", joiner "PlayerB") with the real lobby on this computer, in two small framed windows, plays the test level as a LAN scenario (`cp` = Copilot on an official map) and quits by itself. Everything is built in a work folder (default `%TEMP%\lan_test`, own write dir per instance, junctions to the installed engine and game): the installed game is not changed, but it must not be running. The widget `zz_lantest.lua` logs `[zzlan]` lines (teams, units, scores, commander positions) into `infolog.txt` of both instances (`<work>\sbx_H\data`, `<work>\sbx_J\data`); both logs must show the same state. Results of 2026-10-27: CTF (PlayerA and PlayerB as opponents, flags taken and held, score equal on both), Reclaim the Fame (both teams earn points, equal on both), Tower Defense (both humans in one team, waves, state "won"), Copilot (both humans in team 0, one commander, orders of both arrive).

What went wrong in earlier runs and how to avoid it: [TESTING.md](TESTING.md).

## Console lobby test (`tools\console_test.ps1`)

`tools\console_test.ps1 -Mode ctf|rtf|td` does the same for the console lobby of the scenario packages (`Host Game` / `Join Game`, `start_scenario.ps1 -Lobby`): two starters in minimized console windows, each with its own BAR folder in the work folder (`%TEMP%\console_test\barH`, `barJ`), the host starts when two players are in. Results of 2026-10-27: Capture the Flag (PlayerA team 0, PlayerB team 1, 2:0 on both), Reclaim the Fame (1564 : 1638 on both), Tower Defense ("won" on both; the lobby put PlayerB in team 1, the team of the enemy AI slot, because the lobby simply gives the joiner the free team, the host could move them in the lobby).

`levels/scav_test.lua` (not a game mode): twelve Scavenger and Raptor units in the team of the human (`armpw_scav`, `armck_scav`, `raptor_land_swarmer_basic_t1_v1`, `raptor_hive`, ...). `tools\lan_test.ps1 -Mode scav` checks that they exist in a LAN game and that nothing gives them orders (the `[zzlan] census` lines at frame 60 and 900 show the same positions and no commands). Result of 2026-10-27: all twelve there, none moved.
