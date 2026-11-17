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
| Gadget | `LevelEditor/scripts/renegade_game.lua` (`luarules/gadgets`) | unit of every human, moving, jump, shooting (the buttons), respawn, energy, bots, power-ups (`lanrenepowerups`), debug messages |
| Weapon data | `LevelEditor/scripts/renegade_data.lua` | the weapon tables, loaded by the gadget (made from the csv) |
| Test hooks | `LevelEditor/scripts/renegade_test.lua` | `ren\|test\|n`, loaded by the gadget only with `lanrenotest=1` |
| Race | `LevelEditor/scripts/renegade_race.lua` (synced, loaded by the gadget with `lanrenemode=race`) | the checkpoints, the laps, the places, the end (see 9) |
| Survival | `LevelEditor/scripts/renegade_survival.lua` (synced, loaded by the gadget with `lanrenemode=survival`) | the waves, the players of a wave, the end (see 8) |
| Round | `LevelEditor/scripts/renegade_rounds.lua` (synced, loaded by the gadget), `renegade_hud.lua` (loaded by the widget) | the kill goal, the kill feed, the end of the round and its banner (see 7) |
| Power-ups | `LevelEditor/scripts/powerups.lua` (synced logic and the list), `powerups_ui.lua` (drawing), shared with [Evolution](evolution.md) | Sprint, Repair, Radar Pulse, Cloak, Jammer: beacons, use, effect; the bar and the beacons on the map (see [shared-code.md](shared-code.md)) |
| Weapon table | `LevelEditor/game-modes/renegade_weapons.csv` (source), `renegade-weapons.md` (made from it) | which weapon of which unit is fired with which button |
| Table tools | `test-data/generators/renegade_weapons.py`, `zz_weapondump.lua`, `game-modes/update_renegade_weapons.bat` | table <-> `renegade_data.lua` (the weapon tables, loaded by the gadget) |
| Start | `LevelEditor/start_renegade.bat`, `LevelEditor/start_race.bat`, `scripts/start_renegade.ps1` | a game at once (see 2) |
| Lobby | `lan_lobby.lua` | the button Renegade of the room with a submenu: On / Off, Always in unit, Power-ups, Goal, Survival, Race (game options `lanrenegade`, `lanrenesingle`, `lanrenepowerups`, `lanrenegoal`, `lanrenemode`; `LAN_VERSION` 36) |

- Widget, gadget, `renegade_data.lua`, `renegade_test.lua`, `renegade_rounds.lua`, `renegade_survival.lua`, `renegade_race.lua`, `renegade_hud.lua`, `mode_ui.lua`, `powerups.lua` and `powerups_ui.lua` are in `$ScenarioGameFiles` (`shared/bar_common.ps1`) together with `editor_common.lua` and `area_attack.lua` (the unit menu of the debug mode; `Get-EditorGameEntries` in `editor_manifest.ps1` skips what the extra game "Level Editor" has already).
- Tests: sandbox `test-data/tools/pve_test.ps1 -Ren [-RenTest] [-RenBots n] -Widget zz_ren*.lua` (see Tests below).

## 2. Game options and start

- `lanrenegade=1`: the mode (gadget and widget load only with it).
  - `lanrenebots=<n>` (0 to 30): computer Peewees that hunt the players.
  - `lanrenepowerups=1`: the power-ups without Evolution (see [renegade-units.md](renegade-units.md), Power-ups); with `lanevolution` Evolution's own are used.
  - `lanrenegoal=<n>`: the first team with n kills wins the round (see 7); the lobby writes 20 by default.
  - `lanrenemode=survival` / `race`: the modes Survival (see 8) and Race (see 9); not with Evolution; always Always in unit, no bots, no goal.
  - The LAN lobby writes `deathmode=neverend` for a Renegade room (the commanders are replaced: the game must not end by a lost commander).
  - `lanrenedebug=1`: the debug menu (turn into a unit, spawn an enemy).
  - `lanrenotest=1`: test hooks (see Tests below).
- **Start scripts:** both quick start scripts (`start_renegade.ps1`, `start_evolution.ps1`) use `Resolve-ExtraGame` and `Start-ExtraGame` of `shared/bar_common.ps1` (data folder, extra game, engine, writing and starting the start script); `-DryRun` only writes the start script (tests: `ps_test.ps1`).
- **Quick start:** `LevelEditor\start_renegade.bat [map] [AI] [bots]` (default `Hooked 1.1`, `NullAI`, 3 bots) runs `ensure_installed.ps1` and `scripts\start_renegade.ps1`, which writes `LevelEditor\renegade_script_installed.txt` (ignored by git) and starts the engine on it: you in team 0 (Armada), the computer player in team 1 (Cortex), options `lanrenegade=1; lanplay=1; deathmode=neverend; lanrenebots=<n>; lanrenedebug=1` (`-DebugMode 0` without the debug menu).
- **Race quick start:** `LevelEditor\start_race.bat [map] [quick]` (default `Comet Catcher Remake 1.8`) runs `start_renegade.ps1 -Mode race -Bots 0 -DebugMode 0`: the option `lanrenemode=race` (`-Mode survival` works the same way); the race removes the units of the computer player.
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
- `ren|unit|<name>`: debug, turn into that unit. `ren|spawn|<name>`: debug, an enemy of that kind. `ren|test|1` to `ren|test|9`: `lanrenotest` only; `ren|use|<n>`: a power-up (only with `lanrenepowerups`, see renegade-units.md).

Parameters (gadget -> widget): team rules `renUnit` (the unit, 0 = none), `renRespawn` (frame of the return after a loss, 0 = alive), `renKills`, `renDeaths`; game rules `renGoal`, `renWinner`, `renResult`, `renOver` (see 7); the message `renKill` (SendToUnsynced, then the global `renKill` of the widget: killer team, victim team, victim and killer unit definitions); unit rules `renSlots` ("left;right;middle", each a comma list of weapon numbers), `renAA` and `renHY` (comma lists, see Anti-air in [renegade-shooting.md](renegade-shooting.md)).

## 4. Documents

| Document | Content |
|---|---|
| [renegade-widget.md](renegade-widget.md) | the widget `renegade.lua`: camera, mouse and keys, crosshair, panel, dials, binoculars, damage numbers, debug menu |
| [renegade-units.md](renegade-units.md) | the gadget `renegade_game.lua`: units, moving, hull controls, reverse, jump, power-ups, takeover mode, healing, debug messages |
| [renegade-aircraft.md](renegade-aircraft.md) | aircraft: steering, height, bombs, shot down aircraft |
| [renegade-shooting.md](renegade-shooting.md) | the three buttons, anti-air, arc weapons, beams, the weapon table and its pictures |

## 5. Tests (sandbox, `pve_test.ps1 -Ren ...`, lines in the infolog)

- `-RenTest` = `lanrenotest=1` and `lanrenedebug=1`, `-RenBots n` = `lanrenebots=n`, `-RenPowerups` = `lanrenepowerups=1`, `-RenTakeover` = `lanrenesingle=0`, `-RenGoal n` = `lanrenegoal=n`, `-RenMode survival|race` = `lanrenemode`.
- Hooks of `lanrenotest` (all in `scripts/renegade_test.lua`, loaded by the gadget only in test mode; `|4`, `|5`, `|6` are described in the aircraft and units documents, `|7` and `|8` give all power-ups and put the unit onto a beacon, `|9` destroys the nearest enemy unit with the player's unit as the attacker: a kill that counts, `|10` destroys the wave of Survival, `|11` puts the unit onto its next checkpoint of the Race): `ren|test|1` an enemy Peewee (hold fire) 150 Elmo ahead, `|2` kills the own unit, `|3` an enemy Brawler (hold fire) 250 Elmo ahead and 100 up; the gadget logs the census at frame 40, bots and spawns.

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
| `zz_ren90.lua` | the jump (Space) of a two-legged bot; tank and spider do not jump |
| `zz_ren91.lua` | Renegade with Evolution: the keys 1 to 5 use the power-ups (`-Ren -RenTakeover -RenTest -Evo -EvoTest -Debug`) |
| `zz_ren92.lua` | Renegade power-ups without Evolution: beacon, the five keys, the bar (`-Ren -RenTest -RenPowerups`) |
| `zz_ren93.lua` | the kill goal (`-RenGoal 3`): three kills by `ren\|test\|9`, the feed, the winner, the banner, GameOver 8 s later |
| `zz_ren97.lua` | Survival: the computer team loses its units, wave 1 (level 2 unit), the wave cleared, the break, wave 2 (level 3), the loss of the only player: the waves win, GameOver |
| `zz_ren98.lua` | Race: the track (8 checkpoints), the racers, the pick of another racer (the unit turns into it), the start grid at GO, 16 checkpoints by `ren\|test\|11` (2 laps), the sounds checkpoint and lap, the results, New race (a new track, race 2), Leave (GameOver); also with `-Map "Comet Catcher Remake 1.8"` (cliffs: 1032 of 7752 cells not drivable) |
| `zz_sight.lua` | the sight of the unit: Renegade 3 times, Radar Pulse, back (`G.setSight`) |
| `zz_weapondump.lua` | one `[zzwep]` line per weapon (for the table) |

## 6. Not done and open

- **Several humans, not tested:** two players in the LAN (host + one joiner): each steers one unit, they fight, no desync.
  - The lobby button, the game options and the kill goal exist; teams are the ally teams of the room.
- **Both modes together:** the speedometer of Renegade overlaps the level badge of the character panel of Evolution at the bottom of the screen (the keys 1 to 5 and the bar of Evolution work).
- **Jump:** done for two-legged bots, see [renegade-units.md](renegade-units.md); not seen in a real window: the walk animation in the air, the feel of the height and of the pause.
- Not checked by a human or not seen: the barrel lines on a picture, the Tab key as a commander, flying units as the player's unit (steering by move orders), whether the Titan starburst can hit an aircraft at all, how the lock feels against fast aircraft.
- Open questions: a feel for the move orders (lag, the unit's heading against the view), traffic and determinism of the messages with many players, what the lobby and team setup need.
- Not planned for the first steps: hundreds of players, an own lobby/matchmaking/dedicated server, new weapons, projectiles or damage model, animations, progression.
- **Unit bars of the game:** the bars over the units (widget "Health Bars GL4") stay on.
  - The bar over the own unit that hangs at the crosshair after the switch back into the unit is **not solved**: restarting the widget with `luaui disablewidget` is refused by the game ("User widgets cannot control other widgets"), so that attempt was removed.

## 7. The round

- **Goal** (`renegade_rounds.lua`, game option `lanrenegoal`): the first team with that many kills (`renKills`) wins.
  - Only with Always in unit, without Evolution (it has its own end).
  - `M.finish(team, text)`: game rules `renWinner`, `renResult`, `renOver` (frame); `Spring.GameOver({ ally team })` 8 s later (`END_WAIT`).
- **Kills:** every enemy unit a team destroys counts (also the bots and the test units); a lost unit of a player counts as a death.
- **Kill feed:** a line for every lost unit of a player or a bot and for every kill of a player's unit (`renKill` -> `R.H.kill`).
  - At the top, left of the list of the players: the last 6 lines, 8 s each, killer and victim in the color of their team; a line of the own team has a warmer background.
- **List of the players:** the title is "FIRST TO n KILLS" with a goal (`R.H.goalTitle`), the leader's name is gold.
- **Banner** (`R.H.drawEnd`, also in the normal game): VICTORY (green) for the own alliance, DEFEAT (red) for the others, ROUND OVER for a spectator; the text of the gadget below.

## 8. Survival

- `renegade_survival.lua` (`modeRun` of the gadget: `frame`, `destroyed`, `clear`), game option `lanrenemode=survival`.
- **Start** (frames 30 to 300): the ally teams of all human teams are allied (`Spring.SetAlly` both ways); the units of the other teams are removed; every player gets a faction of `LADDERS` (Armada or Cortex, the ladders of Evolution).
- **Waves** (`WAVES` = 10, the first at 15 s, a break of 15 s): wave n has `count(n)` = (2 + 1.5 n) x (0.6 + 0.4 x humans) Gaia units of the levels n - 2 - (i mod 3) (at least 1), with half of their health, placed about 1600 Elmo from the players (`place`); waves 5 and 10 add a boss of level n; every 4 s a fight order toward the nearest player unit.
- **Players:** at the start of wave n every unit becomes the unit of level n + 1 of the player's faction (`turnInto`) at full health. A lost unit does not come back during the wave (`due` is not set); at the end of the wave every dead player comes back next to a living mate (`giveUnit`).
- **End:** all waves beaten: `rounds.finish(first human team, ..., the ally teams of the humans)`; all players lost at once: `rounds.finish(-1, "The waves won: ...")`.
- **State:** game rules `renSurvWave`, `renSurvWaves`, `renSurvLeft`, `renSurvNext` (frame of the next wave, 0 during one).
- **Screen** (`renegade_hud.lua`, `H.drawMode`): a panel at the top middle (WAVE 3 OF 10, the enemies left / the seconds to the next wave), "YOU DIED ... when the others beat this wave", the sounds "wave" and "tick" (the last 3 s), the hints of the mode; the hints of `mode_ui.lua` move below the panel.
- **Not checked:** the balance (number, levels and health of the waves) with real players.

## 9. Race

- `renegade_race.lua` (`modeRun`: `frame`, `destroyed`, `noDamage`, `toNext`, `msg`), game option `lanrenemode=race`; phases `wait`, `pick`, `race`, `results`, `leaving`.
- **Racers** (`RACERS`, those the game has): `armflea` (Tick), `armfav` (Rover), `corfav` (Rascal), `legscout` (Wheelie); game rules `renRaceUnits`.
  - Every racer gets the same movement (`equalize`: `SetGroundMoveTypeData` maxSpeed / maxWantedSpeed `SPEED` 150, accRate, decRate and turnRate the means of the racers' `maxAcc`, `maxDec`, `turnRate`); unit rules `ledBaseSpeed` = `SPEED`, which Sprint (`powerups.lua`) uses instead of the speed of the definition.
  - `racers()` (every 15 frames) turns the unit of every human into its pick (`turnInto`), also a respawned Pawn; only the Tick jumps (two legs).
- **Pick:** from frame 60 to the start (`FIRST_GO` = frame 600; `AGAIN_PICK` = 15 s for a new race) `ren|race|pick|<n>` (the gadget's `RecvLuaMsg` gives `ren|race|...` to `modeRun.msg`); no pick = a random one. Team rules `renRacePick`.
- **Track** (`makeTrack`, frame 60 and every new race):
  - The grid (`buildGrid`, once): cells of max(80, the longer side / 120) Elmo where every kind of movement of the racers can drive (`G.fits` without objects, dry ground), a connection to the right and down where the middle between two cells is drivable too; the biggest connected piece.
  - Up to `TRIES` (14) rings: a random turn, a radius of 0.22 to 0.36 of the smaller side; each of the 8 points goes to the nearest cell of the piece. The worst stretch = steps on the grid (breadth first) against the steps of a straight way; at once when it is below `DETOUR` (1.35), otherwise the best ring. A stretch shorter than 3 cells or without a way does not count.
  - Game rules `renRaceCps`, `renRaceLaps` (2), `renRaceGo`, `renRaceNo` (the number of the race).
- **Start:** the units of the computer teams are removed (frames 30 to 300); at the start every racer is put on the start grid (rows of 4 behind the last checkpoint, facing the first one; a place off the drivable piece goes to its nearest cell).
- **Progress** (every 5 frames): a unit within `PASS` (140 Elmo) of its next checkpoint passes it; after the last one the next lap; after the last lap the time (frames since the start). Team rules `renRaceLap`, `renRaceCp`, `renRacePos` (place by lap, checkpoint, distance; finished ones by time), `renRaceTime`.
- **End:** the first one through the finish is the winner; when all are through or after `FINISH_WAIT` (30 s) the results: game rules `renRaceOver` (frame), `renRaceResult` (`team:time:unit;...` by place, time 0 = not finished); the game goes on.
  - `ren|race|again` (any player): `newRace` (a new track, the pick again, `renRaceOver` 0).
  - `ren|race|leave` (any player; also during a race): `rounds.finish(winner or -1)`: the banner and GameOver 8 s later.
- **No damage** between the units of players (`UnitPreDamaged` asks `modeRun.noDamage`).
- **Screen** (`renegade_hud.lua`): the rings on the ground (`H.drawModeWorld`: the next one green, pulsing, with a column of light and a flat arrow to the checkpoint after it, the others faint), the panel (lap, checkpoint, place, time), the countdown 5 to 1 and GO, an arrow to the next checkpoint (relative to the view) with its distance; sounds tick, the start, checkpoint, lap (reset with `renRaceNo`); the hints of the mode after the start.
  - Before the start the cards of the racers (`drawPick`: picture, name, faction, key; the own pick green); after the race the results (`drawResults`: place, name, racer, time; buttons New race [N] and Leave [L]).
  - `H.raceFree()` (cards or results on screen): the widget frees the mouse (no view, no driving, no hints), a click goes to `H.raceClick`, keys to `H.raceKey` (1 to 9, N, L).
- **Not checked:** a race of several humans; a map where the drivable land is split (the track uses the biggest piece only).
