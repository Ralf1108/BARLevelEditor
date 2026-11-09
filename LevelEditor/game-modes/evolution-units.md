# Evolution: unit candidates

[Evolution](evolution.md) · [Specification](../../specs/evolution.md) · [Start page](../../README.md)

Every mobile ground unit of Armada, Cortex and Legion that may be used for Evolution, with the level it would get: the level whose current units (column *On ladder*) have the closest damage per second times health. Left out: Scavenger and Raptor units, constructors, aircraft, water units, units without a ground weapon (radar, jammers, spies, anti air, crawling bombs), artillery and rocket launchers, mine layers, the Epic and Archaic variants, Tumbleweeds, commanders and drones. DPS: against the default armor, without anti air, paralyzers and the D-gun. Also as a table for Excel: [evolution_units.csv](evolution_units.csv). Both are made by `LevelEditor/test-data/tools/evolution_units.py` from the numbers of the game (`zz_unitdump.lua`).

| Level | On ladder | Faction | Name | Unit | Type | Tech | DPS | Health | Metal | Speed | Range | Note |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 1 |  | Armada | Tick | armflea | Bot | 1 | 40 | 60 | 21 | 132 | 140 |  |
| 1 |  | Armada | Rover | armfav | Vehicle | 1 | 35 | 105 | 31 | 168 | 180 |  |
| 1 |  | Armada | Seeker | armsh | Hover | 1 | 60 | 290 | 85 | 114 | 230 |  |
| 1 |  | Armada | Whistler | armsam | Vehicle | 1 | 26 | 820 | 150 | 55 | 550 |  |
| 1 | 1 | Armada | Pawn | armpw | Bot | 1 | 90 | 370 | 54 | 87 | 180 |  |
| 1 |  | Cortex | Rascal | corfav | Vehicle | 1 | 32 | 90 | 26 | 153 | 180 |  |
| 1 |  | Cortex | Goon | corsh | Hover | 1 | 60 | 255 | 75 | 110 | 230 |  |
| 1 | 1 | Cortex | Grunt | corak | Bot | 1 | 74 | 280 | 43 | 81 | 215 |  |
| 1 |  | Cortex | Lasher | cormist | Vehicle | 1 | 25 | 860 | 155 | 52 | 575 |  |
| 1 |  | Legion | Wheelie | legscout | Vehicle | 1 | 24 | 75 | 23 | 160 | 169 |  |
| 1 |  | Legion | Goblin | leggob | Bot | 1 | 27 | 200 | 30 | 75 | 261 |  |
| 1 |  | Legion | Glaucus | legsh | Hover | 1 | 60 | 220 | 60 | 102 | 260 |  |
| 1 |  | Legion | Satyr | leglob | Bot | 1 | 30 | 550 | 60 | 51 | 400 |  |
| 1 | 1 | Legion | Alaris | leghades | Vehicle | 1 | 42 | 425 | 65 | 99 | 211 |  |
| 1 |  | Legion | Salacia | legmh | Hover | 1 | 53 | 520 | 190 | 70 | 700 |  |
| 1 |  | Legion | Lance | legrail | Vehicle | 1 | 27 | 1100 | 240 | 47 | 650 |  |
| 2 |  | Armada | Mace | armham | Bot | 1 | 60 | 1000 | 130 | 46 | 380 |  |
| 2 | 2 | Armada | Blitz | armflash | Vehicle | 1 | 90 | 730 | 110 | 101 | 180 |  |
| 2 |  | Armada | Sprinter | armfast | Bot | 2 | 120 | 690 | 160 | 111 | 230 |  |
| 2 |  | Armada | Gremlin | armgremlin | Vehicle | 2 | 88 | 1060 | 230 | 71 | 220 |  |
| 2 |  | Armada | Pincer | armpincer | Vehicle | 1 | 77 | 1340 | 200 | 63 | 305 |  |
| 2 |  | Armada | Crocodile | armanac | Hover | 1 | 70 | 1530 | 270 | 70 | 370 |  |
| 2 |  | Armada | Platypus | armamph | Hover | 2 | 109 | 1170 | 260 | 90 | 275 |  |
| 2 |  | Cortex | Thug | corthud | Bot | 1 | 60 | 1100 | 140 | 45 | 380 |  |
| 2 |  | Cortex | Torch | cortorch | Vehicle | 1 | 116 | 650 | 220 | 141 | 280 |  |
| 2 | 2 | Cortex | Incisor | corgator | Vehicle | 1 | 94 | 820 | 120 | 85 | 230 |  |
| 2 |  | Cortex | Garpike | corgarp | Vehicle | 1 | 77 | 1420 | 220 | 59 | 305 |  |
| 2 |  | Cortex | Cayman | corsnap | Hover | 1 | 70 | 1720 | 300 | 67 | 370 |  |
| 2 |  | Legion | Belcher | legbart | Bot | 2 | 30 | 1780 | 550 | 60 | 625 |  |
| 2 |  | Legion | Nereus | legner | Hover | 1 | 61 | 1100 | 220 | 76 | 370 |  |
| 2 | 2 | Legion | Phobos | legcen | Bot | 1 | 107 | 840 | 140 | 90 | 180 |  |
| 2 |  | Legion | Cetus | legamphtank | Vehicle | 1 | 77 | 1340 | 200 | 63 | 305 |  |
| 2 |  | Legion | Helios | leghelios | Vehicle | 1 | 104 | 1000 | 160 | 75 | 320 |  |
| 2 |  | Legion | Quickshot | legmrv | Vehicle | 2 | 120 | 970 | 210 | 135 | 240 |  |
| 3 |  | Armada | Sharpshooter | armsnipe | Bot | 2 | 250 | 580 | 680 | 33 | 900 |  |
| 3 |  | Armada | Stout | armstump | Vehicle | 1 | 81 | 1800 | 225 | 75 | 350 |  |
| 3 |  | Armada | Jaguar | armlatnk | Vehicle | 2 | 147 | 1060 | 330 | 90 | 300 |  |
| 3 | 3 | Armada | Centurion | armwar | Bot | 1 | 183 | 1590 | 270 | 45 | 325 |  |
| 3 |  | Cortex | Pounder | corlevlr | Vehicle | 1 | 106 | 1400 | 220 | 40 | 315 |  |
| 3 | 3 | Cortex | Brute | corraid | Vehicle | 1 | 81 | 2000 | 235 | 72 | 350 |  |
| 3 | 4 | Cortex | Fiend | corpyro | Bot | 2 | 240 | 1060 | 200 | 83 | 230 |  |
| 3 |  | Legion | Gladiator | legaskirmtank | Vehicle | 2 | 105 | 2500 | 450 | 65 | 600 |  |
| 3 |  | Legion | Arquebus | legsrail | Bot | 2 | 121 | 2200 | 750 | 42 | 850 |  |
| 4 | 4 | Armada | Welder | armzeus | Bot | 2 | 129 | 3500 | 350 | 48 | 280 |  |
| 4 |  | Armada | Gunslinger | armmav | Bot | 2 | 265 | 1800 | 650 | 50 | 365 |  |
| 4 |  | Armada | Turtle | armcroc | Vehicle | 2 | 141 | 5000 | 750 | 54 | 480 |  |
| 4 |  | Cortex | Banisher | corban | Vehicle | 2 | 133 | 2500 | 1000 | 54 | 800 |  |
| 4 |  | Cortex | Alligator | corseal | Vehicle | 2 | 129 | 2600 | 480 | 72 | 440 |  |
| 4 |  | Cortex | Salamander | corsala | Vehicle | 2 | 164 | 2100 | 350 | 72 | 340 |  |
| 4 |  | Cortex | Duck | coramph | Bot | 2 | 174 | 2350 | 330 | 56 | 400 |  |
| 4 |  | Cortex | Deadeye | cordeadeye | Bot | 2 | 208 | 2700 | 1050 | 40 | 850 |  |
| 4 | 3 | Legion | Karkinos | legkark | Bot | 1 | 189 | 1725 | 310 | 42 | 360 |  |
| 4 |  | Legion | Phalanx | legshot | Bot | 2 | 105 | 3350 | 470 | 44 | 280 |  |
| 4 |  | Legion | Hoplite | legstr | Bot | 2 | 240 | 1780 | 355 | 84 | 280 |  |
| 4 | 4 | Legion | Decurion | leggat | Vehicle | 1 | 180 | 2550 | 300 | 45 | 361 |  |
| 5 |  | Armada | Fatboy | armfboy | Bot | 2 | 114 | 7800 | 1400 | 30 | 700 |  |
| 5 | 5 | Armada | Bull | armbull | Vehicle | 2 | 246 | 4650 | 950 | 62 | 460 |  |
| 5 |  | Armada | Starlight | armmanni | Vehicle | 2 | 532 | 2800 | 1200 | 42 | 950 |  |
| 5 | 6 | Armada | Marauder | armmar | Bot | 3 | 336 | 4900 | 970 | 95 | 350 |  |
| 5 |  | Armada | units.names.armprowl | armprowl | Vehicle | 3 | 336 | 4900 | 970 | 95 | 350 |  |
| 5 |  | Armada | Lunkhead | armlun | Hover | 3 | 318 | 5300 | 1150 | 50 | 575 |  |
| 5 | 5 | Cortex | Tiger | correap | Vehicle | 2 | 150 | 5300 | 690 | 69 | 410 |  |
| 5 |  | Cortex | Termite | cortermite | Bot | 2 | 331 | 3100 | 540 | 50 | 340 |  |
| 5 |  | Cortex | Heat Tiger | corftiger | Vehicle | 2 | 207 | 5300 | 665 | 71 | 410 |  |
| 5 |  | Cortex | Cataphract | corsok | Hover | 3 | 279 | 4200 | 950 | 45 | 725 |  |
| 5 |  | Cortex | Poison Arrow | corparrow | Vehicle | 2 | 206 | 6300 | 1050 | 51 | 575 |  |
| 5 |  | Cortex | Halberd | corhal | Hover | 1 | 344 | 4350 | 640 | 45 | 300 |  |
| 5 |  | Cortex | Siegebreaker | corsiegebreaker | Vehicle | 2 | 500 | 3000 | 1100 | 54 | 910 |  |
| 5 |  | Cortex | Laser Tiger | corgatreap | Vehicle | 2 | 326 | 5000 | 1400 | 69 | 620 |  |
| 5 |  | Legion | Triton | legfloat | Hover | 2 | 205 | 3500 | 650 | 55 | 550 |  |
| 5 |  | Legion | Cardea | legcar | Hover | 1 | 280 | 3600 | 550 | 51 | 321 |  |
| 5 |  | Legion | Charybdis | legehovertank | Hover | 3 | 221 | 4900 | 1350 | 63 | 500 |  |
| 5 |  | Legion | Pilum | legbunk | Bot | 3 | 158 | 9400 | 1500 | 82 | 650 |  |
| 6 |  | Cortex | Tzar | corgol | Vehicle | 2 | 257 | 7800 | 1650 | 39 | 650 |  |
| 6 | 6 | Cortex | Sumo | corcan | Bot | 2 | 344 | 6000 | 560 | 38 | 275 |  |
| 6 | 5 | Legion | Javelin | legjav | Bot | 3 | 360 | 7200 | 1200 | 68 | 450 |  |
| 6 |  | Legion | Telchine | legamph | Bot | 2 | 1107 | 2750 | 600 | 48 | 600 |  |
| 7 | 7 | Armada | Meatball | armmeatball | Bot | 3 | 667 | 8000 | 3000 | 30 | 800 |  |
| 7 | 7 | Cortex | Shiva | corshiva | Bot | 3 | 407 | 9400 | 1700 | 48 | 800 |  |
| 7 | 8 | Cortex | Karganeth | corkarg | Bot | 3 | 600 | 12500 | 2500 | 45 | 600 |  |
| 7 | 6 | Legion | Prometheus | legaheattank | Vehicle | 2 | 750 | 5700 | 1050 | 52 | 450 |  |
| 8 | 8 | Armada | Razorback | armraz | Bot | 3 | 1050 | 13300 | 3800 | 69 | 475 |  |
| 8 |  | Cortex | Mammoth | corsumo | Bot | 2 | 503 | 15600 | 2200 | 23 | 650 |  |
| 8 | 7 | Legion | Incinerator | leginc | Bot | 2 | 990 | 9000 | 2300 | 24 | 725 |  |
| 8 | 8 | Legion | Keres | legkeres | Vehicle | 3 | 535 | 21000 | 2600 | 48 | 481 |  |
| 8 |  | Legion | Daedalus | legerailtank | Vehicle | 3 | 800 | 16500 | 6500 | 61 | 1000 |  |
| 9 | 9 | Armada | Thor | armthor | Vehicle | 3 | 968 | 56000 | 9000 | 54 | 540 |  |
| 9 |  | Cortex | Thermite | corthermite | Bot | 3 | 1400 | 15000 | 3500 | 42 | 900 |  |
| 9 | 9 | Cortex | Demon | cordemon | Bot | 3 | 1440 | 18000 | 6000 | 63 | 500 |  |
| 9 | 9 | Legion | Praetorian | legeshotgunmech | Bot | 3 | 1233 | 22000 | 7000 | 72 | 700 |  |
| 9 |  | Legion | Mukade | legpede | Bot | 3 | 1174 | 28000 | 5500 | 51 | 850 |  |
| 10 | 10 | Armada | Titan | armbanth | Bot | 3 | 1450 | 69000 | 13500 | 46 | 860 |  |
| 10 |  | Cortex | Behemoth | corjugg | Bot | 3 | 821 | 335000 | 20000 | 17 | 550 |  |
| 10 | 10 | Cortex | Juggernaut | corkorg | Bot | 3 | 4220 | 149000 | 29000 | 37 | 950 |  |
| 10 |  | Legion | Apollyon | legapollyon | Vehicle | 3 | 4298 | 56000 | 15000 | 38 | 1200 |  |
| 10 | 10 | Legion | Sol Invictus | legeheatraymech | Bot | 3 | 2680 | 110000 | 23500 | 40 | 800 |  |
