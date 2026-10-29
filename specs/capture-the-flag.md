# Capture the Flag

Button **CF** (gadget `ctf_game.lua`, page `led_ctf.lua`). Flags lie at flag points; units pick them up, carry them to the collection point of their team and are paid. For human against human; nothing makes a computer opponent play it. Idea and open questions: issue 1 of the repository. User view: [Capture the Flag manual](../LevelEditor/game-modes/capture-the-flag.md).

## 1. Rules

- Flags lie at flag points; units pick them up (a mobile unit that is not a building, not Gaia, not being destroyed, within the capture radius) and carry them to a collection point of their alliance. Pay: `amount` metal per second for every flag that lies at a collection point, to the team that owns that collection point; nothing else (no one-time reward, no experience; a carried or stolen flag pays nothing).
- A flag with an owner team (`flags` entry with a team ≥ 0, "own flag") can be taken by units of other alliances; the owner's alliance only brings a dropped flag back to its flag point (and a delivered one back from a collection point of another alliance). A neutral flag (team -1, Gaia) can be taken by everybody.
- The delivered flag stays at the collection point (it is put on a ring of 60 Elmo around it; `f.parked`, `unpark`), where units of other alliances take it (`check`).
- A destroyed carrier drops the flag where it died; it goes back to its flag point only after `returnTime` seconds if that is above 0.
- Everything is counted **per alliance** (`allyOf`, [Teams](teams.md)): a carrier delivers at any collection point of its alliance (`g.homes[ally]`); allied teams do not take each other's flags; `g.score[ally]` = `g.parked[ally]` = the flags held at the collection points of the alliance (game rules `ctfScore<ally>`, `ctfTeams` = the alliances); the score line says "Alliance N" (or "group N" for an alliance of the editor).
- **Win:** an alliance that holds `score` flags at the same time wins (0 = never). `finish` blows up the units of every alliance that is not the winner (`blowUp`; flags and collection points stay). In a finished scenario `Spring.GameOver({ ally })`, in the editor only a message.
- **Lost alliance:** when all own flags (flags with an owner) of an alliance are parked at collection points of others, `eliminate` blows up all its units (`Spring.DestroyUnit(id, true)`, not the flags and collection points) and, every second, what the alliance built since. When only one alliance is left it wins ("last one standing"). Neutral flags do not count for this.
- The pod is not blocking (`SetUnitBlocking`: a blocking pod pushed the carrier into a zigzag).
- **Transports:** a flag or collection point cannot be loaded (`AllowUnitTransport`; `AllowCommand` refuses `CMD.LOAD_UNITS` on one). A transport that holds a flag carrier (loaded with it, or the loaded unit takes a flag on the way) is slowed down to the carrier speed (`slowTransport`, `UnitLoaded`) until it unloads it, the flag is delivered or lost, or the game stops (`unslowTransport`). The top speed of an aircraft is set with `Spring.MoveCtrl.SetAirMoveTypeData(maxSpeed)` (Elmo per frame), of other units through COB `MAX_SPEED`.

## 2. Widget

- `led_ctf.lua` returns a function; the widget loads it (`VFS.Include("luaui/Include/led_ctf.lua")`) and calls it with a `host` table (the services of the widget: `Shared`, `S()`, `say`, `canEdit`, `team()`, `serialize` (= `td.lua`), `disarm` (ends the other modes), `beforePlay` / `afterPlay` (save and restore `_beforeplay`), `excludeOthers`). It returns the page `ctf` (the widget keeps one local variable for it).
- Functions: `ctf.layout(rect)` (buttons, labels, height, also for `DebugLayout`), `ctf.draw`, `ctf.press`, `ctf.key`, `ctf.text`, `ctf.click(x, z)` (left click on the map in the pick mode `ctf.pick` = "home" | "flag"), `ctf.cancel`, `ctf.deleteAt` (Del), `ctf.grab` / `ctf.sample` / `ctf.endDrag` (Alt + drag moves a point, also with the page closed), `ctf.state` / `ctf.applyState` / `ctf.commit` / `ctf.poll` (undo, section 5), `ctf.pointAt`, `ctf.drawWorld` (rings), `ctf.toggle` (test), `ctf.payload`.
- Hooks in the widget as for `td`: header button (`kind = "ctf"`), size of the panel, title ("Level Editor - Capture the Flag"), drawing, press, map click and right click, text and key input, Del, mouse wheel, world drawing, the pick mode ended when another mode starts, save and load of the level.
- **Exclusive** with the other game modes: ticking `ctfon` calls `host.excludeOthers()` (switches Tower Defense and Reclaim the Fame off, with a message); ticking `tdon` or `rtfon` switches Capture the Flag off. All three can be off, never two on.

## 3. Data and page

Section `capture` of the level file (written by `saveLevel` through `td.lua`, read by `load_level` into `ctf.data`):

| Field | Meaning |
|---|---|
| `enabled` | the mode is on |
| `amount` | metal per second per flag, 0 to 99999, default 100 |
| `score` | flags to win, 0 to 99, default 3, 0 = never |
| `radius` | capture radius in Elmo, 10 to 2000, default 100 |
| `returnTime` | seconds, 0 to 3600, default 0 = the dropped flag stays |
| `speed` | top speed of a flag carrier in Elmo per second, 0 to 2000, default 50, 0 = no limit |
| `visible` | boolean, default true |
| `homes` | `{ team, x, z }`, as many as you like per team |
| `flags` | `{ team, x, z }`; team -1 = neutral = Gaia (chosen with G in the strip), otherwise the team chosen in the strip |

Neutral flags are units of the Gaia team, which has its own limit (500): with very many Gaia units in the level a neutral flag could not be created.

Page, top to bottom: checkbox `ctfon` (the switch of the mode); Places: `ctfhome` + X, `ctfflag` + X and two lines of what is placed; the box `ctfvisible`; Income: the field `amount`; the fields `score`, `radius`, `speed`, `returnTime` (`ctfedit`: click, type digits, Enter accepts, Esc cancels, limits as above); at the bottom `ctfplay`.

## 4. Gadget `ctf_game.lua`

- **Input:** payload `amount;radius;score;returnTime;speed;homes;flags;visible` (homes and flags as `team,x,z/team,x,z`; visible "1" or "0") by message `ctf|start|...` (`ctf|stop`; only with cheats or in the editor) or the game option `ctfconfig` (base64url, decoded by `decode64` of `bar_rules.lua`; the game starts at frame 30).
- **Units:** flags are real units (`lootboxsilver`, the silver pod of the scavengers), collection points are `lootboxnano_t1_var1`. Both are created neutral, with no selection, always visible (`Spring.SetUnitAlwaysVisible`, flags only with the option `visible`), indestructible (own protection: no damage, no reclaim, capture or self destruction), with the unit rules parameter `led_nosave` (the editor does not save them) and frozen with `Spring.MoveCtrl.Enable` (the pod is a drifting unit with speed 0.03). A flag with an owner is created for that team (its color), a neutral flag for the Gaia team.
- **Pick up:** every 5 frames (`CHECK_EVERY`) a flag that nobody carries is taken by the first mobile unit (not a building, not a Gaia unit, not a unit being destroyed) within the radius; a flag with an owner only by a unit of another alliance, a unit of the owner's alliance brings a dropped flag home. A flag at a collection point is taken by units of other alliances the same way.
- **Carrying:** a carried flag follows its carrier every frame (`SetUnitPosition` to the position plus one frame of the carrier's speed; air units and units in a transporter work, the position of a loaded unit is the one of its transporter).
- **Delivery:** a carrier within the radius of a collection point of its own alliance delivers: the flag stays there (put on a ring of 60 Elmo around the point), the alliance score rises, and every second the team that owns the point gets `amount` times the number of flags lying at that point (`AddTeamResource(team, "metal", ...)`).
- **Carrier:** while a unit carries a flag its weapons have the range 0 (`disarm` saves the ranges in the flag record, `rearm` puts them back on delivery or when the game stops). Speed: `disarm` saves `ud.speed` and calls `Spring.SetUnitCOBValue(unitID, COB.MAX_SPEED, speed * 65536 / 30)` when the unit is faster than the cap; `rearm` sets `ud.speed * 65536 / 30` again (`MoveCtrl.SetGroundMoveTypeData("maxSpeed")` has no effect). Air units and hovercraft are not checked.
- **Minimap:** the pods get `Spring.SetUnitNoMinimap`; the unsynced part draws a square per flag in the color of its owner (light grey: neutral) and a ring of the capture radius around every collection point over the minimap (`drawMiniMap`, from `DrawScreenPost` with `Spring.GetMiniMapGeometry`: BAR's minimap does not call `DrawInMiniMap` of gadgets). The flag ids come in `ctfFlagIds` ("id:owner,..."); with the option `visible` off a flag is only drawn when `GetUnitLosState` says los or radar (spectators see all).
- **Display:** game rules parameters `ctfState` ("", "running", "won by alliance N"), `ctfScore<ally>`, `ctfTarget`, `ctfTeams` (the alliances), `ctfOut` (lost alliances), `ctfVisible`, `ctfRadius`, `ctfHomes`, `ctfSpots`. The unsynced part draws the rings (`DrawWorldPreUnit`) and the score line (`DrawScreen`), so a finished scenario needs no widget.

## 5. Undo of the points

Like the route of Tower Defense: `ctf.state()` writes collection points and flag points as text ("t,x,z/t,x,z;t,x,z/..."; "-" for none); every change (`ctf.commit(before)`: click, Del, X buttons, end of a drag) sends `led|step` and `led|ctfpts|before|after`. The editor gadget records the operation `ctfpts` (with the unit steps, so Ctrl+Z / Ctrl+Y keep the order) and hands the state of an undo or redo back through the game rules parameters `led_ctfpts` / `led_ctfpts_n`, which `ctf.poll()` reads every frame. The settings (buttons, fields) are not part of the undo.

## 6. No capture of the pods

BAR's gadget `pve_supply_drops.lua` treats every unit with "lootbox" in its name as a lootbox: every 30 frames `NearbyCapture` adds capture progress for units of other teams within 1024 Elmo and at 1 hands the unit to the nearest enemy (`Spring.TransferUnit`). A commander next to a collection point took it within about 40 s.

- **Main fix:** the extra game replaces that gadget. The files of an extra game come before those of the game it builds on, so `luarules/gadgets/pve_supply_drops.lua` in the extra game (the text of `scripts\pve_supply_drops_stub.lua`: only `return false`) keeps the game's gadget from loading. The stub is packed into `LevelEditorMod.sdz` and into the extra game of the scenarios (it is in `$ScenarioGameFiles`). What is lost: the dropping of lootboxes by the game option `lootboxes` (off by default), only in these extra games; the official game is not changed.
- **Second line of defense in `ctf_game.lua`:** `AllowUnitTransfer` refuses every change of the team of a protected unit, and every 5 frames the capture progress of protected units is set back to 0 (`SetUnitHealth(id, { capture = 0 })`).
- Learned: `AllowUnitTransfer` is also asked when another gadget calls `Spring.TransferUnit`; the game's capture needs no command, so `AllowCommand` (refusing CAPTURE and RECLAIM) is not enough. Which of the game's gadgets act on a unit can be found by reading the game files: `data\packages\*.sdp` lists the files (name, md5) and `data\pool\<md5[0..1]>\<rest>.gz` holds the gzipped content.

## 7. Scenario

A level with Capture the Flag on becomes a scenario with the settings in the game option `ctfconfig` (teams renumbered like the units, a team with a collection point but without units is added). `ctf_game.lua` and `bar_rules.lua` are in the package and the starter builds them into the small extra game ([Scenario builder](scenario-builder.md)). The computer opponents get no AI (NullAI), the win condition is "no end" (the gadget decides). A level with another mode on as well is refused by the script.

## 8. Not checked and open

Not checked: the speed of air transports holding a flag carrier; air units and hovercraft as carriers. Open: a computer opponent that fetches flags; a pod that runs away from the carriers (idea).
