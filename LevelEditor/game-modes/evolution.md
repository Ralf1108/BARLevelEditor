# Evolution

[LAN Play](../../docs/lan-play.md) · [Specification](../../specs/evolution.md) · [Start page](../../README.md)

![Evolution in the game: the overview of seven players at the right, your own panel with the abilities at the bottom](../../docs/evolution-game.jpg)

Every player starts with **one weak unit** instead of the commander. Kills give **points**, and enough points **evolve** the unit into a stronger one: 10 levels, from a Pawn up to a tier 3 giant. A lost unit comes back somewhere else, one level lower. The first unit on level 10 brings **Armageddon**: no more fog of war, no more coming back, the last one standing wins. A mode of **LAN Play** on any map: no level, no editor needed.

## In short

- **LAN Play** room: the host presses the green button **LAN Play** in the title row of the room (next to "Leave Lobby"), then **Evolution** in its menu (a submenu with the green / red button On / Off opens); everybody in the room sees it
- When the host switches it on, the rules appear in the chat of the room for everybody (with the tip: a map of size **M or smaller**, up to 16 x 16); the buttons of the menu explain themselves when you hold the mouse over them
- Start the game as usual: humans and computer players all play
- The start positions of the map are used (nobody has to place one)
- **Evolution** in the menu opens a small menu of its own with the settings (hold the mouse over a button for its explanation):
  - **On / Off**: a green button when on, red when off; off is the default
  - **Unit multiplier**: 1x to 10x, click to step through: so many times the normal number of wild units and towers, a denser map
  - **Unit health**: the health the wild units start with, click to step through: **Auto** (the default) is 10 % on level 1, 30 % on levels 2 to 4, 40 % on levels 5 to 7 and 50 % from level 8 (a stronger level starts with more); or one value from 10 % to 100 % for all levels (the health bar of a wild unit shows it)
  - **Regeneration**: On (default) or Off: whether the units of the players heal by themselves (1 % of the health every 5 seconds, starting 5 seconds after the last damage; the tooltip tells the rate)
  - **Long range**: On or Off (off is the default): when on, nine units with a long range (lasers, plasma and rail guns of 850 Elmo or more, no missiles) can appear on their levels too: Sharpshooter, Arquebus, Deadeye, Starlight, Siegebreaker, Daedalus, Thermite, Mukade, Apollyon (the column Long range of the [unit table](evolution-units.md))
  - **Debug mode**: extra buttons above your panel in the game for testing: Armageddon, Level Up (green, arrow up), Level Down (red, arrow down), XP Up / XP Down, one small button per power-up that gives it at once (or, when you have it, makes it ready again without cooldown), a star that gives every player random values (for a picture) and Hide

![The menu LAN Play of the room: the submenu Evolution with On / Off, Unit multiplier, Unit health, Regeneration, Long range and Debug mode](../../docs/evolution-room.jpg)

![The help window at the start of the game: power-ups, the units of every level, Armageddon](../../docs/evolution-help.jpg)

## Rules

**Your unit**
- Every team starts with one level 1 unit where its commander would stand; all other units are gone
- Every new unit is of a **random faction** (Armada, Cortex or Legion): a Pawn can become a Brute and then a Karkinos
- The new unit replaces the old one where it stands; it has the health fraction of the old unit plus 20 % (not a full heal); it keeps its orders and is selected again by itself

**Points**
- A wild unit or tower: a third of what its level costs (1 for level 1, 2 for level 2, 3, 4, 7, 10, 17, 27, 43, 69): about three of your own level bring you up
- **Catching up**: who is behind gets more for every kill: half the points more for every level below the best player (on level 1 next to a player on level 5: three times the points)
- An enemy player of level *v*: the points that level costs (3 for level 1, 5, 8, 12, 20, 31, 50, 81, 129 up to level 9, 206 for level 10)
- An enemy **above** your level is worth more: times (1 + the levels it is above you). A level 1 unit that kills a level 3 unit gets 8 x 3 = 24 points and jumps to level 4
- Points to the next level: 3, 5, 8, 12, 20, 31, 50, 81, 129 (every level 1.6 times the one before)

**Experience**
- Every kill of another player gives your unit 0.1 experience (the game's own bonus: a little more health, damage and faster reloading); you keep it when you level up
- Every death costs 0.1 again

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
  - **Hell on Earth**: 8 tier 3 units rise all over the map; when one of them is lost a new one rises somewhere, and one more every 30 seconds; they are yours
  - **Heaven on Earth**: 8 Dragons (heavy gunships) come down on a hexagon around your unit, a little way off; when one is lost a new one comes down near you, and one more at a random place every 30 seconds; they are yours
  - **Gates of Hell**: first a barrage of nuclear missiles all at once at random places of the map (10 per player, at least 20); the red rings warn everybody 5 seconds before where each one comes down. Then the missiles never stop and get worse: every human enemy has missiles of his own that follow him (one at first, two after two minutes, then one more every two minutes), the volleys come every 10 seconds at first and every 3 seconds after four minutes. They start 2000 Elmo from the enemy and come closer and closer, until there is no way out; computer players are not followed. Your own unit and your allies are never hit
- What the gift kills counts for you; when you are out, the units of your gift blow up


**Wild units and towers**
- Units of nobody (Gaia) with only 10 % of their health on level 1 (30 % on levels 2 to 4, 40 % on levels 5 to 7, 50 % from level 8; the health bar shows it) stand around the map; about one in seven is a **tower** (a tower does half of its normal damage)
- Most of them **walk around** the map, about one in five stands still (and the towers), and they **only shoot back**
- They **grow with the weakest player**: a new one has the level of the weakest player who is still in; one above it is replaced at once by one of its level (so the weakest player always has a chance), one two or more levels below it too, one every 3 seconds
- One per 1024 x 1024 Elmo of the land (a 16 x 16 map without water has 64), at least 12, at most 100; a killed one comes back 10 seconds later somewhere else, and the number is topped up every 10 seconds

**Regeneration**
- Your unit regenerates **1 % of its health every 5 seconds**, but only when it has not been hit for 5 seconds

**Energy**
- Every player gets **5 energy per second plus 3 for every level** (level 1: 8, level 8: 29) and can store **1000**: units with laser weapons need it to shoot, the abilities cost it
- **More energy**: solar collectors and wind turbines of nobody stand around the map; they cannot be destroyed. Stand next to one for 5 seconds ("Taking 3/5") and its energy is yours (a solar collector about 20 per second, a wind turbine as much as the wind gives); an enemy takes it the same way

**Radars**
- Radars of nobody stand all over the map, until it is covered; they **cannot be destroyed**
- Stand next to one with your unit for **5 seconds** ("Taking 3/5" above it) and it is **yours**: you see more of where the others go; an enemy takes it the same way
- When more than half of the players are on level 5 or higher, the radars become **T2 radars** one by one (a much larger range)
- When a player is out, their radars belong to nobody again

**Beacons and abilities**
- Glowing beacons in five colors lie around the map (you see them where your unit sees); drive over one to get its **ability** until your unit dies (evolving keeps it)
- Your abilities are the five colored buttons in your panel at the bottom of the screen, always in the same place with a symbol (a double arrow, a plus, radar waves, a crossed out eye, a zigzag wave): grey until you have one, then in its color; click to use it; it costs energy and then needs a while before it can be used again (while an ability works, a fill in its color runs down the button and the number at the top left counts the seconds it lasts; when it is over, the cooldown starts: a grey fill runs down and the number counts the seconds down); hold the mouse over a button to read what it does
- The overview at the right shows which abilities every player has (the symbols only, no cooldowns). The button at its top right hides and shows the list; with many players it stops above the music player and scrolls with the mouse wheel (the highest level is always on top)

| Color | Ability | What it does | Energy | Cooldown |
|---|---|---|---|---|
| Blue | Sprint | 50 % faster for 8 s | 200 | 30 s |
| Green | Repair | heals 20 % of the health at once (at full health the button says "not needed" and a click does nothing) | 500 | 60 s |
| Orange | Radar Pulse | your unit sees everything within 2500 Elmo for 5 s | 250 | 45 s |
| Yellow | Cloak | your unit is invisible to the enemy for 15 s (even right next to it); when it fires it is seen and the cloak ends | 400 | 60 s |
| Violet | Jammer | your unit is hidden from the enemy radar and sonar and jams radar for 20 s | 300 | 60 s |

- At the start there are 2 to 6 beacons of every color, more on a bigger map and with more players; a taken beacon comes back 45 seconds later somewhere else, in the same color; a beacon of an ability you already have stays for the others

**Computer players**
- Every team without a human is steered by the game (its own AI is switched off for this unit)
- It picks up the beacons it drives over and uses its abilities by itself
- It also takes radars, solar collectors and wind turbines: it goes to the nearest one that is not its own and stands next to it until it is taken (unless an enemy is close), but it does not hold more than its share
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

Chosen by damage per second times health; artillery, units for water and the bomb bots are left out. Evolution always plays with the Legion faction and the Extra Units Pack (the host switches both on by itself).

## On the screen

- At the right edge, below the bars of the game: one compact row per team, the highest level on top: at the left level badge, name, the points now and needed for the next level ("4/12") and the experience ("XP 0.3"), a column with kills above deaths, at the right the abilities as large squares (like your own panel) (your own row lighter; "out" in Armageddon)
- At the bottom, left of the music player: your own unit, big: level, unit, points bar, a violet **XP bar** (the experience bonus you keep: +0.1 per kill of a player, -0.1 per death), kills, deaths and the buttons of your abilities
- Everything scales with the size of the window
- After a respawn the camera jumps to your new unit
- At the start of the game (for 40 seconds) a **help window** explains the power-ups, shows every level with example units of the three factions (picture and name; every level has more units, see the [unit table](evolution-units.md)) and what Armageddon brings; the button **?** at the title of the overview opens and closes it; a click anywhere outside the window closes it too
- The button with the arrow at the top right of the overview folds the list away to the right; with many players it scrolls with the mouse wheel

## Quick start for testing

`start_evolution.bat` in the folder LevelEditor starts at once a game of you against one SimpleAI on Hooked 1.1 with the debug mode on. Another map or computer player: `start_evolution.bat "Comet Catcher Remake 1.8" SimpleDefenderAI`.

## Tips

- Hunt the wild units first, then pick fights with enemies of your level or above
- Take the radars near you early: you see the others coming
- A small map keeps the fights coming: size M or smaller (up to 16 x 16, e.g. Comet Catcher Remake, Trefoil Remake, Argent Strata)
- The game runs in the gadget `evo_game.lua` and the window of the gift in `evo_gift.lua` of the extra game "Level Editor Scenarios" (installed with the Level Editor; a joiner without it gets it from the host)

## Unit candidates

The table of all units that can be used for Evolution, with their type, tech level, damage per second and the level they would get: [Unit candidates](evolution-units.md) (also as [evolution_units.csv](evolution_units.csv) for Excel).
