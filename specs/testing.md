# Testing

How changes are checked. The details of the test tools and what got in the way are in `LevelEditor/test-data/README.md` (tools, levels) and `LevelEditor/test-data/TESTING.md` (pitfalls; read it before a test run).

## 1. Principles

- There is **no Lua interpreter** on the development machine. Lua changes are checked in the real game. The mocks (Python with Lupa, not in the repository) cover widget logic but **not** Lua 5.1 engine limits: at most 200 local variables per function and at most 60 upvalues per function. After a change start the real game once and check that the widget loads (`Failed to load: ...` in `infolog.txt`).
- Tests run in **sandbox instances** of the game: own write folder, own settings with a framed window, own copy of the extra game, nothing in the user's data folder. They can run next to a running game (`-AlongsideGame`). Long tests run in the background and end the game by themselves (`quitforce`); a killed process loses the log tail. Never kill the user's own `spring.exe`.
- A game instance needs 8 to 10 GB of RAM: LAN tests run with the host plus one joiner at most.
- Before every hand-over: run both installers (`install_editor`, `install_blueprinter`), start the editor, check the log for errors.
- PowerShell files are parsed after every patch (`[System.Management.Automation.Language.Parser]::ParseFile`); patched text is checked for control characters.

## 2. Tools

| Tool | What it checks |
|---|---|
| `test-data\levels\` (`ctf_test`, `rtf_test`, `td_test`, `scav_test`) | one small level per game mode on the flat map Full Metal Plate 1.7 |
| `tools\make_demo_levels.py` | writes the three demo levels into `LevelEditor\levels` |
| `tools\arena_test.ps1` (with `-Widget zz_*.lua`, `-Shots`) | one sandbox game of the editor (ten teams, flat map) with a test widget from `tools\` (`zz_arena.lua`, `zz_teams.lua`, `zz_menu.lua`, `zz_shots_all.lua`, ...; the method for each is in `TESTING.md`); `zz_bpt.lua` tests the BluePrinter plans through its test hooks |
| `tools\lan_test.ps1 -Mode ctf\|rtf\|td\|cp\|scav` (also `-Sync`, `-Lobby`, `-NoMap`) | LAN Play: two real lobbies, join, scenario, transfer, versions |
| `tools\console_test.ps1 -Mode ctf\|rtf\|td` | the console lobby of the scenario packages |
| `scenario_builder.ps1 -Level <name> -LevelDir <folder> -Auto -BundleDir <folder>` | builds a bundle from a test level without touching the user's levels |

## 3. What is checked how

- **Widget logic:** mocks (menus, grid, dragging, renaming, deleting, settings, stamp, preview, rotation, search, favorites, edit buttons, level list, redo and the messages sent).
- **Gadgets and engine:** headless runs of the real engine with test gadgets (placing, factories, air unit height, handover, builders, unit catalog, classification of feature and unit definitions) and sandbox games with test widgets that click through the pages and drags (Tower Defense, Capture the Flag, Reclaim the Fame, restrictions, Arena, teams, menu pairs).
- **Scripts:** the installers against a dummy game folder (`ensure_installed.ps1`: no stamp, current stamp, changed file); the start menu with real key presses in a console; the scenario builder on copies of the folders.
- **Screenshots:** how the pictures of the manuals are taken is in `docs/screenshots.md`.

## 4. Not checkable in the game

Ctrl+click and Alt-drag (the key states cannot be given there; mocks only); screenshots of the OpenGL window of the lobby (they come out black).
