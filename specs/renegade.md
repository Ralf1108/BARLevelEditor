# Renegade

- A game mode of LAN Play (button **Renegade** of the room, see [LAN Play](lan-play.md); quick start `start_renegade.bat`).
- Every human steers **one original BAR unit in the first person** (mouse look, W A S D, crosshair, three mouse buttons for the weapons), like the units of a real-time strategy game played as a shooter (named after C&C Renegade).
- Models, speed, weapons, range, armor and damage stay those of the game; the engine does movement, collision, weapons, projectiles and damage, Lua only sends the intent.
- User view: [Renegade manual](../LevelEditor/game-modes/renegade.md), the weapon table: [renegade-weapons.md](../LevelEditor/game-modes/renegade-weapons.md).
- Related: [Evolution](evolution.md) (one unit per player, same gadget pattern), [LAN Play](lan-play.md).

- Rules of thumb: local things stay local (camera, mouse, crosshair, HUD: a game widget); everything that changes the game goes through the synchronized gadget (`Spring.SendLuaRulesMsg` -> `gadget:RecvLuaMsg`), so every computer simulates the same game.
- Scaling target (long term, not promised): 1 -> 2 -> 4-8 -> 20-40 players, measure network load, latency, sim rate and desyncs before going further; hundreds of players are not a goal of the first steps.

## 1. Parts

| Part | File | Job |
|---|---|---|
| Game widget | `LevelEditor/scripts/renegade.lua` (`luaui/widgets`) | camera on the eye of the unit, mouse and keys, crosshair, ray, HUD, anti-air circle, debug menu, sends the input |
| Gadget | `LevelEditor/scripts/renegade_game.lua` (`luarules/gadgets`) | unit of every human, moving, shooting (the buttons), respawn, energy, bots, debug messages |
| Weapon table | `LevelEditor/game-modes/renegade_weapons.csv` (source), `renegade-weapons.md` (made from it) | which weapon of which unit is fired with which button |
| Table tools | `test-data/tools/renegade_weapons.py`, `zz_weapondump.lua`, `game-modes/update_renegade_weapons.bat` | table <-> `renegade_data.lua` (the weapon tables, loaded by the gadget) |
| Start | `LevelEditor/start_renegade.bat`, `scripts/start_renegade.ps1` | a game at once (see 2) |
| Lobby | `lan_lobby.lua` | not done: button and game option like `lanevolution` (needs a `LAN_VERSION` bump) |

- Widget and gadget are in `$ScenarioGameFiles` (`shared/bar_common.ps1`) together with `editor_common.lua` and `area_attack.lua` (the unit menu of the debug mode; `Get-EditorGameEntries` in `editor_manifest.ps1` skips what the extra game "Level Editor" has already).
- Tests: sandbox `test-data/tools/pve_test.ps1 -Ren [-RenTest] [-RenBots n] -Widget zz_ren*.lua` (see Tests below).

## 2. Game options and start

- `lanrenegade=1`: the mode (gadget and widget load only with it).
  - `lanrenebots=<n>` (0 to 30): computer Peewees that hunt the players.
  - `lanrenedebug=1`: the debug menu (turn into a unit, spawn an enemy).
  - `lanrenotest=1`: test hooks (see Tests below).
- **Quick start:** `LevelEditor\start_renegade.bat [map] [AI] [bots]` (default `Hooked 1.1`, `NullAI`, 3 bots) runs `ensure_installed.ps1` and `scripts\start_renegade.ps1`, which writes `LevelEditor\renegade_script_installed.txt` (ignored by git) and starts the engine on it: you in team 0 (Armada), the computer player in team 1 (Cortex), options `lanrenegade=1; lanplay=1; deathmode=neverend; lanrenebots=<n>; lanrenedebug=1` (`-DebugMode 0` without the debug menu).
  - Do not change the bat file while the game runs (cmd reads it by position).

- **Quick test start (`-QuickTest`, `quick`):** `start_renegade.bat "Map" AI Count quick` (the fourth parameter) passes `-QuickTest` to `start_renegade.ps1`: then the game options below are **not** written (no Legion, no extra units, no release candidates, no Scavenger and Raptor units: the game loads faster).
  - Without it everything is loaded (the default when the user starts the batch file).
  - The test tool has the same switch: `pve_test.ps1 -Quick` leaves out `experimentallegionfaction` and `forceallunits` (the sandbox runs of a Renegade test take about 33 s then); use it for quick tests that do not need Legion or Scavenger units (a test of a Legion unit or of a unit that only exists with these options runs without `-Quick`; `zz_unitinfo.lua` does).
- **All units in the start script:** `start_renegade.ps1` writes the game options `experimentallegionfaction=1; experimentalextraunits=1; releasecandidates=1` (the same three as the Level Editor and `choose_map.ps1`), so the Legion units, the extra units of the release candidates and the units of the release candidates are in the game and in the unit menu of the debug mode.
  - And since the user wants to test the Raptors, `forceallunits=1` (the Scavenger and Raptor units; about 10 s longer start) is part of the default too; the test start `pve_test.ps1` has `experimentallegionfaction=1` and `forceallunits=1` since long ago.
- **BAR folder in the start files:** `start_renegade.bat`, `start_evolution.bat` and `start_level_editor.bat` no longer have `C:\Games\Beyond-All-Reason` built in: without `-Data` the scripts (and the Level Editor bat) search the installation with `Find-Bar` and remember it in `%LOCALAPPDATA%\BAR-Level-Editor\bar_path.txt`.
  - `Get-VersionsText` takes any `rapid\<repository>\byar\versions.gz` when the usual repository folder is missing, and the error lists what was found.

## 3. Messages and parameters

Widget -> gadget (`SendLuaRulesMsg`; the sender's team must own a unit):

- `ren|<yaw>|<pitch>|<keys>|<fire>|<x>|<y>|<z>|<unit>`: the view in whole degrees (yaw 0 looks along +z, 90 along +x), keys W 1, A 2, S 4, D 8, `fire` bits left 1, right 2, middle 4; always (also without a button: the turret follows the view) the point under the crosshair, or a far point in the sky, and the unit there (an aircraft in the anti-air circle: the lock) or -1.
  - Sent at once when keys or buttons change, otherwise at most every 3 frames and only when the text changed.
- `ren|unit|<name>`: debug, turn into that unit. `ren|spawn|<name>`: debug, an enemy of that kind. `ren|test|1`, `ren|test|2`, `ren|test|3`: `lanrenotest` only.

Parameters (gadget -> widget): team rules `renUnit` (the unit, 0 = none), `renRespawn` (frame of the return after a loss, 0 = alive); unit rules `renSlots` ("left;right;middle", each a comma list of weapon numbers), `renAA` and `renHY` (comma lists, see Anti-air in [renegade-shooting.md](renegade-shooting.md)).

## 4. Documents

| Document | Content |
|---|---|
| [renegade-widget.md](renegade-widget.md) | the widget `renegade.lua`: camera, mouse and keys, crosshair, panel, dials, binoculars, damage numbers, debug menu |
| [renegade-units.md](renegade-units.md) | the gadget `renegade_game.lua`: units, moving, hull controls, reverse, jump mode, healing, debug messages |
| [renegade-aircraft.md](renegade-aircraft.md) | aircraft: steering, height, bombs, shot down aircraft |
| [renegade-shooting.md](renegade-shooting.md) | the three buttons, anti-air, arc weapons, beams, the weapon table and its pictures |

## 5. Tests (sandbox, `pve_test.ps1 -Ren ...`, lines in the infolog)

- `-RenTest` = `lanrenotest=1` and `lanrenedebug=1`, `-RenBots n` = `lanrenebots=n`.
- Hooks of `lanrenotest`: `ren|test|1` an enemy Peewee (hold fire) 150 Elmo ahead, `|2` kills the own unit, `|3` an enemy Brawler (hold fire) 250 Elmo ahead and 100 up; the gadget logs the census at frame 40, bots and spawns.

| Widget | Checks |
|---|---|
| `zz_ren.lua` | camera state against the wanted direction, W A S D, the mouse warp |
| `zz_cam.lua` | which camera states take a direction |
| `zz_ren3.lua`, `zz_ren4.lua` | ray on enemy and ground, full turn, fire into the sky; features near the start (Hooked: a gravestone `corstone` 40 Elmo in front of the start) |
| `zz_ren5.lua` | bots (`-RenBots 3`), turning into a Grunt, the menu picture, kill and respawn |
| `zz_ren6.lua` | latency, two buttons with a Titan, a turret, energy |
| `zz_ren7.lua` | the search field, a ship on the land |
| `zz_ren8.lua` | the three buttons with Titan, Epoch, Karganeth, nothing keeps firing after the release |
| `zz_ren16.lua` | commander: laser left, D-gun right (the enemy is destroyed) |
| `zz_ren15.lua` | the turret follows the view without a button (barrel direction, reload held), the first shot 2 frames after the click, the facing arrow (picture); a screenshot stalls drawing for a few frames: a short press during that time is not seen by the widget |
| `zz_ren14.lua` | one click = one shot (turret still turning), held = continuous fire |
| `zz_ren9.lua` | respawn with the countdown, `GetUnitWeaponVectors` |
| `zz_ren10.lua`, `zz_ren11.lua`, `zz_ren13.lua` | anti-air circle and lock (turret `armrl`), Titan starburst (point only), Titan laser (lock) |
| `zz_ren12.lua` | the menu in the mode "Spawn enemy", spawned units: distance 1001 Elmo, aircraft 200 up |
| `zz_weapondump.lua` | one `[zzwep]` line per weapon (for the table) |

## 6. Not done and open

- **Several humans, not tested:** two players in the LAN (host + one joiner): each steers one unit, they fight, no desync.
  - Needs the lobby button, the game option for every player, `LAN_VERSION`, teams, one unit per human without a commander, scoring.
- **Jumping:** the engine has no jump for ground units; ideas: a short hop with `Spring.SetUnitVelocity` (the movement type may overwrite it), or `Spring.MoveCtrl` only for the duration of the jump (own ballistic curve, back to normal movement on landing), or the unit scripts (`CallCOBScript`) for the animation.
  - To decide: how ground movement reacts to a velocity impulse, landing detection, firing in the air, determinism; the input message would get a key bit (Space = 16).
- Not checked by a human or not seen: the barrel lines on a picture, the Tab key as a commander, flying units as the player's unit (steering by move orders), whether the Titan starburst can hit an aircraft at all, how the lock feels against fast aircraft.
- Open questions: a feel for the move orders (lag, the unit's heading against the view), traffic and determinism of the messages with many players, what the lobby and team setup need.
- Not planned for the first steps: hundreds of players, an own lobby/matchmaking/dedicated server, new weapons, projectiles or damage model, full HUD, sound, animations, progression.
- **Unit bars of the game:** the bars over the units (widget "Health Bars GL4") stay on.
  - The bar over the own unit that hangs at the crosshair after the switch back into the unit is **not solved**: restarting the widget with `luaui disablewidget` is refused by the game ("User widgets cannot control other widgets"), so that attempt was removed.
