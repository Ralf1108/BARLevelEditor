# BAR Level Editor

Tools for [Beyond All Reason](https://www.beyondallreason.info/) (BAR), a free real-time strategy game:

- **Build your own levels** on any map with the mouse and share them as ready-to-play scenarios.
- **Play in your home network** without an account, with new game modes.
- **Queue saved building layouts** in normal games.

![Level Editor: Place menu with units](docs/level-editor-place-units.jpg)

## What is in here

| Part | What it is | For whom | Status |
|---|---|---|---|
| [Level Editor](#level-editor) | build levels on any map, test them, export them as scenarios | level builders | stable |
| [Game modes](#game-modes-of-a-level) | Tower Defense, Capture the Flag, Reclaim the Fame for your levels | level builders and their players | stable |
| [LAN Play](#lan-play) | a battle room for computers in the same network | friends in one network | tested with two game instances on one computer |
| [Evolution](#lan-game-modes) | LAN game mode: one unit each, kills evolve it | LAN players | playable |
| [Renegade](#lan-game-modes) | LAN game mode: steer one unit from the inside, like a shooter | LAN players | experimental |
| [BluePrinter](#blueprinter) | blueprints for buildings in normal matches | every BAR player | stable |
| [Experimental Attacks](#experimental-attacks) | one order for many units over an area | every BAR player | experimental |

## Quick start (Windows)

You need Windows and Beyond All Reason, started once through its launcher.

1. **Get the files** (one of the two):
   - `git clone https://github.com/Ralf1108/BARLevelEditor.git` (update later with `git pull`)
   - or download [main.zip](https://github.com/Ralf1108/BARLevelEditor/archive/refs/heads/main.zip) and unpack it (update: download again)
2. **Install:** run `LevelEditor\install_editor.bat`.
3. **Start:** the desktop shortcut **BAR Level Editor**.
4. Optional, for normal games: run `BluePrinter\install_blueprinter.bat`.

| I want to ... | Do this |
|---|---|
| build a level | desktop shortcut **BAR Level Editor**, key `1` |
| look at a demo level | the same, key `2`, pick a `demo_*` level |
| play with friends in my network | start BAR, main menu > **LAN Play** |
| try Evolution alone | `LevelEditor\start_evolution.bat` |
| try Renegade alone | `LevelEditor\start_renegade.bat` |
| remove everything | `LevelEditor\uninstall_editor.bat`, `BluePrinter\uninstall_blueprinter.bat` |

## Level Editor

**Build**
- Units of all factions (Armada, Cortex, Legion, Scavengers, Raptors), trees, rocks and wrecks, with a 3D preview and a search
- Paint, rows, rectangles; copy, cut, paste, move, rotate, mirror; undo and redo for everything
- Generate random armies, turrets, air or ships, or a maze of walls
- Blueprints: save a selection and place the layout again anywhere
- Ten teams plus neutral, with alliances, human or AI per team and start resources

**Play it**
- Command the units of every team (cheat and god mode are switched on for you)
- An AI of your choice per team (BARb, CircuitAI, Simple AIs, Scavengers, Raptors)
- Restrict units, factions or tech levels for the player
- Test at once: single player, host, join or split screen

**Share it**
- Scenario builder: a level becomes a ZIP with briefing, AI opponents and win condition that others start with their own BAR

| Blueprints | Generate: units | Generate: maze |
|---|---|---|
| ![Place menu, Blueprints tab](docs/level-editor-place-blueprints.jpg) | ![Generate menu, Units](docs/level-editor-generate-units.jpg) | ![Generate menu, Maze](docs/level-editor-generate-maze.jpg) |

More: [Using the Level Editor](docs/level-editor-usage.md) (keys and controls) · [full manual](LevelEditor/README.md) · [Scenario builder](LevelEditor/scenario/README.md)

## Game modes of a level

Each mode has its own page in the editor, a test run and the export as a scenario.

| [Tower Defense](LevelEditor/game-modes/tower-defense.md) | [Capture the Flag](LevelEditor/game-modes/capture-the-flag.md) | [Reclaim the Fame](LevelEditor/game-modes/reclaim-the-fame.md) |
|---|---|---|
| [![Tower Defense page](docs/level-editor-tower-defense.jpg)](LevelEditor/game-modes/tower-defense.md) | [![Capture the Flag page](docs/level-editor-capture-the-flag.jpg)](LevelEditor/game-modes/capture-the-flag.md) | [![Reclaim the Fame page](docs/level-editor-reclaim-the-fame.jpg)](LevelEditor/game-modes/reclaim-the-fame.md) |
| Waves walk along a route you build; the player builds towers | Carry flags to your collection point and earn metal | Reclaim crystals for points; first at the score limit wins |
| ![Demo level Serpentine](docs/demo-tower-defense.jpg) | ![Demo level Crossroads](docs/demo-capture-the-flag.jpg) | ![Demo level Crystal Fields](docs/demo-reclaim-the-fame.jpg) |
| Demo level *Serpentine* | Demo level *Crossroads* | Demo level *Crystal Fields* |

- One demo level per mode comes with the editor (`LevelEditor\levels\demo_*.lua`, flat map Full Metal Plate): start menu key `2`.
- **[Arena](LevelEditor/sandbox/arena.md)** (a tool, not a mode): armies of up to ten teams stand around a point and fight each other. Choose units, count or budget, press Generate and Start.

| Arena page | Three armies after Generate |
|---|---|
| [![Arena page](docs/level-editor-arena.jpg)](LevelEditor/sandbox/arena.md) | ![Arena: three armies](docs/arena-lineup.jpg) |

## LAN Play

Play with computers in the same network: no account, no server in the cloud.

- A new entry **LAN Play** in the main menu of the game, below Multiplayer. The normal Multiplayer is not touched.
- It opens the normal battle room: map, options, AIs, teams, chat.
- **Host a LAN game**, or pick a game from the list that fills by itself, or type the host's address.
- A missing map and a scenario's game file are fetched from the host.
- Installed together with the Level Editor. Works in the local network or over a VPN (Tailscale, Hamachi).

The green button **LAN Play** in the title row of the room has the extras:

| Extra | What it does |
|---|---|
| **Custom Scenario** | the host picks a scenario built with the Level Editor; map and teams are set |
| **Copilot** | two or more people play **one** player together, e.g. one fights and one builds |
| **Evolution** | game mode, see below |
| **Renegade** | game mode, see below |

Also in LAN Play: play the Scavengers or Raptors yourself, Raptors against Scavengers, the Raptor Brood Chamber, rejoin after a crash, join a running game.

<img src="docs/lanPlay.png" alt="LAN Play: the menu entry on the left, Host a LAN game on the page" width="740">

More: [LAN Play](docs/lan-play.md)

### LAN game modes

Both run on any map, in LAN Play or alone with a start file.

| | [Evolution](LevelEditor/game-modes/evolution.md) | [Renegade](LevelEditor/game-modes/renegade.md) |
|---|---|---|
| Idea | every player has **one unit**; kills evolve it through 10 levels up to a tier 3 giant | you **are one unit**, seen from the inside: first or third person, like a shooter |
| Highlights | power-ups, regeneration, a gift and **Armageddon** at level 10 | W A S D drives, the mouse aims, three mouse buttons fire the weapons; aircraft, bombs, binoculars |
| Settings in the room | unit multiplier, unit health, regeneration, long range, all be gods | On / Off, Always in unit (or jump into any of your units with the key left of the 1) |
| Try it alone | `LevelEditor\start_evolution.bat` | `LevelEditor\start_renegade.bat` |
| Status | playable | experimental, not tested with several humans |

| Evolution in the game | Armageddon: the gift of level 10 |
|---|---|
| [![Evolution in the game](docs/evolution-game.jpg)](LevelEditor/game-modes/evolution.md) | ![Armageddon: the gift of level 10](docs/evolution-armageddon.jpg) |

Renegade tables you can change in Excel: [weapons and buttons](LevelEditor/game-modes/renegade-weapons.md) · [weapon categories and pictures](LevelEditor/game-modes/renegade-weapon-categories.md) · [cruise altitudes](LevelEditor/game-modes/renegade-cruise.md)

## BluePrinter

A small widget for the **official** game: blueprints in normal matches (buildings only).

- Queue blueprints and single buildings from a catalog as build plans, with a 3D ghost
- Idle builders and the commander help on their own, with normal costs and build times
- Select, remove, rotate and reorder plans; undo for every step
- Cost, build time and **Eco time** (how long your income needs to pay for it)
- Auto-build can be switched off (it may count as automation in ranked games)

| Blueprints | Buildings |
|---|---|
| ![BluePrinter, Blueprints view](docs/blueprinter-blueprints.jpg) | ![BluePrinter, Buildings view](docs/blueprinter-buildings.jpg) |

More: [Using the BluePrinter](docs/blueprinter-usage.md) · [full manual](BluePrinter/README.md)

## Experimental Attacks

Five buttons in the BluePrinter and in the Level Editor. Select armed units, press the button, drag the shape on the map.

| [Area attacks](docs/experimental-attacks.md#area-attacks-xl-xr-xc) | [Split attack](docs/experimental-attacks.md#split-attack-xs) | [Focus attack](docs/experimental-attacks.md#focus-attack-xf) |
|---|---|---|
| [![Area attack](docs/area-attack.jpg)](docs/experimental-attacks.md#area-attacks-xl-xr-xc) | [![Split attack](docs/split-attack.jpg)](docs/experimental-attacks.md#split-attack-xs) | [![Focus attack](docs/focus-attack.jpg)](docs/experimental-attacks.md#focus-attack-xf) |
| **XL**, **XR**, **XC**: spread the units over a line, rectangle or circle; every unit gets its own target | **XS**: spread the damage evenly over the visible enemies in a circle | **XF**: kill the enemies in a circle one after the other, the most dangerous first |

More: [Experimental Attacks](docs/experimental-attacks.md)

## How it works

- BAR runs on an engine that loads **Lua scripts**: *widgets* (what one player sees and clicks) and *gadgets* (rules of the game, the same on every computer).
- The setup packs the scripts of this repository into an **extra game** next to BAR. BAR's own files are not changed.
- The start files (`.bat`) and the menus are **PowerShell** scripts; they find your BAR folder by themselves.
- The BluePrinter is a single widget copied into BAR's widget folder, so it also works in official matches.
- After a BAR update or a `git pull` nothing has to be done: the start script rebuilds the extra game by itself.

## Repository layout

| Folder | Content |
|---|---|
| `LevelEditor/` | the editor: setup and start files, `scripts/` (widgets, gadgets, start menu), `game-modes/` (manuals and tables), `scenario/` (scenario builder), `lan_lobby/` (LAN Play), `levels/` (your levels, three demo levels) |
| `BluePrinter/` | the BluePrinter widget with its setup |
| `shared/` | code that the editor and the BluePrinter share |
| `docs/` | short manuals and pictures |
| `specs/` | specifications for development: how the code works now |
| `LevelEditor/test-data/` | test levels and test tools |

## Documentation

| Topic | Short | Full |
|---|---|---|
| Level Editor | [usage](docs/level-editor-usage.md) | [manual](LevelEditor/README.md), [scenario builder](LevelEditor/scenario/README.md) |
| Game modes | | [Tower Defense](LevelEditor/game-modes/tower-defense.md), [Capture the Flag](LevelEditor/game-modes/capture-the-flag.md), [Reclaim the Fame](LevelEditor/game-modes/reclaim-the-fame.md), [Arena](LevelEditor/sandbox/arena.md) |
| LAN Play | [LAN Play](docs/lan-play.md) | [Evolution](LevelEditor/game-modes/evolution.md), [Renegade](LevelEditor/game-modes/renegade.md) |
| BluePrinter | [usage](docs/blueprinter-usage.md) | [manual](BluePrinter/README.md), [experimental attacks](docs/experimental-attacks.md) |
| Development | [contributing](CONTRIBUTING.md) | [specifications](specs/README.md), [testing](specs/testing.md) |

## Problems

| Problem | Try this |
|---|---|
| "BAR not found" | start BAR once through its launcher, then run the start file again; it asks for the folder when it cannot find it |
| Something changed after an update | close the game completely and start again through the shortcut or the start file |
| The game ended with an error | the log is `infolog.txt` in the `data` folder of BAR |
| Players have different versions of LAN Play | `git pull` (or copy the folder) on all computers, then `LevelEditor\install_editor.bat` |
| Anything else | [open an issue](https://github.com/Ralf1108/BARLevelEditor/issues) with what you did and the `infolog.txt` |

Windows only for now. Not an official Beyond All Reason project.

## Other useful links

- [Map Generator](https://eclipseforeverbeyond.com/)

## AI assistance

- Most of the code and the documents in this repository were written with [Claude Code](https://claude.com/claude-code) (Anthropic)
- The maintainer designs the features, tests them in the game and decides what goes in
- Commits written with Claude carry a `Co-Authored-By: Claude` line. The working rules for the agent are in [CLAUDE.md](CLAUDE.md)
- If you send changes to the Beyond All Reason project itself, follow its AI policy (disclosure and testing by a human)
