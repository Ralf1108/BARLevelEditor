# Testing

How changes are checked. The details of the test tools and what got in the way are in `LevelEditor/test-data/README.md` (tools, levels) and `LevelEditor/test-data/TESTING.md` (pitfalls; read it before a test run).

## 1. Principles

- `LevelEditor\test-data\tools\lua_check.py` compiles every Lua file with Lua 5.1 (the Python package lupa brings it as `lupa.lua51`): syntax errors and the limits of 5.1 (200 locals, 60 upvalues per function) are found without the game. It runs nothing; what the code does is checked in the real game. The mocks (Python with Lupa, not in the repository) cover widget logic but **not** Lua 5.1 engine limits: at most 200 local variables per function and at most 60 upvalues per function. After a change start the real game once and check that the widget loads (`Failed to load: ...` in `infolog.txt`).
- Tests run in **sandbox instances** of the game: own write folder, own settings with a framed window, own copy of the extra game, nothing in the user's data folder. They can run next to a running game (`-AlongsideGame`). Long tests run in the background and end the game by themselves (`quitforce`); a killed process loses the log tail. Never kill the user's own `spring.exe`.
- A game instance needs 8 to 10 GB of RAM: LAN tests run with the host plus one joiner at most.
- Before every hand-over: run both installers (`install_editor`, `install_blueprinter`), start the editor, check the log for errors.
- PowerShell files are parsed after every patch (`[System.Management.Automation.Language.Parser]::ParseFile`); patched text is checked for control characters.

## 2. Tools

| Tool | What it checks |
|---|---|
| `test-data\levels\` (`ctf_test`, `rtf_test`, `td_test`, `evo_test`, `scav_test`) | one small level per game mode on the flat map Full Metal Plate 1.7 |
| `tools\make_demo_levels.py` | writes the three demo levels into `LevelEditor\levels` |
| `tools\pve_test.ps1` (`-Ai Raptors|Scavengers`, `-Hold 1|0`, `-Layout ally|separate`, `-Enemy 1`) | one sandbox game of the extra game of the scenarios (built from this repository, with `lan_pve_hold.lua`) with a human and a Raptors or Scavengers AI; the widget `zz_pve.lua` counts the AI's units that have an order of the AI and checks that a move order of the human stays; `[zzpve]` and `[LAN]` lines; a Scavenger wave needs about 80 s at speed 20 |
| `tools\arena_test.ps1` (with `-Widget zz_*.lua`, `-Shots`) | one sandbox game of the editor (ten teams, flat map) with a test widget from `tools\` (`zz_arena.lua`, `zz_split.lua` (split attack XS), `zz_save.lua` (Save page S), `zz_scenario.lua` (Scenario info page I), `zz_cycle.lua` (Ctrl + wheel: choose the blueprint), `zz_export.lua` (the export buttons of the settings page: units.json, comparison.json), `zz_cmdbuttons.lua` (the buttons Area / Split / Focus Attack in the command menu), `zz_teams.lua`, `zz_menu.lua`, `zz_shots_all.lua`, ...; the method for each is in `TESTING.md`); `zz_bpt.lua` tests the BluePrinter plans through its test hooks |
| `tools\bp_test.ps1` | a sandbox game with the BluePrinter, next to a running game (`-Widget zz_bpfaction.lua`) |
| `tools\lan_test.ps1 -Mode ctf\|rtf\|td\|cp\|scav\|page\|boss\|pve\|preset\|rejoin\|latejoin\|mix` (`-Play`: a game to play, no test widgets) (also `-Sync`, `-Lobby`, `-NoMap`, `-AlongsideGame` = next to a game you play; it must not host on port 8453 at the same time) | LAN Play: two real lobbies, join, scenario, transfer, versions |
| `tools\console_test.ps1 -Mode ctf\|rtf\|td` | the console lobby of the scenario packages |
| `scenario_builder.ps1 -Level <name> -LevelDir <folder> -Auto -BundleDir <folder>` | builds a bundle from a test level without touching the user's levels |

## 3. What is checked how

- **Widget logic:** mocks (menus, grid, dragging, renaming, deleting, settings, stamp, preview, rotation, search, favorites, edit buttons, level list, redo and the messages sent).
- **Gadgets and engine:** headless runs of the real engine with test gadgets (placing, factories, air unit height, handover, builders, unit catalog, classification of feature and unit definitions) and sandbox games with test widgets that click through the pages and drags (Tower Defense, Capture the Flag, Reclaim the Fame, restrictions, Arena, teams, menu pairs).
- **Scripts:** the installers against a dummy game folder (`ensure_installed.ps1`: no stamp, current stamp, changed file); the start menu with real key presses in a console; the scenario builder on copies of the folders.
- **Screenshots:** how the pictures of the manuals are taken is in `docs/screenshots.md`.

## 4. Not checkable in the game

Ctrl+click and Alt-drag (the key states cannot be given there; mocks only); screenshots of the lobby only with `PrintWindow` (`lan_test.ps1 -Shots`).
