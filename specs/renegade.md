# Renegade

A planned game mode of LAN Play: every human player steers **one original BAR unit in the first person** (mouse look, WASD, crosshair, left mouse button fires), the others do the same in the same world. Named after the C&C Renegade idea: the units of a real-time strategy game, played as a shooter. Status: **concept and proof-of-concept plan, nothing is implemented yet.** This document is the working spec; it grows with each proof-of-concept step. Related: [Evolution](evolution.md) (one unit per player, same lobby and gadget pattern), [LAN Play](lan-play.md).

## 1. Goal and rules of thumb

- One human = one unit of the original game (first test unit: Peewee, `armpw`). Models, speed, weapons, range, armor and damage stay as they are; no new projectiles, no own damage system. The engine keeps doing movement, collision, weapons, projectiles and damage; Lua only sends the intent (where to go, where to look, whether to fire).
- Local things stay local (camera, mouse, crosshair, HUD: a game widget); everything that changes the game state goes through the synchronized gadget (`SendLuaRulesMsg` -> `RecvLuaRulesMsg`), so every computer simulates the same game.
- Scaling target (long term, not promised): test 1 -> 2 -> 4-8 -> 20-40 players, measure network load, latency, sim rate and desyncs before going further. Hundreds of players are explicitly not a goal of the proof of concept.

## 2. Parts (planned)

| Part | File (planned) | Job |
|---|---|---|
| Game widget | `renegade.lua` (`luaui/widgets`) | camera on the unit's eye, mouse look, key capture, crosshair/HUD, screen ray, sends input |
| Gadget | `renegade_game.lua` (`luarules/gadgets`) | player -> unit assignment, validates input, moves the unit, aims and fires, death/respawn, rules |
| Lobby | `lan_lobby.lua` | later: button + game option `lanrenegade=1` like `lanevolution` (adds a `LAN_VERSION` bump) |

Both files are listed in `$ScenarioGameFiles` (`shared/bar_common.ps1`) and `editor_manifest.ps1` once they exist. Test start: `pve_test.ps1`-style sandbox with a game option `lanrenegade=1` (same pattern as `-Evo`).

## 3. What the engine offers (checked)

Checked 2026-11-10 by looking for the function names in the installed engine (`spring.exe`, Recoil 2026.07.04; names found, behaviour and signatures still to be tested in the game):

- **Camera:** `Spring.SetCameraState`, `GetCameraState`, `SetCameraTarget`, `GetCameraPosition`, `GetCameraDirection`, `SetCameraOffset`, and the camera controller named `fps` (`FPSController`) are present. Plan A: try `SetCameraState({name = "fps", ...})` and log what comes back; plan B: own camera, set position and direction every draw frame (`free`/`ta` state with px, py, pz, rx, ry, rz).
- **Mouse:** widget callbacks `MousePress`, `MouseRelease`, `MouseMove` (with dx, dy), `Spring.WarpMouse`, `Spring.SetMouseCursor`, `GetMouseState`. Plan: keep the cursor in the middle (warp back each frame, cursor "none") and take yaw/pitch from dx/dy. The widget returns true from `MousePress` so the RTS does not select or order; `KeyPress` returns true for W, A, S, D (and others) for the same reason.
- **Screen ray:** `Spring.TraceScreenRay(x, y, ...)` (unit or ground hit under the crosshair); `Spring.TraceRay...` functions exist too. Open: does the ray hit the own unit (then hide it with `Spring.SetUnitNoDraw`, local only, or skip it).
- **Own unit hidden/visible:** `Spring.SetUnitNoDraw` (local) for the first-person view; the model of others stays.
- **Moving (synced):** `Spring.GiveOrderToUnit` (`CMD.MOVE`, `CMD.STOP`, `CMD.ATTACK`), `Spring.MoveCtrl.*` (full control, bypasses the movement type), `Spring.SetUnitVelocity`, `SetUnitDirection`, `SetUnitRotation`, `SetUnitHeadingAndUpDir`, `SetUnitPhysics`, `SetMoveTypeData` are present.
- **Aiming and firing (synced):** `Spring.SetUnitTarget` (ground position or unit, as user target), `GiveOrderToUnit(CMD.ATTACK, {x, y, z})`, `SetUnitFireState`, `SetUnitWeaponState`, `SetUnitMaxRange`, `CallCOBScript` / `SetUnitCOBValue` for unit scripts. No `SetUnitWeaponTarget` was found by that name; `SetUnitTarget` is the candidate.

## 4. Approaches per topic

**Camera.** Eye position = unit position + eye height (from the unit definition: `height`, or the aim point `Spring.GetUnitPosition(id, true, true)`), looking along yaw/pitch of the player. Camera set in `Update`/`DrawWorldPreUnit` so it follows without lag. Hide the own model (`SetUnitNoDraw`) or put the eye in front of it.

**Mouse and keys.** Only active when the player has a unit and the mode is on; a toggle key gives the RTS camera back (needed for testing and for spectators). Yaw/pitch are widget state only; they go to the gadget as numbers (see below).

**Movement (decision open).** Candidate 1, **move orders**: the widget sends the wish direction (WASD relative to yaw), the gadget gives `CMD.MOVE` to a point 150-300 Elmo ahead, re-issued a few times a second, `CMD.STOP` when no key. Respects the movement class, pathfinding, collision and slopes; deterministic; feels laggy and turns the unit toward the goal. Candidate 2, **velocity control** (`MoveCtrl` / `SetUnitVelocity`): immediate and strafing is possible, but the gadget must do collision, terrain following and movement-class limits itself, and the behaviour differs for kbots, vehicles, hovercraft and aircraft. PoC 2 starts with candidate 1 for kbots, then measures; candidate 2 only if 1 is too sluggish.

**Aim and fire.** The widget sends yaw and pitch; the gadget works out the ground point (or unit) under the crosshair and calls `SetUnitTarget`/`CMD.ATTACK` with it while the button is held, so the original weapon, turret turn speed, reload and damage apply. Known limits to test: the weapon only turns as fast and as far as its script allows (Peewee torso), range and firing arc cut off shots, a unit that walks sideways does not face the target. If a weapon cannot follow, the fallback must still use the original weapon logic (e.g. the unit's own heading follows yaw).

**Syncing the view.** Only small integer messages: `ren|<yaw*?>|<pitch>|<keys>|<fire>`, sent when something changes, at most about 15 per second per player; the gadget keeps the last values per player and applies them every few frames. Messages are checked: the sender must own the unit.

## 5. Proof of concept steps

| Step | Content | Done when |
|---|---|---|
| PoC 1 | Camera: pick the test unit, put the camera on its eye and follow (local, no gadget). Try the `fps` controller first, log its state; else own camera | stable first-person picture while the unit is moved by normal orders |
| PoC 2 | Mouse and movement: yaw/pitch from mouse, WASD moves the unit (gadget with move orders), RTS input suppressed | walk around with mouse look, no selection boxes or camera scrolling |
| PoC 3 (done) | Crosshair and screen ray: crosshair in the middle, the ray's hit (ground point / unit) shown as debug text | the shown hit matches what the crosshair points at |
| PoC 4 (done) | Fire: left button -> target to the gadget -> original weapon fires at the crosshair point | shots land at the crosshair, damage is the game's own |
| PoC 5 | Two players (LAN test with host + 1 joiner): each steers one unit, they shoot each other | both screens show the same fight, no desync |

PoC 1 to 4 are implemented, see the last section.

## 6. Later: jumping (noted, not planned in detail)

A shooter has jump and hop. The engine has no jump key for ground units; ideas to try later: a short synced hop with `Spring.SetUnitVelocity` (upward speed, gravity does the rest; for kbots and vehicles the movement type may overwrite it), or `Spring.MoveCtrl` for the duration of the jump only (position by our own ballistic curve, back to normal movement on landing), or the unit scripts (`CallCOBScript`) for the animation. To decide: how the engine's ground movement reacts to a velocity impulse, how to detect landing, whether the weapon may be fired in the air, and whether jumping stays deterministic. The input message would get a key bit (Space = 16).

## 7. Not in the first prototype

Hundreds of players, own lobby/matchmaking/dedicated server, new weapons/projectiles/damage model, all unit types (aircraft, ships, hovercraft need their own control model), full HUD, sound, animation and progression systems. Respawn and teams will reuse the Evolution pattern (start position, death -> new unit after a delay).

## 8. Open questions

- Is the `fps` camera state usable from a widget and tied to a unit, or must the own camera be used?
- Can the mouse be fully captured (cursor hidden and kept in the middle, also at the window edge)?
- Does `TraceScreenRay` hit the own unit, and how does it behave with the changed camera?
- How well does a move-order based WASD feel, and how does the unit's heading relate to the view yaw?
- Can a weapon follow an arbitrary aim point fast enough, and what does the hold-fire/fire-state interplay look like?
- Traffic and determinism of the input messages with many players.
- What the lobby/team setup needs (one unit per human, no commander, no building).

## 9. Implemented and measured (PoC 1 to 4)

Files: `LevelEditor/scripts/renegade.lua` (widget), `renegade_game.lua` (gadget), both in `$ScenarioGameFiles`. Tests: `pve_test.ps1 -Ren -Widget zz_ren.lua -Map "Hooked 1.1"` (lines `[zzren]`; PoC 1 and 2), `-Ren -RenTest -Widget zz_ren3.lua` (PoC 3 and 4), `-Ren -Widget zz_ren4.lua` (the ray in a full turn, fire at the sky; the features near the start: Hooked has a gravestone `corstone` 40 Elmo in front of the start point), `zz_cam.lua` (which camera states take a direction).

- **Gadget:** with `lanrenegade=1` every team with a human and a commander gets an `armpw` instead (frames 30-300; team rules parameter `renUnit`, public). The widget's message `ren|<yaw>|<pitch>|<keys>|<fire>` (`RecvLuaMsg`, sender's team must own a unit; keys W 1, A 2, S 4, D 8) is stored; `steer` gives `CMD.MOVE` to a point 200 Elmo ahead in the wished direction (forward `(sin yaw, cos yaw)`, right `(-cos yaw, sin yaw)`), again after 10 frames or when the direction turns by more than 6 degrees, `CMD.STOP` when no key is down. No `MoveCtrl`. `fire` is only stored (PoC 4).
- **Camera:** the engine camera `fps` works from a widget, set every frame by `Spring.SetCameraState({name = "fps", mode = 0, oldHeight = 0, px, py, pz, rx, ry, rz}, 0)`. **The direction comes from `rx` and `ry`, not from `dx, dy, dz` (ignored):** `rx = pi/2 - pitch` (pi/2 horizontal), `ry = pi - yaw` (our yaw 0 looks along +z, 90 along +x). Without `mode`/`oldHeight` the engine fell back to the `spring` camera in one run. Measured: `GetCameraDirection` equals the wanted direction (yaw 0/90/45, pitch 0/20/-10). Switching by name to `free`, `ta` or `spring` did not take over (name stayed `fps`). Eye = `GetUnitViewPosition` + 0.85 x `GetUnitHeight` (Peewee: 26 -> 22.1 above the base); the own model is hidden with `SetUnitNoDraw` (a picture shows ground, crosshair and the minimap view cone; the unit panel still shows the unit).
- **Mouse:** `Spring.GetMouseState` + `Spring.WarpMouse(middle)` each frame; the difference is the turn (0.15 degrees per pixel; y is from the bottom: mouse up = look up, mouse right = yaw down). Measured: the warp lands exactly, one frame later yaw and pitch are as expected. `MousePress`, `MouseRelease`, `MouseWheel` and the keys W A S D return true while the view is on (RTS does not react; not yet checked by hand with a real mouse). Insert (or `/renegade`) switches back and forth, `/renegade log` writes the camera state, `/renegade flip` turns the yaw offset by 180 degrees.
- **Movement:** W with yaw 0 / A with yaw 90 / S with yaw 270 moved the unit the right way (north-south 211 and 327 Elmo in about 4 s of game time at speed 4); the stop works (speed 0). At the start position of Hooked (map edge, x = 10) the first W was blocked (8 Elmo), a second try elsewhere worked; an S after A took a detour (cliffs near the edge): pathfinding decides, as expected for move orders.
- **Crosshair and screen ray (PoC 3):** four short lines in the middle (`DrawScreen`) and, under it, what the ray hits: `Spring.TraceScreenRay(middle, false, false, true)` gives `"unit", id` or `"ground", {x, y, z}` (the table also with `onlyCoords`, which ignores units; `"sky"` otherwise). The own unit is hidden (`SetUnitNoDraw`) and made unselectable (`SetUnitNoSelect`): without that the ray with the eye inside the unit's volume answered "unit" (the own one) in many directions, and a click would select the unit. `TraceScreenRay` also answered "sky" for slopes that the heightmap has (measured: ground 337 to 560 Elmo away at pitch 3 degrees where the ray said sky), so `march` follows the view ray over `GetGroundHeight` in steps of `R.MARCH` = 24 Elmo (bisected at the hit, inside the map only) when the engine ray finds no unit or ground; scenery beyond the map edge (mountains outside the map) has no heightmap and stays "sky". `R.hit` = kind, point, unit, distance; the text is "Pawn 100% 151 m" (red for an enemy, "(ally)" for an ally), "ground x / z, distance" or "sky". Measured with `zz_ren3.lua`: the crosshair on the enemy gave its id at 151.6 m, on the ground the point 84 m away.
- **Shots go anywhere (`R.shot`):** the player can always fire; the shot goes to the point under the crosshair when it is within the weapon's reach (`maxWeaponRange` - 8), otherwise to the point at the reach along the view ray (kind "air", no unit target): into the sky, at far mountains or enemies out of range the unit still shoots along the view and the weapon's reload is the only limit. An enemy within reach is the unit target.
- **Weapon panel (`weaponPanel`):** right of the middle at the bottom: for each weapon with a range, its description (shortened to the width), range, reload time, READY / reloading and a bar (full = ready, from `GetUnitWeaponState` `reloadFrame` and `reloadTime`). Peewee: "Rapid-fire close-quarters g2g plasma", range 180, reload 0.3 s.
- **Fire (PoC 4):** the left button sets `fire`; while it is down the message carries `R.shot` (the point and the unit there or -1). The gadget (`shoot`, every 3 frames) calls `Spring.SetUnitTarget(unit, enemy, false, true)` or `(unit, x, y, z, false, true)` (user target; an allied unit counts as a point) and `SetUnitTarget(unit, nil)` when the button is up; the unit's fire state is hold fire, so it shoots only at what the player aims at. Measured with `pve_test.ps1 -Ren -RenTest -Widget zz_ren3.lua` (game option `lanrenotest=1`, hook `ren|test|1` puts a Peewee of the enemy 150 Elmo ahead): the weapon target was the enemy (`GetUnitWeaponTarget`: type 1, user true), after 4 s of fire its health fell from 370 to 109 (the weapon's own damage, no own damage system); after the button went up the target was cleared; at the ground the target (type 2) followed the crosshair while the unit strafed with A.

- **Quick start:** `LevelEditor\start_renegade.bat [map] [AI] [bots]` (default `Hooked 1.1`, `NullAI` and 3 bots; the game options `lanrenebots` and `lanrenedebug=1`) runs `ensure_installed.ps1` and `scripts\start_renegade.ps1` (writes `LevelEditor\renegade_script_installed.txt`, ignored by git): you in team 0, the computer player in team 1, game options `lanrenegade=1; lanplay=1; deathmode=neverend`.

- **Bots (`lanrenebots=<n>`, 0 to 30):** at frame 120 `n` Peewees of the first team without a human (`botTeam`) appear on the land at about 800 Elmo from the nearest player unit (`place`: of 24 random places where the unit can stand, the one closest to the wished distance); every 120 frames each bot gets `CMD.FIGHT` to a point within 150 Elmo of the nearest player unit (fire at will, so they shoot what they meet); a lost bot comes back after 150 frames. Measured with `-RenBots 3 -Widget zz_ren5.lua` (`lanrenotest=1` logs "bots n, nearest ..."): on Hooked they needed about 40 s of game time to arrive (the path round the rim is long), then killed the standing player unit.
- **Loss and respawn:** a player's unit that is lost comes back after 90 frames as the same kind at a place far from the enemy units (`place`, farthest of 24); `renUnit` is 0 meanwhile and the widget leaves the view (it comes back by itself when the new unit appears). No score, no teams yet.
- **Debug menu (`lanrenedebug=1`, `start_renegade.bat` has it on):** above the weapon panel a button "Debug unit: <name> v". Tab frees the mouse (no look, no steering, no fire; the cursor shows), a click on the button opens a list of 175 mobile land units with a weapon (not aircraft, ships, commanders, Epic/Final Boss, Scavenger copies; sorted Armada, Cortex, Legion, rest; 3 columns of 18, the mouse wheel scrolls by 3 rows), a click on a name sends `ren|unit|<unit name>` and leaves the menu. The gadget (`turnInto`, only with the option, not for aircraft or units that cannot move) makes the new unit at the place and facing of the old one with the same health fraction, then removes the old one without wreck (`units[team]` is the new one first, so no respawn). Measured: Pawn -> Grunt (`corak`), the view follows, the unit stays hidden; the weapon panel shows the new weapon (Laser, range 215, reload 0.5 s). Test hook `ren|test|2` (with `lanrenotest=1`) kills the own unit (respawn test).

Not yet done: PoC 5 (two players), a hand test of the fire, lobby button and `LAN_VERSION`, aircraft and other movement types.
