# BAR Level Editor

> **Note:** This project was created with the help of [Claude Code](https://claude.com/claude-code) (Anthropic's AI coding assistant). The code was written and tested together with it; please report anything that does not work as described.

A level editor for [Beyond All Reason](https://www.beyondallreason.info/). Place units, buildings, trees, rocks and wrecks on any map with the mouse, generate whole armies or mazes in one drag, save the result as a level and turn it into a ready-to-play scenario package.

| Place: units | Place: blueprints |
|---|---|
| ![Place menu, Units tab](docs/level-editor-place-units.jpg) | ![Place menu, Blueprints tab](docs/level-editor-place-blueprints.jpg) |

| Generate: units | Generate: maze |
|---|---|
| ![Generate menu, Units](docs/level-editor-generate-units.jpg) | ![Generate menu, Maze](docs/level-editor-generate-maze.jpg) |

The editor runs inside BAR as an extra game ("Level Editor") that builds on the official one. Everything is free and finished instantly, no `/cheat` needed. The official game is not changed.

This repository also contains **BluePrinter**, a small widget for normal games that queues saved building layouts as build plans, and the code both share.

## Features

- **Place** units of all factions (Armada, Cortex, Legion), features (trees, rocks, wrecks) and blueprints. A 3D preview follows the mouse; `[` and `]` rotate.
- **One search** over recent items, units, features and blueprints (words of the description or the unit code).
- **Rows and rectangles:** Shift + drag places a row, Shift + Alt + drag a rectangle; Shift + mouse wheel changes the spacing.
- **Blueprints:** select units, press *Create* and the layout is saved as a tile with a preview. Click a tile to place it again, drag tiles to sort them.
- **Generate:** random units, buildings, turrets, air or ships in a rectangle or circle (faction, tech level and count are up to you), or a **random maze** of dragon teeth or walls.
- **Copy and paste:** Ctrl+C / Ctrl+X / Ctrl+V, undo and redo with Ctrl+Z / Ctrl+Y, move with Alt + drag or the arrow keys, rotate and mirror selections.
- **Delete** along a line, in a rectangle or in a circle with the buttons `DL`, `DR` and `DC` (units, wrecks and features), or select enemy units too with Ctrl + click.
- **Area attacks (experimental):** the buttons `XL`, `XR` and `XC` send selected bombers, artillery, rocket launchers and nukes against a line, a rectangle or a circle; the bombers form up and attack together, front targets first. Good for trying out and for videos.
- **Teams:** pick the team (and "neutral") with the buttons next to the menu, with a live unit count per team. Up to 32,000 units.
- **Save and load** levels with Ctrl+S; the editor also autosaves when you leave.
- **Scenario builder:** turns a level into a ZIP with a start script, briefing, AI opponents and win condition that others can play with their own BAR install.

## Installation (Windows)

1. Install Beyond All Reason and start the launcher once.
2. Download or clone this repository. Keep the folders `LevelEditor` and `shared` next to each other.
3. Run `LevelEditor\install_editor.bat`. It finds your BAR installation, builds the extra game and creates a desktop shortcut **BAR Level Editor**.
4. Start the shortcut. In the start menu press `1` for a new level (choose a map), `2` to load a level, `0` to continue where you left off or `3` to build a scenario package.

After a BAR update run `install_editor.bat` again. `LevelEditor\uninstall_editor.bat` removes everything it installed (your levels and blueprints stay).

**What the setup does (Windows):** `install_editor.bat` starts the PowerShell script `install_editor.ps1` with `-ExecutionPolicy Bypass` (only for this script, your system setting stays untouched). It builds the extra game `LevelEditorMod.sdz` in your BAR `data\games` folder, creates folder junctions in the BAR data folder (`LevelEditor` and `LevelEditorBlueprints`, pointing to the `levels` and `blueprints` folders of this repository), writes `start_level_editor.bat` and puts a shortcut on your desktop. The official game files are not modified. Read the scripts first if you want to be sure; `uninstall_editor.bat` undoes everything. The editor needs the repository folder to stay where it is, because the junctions point to it.

**BluePrinter (optional, for normal games):** run `BluePrinter\install_blueprinter.bat`, then enable *Allow user widgets* in the game settings and switch **BluePrinter** on in the widget list (F11).

## Quick start

| | |
|---|---|
| Place a unit | Pick it in **Place → Units**, then left click on the map. Right click ends. |
| Place many | Arm a unit, feature or blueprint, then hold **Shift** and drag (a row) or **Shift + Alt** and drag (a rectangle); all of them are placed on release. **Shift + mouse wheel** changes the spacing, **[** and **]** rotate. |
| Random army | **Generate**, choose faction / type / tech / count and *Area*, press **Generate**, drag on the map. |
| Maze | **Generate → Maze**, choose the material, press **Generate**, drag on the map. |
| Delete | **Del** on the selection or under the mouse. For whole areas use the buttons at the right: **DL** (along a line), **DR** (in a rectangle, key **D**) or **DC** (in a circle), then drag the shape on the map. |
| Copy / cut / paste | **Ctrl+C** copies, **Ctrl+X** cuts (copies and deletes), **Ctrl+V** pastes at the mouse. |
| Undo / redo | **Ctrl+Z** undoes the last action (placing, deleting, moving, generating ...), **Ctrl+Y** redoes it. |
| Save a layout | Select units, **Place → Blueprints → Create**. |
| Save the level | **Ctrl+S** (settings button **O** lists and loads saved levels). |
| Help | The **?** button shows all keys and controls on screen. |

## Scenario creator

A level you built can become a **scenario** that others play with their own, unmodified Beyond All Reason:

1. Build the level (units, buildings, trees, wrecks, a maze ...) and save it with **Ctrl+S**.
2. Press the **I** button (button column at the right). Fill in the scenario info: title, author, summary, briefing (Shift+Enter = new line), the role of every team (player, allied AI, enemy AI), the allowed tech levels per team, the AI behavior, the win condition, start metal and energy, an optional grace period (no attacks for the first minutes) and an ID. The info is stored in the level with the next Ctrl+S.
3. Start **BAR Level Editor** again and press **3** in the start menu (*create a scenario package*), then choose the level. The script builds the package without further questions: `LevelEditor\scenario\scenarios\<id>.zip` (and the same as a folder).
4. Pass the zip on. The other person unpacks it, double-clicks `Start Scenario.bat` and plays with their own BAR installation (it asks before it downloads a missing map).

![Level Editor, scenario info (button I)](docs/level-editor-scenario.jpg)

Details are in the [scenario builder readme](LevelEditor/scenario/README.md).

## BluePrinter (for the official game)

Besides the Level Editor there is a second, much smaller widget for the **official** Beyond All Reason: **BluePrinter**. It brings the blueprints to normal games. It cannot place units directly (that is only possible in the Level Editor); it works with **buildings only**:

- **Blueprints** (the layouts saved in the Level Editor, or new ones made from your selection with *Create Blueprint*) and single buildings from a catalog are **queued as build plans** on the map. A 3D ghost and a number show every plan.
- **Your builders help on their own:** idle builders and the commander nearby take the plans and build them with normal build orders (cost and build time apply as usual, no cheat). Choose the radius, switch auto-build and the commander on or off with the buttons next to the menu, or send selected builders to one plan with a right click.
- Rows and rectangles (Shift), rotating, undo and a search field work as in the Level Editor. Because automatic building may count as automation in ranked games, auto-build can be switched off (button **A**).
- Experimental: the buttons **XL**, **XR**, **XC** send selected bombers, artillery and nukes against a line, a rectangle or a circle; the bombers form up first and attack together as a front.

| Blueprints | Buildings |
|---|---|
| ![BluePrinter, Blueprints view](docs/blueprinter-blueprints.jpg) | ![BluePrinter, Buildings view](docs/blueprinter-buildings.jpg) |

Install it with `BluePrinter\install_blueprinter.bat` (see the installation section) and read the [BluePrinter manual](BluePrinter/README.md).

## Documentation

- [Level Editor](LevelEditor/README.md) and its [specification](LevelEditor/SPECIFICATION.md)
- [Scenario builder](LevelEditor/scenario/README.md)
- [BluePrinter](BluePrinter/README.md)
- [Shared code](shared/README.md)

## Notes

- Windows only for now (the setup uses PowerShell and junctions).
- Not an official Beyond All Reason project.
