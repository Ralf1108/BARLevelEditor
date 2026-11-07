# Evolution

Button **EV** (gadget `evo_game.lua`, page `led_evo.lua`). Every team plays one unit that evolves through 10 stages by kills; the last alliance with lives left wins. Computer teams are steered by the gadget. User view: [Evolution manual](../LevelEditor/game-modes/evolution.md).

## 1. Rules

- **Players:** the teams (not Gaia) that own units when the mode starts. Their units are removed (no wreck, no explosion) and one unit of stage 1 is created where the commander stood (the first unit when there is no commander). The faction is the prefix of that unit's name (`arm`, `cor`, `leg`; otherwise the side of the team).
- **Ladders:** `LADDERS` in the gadget, 10 names per faction, chosen by damage per second against the default armor times health (armed, mobile, walking or driving ground units; artillery, the Tumbleweed and units that need deep water left out). A name missing in `UnitDefNames` is replaced by the unit of another faction on the same stage (`stageUnit`).
- **Points:** `need(s) = max(1, floor(first * (factor / 100)^(s - 1) + 0.5))` points from stage s to s + 1. A wild unit gives 1 point, a player unit `need(its stage)` (also for stage 10). Points go to the team of the attacker (`UnitDestroyed` attackerTeam), never for an allied unit or the own unit. Several stages at once are possible; at stage 10 the points stay 0.
- **Evolving:** the new unit replaces the old one at its place (`evolve`: position, facing, up to 16 orders taken over with shift), with full health.
- **Death:** the points of the stage are lost, a life is taken (`lives` > 0). With lives left (or `lives` = 0) the unit comes back after `respawn` seconds on the same stage at `spawnPoint`: of 24 random places (200 Elmo from the edge) that the unit can stand on (`Spring.TestMoveOrder`, otherwise ground height > 0) the one farthest from the units of the players. Without lives the team is out.
- **Win:** when only one alliance has a team that is not out (and there were two or more at the start): `evoState` = "won by alliance N", `Spring.GameOver({ ally })` in a scenario, only a message in the editor. With `lives` = 0 the game does not end.
- **Wild units:** `wilds` units of Gaia, stage 1 of a random faction, at random places, health `wildHp` % (`SetUnitMaxHealth`). Every 3 s a wild unit without orders gets a move to a place up to 1500 Elmo away. A destroyed one comes back 10 s later somewhere else.
- **Computer teams:** a team without an active human player (`Spring.GetPlayerList(team, true)`, not a spectator) is steered: every 3 s (when its unit has no orders, and every 9 s anyway) a `CMD.FIGHT` to the nearest enemy player unit that is at most one stage above it, or to a wild unit that is much closer (distance² × 4 smaller).
- **Protection:** the unit of a player cannot self-destruct (`AllowCommand` refuses `CMD.SELFD`) or be given away (`AllowUnitTransfer`).
- **Display (unsynced):** a line per team at the top ("stage 3/10 Centurion   points 2/8   lives 2", "out"), the own team in white. When the own unit changes it is selected (`SelectUnitArray`); after a respawn the camera goes to it (`SetCameraTarget`).
- **State:** game rules `evoState`, `evoTeams`, `evoLives`; team rules (public) `evoStage`, `evoXp`, `evoNeed`, `evoLeft`, `evoOut`, `evoUnit`, `evoSpawn`, `evoName`. Every created unit has the unit rules parameter `led_nosave` (the editor does not save it).

## 2. Widget and page

- `led_evo.lua` returns a function; the widget loads it with the host services `Shared`, `S`, `say`, `serialize`, `disarmAll`, `excludeOthers`, `restrictStart` / `restrictStop`, `beforePlay` / `afterPlay`. Functions: `evo.layout`, `draw`, `press`, `height`, `payload`, `toggle`, `steps` (the row of points shown on the page), `cfg`, `lua`, and `finish` / `key` / `text` of `Shared.numberField`.
- Hooks in the widget as for `rtf`: header button EV (slot 12 of the button column, the attack and FX / FD buttons one row lower), panel size, title "Level Editor - Evolution", press, text and key input, `runningModes`, saving and loading (section `evolution`), `reloadBeforePlay`, `DebugEvo`.
- **Exclusive** with the other game modes: `evoon` switches Tower Defense, Capture the Flag and Reclaim the Fame off; ticking one of them switches Evolution off.
- `evo.payload()` refuses a level without a team with units.

## 3. Data and payload

Section `evolution` of the level file:

| Field | Meaning |
|---|---|
| `enabled` | the mode is on |
| `lives` | 0 to 99, default 3, 0 = unlimited |
| `respawn` | seconds, 0 to 600, default 5 |
| `wilds` | 0 to 300, default 20 |
| `wildHp` | percent, 1 to 100, default 10 |
| `first` | points from stage 1 to 2, 1 to 10000, default 3 |
| `factor` | percent, 100 to 400, default 160 |

Payload `lives;respawn;wilds;wildHp;first;factor` by message `evo|start|...` (`evo|stop`; only with cheats or in the editor) or the game option `evoconfig` (base64url; started at frame 30 through `G.gameMode`).

## 4. Scenario

`Read-Evolution` of the scenario builder; game option `evoconfig`; the computer teams get NullAI (the gadget steers them), the win condition runs as "no end" (`deathmode = neverend`: there are no commanders, the gadget decides), no grace period. A level with another mode on as well is refused. LAN Play treats it as human against human like Capture the Flag (`versus`: the joiner gets the other ally team, the AI of the opponent team is removed).

## 5. Not checked and open

Open: hovercraft and amphibious units in the ladders (left out for now), a balance of the factions on the same stage, own spawn points instead of random places, a minimap marker of the units.
