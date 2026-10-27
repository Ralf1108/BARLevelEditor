# BAR Level Editor

A level editor and a building helper for [Beyond All Reason](https://www.beyondallreason.info/) (BAR). Build levels on any map with the mouse, turn them into ready-to-play scenarios, and queue saved building layouts in normal games.

![Level Editor: Place menu with units](docs/level-editor-place-units.jpg)

## Level Editor

**Build**
- Place units of all factions (Armada, Cortex, Legion, Scavengers, Raptors), trees, rocks and wrecks, with a 3D preview and a search
- Paint, rows and rectangles; copy, cut, paste, move, rotate, mirror; undo and redo for everything
- Delete along a line, in a rectangle or in a circle; make buildings indestructible
- Generate random armies, turrets, air or ships, or a random maze of walls and dragon teeth
- Blueprints: save a selection as a tile and place the layout again anywhere
- Up to 32,000 units, 11 teams plus neutral, a live unit count per team

**Play it**
- Select and command units of every team, with the cheat and god mode switched on for you
- An AI of your choice for every team (BARb, CircuitAI, Simple AIs, Scavengers, Raptors)
- Restrictions: forbid units, factions or tech levels for the player
- Test a level at once: single player, host, join or split screen

**Share it**
- Scenario builder: a level becomes a ZIP with briefing, AI opponents and win condition that others start with their own BAR
- LAN Play: host and join games in the same network, with Copilot (two people play one player)

| Blueprints | Generate: units | Generate: maze |
|---|---|---|
| ![Place menu, Blueprints tab](docs/level-editor-place-blueprints.jpg) | ![Generate menu, Units](docs/level-editor-generate-units.jpg) | ![Generate menu, Maze](docs/level-editor-generate-maze.jpg) |

## Game modes

Three modes, one per level, each with its own page, a test run and export as a scenario:

| [Tower Defense](LevelEditor/game-modes/tower-defense.md) | [Capture the Flag](LevelEditor/game-modes/capture-the-flag.md) | [Reclaim the Fame](LevelEditor/game-modes/reclaim-the-fame.md) |
|---|---|---|
| [![Tower Defense page](docs/level-editor-tower-defense.jpg)](LevelEditor/game-modes/tower-defense.md) | [![Capture the Flag page](docs/level-editor-capture-the-flag.jpg)](LevelEditor/game-modes/capture-the-flag.md) | [![Reclaim the Fame page](docs/level-editor-reclaim-the-fame.jpg)](LevelEditor/game-modes/reclaim-the-fame.md) |
| Waves walk along a route you build; the player builds towers | Carry flags to your collection point and earn metal | Reclaim crystals for points; first at the score limit wins |

## BluePrinter

A small widget for the **official** game that brings blueprints to normal matches (buildings only):

- Queue blueprints and single buildings from a catalog as build plans, with a 3D ghost and a number
- Idle builders and the commander help on their own, with normal costs and build times
- Select, remove, rotate and reorder plans; a new placement replaces plans below it; undo for every step
- Painting, rows, rectangles and search as in the Level Editor
- Cost, build time and **Eco time** (how long your income needs to pay for it) of every building and blueprint
- Auto-build can be switched off (it may count as automation in ranked games)
- Area attacks (XL, XR, XC): spread the bombs and shots of many units evenly over a line, rectangle or circle *(experimental)*

| Blueprints | Buildings |
|---|---|
| ![BluePrinter, Blueprints view](docs/blueprinter-blueprints.jpg) | ![BluePrinter, Buildings view](docs/blueprinter-buildings.jpg) |

## Installation (Windows)

1. [Download the repository as a ZIP](https://github.com/Ralf1108/BARLevelEditor/archive/refs/heads/main.zip) and unpack it (or clone it). Start Beyond All Reason once through its launcher.
2. Run `LevelEditor\install_editor.bat`, then start the desktop shortcut **BAR Level Editor**.
3. Optional, for normal games: run `BluePrinter\install_blueprinter.bat`.

## Documentation

- **[Using the Level Editor](docs/level-editor-usage.md)**: installation details, keys and controls, scenario builder, game modes
- **[Using the BluePrinter](docs/blueprinter-usage.md)**: installation, what it does, area attacks
- **[LAN Play](docs/lan-play.md)** and Copilot
- [Level Editor](LevelEditor/README.md), [Scenario builder](LevelEditor/scenario/README.md), [LAN Play](LevelEditor/lan_lobby/README.md), [BluePrinter](BluePrinter/README.md)
- Game modes: [Tower Defense](LevelEditor/game-modes/tower-defense.md), [Capture the Flag](LevelEditor/game-modes/capture-the-flag.md), [Reclaim the Fame](LevelEditor/game-modes/reclaim-the-fame.md)
- Specifications: [Level Editor](LevelEditor/SPECIFICATION.md), [BluePrinter](BluePrinter/SPECIFICATION.md), [shared code](shared/SPECIFICATION.md)

Windows only for now. Not an official Beyond All Reason project. Created with the help of [Claude Code](https://claude.com/claude-code); please report anything that does not work as described.
