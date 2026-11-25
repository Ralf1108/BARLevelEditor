# Tweaked units (tab Tweaks of the Place menu)

- A tweaked unit ("clone") is a placed unit of a normal type whose values are changed for that one unit: health, speed, costs, sight, weapons.
- The values come from a `tweakunits` text as BAR's game option of that name takes it (`{ armpw = { health = 2000 } }`), pasted in the editor.
- The unit definitions cannot change after the game has loaded, so there is no new unit type: the gadget sets the values of the single unit with the engine's functions.
- It works without a restart, in the editor and in a scenario built from the level, and it uses no game option of BAR (a `tweakunits` / `tweakdefs` option set in a lobby stays untouched and works next to it).
- User view: [Level Editor manual](../LevelEditor/README.md), "Tweaked units". Request: issue 5.

Related: [Level Editor](level-editor.md), [placing](level-editor-placing.md), [Scenario builder](scenario-builder.md), [Testing](testing.md).

## 1. Parts

| File | Role |
|---|---|
| `scripts\tweak_rules.lua` | pure Lua, shared by the page and the gadget (`luaui/Include/tweak_rules.lua` in both extra games): reading and writing a table, base64url, the fields a running game can change, `T.walk`, `T.check`, the help text `T.HELP` |
| `scripts\unit_tweaks.lua` | gadget in both extra games: the definitions, `GG.Tweaks.apply(unitID, id)`, the values, the game options of a scenario |
| `scripts\led_tweaks.lua` | the tab of the widget (`tw`): library, paste, list, rename, delete, arming, the boxes and Copy checked, the section of the level file, the names above the units |
| `scripts\unit_level_editor.lua` | carries the tweak of a unit through placing, loading, undo, redo, moving, rotating (`setTweak`, field `tweak` of the snapshot) |
| `scripts\led_level.lua`, `led_place.lua` | the level file (unit field `tweak`, section `tweaks`), copy and paste |
| `scenario\scenario_builder.ps1` | the game options `ledtweaks` and `ledtweakunits` |

## 2. The text (`tweak_rules.lua`)

- `T.parse(text)`: plain Lua (also with `return` in front) or the same in base64; a text without `{` is taken as base64.
  - base64: standard or url alphabet; padding `=` or `_` at the end is skipped (BAR writes `_`).
  - The text runs as `return <text>` in an empty environment (`setfenv`): it cannot call anything.
  - Keys are taken in lower case (as BAR's `lowerkeys`). Every entry must be `unitname = { ... }`.
  - Errors as text: a syntax error with its line; "this is program code (a tweakdefs text)" when the text compiles as statements but not as a table; "neither a Lua table nor base64".
- `T.serialize(t)`: Lua text with sorted keys (the same table gives the same text). Numbers through `T.numberText` (whole numbers without a point, others up to four decimals: the `%g` of the game's Lua writes six decimals).
- `T.encode64` / `T.decode64`: base64url without padding. The game's Lua computes with 32-bit floats: `encode64` stays below 2^24.
- `T.walk(base, tw, ud, weaponDefs, visitor)` goes through the tweak of one unit: `visitor.unit`, `.weapon` (with the weapon numbers of the unit that use the weapon definition `<base>_<name>`), `.damage`, `.ignored`, `.error`.
  - Page and gadget use the same walk, so what the page shows as applied is what the gadget sets.
- `T.check(...)`: the texts for the display: `applied` ("health 370 -> 2000"; the old value from `UnitDefs` / `WeaponDefs` where a getter knows it), `ignored`, `errors` (a value of the wrong type, an unknown unit).

### 2.1 Fields

| Field of the table | Engine call of the gadget |
|---|---|
| `health` (also `maxdamage`) | `SetUnitMaxHealth`, `SetUnitHealth` (full) |
| `speed`, `maxacc`, `maxdec`, `turnrate` | the data of the move type (`maxSpeed` and `maxWantedSpeed`, `accRate`, `decRate`, `turnRate`; ground, gunship or plane setter, through `pcall`) |
| `metalcost`, `energycost`, `buildtime` (also `buildcostmetal`, `buildcostenergy`) | `SetUnitCosts` |
| `sightdistance`, `airsightdistance`, `radardistance`, `sonardistance`, `radardistancejam`, `seismicdistance` | `SetUnitSensorRadius` (`los`, `airLos`, `radar`, `sonar`, `radarJammer`, `seismic`); `sightdistance` alone also sets `airLos` to 1.5 x |
| `workertime` | `SetUnitBuildSpeed` (build, repair, reclaim, resurrect, capture) |
| `metalmake`, `energymake` | `SetUnitResourcing` (`umm`, `ume`) |
| `mass`, `stealth`, `sonarstealth` | `SetUnitMass`, `SetUnitStealth`, `SetUnitSonarStealth` |
| `weapondefs.<name>.range`, `reloadtime`, `burst`, `burstrate`, `projectiles` | `SetUnitWeaponState` (`range`, `reloadTime`, `burst`, `burstRate`, `projectiles`); after a range change `SetUnitMaxRange` = the longest weapon that is no shield |
| `weapondefs.<name>.weaponvelocity` | `SetUnitWeaponState` `projectileSpeed` = value / 30 (per frame) |
| `weapondefs.<name>.accuracy`, `sprayangle` | `SetUnitWeaponState` `accuracy` / `sprayAngle` = sin(value x pi / 0xafff) |
| `weapondefs.<name>.areaofeffect`, `edgeeffectiveness`, `impulsefactor` | `SetUnitWeaponDamages` (`damageAreaOfEffect` = value / 2, `edgeEffectiveness`, `impulseFactor`) |
| `weapondefs.<name>.damage = { default = n, <armor class> = n }` | `SetUnitWeaponDamages` with a table by armor class number: a named class gets its value; `default` goes to every class that had the default damage before |

- Everything else is **ignored** and listed at the entry (yellow `!`): model, footprint, movement type, weapons of another kind, build options, `customparams`, explosions, wrecks; also a weapon the unit does not carry.
- An entry in which nothing can be applied is refused at paste.
- Checked in the game (`zz_tweak.lua`, Pawn): health 2000 (normal 370), range 500 (180), damage 50 (9), metal cost 10 (54), sight 900 (429), top speed x 2. Not checked in the game: acceleration, turn rate, accuracy, area of effect, the fields of aircraft.

## 3. Gadget `unit_tweaks.lua`

- `defs[id] = { name, base, tw }`; `unitTweak[unitID] = id`.
- `GG.Tweaks.apply(unitID, id)`: sets the public unit rules parameters `ledtweak` (the id) and `ledtweakname`, then the values (`applyValues`: only for a unit of the base type).
  - A unit whose definition is not known yet keeps the id and gets the values when the definition arrives.
- `GG.Tweaks.define(id, name, base, text)`: id of letters, digits and `_`; the base unit must exist; the text must hold an entry for it. A definition that is known again with the same table only renews the name of its units.
- **Editor:** the message `tweak|def|<id>|<name b64>|<base>|<table b64>` (`G.handleMessage`: only in the editor game or with cheats).
- **Scenario:** `GamePreload` reads the game options `ledtweaks` (`id,base,name b64,table b64;...`) and `ledtweakunits` (`id:x,z,x,z|id:...`), both base64url; at frames 5, 30 and 90 a unit of the base type within 10 of the place becomes the tweaked unit (each entry once, one unit).
- A definition that is known with another table (the entry was edited, 4.2): its units get the normal values of the old fields back (`T.normalOf`), then the new values. Editor only: in a scenario no message is taken.

## 4. The tab (`led_tweaks.lua`)

- Sub-tab **Tweaks** of the Place menu (`menuMode == "tw"`, fifth tab; two header rows like Recent; width 680 x S).
- **Paste tweakunits** (`twpaste`, `tw.paste(text)`; `Spring.GetClipboard`): every unit of the table becomes an entry (newest on top); the note says how many were added and how many fields are ignored.
- **Copy an example** (`twexample`, `tw.copyExample()`): `T.EXAMPLE` (a tweaked Pawn, several lines) goes into the clipboard (`Spring.SetClipboard`).
- **Yellow `!` at the top** (`twhelp`): its tooltip is `T.HELP` (what works, what does not, good to know).
- **A row:** the name with the picture of the base unit (`twarm`: arms it; tooltip = the changes), a yellow `!` when fields are ignored (`twwarn`, tooltip = the list), **Rename** (`twname`: type, Enter accepts, Esc undoes; letters, digits, space, `_ - . ( )`, at most 40), **Delete** (`twdel`, second click confirms).
  - Deleting only removes the entry from the library; placed units keep their values, and the level still saves their definition (`tw.known`).
- **Arming:** `host.armUnit(base)` (the normal unit stamp: painting, rows, rectangles, rotation, W) and `tw.armed = id`; `tw.placeSuffix()` gives `|0|0|<id>` for the `led|place` messages while the tab is open and the stamp is the base unit (otherwise an empty text).
- **Ids:** `<base>_<five random characters>`; fixed for the life of the entry (also when it is edited), a level refers to it.
- **Checked** (`pick = true` in the library file, `e.pick`): only for Copy checked (4.3); a level and a scenario take every entry.
- **Library:** `LevelEditor/_tweaks.lua` (the levels folder; files with `_` are internal): `{ id, name, base, b64 }` per entry, `b64` = the table of the unit in base64url.
- **Names on the map:** `tw.drawLabels()` (from `widget:DrawScreen`) writes the name above every tweaked unit in view (looked up once a second, at most 60).
- Test hooks: `widget:DebugTweaks()` returns `tw`; `widget:DebugLayout()` also returns the rectangles of the tab and of the open menu of a unit tile.

### 4.1 Copying the values of a unit (right click on a unit tile)

- A right click on a tile of the tab **Units** opens a menu at the mouse pointer (`panelPress` -> `tw.openUnitMenu(name, mx, my)`; `tw.menuRects` (kind `twmenu`), `tw.drawMenu` after the menu of the alliance colors, `tw.menuPress` first in `widget:MousePress`: every click closes it).
- A right click on an entry of the tab **Tweaks** (`tw.rightPress` -> `tw.openEntryMenu(id, mx, my)`): **Edit**, **Copy as tweakunits**, **Copy as tweakdefs** (the table of the entry).
- **Modify tweakunits** (value `modify`) and **Edit** (value `edit`) open the window of the values (4.2).
- **Copy as tweakunits** (`twcopy`, value `units`): `tw.unitText(name, "units")` = `T.pretty({ [name] = T.unitTable(...) })`, one field per line.
  - `T.unitTable(base, ud, weaponDefs)`: the fields of 2.1 with the values of `UnitDefs` / `WeaponDefs` (zero and false left out; `accuracy`, `sprayangle`, `impulsefactor` have no getter and are left out), the unit's own weapons (`<base>_<name>`, no shields) with `damage = { default = n }`.
  - Pasted again unchanged it gives an entry with nothing ignored.
- **Copy as tweakdefs** (value `defs`): `T.defsText(base, table)`: the same values as program code (`local u = UnitDefs["armpw"]`, `u.health = 370`, `u.weapondefs.emg.range = 180`), for BAR's game option; the paste of the tab refuses it as program code.
- The tab Recent has no such menu.

### 4.3 Copy checked (a text for BAR's lobby)

- A box (`twpick`, a tick when checked) before every entry; a click switches it and saves the library.
- Below the list: **Copy checked as text** (`twcopytext`) and **Copy checked as base64** (`twcopyb64`): `tw.copyChecked(kind)` -> `tw.checkedText(kind)`.
  - The table `{ [base] = e.tw }` of the checked entries in list order; text = `T.pretty` (one field per line), base64 = `T.encode64(T.serialize(t))` (base64url, as read by the paste and by BAR's game option `tweakunits`).
  - Two checked entries with the same base unit: nothing is copied, the note names both ("A tweakunits text holds one entry per unit type").
  - Nothing checked: nothing is copied, the note "Check an entry first".
- Every copy (`copy(text, what)`) reads the clipboard back; when Windows held it and the text did not arrive it writes once more, then says "The clipboard of Windows is busy: click again."
- The rule of one entry per unit type holds only for the copied text: the editor and a scenario allow several entries of one unit (the values go to each placed unit).

### 4.2 The window of the values (`tw.win`)

- `tw.openEditor(base, entry)`: a window in the middle of the screen; `entry` = nil from a unit tile ("Modify <unit>"), an entry of the list for "Edit '<name>'".
- **Rows** (`T.rows(base, ud, weaponDefs, tw)`): under the head "Unit" every field of `T.UNIT_ORDER`, then per own weapon (no shield) a head "Weapon <name>" with the fields of `T.WEAPON_ORDER` and `damage` (the default damage).
  - A row: label and key, "normal <value>", the value box (`twval`; yes / no button `twbool` for `stealth`, `sonarstealth`), an `x` (`twreset`) when the value is changed (yellow).
  - A weapon field the game does not tell (`accuracy`, `sprayangle`, `impulsefactor`) is a row only when the entry sets it.
  - 12 lines are visible; mouse wheel or scrollbar.
- **Typing:** a click on a box starts the entry (`tw.edit = { row, buf }`, `tw.editRowAt`): digits, `.` and `-`; Enter accepts, Tab accepts and goes to the next value, Esc undoes, a click elsewhere accepts.
- **The table** (`T.rowsTable(rows, tw0)`): the table of the entry (`tw0`; its fields without a row stay: ignored fields, damage per armor class) with the changed rows; a row with its normal value is left out (`T.rowChanged` compares the texts of the numbers).
- **Buttons:**

| Button | From a unit | From an entry |
|---|---|---|
| **Create clone** / **Create new clone** (`twclone`) | new entry "<unit> (tweaked)" on top of the list | new entry "<name> copy"; the edited entry stays |
| **Save** (`twsave`) | | the entry gets the table (same id), `tweak\|def` is sent again |
| **Copy** (`twwcopy`) | the changed values as a `tweakunits` text; nothing changed: all values | the same |
| **Reset all** (`twresetall`), **Close** (`twclose`, also Esc) | | |

- Create and Save close the window and open the Tweaks tab (`host.showTweaks()`); both refuse a table in which nothing can be applied ("Change a value first").
- **Save and the placed units:** the gadget (`define`) sees the known id with another table: every unit of the id first gets the normal values of the old fields (`T.normalOf`: unit fields, weapon fields, the damage of every armor class) and then the new values. Health is set to full.
- The window takes every click while it is open (`widget:MousePress`; `inPanel` is true, the wheel scrolls it); it closes when the menu is closed or folded.

## 5. Placing, editing, the level file

- `led|place|name|team|x|z|facing|neutral|indestructible|arena|<tweak id>` and `led|load|...|rec|indestructible|arena|<tweak id>`: the editor gadget calls `setTweak` after creating the unit.
- The snapshot of a unit holds `tweak` (from the rules parameter): undo, redo, moving, rotating and mirroring give the new unit the tweak again.
- Copy and paste keep the tweak (the clipboard). A **blueprint** file does not carry it: its units are placed as normal units.
- **Level file:** a tweaked unit line ends with `, tweak = '<id>'`; the section `tweaks = { { id = "...", name = "...", base = "...", b64 = "..." }, ... }` (before `requiredmodoptions`) holds every entry of the list (also entries without placed units, so that loading the level brings them back) and the definitions of the ids on the map (`tw.lua(used)`).
  - Loading: `tw.load(data.tweaks)` sends the definitions before the units and adds entries the library does not have.
- **Scenario builder:** `UNIT_RX` reads `tweak`, `TWEAK_RX` the section; units whose tweak has a definition for their type go into `ledtweakunits`, the used definitions into `ledtweaks` (an entry without placed units has no effect in the game, so it is left out of the game options). The extra game of the scenarios holds `unit_tweaks.lua` and `tweak_rules.lua`.

## 6. Limits

- Only placed units are tweaked: a unit of the same type built later by a factory is the normal one.
- The info of the game (tooltip, build menu) shows the name and mostly the values of the normal unit; the name of the entry is shown by the editor only (list, label above the unit), not in a scenario.
- The stockpile, the wreck and the radar icon are those of the base unit.
- An AI does not know about the changed values.

## 7. Tests

- `mock_tweaks.lua` (128 checks, no game): reading (plain, base64, padding, errors, program code), writing, applied / ignored / errors, the help text names every field, the values of a unit as text (`unitTable`, `pretty`, `defsText`, the example), the rows of the window (`rows`, `rowsTable`, `normalOf`), the gadget with a fake engine (message, each engine call, a waiting unit, an edited definition, the scenario options).
- `ps_test.ps1`, group "scenario_builder.ps1: tweaked units": the bundle of the level `test-data\levels\tweak_test.lua` has the two game options and the two files.
- `arena_test.ps1 -Widget zz_tweak.lua` (regression set, 62 checks): paste, refusals, arming, placing with a click, the values in the engine against a normal unit, move and undo, copy and paste, rename, save / clear / load, the test level, delete, Copy an example and the Paste button through the clipboard of Windows, the right click menu (both copy lines, pasted again, closed by a click), the window of the values (Modify: type a value, Copy, Create clone; Edit: Save changes the placed units, a value set back, Create new clone, Esc), Copy checked (nothing checked, as text, as base64 and pasted again, two entries of one unit refused, unchecked, kept in the library), every entry in the section of the level.
  - With `Set-Clipboard '{ armllt = { health = 4321 } }'` before the run it also checks that the Paste button takes a text put into the clipboard from outside (otherwise that check is skipped).
- `pve_test.ps1 -Tweaks -Quick -Widget zz_tweak_scn.lua` (regression set): the scenario game with the two game options; of two Pawns only the one at the place is tweaked.

## Tried and rejected

- **Real clones through BAR's `tweakdefs` option** (a copy of the unit under a new name): needs a restart of the editor for every new or changed clone, because definitions load only at the start. Kept as an idea for the fields a running game cannot change.
- **Applying `tweakdefs` texts:** they are program code on the raw definition tables, which do not exist in a running game; refused with a message.
- **An id from a self-made random number (multiply and modulo):** the game's Lua computes with 32-bit floats, every id came out as `<base>_00000`; `math.random` is used.
