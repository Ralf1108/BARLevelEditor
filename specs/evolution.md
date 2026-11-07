# Evolution

A game mode of LAN Play on any map (button **Evolution** of the room, gadget `evo_game.lua` of the extra game "Level Editor Scenarios"). Every team plays one unit that evolves through 10 stages by kills. User view: [Evolution manual](../LevelEditor/game-modes/evolution.md).

## 1. LAN Play room (`lan_lobby.lua`)

- Button **Evolution** below Custom Scenario and Copilot (`ensureEvolutionUi`, row 3 of `roomPlace`; caption "Evolution: on / off"), not in a scenario room. The host switches it (`setEvolution`): the game option `lanevolution=1` in `S.battle.modoptions` (sent to the room with `SETSCRIPTTAGS game/modoptions/lanevolution=1`, empty when off), and `syncPveGame()` because the mode needs the extra game (`needsExtraGame`). A joiner sees the state from the game options of the room and cannot change it.
- Switching it on opens a window for the host (`bigPopup(EVO_INFO)`): the rules in short and the tip about the map size (size class M or smaller, up to 16 x 16; the size classes of the lobby: M is mostly 16 x 16).
- Choosing a scenario switches it off (a scenario has its own rules).
- Start script (`buildScript`): `lanevolution=1`, `deathmode=neverend` instead of the room's value (the commanders are replaced, the game must not end for that; the mode never ends) and `StartPosType=0` (the start positions of the map: choosing a position would only hold up the start).
- Test automation: `evolution=1` in `lanlobby_cfg.txt` (the host switches it on after 10 s); `botVersion=` for the computer of `bot=`.
- Changing these rules is a change of the LAN logic: `LAN_VERSION` 16.

## 2. Gadget `evo_game.lua`

- Loaded only with the game option `lanevolution=1` (otherwise the file returns false).
- **Players:** from frame 30 to 900, every 15 frames, every team (not Gaia, not dead) with a commander (`customParams.iscommander`) joins: its units are removed (no wreck, no explosion) and a stage 1 unit stands where the commander stood. Teams without a commander (Scavengers, Raptors) stay as they are. A team without an active human player (`Spring.GetPlayerList(team, true)`, not a spectator) is a computer team.
- **Units:** `LADDERS`, three lists of 10 names (Armada, Cortex, Legion), chosen by damage per second against the default armor times health (armed ground units; artillery, water units and the Tumbleweed left out; the numbers: `test-data\tools\zz_dpsdump.lua`). Every spawn takes a random one of the names of its stage that exist in `UnitDefNames` (`stageUnit`).
- **Points:** `need(s) = max(1, floor(3 * 1.6^(s - 1) + 0.5))` from stage s to s + 1. A wild unit gives 1, a player unit of stage v killed by a unit of stage k gives `need(v) * max(1, 1 + v - k)` (`worth`). Points go to the team of the attacker (`UnitDestroyed` attackerTeam), never for an allied or the own unit. Several stages at once are possible; at stage 10 the points stay 0.
- **Evolving:** the new unit replaces the old one at its place (`evolve`: position, facing, full health; a human's unit keeps up to 16 orders, given again with shift).
- **Death:** the stage goes down by one (at least 1), the points are lost, deaths + 1; after 5 s the unit comes back at `spawnPoint`: of 24 random places (200 Elmo from the edge) where the unit can stand (`Spring.TestMoveOrder`, otherwise ground height > 0) the one farthest from the units of the players. Unlimited lives, no end.
- **Wild units:** `wildCount()` = one per 1024 x 1024 Elmo of the map, 12 to 100; Gaia units of stage 1 of a random faction at random places, health 10 % (`SetUnitMaxHealth`), fire state return fire, move state hold position. A destroyed one comes back 10 s later somewhere else.
- **Computer teams:** fire state return fire; every 3 s an `CMD.ATTACK` on the nearest enemy player unit of the same stage or higher (at stage 1 also the wild units), with nothing to attack a move to a random place when idle. `AllowCommand` drops every order to their unit that is not given by synced code (the orders of the team's own AI), except the state orders (fire state, move state, repeat, idle mode).
- **Protection:** a player's unit cannot self-destruct (`CMD.SELFD`) or be given away (`AllowUnitTransfer`).
- **Display (unsynced):** a line per team at the top ("PlayerA: stage 3/10 Brute   points 2/8   kills 1   deaths 0"), the own team in white; the own new unit is selected (`SelectUnitArray`); after a respawn the camera goes to it (`SetCameraTarget`).
- **State:** game rules `evoState` ("" / "running"), `evoTeams`; team rules (public) `evoStage`, `evoXp`, `evoNeed`, `evoKills`, `evoDeaths`, `evoUnit`, `evoSpawn`, `evoName` (unit definition name).

## 3. Tests

`lan_test.ps1 -Mode evo` (official map, default Comet Catcher Remake 1.8): the host switches Evolution on, PlayerA, PlayerB and a BARb computer (ally team 2) play; `zz_lantest.lua` logs the state every 10 s, sends the units of the two humans to random places in the middle and takes the pictures of the README with the engine's own `screenshot png` at frames 2460, 5460 and 8460 (camera on the own unit; `screenshots\` of the host's write dir). A picture of the window from outside (PrintWindow, also with `-FrontShots`: the window in front and the screen copied) came out white on the test machine, in the lobby and in the game, so there is no picture of the room. Checked: the button and the game option, the same state on both computers, points, evolving into units of other factions, death with respawn one stage lower, the wild units, BARb steered (its own orders dropped: they come with player 0 and fromSynced true) up to stage 4.

## 4. Open

Hovercraft and amphibious units in the ladders; a balance of the factions on the same stage; settings in the room (number of wild units, points); a minimap marker of the units.
