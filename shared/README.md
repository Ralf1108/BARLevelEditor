# shared

`editor_common.lua` is the shared code of the **Level Editor** and the **BluePrinter**:

- Blueprint library (read, sort, rename files, move them to the trash, write new blueprints)
- Tile grid for blueprints (drag to sort, double click to rename, x to delete, scrolling, search filter, name, count and total cost per tile)
- Unit catalog with a selection grid (faction, group, tech, sorting, name/description/cost) and the feature grid
- Search helpers (words of the code, name and description) and a scrollbar for the lists
- Settings (gear): columns and rows (and the grid and unit limit of the Level Editor), stored in a config file
- 3D preview of the models at the mouse pointer
- Area attack (line, rectangle, circle with bombers, artillery, rockets and nukes; the experimental buttons XL, XR, XC of both widgets)
- Helper functions (rotating, team color, scaling), the help board and the maze generator

A change here affects both widgets. Afterwards run `LevelEditor\install_editor.bat` and `BluePrinter\install_blueprinter.bat`:
they copy the file into the extra game and to `data\LuaUI\Include` respectively.

On a second computer the folders `shared`, `LevelEditor` and `BluePrinter` must lie next to each other.
