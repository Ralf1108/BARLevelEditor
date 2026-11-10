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
| Left mouse button | fire the **main weapon** (the strongest one) at the point under the crosshair |
| Right mouse button | fire all **other weapons** of the unit |
| Insert (or `/renegade`) | normal camera and back |
| Tab | free the mouse for the debug menu, again: back to the game |

## What you see

- **Crosshair** in the middle: **green** when the point under it is within the reach of the main weapon, **red** when it is too far, white for the sky. Under it: what you point at (unit, health, distance) and IN RANGE / OUT OF RANGE.
- **Range rings** on the ground round you: the main weapon thick and red, the other weapons thin and yellow.
- **Panel** at the bottom: your health, then every weapon with its name, LMB / RMB, range, reload time and a **reload bar** (green = ready to fire).
- You can **always fire**, also into the sky or at far mountains: the shot goes where the crosshair points, as far as the weapon reaches, and the weapon's own reload is the only limit. Nothing is "targeted" as in the strategy game.
- Laser units need energy: for the tests you get **500 energy per second**.

## Debug menu

With `start_renegade.bat` a button **Debug unit** sits above the panel. Press **Tab** (the mouse is free), click the button: the unit menu of the Level Editor opens (faction, group - Turrets, Bots, Vehicles, Hover, Air, Ships -, tech level and the pictures of the units that have a weapon). A click on a picture **turns you into that unit** at the same place with the same share of health; as a turret you cannot move but you can fire; a ship needs water.

## Not yet there

Jumping (planned, see the specification), several human players in the LAN, lobby button, score, teams and a real game goal, all unit types steered equally well (aircraft and ships are only tried), sound and a fuller HUD. The plan and what was measured in the game are in the [specification](../../specs/renegade.md).
