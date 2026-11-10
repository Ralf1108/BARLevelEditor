# Renegade

[Specification](../../specs/renegade.md) · [Start page](../../README.md)

A game mode in the making: **you are one unit of Beyond All Reason, seen from the inside** - first person, mouse look, W A S D, crosshair, fire. Named after Command & Conquer Renegade, where the units of the strategy game were played as a shooter. Every human steers exactly one original unit (model, speed, weapon, range, armor and damage stay as they are in the game); later several players fight each other in the same world.

**Status: first test (proof of concept), for one player against computer units. Not yet in the LAN Play room, not yet for several humans.**

## Start it

`LevelEditor\start_renegade.bat` in the folder LevelEditor starts at once a game on **Hooked 1.1**: you with a Peewee against 3 computer Peewees that walk around and hunt you (a lost one comes back after a few seconds, so does yours). Another map, computer player or number of enemies: `start_renegade.bat "Comet Catcher Remake 1.8" SimpleAI 5` (0 = nobody).

## Controls

| Input | Effect |
|---|---|
| Mouse | look round (the cursor stays in the middle) |
| W A S D | walk (forward, left, back, right, relative to where you look) |
| Left mouse button | fire the **short range weapons** at the point under the crosshair (red) |
| Right mouse button | fire the **long range weapons** (yellow) |
| Middle mouse button | fire the **missiles** (green); anti-air missiles only at the aircraft you look at |
| Insert (or `/renegade`) | normal camera and back |
| Alt + left mouse button | fire **every weapon at once** (the panel then shows LMB on all rows; anti-air weapons still need an aircraft in the circle) |
| Tab | free the mouse for the debug menu, again: back to the game |

## What you see

- **Crosshair** in the middle: **green** when the point under it is within the reach of the main weapon, **red** when it is too far, white for the sky. Under it: what you point at (unit, health, distance) and IN RANGE / OUT OF RANGE.
- **Range rings** on the ground round you, in the color of the button: red (left), yellow (right), green (middle), thicker from red to green so you see all three when they lie on each other. A **line on the ground** of the same color shows where the barrel of that group points now: you look round faster than the turret turns, fire when the line points where you look.
- **Anti-air circle**: a unit with anti-air weapons has a large **orange circle** round the crosshair. Bring the aircraft into the circle: it **glows** (bright with a pulsing halo), an orange square and "AA LOCK" show on it; press the button of the anti-air weapons and the homing missiles go for it. Without an aircraft in the circle they do not fire. The panel marks such a weapon with an orange **AIR ONLY** under its button tag.
- Weapons that hit the ground **and** aircraft (description "g2g/g2a", e.g. the Titan's big laser) use the same circle: an aircraft inside it is locked, at the ground you aim yourself. All other weapons can be fired into the air too, like in Total Annihilation: you only hit by luck, and the range limits it.
- **The turret follows your view**, also when you do not fire (the line on the ground shows where it points): when you press the button it fires as soon as it points where you look. A small thick **green arrow** on the ground in front of you shows the way the unit faces, i.e. the way it walks or drives when you press W (a tank turns first when you look behind you).
- **Panel** at the bottom: your health, then one row for every button group with the weapon's name, LMB / RMB / MMB, range, reload time and a **reload bar** in the color of the button (full = ready to fire).
- Which weapons are on which button: weapons of the same kind fire together; the short range ones are on the left, the long range ones on the right, missiles in the middle (Titan: impulsion blaster, long-range laser, starburst rocket; Epoch: medium plasma, heavy plasma, anti-air missiles). Exception: the **commander's Disintegrator** (D-gun) is always on the right button, the laser on the left. Three buttons are enough for every unit of the game. The full list of all weapons of all units with the proposal of the buttons, which you can change, is in [renegade-weapons.md](renegade-weapons.md); to change it edit `renegade_weapons.csv` (Excel) and double-click `update_renegade_weapons.bat` in the same folder (it updates the page and the game file). Hold the button for continuous fire (as fast as the weapon reloads); one click is **one shot**: the weapon turns to the aim and fires once, even if you let go at once. Let go of the button and the unit stops firing. If your unit is lost, a big **respawn countdown** (5 to 1) shows and you come back as the same unit at a place far from the enemies.
- **Impact preview**: for artillery, rockets and missiles a translucent disc with a ring, a cross and a tall beam shows on the ground where the shot comes down (the size of the explosion, in the color of the button; as far as the weapon reaches). Aim at the ground a bit ahead of a moving enemy to lead the shot.
- You can **always fire**, also into the sky or at far mountains: the shot goes where the crosshair points, as far as the weapon reaches, and the weapon's own reload is the only limit. Nothing is "targeted" as in the strategy game (only anti-air missiles need the aircraft in the crosshair).
- Laser units need energy: for the tests you get **500 energy per second**.

## Debug menu

With `start_renegade.bat` a button **Debug unit** sits above the panel. Press **Tab** (the mouse is free), click the button: the unit menu of the Level Editor opens (faction, group - Turrets, Bots, Vehicles, Hover, Air, Ships -, tech level, a **search field** and the pictures of the units that have a weapon). A second button **Spawn enemy** opens the same menu: a click on a picture makes that unit appear as an **enemy 1000 Elmo ahead of you** (an aircraft 200 up, a ground unit or turret on the ground; the menu stays open for more), so you can fight it. A click on a picture after **Debug unit** **turns you into that unit** at the same place with the same share of health; as a turret you cannot move but you can fire; a ship lies on the land (for the tests) and fires.

## Not yet there

Jumping (planned, see the specification), several human players in the LAN, lobby button, score, teams and a real game goal, all unit types steered equally well (aircraft and ships are only tried), sound and a fuller HUD. The plan and what was measured in the game are in the [specification](../../specs/renegade.md).
