# Screenshots of the README

Notes on what each picture shows, so they can be retaken after a change of the layout.

**Rules for all Level Editor pictures**
- They show the **whole widget**: the strip at the left of the menu (W, DL, DR, DC, L, R, S, N, teams, G), the menu, the button column at the right (V, O, I, ?, P, G, TD, XL, XR, XC, FX, FD) and, where the mouse pointer rests on a tile, the **3D preview** left of the strip with the **info lines** below the menu.
- Where it matters the picture also shows a part of the map with the result of the action (generated units, a maze, a corridor with route and towers, ...).
- Taken in a window of 3000 x 1500 pixels (isolated test instance, see below), cut to x 940 ... 3000, y 0 ... 1260 (the chat lines at the top left are part of the cut on purpose) and scaled to 1600 pixels width, JPEG quality 88.
- Map "Hooked 1.1", Armada, team 0 (the Capture the Flag picture uses the flat map "Full Metal Plate 1.7").

| File | Page and state |
|---|---|
| `level-editor-place-units.jpg` | Place, tab Units, Armada, Buildings, T1. Some buildings and bots standing on the map. Two units are forbidden (dimmed with a big red X); the small X marks in every tile and in the faction, group and tech buttons are the restrictions of the level. The pointer rests on the Energy Converter tile: 3D preview and info lines (cost, explosion). |
| `level-editor-place-blueprints.jpg` | Place, tab Blueprints with five blueprints (Defense Cluster, Wall Line, Factory Block, Mex Outpost, Solar Farm) with their cost; copies of three of them placed on the map; the pointer rests on Factory Block (3D preview and info). |
| `level-editor-generate-units.jpg` | Generate, sub-tab Units with Units and Turrets switched on, count 100, area Rectangle (pressed = armed). The result of a dragged rectangle: about 100 Armada units and turrets in the area (message about free space). |
| `level-editor-generate-maze.jpg` | Generate, sub-tab Maze, material Walls, corridor width 64, area Rectangle (pressed = armed). A maze built in a dragged rectangle (top-down view). Third picture under Features on the GitHub page. |
| `level-editor-tower-defense.jpg` | Tower Defense page: Tower Defense on (green), corridor of walls (Line, 128 Elmo) drawn with a bend, spawn point (green circle), three waypoints and the goal (red circle) with the yellow route line, three waves, Restrictions with Economy and Fog of war on, tower list (Armada, Towers, T1), a few towers placed, the pointer on the Ferret tile (3D preview, info). |
| `level-editor-capture-the-flag.jpg` | Capture the Flag page **while the test runs** (map "Full Metal Plate 1.7", flat; taken after Start test, cut to x 940 ... 3000, y 0 ... 1150): team 0 (blue) with two collection points on the left (thick rings) and three flag points, team 1 (red) with one collection point on the right and three flag points (thin rings); beside every flag three units of the other team (placed outside the capture radius, fire state hold fire); a blue tank has already taken a red flag and drives to a collection point (the pod follows it). The score line at the top shows 0/3 for both teams. |
| `level-editor-scenario.jpg` | Scenario page (button I) of a level with a battle: title "Hold the Plateau", roles, tech, AI, win condition, start resources, grace period 2:30, ID; the map shows the plateau and the Cortex base. |

The BluePrinter pictures (`blueprinter-blueprints.jpg`, `blueprinter-buildings.jpg`) show the BluePrinter in a normal game (window 3000 x 1800, cut to x 1000 ... 3000, y 60 ... 1460 and scaled to 1600 x 1120; map Hooked 1.1; five sample blueprints bp_001 ... bp_005, three of them queued with 18 open plans). The Buildings view has no red X marks: they belong to the Level Editor only. `area-attack.jpg` was not retaken (its layout did not change).

**How they were taken:** an isolated test instance of the game (own write folder, own settings with a framed window, own copy of the extra game) so the normal game stays untouched; a temporary widget set the scenes up through the widget (clicks on buttons and on the map) and took the screenshots. The scripts are not part of the repository.
