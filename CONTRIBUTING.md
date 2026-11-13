# Contributing

Thank you for helping. This page tells you how to report a problem and how to change something.

## Report a problem

- [Open an issue](https://github.com/Ralf1108/BARLevelEditor/issues) and say:
  - which part (Level Editor, LAN Play, Evolution, Renegade, BluePrinter)
  - what you did, what you expected, what happened
  - the map and the game mode
- Attach `infolog.txt` from the `data` folder of your BAR installation (it is written new at every start of the game).
- A screenshot helps (F12 in the game; the pictures are in `data\screenshots`).

## Change something

1. Read [README.md](README.md) for what the parts do and [specs/README.md](specs/README.md) for how the code works.
2. Change the code. The rules are in [CLAUDE.md](CLAUDE.md); the most important:
   - everything is English: texts in the game, comments, documents, file names
   - no names of persons in code, texts or file names
   - shared code goes into `shared/`
   - update the specification and the manual of what you changed in the same commit
3. Check it without the game:
   - `python LevelEditor\test-data\tools\lua_check.py` compiles every Lua file with Lua 5.1 (needs the Python package `lupa`)
   - `python LevelEditor\test-data\tools\mock_test.py` runs the tests of the shared modules
4. Check it in the game: [specs/testing.md](specs/testing.md) and [LevelEditor/test-data/README.md](LevelEditor/test-data/README.md) describe the sandbox tests.
5. Send a pull request with one topic. Say what you tested and how.

## Where things are

| Folder | Content |
|---|---|
| `LevelEditor/scripts/` | widgets and gadgets of the editor and of the game modes, the start menu |
| `LevelEditor/lan_lobby/` | LAN Play |
| `LevelEditor/scenario/` | the scenario builder and what goes into a scenario package |
| `BluePrinter/` | the BluePrinter widget |
| `shared/` | code used by several parts |
| `specs/` | specifications: the current state of the code |
| `LevelEditor/test-data/` | test levels and test tools |

## AI assistance

- Most of this repository was written with an AI coding agent; changes made that way are welcome.
- Say so in the pull request and test the change in the game yourself.
