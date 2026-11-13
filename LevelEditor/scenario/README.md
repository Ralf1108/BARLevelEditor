# Scenario builder

[Start page](../../README.md) · [Level Editor](../README.md) · [Specification](../../specs/scenario-builder.md)

Turns a saved level of the Level Editor into a scenario that anyone can play with the **official Beyond All Reason**.

- The result is a folder and a ZIP that you pass on.
- Nothing in the official game is changed: the starter builds a small extra game "Level Editor Scenarios" next to it.

## Build a scenario

1. Save the level in the Level Editor (**Ctrl+S**).
2. Start menu of the Level Editor, **key 3**: choose the level.
3. The builder shows the values stored in the level and asks for the title and the name (ID). Enter keeps them.
4. The result: `scenarios\<id>\` and `scenarios\<id>.zip`.

Where the values come from:

| Value | Set where |
|---|---|
| Title, author, summary, briefing, win condition, grace period, ID | button **I** in the editor |
| Human or AI per team, which AI, alliances, start resources | button **T** in the editor |
| Game mode and its settings | pages **TD**, **CF**, **RF** |
| Restricted units | the X marks of the Place menu |

- Everything is stored in the level file, so the next build needs no answers.
- Only teams with units take part.
- An existing scenario of the same name is overwritten only after a question.
- **Change something later:** change it in the editor, save, then key 3 again, or **key 5** to rebuild a package without questions.
- By hand: `powershell -File scenario_builder.ps1` (asks everything); for tests `-Level name -Auto`.

## Play it (for the recipient)

1. Install BAR and start it once.
2. Unpack the ZIP anywhere.
3. Double-click `Start Scenario.bat`.

- The script finds BAR (or asks for the folder) and asks before it downloads a missing map.
- Without internet the map must be installed already.

## Several players

Every package has `Host Game.bat` and `Join Game.bat`. In the Level Editor, start menu key 4 offers **Single player**, **Host**, **Join** and **Split screen**.

**Lobby of the host:** a box per team; everybody who joins lands in a box.

| Key | Action |
|---|---|
| `Tab` / `Shift+Tab`, `Left` / `Right` | next box (the last stop is "Start game") |
| `Up` / `Down` | player in the box |
| `Enter` on a player | pick the player up, move with the arrow keys, `Enter` drops, `Esc` puts back |
| `N` | give the player the next player number of their team |
| `F5`, or `Enter` on "Start game" | start (at least two players) |
| `Esc` twice | cancel |

- **Copilot:** humans with the same number in a team play **one** player together: all give orders to its units and share its resources.
- **Joiner:** enters only the address (the last 10 are offered) and a name.
- **Start:** every computer gets ready (extra game, map), then the host's game starts and the joiners connect. The game begins 15 seconds after the host has loaded.
- **Split screen** (start menu only): 2 to 8 players on this computer, one window each; you distribute the teams in the same lobby.
- **Remembered** per user: the last addresses, your name and who played which team.
- **Needed:** the same BAR version and the same scenario on every computer; in the firewall of the host TCP port 8453 (lobby) and UDP port 8452 (game).
- **Same network only:** a VPN like Tailscale, ZeroTier, Hamachi or WireGuard counts; a connection from outside is closed.
- Tested so far only on one computer. Details: [multiplayer specification](../../specs/scenario-multiplayer.md).

## What a game mode brings into the scenario

| Mode | Needed in the level | In the package | Who wins |
|---|---|---|---|
| **Tower Defense** | spawn point, goal, at least one wave | everything of the page TD: waves, route, enemies allowed through, restriction to towers, fog of war, indestructible walls | all waves beaten = won; too many through = lost |
| **Capture the Flag** | at least one flag point and one collection point | the settings of the page CF | the first team that holds the wanted number of flags (0 = never) |
| **Reclaim the Fame** | at least one crystal | the settings of the page RF; the crystals are features of the level | the first team at the score limit (0 = never) |

- The modes exclude each other: a level file with two of them on is refused.
- **Capture the Flag and Reclaim the Fame** are made for human against human: the computer opponents get the AI of page T, but none of them plays the mode. The single player start is for trying the level out.
- **Tower Defense notes:**
  - the enemy team gets no AI; the waves come from the game mode
  - the start commander of the player is removed when the waves start, so the level needs builders
  - there is no grace period
  - a level with only one team gets an extra enemy team for the waves
- **Restrictions:** restricted units are greyed out in the build menu of the player and their build orders are refused.

## Good to know

- **Scripts in the package:** it holds a copy of everything it needs, so people without the Level Editor can play it. Started from the start menu of the editor (key 4), the current scripts of the editor run instead: an old scenario never goes out of date.
- **Grace period:** until it ends no side can leave its start area and each is safe from damage there. The areas are made from where the units of each side stand.
- **Nuclear silos** start empty in a scenario (the editor loads them only for testing).
- **Wrecks** can be resurrected by resurrection bots; heaps cannot.
- **Gaia units** (button G) are enemies to everyone and have no AI.
- **Builders made with Ctrl+D** in the editor are tools and not part of the level.
- **Unit limit:** taken from the level (editor settings, default 32,000).
- **Briefing:** shown at the start and with the button "Mission" (`/briefing` opens it again).

## What is in the package

| File | Content |
|---|---|
| `Start Scenario.bat` | double-click start |
| `Host Game.bat`, `Join Game.bat` | start for several players in the same network |
| `scenario.txt` | the start script: teams, allies and enemies, AIs, game options, the units |
| `README.txt` | briefing and instructions |
| `*.ps1` | starter, lobby and the search of BAR |
| `*.lua` | the scripts of the extra game: game modes, restrictions, briefing |

How the package is built and what each script does: [scenario builder specification](../../specs/scenario-builder.md).
