# Specifications

The specifications describe the **current state** of the code for whoever develops it further (in practice: the AI agent working on this repository). They are not manuals: the instructions for players are in the READMEs next to the programs and in `docs/`, and are not repeated here. Keep a specification up to date with every change. There is no backward compatibility to document: only what exists now.

Rules for writing and maintaining them are in `CLAUDE.md`. Sections are numbered inside each document only; documents refer to each other by file and heading, not by number.

## Documents

| Document | Content |
|---|---|
| [level-editor.md](level-editor.md) | the editor core: structure, keys, menus, strip and button column, editing, undo, placing, Generate, levels, gadget, files |
| [level-editor-setup.md](level-editor-setup.md) | setup and removal, the extra game, the start menu (keys 0–8), game start |
| [teams.md](teams.md) | ten teams, alliances, human / AI, start resources (button T) |
| [restrictions.md](restrictions.md) | what the player may not build, the R window |
| [tower-defense.md](tower-defense.md), [capture-the-flag.md](capture-the-flag.md), [reclaim-the-fame.md](reclaim-the-fame.md) | the three game modes of a level |
| [evolution.md](evolution.md) | the game mode Evolution of LAN Play (any map) |
| [renegade.md](renegade.md) | the game mode Renegade (first test): one unit per player in the first or third person, three mouse buttons for the weapons, the panel (cards, sorted by range, name from the picture, range / shots per second / damage / DPS), compass, speedometer, altimeter, list of the players, binoculars, the weapon table with its categories (39 pictures, sizes by tech level and damage per second, the generator `weapon_art_build.py`), the flight heights and bombs of aircraft, arc weapons and their preview, the turret angle, the smart weapon selection units (direct / vertical), the AUTO row of the anti-nuke launchers, anti-air lock, the switch to the normal game, the start script (all units, `quick`), debug menu, bots |
| [arena.md](arena.md) | the Arena tool (button A) |
| [scenario-builder.md](scenario-builder.md) | scenario info, the builder, `scenario.txt`, the extra game of the scenarios |
| [scenario-multiplayer.md](scenario-multiplayer.md) | console lobby, split screen, bundle and map transfer |
| [lan-play.md](lan-play.md) | the lobby widget for LAN Play |
| [blueprinter.md](blueprinter.md) | the BluePrinter widget |
| [shared-code.md](shared-code.md) | `editor_common.lua`, `bar_rules.lua`, `bar_common.ps1` |
| [testing.md](testing.md) | how changes are checked |

## Where things live

- Programs: `LevelEditor/`, `BluePrinter/`, `shared/`. Manuals: `README.md`, `docs/`, `LevelEditor/README.md`, `LevelEditor/game-modes/`, `LevelEditor/sandbox/`, `LevelEditor/scenario/README.md`, `BluePrinter/README.md`.
- Test tools and pitfalls: `LevelEditor/test-data/` (`README.md`, `TESTING.md`).
