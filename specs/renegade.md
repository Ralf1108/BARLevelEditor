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
| PoC 3 | Crosshair and screen ray: crosshair in the middle, the ray's hit (ground point / unit) shown as debug text | the shown hit matches what the crosshair points at |
| PoC 4 | Fire: left button -> target to the gadget -> original weapon fires at the crosshair point | shots land at the crosshair, damage is the game's own |
| PoC 5 | Two players (LAN test with host + 1 joiner): each steers one unit, they shoot each other | both screens show the same fight, no desync |

The first implementation covers PoC 1 and 2 (camera, mouse, movement).

## 6. Not in the first prototype

Hundreds of players, own lobby/matchmaking/dedicated server, new weapons/projectiles/damage model, all unit types (aircraft, ships, hovercraft need their own control model), full HUD, sound, animation and progression systems. Respawn and teams will reuse the Evolution pattern (start position, death -> new unit after a delay).

## 7. Open questions

- Is the `fps` camera state usable from a widget and tied to a unit, or must the own camera be used?
- Can the mouse be fully captured (cursor hidden and kept in the middle, also at the window edge)?
- Does `TraceScreenRay` hit the own unit, and how does it behave with the changed camera?
- How well does a move-order based WASD feel, and how does the unit's heading relate to the view yaw?
- Can a weapon follow an arbitrary aim point fast enough, and what does the hold-fire/fire-state interplay look like?
- Traffic and determinism of the input messages with many players.
- What the lobby/team setup needs (one unit per human, no commander, no building).

## 8. Implemented and measured (PoC 1 and 2)

Files: `LevelEditor/scripts/renegade.lua` (widget), `renegade_game.lua` (gadget), both in `$ScenarioGameFiles`. Test: `pve_test.ps1 -Ren -Widget zz_ren.lua -Map "Hooked 1.1"` (lines `[zzren]`), `zz_cam.lua` (which camera states take a direction).

- **Gadget:** with `lanrenegade=1` every team with a human and a commander gets an `armpw` instead (frames 30-300; team rules parameter `renUnit`, public). The widget's message `ren|<yaw>|<pitch>|<keys>|<fire>` (`RecvLuaMsg`, sender's team must own a unit; keys W 1, A 2, S 4, D 8) is stored; `steer` gives `CMD.MOVE` to a point 200 Elmo ahead in the wished direction (forward `(sin yaw, cos yaw)`, right `(-cos yaw, sin yaw)`), again after 10 frames or when the direction turns by more than 6 degrees, `CMD.STOP` when no key is down. No `MoveCtrl`. `fire` is only stored (PoC 4).
- **Camera:** the engine camera `fps` works from a widget, set every frame by `Spring.SetCameraState({name = "fps", mode = 0, oldHeight = 0, px, py, pz, rx, ry, rz}, 0)`. **The direction comes from `rx` and `ry`, not from `dx, dy, dz` (ignored):** `rx = pi/2 - pitch` (pi/2 horizontal), `ry = pi - yaw` (our yaw 0 looks along +z, 90 along +x). Without `mode`/`oldHeight` the engine fell back to the `spring` camera in one run. Measured: `GetCameraDirection` equals the wanted direction (yaw 0/90/45, pitch 0/20/-10). Switching by name to `free`, `ta` or `spring` did not take over (name stayed `fps`). Eye = `GetUnitViewPosition` + 0.85 x `GetUnitHeight` (Peewee: 26 -> 22.1 above the base); the own model is hidden with `SetUnitNoDraw` (a picture shows ground, crosshair and the minimap view cone; the unit panel still shows the unit).
- **Mouse:** `Spring.GetMouseState` + `Spring.WarpMouse(middle)` each frame; the difference is the turn (0.15 degrees per pixel; y is from the bottom: mouse up = look up, mouse right = yaw down). Measured: the warp lands exactly, one frame later yaw and pitch are as expected. `MousePress`, `MouseRelease`, `MouseWheel` and the keys W A S D return true while the view is on (RTS does not react; not yet checked by hand with a real mouse). Insert (or `/renegade`) switches back and forth, `/renegade log` writes the camera state, `/renegade flip` turns the yaw offset by 180 degrees.
- **Movement:** W with yaw 0 / A with yaw 90 / S with yaw 270 moved the unit the right way (north-south 211 and 327 Elmo in about 4 s of game time at speed 4); the stop works (speed 0). At the start position of Hooked (map edge, x = 10) the first W was blocked (8 Elmo), a second try elsewhere worked; an S after A took a detour (cliffs near the edge): pathfinding decides, as expected for move orders.
- **Crosshair:** four short lines in the middle (`DrawScreen`); the screen ray is PoC 3.

Not yet done: a real mouse and keyboard test by hand, PoC 3 to 5, lobby button and `LAN_VERSION`, aircraft and other movement types.
