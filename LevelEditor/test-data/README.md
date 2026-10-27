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

## LAN Play test (`tools`)

`tools\lan_test.ps1 -Mode ctf|rtf|td|cp` starts two instances of the game (host "Ralf", joiner "Ben") with the real lobby on this computer, in two small framed windows, plays the test level as a LAN scenario (`cp` = Copilot on an official map) and quits by itself. Everything is built in a work folder (default `%TEMP%\lan_test`, own write dir per instance, junctions to the installed engine and game): the installed game is not changed, but it must not be running. The widget `zz_lantest.lua` logs `[zzlan]` lines (teams, units, scores, commander positions) into `infolog.txt` of both instances (`<work>\sbx_H\data`, `<work>\sbx_J\data`); both logs must show the same state. Results of 2026-10-27: CTF (Ralf and Ben as opponents, flags taken and held, score equal on both), Reclaim the Fame (both teams earn points, equal on both), Tower Defense (both humans in one team, waves, state "won"), Copilot (both humans in team 0, one commander, orders of both arrive).

What went wrong in earlier runs and how to avoid it: [TESTING.md](TESTING.md).
