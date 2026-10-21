# BAR Level Editor

> **Note:** This project was created with the help of [Claude Code](https://claude.com/claude-code) (Anthropic's AI coding assistant). The code was written and tested together with it; please report anything that does not work as described.

A level editor for [Beyond All Reason](https://www.beyondallreason.info/). Place units, buildings, trees, rocks and wrecks on any map with the mouse, generate whole armies or mazes in one drag, save the result as a level and turn it into a ready-to-play scenario package.

**Contents**

- [Features](#features)
- [Installation (Windows)](#installation-windows)
- [Quick start](#quick-start)
- [Scenario creator](#scenario-creator)
- [Tower Defense](#tower-defense)
- [BluePrinter (for the official game)](#blueprinter-for-the-official-game)
- [Experimental: area attacks (XL, XR, XC)](#experimental-area-attacks-xl-xr-xc)
- [Documentation](#documentation)
- [Notes](#notes)

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
- **Painting, rows and rectangles:** hold the left mouse button and move to place many (each one a whole footprint apart); Shift + drag places a row, Shift + Alt + drag a rectangle; Shift + mouse wheel changes the spacing. The button **W** decides whether placing overwrites what is in the way (default) or leaves occupied spots free.
- **Blueprints:** select units, press *Create* and the layout is saved as a tile with a preview. Click a tile to place it again, drag tiles to sort them.
- **Generate:** random units, buildings, turrets, air or ships in a rectangle or circle (faction, tech level and count are up to you), or a **random maze** of dragon teeth or walls.
- **Copy and paste:** Ctrl+C / Ctrl+X / Ctrl+V, undo and redo with Ctrl+Z / Ctrl+Y, move with Alt + drag or the arrow keys, rotate and mirror selections.
- **Delete** along a line, in a rectangle or in a circle with the buttons `DL`, `DR` and `DC` left of the menu (units, wrecks and features), or select enemy units too with Ctrl + click. `FX` / `FD` make buildings in a rectangle indestructible or destructible again.
- **Area attacks (experimental):** the buttons `XL`, `XR` and `XC` send selected bombers, artillery, rocket launchers and nukes against a line, a rectangle or a circle; the bombers form up and attack together, front targets first. The bombs and shots of all selected units are spread evenly over the chosen area.
- **Teams:** pick the team (and "neutral") with the buttons next to the menu, with a live unit count per team. Up to 32,000 units.
- **Save and load** levels with Ctrl+S; the editor also autosaves when you leave.
- **Scenario builder:** turns a level into a ZIP with a start script, briefing, AI opponents and win condition that others can play with their own BAR install (button **I** for the scenario info). Start menu key **3** builds it, key **4** starts a built scenario.
- **Tower Defense:** build your own tower defense levels: walls that guide the enemies, a route with spawn point, waypoints and goal, waves of enemies and rules for what the player may build. Test them in the editor and turn them into a scenario that others can play.

## Installation (Windows)

1. Install Beyond All Reason and start the launcher once.
2. Download or clone this repository. Keep the folders `LevelEditor` and `shared` next to each other.
3. Run `LevelEditor\install_editor.bat`. It finds your BAR installation, builds the extra game and creates a desktop shortcut **BAR Level Editor**.
4. Start the shortcut. In the start menu press `1` for a new level (choose a map), `2` to load a level, `0` to continue where you left off, `3` to build a scenario package or `4` to start one of the scenarios you built.

After a BAR update run `install_editor.bat` again. `LevelEditor\uninstall_editor.bat` removes everything it installed (your levels and blueprints stay).

**What the setup does (Windows):** `install_editor.bat` starts the PowerShell script `install_editor.ps1` with `-ExecutionPolicy Bypass` (only for this script, your system setting stays untouched). It builds the extra game `LevelEditorMod.sdz` in your BAR `data\games` folder, creates folder junctions in the BAR data folder (`LevelEditor` and `LevelEditorBlueprints`, pointing to the `levels` and `blueprints` folders of this repository), writes `start_level_editor.bat` and puts a shortcut on your desktop. The official game files are not modified. Read the scripts first if you want to be sure; `uninstall_editor.bat` undoes everything. The editor needs the repository folder to stay where it is, because the junctions point to it.

**BluePrinter (optional, for normal games):** run `BluePrinter\install_blueprinter.bat`, then enable *Allow user widgets* in the game settings and switch **BluePrinter** on in the widget list (F11). `BluePrinter\uninstall_blueprinter.bat` removes it again (your blueprints stay).

## Quick start

| | |
|---|---|
| Place a unit | Press **P** (Place) in the button column at the right, pick the unit in **Units**, then left click on the map. Right click ends. |
| Place many | Arm a unit or feature, then hold the left mouse button and move: one is placed after every footprint. Or hold **Shift** and drag (a row) or **Shift + Alt** and drag (a rectangle) for units, features and blueprints; all of them are placed on release. **Shift + mouse wheel** changes the spacing, **[** and **]** rotate. The button **W** (left of the menu) decides whether occupied spots are overwritten (default) or left free. |
| Random army | Press **G** (Generate) in the button column at the right, choose faction / type / tech / count and *Area*, press **Generate**, drag on the map. |
| Tower Defense | Click **TD** in the button column at the right (below P and G): build corridors (Single / Line / Free), set **Spawn**, **Waypoint**s and **Goal**, define the waves (factions, tech, type, count, gap, HP %) and the **Restrictions** for the player, then **Start test** at the bottom of the page. |
| Maze | **G → Maze**, choose the material and the corridor width, press **Generate**, drag on the map. |
| Delete | **Del** on the selection or under the mouse. For whole areas use the buttons in the strip left of the menu: **DL** (along a line), **DR** (in a rectangle, key **D**) or **DC** (in a circle), then drag the shape on the map. |
| Copy / cut / paste | **Ctrl+C** copies, **Ctrl+X** cuts (copies and deletes), **Ctrl+V** pastes at the mouse. |
| Undo / redo | **Ctrl+Z** undoes the last action (placing, deleting, moving, generating ...), **Ctrl+Y** redoes it. |
| Save a layout | Select units, **P → Blueprints → Create**. |
| Save the level | **Ctrl+S** (settings button **O** lists and loads saved levels). |
| Scenario | **I** (information) opens the scenario info: title, briefing, roles ... Then in the start menu **3** builds the package and **4** starts a built scenario. For Tower Defense click **TD** first (see below). |
| Help | The **?** button shows all keys and controls on screen. |

## Scenario creator

A level you built can become a **scenario** that others play with their own, unmodified Beyond All Reason:

1. Build the level (units, buildings, trees, wrecks, a maze ...) and save it with **Ctrl+S**. For a **Tower Defense** scenario click **TD** in the button column, tick *Tower Defense* and set up corridors, route, waves and restrictions (see [Tower Defense](#tower-defense)).
2. Click **I** (information) in the button column at the right. Fill in the scenario info: title, author, summary, briefing (Shift+Enter = new line), the role of every team (player, allied AI, enemy AI), the allowed tech levels per team, the AI behavior, the win condition, start metal and energy, an optional grace period (no attacks for the first minutes) and an ID. The info is stored in the level with the next Ctrl+S.
3. Start **BAR Level Editor** again and press **3** in the start menu (*create a scenario package*), then choose the level. The script first lists the **values stored in the level** (title, author, roles, tech, resources, ID, Tower Defense ...) and then asks for the **title** (Enter keeps it) and for the **name of the scenario** (its ID, taken from the level, or made from a new title): press Enter to take it or type another name (title and name are stored in the level as well); if a scenario of that name already exists it asks before overwriting it. Then it builds the package without further questions: `LevelEditor\scenario\scenarios\<id>.zip` (and the same as a folder).
4. Pass the zip on. The other person unpacks it, double-clicks `Start Scenario.bat` and plays with their own BAR installation (it asks before it downloads a missing map). A level with **Tower Defense** switched on becomes a Tower Defense scenario: the waves, the route, the build restrictions and the indestructible walls are packed as well (no grace period then; the starter builds a small extra game that only adds the wave script).

![Level Editor, scenario info (button I)](docs/level-editor-scenario.jpg)

Details are in the [scenario builder readme](LevelEditor/scenario/README.md).

## Tower Defense

Waves of enemy land units walk from a spawn point through waypoints to a goal; the player builds towers next to the route. Switch it on with the **TD** button (the page is called Tower Defense) and build the level on that page:

![Tower Defense page](docs/level-editor-tower-defense.jpg)

- **Corridor:** walls on both sides of a way, as single pieces (click or drag), along clicked points (*Line*) or freehand (*Free*), made of dragon teeth or walls, 32 to 192 Elmo wide. Corners are closed. The pieces are **indestructible**. What stands in the way is overwritten while **W** (left of the menu) is on.
- **Route:** *Spawn*, *Goal* and any number of *Waypoints*. A waypoint on the drawn line is inserted there, Ctrl + drag moves one, Del removes it. Everything can be undone with Ctrl+Z.
- **Waves:** per wave the factions, tech levels and types (vehicles, bots, hovercraft), count, gap in seconds and strength in percent. Every kill pays the unit's metal and energy. How many enemies may get through is set too: more and the level is lost, all waves beaten and it is won.
- **Restrictions:** what the player may build. Towers always; **Economy** (extractors, power plants, storage) and **Fog of war** (radars) can be switched on or off. Single towers get a red X and are forbidden, a red X on T1, T2 or T3 forbids every structure of that tech level. The player has no commander, the builders come from the level.
- **Start test** runs the waves in the editor; **Stop** brings the level back to the state before.
- **As a scenario:** a level with Tower Defense switched on becomes a Tower Defense scenario with everything above (see [Scenario creator](#scenario-creator)); the recipient's starter builds a small extra game that only adds the wave script.

Details are in the [Level Editor manual](LevelEditor/README.md#tower-defense) and the [specification](LevelEditor/SPECIFICATION.md).

## BluePrinter (for the official game)

Besides the Level Editor there is a second, much smaller widget for the **official** Beyond All Reason: **BluePrinter**. It brings the blueprints to normal games. It cannot place units directly (that is only possible in the Level Editor); it works with **buildings only**:

- **Blueprints** (the layouts saved in the Level Editor, or new ones made from your selection with *Create Blueprint*) and single buildings from a catalog are **queued as build plans** on the map. A 3D ghost and a number show every plan.
- **Your builders help on their own:** idle builders and the commander nearby take the plans and build them with normal build orders (cost and build time apply as usual, no cheat). Choose the radius, switch auto-build and the commander on or off with the buttons next to the menu, or send selected builders to one plan with a right click.
- Painting (hold the left mouse button and move), rows and rectangles (Shift), rotating, undo and a search field work as in the Level Editor. Because automatic building may count as automation in ranked games, auto-build can be switched off (button **A**).
- Experimental: the buttons **XL**, **XR**, **XC** send selected bombers, artillery and nukes against a line, a rectangle or a circle; the bombers form up first and attack together as a front.

| Blueprints | Buildings |
|---|---|
| ![BluePrinter, Blueprints view](docs/blueprinter-blueprints.jpg) | ![BluePrinter, Buildings view](docs/blueprinter-buildings.jpg) |

Install it with `BluePrinter\install_blueprinter.bat` (see the installation section) and read the [BluePrinter manual](BluePrinter/README.md).

## Experimental: area attacks (XL, XR, XC)

Three buttons in the button column at the right edge, in the Level Editor (below the page buttons P, G and TD) and in the BluePrinter, give you another kind of attack: they spread the bombs and explosive shots of all selected units evenly over the area you choose. With many units an area attack is awkward, because you can either bombard one single spot or give every unit its own order by hand. Here you select the units and say: distribute all bombs of all these units over this area. It works with bombers, artillery, rocket launchers and nuclear silos.

![Area attack: a circle is dragged, every unit gets its own target](docs/area-attack.jpg)

| Button | What it does |
|---|---|
| **XL** | Line (carpet attack): drag a line, every unit gets a piece of it. |
| **XR** | Rectangle: drag two corners, the units spread over the whole area. |
| **XC** | Circle: press at the center and drag outwards, the units spread over the circle. |

How to use it: select bombers, artillery, rocket launchers or nuclear silos, press one of the buttons (it lights up) and drag the shape on the map. A preview shows the shape, one frame per unit as its target and the approach lines; releasing the mouse gives the orders, a right click cancels. The **bombers form up side by side first** and, once all are in position, attack at the same moment as a front, with the front targets hit first; artillery, rockets and nukes fire at their own target in the shape. Nukes need loaded missiles. In the BluePrinter, Ctrl+Alt+K is the same as XL and `/bp_carpet [line|rect|circle]` works too.

## Documentation

- [Level Editor](LevelEditor/README.md) and its [specification](LevelEditor/SPECIFICATION.md)
- [Scenario builder](LevelEditor/scenario/README.md)
- [BluePrinter](BluePrinter/README.md) and its [specification](BluePrinter/SPECIFICATION.md)
- [Shared code](shared/README.md) and its [specification](shared/SPECIFICATION.md)

## Notes

- Windows only for now (the setup uses PowerShell and junctions).
- Not an official Beyond All Reason project.
