# Renegade

[Start page](../../README.md) · [Specification](../../specs/renegade.md)

**You are one unit of Beyond All Reason, seen from the inside.**

- First or third person, mouse look, W A S D, crosshair, three mouse buttons for the weapons.
- Every unit is the original: model, speed, weapons, range, armor and damage stay as they are in the game.
- Named after Command & Conquer Renegade, where the units of a strategy game were played as a shooter.

**Status: experimental.** Tested with one human against computer units. The LAN Play room has the button, but games with several humans are not tested yet.

## Start it

| Way | How |
|---|---|
| Quick start | double-click `LevelEditor\start_renegade.bat`: you as a Peewee on **Hooked 1.1** against 3 computer Peewees that hunt you |
| Other map, computer player, number of enemies | `start_renegade.bat "Comet Catcher Remake 1.8" SimpleAI 5` (0 = no enemies) |
| Faster start | add `quick` as the fourth parameter: `start_renegade.bat "Hooked 1.1" NullAI 3 quick` (without Legion, extra, Scavenger and Raptor units) |
| LAN Play | green button **LAN Play** in the room > **Renegade** > On |

Two ways to play in LAN Play (settings of the button **Renegade**):

- **Always in unit On** (the default): every player is one unit for the whole game.
- **Always in unit Off** (jump mode): you play the normal game with all your units. Hold the mouse over one of your units and press **the key left of the 1** to jump into it, the same key to jump out. If the unit is lost you are out of it.

## Controls

| Input | Effect |
|---|---|
| Mouse | look round and aim (the cursor stays in the middle) |
| W A S D | drive like a tank: W forward, S reverse (60 % of the speed), A and D turn the vehicle |
| Left / right / middle mouse button | fire the **short range weapons** (red) / **long range weapons** (yellow) / **missiles** (green) |
| Shift | third person view (camera behind your unit) and back |
| Alt | **FULL FIRE** on / off: the left button fires every weapon at once |
| Space / Ctrl | aircraft: higher / lower; Ctrl held at the bottom for 2 s lands a gunship |
| Mouse wheel, B | binoculars (units with a range of 600 or more): wheel forward zooms in, back zooms out |
| Key left of the 1 ("^" on a German keyboard) | switch between Renegade and the normal game; in jump mode: jump into the unit under the mouse and out |
| Insert, or the key next to the left Shift | switch between Renegade and the normal game |
| Tab | free the mouse for the debug menu, again: back |
| Windows key | free the mouse (to reach another window) |

Good to know about driving:

- The mouse only aims: you can drive one way and shoot another.
- Driving straight ahead and looking within 20 degrees of the hull: the vehicle drives exactly where you look.
- Ships have no reverse.
- Aircraft, gunships and units with weapons fixed to the hull go where you look when you press W.

## Shooting

- **You can always fire**, also into the sky or at far mountains. The shot goes where the crosshair points, as far as the weapon reaches. Nothing is "targeted" as in the strategy game.
- **One click is one shot**, holding the button is continuous fire. A weapon fires only when it is loaded **and** the button is down: a click during the reload is forgotten.
- **The turret follows your view** all the time, so it is ready when you press the button.
- **Which weapon is on which button:** weapons of the same kind fire together. Short range left, long range right, missiles in the middle.
  - Exception: the commander's Disintegrator (D-gun) is always on the right button, the laser on the left.
  - Units with two trajectories (Rattlesnake, Gauntlet, Vanguard, Agitator, Persecutor, Eviscerator, Amputator, Myrmidon): left = direct shot, right = vertical shot.
  - The full list is a table you can change in Excel: [renegade-weapons.md](renegade-weapons.md).
- **Anti-air:** a unit with anti-air weapons has a large orange circle round the crosshair.
  - Bring an aircraft into the circle: it glows and "AA LOCK" shows. Press the button and the homing missiles go for it.
  - Without an aircraft in the circle these weapons do not fire (the panel marks them **AIR ONLY**).
  - Weapons that hit ground and aircraft (e.g. the Titan's big laser) use the same circle for aircraft; at the ground you aim yourself.
  - An aircraft that is already shot down is no target any more.
- **Arc weapons** (artillery, lofted and vertical missiles, nuclear missiles, long-range cannons): a disc on the ground shows where the shot comes down. Aim a bit ahead of a moving enemy.
- **Turret angle:** some turrets cannot turn all the way round (e.g. the Mauser, 90 degrees to each side). The crosshair turns red and says **TURN THE VEHICLE** with the side (`>>` or `<<`).
- **Beam weapons** are aimed through the unit under the crosshair, so the beam hits it in the middle.
- **Energy:** laser units need energy; your team gets plenty of it by itself.

## Aircraft

- **Altimeter** at the right edge: fixed scale 0 to 500 m above the sea level. Yellow = the ground, blue = your height in the air, the number on top = height above the ground, the red line **MAX** = the highest your aircraft can fly here.
- **Highest height:** an aircraft cannot fly above its cruise altitude (a hard limit, it follows the terrain). The values are a table: [cruise altitudes](renegade-cruise.md).
- **Gunships:** the guns are fixed to the body and point at most about 27 degrees down. You fly forward, backward and sideways with the nose toward where you look.
  - Aiming steeper: the crosshair turns orange (**STEEP**) and the shot goes to the nearest point the guns can reach.
  - A red disc under you is the zone you cannot hit: go lower, or fly away and aim flatter.
- **Bombers:** one click drops the whole salvo; hold the button for the next one.
  - Bombs fall only below the **attack altitude** (the panel says DROPS BELOW). Bomb sight and crosshair: green = bombs fall, yellow = just above, red "TOO HIGH".
  - A disc on the ground shows where the bombs would land now.
  - A bomber cannot climb far above that altitude (at most 1.5 times).

## What you see

- **Crosshair:** green = a weapon reaches what you look at, yellow = just at its limit, red = out of range. Under it: what you point at, its health and the distance.
- **Weapon panel** (bottom left): one card per weapon with its picture, name, mouse button, range, shots per second, damage per shot and damage per second.
  - Sorted by range, the shortest on top. The card has the colour of the crosshair for its own weapon.
  - While a weapon reloads a grey fill runs down and the seconds left count.
  - Weapons that fire by themselves (anti-nuke) are a grey row **AUTO**.
  - All pictures with their damage limits: [weapon categories](renegade-weapon-categories.md#overview-of-all-pictures).
- **Compass** (bottom middle): up = where you look, green arrow = where the vehicle drives, coloured arrowheads = where each group of weapons points.
- **Speedometer** (right of the compass): 0 to 150 Elmo per second, the yellow mark is your highest speed.
- **Health bar** under compass and speedometer.
- **List of the players** (top right): unit, kills and deaths.
- **Lines on the ground:** where each group of weapons points. The range rings are off; `/renegade rings` or the debug button **Range** switches them on.
- **Green arrow on the ground:** the way the unit faces (for a turret: where its gun points).
- **Damage numbers:** every hit on a unit you can see rises as a red number (blue = paralyzing damage). Hits in quick succession are added up.
- **Respawn:** when your unit is lost, a countdown (5 to 1) shows and you come back as the same unit far from the enemies.

## More rules

- **Long sight:** your unit sees three times as far as its type normally does. There is no fog, and units far away stay units (no icons). Radar and minimap show only what your sight covers.
- **Wrecks heal:** a hurt unit reclaims wrecks within 300 Elmo by itself (1 metal = 1 health).
  - Rate: 1 % of the health it has now per second, at most 150.
  - Shown as green plus signs and a rising green "+number".
  - It stops at full health and when an armed enemy is near (a little more than the range of your weapons).
  - Evolution has its own version of this.
- **Normal game:** switching to it puts the camera over your unit at the usual distance, so you see the battlefield.

## Debug menu

With `start_renegade.bat` three buttons sit above the panel. Press **Tab** to free the mouse, then click one:

| Button | Effect |
|---|---|
| **Unit** | the unit menu of the Level Editor (faction, group, tech level, search, pictures): a click **turns you into that unit**, same place, same share of health |
| **Spawn** | the same menu: a click makes that unit appear as an **enemy 1000 Elmo ahead** (an aircraft 200 up); the menu stays open |
| **Range** | range rings on (green) / off (red) |

- Under the pictures the unit under the mouse is described: name, speed, health and the values of each weapon.
- As a turret you cannot move but you can fire. A ship lies on the land (for the tests) and fires.

## Change the tables (Excel)

| Table | What it sets | Apply |
|---|---|---|
| `renegade_weapons.csv` | which weapon is on which button, its category | double-click `update_renegade_weapons.bat` |
| `renegade_weapon_limits.csv` | which size of picture a weapon gets (by tech level and damage per second) | the same |
| `renegade_cruise.csv` | highest height and attack altitude of every aircraft | the same |

- Pictures: `weapon-images\weapon_<category>.png` (39 categories). Put your own picture with that name into the folder, run the update and start the game again.

## Not yet there

- Jumping, games with several humans (not tested), score, teams and a real game goal, sound.
- Aircraft and ships are steered less well than ground units.
- The plan and what was measured in the game: [specification](../../specs/renegade.md).
