# Evolution: unit candidates

[Evolution](evolution.md) · [Specification](../../specs/evolution.md) · [Start page](../../README.md)

Every mobile ground unit of Armada, Cortex and Legion that may be used for Evolution, with the level it would get. **How the level is found:** *Score* = DPS times health (the strength in a fight of one against one). The units that are in the game now (column *Included in Evolution*: the unit is in the game already, the number is its level there; the current ladder of `evo_game.lua`, three per level) are the yardstick: the score of a level is the geometric mean of its three ladder units, and a unit gets the level whose score is closest to its own (on a logarithmic scale). One manual change: Telchine on level 7. Long range = yes: laser, plasma and rail gun units of 850 Elmo or more (no missiles) that only join when the option Long range of the room is on. Left out: Scavenger and Raptor units, constructors, aircraft, water units, units without a ground weapon (radar, jammers, spies, anti air, crawling bombs), artillery and rocket launchers, mine layers, the Epic and Archaic variants, Tumbleweeds, the scouts (DPS times health below 10000) and the weak support vehicles (DPS below 40), commanders and drones. DPS: against the default armor, without anti air, paralyzers and the D-gun. Also as a table for Excel: [evolution_units.csv](evolution_units.csv). Both are made by `LevelEditor/test-data/tools/evolution_units.py` from the numbers of the game (`zz_unitdump.lua`).

**The ranges of the levels** (DPS x health): a unit gets the level whose range holds its score; the borders lie in the middle (geometric mean) between the reference scores of two levels.

| Level | Reference (3 units in the game) | From | To |
|---|---|---|---|
| 1 | 23,038 | 0 | 42,089 |
| 2 | 76,892 | 42,089 | 138,233 |
| 3 | 248,508 | 138,233 | 305,416 |
| 4 | 375,357 | 305,416 | 706,545 |
| 5 | 1,329,951 | 706,545 | 1,800,976 |
| 6 | 2,438,823 | 1,800,976 | 3,717,160 |
| 7 | 5,665,554 | 3,717,160 | 7,734,655 |
| 8 | 10,559,408 | 7,734,655 | 18,850,765 |
| 9 | 33,652,582 | 18,850,765 | 94,381,420 |
| 10 | 264,700,416 | 94,381,420 | no limit |

Telchine is the one exception (set to level 7 by hand).

| Level (DPS x health) | Included in Evolution | Faction | Name | Unit | Type | Tech | DPS | Health | Score | Metal | Speed | Range | Long range | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 |  | Armada | Seeker | armsh | Hover | 1 | 60 | 290 | 17400 | 85 | 114 | 230 |  |  |
| 1 | 1 | Armada | Pawn | armpw | Bot | 1 | 90 | 370 | 33300 | 54 | 87 | 180 |  |  |
| 1 |  | Cortex | Goon | corsh | Hover | 1 | 60 | 255 | 15300 | 75 | 110 | 230 |  |  |
| 1 | 1 | Cortex | Grunt | corak | Bot | 1 | 74 | 280 | 20720 | 43 | 81 | 215 |  |  |
| 1 |  | Legion | Glaucus | legsh | Hover | 1 | 60 | 220 | 13200 | 60 | 102 | 260 |  |  |
| 1 | 1 | Legion | Alaris | leghades | Vehicle | 1 | 42 | 425 | 17722 | 65 | 99 | 211 |  |  |
| 1 |  | Legion | Salacia | legmh | Hover | 1 | 53 | 520 | 27716 | 190 | 70 | 700 |  |  |
| 2 |  | Armada | Mace | armham | Bot | 1 | 60 | 1000 | 60000 | 130 | 46 | 380 |  |  |
| 2 | 2 | Armada | Blitz | armflash | Vehicle | 1 | 90 | 730 | 65700 | 110 | 101 | 180 |  |  |
| 2 |  | Armada | Sprinter | armfast | Bot | 2 | 120 | 690 | 82800 | 160 | 111 | 230 |  |  |
| 2 |  | Armada | Gremlin | armgremlin | Vehicle | 2 | 88 | 1060 | 92750 | 230 | 71 | 220 |  |  |
| 2 |  | Armada | Pincer | armpincer | Vehicle | 1 | 77 | 1340 | 103582 | 200 | 63 | 305 |  |  |
| 2 |  | Armada | Crocodile | armanac | Hover | 1 | 70 | 1530 | 107100 | 270 | 70 | 370 |  |  |
| 2 |  | Armada | Platypus | armamph | Hover | 2 | 109 | 1170 | 127647 | 260 | 90 | 275 |  |  |
| 2 |  | Cortex | Thug | corthud | Bot | 1 | 60 | 1100 | 66000 | 140 | 45 | 380 |  |  |
| 2 |  | Cortex | Torch | cortorch | Vehicle | 1 | 116 | 650 | 75335 | 220 | 141 | 280 |  |  |
| 2 | 2 | Cortex | Incisor | corgator | Vehicle | 1 | 94 | 820 | 76916 | 120 | 85 | 230 |  |  |
| 2 |  | Cortex | Garpike | corgarp | Vehicle | 1 | 77 | 1420 | 109766 | 220 | 59 | 305 |  |  |
| 2 |  | Cortex | Cayman | corsnap | Hover | 1 | 70 | 1720 | 120400 | 300 | 67 | 370 |  |  |
| 2 |  | Legion | Nereus | legner | Hover | 1 | 61 | 1100 | 67210 | 220 | 76 | 370 |  |  |
| 2 | 2 | Legion | Phobos | legcen | Bot | 1 | 107 | 840 | 89964 | 140 | 90 | 180 |  |  |
| 2 |  | Legion | Cetus | legamphtank | Vehicle | 1 | 77 | 1340 | 103582 | 200 | 63 | 305 |  |  |
| 2 |  | Legion | Helios | leghelios | Vehicle | 1 | 104 | 1000 | 103800 | 160 | 75 | 320 |  |  |
| 2 |  | Legion | Quickshot | legmrv | Vehicle | 2 | 120 | 970 | 116400 | 210 | 135 | 240 |  |  |
| 3 |  | Armada | Sharpshooter | armsnipe | Bot | 2 | 250 | 580 | 145000 | 680 | 33 | 900 | yes |  |
| 3 |  | Armada | Stout | armstump | Vehicle | 1 | 81 | 1800 | 145440 | 225 | 75 | 350 |  |  |
| 3 |  | Armada | Jaguar | armlatnk | Vehicle | 2 | 147 | 1060 | 155502 | 330 | 90 | 300 |  |  |
| 3 | 3 | Armada | Centurion | armwar | Bot | 1 | 183 | 1590 | 291447 | 270 | 45 | 325 |  |  |
| 3 |  | Cortex | Pounder | corlevlr | Vehicle | 1 | 106 | 1400 | 147840 | 220 | 40 | 315 |  |  |
| 3 | 3 | Cortex | Brute | corraid | Vehicle | 1 | 81 | 2000 | 161600 | 235 | 72 | 350 |  |  |
| 3 | 4 | Cortex | Fiend | corpyro | Bot | 2 | 240 | 1060 | 254400 | 200 | 83 | 230 |  |  |
| 3 |  | Legion | Gladiator | legaskirmtank | Vehicle | 2 | 105 | 2500 | 262500 | 450 | 65 | 600 |  |  |
| 3 |  | Legion | Arquebus | legsrail | Bot | 2 | 121 | 2200 | 267080 | 750 | 42 | 850 | yes |  |
| 4 | 4 | Armada | Welder | armzeus | Bot | 2 | 129 | 3500 | 452900 | 350 | 48 | 280 |  |  |
| 4 |  | Armada | Gunslinger | armmav | Bot | 2 | 265 | 1800 | 477000 | 650 | 50 | 365 |  |  |
| 4 |  | Armada | Turtle | armcroc | Vehicle | 2 | 141 | 5000 | 703000 | 750 | 54 | 480 |  |  |
| 4 |  | Cortex | Banisher | corban | Vehicle | 2 | 133 | 2500 | 333250 | 1000 | 54 | 800 |  |  |
| 4 |  | Cortex | Alligator | corseal | Vehicle | 2 | 129 | 2600 | 335140 | 480 | 72 | 440 |  |  |
| 4 |  | Cortex | Salamander | corsala | Vehicle | 2 | 164 | 2100 | 343560 | 350 | 72 | 340 |  |  |
| 4 |  | Cortex | Duck | coramph | Bot | 2 | 174 | 2350 | 408900 | 330 | 56 | 400 |  |  |
| 4 |  | Cortex | Deadeye | cordeadeye | Bot | 2 | 208 | 2700 | 562950 | 1050 | 40 | 850 | yes |  |
| 4 | 3 | Legion | Karkinos | legkark | Bot | 1 | 189 | 1725 | 325852 | 310 | 42 | 360 |  |  |
| 4 |  | Legion | Phalanx | legshot | Bot | 2 | 105 | 3350 | 351750 | 470 | 44 | 280 |  |  |
| 4 |  | Legion | Hoplite | legstr | Bot | 2 | 240 | 1780 | 427200 | 355 | 84 | 280 |  |  |
| 4 | 4 | Legion | Decurion | leggat | Vehicle | 1 | 180 | 2550 | 459000 | 300 | 45 | 361 |  |  |
| 5 |  | Armada | Fatboy | armfboy | Bot | 2 | 114 | 7800 | 891540 | 1400 | 30 | 700 |  |  |
| 5 | 5 | Armada | Bull | armbull | Vehicle | 2 | 246 | 4650 | 1141575 | 950 | 62 | 460 |  |  |
| 5 |  | Armada | Starlight | armmanni | Vehicle | 2 | 532 | 2800 | 1489320 | 1200 | 42 | 950 | yes |  |
| 5 | 6 | Armada | Marauder | armmar | Bot | 3 | 336 | 4900 | 1644930 | 970 | 95 | 350 |  |  |
| 5 |  | Armada | units.names.armprowl | armprowl | Vehicle | 3 | 336 | 4900 | 1644930 | 970 | 95 | 350 |  |  |
| 5 |  | Armada | Lunkhead | armlun | Hover | 3 | 318 | 5300 | 1685930 | 1150 | 50 | 575 |  |  |
| 5 | 5 | Cortex | Tiger | correap | Vehicle | 2 | 150 | 5300 | 795000 | 690 | 69 | 410 |  |  |
| 5 |  | Cortex | Termite | cortermite | Bot | 2 | 331 | 3100 | 1027030 | 540 | 50 | 340 |  |  |
| 5 |  | Cortex | Heat Tiger | corftiger | Vehicle | 2 | 207 | 5300 | 1097630 | 665 | 71 | 410 |  |  |
| 5 |  | Cortex | Cataphract | corsok | Hover | 3 | 279 | 4200 | 1172640 | 950 | 45 | 725 |  |  |
| 5 |  | Cortex | Poison Arrow | corparrow | Vehicle | 2 | 206 | 6300 | 1295280 | 1050 | 51 | 575 |  |  |
| 5 |  | Cortex | Halberd | corhal | Hover | 1 | 344 | 4350 | 1495530 | 640 | 45 | 300 |  |  |
| 5 |  | Cortex | Siegebreaker | corsiegebreaker | Vehicle | 2 | 500 | 3000 | 1500000 | 1100 | 54 | 910 | yes |  |
| 5 |  | Cortex | Laser Tiger | corgatreap | Vehicle | 2 | 326 | 5000 | 1631500 | 1400 | 69 | 620 |  |  |
| 5 |  | Legion | Triton | legfloat | Hover | 2 | 205 | 3500 | 717500 | 650 | 55 | 550 |  |  |
| 5 |  | Legion | Cardea | legcar | Hover | 1 | 280 | 3600 | 1008000 | 550 | 51 | 321 |  |  |
| 5 |  | Legion | Charybdis | legehovertank | Hover | 3 | 221 | 4900 | 1081920 | 1350 | 63 | 500 |  |  |
| 5 |  | Legion | Pilum | legbunk | Bot | 3 | 158 | 9400 | 1488020 | 1500 | 82 | 650 |  |  |
| 6 |  | Cortex | Tzar | corgol | Vehicle | 2 | 257 | 7800 | 2005380 | 1650 | 39 | 650 |  |  |
| 6 | 6 | Cortex | Sumo | corcan | Bot | 2 | 344 | 6000 | 2062800 | 560 | 38 | 275 |  |  |
| 6 | 5 | Legion | Javelin | legjav | Bot | 3 | 360 | 7200 | 2592000 | 1200 | 68 | 450 |  |  |
| 7 | 7 | Armada | Meatball | armmeatball | Bot | 3 | 667 | 8000 | 5333600 | 3000 | 30 | 800 |  |  |
| 7 | 7 | Cortex | Shiva | corshiva | Bot | 3 | 407 | 9400 | 3826740 | 1700 | 48 | 800 |  |  |
| 7 | 8 | Cortex | Karganeth | corkarg | Bot | 3 | 600 | 12500 | 7500000 | 2500 | 45 | 600 |  |  |
| 7 |  | Legion | Telchine | legamph | Bot | 2 | 1107 | 2750 | 3043425 | 600 | 48 | 600 |  |  |
| 7 | 6 | Legion | Prometheus | legaheattank | Vehicle | 2 | 750 | 5700 | 4275000 | 1050 | 52 | 450 |  |  |
| 8 | 8 | Armada | Razorback | armraz | Bot | 3 | 1050 | 13300 | 13965000 | 3800 | 69 | 475 |  |  |
| 8 |  | Cortex | Mammoth | corsumo | Bot | 2 | 503 | 15600 | 7851480 | 2200 | 23 | 650 |  |  |
| 8 | 7 | Legion | Incinerator | leginc | Bot | 2 | 990 | 9000 | 8910000 | 2300 | 24 | 725 |  |  |
| 8 | 8 | Legion | Keres | legkeres | Vehicle | 3 | 535 | 21000 | 11241300 | 2600 | 48 | 481 |  |  |
| 8 |  | Legion | Daedalus | legerailtank | Vehicle | 3 | 800 | 16500 | 13200000 | 6500 | 61 | 1000 | yes |  |
| 9 | 9 | Armada | Thor | armthor | Vehicle | 3 | 968 | 56000 | 54191200 | 9000 | 54 | 540 |  |  |
| 9 |  | Cortex | Thermite | corthermite | Bot | 3 | 1400 | 15000 | 21000000 | 3500 | 42 | 900 | yes |  |
| 9 | 9 | Cortex | Demon | cordemon | Bot | 3 | 1440 | 18000 | 25920000 | 6000 | 63 | 500 |  |  |
| 9 | 9 | Legion | Praetorian | legeshotgunmech | Bot | 3 | 1233 | 22000 | 27132600 | 7000 | 72 | 700 |  |  |
| 9 |  | Legion | Mukade | legpede | Bot | 3 | 1174 | 28000 | 32863600 | 5500 | 51 | 850 | yes |  |
| 10 | 10 | Armada | Titan | armbanth | Bot | 3 | 1450 | 69000 | 100050000 | 13500 | 46 | 860 |  |  |
| 10 |  | Cortex | Behemoth | corjugg | Bot | 3 | 821 | 335000 | 275169000 | 20000 | 17 | 550 |  |  |
| 10 | 10 | Cortex | Juggernaut | corkorg | Bot | 3 | 4220 | 149000 | 628809800 | 29000 | 37 | 950 |  |  |
| 10 |  | Legion | Apollyon | legapollyon | Vehicle | 3 | 4298 | 56000 | 240660000 | 15000 | 38 | 1200 | yes |  |
| 10 | 10 | Legion | Sol Invictus | legeheatraymech | Bot | 3 | 2680 | 110000 | 294800000 | 23500 | 40 | 800 |  |  |
