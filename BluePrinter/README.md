# BluePrinter

Widget for the official Beyond All Reason. Building blueprints are queued on the map as build plans.
Idle own builders nearby then get the build orders for them on their own.

Nothing in the game is changed and nothing is cheated: these are normal build orders (`GiveOrderToUnit`),
cost and build time apply as usual.

| Blueprints | Buildings |
|---|---|
| ![BluePrinter, Blueprints view](../docs/blueprinter-blueprints.jpg) | ![BluePrinter, Buildings view](../docs/blueprinter-buildings.jpg) |

## Installing
1. BAR must be installed (launcher started once).
2. Run `install_blueprinter.bat`. It copies `bluePrinter.lua` to `data\LuaUI\Widgets`, the shared code
   `shared/editor_common.lua` to `data\LuaUI\Include` and creates the junctions `data\LuaUI\Config\BluePrinter` -> `blueprints` and `data\LuaUI\Config\LevelEditorBlueprints` -> blueprints of the Level Editor (BAR only allows user widgets to write under `LuaUI\Config` and to read under `LuaUI`). An old junction `data\BluePrinter` is removed.
   The folder `shared` must lie next to `BluePrinter`.
3. In the game switch on "Allow user widgets" in the settings, then switch BluePrinter on in the widget list (F11).
After a change to `bluePrinter.lua` run the installation again.

## Blueprints
Files `<name>.lua` are read from `data\LuaUI\Config\BluePrinter` (that is from `BluePrinter\blueprints`) and from
`data\LuaUI\Config\LevelEditorBlueprints` (the blueprints of the Level Editor, if the folder `LevelEditor` lies next to `BluePrinter`). Only buildings are used,
units in a blueprint are skipped. The team in the blueprint does not matter, it is built for you.

## Usage
- Menu on the right (with `/bp_side left` to the left): click a blueprint in the list, then left click on the map = queue it
  (several times possible), right click ends. Green = free, red = blocked.
- The list shows thumbnails (buildings as unit pictures from above). With the large x at the top right of the tile
  (click twice) a blueprint goes to the trash (`_trash`).
- The tiles stand in a grid that grows from top to bottom: first a column with up to 4 tiles, then the next column (up to 3 columns), after that the mouse wheel scrolls (three times as fast).
- The small button **O** at the top right opens the settings: columns and rows of the grid (default 3 and 4) with - and +. They are stored in `LuaUI\Config\BluePrinterUI.lua` in the game folder.
- Drag a tile with the mouse button held down = sort (a yellow mark shows the place, the order is remembered).
  Double click on the name = rename (type, Enter accepts, Esc cancels).
- Ctrl+Alt+P (or `/bp_create`) = same as the button **Create Blueprint** at the top right of the title row.
- Button **Create**: the selected buildings are saved as `bp_001`, `bp_002` ... in `BluePrinter\blueprints`
  and made ready for placing right away.
- When placing, the widget shows the 3D models of the buildings in addition to the frames (semi-transparent, for large blueprints the 150 closest to the center). With `/bp_ghost` you check the mode (`gl` or `wg`, if the models are missing).
- A **search field** sits above the blueprint tiles (and in the building catalog): type words of the description or the code, the list filters at once (Enter = done, Esc or X = clear; sorting is off while searching). The lists have a **scrollbar** at the right edge.
- Rotate: the BAR keys `[` and `]` (build rotation), or Alt + mouse wheel (there is no button; the direction is shown in the status line).
- Blue = planned, yellow = a builder is working on it, red = blocked right now (tried again later). Every open plan also shows a semi-transparent 3D ghost of the building (the 150 closest to the mouse pointer if there are more).
- **Right click on a plan** with builders selected: exactly these builders build exactly this plan now (Shift = add it behind their current orders). Builders that cannot build it give a message; without a selected builder the click keeps its normal meaning.
- Buttons at the screen edge next to the menu: **V** collapse, **O** settings, **?** help, **A** auto-build on/off, **C** commanders help build yes/no (hover for a tooltip). In the menu: Back, Clear all and the radius field (builders react to plans within this radius; click the number to type one, or use - and +).
- Only builders that are idle and can build the building take part (e.g. no T2 buildings with a T1 builder).
  If a builder has several plans nearby, it gets up to four in a row. When all plans are taken,
  it helps with one in progress.
- Queued plans are kept when you quit the game, on the same map.

## Area attack (experimental)
Has nothing to do with the build plans; it only sits in the same menu. Select bombers, artillery, rocket launchers or nukes and press one of the buttons next to the menu: **XL** (a line), **XR** (a rectangle) or **XC** (a circle; drag from the center outwards). Then drag the shape on the map. Each unit gets its own target inside the shape: bombers approach it from the side where they stand, artillery and rockets fire at their target. Right click cancels. Also Ctrl+Alt+K (= XL) or `/bp_carpet [line|rect|circle]`.

## Chat commands
`/bp_menu` menu on/off (auto-build and radius are buttons in the menu), `/bp_rotate`, `/bp_undo`, `/bp_clear`, `/bp_com`, `/bp_side left|right`, `/bp_scan` (re-read the list), `/bp_create` (blueprint from the selection), `/bp_mode bp|units` (switch the view), `/bp_carpet`, `/bp_spacing <n|+|->`, `/bp_ghost [gl|wg|auto]` (state of the 3D preview).

## Note
Automatic building may count as automation in some ranked or tournament games. If in doubt, switch `Auto-build` off.

## Queueing single buildings
At the top of the menu use **Buildings** to switch to the catalog view: choose the faction (preselected by your builders) and the tech tier,
click a building, then every left click on the map queues one (right click ends, `[` and `]` rotate). Buildings that
your builders cannot build right now are dimmed (queueing works anyway). The builders work through them like all plans.
You set the display (columns/rows) with the **O** button.

## Shared code
The blueprint view (grid, dragging, renaming, trash, settings, 3D preview) comes from `shared/editor_common.lua`
and is the same as in the Level Editor.

## Help
The menu has a **?** button. It shows the keys and short explanations as a board on the screen; a click closes it.
