# Evolution

[LAN Play](../../docs/lan-play.md) · [Specification](../../specs/evolution.md) · [Start page](../../README.md)

![Evolution in the game](../../docs/evolution-game.jpg)

Every player starts with **one weak unit** instead of the commander. Kills give **points**, and enough points **evolve** the unit into a stronger one: 10 levels, from a Pawn up to a tier 3 giant. A lost unit comes back somewhere else, one level lower. The first unit on level 10 brings **Armageddon**: no more fog of war, no more coming back, the last one standing wins. A mode of **LAN Play** on any map: no level, no editor needed.

## In short

- **LAN Play** room: the host presses the green button **LAN Options** in the title row of the room (next to "Leave Lobby"), then **Evolution** in its menu (it then reads "Evolution on"); everybody in the room sees it
- The host gets a window with the rules and a tip: a map of size **M or smaller** (up to 16 x 16)
- Start the game as usual: humans and computer players all play
- The start positions of the map are used (nobody has to place one)

![The menu LAN Play of the room with Evolution on](../../docs/evolution-room.jpg)

![Evolution: two players and a computer player on level 2](../../docs/evolution-fight.jpg)

## Rules

**Your unit**
- Every team starts with one level 1 unit where its commander would stand; all other units are gone
- Every new unit is of a **random faction** (Armada, Cortex or Legion): a Pawn can become a Brute and then a Karkinos
- The new unit replaces the old one where it stands, with full health; it keeps its orders and is selected again by itself

**Points**
- A wild unit or tower: a third of what its level costs (1 for level 1, 2 for level 2, 3, 4, 7, 10, 17, 27, 43, 69): about three of your own level bring you up
- An enemy player of level *v*: the points that level costs (3 for level 1, 5, 8, 12, 20, 31, 50, 81, 129 up to level 9, 206 for level 10)
- An enemy **above** your level is worth more: times (1 + the levels it is above you). A level 1 unit that kills a level 3 unit gets 8 x 3 = 24 points and jumps to level 4
- Points to the next level: 3, 5, 8, 12, 20, 31, 50, 81, 129 (every level 1.6 times the one before)

**Death**
- Before Armageddon: the unit comes back after **5 seconds** at a random place far from the others, **one level lower** (never below 1); the points of the level are lost
- Every unit spawns on the land the commanders stand on: on a map with water or islands all of them are on the same piece of land and can reach each other

**Level 10: Armageddon**
- The first player on level 10 brings Armageddon: a message to everybody, big letters on the screen
- The **fog of war is gone**: everybody sees everybody
- From now on a lost unit **does not come back**: that player is out
- **Everybody else allies against level 10**: as long as a player on level 10 is in, all the others are allied with each other and hunt that player together
- When nobody on level 10 is left, the alliance is over and everybody fights on their own again (a new player on level 10 brings it back)
- The **last one standing wins** (allies of the start together); others may still reach level 10 in the meantime

![Armageddon: the banner and the window of the gift](../../docs/evolution-armageddon.jpg)

**The gift of level 10**
- Every player who reaches level 10 chooses a gift in a window (click, or the keys 1, 2, 3; a random one after 30 seconds; a computer player chooses at once):
  - **Hell on Earth**: 8 strong ground units rise all over the map; they are yours
  - **Heaven on Earth**: 8 gunships come down around your unit; they are yours
  - **Gates of Hell**: 12 nuclear missiles rain on the map, one every 4 seconds, far from your unit; red rings warn 5 seconds before where they come down
- What the gift kills counts for you; when you are out, the units of your gift blow up

![Gates of Hell: red rings where the next missiles come down](../../docs/evolution-gates-of-hell.jpg)

**Wild units and towers**
- Units of nobody (Gaia) with a tenth of their health stand around the map; about one in seven is a **tower**
- They hold their position and **only shoot back**
- They **grow with the players**: a new one has the level of a random player (sometimes one less); old ones far below the weakest player are replaced by stronger ones, one every 3 seconds
- One per 1024 x 1024 Elmo of the land (a 16 x 16 map without water has 64), at least 12, at most 100; a killed one comes back 10 seconds later somewhere else, and the number is topped up every 10 seconds

**Energy**
- Every player gets **10 energy per second** and can store **1000**: units with laser weapons need it to shoot

**Radars**
- Radars of nobody stand all over the map, until it is covered; they **cannot be destroyed**
- Stand next to one with your unit for **5 seconds** ("Taking 3/5" above it) and it is **yours**: you see more of where the others go; an enemy takes it the same way
- When more than half of the players are on level 5 or higher, the radars become **T2 radars** one by one (a much larger range)
- When a player is out, their radars belong to nobody again

**Beacons and abilities**
- Glowing beacons in five colors lie around the map (you see them where your unit sees); drive over one to get its **ability** until your unit dies (evolving keeps it)
- Each ability is a button in the order menu of your unit; it costs energy and then needs a while before it can be used again (the seconds are on the button)

| Color | Ability | What it does | Energy | Cooldown |
|---|---|---|---|---|
| Violet | Jammer | your unit is hidden from the enemy radar for 20 s | 300 | 60 s |
| Blue | Cloak | your unit is invisible for 15 s (shooting or an enemy close by shows it) | 400 | 60 s |
| Yellow | Sprint | 50 % faster for 8 s | 200 | 30 s |
| Green | Repair | heals 30 % of the health at once | 500 | 90 s |
| Orange | Radar Pulse | your unit sees everything within 2500 Elmo for 5 s | 250 | 45 s |

- A taken beacon comes back 45 seconds later somewhere else, in a new color; a beacon of an ability you already have stays for the others

**Computer players**
- Every team without a human is steered by the game (its own AI is switched off for this unit)
- It picks up the beacons it drives over and uses its abilities by itself
- It attacks only enemies of its **own level or higher** and wild units of its level or lower (in Armageddon every enemy) and otherwise only shoots back; with nothing to attack it walks around

## The ladders

| Level | Armada | Cortex | Legion |
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

Chosen by damage per second times health; artillery, units for water and the bomb bots are left out. Legion units only come with the game option for the Legion faction; without it a level picks Armada or Cortex.

## On the screen

- At the top: one line per team with level, unit, points, kills and deaths (your own line in white; "out" in Armageddon)
- After a respawn the camera jumps to your new unit

## Tips

- Hunt the wild units first, then pick fights with enemies of your level or above
- Take the radars near you early: you see the others coming
- A small map keeps the fights coming: size M or smaller (up to 16 x 16, e.g. Comet Catcher Remake, Trefoil Remake, Argent Strata)
- The game runs in the gadget `evo_game.lua` and the window of the gift in `evo_gift.lua` of the extra game "Level Editor Scenarios" (installed with the Level Editor; a joiner without it gets it from the host)
