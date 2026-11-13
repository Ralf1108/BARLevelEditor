# Renegade: aircraft

Part of the specification of [Renegade](renegade.md) (overview, game options, messages, tests, open points).

Flying units as the unit of a player: steering, height, bombs. Gadget `renegade_game.lua` (`lift`, `faceView`, `dropBombs`), altimeter in the widget.

## Flying and gunships

- **Aircraft and range colours:** a unit that flies (`canFly`: gunships, fighters, bombers; the range of a bomb is tiny, the impact preview shows where it lands) has no range colours: the crosshair stays green and the rows of the panel have no tint.
  - Enemy aircraft out of the reach of the anti-air weapons are not shown at all (it would give away where aircraft fly).
- **Gunships:** the guns are fixed to the body, so the player has to fly so that the nose points at the target (the aircraft turns toward where it moves).
  - The unit gets no move order from firing (a `faceTarget` that turned it with short move orders was taken out: it disturbed the flying).
  - `SetUnitRotation` has no effect on aircraft (neither yaw nor pitch: the move type overwrites it every frame; measured), so the body cannot be tilted toward the view; see the steepness limit below.
- **Backward and sideways flight of a gunship (`faceView` in the gadget, measured with `zz_ren26.lua`):** the move type turns a gunship toward the way it flies (S flew backward at 5.4 Elmo a frame but the nose turned away from the view within a second).
  - For a gunship with fixed guns (hovering aircraft, weapons without a turret) the gadget therefore sets `turnRate` and `maxRudder` to 0 (`Spring.MoveCtrl.SetGunshipMoveTypeData`, once per unit; the engine accepts both names) and sets the heading itself every frame to the view yaw (`Spring.SetUnitDirection(u, sin(yaw), 0, cos(yaw))`; with the turn rate 0 the move type no longer overwrites it).
  - Measured: the nose stayed at -1.00 0.00 (the view) while the unit flew backward (S: velocity +5.4 along x) and sideways (D: velocity -5.4 along z).
  - So the guns of the gunship look where the player looks (in the yaw; the pitch is the steepness limit below), and it flies in every direction.
  - Other units: a tank or bot already turns only its chassis with the movement while the turret follows the view; a ground unit with fixed guns was not looked at.
- **Steepness limit of fixed guns (`fixedGun`, `deadRadius`, `correctShot`, `MAX_DOWN` 27):** an aircraft that hovers and has a weapon without a turret has its guns fixed to the body: they point at most about 27 degrees below its nose (measured with the Roughneck, `zz_ren20.lua`: the barrel direction `GetUnitWeaponVectors` for views from 20 to 90 degrees down stays at about 27 degrees; the shots fly on but miss the point).
  - The unit keeps its free movement.
  - Instead `correctShot` (widget, after `aim`): when the point under the crosshair (`R.hit`) lies steeper below the aircraft than `MAX_DOWN`, `R.shot` (the aim point that is sent to the gadget) is moved out along the ground in the same direction to the edge of the zone (four passes: distance = height above that ground / tan(27 degrees)); `R.corrected` holds it.
  - The crosshair turns orange and says "STEEP: the shot lands N m out (guns reach 27 deg down)"; on the ground a ring, a cross and a beam mark the point; the red disc with the ring (radius height / tan(27), smaller the lower the aircraft) still shows the dead zone under the aircraft.
  - The player sees that he has to go lower or change the angle.
  - Measured with the Roughneck at 234 Elmo: views of 20 and 30 degrees down are not changed (shot 399 and 383 m), from 40 degrees down the point is moved (to 68 m where the ground ahead rises, to 278 m and 188 m at lower height), and the gun keeps firing (the reload runs on).
  - The 27 degrees are the Roughneck's; other gunships were not measured.
- **How a gunship attacks in the normal game (measured, `zz_ren23.lua`):** an enemy Roughneck (the game's own `CMD.FIGHT`) flies toward the player at about 290 Elmo height and does **not** go lower;
  - within its range (380) it **tilts the body nose down by about 30 degrees** (body direction y -0.28, then -0.52 to -0.54) and fires from 270 to 320 Elmo away;
  - the player's Pawn died within 4 s.
  - It circles the target (a Titan as the player, 25 s: the bearing from the target swings through about 300 degrees, the distance stays between 270 and 330 Elmo), keeps its height of about 290 to 300 Elmo for the first 9 s and then sinks to about 230 Elmo, the tilt stays at 0.54.
  - So the engine's attack state pitches the body; together with the gun's own 27 degrees the angle down is about 57 degrees.
  - The first attempt with an ordinary `CMD.ATTACK` on the player's own Roughneck did not tilt (body y 0.00): there the Renegade targets (aim only, manual weapon targets) were set on the weapon at the same time.
  - Not built: an attack order on the aim point while firing (the engine would tilt, but also fly the unit) or a MoveCtrl flight model (the rotation can be held, see below).

## Height

- **Height of an aircraft (`lift` in the gadget, altimeter in the widget):** keys bit 16 (Space, polled with `GetKeyState(32)`) = higher, bit 32 (Ctrl, `GetModKeyState`) = lower; the message carries 0 to 63.
  - **Landing:** with the lower key (Ctrl) held all the way down (`MIN_ALT` 4; the aircraft stops at about 12 Elmo) for `LAND_HOLD` 60 frames (2 s) it lands (`CMD.STOP` and idle mode 1; the height goes to 0 within a second);
    - the next key other than Ctrl takes it off again (measured with `zz_ren28.lua`: from 426 down to 12 in about 6 s, landed at 0, W took it up to 430 and settled at 400).
  - **Terrain following (`followGround` in the gadget):** the move type of an aircraft follows the ground only slowly, so every frame the height it should have is worked out (wished height `inp.alt` above the ground under it when going down; above the highest ground in the next second, 3 samples of 20 frames of its velocity, when going up) and its vertical speed is pushed toward it with `SetUnitVelocity` (at most `FOLLOW_MAX` 4 Elmo a frame, only in the needed direction; not while Space or Ctrl are held, not for 45 frames after letting them go, not on the ground; no climbing when it is already at its highest height over the ground).
  - Measured with `zz_ren34.lua` (bomber armthund, W held, over a cliff from ground 4 to 202 and back on Hooked 1.1): after the take-off it stays at 393-408 above the ground, over the cliff it climbs ahead of it (peak 488, under the highest height 495) and is back at about 400 within 1-2 s, down the cliff it sinks (peak 467 over the lower ground, then 393-408).
  - The vertical speed of a fixed-wing aircraft takes the push only partly (the engine sets it too), the result is as described.
- **Terrain following of big aircraft (Flying Black Hydra, `followGround`):** `corfblackhyt4` is a gunship (`hoverAttack`, speed 36, radius 55, cruise altitude 100 / used 300, only with the extra units: **not** in a `-Quick` run); in `zz_ren73.lua` it lifts to about 195 above the ground and hovers there (vy +-1).
  - The look-ahead for the ground was 3 samples of 20 frames along the velocity (60 frames x 1.2 Elmo a frame = 72 Elmo for this unit), too short for a big slow aircraft that climbs about 2 Elmo a frame (measured vy 2.2): it began to climb at the foot of a mountain and was too low at the top ("sticks in the mountains").
  - Now **6 samples of 20 frames** (144 Elmo for the Hydra, a fast aircraft looks further) and **3 samples at 1.5 / 3 / 4.5 radii ahead** of the body.
  - The bomber test `zz_ren34.lua` still gives the earlier result (over the cliff from ground 4 to 202 it keeps 393 above the ground, peak 490 below the highest height).
  - **Not verified with the Hydra on a slope:** in my test neither the Hydra nor an ordinary gunship (Brawler) flew forward with W (the gadget gave the orders, `moving` true, but no command stayed in the queue; the start is 10 Elmo from the map edge, the order target clamps to 16: probably an artefact of that place, not looked at further), so whether it climbs in time at a real mountain has to be seen in a game;
    - if it still sticks, say where (height above the ground, ground ahead).
- **Hard ceiling (`ceiling` in the gadget):** the wished height was limited only, the real height overshot (a bomber went to 500-600 with Space held).
  - Now every frame the real height over the ground is compared with `maxAlt` and a unit over it is pushed down (vertical speed at most -(0.5 + 0.2 * excess), at most `2 * FOLLOW_MAX`); `inp.alt` is cut as well.
  - Measured with `zz_ren35.lua` (bomber armthund, highest height 495, W and Space held for 20 s over the cliff of Hooked 1.1): the maximum height over the ground was 496 (without the ceiling 534 at the cliff, with a push of at most 4: 498-534).
- **Highest height (the table `renegade_cruise.csv`):** the highest height above the ground of an aircraft is the column **Cruise altitude used** of `LevelEditor/game-modes/renegade_cruise.csv` (own table, readable as `renegade-cruise.md`; every aircraft of Armada, Cortex and Legion, also the 33 without a weapon: scouts, transports, builders, radar planes, satellites; names from `zz_alt.lua`).
  - The column **Cruise altitude** next to it is the `cruiseAltitude` of the unit definition (`zz_weapondump.lua` writes it as the 17th field of its lines; `renegade_weapons.py table` adds the aircraft that are new and renews that column, Cruise altitude used stays); Cruise altitude used is 3 times it for a new row.
  - `renegade_weapons.py update` writes the table `CRUISE_ALT` of the gadget (between the markers of the weapon block) from it; a unit that is not in it: 3 times `ud.cruiseAltitude`; the value is cut to between `MIN_ALT` + 20 and `MAX_ALT` 1000 (the satellites, 8100).
  - A unit without a weapon is not playable (`turnInto` and the unit choice need a weapon).
  - Measured with `zz_ren30.lua` and `zz_ren31.lua` (enemy aircraft that fly toward the player, Hooked 1.1, ground 4-24 Elmo): Roughneck cruise 100 flies at 297 above the ground (286-301; 297-309 above the sea level: the move type smooths the terrain); fighter 125 -> 377; bomber 165 -> 370-440; scout 180 -> 130-470 (no steady value); the factor 3 fits the gunship and the fighter, the bomber is a little below, the scout is unclear.
  - Values of the definitions (`zz_alt.lua`, 230 aircraft definitions): scout Blink 180, fighters 125-160, bombers 150-220, gunships and transporters 100, construction aircraft 50-80, drones 40-70, satellites 2700.
  - The height is above the ground, so the aircraft follows the terrain (the move type's wanted height is relative to the ground; not measured over a mountain yet).
  - The move type of a gunship hovers at least about 128 Elmo high when Renegade asks for a wanted height of 0 (`zz_ren27.lua`: wished 100, real 128), so the value of a gunship should not be under that.  **Take-off:** the first key (not Ctrl) of an aircraft that stands on the ground (height under 25) makes it take off once to `TAKEOFF_ALT` 400, or to its highest height when that is lower (`inp.takeoffUnit`);
    - it does not land by itself any more (no landing timer) and nothing else changes its height: only Space and Ctrl.
  - The gadget keeps the wished height `inp.alt` (between `MIN_ALT` 4 and the highest height of the unit, `maxAlt`, above the ground; `LIFT_RATE` 4 Elmo a frame while a key is down) and asks the move type for it with `Spring.MoveCtrl.SetGunshipMoveTypeData(unit, "wantedHeight", h)` (`SetAirMoveTypeData` as well; there is no getter).
  - The move type hovers higher than asked: `applyHeight` takes the measured difference `inp.off` (start value 100; measured about 130 for the Roughneck, whenever the vertical speed is 0) off what is asked, so the real height is the wished one (measured with `zz_ren27.lua`: take-off from the ground, 429 Elmo at the top, then settled at 400 within 2 s and stayed there for 10 s without a key).
  - Down: `SetUnitVelocity` pushes the unit down (`DOWN_SPEED` 2.3 Elmo a frame) because the move type sinks slowly; a landed aircraft takes off with the first key; on letting go the wished height becomes the real one and the vertical speed is taken away for 45 frames.
  - The widget draws the altimeter (`altimeter`) at the right edge for every unit: a scale 0 to the highest height of the aircraft (rules parameter `renMaxAlt`; any other unit: 0 to 600) with a tick every 100 (every 50 on a short scale), a bar and a marker with the height (an aircraft: above the ground; any other unit: the height of the ground it stands on, above the sea level, cut at 0), the number with " m" above it (Elmo are shown as m, like the distances at the crosshair), orange below 40 (aircraft only);
    - the keys hint only for aircraft.
- **Attack altitude (column of `renegade_cruise.csv`, table `ATTACK_ALT` of the gadget, rules parameter `renAttackAlt`):** a bomber (an aircraft whose bomb is on a mouse button: 13 of them) drops its bombs only up to this height above the ground (`dropBombs` returns false above it, nothing falls);
  - the panel row of the bomb is green up to it, yellow up to 15% above it, red higher, and says "drops below N m (now M m)".
  - Empty = no limit.
  - The value is the cruise altitude of the definition as a start (a second measurement of the engine's own release with the landing point as target gave 341-406 above the ground for armstil, armthund, corshad and legspbomber at once, 21-159 for others and nothing for armthundt4, cords, corhurc and legkam: it depends on the target and the heading, so no value could be taken from it; the Tsunami's first measurement of about 190-200 fits its cruise altitude 210).
  - Measured with `zz_ren41.lua` (Tsunami, attack altitude 210): a click at 463 above the ground drops nothing (row red), at 213 the row is yellow, under 210 green, a click at 185 drops 5 bombs.
- **Bomber ceiling 0.95 and automatic descent (`BOMBER_CEILING`, `lift`):** a bomber cannot climb higher than 0.95 x its attack altitude (Stormbringer: 157; measured with `zz_ren74.lua`: it stays at 156 - 157 and the sight stays green), so it never flies where its bombs do not fall.
  - With a button pressed and the height over the attack altitude minus 5 `lift` treats it as if Ctrl were held (`down`), the bomber sinks to the attack altitude and holds it when it is reached (not measured: it is possible to get above it only by an overshoot, the ceiling pushes down anyway).

## Bombs

- **Bombs are dropped by the gadget (`dropBombs`, `processBombs`):** the engine's bomb weapon fires only when the aircraft is low (measured with `zz_ren36.lua` / `zz_ren37.lua`, see below), so a button press drops the salvo itself: `salvoSize` x `projectiles` bombs, `salvoDelay` apart (Tsunami: 5 bombs, 5 frames apart, reload 7 s), each with `Spring.SpawnProjectile(weaponDef, { pos = unit position - 8 in height, speed = the unit's velocity, owner, team, ttl = 1200, gravity = -myGravity })` (without `gravity` the bombs fly straight on, measured; `myGravity` of the Tsunami's bomb is 0.4, not the map gravity 0.133; the five bombs of `zz_ren38.lua` all fall and explode after about 50 frames, at the predicted place within about 10 Elmo).
  - The reload is set with `SetUnitWeaponState(reloadFrame)` (the panel shows it), a button that stays down drops the next salvo as soon as it is ready, the weapon gets no target (so the engine's own release stays quiet).
  - The preview in the widget uses the same `myGravity`.
  - At any height one click is enough.
  - Earlier finding (the reason): (measured with `zz_ren36.lua`, Tsunami armsb, weapon `armsb_arm_seaadvbomb`: AircraftBomb, range 1280, onlyForward, maxAngleDif -1):** with the left button held at 340-550 above the ground the weapon does not fire (40 frames); it fires only when the aircraft has sunk to about 110-150 above the ground (frame 650 at height 106 in one run, frame 629 at about 150 in another); the same with the trigger target directly under the aircraft instead of the landing point (`bombPoint`), so it is not the position of the target. Not known why (the engine's bomb dropper); to decide: a hint on the crosshair (too high to bomb) or release the bombs by hand with `Spring.SpawnProjectile` (position, the unit's velocity, owner; reload, salvo and the reload bar to be done by the gadget).
- **Bomb sight and bomber ceiling (`bombState`, `BOMBER_CEILING`):** a bomber drops only up to its attack altitude (`renAttackAlt`).
  - `bombState` gives green up to it, yellow up to 15% above, red higher.
  - The impact preview of the bombs (disc, ring, line) and the crosshair take that colour, and the text under the crosshair says "BOMBS READY  n m", "almost  n m  (bombs fall below A m)" or "TOO HIGH  n m  (fly below A m to drop bombs)" (before, the preview kept the colour of the button, red for the left one, and the crosshair stayed green).
  - The highest height of a bomber (`maxAlt`) is its attack altitude x `BOMBER_CEILING` = 1.5 (before: the cruise altitude used, 3 x the attack altitude: 450 - 660 Elmo, far above where bombs fall); it can still climb to the yellow / red zone.
  - Measured with `zz_ren74.lua` (Stormbringer, attack 165): the ceiling is 248 (= 165 x 1.5), the sight changes green -> red when climbing; screenshots: yellow "almost 186 m" and green "BOMBS READY 152 m"; the red text is not seen in a picture.
  - A bug of the first version (the call `tonumber(GetUnitRulesParam(...))` fails when the value is missing) is fixed with extra brackets.
- **Own release over all bombers (`zz_ren40.lua`, one click of 3 frames at the flying height 240-444 above the ground, Hooked 1.1):** 13 of the 15 aircraft with an `AircraftBomb` weapon dropped their salvo (110 explosions in all, bombs land on the ground; salvo sizes 1 to 28: armlichet4 1 with reload 120 s, armsb 5, armthund 5, armthundt4 28, corsb 24, legspbomber 24, legkam 1 (kamikaze), legnap 4 ...).
  - The other two have no bomb on a button by design: legmineb (a mine layer, damage 0, empty Fire button) and legphoenix (its bomb weapon is a targeting dummy; its button weapon is the flame beam).
- **Engine bomb release over all bombers (`zz_ren39.lua`, `ren|test|4` = the engine's own release with the ground under the aircraft as target, descending with Ctrl):** 15 aircraft with an `AircraftBomb` weapon;
  - fired at: armpnix 53, armsb 16, armthund 5, armthundt4 190, cords 36, corhurc 40, corshad 44, legnap 202 above the ground;
  - no release at all for armlichet4, armstil, corsb, legkam, legmineb, legphoenix, legspbomber within 300 frames.
  - So the engine's release height is not a property of the unit: it depends on where the target lies (with the landing point ahead as target the Tsunami fired under about 190-200, with the ground right under it under about 16) and cannot be used as the highest height (which stays 3 times the cruise altitude, `renegade_cruise.csv`); our own release (above) works at every height.

## Shot down aircraft

- **Shot down aircraft are no anti-air targets (`shotDown`):** an aircraft that is dead (`GetUnitIsDead`), has no health left (`GetUnitHealth` <= 0) or is crashing (`GetUnitMoveTypeData(id).aircraftState == "crashing"`; the field exists for bombers and gunships, `zz_ren54.lua`) is skipped by `aaPick` in the widget (no lock, no circle highlight) and by `applyTarget` in the gadget (`lock` is false: an anti-air weapon gets no target from it).
  - The same function is in both files.
  - Not measured: a real crashing aircraft (none could be made in the sandbox); the move type data of an enemy aircraft outside of the line of sight can be empty in the widget (then the gadget, which sees everything, still refuses it).
  - `zz_ren53.lua` (a copy of `zz_ren13.lua`) shows that the lock on a healthy gunship still works.
- **Shot-down aircraft fall (`downed`, `lift`):** `lift` holds the height of an aircraft every frame (`wantedHeight`, push down with Ctrl).
  - A unit with no health left or with the move type state `crashing` is now left alone: the height control stops (once `wantedHeight` 0) and the log says "the unit is shot down: no height control".
  - Before, a gunship with Space held stayed at 300 Elmo for 8 s with health below 0 and `crashing`.
  - Test hook `ren|test|5` (lanrenotest=1): damage of health + 100000 to the unit; measured with `zz_ren84.lua` (armthund: crashes, gone after about 4 s; armbrawl gunship: before the fix it hung at 300 Elmo, after it falls 30 Elmo per 10 frames and is gone at frame 500).

## Tried and rejected

- **Tried and taken out (gunships):** (1) a short move order toward the aim to turn the unit (disturbed the flying); (2) `CMD.ATTACK` on the aim point while firing: the engine tilted the body about 30 degrees and the guns fired (measured: direction y 0 -> -0.5 in 1.5 s, back to 0 after the release), but the engine then flies the unit (approach, circling), the movement keys wait, and with the order renewed every 10 frames the flight trembled; not intuitive, removed.
  - (3) `Spring.SetUnitRotation` (yaw and pitch) in `GameFrame` and in `GameFramePost`: the move type computes the rotation again from nothing every frame (the value read before each set was 0.00), so a set holds only for the picture between two frames, not for the weapons; no use for aiming.
- **MoveCtrl flight model for gunships (tried, taken out):** the gadget took the Roughneck over with `Spring.MoveCtrl.Enable` and set position and velocity every frame (W/S along the view, A/D, Space/Ctrl) and the direction of the body from the view.
  - The flight worked (height 12 -> 330 Elmo with Space) and the body followed the view exactly (`Spring.SetUnitDirection(u, sin(yaw)cos(p), sin(p), cos(yaw)cos(p))`: direction 0.41 -0.91 0.00 as set, the weapon direction followed: 0.42 -0.91; with `MoveCtrl.SetRotation(pitch, yaw, 0)` the pitch turned into a roll as soon as the yaw was not 0).
  - But **the weapons did not fire** under MoveCtrl: `GetUnitWeaponCanFire` and `GetUnitWeaponHaveFreeLineOfFire` false, `reloadFrame` unchanged, at 152 Elmo level as well as steeply down, with and without the direction set.
  - So the guns are blocked by MoveCtrl itself; not usable.
- **MoveCtrl (measured):** with `Spring.MoveCtrl.Enable(unit)` and `SetRotation` each frame the body of a hovering Roughneck stays tilted (pitch -0.5 rad = direction y -0.48); `Disable` resets the rotation at once and the unit spins for a moment.
  - While enabled the engine does not move the unit at all.
