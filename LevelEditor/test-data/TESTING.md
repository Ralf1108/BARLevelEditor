# Testing notes: what got in the way

Collected while testing the game modes over LAN Play (2026-10-27). Read this before the next test run. How to run: [README](README.md).

## Before a run

- **Update the installation first.** Run `scripts\install_editor.ps1` (the full run, not `-Quick`: only it installs the LAN lobby widget and the junction for the scenarios) when the installed state is older than the repository. The installed `LevelEditorScenarios.sdz` was from before Reclaim the Fame and had no `rtf_game.lua`. The test tool builds its own copy of that game from the repository, but the game files and engine come from the installation. The installed game must not be running (`tasklist`); kill only the own test processes, never `spring.exe` of the user.
- **Memory.** Two instances of the game need about 8 GB each. Claude Code stops background jobs when the machine runs low on memory (a run was killed once). Ask the user to close the browser, check the free memory, run the modes one after the other, never in parallel.
- **Sandbox rules** (own write dir, framed window, nothing in the user's data folder): see the memory note "Test runs in a window". The tool does it; the work folder is rebuilt at every start.

## During a run

- **Run the tool in the background** (`run_in_background`) and wait for the notice. A foreground command is moved to the background after 120 s; `sleep` chains are blocked.
- **The log tail is lost when a process is killed.** Let the game end itself (the widget calls `quitforce` at `-QuitFrame`) and keep `LogFlushLevel = 0` in the springsettings of the sandbox (the tool sets it). A log that stops after "frame 0" looked like a hang, but the game had run on to frame 9000.
- **A widget that fails once is removed for good.** `Error in GameFrame()` in `infolog.txt` means the test widget is gone and nothing more is logged. Pitfalls found: `tostring(Spring.GetGameRulesParam(x))` fails when the parameter is not set yet (use a helper that checks `nil`), `table.concat` fails with the boolean values of `Spring.GetPlayerInfo` (wrap in `tostring((...))`).
- **A game widget cannot read files from the write dir** with `VFS.LoadFile(name, VFS.RAW)` (the mode silently fell back to the default). Take values from the game options (`Spring.GetModOptions()`: `ctfconfig`, `rtfconfig`, `tdconfig`).
- **The lobby test hooks race each other.** The automatic Start (`lanlobby_cfg.txt`: `auto=host`) fired 5 s before the Copilot click and the game started with two separate teams. Use `startDelay=` in the cfg so that the Start comes after the hook.
- **Check the start script, not only the game.** `<work>\sbx_H\data\lan_status.txt` holds the script the host built (`[player]`, `Team=`, `[ai]`): that is where "both humans are in team 0, the opponent is an AI" showed up first.
- **Compare both logs.** Every `[zzlan]` line must show the same scores and positions on host and joiner; one side alone proves nothing.
- **Screenshots of the lobby come out black** with `CopyFromScreen` unless the window is topmost and the mouse is moved; the log is the more reliable proof.

## Test levels and the scenario builder

- A scenario has **exactly one player team** (`roles`: `"0": "s"`, `"1": "e"`); the other team is an AI team in `scenario.txt`. Two humans against each other need the lobby to turn that AI team into a human team (done in `lan_lobby.lua` for scenarios with `ctfconfig` / `rtfconfig`).
- Capture the Flag and Reclaim the Fame cannot be on in the same level as Tower Defense.
- Without `-LevelDir` the builder reads the user's `LevelEditor\levels` (gitignored); the test levels are in `test-data\levels`.
- The unit height on "Full Metal Plate 1.7" is y = 449.

## Writing the tools (Windows)

- Python gets Windows paths (`C:/...`) from Git Bash scripts, not `/c/...`.
- Do not patch PowerShell files with Python strings that contain `\t`, `\b`, `\n`: the backslash sequences turn into tab / backspace characters (`$sp\bundle_` became `$spundle_`). Use `chr(92)` or write the file as a whole, then run `[scriptblock]::Create((Get-Content -Raw file))` as a syntax check and grep for control characters.
- Write start scripts without BOM (PowerShell 5.1 `Set-Content -Encoding UTF8` adds one and the engine does not start the game).
- Junctions in the sandbox are removed with `cmd /c rmdir` before the folder is deleted, otherwise `Remove-Item -Recurse` deletes the real folders behind them.

## What the first runs found

- Over LAN Play every human of a scenario was put in team 0 and the opponent stayed an AI: Capture the Flag and Reclaim the Fame (human against human) could not be played. Fixed in `lan_lobby.lua` (the joiner gets the other ally team once; the AI of the opponent team is removed). The room gave the joiner the host's ally number by default, so the fix needed the first-status correction too.
