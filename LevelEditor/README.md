# Level Editor

[Start page](../README.md) · [Short version](../docs/level-editor-usage.md) · [Specification](../specs/level-editor.md)

Build a level on any BAR map with the mouse, test it and turn it into a scenario for the official game.

- Place units, buildings, trees, rocks and wrecks; generate armies and mazes.
- Make it a Tower Defense, Capture the Flag or Reclaim the Fame level.
- Every button has a tooltip; the **?** button shows all keys on the screen.

## Setup

| Step | What to do |
|---|---|
| Install | keep the folders `LevelEditor` and `shared` next to each other, close the game and its launcher, run `install_editor.bat` |
| Start | desktop shortcut **BAR Level Editor** (or `start_level_editor.bat`) |
| Update | nothing: the start checks the files and the BAR version and runs the setup by itself when they changed |
| Remove | `uninstall_editor.bat` (asks first; the game must not run) |

- The setup finds BAR by itself, builds an extra game next to the official one and installs **LAN Play**. The official game is not changed.
- Removing keeps your levels and blueprints. `-WithSettings` also deletes the settings of the editor, `-Yes` skips the question.
- What the setup creates in detail: [setup specification](../specs/level-editor-setup.md).

## Start menu

Arrow keys and Enter, or a digit key.

| Key | Action |
|---|---|
| **0** | continue the last map (saved every 2 minutes and when leaving) |
| **1** | new level: choose a map |
| **2** | load a level |
| **3** | build a scenario package (ZIP) from a level |
| **4** | start a scenario you built: single player, host, join or split screen |
| **5** | rebuild a scenario package from its level, without questions (after an update or a change of the level) |
| **6** | play a level at once: single player, host, join or split screen; no package is built |
| **7** | Scavenger and Raptor units in the Place menu on / off |
| **8** | clean up levels, scenarios and what came from other players |

- **Map list (key 1):** all BAR maps; a missing one is downloaded after you chose it. Type to search. A picture with size, players and terrain is shown; **Tab** and **Left / Right** filter.
- **Host / join (keys 4 and 6):** a lobby with a box per team. Move players with Tab, Enter and the arrow keys, then "Start game" or F5. A joiner only enters the address.
- **Split screen:** 2 to 8 players on this computer, one window each.
- **Joiners get what they need from the host:** the scenario and, in the same network, a missing map (otherwise it is downloaded).
  - A map from the host is checked against the official map list first.
  - Only game scripts are taken from the host, never programs that run on your computer.
  - The lobby version must be the same everywhere (first line of the start menu).
- **Key 7:** switched off, the game starts about 10 seconds faster. A level that holds such units switches them on by itself.
- **Key 8:** Space marks, A marks all of a kind, Enter removes after a question. Your own things go into a `_trash` folder; what came from others is deleted. Old things of other players also go by themselves (scenarios after 30 days, maps after 60 days or beyond 3 GB).

## The screen

In the editor everything is free and built instantly, and no cheat command is needed. Legion and the extra units are on.

- **At the start** only the commander stands there. **Ctrl+D** creates the builders of all factions at the mouse (tools, not saved in the level).
- **Menu:** drag the title row to move it, right click on the title puts it back. It follows the UI size of the BAR settings.
- **Right click** anywhere ends every mode (placing, delete, maze, generate, attack). Without a mode it is the normal order for the selected units.
- **Left click** on the ground clears the selection.

**Button column at the right edge**

| Button | Page or action |
|---|---|
| **V** | collapse the menu |
| **O** | settings |
| **S** | saved levels (save and load) |
| **I** | scenario info |
| **T** | teams: human or AI, alliance, start resources |
| **?** | help board |
| **P** / **G** | Place / Generate |
| **TD** / **CF** / **RF** | Tower Defense / Capture the Flag / Reclaim the Fame |
| **A** | [Arena](sandbox/arena.md) |
| **XL XR XC XS XF** | [experimental attacks](../docs/experimental-attacks.md) |
| **FX** / **FD** | make buildings in a rectangle indestructible / destructible again |

**Strip left of the menu**

| Button | Action |
|---|---|
| **W** | write: overwrite occupied spots (green) or leave them free |
| **DL** / **DR** / **DC** | delete along a line, in a rectangle, in a circle |
| **L** / **R** / **S** | rotate left / right, mirror (with a selection) |
| **N** | neutral |
| one per team | choose the team; shows its unit count |
| **G** | Gaia: no owner, enemy to everyone (at most 500 units; for many neutral units use **N**) |

**Teams**

- Ten teams (0 to 9), 3150 units each, 32,000 in all. Only teams 0 and 1 start with a commander.
- A click on a team button gives the selected units that team.
- A **right click** on a team button chooses its **alliance** (ten colors, shown as a frame): the same color = allies.
- Human or AI and the start resources: page **T**.

## Placing (button P)

Tabs: **Recent**, **Units**, **Features**, **Blueprints**.

- **Units:** choose faction (Armada, Cortex, Legion, Scavengers, Raptors), group and tech (T1 to T3), click a picture, left click on the map. Right click ends. **[** and **]** rotate.
  - Hovering shows a 3D view and the values: cost, **Eco time** (how long your income needs to pay for it), health, damage per second, range, sight, speed, radar.
  - A faction, group or tech button with nothing behind it is slightly red.
- **Features:** trees, rocks, wrecks and the crystals of Reclaim the Fame, placed like units.
- **Search:** one field for recent items, units, features and blueprints. All words must match. Enter = done, Esc or X = clear.
- **Crosshair button** (left of the search): click it, then a unit on the map: the list jumps to that unit.
- **Painting:** hold the left button and move.
- **Rows and rectangles:** **Shift + drag** = row, **Shift + Alt + drag** = rectangle. **Shift + wheel** changes the spacing.
- **W (write):** on = what is in the way is deleted (Ctrl+Z brings it back); off = nothing is placed on an occupied spot.
- **Range circles** before placing: red = weapon range, blue = line of sight.

Good to know:

- Air units appear in the air and keep flying.
- Nuclear silos start loaded (10 missiles) in the editor; a scenario built from the level starts with empty silos.
- **Scavengers and Raptors:** nobody steers them in a level; they stand until a player gives them orders. They need start menu **key 7** (about 10 s more loading).

**Restrictions (red X): what the player may not build**

- A small **X** on a unit picture restricts that unit (click again to allow it). The editor itself can always place everything.
- The X on a faction, group or tech button restricts all units behind it.
- The **R** button next to the search lists the restricted units; it is red when there is at least one.
- The list is saved with the level and works in every game mode and for every team.
- The Tower Defense page shows the same list.

## Blueprints

| Action | How |
|---|---|
| Create | select units, **P** > Blueprints > **Create** |
| Place | click a tile, left click on the map; right click ends |
| Choose with the wheel | **Ctrl + mouse wheel** on the map: next / previous blueprint |
| Sort | drag a tile and drop it elsewhere |
| Rename | double click on the name, type, Enter |
| Delete | small x on the tile, click twice (the file goes to `blueprints\_trash`) |

- A tile shows a preview, the name, the number of units and the total cost.
- Blueprints are files in the folder `blueprints`.

## Generate (button G)

For the team chosen on the left.

- **Units:** choose faction, type (units, buildings, turrets, air, ships), tech and count (1 to 2000), press **Rectangle** or **Circle** and drag the area. Random units appear in it.
- **Maze:** choose faction, material (dragon teeth or walls) and corridor width, press **Rectangle** or **Circle** and drag. Entrance top left, exit bottom right. Key **M** cycles the maze mode.
- The same button again or a right click ends it. Ctrl+Z undoes it.

## Selecting, editing, deleting

The editor switches on cheat and god mode, so you select and command units of **every** team like your own.

| Action | Keys |
|---|---|
| Select | click or drag a rectangle |
| Delete | **Del** (selection, or what is under the mouse); **DL / DR / DC** along a line, in a rectangle (key **D**), in a circle |
| Blow up (a wreck stays) | **Ctrl+B** |
| Copy / cut / paste | **Ctrl+C** / **Ctrl+X** / **Ctrl+V** (at the mouse, any number of times) |
| Move | **Alt + drag**, or the arrow keys (one grid step) |
| Rotate, mirror | **[** / **]** for a stamp, **L / R / S** for a selection |
| Undo / redo | **Ctrl+Z** / **Ctrl+Y**, for everything |
| Indestructible buildings | **FX** / **FD**, drag a rectangle |

- The shortcuts do not apply while you type in the chat or in a search field.

## Levels and settings

- **Ctrl+S** saves the level to `levels\<name>.lua`: units, features, the page of the game mode, restrictions, teams and the scenario info.
- **S** opens the list of saved levels (save, load, sort).
- **O** opens the settings:
  - **Grid:** 1 (free), 4, 8, 16, 32 or 64 Elmo.
  - **Unit limit** of the level: 500 to 32,000 (used by the scenario).
  - Columns and rows of the unit and blueprint views.
  - **Export Units Info** and **Export Comparison:** data files for a website that compares units (a separate project).
- **Help:** the **?** board. Chat commands for diagnosis: `/led_help`, `/led_clear` (clears the map).

## Game modes

A level can be one of three modes (ticking one switches the others off). Each has a page, a test run (**Start** / **Stop**) and becomes a scenario.

| Button | Mode | Idea |
|---|---|---|
| **TD** | [Tower Defense](game-modes/tower-defense.md) | waves of enemies walk a route to a goal; the player builds towers next to it |
| **CF** | [Capture the Flag](game-modes/capture-the-flag.md) | flags are carried to a team's collection point and earn metal |
| **RF** | [Reclaim the Fame](game-modes/reclaim-the-fame.md) | crystals pay points when reclaimed; first team at the score limit wins |

## Making a scenario

1. **I** (scenario info): title, author, summary, briefing (Shift+Enter = new line), win condition, grace period, ID.
2. **T** (teams): per team Human or AI, which AI, the alliance, start metal and energy.
3. **Ctrl+S** saves everything with the level.
4. Start menu **key 3**: choose the level; the builder asks only for title and name and writes folder and ZIP into `scenario\scenarios`.

- Only teams with units are part of a scenario.
- In Tower Defense every AI team is an enemy and the first AI team spawns the waves.
- Details: [Scenario builder](scenario/README.md).

## LAN Play

Installed with the editor: an entry **LAN Play** in the main menu of the game for games in your network. See [LAN Play](../docs/lan-play.md).

## For developers

- Which file does what: [specification of the editor](../specs/level-editor.md), [shared code](../specs/shared-code.md).
- All scripts are in `scripts\`; the list of what the setup installs is `scripts\editor_manifest.ps1`.
