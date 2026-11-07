# Evolution

[Level Editor manual](../README.md) · [Specification](../../specs/evolution.md) · [Scenario builder](../scenario/README.md) · [Start page](../../README.md)

Every team starts with **one weak unit**. Kills give **points**, and enough points **evolve** the unit into a stronger one: 10 stages, from a Pawn up to a tier 3 giant. A lost unit comes back somewhere else on the map while the team has lives left. The last alliance standing wins. Computer teams play too: the game steers their unit.

## In short

- **Menu:** click the button **EV** in the button column at the right edge of the editor (below **RF**)
- Tick **Evolution** to mark the level (the button turns green)
- Place a commander (or any unit) for every team that plays: there it starts
- Excludes the other game modes in the same level
- **Start** runs it in the editor

## Build the level

**Teams**
- Every team with units plays; at the start its units are replaced by one stage 1 unit where its commander stood
- The faction of that unit decides the ladder (Armada, Cortex or Legion)
- Alliances (page **T**) play together

**Lives**
- **Lives** per team, default 3; 0 = unlimited (then the game does not end)
- A lost unit comes back after the **respawn** time (default 5 s) at a random place far from the others, on the same stage; the points of the stage are lost

**Wild units**
- Stage 1 units of nobody walk around the map, default 20
- **Health in %** of the normal unit, default 10: easy prey
- Each gives 1 point and comes back 10 s after it died

**Points**
- A wild unit gives 1 point
- A player unit gives as many points as its stage cost: killing a unit of your own stage is a whole stage
- **Points to stage 2** (default 3) and the **factor** per stage (default 160 %: every stage costs 1.6 times the one before)
- With the defaults: 3, 5, 8, 12, 20, 31, 50, 81, 129 points from stage 1 to 10 (the page shows the row)

## The ladders

| Stage | Armada | Cortex | Legion |
|---|---|---|---|
| 1 | Pawn | Grunt | Alaris |
| 2 | Blitz | Incisor | Phobos |
| 3 | Centurion | Brute | Karkinos |
| 4 | Welder | Fiend | Decurion |
| 5 | Bull | Tiger | Javelin |
| 6 | Marauder | Sumo | Prometheus |
| 7 | Meatball | Shiva | Incinerator |
| 8 | Razorback | Karganeth | Keres |
| 9 | Thor | Demon | Praetorian |
| 10 | Titan | Juggernaut | Sol Invictus |

Chosen by damage per second times health. A unit missing in the game (an option off, e.g. Legion) is taken from another faction on the same stage.

## How it plays

- Hunt the wild units first, stay away from bigger enemies
- A strong enemy is worth a lot: a stage 2 unit that kills a stage 5 unit jumps several stages
- The evolved unit keeps its orders and is selected again by itself; after a respawn the camera jumps to it

## Test and play

- **Start** / **Stop**: runs the game, the level comes back as before
- The stage, points and lives of every team are shown at the top
- Scenario package (start menu key `3`): settings are packed; computer teams get no AI of their own (the game steers them), the win condition is always the last alliance standing, no grace period
- LAN Play: the joiner plays the second team (human against human)
- The game runs in the gadget `evo_game.lua`
