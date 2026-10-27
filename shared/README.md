# shared

`editor_common.lua` is the shared code of the **Level Editor** and the **BluePrinter**:

- Blueprint library (read, sort, rename files, move them to the trash, write new blueprints)
- Tile grid for blueprints (drag to sort, double click to rename, x to delete, scrolling, search filter, name, count and total cost per tile)
- Unit catalog with a selection grid (faction, group, tech, sorting, name/description/cost) and the feature grid; for the Level Editor optionally with the red X marks that forbid units (single units, factions, groups, tech levels)
- Search helpers (words of the code, name and description) and a scrollbar for the lists
- Settings (gear): columns and rows (and the grid and unit limit of the Level Editor), stored in a config file
- 3D preview of the models at the mouse pointer
- Area attack (line, rectangle, circle with bombers, artillery, rockets and nukes; the experimental buttons XL, XR, XC of both widgets)
- Helper functions (rotating, team color, scaling), the help board and the maze generator

`bar_rules.lua` holds the rules about unit definitions that gadgets and widgets need in the same way (`techLevel`, `buildClass`, `hitsGround`, `decode64`); `editor_common.lua`, the two gadgets of the Level Editor and the Tower Defense scenario load it (`VFS.Include("luaui/Include/bar_rules.lua")`), so both installers and the scenario starter pack it as well.

`bar_common.ps1` holds the shared parts of the setup scripts (Level Editor, BluePrinter, LAN Play) and of the scenario starter: finding BAR, the engine and the game version, creating and removing junctions. The scenario builder copies it into every scenario package.

A change here affects both widgets (and the gadgets for `bar_rules.lua`). The Level Editor updates its extra game by itself at the next start with `start_level_editor.bat`; for the BluePrinter in a normal game run `BluePrinter\install_blueprinter.bat` (the file is copied to `data\LuaUI\Include`).

On a second computer the folders `shared`, `LevelEditor` and `BluePrinter` must lie next to each other.
