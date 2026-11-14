# LAN Play

[Start page](../README.md) · [Level Editor](level-editor-usage.md) · [BluePrinter](blueprinter-usage.md)

Play with computers in the same network. No account, no server in the cloud.

## Play

- **Install:** comes with the Level Editor (close the game first).
- **Open:** new entry **LAN Play** in the main menu, below Multiplayer. Normal Multiplayer is not touched.
- **Host:** **Host a LAN game** opens the normal battle room: map, options, AIs, colours, teams, chat. Press Start when everybody is in.
- **Join:** games in your network show up in a list by themselves, a click joins. Or type the host's address and press **Join**.
- **Your name:** starts with your lobby name. Two players cannot have the same name in one game.
- **Leave LAN play** (shown while you host or play) brings you back to the normal lobby. **Close** only closes the page.
- **Who can join:** only computers of the local network, or of a VPN such as Tailscale or Hamachi.
- **Firewall:** it may ask once: allow it (ports 8453 for the lobby and 8452 for the game).

<img src="lanPlay.png" alt="LAN Play: the menu entry on the left, Host a LAN game on the page" width="740">

## Game modes

The host chooses them with the green button **LAN Play** in the title row of the room.

| Mode | How | What it is |
|---|---|---|
| **Official maps** | nothing to set | just play, like any room |
| **Custom Scenario** | **LAN Play** > **Custom Scenario** | a scenario built with the Level Editor: map and teams are set, all humans play the scenario's team together |
| **[Evolution](../LevelEditor/game-modes/evolution.md)** | **LAN Play** > **Evolution** > On | every player starts with one weak unit; kills evolve it through 10 levels; level 10 brings Armageddon |
| **[Renegade](../LevelEditor/game-modes/renegade.md)** | **LAN Play** > **Renegade** > On | every player steers one unit from the inside, like a shooter (experimental, not tested with several humans) |

- **Custom Scenario:** the other players get the scenario's game file automatically.
- **Evolution:** any map, best a small one (size M or smaller). Its settings: Unit multiplier, Unit health, Regeneration, Long range, All Be Gods, Debug mode.
- **Renegade** has two more settings:
  - **Always in unit Off:** you play the normal game and take over any of your units with the key left of the 1.
  - **Power-ups On:** beacons of five colors lie on the map; a unit that drives over one gets Sprint, Repair, Radar Pulse, Cloak or Jammer, used with the keys 1 to 5.

## In the room

| Feature | How |
|---|---|
| **Teams** | the buttons "N teams" and "N per team" work as on the official server: the players are spread over the teams and the start boxes of the map are used |
| **Copilot** | two or more people play **one** player, see below |
| **Boss** | menu of a player > **Make Boss**: the boss can change map and teams and press **Start** |
| **Join a running game** | the host types `!latejoin on` in the room chat before the start |
| **Rejoin** | after a crash: start the game, open **LAN Play**, join the room with the same name, press **Rejoin** |

- **Teams:** a map without start boxes gets left / right for two teams, corners for four, otherwise boxes round the middle.
- **Boss:** the game of a boss only starts when **every player has pressed Ready** (the room says who is missing). The host can always start.
- **Join a running game:** players who come later press **Rejoin** and join the team with the fewest humans, together with its players as in Copilot. They catch up with the game first.
- **Rejoin:** you come back to your team and catch up with the game.

## Copilot

- Two or more people of a team play **one** player: one fights, one builds.
- Host: **LAN Play** > **Copilot**, then click a player to give the next number of their team.
- The same number means the same player. The other players see the list read only.

<img src="lanCopilot.png" alt="LAN room of the host with Custom Scenario, Copilot and the Copilot list" width="740">

## Raptors and Scavengers

- **Played by humans:** add a Raptors or Scavengers computer to a team and put a human into the same team.
  - The computer only spawns (waves, beacons, queens as in the official game); the humans of the team command the units.
  - The room writes a message into the chat when the first human comes into such a team and when the last one leaves.
  - Alone in its team, the computer plays as in the official game.
- **Raptors against Scavengers:** a Raptors computer in one team, a Scavengers computer in the other, each with a human. Both play at the same time.
  - The official game refuses this combination; LAN Play plays with a changed copy of the game's files.
- **Raptor Brood Chamber:** with a Raptors computer in the room, the healers of the Raptors can build this nest. The humans of the Raptors team order raptors from it like from a factory (swarmers, healers, kamikazes, brawlers, spikers, artillery, scouts, fighters, bombers).
- All players need the same extra game of the scenarios (LAN Play fetches it like a scenario's game file).

## Same version for everybody

- When you join, your LAN Play is compared with the host's. If they differ, one message shows both version numbers and who is newer. You can still play.
- To get the same version: `git pull` on all computers, or copy the Level Editor folder to the other computers and run `install_editor.bat`.

## Missing map

- A map you do not have comes from the host over the LAN. It is checked against the list of official maps that the setup saved.
- If the map is not in the list or its checksum differs, a window asks: **From the host** or **Online**.
- The game starts for you when the map is there.

## Status

- Tested with two game instances on one computer: Capture the Flag, Reclaim the Fame, Tower Defense, Evolution, Copilot, scenario transfer, map transfer, version warning.
- Not tested yet: two real computers, three or more players.

Technical details: [LAN Play specification](../specs/lan-play.md)
