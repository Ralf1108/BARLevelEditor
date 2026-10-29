# Teams: alliances, human or AI, start resources

Button **T** (page `led_teams.lua`) and the team strip at the left of the menu. User view: [Level Editor manual](../LevelEditor/README.md) (Making a scenario from it).

## 1. Ten teams

- The editor game always has ten teams (0 to 9, `choose_map.ps1`, `Write-StartScript`), each in its own ally team of the engine. Only teams 0 and 1 keep their start commander; the gadget removes the ones of teams 2 to 9 in the first frames.
- `maxunits` 32000 is shared by the teams: 3150 units per team and 500 for Gaia (the engine fixes Gaia's limit; `Spring.GetTeamMaxUnits`). A level with more than 3150 units of one team cannot be built; for many neutral units use N (neutral) instead of Gaia.
- A team belongs to a scenario only when it has units (the editor's builders and Gaia do not count), when it is the spawner of a Tower Defense level, or when it has a collection point of Capture the Flag.

## 2. Data per team

Section `teams` of the level file (read with `knownFields`, no other place holds it):

| Field | Meaning |
|---|---|
| `group` | alliance: 0 = none, 1 to 10 = one of ten colors |
| `ai` | `""` = a human, else the name of an AI: `NullAI`, `BARb`, `CircuitAI`, `CircuitAI easy`, `SimpleAI`, `SimpleDefenderAI`, `SimpleConstructorAI`, `ScavengersAI`, `RaptorsAI` |
| `metal`, `energy` | start resources, default 1000 each |

Defaults: team 0 is a human, every other team is an AI with `NullAI` (it does nothing), nobody has a group, so everybody is an enemy of everybody.

## 3. Alliances in the editor

- The engine cannot move a team into another ally team, so the widget sends the groups to the gadget (`led|teams|g0,...,g9`, `GG.LedGroups` in `unit_level_editor.lua`) and the gadget sets the alliances between the ally teams with `Spring.SetAlly(a, b, true/false)`: two teams are allied when both have the same group (> 0), else they are enemies. Allied teams do not shoot each other. The groups are applied on every change and after loading a level.
- In the gadgets one function gives the alliance of a team: `G.allyOf(team)` in `led_gadgets.lua` (with `G.teamsOfAlliance`, `G.allianceList`, `G.allianceName`). In the editor it is `100 + group` (from `GG.LedGroups`); a team without a group is its own alliance (its ally team of the engine); in a scenario the ally team of the engine. Tower Defense, Capture the Flag and Reclaim the Fame use it. The widget side: `tm.group(t)`, and `tm.player()` (first human team, default 0) / `tm.enemy(player)` (first AI team, default 1 or 0)  for the Tower Defense payload.

## 4. Strip at the left of the menu

See [Level Editor](level-editor.md), "Strip at the left". Alliance related:

- A **right click** on a team button opens a small menu with the ten colors and "none" (the AI and the human are chosen on the page T).
- Every team button is drawn as: outer frame in the color of the group (none: no frame), a thin black border, inside the team color with the number. The chosen team is shown by the full color inside (the others are dimmed) and a bright number. The tooltip names group, human or AI and the start resources.

## 5. Page T

Button **T** in the button column (between I and ?; same panel as the page I, `scenarioPage = "teams"`). One row per team 0 to 9 with the columns:

- **Team**,
- **Human / AI** (a click switches; a new AI is NullAI),
- **AI** (the name; a click opens the list of the AIs above; "-" for a human),
- **Alliance** (a click opens the same color menu),
- **Start metal** and **Start energy** (numbers, click and type).

Teams without units are shown too (gray), so AI and alliance can be set before units are placed. The page and the strip show the same data. The page I (scenario info) keeps title, author, summary, briefing, win condition, grace period and ID ([Scenario builder](scenario-builder.md)).

## 6. The AI

- The editor game starts with the AI of team 1 (`Read-Level` gives `Ai1` from the section `teams`, without an entry NullAI) and ignores the others; the choice of all teams is used by the scenario.
- No AI can be given to a team during the game: the engine command `aicontrol` is refused by the server (`player 0 not allowed to use /aicontrol`, also with cheats on), BAR has no Lua call to start a Skirmish AI. So the AI is chosen before the start (`[ai]` in the start script). A running game cannot change an AI.
- **Tower Defense:** all teams that are an AI are enemies; the first AI team (lowest number) spawns the waves (`enemyTeam` of the payload); every human team is a player. The spawner is part of the scenario even without units. The enemy AI stays NullAI (the gadget moves the units along the waypoints).
- **Capture the Flag and Reclaim the Fame** use the AI that is set. It does not know the modes and will not fetch flags or reclaim crystals; an own AI would have to be written.

## 7. Scenario builder

`Read-Teams` in `scenario_builder.ps1` reads `teams`:

- Teams = those with units, plus the Tower Defense spawner and the teams with a collection point.
- A team with `ai = ""` has no `[ai]` section in `scenario.txt` (a human; the lobby puts the players in). A team with an AI gets the `[ai]` section (BARb and CircuitAI version `stable`, NullAI `0.1`, `CircuitAI easy` with `[Options] profile=easy`) or, for the Lua AIs, `LuaAI=<name>;` in the `[team]` section (`Get-AiSpec`). BARb has only its default profile.
- Teams with the same group get the same `allyteam`, a team without a group its own.
- The start resources are written as `StartMetal` and `StartEnergy` of the `[team]` section (open: whether the engine takes them from the team section; BAR also reads the game options `startmetal` / `startenergy`; if the keys are ignored, the largest values of the teams go into the game options).

## 8. Files

`led_teams.lua` (data, page, menu, frames; a function that gets the host, like `led_arena.lua`); the message `led|teams` and `GG.LedGroups` in `unit_level_editor.lua`; `led_gadgets.lua` (`G.allyOf` and the other alliance functions); `led_td.lua` (`td.payload`: player = first human team, enemy = first AI team, start resources of the player); `scenario_builder.ps1` (`Read-Teams`); `choose_map.ps1` (`Read-Level`).

## 9. Not checked

The start resources per team in a real scenario game; several humans in one scenario in the lobby; allied armies and enemies in a real fight; Capture the Flag and Reclaim the Fame with allied teams to the end.
