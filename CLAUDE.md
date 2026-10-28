# Working on this repository (notes for Claude Code)

A Level Editor and the BluePrinter for Beyond All Reason (BAR): Lua widgets and gadgets that run inside the game engine, PowerShell scripts for setup,
start menu, scenario builder and lobby. Start with `README.md`; the specifications (`LevelEditor/SPECIFICATION.md`, `BluePrinter/SPECIFICATION.md`,
`shared/SPECIFICATION.md`) describe the current state and are kept up to date with every change.

## Rules
- Everything visible and written is English: texts in the game, console menus, comments, documents, file names. No umlauts in texts drawn in the game.
- No names or private matters of persons in code, texts or file names (example players are PlayerA, PlayerB, PlayerC).
- No backward compatibility for level files: only the known fields are read (`knownFields`).
- Shared code belongs in `shared/` (`editor_common.lua` for both widgets, `bar_rules.lua` for widgets and gadgets, `bar_common.ps1` for the scripts),
  what the gadgets share in `LevelEditor/scripts/led_gadgets.lua`. Which file goes where is listed once: `LevelEditor/scripts/editor_manifest.ps1` and
  `$ScenarioGameFiles` in `shared/bar_common.ps1`; a new file is added there, not in the scripts that use the lists.
- Lua 5.1 allows at most 200 local variables per function: `lvl_level_editor.lua` is close to it at top level. Count the `^local` lines before adding
  one; put new values into an existing table or a page module (`led_td.lua`, `led_ctf.lua`, `led_rtf.lua`, `led_restrictions.lua`).
- LAN Play has a version number with date and time (`LAN_VERSION` at the top of `lan_lobby.lua`): raise the number and set the time with every change of `lan_lobby.lua` or `shared_start.lua` once the first release is out (before that it stays 1, only the time is set); the joiner warns when host and joiner differ and says who is newer.
- After a change of the widget, gadgets or shared code: `start_level_editor.bat` rebuilds the extra games by itself (stamp); the BluePrinter needs
  `BluePrinter\install_blueprinter.bat` (or its start scripts).

## Patching files on Windows
- Do not write PowerShell or Lua text with backslashes through shell heredocs or Python string literals: `\b`, `\t`, `\n` and `\\` get turned into control
  characters or lose a backslash (`shared\bar_common.ps1` became `shared<BS>ar_common.ps1`). Write the patch script as a file (the file write tool),
  use raw strings or `chr(92)`, and replace with an `assert` that the old text occurs exactly once.
- After every patch: look for control characters (`[c for c in set(text) if ord(c) < 32 and c not in '\n\r\t']`) and parse the PowerShell files
  (`[System.Management.Automation.Language.Parser]::ParseFile(...)`). There is no Lua interpreter on the machine: Lua changes are checked in the game.
- The git warning "LF will be replaced by CRLF" is harmless here.

## Tests
- Tests run in the game, in sandbox instances (own write folder, framed window, nothing in the user's data folder): `LevelEditor/test-data/README.md`
  and `LevelEditor/test-data/TESTING.md` (what got in the way before). Run long tests with `run_in_background` and wait for the notice; let the game
  end itself (`quitforce`), a killed process loses the log tail.
- Never kill the user's own `spring.exe`; only the processes the test started.
