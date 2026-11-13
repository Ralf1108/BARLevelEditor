# Renegade: units and movement (gadget `renegade_game.lua`)

Part of the specification of [Renegade](renegade.md) (overview, game options, messages, tests, open points).

How a player gets a unit and how it drives: the synchronized part of the game mode. Aircraft: [renegade-aircraft.md](renegade-aircraft.md). Weapons: [renegade-shooting.md](renegade-shooting.md).

## Units, respawn, energy, bots

- **Units:** from frame 30 to 300 every team with a human and a commander gets an `armpw` at the commander's place instead (`take`, `giveUnit`; fire state hold fire: the unit shoots only what the player aims at).
  - `units[team]`, `kind[team]`, `input[team]`.
- **Start inside the map (`giveUnit`):** a ground unit that is made is put at least max(48, 1.4 x radius + 24) inside the map edge (the sandbox start is 10 Elmo from the edge; a Juggernaut, radius 74, stood half outside there).
  - Measured with `zz_ren76.lua`: the Juggernaut starts at 128, 1920 and walks.
- **Respawn:** a lost unit of a player comes back after 150 frames (`RESPAWN`) as the same kind, at a place far from the enemy units (`place`: of 24 random places where the unit can stand, the farthest; a second pass without the movement test for ships on land and turrets; none: the place where it was lost; creating fails: again after a second).
  - No score, no teams yet.
- **Energy:** each player team starts with 200000 energy, has a storage of 200000 and gets 5000 energy a second (`ENERGY_START`, `ENERGY_STORE`, `ENERGY_INCOME`; `SetTeamResource`, `AddTeamResource` every 30 frames).
  - Shots cost energy; the Calamity needs 18000 a shot, so it can fire continuously (5000 a second refill about one shot in 3.6 s once the storage is used up; the 200000 last for 11 shots).
- **Bots (`lanrenebots`):** at frame 120 `n` Peewees of the first team without a human (`botTeam`) appear on the land at about 800 Elmo from the nearest player unit (`place`); every 120 frames each bot gets `CMD.FIGHT` to a point within 150 Elmo of the nearest player unit; a lost one comes back after 150 frames.
  - On Hooked they need about 40 s of game time to arrive (the way round the rim is long).
- **Exploiters (extractors with lasers) and the energy of the enemy teams:** `zz_ren64.lua` (Advanced Exploiter `cormexp`, Exploiter `corexp`, `corllt`, `armllt` as the player's unit, aimed at the ground and at the sky): all of them fire (a press fires after 2 frames; the Advanced Exploiter's laser and barrage missile together), so as the **player's unit** the extractors work.
  - `zz_ren65.lua`: the **fusion reactors have no weapon at all** (`corfus`, `armfus`, `corafus`, `legfus`: 0 weapons) and so cannot fire; the laser of the Advanced Exploiter costs **50 energy a shot** at 0.53 s (the Exploiter 15, a light laser tower 20, the Titan's big laser 1300).
  - Only the player's teams had the big energy store (200000, income 5000 a second, `ENERGY_*`); a team of the AI that owns a spawned enemy ("Spawn" in the debug menu) or the bots started with **1000 energy and an income of 30** (measured, `[Renegade] team ... energy` at frame 200 in the test mode): an enemy extractor ran dry after about 20 shots and then did not fire.
  - Now **every team except Gaia** gets the store, the start energy and the income (`GameFrame`; before: only the teams that have a Renegade unit); the test line shows team 1 with 200000 / 5030.
  - Not reproduced: an extractor that does not fire as the player's unit (that works); an enemy extractor that shoots at the player was not seen in a run either (the player's unit did not get near enough in the test: that test widget was not kept).

## Moving

- **Moving:** `steer` gives `CMD.MOVE` to a point 200 Elmo ahead in the wished direction (forward `(sin yaw, cos yaw)`, right `(-cos yaw, sin yaw)`; again after 10 frames or when the direction turns by more than 6 degrees), `CMD.STOP` when no key is down.
  - No `MoveCtrl`.
  - W, A, S, D move the unit the right way (measured: 211 and 327 Elmo in about 4 s game time); pathfinding decides at cliffs, ships are not steered specially.
  - **Aircraft** never land by themselves: `CMD.IDLEMODE` 0 (fly) from the first key on; they take off once (see the height below) and only Space and Ctrl change the height afterwards.
- **Hull controls (`hullControl`, `hullSteer`, `HULL`):** ground units and ships that have at least one weapon with a turret (`wd.turret`) or no weapon at all (not aircraft, speed > 0) are steered like a tank, independent of the view: W = a move order `STEP` (200) ahead along the hull's heading (`GetUnitHeading` x 2 pi / 65536; 0 looks along +z, the heading grows to the left like the yaw), W + A / D = the order points 45 degrees to the left / right of the front and is given again every 4 frames (the unit keeps turning at its turn rate), A / D alone = the order points 90 degrees to the side, 120 Elmo away (the unit turns on the spot), S = reverse gear (`reverse`, only `canReverse` units: tanks, bots, spiders, hovercraft; a ship stops), A / D while reversing turn the hull at 60 % of the turn rate by `SetHeading`.
  - The mouse only changes `R.yaw` / `R.pitch`: the camera and the aim (the weapons shoot at the crosshair point as before; a turret with a limited angle gets the hint "TURN THE VEHICLE" which is now answered with A / D).
  - The compass shows the hull's heading relative to the view (it did before).
  - Units whose weapons are all fixed (no turret), aircraft and gunships keep the old control (`wish`: the direction relative to the view, the hull follows it by the move order; no reverse gear for the first).
  - Measured with `zz_ren78.lua` (view fixed at yaw 90): Bulldog `armbull`: W + D turns the heading 64 -> 26 -> -24 -> -75 degrees (right = smaller), S + A turns it -131 -> -106 (left = larger), speeds 62 forward and 37.2 (60 %) backward; the Pawn at the start (10 Elmo from the edge) was held by the map edge.
  - Not measured: ships, hovercraft, the feel at high turn rates, the turning angle 45 degrees (a guess).
- **Straight along the view (`SNAP_ANGLE` = 20 degrees):** a hull-controlled unit that drives straight ahead (W, no A / D) with its hull within 20 degrees of the view gets the move order exactly along the view (not along the hull), so it turns into the view and then drives where the player looks (before: along its slightly crooked hull).
  - Measured with `zz_ren87.lua` on Comet Catcher (view -8 degrees, hull 0): hull and path -8.0 after 1 s.
  - A direct `SetUnitDirection` of the hull was tried first and failed (the unit turned away to 50 degrees).
  - On Hooked 1.1 the start lies in a narrow corridor, so the test does not work there.
- **Reverse gear (`reverse`, `canReverse`, `REVERSE_SPEED`):** with S held and W not (`steer`), tanks, bots, spiders and hovercraft (not ships, aircraft, buildings; gunships have their own backward flight) are moved by hand: `MoveCtrl.Enable`, `SetTrackGround(true)`, `SetGravity(0)` and every frame only `SetVelocity` along the wished direction (`wish`: S, with A / D to the side) x speed / 30 x 0.6 (the speedometer shows it: up to 60 % of the maximum; **no `SetPosition`**: with it on top the engine, which also integrates the velocity of a unit under MoveCtrl, moved the unit twice per frame and the drawn position was not interpolated: the first version measured 3.48 Elmo per drawn frame instead of 1.74 and shook; with the velocity alone: 1.73 - 1.74 per drawn frame, the same evenness as forward walking (`zz_ren79.lua`: spread of the step 0.01 forward, 0.00 in the steady part of the reverse), height step 0.01), the heading (`MoveCtrl.SetHeading`) turned toward the view at the turn rate (`turnRate` / 182.04 degrees a frame).
  - The step is refused at the map edge, where `TestMoveOrder` (terrain only) says no and when a ground unit stands in the way; then the unit stands (velocity 0).
  - Letting go of S, pressing W or the switch to the normal game does `MoveCtrl.Disable` and the normal move orders go on.
  - This replaces the walk-around of the next paragraph (the engine turns the unit around and drives forward).
  - Steering while reversing: A / D give the sideways part of the wished direction and the mouse turns the view (and so the heading and the direction of the reverse), both at the same time.
  - Measured with `zz_ren78.lua`: Pawn 52.2 of 87 (= 60 %), Bulldog (`armbull`) 37.2 of 62; S + D curves (z changes while x grows); the heading goes to the view (-90 degrees); afterwards W drives forward again at the full speed.
  - Not measured: other movement classes, hovercraft, pushing against other units and steep slopes (the Bulldog stopped at a wall at x = 289).
- **Reverse from standing: the walk animation (`PRIME_FRAMES`, `reverse`, `stopReverse`):** the model script gets "StartMoving" only from the engine's own move type, so a unit that reverses by `MoveCtrl` from standing had no walk animation (after a forward step the animation went on: no "StopMoving" came).
  - Now a unit that stands (speed under 15 % of its maximum) first gets a move order 150 Elmo forward along the hull and drives it for 5 frames (`inp.primeU`, `inp.primeN`); then the reverse takes over **without** a stop order (before, `reverse` started with `CMD.STOP`, which ends the animation).
  - `stopReverse` gives the stop order at the end.
  - A unit that is already walking starts the reverse at once.
  - Measured with `zz_ren86.lua` (Pawn standing, S held: z +4 Elmo forward in the first frames, then back at 52 Elmo/s; after releasing it stops).
  - **The animation itself was not seen.**
- **Walking backwards without turning (spiders; tried, not possible with the engine's movement):** the spiders are the movement classes `tbot3` (Webber `armspid`, Recluse `armsptk`, Scarab `armscab`, termites), `epicallterrain` (the epic spiders) and `htbot6` (Vanguard `armvang`, but also the Karganeth and the Myrmidon) (`zz_spider.lua` lists all movement classes).
  - S gives the unit a move order 200 Elmo behind it; the engine turns the body toward the way it goes (`turnRate` 1290 for the spiders: the turn takes about half a second, heading 0 to 179 degrees in `zz_ren70.lua`) and then walks forward along the new heading: ground units move along their front direction.
  - Tried: `MoveCtrl.SetGroundMoveTypeData(unit, "maxReverseSpeed", speed / 30)` (accepted, `true`) and a short move step of 40 Elmo: **no change, the spider still turns**;
    - a body that keeps its heading while it walks backwards would need the unit to be moved by hand (`MoveCtrl`, free of the path finding and of the collisions with other units) or a script that turns the legs: both left out.
  - The test code was removed again.

## Take-over mode and single unit mode

- **Take-over mode and single unit mode (`SINGLE`, `lanrenesingle`, `possess`, `release`, `adopt`, `takeKey`):** game option `lanrenegade=1` switches the mode on;
  - `lanrenesingle` (missing or "1" = the **single unit mode** as before: `take` replaces the commander at the start, a lost unit comes back after 5 s, the key next to Shift switches between Renegade and the normal game) or "0" = the **take-over mode** (named so that "jump" means the jump of a unit): nothing is replaced, no respawn;
  - the player plays the normal game and presses **the mode key** over one of the own units (`takeKey`: `TraceScreenRay` at the cursor, the unit must be the own team's) to send `ren|possess|<id>`: the gadget (`possess`: not being built, a unit that moves or has a weapon, no other unit steered) makes it the steered one with `adopt` (the part of `giveUnit` after the creation: hold fire, rules parameters for the panel, three times the sight, whose own values `sightBase` keeps) and sets `renUnit`;
  - the widget sees it and `enable`s the first person view (the camera flies into the unit).
  - **the mode key again** (`ren|release`; also when the unit dies or is turned into another by Evolution: `UnitDestroyed` sets `renUnit` 0 without a respawn) gives the unit back (`release`: stop, no target, fire state 2, the held reloads released, its own sight) and the widget `disable`s and flies the camera back over the unit (`overviewCam`; the saved camera when the unit is gone). the mode key is taken in `KeyPress` (returns true) and polled (`GetKeyState(113)`, a press within 0.3 s counts once);
    - not with Ctrl / Alt / Shift.
  - `pve_test.ps1 -Ren -RenTake` starts it.
  - Measured with `zz_ren80.lua` (the message that the mode key sends over a unit): normal game (camera `spring`, no unit) -> take over (R.on, `renUnit` = the commander, camera `fps`, fire state 0) -> out (R.on false, `renUnit` 0, camera `spring`) -> in again -> out;
    - **not measured: the real key over a unit** and Evolution + Renegade together (an evolved unit is a new one: the player is thrown out and takes over the new one).
  - **The mode key** (changed from Q, which BAR uses): the key left of the 1 (scan code 53, SDL "grave"; the circumflex "^" on a German keyboard, key code 94): `KeyPress(key, mods, isRepeat, label, utf32, scanCode)` accepts `scanCode == 53` or `key == 94`, and `Update` polls `GetKeyState(94)`;
    - in the single unit mode it calls `toggleMode` (both ways, like the key next to Shift and Insert), in the take-over mode `takeKey`.
  - **Not measured with the real key.**
- **Take-over mode with Evolution (`EVO`, `follow`, `renFollow`, `R.waiting`):** with the game option `lanevolution` and the take-over mode the player's unit is replaced when it evolves and comes back after a death.
  - `UnitDestroyed` of the steered unit then sets `follow[team]` (15 s) and the team rules parameter `renFollow` = 1; every frame the gadget looks at `evoUnit` (the parameter of `evo_game.lua`) and as soon as it is a living unit of the team `possess`es it (`renFollow` 0; after 15 s it gives up).
  - The widget keeps the view while `renFollow` is 1 and the unit is gone (`R.waiting`: no drawing for the old unit, no input), and when `renUnit` shows the new unit the `u ~= R.unit` branch of `Update` starts a camera flight from the last camera (`R.camNow`, 0.9 s) to the new unit; `R.third` is kept, so the new unit is entered in the same view (first or third person).
  - A manual Q out of the unit does not follow.
  - Measured with `zz_ren81.lua` (`pve_test.ps1 -Ren -RenTake -Evo -EvoTest`): the player in the third person view; `evo|test|4` (level 10): `renUnit` 31090 (`corak`) -> 31886 (`corkorg`) within 2 frames, `R.on` true, third person kept; the flight and the waiting after a death are not seen in a picture.

## Healing: wrecks and the heal effect

- **Heal effect and wreck reclaim:** `G.healAdd(unit, amount)` and `G.healDraw(vsy)` in `led_gadgets.lua` (unsynced, called from `gadget:DrawScreen`): 12 green plus signs circle round the unit and rise, a green "+N" climbs over it (1.6 s; in the first person view, with the camera inside the unit, the same round the middle of the screen).
  - The synced part sends `SendToUnsynced("renHeal" / "evoHeal", unit, amount)`.
  - `autoReclaim` in `renegade_game.lua` (not with Evolution, which has its own): once a second the unit of a human that is hurt takes the metal of the wrecks within `RECLAIM_RANGE` = 300 Elmo as health, 1 metal = 1 health, at most 1 % of the maximum health a second, at least `RECLAIM_MIN` = 1 and at most `RECLAIM_RATE` = 150 (the wreck shrinks or is gone); the work is done by `G.reclaimFeatures` of `led_gadgets.lua`, which Evolution uses too;
    - it stops at full health and while an armed enemy is within 1.25 times the longest weapon range of the unit (at least 375 Elmo).
  - Test hook `ren|test|6` (unit at 30 %, three Bull wrecks ahead), `zz_ren89.lua`: the health rises by the rate every second until it is full.
  - Not for computer Peewees.
  - The third person view of the effect was not seen.
- **Reclaim rate and one heal number:** the health a unit takes from wrecks per second is 1 % of its **maximum** health (`RECLAIM_PERCENT` = 0.01), at least `RECLAIM_MIN` = 1 and at most `RECLAIM_RATE` = 150, so a big unit heals faster and a small one still at least 1 a second; Evolution the same (`R.RECLAIM_HEAL_PERCENT`, `R.RECLAIM_HEAL_MIN`, `R.RECLAIM_HEAL_MAX`).
  - Measured with `zz_ren89.lua`: a Pawn (370 health) at 111 gets 3.7 health a second (111, 115, 118, 122, 126 ... every 30 frames).
  - `G.healAdd` joins the heals of one unit within 1.3 s into one number that counts up (before: one number per second, so two were seen at the same time).

## Debug messages (only with `lanrenedebug`)

- `ren|unit|<name>` (`turnInto`): every unit with a weapon (aircraft, turrets that stand still and shoot, ships: they lie on the land and fire) is made at the place and facing of the old one with the same share of health, the old one is removed without wreck (`units[team]` is the new one first: no respawn); groups and parameters are worked out again.
- `ren|spawn|<name>`: the unit for the first team not allied to the player, 1000 Elmo ahead of the player's view (yaw of the last message), a ground unit on the ground, an aircraft 200 Elmo above, `CMD.FIGHT` toward the player.
