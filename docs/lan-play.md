# LAN Play

[Start page](../README.md) · [Level Editor](level-editor-usage.md) · [BluePrinter](blueprinter-usage.md)

Play with computers in the same network, no server in the cloud.

- Installed together with the Level Editor (game closed; TCP ports 8453 and 8452 between the computers)
- New entry **LAN Play** in the main menu, below Multiplayer
- **Host a LAN game** opens the normal battle room: map, options, AIs, teams, chat
- **Find LAN games** (or the address field and **Join**) joins another computer
- **Custom Scenario**: the host picks a scenario built with the Level Editor, the other players get it automatically

<img src="lanPlay.png" alt="LAN Play: the menu entry on the left, Host a LAN game on the page" width="740">

## Copilot

- Two or more people of a team play **one** player: one fights, one builds
- Host: button **Copilot**, click a player to give the next number of their team (console lobby: key **N**)
- The same number means the same player; the other players see the list read only

<img src="lanCopilot.png" alt="LAN room of the host with Custom Scenario, Copilot and the Copilot list" width="740">

## Status

- Prototype, tested with two game instances on one computer
- Capture the Flag, Reclaim the Fame, Tower Defense and Copilot ran through

Details: [LAN Play readme](../LevelEditor/lan_lobby/README.md)
