# Testing notes: what got in the way

Collected while testing the game modes over LAN Play (2026-10-27). Read this before the next test run. How to run: [README](README.md). Notes on patching files are in `CLAUDE.md` at the top of the repository.

## Before a run

- **Update the installation first.** Run `scripts\install_editor.ps1` (the full run installs the junction for the scenarios; the quick run of `start_level_editor.bat` updates the extra games and LAN Play) when the installed state is older than the repository. The test tool builds its own copy of the extra game of the scenarios from the repository (`Write-ScenarioGame`), but the game files and engine come from the installation. The installed game must not be running (`tasklist`); kill only the own test processes, never `spring.exe` of the user.
- **Memory.** Each instance of the game needs 8-10 GB (the test machine has 32 GB). A run with too little free memory was killed once; three instances (host and two joiners, `lan_test.ps1 -Clients 2`) were stopped twice by Claude Code for lack of memory (2026-10-28), host plus one joiner works. Close the browser, run the modes one after the other, never in parallel, and do not start a killed run again by yourself.
- **Sandbox rules:** an own write dir, a framed window, nothing in the user's data folder. The tools do it; the work folder is rebuilt at every start.

## During a run

- **The log tail is lost when a process is killed.** Let the game end itself (the widget calls `quitforce` at `-QuitFrame`) and keep `LogFlushLevel = 0` in the springsettings of the sandbox (the tool sets it). A log that stops after "frame 0" looked like a hang, but the game had run on to frame 9000.
- **A widget that fails once is removed for good.** `Error in GameFrame()` in `infolog.txt` means the test widget is gone and nothing more is logged. Pitfalls found: `tostring(Spring.GetGameRulesParam(x))` fails when the parameter is not set yet (use a helper that checks `nil`), `table.concat` fails with the boolean values of `Spring.GetPlayerInfo` (wrap in `tostring((...))`).
- **A game widget cannot read files from the write dir** with `VFS.LoadFile(name, VFS.RAW)` (the mode silently fell back to the default). Take values from the game options (`Spring.GetModOptions()`: `ctfconfig`, `rtfconfig`, `tdconfig`).
- **The lobby test hooks race each other.** The automatic Start (`lanlobby_cfg.txt`: `auto=host`) fired 5 s before the Copilot click and the game started with two separate teams. Use `startDelay=` in the cfg so that the Start comes after the hook.
- **Check the start script, not only the game.** `<work>\sbx_H\data\lan_status.txt` holds the script the host built (`[player]`, `Team=`, `[ai]`): that is where "both humans are in team 0, the opponent is an AI" showed up first.
- **Compare both logs.** Every `[zzlan]` line must show the same scores and positions on host and joiner; one side alone proves nothing.
- **A game option is shown by the room as a text line.** A first version of the version check sent its checksums as a game option (`SETSCRIPTTAGS game/modoptions/...`); the room showed them and pushed the buttons Custom Scenario and Copilot out of sight (seen by the user, not in a log). Anything that is not meant to be read in the room goes over a short connection to the server of the widget (`WHO`, `COPILOT`, `LANVER`, `MAPINFO`, `FETCHMAP`).
- **The lobby downloads a missing map by itself.** A joiner with an empty maps folder starts the online download of the map as soon as he is in the room (`WG.DownloadHandler`), so a test of the transfer from the host runs in parallel with it and proves nothing (the file with its `.md5.gz` came from the official servers). `-NoMap` of `lan_test.ps1` writes `noOnline=1` into the cfg: the widget replaces `WG.DownloadHandler.QueueDownload` by an empty function; no `.md5.gz` next to the map means it came from the host.
- **`read("*a")` and `seek("end")` of a file in the lobby give 3 bytes more than the file has** (69333408 against 69333405 for Full Metal Plate 1.7); the md5 over the chunks (`read(65536)` in a loop) is the official one. The widget reads every file in chunks (`readWhole`) so that size and md5 are the same on both computers; the cause was not looked for.
- **Version test without a second version:** `lan_test.ps1 -Lobby other` adds a comment line to the joiner's `lan_lobby.lua` (another hash, the same `LAN_VERSION`: the message says "same version number, but the files differ"), `-Sync same|missing|other` does the same for the extra game of the scenarios.
- **Screenshots of the lobby come out black** with `CopyFromScreen` unless the window is topmost and the mouse is moved; the log is the more reliable proof.

## Test levels and the scenario builder

- A scenario has **exactly one player team** (`roles`: `"0": "s"`, `"1": "e"`); the other team is an AI team in `scenario.txt`. Two humans against each other need the lobby to turn that AI team into a human team (done in `lan_lobby.lua` for scenarios with `ctfconfig` / `rtfconfig`).
- Capture the Flag and Reclaim the Fame cannot be on in the same level as Tower Defense.
- Without `-LevelDir` the builder reads the user's `LevelEditor\levels` (gitignored); the test levels are in `test-data\levels`.
- The unit height on "Full Metal Plate 1.7" is y = 449.

## Writing the tools (Windows)

- Python gets Windows paths (`C:/...`) from Git Bash scripts, not `/c/...`.
- Patching files with backslashes: see `CLAUDE.md`.
- Write start scripts without BOM (PowerShell 5.1 `Set-Content -Encoding UTF8` adds one and the engine does not start the game).
- Junctions in the sandbox are removed with `cmd /c rmdir` before the folder is deleted, otherwise `Remove-Item -Recurse` deletes the real folders behind them.

## What the first runs found

- Over LAN Play every human of a scenario was put in team 0 and the opponent stayed an AI: Capture the Flag and Reclaim the Fame (human against human) could not be played. Fixed in `lan_lobby.lua` (the joiner gets the other ally team once; the AI of the opponent team is removed). The room gave the joiner the host's ally number by default, so the fix needed the first-status correction too.

## Testing the menu of the editor in a sandbox game (found 2026-10-27, AI page and menu bug)

- **Method:** a small test widget (`tools/zz_menu.lua`, goes to `LuaUI/Widgets` of a sandbox game that has the editor built from the repository files) works the buttons through `WG.LevelEditorWidget`: `DebugLayout()` returns the rectangles (side buttons have `side = true`, `kind`, `value` and `active`), `MousePress` / `MouseRelease` click them, `KeyPress(27, {}, false)` presses Esc, a screenshot (`screenshot png`) shows the result. `zz_menu.lua` clicks every side button after every other one (56 pairs) and checks that exactly the chosen one is `active`; it ends with `quitforce`. Result 2026-10-27: 56 pairs, 0 mismatches.
- **Look into `infolog.txt` first when `WG.LevelEditorWidget` is nil** in the test ("attempt to index a nil value"): the editor widget did not load. The line `Failed to load: lvl_level_editor.lua (...:LINE: ...)` names the line (here an unfinished string). The game itself shows no message for it.
- **A test widget may run out of memory** ("memory limit exceeded"): `DebugLayout()` builds many tables, so a loop with hundreds of calls in one frame dies. Do one action per frame (take one entry off a queue in `widget:Update`) and call `collectgarbage()` between them.
- **A test must always end with `quitforce`**, outside `pcall`; an error before it leaves the sandbox game open until the runner times out (300 s).
- **The one menu toggle that does not close:** `G` stays open when pressed again (leave with `P`); every other side button closes its page on a second click.
- **Two bugs found:** the Place button (`P`) did not close the I, O and AI pages (the same click on `G` did it by accident), and Esc did not close the help board. Both fixed; test them again after changes to the button handling (`kind == "top"` in `widget:MousePress`).
- **A window for pictures:** `XResolutionWindowed = 3000` with a 1500-high window gives readable screenshots; the tooltip of a row shows only while the mouse pointer (`Spring.WarpMouse`) lies on it at the time of the screenshot.
- **Lua limit:** at most 200 local variables per function; `lvl_level_editor.lua` has about 195 at top level. A new top-level `local` can break the load of the whole widget (see above), so count the `^local` lines before adding more and put new constants into an existing table.
- **Per-team AI (button AI):** check the generated start script, not only the menu. `Write-StartScript 'Hooked 1.1' $false '<AI>'` from `choose_map.ps1` (load the function text with `Invoke-Expression`, from `function Write-StartScript` up to `function Set-Autoload`) must give `[ai0] { shortname=...; version=stable|0.1 ... }` for BARb, CircuitAI, `CircuitAI easy` (`[Options] { profile=easy; }`) and NullAI, and `LuaAI=<name>;` in `[team1]` without `[ai0]` for the Lua AIs. Then start a sandbox game with the line and look for `Skirmish AI <Circuit-stable>` in `infolog.txt` (the engine accepted it). Whether Raptors really send waves was not checked.

## BluePrinter in a test

- After a change of `shared\editor_common.lua` or `BluePrinter\bluePrinter.lua` the installed BluePrinter is old until `install_blueprinter.bat`, `start_blueprinter.bat`, `start_blueprinter_test.bat` copied the files (a start of the editor does not); the game that is running keeps the old ones (`/luaui reload`). "I do not see the new feature in the BluePrinter" is almost always this.
- In a sandbox game the BluePrinter does not run next to the editor (it ends when `leveleditor=1` or the editor widget is there); use `leveleditor=0` in the modoptions and expect both panels on top of each other.

## BluePrinter plan tests in a sandbox game

- `tools/zz_bpt.lua` tests selecting, ordering, rotating, removing, Undo, Queue order, right click on a blueprint copy and the commander next to an enemy through the test hooks of the widget (`WG.BluePrinterWidget:DebugState()` and others, see `BluePrinter/SPECIFICATION.md` 4.10); `tools/zz_bpg.lua` plus a screenshot checks that nothing is left after Undo. They run in a game of the **normal BAR** (not the editor game: the BluePrinter does not run next to the editor) with the BluePrinter files copied to `LuaUI/Widgets` and `LuaUI/Include` of the sandbox. Result 2026-10-27: all checks passed; two of the checks depend on terrain (a copy of three buildings had only two buildable spots).
- `tools/zz_bpo.lua` tests placing on plans: a single building and a blueprint replace the plans below, Undo brings them back, a plan with another building on its spot leaves the queue by itself, and Undo does not bring back replaced plans that have a building on them now. Result 2026-10-27: all passed.
- **No buildings from a widget:** `Spring.CreateUnit` does not exist in a widget and `/give` did not create anything in the sandbox. Let the commander build a **different** building (a windmill) on the spot (`GiveOrderToUnit(c, -defID, {x, y, z, 0})`) and check after about 500 frames. A building under construction counts as a building.
- **The pointer moves one frame later:** after `Spring.WarpMouse` the next `Spring.GetMouseState()` still returns the old position; click in a later frame. `TraceScreenRay(mx, my)` returns nil when the point is outside the map (commander start at the left edge): look top-down at plans that lie inside the map (`rx = 2.5`).
- **Auto-build eats the test plans:** with auto-build on a commander finishes small buildings within seconds and they disappear from the queue; switch it off (`DebugSetAuto(false)`) for selection tests, and put plans on spots where `Spring.TestBuildOrder` says free (otherwise they are blocked and never claimed).
- **Chat commands are asynchronous:** `Spring.SendCommands("bp_undo")` acts a frame later; check the result in a later step.
- **A leftover after Undo was found only by looking at units, not at plans:** the builder had received its orders already and started building after the plan was gone. Test "Undo" by counting the own unfinished buildings (`Spring.GetUnitIsBeingBuilt`) some seconds later, once with the building not yet started and once already started.
