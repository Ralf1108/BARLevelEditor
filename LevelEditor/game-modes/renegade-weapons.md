# Renegade: the weapons of all units

[Renegade](renegade.md) · [Specification](../../specs/renegade.md) · [Start page](../../README.md)

Which weapon of a unit is fired with which mouse button in Renegade. **Change the last two columns** (and nothing else): the rest is read from the game.

- **Group**: a letter per unit; weapons with the same letter belong together (they are fired together, like the three medium plasma guns of the Epoch). `-` = the weapon is not fired by a button (footsteps, script dummies).
- **Fire button**: `LMB` (left mouse button), `RMB` (right) or `MMB` (middle). A group has one button: the button of the first row of the group counts. Several groups may share a button.
- **Target**: what the weapon can hit (Ground, Air, Water; All = everything). Anti-air weapons cannot take a ground point: they fire at the aircraft you look at.
- The proposal: weapons with the same weapon definition are one group; missiles (missile launchers, starburst, torpedoes, anti-air weapons) and all other groups are sorted by range. Short range on LMB, long range on RMB, missiles on MMB (with two groups only: the short on LMB, the other on RMB; with three or more of the same kind: the shortest on LMB, the next on RMB, all further on MMB).
- A unit that is not in the table (and the Scavenger copies of the units: they use the entry of the normal unit) gets the proposal worked out in the game (`slotsFor` in `renegade_game.lua`).

After a change: `python LevelEditor\test-data\tools\renegade_weapons.py lua` writes the table into `renegade_game.lua` (the block between `-- BEGIN WEAPONS` and `-- END WEAPONS`; do not edit it by hand), then the game gets the new file as usual. The same table is `renegade_weapons.csv` (for Excel; `lua renegade_weapons.csv` reads that one instead). New units or changed weapons: run `pve_test.ps1 -Ren -Widget zz_weapondump.lua` and `python renegade_weapons.py table <infolog.txt>`; your entries stay.

1035 weapons of 497 units.

| Faction | Unit | Code | # | Weapon | Type | Target | Range | Reload | Damage | Weapon name | Group | Fire button |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| Armada | Abductor | armdfly | 1 | Heavy a2g EMP beam | Beam laser | Air+Ground | 520 | 8.0 s | 10500 | armdfly_armdfly_paralyzer | A | LMB |
| Armada | Ambassador | armmerl | 1 | Heavy long-range g2g high-trajectory starburst rocket launcher | Starburst missile | Air+Ground | 1300 | 18.0 s | 2000 | armmerl_armtruck_rocket | A | LMB |
| Armada | Anemone | armdl | 1 | Depthcharge launcher | Torpedo | All | 600 | 1.5 s | 225 | armdl_coax_depthcharge | A | LMB |
| Armada | Arbalest | armflak | 1 | Heavy g2a flak cannon | Cannon | Air | 850 | 0.5 s | 250 (air) | armflak_armflak_gun | A | LMB |
| Armada | Archangel | armaak | 1 | Long-Range Anti-Air Missile Launcher | Missile | Air | 1200 | 1.3 s | 150 (air) | armaak_longrangemissile | B | RMB |
| Armada | Archangel | armaak | 2 | Medium-Range Anti-Air Missile Launcher | Missile | Air | 880 | 0.7 s | 100 (air) | armaak_shortrangemissile | A | LMB |
| Armada | Armada Commander | armcom | 1 | Light close-quarters g2g/g2a laser | Beam laser | Air+Ground | 300 | 0.4 s | 75 | armcom_armcomlaser | B | RMB |
| Armada | Armada Commander | armcom | 2 | Light underwater-combat laser | Beam laser | All | 300 | 1.0 s | 200 | armcom_armcomsealaser | C | MMB |
| Armada | Armada Commander | armcom | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcom_disintegrator | A | LMB |
| Armada | Armada Commander | armcomcon | 1 | Light close-quarters g2g/g2a laser | Beam laser | Air+Ground | 300 | 0.4 s | 75 | armcomcon_armcomlaser | B | RMB |
| Armada | Armada Commander | armcomcon | 2 | Light underwater-combat laser | Beam laser | All | 300 | 1.0 s | 200 | armcomcon_armcomsealaser | C | MMB |
| Armada | Armada Commander | armcomcon | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomcon_disintegrator | A | LMB |
| Armada | Armada Commander Level 10 | armcomlvl10 | 1 | HeavyRockets | Starburst missile | Air+Ground | 870 | 2.0 s | 4400 | armcomlvl10_backlauncher | F | MMB |
| Armada | Armada Commander Level 10 | armcomlvl10 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.3 s | 1400 | armcomlvl10_armcomsealaser | C | RMB |
| Armada | Armada Commander Level 10 | armcomlvl10 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomlvl10_disintegrator | B | RMB |
| Armada | Armada Commander Level 10 | armcomlvl10 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 600 | 8.0 s | 60000 | armcomlvl10_longgun | E | RMB |
| Armada | Armada Commander Level 10 | armcomlvl10 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 500 | 0.1 s | 118 | armcomlvl10_shortgun | D | RMB |
| Armada | Armada Commander Level 10 | armcomlvl10 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armcomlvl10_empflashbang | A | LMB |
| Armada | Armada Commander Level 10 | armdecomlvl10 | 1 | HeavyRockets | Starburst missile | Air+Ground | 870 | 2.0 s | 4400 | armdecomlvl10_backlauncher | F | MMB |
| Armada | Armada Commander Level 10 | armdecomlvl10 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.3 s | 1400 | armdecomlvl10_armcomsealaser | C | RMB |
| Armada | Armada Commander Level 10 | armdecomlvl10 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecomlvl10_disintegrator | B | RMB |
| Armada | Armada Commander Level 10 | armdecomlvl10 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 600 | 8.0 s | 60000 | armdecomlvl10_longgun | E | RMB |
| Armada | Armada Commander Level 10 | armdecomlvl10 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 500 | 0.1 s | 118 | armdecomlvl10_shortgun | D | RMB |
| Armada | Armada Commander Level 10 | armdecomlvl10 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armdecomlvl10_empflashbang | A | LMB |
| Armada | Armada Commander Level 2 | armcomlvl2 | 1 | Scatter Beamer | Beam laser | Air+Ground | 300 | 0.1 s | 14 | armcomlvl2_shortgun | B | RMB |
| Armada | Armada Commander Level 2 | armcomlvl2 | 2 | Light underwater-combat laser | Beam laser | All | 300 | 1.0 s | 400 | armcomlvl2_armcomsealaser | C | MMB |
| Armada | Armada Commander Level 2 | armcomlvl2 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomlvl2_disintegrator | A | LMB |
| Armada | Armada Commander Level 2 | armdecomlvl2 | 1 | Scatter Beamer | Beam laser | Air+Ground | 300 | 0.1 s | 14 | armdecomlvl2_shortgun | B | RMB |
| Armada | Armada Commander Level 2 | armdecomlvl2 | 2 | Light underwater-combat laser | Beam laser | All | 300 | 1.0 s | 400 | armdecomlvl2_armcomsealaser | C | MMB |
| Armada | Armada Commander Level 2 | armdecomlvl2 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecomlvl2_disintegrator | A | LMB |
| Armada | Armada Commander Level 3 | armcomlvl3 | 1 | HeavyRockets | Starburst missile | Air+Ground | 435 | 3.3 s | 550 | armcomlvl3_backlauncher | F | MMB |
| Armada | Armada Commander Level 3 | armcomlvl3 | 2 | J7NSLaser | Beam laser | All | 450 | 0.4 s | 300 | armcomlvl3_armcomsealaser | E | RMB |
| Armada | Armada Commander Level 3 | armcomlvl3 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomlvl3_disintegrator | B | RMB |
| Armada | Armada Commander Level 3 | armcomlvl3 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 410 | 8.0 s | 16000 | armcomlvl3_longgun | D | RMB |
| Armada | Armada Commander Level 3 | armcomlvl3 | 5 | Scatter Beamer | Beam laser | Air+Ground | 350 | 0.1 s | 15 | armcomlvl3_shortgun | C | RMB |
| Armada | Armada Commander Level 3 | armcomlvl3 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armcomlvl3_empflashbang | A | LMB |
| Armada | Armada Commander Level 3 | armdecomlvl3 | 1 | HeavyRockets | Starburst missile | Air+Ground | 435 | 3.3 s | 550 | armdecomlvl3_backlauncher | F | MMB |
| Armada | Armada Commander Level 3 | armdecomlvl3 | 2 | J7NSLaser | Beam laser | All | 450 | 0.4 s | 300 | armdecomlvl3_armcomsealaser | E | RMB |
| Armada | Armada Commander Level 3 | armdecomlvl3 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecomlvl3_disintegrator | B | RMB |
| Armada | Armada Commander Level 3 | armdecomlvl3 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 410 | 8.0 s | 16000 | armdecomlvl3_longgun | D | RMB |
| Armada | Armada Commander Level 3 | armdecomlvl3 | 5 | Scatter Beamer | Beam laser | Air+Ground | 350 | 0.1 s | 15 | armdecomlvl3_shortgun | C | RMB |
| Armada | Armada Commander Level 3 | armdecomlvl3 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armdecomlvl3_empflashbang | A | LMB |
| Armada | Armada Commander Level 4 | armcomlvl4 | 1 | HeavyRockets | Starburst missile | Air+Ground | 550 | 3.3 s | 800 | armcomlvl4_backlauncher | F | MMB |
| Armada | Armada Commander Level 4 | armcomlvl4 | 2 | J7NSLaser | Beam laser | All | 450 | 0.3 s | 400 | armcomlvl4_armcomsealaser | D | RMB |
| Armada | Armada Commander Level 4 | armcomlvl4 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomlvl4_disintegrator | B | RMB |
| Armada | Armada Commander Level 4 | armcomlvl4 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 500 | 8.0 s | 22000 | armcomlvl4_longgun | E | RMB |
| Armada | Armada Commander Level 4 | armcomlvl4 | 5 | Scatter Beamer | Beam laser | Air+Ground | 350 | 0.1 s | 25 | armcomlvl4_shortgun | C | RMB |
| Armada | Armada Commander Level 4 | armcomlvl4 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armcomlvl4_empflashbang | A | LMB |
| Armada | Armada Commander Level 4 | armdecomlvl4 | 1 | HeavyRockets | Starburst missile | Air+Ground | 550 | 3.3 s | 800 | armdecomlvl4_backlauncher | F | MMB |
| Armada | Armada Commander Level 4 | armdecomlvl4 | 2 | J7NSLaser | Beam laser | All | 450 | 0.3 s | 400 | armdecomlvl4_armcomsealaser | D | RMB |
| Armada | Armada Commander Level 4 | armdecomlvl4 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecomlvl4_disintegrator | B | RMB |
| Armada | Armada Commander Level 4 | armdecomlvl4 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 500 | 8.0 s | 22000 | armdecomlvl4_longgun | E | RMB |
| Armada | Armada Commander Level 4 | armdecomlvl4 | 5 | Scatter Beamer | Beam laser | Air+Ground | 350 | 0.1 s | 25 | armdecomlvl4_shortgun | C | RMB |
| Armada | Armada Commander Level 4 | armdecomlvl4 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armdecomlvl4_empflashbang | A | LMB |
| Armada | Armada Commander Level 5 | armcomlvl5 | 1 | HeavyRockets | Starburst missile | Air+Ground | 620 | 2.5 s | 1200 | armcomlvl5_backlauncher | F | MMB |
| Armada | Armada Commander Level 5 | armcomlvl5 | 2 | UltravioletRayBeam | Beam laser | All | 475 | 0.7 s | 1200 | armcomlvl5_armcomsealaser | D | RMB |
| Armada | Armada Commander Level 5 | armcomlvl5 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomlvl5_disintegrator | B | RMB |
| Armada | Armada Commander Level 5 | armcomlvl5 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 550 | 8.0 s | 30000 | armcomlvl5_longgun | E | RMB |
| Armada | Armada Commander Level 5 | armcomlvl5 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 425 | 0.1 s | 42 | armcomlvl5_shortgun | C | RMB |
| Armada | Armada Commander Level 5 | armcomlvl5 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armcomlvl5_empflashbang | A | LMB |
| Armada | Armada Commander Level 5 | armdecomlvl5 | 1 | HeavyRockets | Starburst missile | Air+Ground | 620 | 2.5 s | 1200 | armdecomlvl5_backlauncher | F | MMB |
| Armada | Armada Commander Level 5 | armdecomlvl5 | 2 | UltravioletRayBeam | Beam laser | All | 475 | 0.7 s | 1200 | armdecomlvl5_armcomsealaser | D | RMB |
| Armada | Armada Commander Level 5 | armdecomlvl5 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecomlvl5_disintegrator | B | RMB |
| Armada | Armada Commander Level 5 | armdecomlvl5 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 550 | 8.0 s | 30000 | armdecomlvl5_longgun | E | RMB |
| Armada | Armada Commander Level 5 | armdecomlvl5 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 425 | 0.1 s | 42 | armdecomlvl5_shortgun | C | RMB |
| Armada | Armada Commander Level 5 | armdecomlvl5 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armdecomlvl5_empflashbang | A | LMB |
| Armada | Armada Commander Level 6 | armcomlvl6 | 1 | HeavyRockets | Starburst missile | Air+Ground | 730 | 2.5 s | 1350 | armcomlvl6_backlauncher | F | MMB |
| Armada | Armada Commander Level 6 | armcomlvl6 | 2 | UltravioletRayBeam | Beam laser | All | 475 | 0.5 s | 1200 | armcomlvl6_armcomsealaser | D | RMB |
| Armada | Armada Commander Level 6 | armcomlvl6 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomlvl6_disintegrator | B | RMB |
| Armada | Armada Commander Level 6 | armcomlvl6 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 550 | 8.0 s | 40000 | armcomlvl6_longgun | E | RMB |
| Armada | Armada Commander Level 6 | armcomlvl6 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 425 | 0.1 s | 50 | armcomlvl6_shortgun | C | RMB |
| Armada | Armada Commander Level 6 | armcomlvl6 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armcomlvl6_empflashbang | A | LMB |
| Armada | Armada Commander Level 6 | armdecomlvl6 | 1 | HeavyRockets | Starburst missile | Air+Ground | 730 | 2.5 s | 1350 | armdecomlvl6_backlauncher | F | MMB |
| Armada | Armada Commander Level 6 | armdecomlvl6 | 2 | UltravioletRayBeam | Beam laser | All | 475 | 0.5 s | 1200 | armdecomlvl6_armcomsealaser | D | RMB |
| Armada | Armada Commander Level 6 | armdecomlvl6 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecomlvl6_disintegrator | B | RMB |
| Armada | Armada Commander Level 6 | armdecomlvl6 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 550 | 8.0 s | 40000 | armdecomlvl6_longgun | E | RMB |
| Armada | Armada Commander Level 6 | armdecomlvl6 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 425 | 0.1 s | 50 | armdecomlvl6_shortgun | C | RMB |
| Armada | Armada Commander Level 6 | armdecomlvl6 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armdecomlvl6_empflashbang | A | LMB |
| Armada | Armada Commander Level 7 | armcomlvl7 | 1 | HeavyRockets | Starburst missile | Air+Ground | 730 | 2.5 s | 1800 | armcomlvl7_backlauncher | F | MMB |
| Armada | Armada Commander Level 7 | armcomlvl7 | 2 | UltravioletRayBeam | Beam laser | All | 500 | 0.4 s | 1200 | armcomlvl7_armcomsealaser | D | RMB |
| Armada | Armada Commander Level 7 | armcomlvl7 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomlvl7_disintegrator | B | RMB |
| Armada | Armada Commander Level 7 | armcomlvl7 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 550 | 8.0 s | 56000 | armcomlvl7_longgun | E | RMB |
| Armada | Armada Commander Level 7 | armcomlvl7 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 425 | 0.1 s | 57 | armcomlvl7_shortgun | C | RMB |
| Armada | Armada Commander Level 7 | armcomlvl7 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armcomlvl7_empflashbang | A | LMB |
| Armada | Armada Commander Level 7 | armdecomlvl7 | 1 | HeavyRockets | Starburst missile | Air+Ground | 730 | 2.5 s | 1800 | armdecomlvl7_backlauncher | F | MMB |
| Armada | Armada Commander Level 7 | armdecomlvl7 | 2 | UltravioletRayBeam | Beam laser | All | 500 | 0.4 s | 1200 | armdecomlvl7_armcomsealaser | D | RMB |
| Armada | Armada Commander Level 7 | armdecomlvl7 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecomlvl7_disintegrator | B | RMB |
| Armada | Armada Commander Level 7 | armdecomlvl7 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 550 | 8.0 s | 56000 | armdecomlvl7_longgun | E | RMB |
| Armada | Armada Commander Level 7 | armdecomlvl7 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 425 | 0.1 s | 57 | armdecomlvl7_shortgun | C | RMB |
| Armada | Armada Commander Level 7 | armdecomlvl7 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armdecomlvl7_empflashbang | A | LMB |
| Armada | Armada Commander Level 8 | armcomlvl8 | 1 | HeavyRockets | Starburst missile | Air+Ground | 800 | 2.0 s | 2300 | armcomlvl8_backlauncher | F | MMB |
| Armada | Armada Commander Level 8 | armcomlvl8 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.4 s | 1400 | armcomlvl8_armcomsealaser | C | RMB |
| Armada | Armada Commander Level 8 | armcomlvl8 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomlvl8_disintegrator | B | RMB |
| Armada | Armada Commander Level 8 | armcomlvl8 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 600 | 8.0 s | 60000 | armcomlvl8_longgun | E | RMB |
| Armada | Armada Commander Level 8 | armcomlvl8 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 500 | 0.1 s | 72 | armcomlvl8_shortgun | D | RMB |
| Armada | Armada Commander Level 8 | armcomlvl8 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armcomlvl8_empflashbang | A | LMB |
| Armada | Armada Commander Level 8 | armdecomlvl8 | 1 | HeavyRockets | Starburst missile | Air+Ground | 800 | 2.0 s | 2300 | armdecomlvl8_backlauncher | F | MMB |
| Armada | Armada Commander Level 8 | armdecomlvl8 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.4 s | 1400 | armdecomlvl8_armcomsealaser | C | RMB |
| Armada | Armada Commander Level 8 | armdecomlvl8 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecomlvl8_disintegrator | B | RMB |
| Armada | Armada Commander Level 8 | armdecomlvl8 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 600 | 8.0 s | 60000 | armdecomlvl8_longgun | E | RMB |
| Armada | Armada Commander Level 8 | armdecomlvl8 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 500 | 0.1 s | 72 | armdecomlvl8_shortgun | D | RMB |
| Armada | Armada Commander Level 8 | armdecomlvl8 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armdecomlvl8_empflashbang | A | LMB |
| Armada | Armada Commander Level 9 | armcomlvl9 | 1 | HeavyRockets | Starburst missile | Air+Ground | 870 | 2.0 s | 3600 | armcomlvl9_backlauncher | F | MMB |
| Armada | Armada Commander Level 9 | armcomlvl9 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.3 s | 1400 | armcomlvl9_armcomsealaser | C | RMB |
| Armada | Armada Commander Level 9 | armcomlvl9 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomlvl9_disintegrator | B | RMB |
| Armada | Armada Commander Level 9 | armcomlvl9 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 600 | 8.0 s | 60000 | armcomlvl9_longgun | E | RMB |
| Armada | Armada Commander Level 9 | armcomlvl9 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 500 | 0.1 s | 88 | armcomlvl9_shortgun | D | RMB |
| Armada | Armada Commander Level 9 | armcomlvl9 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armcomlvl9_empflashbang | A | LMB |
| Armada | Armada Commander Level 9 | armdecomlvl9 | 1 | HeavyRockets | Starburst missile | Air+Ground | 870 | 2.0 s | 3600 | armdecomlvl9_backlauncher | F | MMB |
| Armada | Armada Commander Level 9 | armdecomlvl9 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.3 s | 1400 | armdecomlvl9_armcomsealaser | C | RMB |
| Armada | Armada Commander Level 9 | armdecomlvl9 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecomlvl9_disintegrator | B | RMB |
| Armada | Armada Commander Level 9 | armdecomlvl9 | 4 | Arcing Stun Beam | Beam laser | Air+Ground | 600 | 8.0 s | 60000 | armdecomlvl9_longgun | E | RMB |
| Armada | Armada Commander Level 9 | armdecomlvl9 | 5 | Short-Range Lightning Discharge | Lightning | Air+Ground | 500 | 0.1 s | 88 | armdecomlvl9_shortgun | D | RMB |
| Armada | Armada Commander Level 9 | armdecomlvl9 | 6 | EMP Damage-Mitigating Flashbang | Laser | Air+Ground | 3 | 0.2 s | 20000 | armdecomlvl9_empflashbang | A | LMB |
| Armada | Armageddon | armsilo | 1 | Intercontinental ballistic nuclear warhead | Starburst missile | Air+Ground | 72000 | 30.0 s | 12500 | armsilo_nuclear_missile | A | LMB |
| Armada | Armageddon | armsilo | 2 | Nuclear Launch | Cannon | - | 0 | 30.0 s | 0 | armsilo_nuclear_launch | - | - |
| Armada | Assimilator | armassimilator | 1 | scav rapid fire plasma gun | Laser | Air+Ground | 800 | 0.1 s | 33 | armassimilator_machinegun | A | LMB |
| Armada | Asylum | armgatet3 | 1 | PlasmaRepulsor | Shield | - | 710 | 1.0 s | 0 | armgatet3_repulsor | - | - |
| Armada | Attack Drone | armdrone | 1 | Rapid-fire a2g machine guns | Laser | Air+Ground | 350 | 1.8 s | 11 | armdrone_med_emg | A | LMB |
| Armada | Attack Drone | armdroneold | 1 | Railgun | Laser | Air+Ground | 350 | 6.0 s | 100 | armdroneold_railgun | A | LMB |
| Armada | Aurora | armfgate | 1 | NavalPlasmaRepulsor | Shield | - | 10 | 1.0 s | 0 | armfgate_sea_repulsor | - | - |
| Armada | Banshee | armkam | 1 | Rapid-fire close-quarters a2g plasma guns | Plasma | Air+Ground | 350 | 0.7 s | 9 | armkam_emg | A | LMB |
| Armada | Barracuda | armsubk | 1 | Rapid armor-piercing torpedoes | Torpedo | All | 400 | 2.0 s | 350 | armsubk_armsmart_torpedo | A | LMB |
| Armada | Basilica | armbrtha | 1 | Long-range plasma cannon | Plasma | Air+Ground | 4650 | 13.2 s | 1625 | armbrtha_lrpc | A | LMB |
| Armada | Beamer | armbeamer | 1 | Anti-swarm constant wave g2g laser | Beam laser | Ground | 490 | 0.1 s | 27 | armbeamer_armbeamer_weapon | A | LMB |
| Armada | Blitz | armflash | 1 | Rapid-fire close-quarters plasma gun | Plasma | Ground | 180 | 0.3 s | 9 | armflash_emgx | A | LMB |
| Armada | Blizzard | armpnix | 1 | Heavy a2g impulse warheads | Bomb | Air+Ground | 1280 | 7.0 s | 266 | armpnix_armadvbomb | A | LMB |
| Armada | Bull | armbull | 1 | Heavy g2g plasma cannon | Plasma | Air+Ground | 460 | 1.1 s | 270 | armbull_arm_bull | A | LMB |
| Armada | Cauteriser | armnavaldefturret | 1 | Dual Medium Plasma Gauss Cannons | Plasma | Air+Ground | 730 | 0.9 s | 200 | armnavaldefturret_arm_medium_gauss_cannon | A | LMB |
| Armada | Centurion | armwar | 1 | Dual close-quarters g2g laser | Beam laser | Air+Ground | 325 | 0.3 s | 55 | armwar_armwar_laser | A | LMB |
| Armada | Chainsaw | armcir | 1 | Rapid-fire long-range g2a missile barrel | Missile | Air | 1200 | 1.6 s | 250 (air) | armcir_arm_cir | A | LMB |
| Armada | Citadel | armamd | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 1500 | armamd_amd_rocket | - | - |
| Armada | Commander | armdecom | 1 | Light close-quarters g2g laser | Beam laser | Air+Ground | 300 | 0.4 s | 75 | armdecom_armcomlaser | C | MMB |
| Armada | Commander | armdecom | 2 | J7NSLaser | Beam laser | All | 260 | 1.0 s | 63 | armdecom_armcomsealaser | B | RMB |
| Armada | Commander | armdecom | 3 | Decoy-disintegrator | D-gun | All | 250 | 0.9 s | 40 | armdecom_disintegrator | A | LMB |
| Armada | Cormorant | armlance | 1 | Light homing torpedo launcher | Torpedo | All | 400 | 6.0 s | 375 | armlance_armair_torpedo | A | LMB |
| Armada | Corsair | armroy | 1 | Heavy long-range plasma cannon | Plasma | Air+Ground | 700 | 1.6 s | 235 | armroy_plasma | A | LMB |
| Armada | Corsair | armroy | 2 | Depthcharge launcher | Torpedo | All | 400 | 2.0 s | 225 | armroy_depthcharge | B | RMB |
| Armada | Crocodile | armanac | 1 | Medium g2g plasma cannon | Plasma | Air+Ground | 370 | 1.4 s | 98 | armanac_armanac_weapon | A | LMB |
| Armada | Crossbow | armjeth | 1 | Light g2a missile launcher | Missile | Air | 760 | 2.0 s | 110 (air) | armjeth_armbot_missile | A | LMB |
| Armada | Cyclone | armsfig | 1 | Guided a2a missile launcher | Missile | Air | 710 | 0.8 s | 12 | armsfig_armsfig_weapon | A | LMB |
| Armada | Cyclone | armsfig2 | 1 | Guided a2a missile launcher | Missile | Air | 710 | 0.8 s | 12 | armsfig2_armsfig_weapon | A | LMB |
| Armada | Depth Charge Drone | armtdrone | 1 | Depthcharge launcher | Torpedo | All | 200 | 6.0 s | 215 | armtdrone_td_depthcharge | A | LMB |
| Armada | Dolphin | armdecade | 1 | Rapid-fire close-quarters plasma turret | Plasma | Ground | 280 | 0.4 s | 9 | armdecade_emg | A | LMB |
| Armada | Dolphin | armdecade | 2 | Rapid-fire close-quarters plasma turret | Plasma | Ground | 280 | 0.4 s | 9 | armdecade_emg | A | LMB |
| Armada | Dragon's Claw | armclaw | 1 | Close-quarters g2g lightning turret | Lightning | Air+Ground | 430 | 1.1 s | 18 | armclaw_dclaw | A | LMB |
| Armada | Dragon's Fury | armlwall | 1 | Medium Lightning Cannon | Lightning | Air+Ground | 315 | 1.3 s | 64 | armlwall_lightning | A | LMB |
| Armada | Dragonslayer | armaas | 1 | Missiles | Cannon | - | 800 | 0.5 s | 0 | armaas_bogus_missile | - | - |
| Armada | Dragonslayer | armaas | 2 | Long-range g2a guided missile launcher | Missile | Air | 840 | 0.8 s | 63 (air) | armaas_ga2 | B | RMB |
| Armada | Dragonslayer | armaas | 3 | Heavy g2a flak cannon | Cannon | Air | 790 | 0.7 s | 200 (air) | armaas_mobileflak | A | LMB |
| Armada | Dreadnought | armbats | 1 | Heavy long-range g2g plasma cannon | Plasma | Air+Ground | 880 | 1.0 s | 300 | armbats_arm_bats | A | LMB |
| Armada | Dreadnought | armbats | 2 | Heavy long-range g2g plasma cannon | Plasma | Air+Ground | 880 | 1.0 s | 300 | armbats_arm_bats | A | LMB |
| Armada | Eel | armsub | 1 | Light torpedo launcher | Torpedo | All | 500 | 4.0 s | 342 | armsub_torpedo | A | LMB |
| Armada | Ellysaw | armpship | 1 | Light long-range plasma cannon | Plasma | Air+Ground | 470 | 1.2 s | 70 | armpship_plasma | A | LMB |
| Armada | Ellysaw | armpship | 2 | Light long-range plasma cannon | Plasma | Air+Ground | 470 | 1.2 s | 70 | armpship_plasma | A | LMB |
| Armada | Epic Commander - Final Boss | armcomboss | 1 | J8Laser | Beam laser | Air+Ground | 1250 | 0.0 s | 1000 | armcomboss_armcomlaserboss | A | LMB |
| Armada | Epic Commander - Final Boss | armcomboss | 2 | J8NSLaser | Beam laser | All | 1250 | 0.0 s | 1000 | armcomboss_armcomsealaserboss | B | RMB |
| Armada | Epic Commander - Final Boss | armcomboss | 3 | Darkmatter Photon-Disruptor | D-gun | Air+Ground | 1250 | 0.0 s | 999999 | armcomboss_disintegratorxl | C | MMB |
| Armada | Epic Dolphin | armdecadet3 | 1 | Mini Rapid-fire long-range plasma cannon | Plasma | Air+Ground | 1300 | 0.4 s | 210 | armdecadet3_armminivulc_weapon | A | LMB |
| Armada | Epic Dolphin | armdecadet3 | 2 | Mini Rapid-fire long-range plasma cannon | Plasma | Air+Ground | 1300 | 0.4 s | 210 | armdecadet3_armminivulc_weapon | A | LMB |
| Armada | Epic Ellysaw | armpshipt3 | 1 | Rapid-fire close quarters g2g armor-piercing laser | Beam laser | Air+Ground | 475 | 0.6 s | 116 | armpshipt3_mech_rapidlaser | A | LMB |
| Armada | Epic Ellysaw | armpshipt3 | 2 | Rapid-fire close quarters g2g armor-piercing laser | Beam laser | Air+Ground | 475 | 0.6 s | 116 | armpshipt3_mech_rapidlaser | A | LMB |
| Armada | Epic Liche | armlichet4 | 1 | Intercontinental ballistic nuclear warhead | Bomb | Air+Ground | 800 | 120.0 s | 9500 | armlichet4_nuclear_missile | A | LMB |
| Armada | Epic Pawn | armpwt4 | 1 | Rapid-fire huge g2g plasma guns | Plasma | Air+Ground | 450 | 0.2 s | 200 | armpwt4_emg | A | LMB |
| Armada | Epic Pulsar | armannit3 | 1 | Heavy long-range g2g tachyon accelerator beam | Beam laser | Air+Ground | 1800 | 15.0 s | 48000 | armannit3_ata | A | LMB |
| Armada | Epic Recluse | armsptkt4 | 1 | Parabolic trajectory g2g multi-rocket launcher | Missile | Air+Ground | 1000 | 10.0 s | 500 | armsptkt4_adv_rocket | A | LMB |
| Armada | Epic Serpent | armserpt3 | 1 | Heavy guided torpedo launcher | Torpedo | All | 800 | 6.0 s | 1650 | armserpt3_armserp_weapon | A | LMB |
| Armada | Epic Serpent | armserpt3 | 2 | Heavy guided torpedo launcher | Torpedo | All | 800 | 6.0 s | 1650 | armserpt3_armserp_weapon_sub | B | RMB |
| Armada | Epic Serpent | armserpt3 | 3 | Heavy guided torpedo launcher | Torpedo | All | 800 | 6.0 s | 1650 | armserpt3_armserp_weapon_sub | B | RMB |
| Armada | Epic Serpent | armserpt3 | 4 | Heavy guided torpedo launcher | Torpedo | All | 800 | 6.0 s | 1650 | armserpt3_armserp_weapon_sub | B | RMB |
| Armada | Epic Serpent | armserpt3 | 5 | Heavy guided torpedo launcher | Torpedo | All | 800 | 6.0 s | 1650 | armserpt3_armserp_weapon_sub | B | RMB |
| Armada | Epic Skater | armptt2 | 1 | Depthcharge launcher | Torpedo | All | 600 | 1.0 s | 225 | armptt2_coax_depthcharge | A | LMB |
| Armada | Epic Skater | armptt2 | 2 | Depthcharge launcher | Torpedo | All | 600 | 1.0 s | 225 | armptt2_coax_depthcharge | A | LMB |
| Armada | Epic Skater | armptt2 | 3 | Rapid-fire long-range g2a missile barrel | Missile | Air | 1125 | 1.6 s | 170 (air) | armptt2_arm_cir | B | RMB |
| Armada | Epic Stormbringer | armthundt4 | 1 | Ultra Heavy Bombs | Bomb | Air+Ground | 2480 | 4.0 s | 900 | armthundt4_armbomb | A | LMB |
| Armada | Epic Tumbleweed | armvadert4 | 1 | Crawlingbomb Dummy Weapon | Melee | All | 47 | 0.1 s | 20000 | armvadert4_crawl_dummy | B | RMB |
| Armada | Epic Tumbleweed | armvadert4 | 2 | Self-destruction | Cannon | Air+Ground | 1 | 0.1 s | 2000 | armvadert4_crawl_detonator | A | LMB |
| Armada | Epoch | armepoch | 1 | Primary rapid-fire heavy long-range plasma cannon | Plasma | Air+Ground | 2450 | 3.5 s | 500 | armepoch_heavyplasma | B | RMB |
| Armada | Epoch | armepoch | 2 | Secondary rapid-fire heavy plasma cannon | Plasma | Air+Ground | 830 | 1.2 s | 270 | armepoch_mediumplasma | A | LMB |
| Armada | Epoch | armepoch | 3 | Primary rapid-fire heavy long-range plasma cannon | Plasma | Air+Ground | 2450 | 3.5 s | 500 | armepoch_heavyplasma | B | RMB |
| Armada | Epoch | armepoch | 4 | Secondary rapid-fire heavy plasma cannon | Plasma | Air+Ground | 830 | 1.2 s | 270 | armepoch_mediumplasma | A | LMB |
| Armada | Epoch | armepoch | 5 | Secondary rapid-fire heavy plasma cannon | Plasma | Air+Ground | 830 | 1.2 s | 270 | armepoch_mediumplasma | A | LMB |
| Armada | Epoch | armepoch | 6 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 840 | 1.7 s | 150 (air) | armepoch_ferret_missile | C | MMB |
| Armada | Epoch | armepoch | 7 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 840 | 1.7 s | 150 (air) | armepoch_ferret_missile | C | MMB |
| Armada | Excalibur | armexcalibur | 1 | Caliburn s2g tachyon accelerator beam | Beam laser | Air+Ground | 600 | 6.0 s | 800 | armexcalibur_exata | A | LMB |
| Armada | Falcon | armfig | 1 | Light a2a missile launcher | Missile | Air | 680 | 0.9 s | 12 | armfig_armvtol_missile | A | LMB |
| Armada | Fatboy | armfboy | 1 | Heavy AoE g2g plasma cannon | Plasma | Air+Ground | 700 | 7.0 s | 800 | armfboy_arm_fatboy_notalaser | A | LMB |
| Armada | Ferret | armferret | 1 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 950 | 0.6 s | 125 (air) | armferret_ferret_missile | A | LMB |
| Armada | Flying Epoch | armfepocht4 | 1 | Primary rapid-fire heavy long-range plasma cannon | Plasma | Air+Ground | 2450 | 3.5 s | 500 | armfepocht4_heavyplasma | B | RMB |
| Armada | Flying Epoch | armfepocht4 | 2 | Secondary rapid-fire heavy plasma cannon | Plasma | Air+Ground | 830 | 1.2 s | 270 | armfepocht4_mediumplasma | A | LMB |
| Armada | Flying Epoch | armfepocht4 | 3 | Primary rapid-fire heavy long-range plasma cannon | Plasma | Air+Ground | 2450 | 3.5 s | 500 | armfepocht4_heavyplasma | B | RMB |
| Armada | Flying Epoch | armfepocht4 | 4 | Secondary rapid-fire heavy plasma cannon | Plasma | Air+Ground | 830 | 1.2 s | 270 | armfepocht4_mediumplasma | A | LMB |
| Armada | Flying Epoch | armfepocht4 | 5 | Secondary rapid-fire heavy plasma cannon | Plasma | Air+Ground | 830 | 1.2 s | 270 | armfepocht4_mediumplasma | A | LMB |
| Armada | Flying Epoch | armfepocht4 | 6 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 840 | 1.7 s | 150 (air) | armfepocht4_ferret_missile | C | MMB |
| Armada | Flying Epoch | armfepocht4 | 7 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 840 | 1.7 s | 150 (air) | armfepocht4_ferret_missile | C | MMB |
| Armada | Gauntlet | armguard | 1 | Heavy g2g long range plasma cannon | Plasma | Air+Ground | 1220 | 2.8 s | 300 | armguard_plasma | A | LMB |
| Armada | Gauntlet | armguard | 2 | Heavy g2g long range plasma cannon | Plasma | Air+Ground | 1220 | 2.8 s | 300 | armguard_plasma_high | B | RMB |
| Armada | Gauntlet | armguard | 3 | Heavy g2g long range plasma cannon | Plasma | - | 1220 | 2.8 s | 0 | armguard_smart_trajectory_dummy | - | - |
| Armada | Ghost | armspy | 1 | Dummy Weapon | Melee | Water | 100 | 0.1 s | 0 | armspy_crawl_dummy | - | - |
| Armada | Gorgon | armkraken | 1 | Rapid-fire gauss cannon | Cannon | Air+Ground | 800 | 0.3 s | 180 | armkraken_armmech_cannon | A | LMB |
| Armada | Gremlin | armgremlin | 1 | Light close-quarters gauss cannon | Cannon | Air+Ground | 220 | 3.0 s | 263 | armgremlin_armgremlin_gauss | A | LMB |
| Armada | Groundhog | armmlv | 1 | Seismic charge | Cannon | Air+Ground | 220 | 3.0 s | 15 | armmlv_minesweep | A | LMB |
| Armada | Gun Platform | armgplat | 1 | Light g2g plasma cannon | Plasma | Air+Ground | 520 | 0.5 s | 97 | armgplat_gun | A | LMB |
| Armada | Gunslinger | armmav | 1 | Anti-swarm g2g gauss-impulse guns | Cannon | Air+Ground | 365 | 1.0 s | 265 | armmav_armmav_weapon | A | LMB |
| Armada | Harpoon | armtl | 1 | Level1TorpedoLauncher | Torpedo | All | 500 | 1.5 s | 280 | armtl_torpedo | A | LMB |
| Armada | Haven | armantiship | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 1500 | armantiship_amd_rocket | - | - |
| Armada | Haven | armcarry | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 1500 | armcarry_amd_rocket | - | - |
| Armada | Heavy Mine | armfmine3 | 1 | Crawlingbomb Dummy Weapon | Melee | - | 64 | 1.0 s | 0 | armfmine3_minerange | - | - |
| Armada | Heavy Mine | armmine3 | 1 | Crawlingbomb Dummy Weapon | Melee | - | 64 | 1.0 s | 0 | armmine3_minerange | - | - |
| Armada | Highwind | armhawk | 1 | High velocity a2a missile launcher | Missile | Air | 740 | 1.4 s | 24 | armhawk_armvtol_advmissile | A | LMB |
| Armada | Hornet | armblade | 1 | Heavy a2g armor-piercing sabot missile launcher | Missile | Air+Ground | 420 | 2.3 s | 190 | armblade_vtol_sabot | A | LMB |
| Armada | Hound | armfido | 1 | Ballistic g2g AoE plasma cannon | Plasma | Air+Ground | 650 | 3.3 s | 255 | armfido_bfido | A | LMB |
| Armada | Jaguar | armlatnk | 1 | Close-quarters lightning turret | Lightning | Air+Ground | 300 | 1.5 s | 22 | armlatnk_lightning | A | LMB |
| Armada | Jaguar | armlatnk | 2 | Light g2a missile launcher | Missile | Air | 600 | 2.1 s | 90 (air) | armlatnk_armamph_missile | B | RMB |
| Armada | Janus | armjanus | 1 | Heavy g2g dual-missile launcher | Missile | Air+Ground | 380 | 7.5 s | 330 | armjanus_janus_rocket | A | LMB |
| Armada | Janus | armjanus | 2 | Heavy g2g dual-missile launcher | Missile | Air+Ground | 380 | 7.5 s | 330 | armjanus_janus_rocket | A | LMB |
| Armada | Juno | armjuno | 1 | Anti radar/minefield/jammer magnetic impulse rocket | Starburst missile | - | 32000 | 2.0 s | 0 | armjuno_juno_pulse | - | - |
| Armada | Keeper | armgate | 1 | PlasmaRepulsor | Shield | - | 10 | 1.0 s | 0 | armgate_repulsor | - | - |
| Armada | Liche | armliche | 1 | Tactical nuclear homing missile | Missile | Air+Ground | 250 | 9.0 s | 5625 | armliche_arm_pidr | A | LMB |
| Armada | Light Mine | armmine1 | 1 | Crawlingbomb Dummy Weapon | Melee | - | 64 | 1.0 s | 0 | armmine1_minerange | - | - |
| Armada | Liquifier | armanavaldefturret | 1 | Long-Range Tachyon Emitter | Beam laser | Air+Ground | 950 | 4.7 s | 2500 | armanavaldefturret_armada_tachyon_emitter | B | RMB |
| Armada | Liquifier | armanavaldefturret | 2 | Quad Medium Plasma Gauss Cannons | Plasma | Air+Ground | 690 | 0.6 s | 200 | armanavaldefturret_armada_medium_gauss_cannon | A | LMB |
| Armada | Longbow | armmship | 1 | Heavy long-range g2g starburst rocket launcher | Cannon | Air+Ground | 1550 | 6.0 s | 650 | armmship_rocket | A | LMB |
| Armada | Longbow | armmship | 2 | Medium Range g2a AA Missiles | Missile | Air | 710 | 2.0 s | 138 (air) | armmship_missile | B | RMB |
| Armada | Lunchbox | armlunchbox | 1 | Heavy long-range g2g plasma cannon | Plasma | Air+Ground | 1325 | 8.0 s | 1265 | armlunchbox_shocker | A | LMB |
| Armada | Lunkhead | armlun | 1 | Heavy ballistic underwater cannon | Cannon | Air+Ground | 575 | 1.8 s | 370 | armlun_cannon | A | LMB |
| Armada | Lunkhead | armlun | 2 | Depthcharge launcher | Torpedo | All | 400 | 2.0 s | 225 | armlun_depthcharge | B | RMB |
| Armada | Mace | armham | 1 | Light g2g plasma cannon (low trajectory) | Plasma | Air+Ground | 380 | 1.7 s | 104 | armham_arm_ham | A | LMB |
| Armada | Maelstrom | armlship | 1 | Close-quarters lightning turret | Lightning | Air+Ground | 400 | 1.4 s | 35 | armlship_lightning | A | LMB |
| Armada | Maelstrom | armlship | 2 | Light g2a missile launcher | Missile | Air | 710 | 2.0 s | 138 (air) | armlship_armamph_missile | B | RMB |
| Armada | Manta | armfhlt | 1 | HighEnergyLaser | Beam laser | Air+Ground | 630 | 0.9 s | 210 | armfhlt_armfhlt_laser | A | LMB |
| Armada | Marauder | armmar | 1 | Double close-quarters gauss cannon | Cannon | Air+Ground | 350 | 0.7 s | 235 | armmar_armmech_cannon | A | LMB |
| Armada | Marauder | armmar | 2 | Guided g2a missile launcher | Missile | Air | 600 | 2.1 s | 90 (air) | armmar_armamph_missile | B | RMB |
| Armada | Mauser | armmart | 1 | Long-range g2g plasma cannon | Plasma | Air+Ground | 820 | 3.0 s | 260 | armmart_arm_artillery | A | LMB |
| Armada | Meatball | armmeatball | 1 | Long range g2g plasma cannon | Plasma | Air+Ground | 800 | 0.3 s | 200 | armmeatball_lrpc | A | LMB |
| Armada | Meatball | armmeatball | 2 | Guided g2a missile launcher | Missile | Air | 600 | 2.0 s | 85 (air) | armmeatball_armamph_missile | B | RMB |
| Armada | Medium Mine | armmine2 | 1 | Crawlingbomb Dummy Weapon | Melee | - | 64 | 1.0 s | 0 | armmine2_minerange | - | - |
| Armada | Mercury | armmercury | 1 | Heavy long-range g2a guided missile launcher | Missile | Air | 2400 | 1.8 s | 750 (air) | armmercury_arm_advsam | A | LMB |
| Armada | Mini Ragnarok | armminivulc | 1 | Mini Rapid-fire long-range plasma cannon | Plasma | Air+Ground | 1300 | 0.4 s | 210 | armminivulc_armminivulc_weapon | A | LMB |
| Armada | Moray | armatl | 1 | Heavy long-range homing torpedo launcher | Torpedo | All | 915 | 2.2 s | 780 | armatl_armatl_torpedo | A | LMB |
| Armada | Naval Arbalest | armfflak | 1 | Heavy g2a flak cannon | Cannon | Air | 850 | 0.5 s | 250 (air) | armfflak_armflak_gun | A | LMB |
| Armada | Naval Nettle | armfrt | 1 | Light g2a missile launcher | Missile | Air | 765 | 1.7 s | 115 (air) | armfrt_armrl_missile | A | LMB |
| Armada | Nettle | armrl | 1 | Light g2a missile launcher | Missile | Air | 765 | 1.7 s | 115 (air) | armrl_armrl_missile | A | LMB |
| Armada | Nexus | armdronecarry | 1 | HeavyCannon | Cannon | - | 1300 | 2.5 s | 0 | armdronecarry_plasma | - | - |
| Armada | Nexus | armdronecarry | 2 | Missiles | Missile | Air | 710 | 2.0 s | 138 (air) | armdronecarry_aamissile | A | LMB |
| Armada | Nexus Terra | armdronecarryland | 1 | HeavyCannon | Cannon | - | 1200 | 2.5 s | 0 | armdronecarryland_plasma | - | - |
| Armada | Overwatch | armhlt | 1 | Heavy g2g high energy laser | Beam laser | Air+Ground | 620 | 1.8 s | 387 | armhlt_arm_laserh1 | A | LMB |
| Armada | Paladin | armcrus | 1 | Long-range g2g gauss cannon | Cannon | Air+Ground | 500 | 1.7 s | 220 | armcrus_gauss | B | RMB |
| Armada | Paladin | armcrus | 2 | Light close-quarters g2g laser | Beam laser | Air+Ground | 430 | 0.3 s | 75 | armcrus_laser | A | LMB |
| Armada | Paladin | armcrus | 3 | Medium depthcharge launcher | Torpedo | All | 450 | 1.8 s | 225 | armcrus_depthcharge | C | MMB |
| Armada | Paralyzer | armemp | 1 | Heavy long-range g2g EMP starburst rocket | Starburst missile | Air+Ground | 3650 | 2.0 s | 50000 | armemp_armemp_weapon | A | LMB |
| Armada | Pawn | armpw | 1 | Rapid-fire close-quarters g2g plasma guns | Plasma | Ground | 180 | 0.3 s | 9 | armpw_emg | A | LMB |
| Armada | Pawn Launcher | armbotrail | 1 | Long range bot cannon | Cannon | Air+Ground | 5250 | 0.5 s | 10 | armbotrail_arm_botrail | A | LMB |
| Armada | Pincer | armpincer | 1 | Light close-quarters plasma cannon | Plasma | Air+Ground | 305 | 1.5 s | 116 | armpincer_arm_pincer_gauss | A | LMB |
| Armada | Pit Bull | armpb | 1 | Pop-up heavy g2g gauss cannon | Cannon | Air+Ground | 730 | 1.6 s | 675 | armpb_armpb_weapon | A | LMB |
| Armada | Platypus | armamph | 1 | Light close-quarters laser | Beam laser | Air+Ground | 275 | 0.7 s | 80 | armamph_armamph_weapon1 | A | LMB |
| Armada | Platypus | armamph | 2 | Light g2a missile launcher | Missile | Air | 600 | 2.1 s | 90 (air) | armamph_armamph_missile | B | RMB |
| Armada | Possum | armmh | 1 | Light long-range g2g starburst rocket launcher | Starburst missile | Air+Ground | 710 | 6.0 s | 300 | armmh_armmh_weapon | A | LMB |
| Armada | Puffin | armseap | 1 | Homing torpedo launcher | Torpedo | All | 600 | 3.0 s | 342 | armseap_armseap_weapon1 | A | LMB |
| Armada | Pulsar | armanni | 1 | Heavy long-range g2g tachyon accelerator beam | Beam laser | Air+Ground | 1400 | 9.9 s | 10800 | armanni_ata | A | LMB |
| Armada | Ragnarok | armvulc | 1 | Rapid-fire long-range plasma cannon | Plasma | Air+Ground | 5750 | 0.6 s | 1625 | armvulc_rflrpc | A | LMB |
| Armada | Ratte | armrattet4 | 1 | Huge g2g plasma cannon | Plasma | Air+Ground | 1000 | 1.5 s | 1200 | armrattet4_arm_bosscannon | A | LMB |
| Armada | Rattlesnake | armamb | 1 | Pop-up heavy  long range g2g plasma cannon | Plasma | Air+Ground | 1380 | 1.8 s | 350 | armamb_armamb_gun | A | LMB |
| Armada | Rattlesnake | armamb | 2 | Pop-up heavy  long range g2g plasna cannon | Cannon | Air+Ground | 1380 | 1.8 s | 350 | armamb_armamb_gun_high | B | RMB |
| Armada | Rattlesnake | armamb | 3 | Pop-up heavy  long range g2g plasma cannon | Plasma | - | 1380 | 1.8 s | 0 | armamb_smart_trajectory_dummy | - | - |
| Armada | Razorback | armraz | 1 | Rapid-fire close quarters g2g armor-piercing laser | Beam laser | Air+Ground | 475 | 0.6 s | 105 | armraz_mech_rapidlaser | A | LMB |
| Armada | Recluse | armsptk | 1 | Parabolic trajectory g2g multi-rocket launcher | Missile | Air+Ground | 575 | 3.7 s | 200 | armsptk_adv_rocket | A | LMB |
| Armada | Rocketeer | armrock | 1 | Medium g2g rocket launcher | Missile | Air+Ground | 475 | 3.8 s | 157 | armrock_arm_bot_rocket | A | LMB |
| Armada | Roughneck | armbrawl | 1 | Rapid-fire a2g plasma guns | Plasma | Ground | 380 | 0.6 s | 16 | armbrawl_vtol_emg | A | LMB |
| Armada | Rover | armfav | 1 | Light Close-Quarters g2g Laser | Beam laser | Ground | 180 | 1.0 s | 35 | armfav_arm_laser | A | LMB |
| Armada | Sabre | armsaber | 1 | Light a2g discharge blaster | Laser | Air+Ground | 425 | 0.9 s | 60 | armsaber_vtol_emg2 | A | LMB |
| Armada | Scumbag | armfrock | 1 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 840 | 1.7 s | 150 (air) | armfrock_aamissile | A | LMB |
| Armada | Seadragon | armseadragon | 1 | Torpedo launcher | Torpedo | All | 720 | 8.0 s | 800 | armseadragon_waterballon | A | LMB |
| Armada | Seadragon | armseadragon | 2 | Intercontinental ballistic nuclear warhead | Starburst missile | All | 72000 | 30.0 s | 12500 | armseadragon_sdmssl | B | RMB |
| Armada | Seadragon | armseadragon | 3 | Nuclear Launch | Cannon | - | 0 | 30.0 s | 0 | armseadragon_nuclear_launch | - | - |
| Armada | Seeker | armsh | 1 | Light Close-Quarters Fast-Firing g2g Laser | Beam laser | Air+Ground | 230 | 0.6 s | 36 | armsh_armsh_weapon | A | LMB |
| Armada | Sentry | armllt | 1 | Light g2g laser turret | Beam laser | Air+Ground | 430 | 0.5 s | 75 | armllt_arm_lightlaser | A | LMB |
| Armada | Serpent | armserp | 1 | Heavy guided torpedo launcher | Torpedo | All | 800 | 8.0 s | 825 | armserp_armserp_weapon | A | LMB |
| Armada | Serpent | armserp | 2 | Heavy guided torpedo launcher | Torpedo | All | 800 | 8.0 s | 825 | armserp_armserp_weapon | A | LMB |
| Armada | Sharpshooter | armsnipe | 1 | SniperWeapon | Cannon | Air+Ground | 900 | 10.0 s | 2500 | armsnipe_old_armsnipe_weapon | A | LMB |
| Armada | Shellshocker | armart | 1 | Long-range high-trajectory g2g plasma cannon | Plasma | Air+Ground | 710 | 4.3 s | 182 | armart_tawf113_weapon | A | LMB |
| Armada | Shockwave | armshockwave | 1 | Medium EMP turret | EMP cannon | Ground | 500 | 1.3 s | 800 | armshockwave_hllt_bottom | A | LMB |
| Armada | Shredder | armyork | 1 | Missiles | Cannon | - | 775 | 0.5 s | 0 | armyork_bogus_missile | - | - |
| Armada | Shredder | armyork | 2 | Heavy g2a flak cannon | Cannon | Air | 775 | 0.7 s | 200 (air) | armyork_mobileflak | A | LMB |
| Armada | Skater | armpt | 1 | Light close-quarters laser | Beam laser | Air+Ground | 300 | 0.4 s | 24 | armpt_laser | A | LMB |
| Armada | Skater | armpt | 2 | Light g2a missile launcher | Missile | Air | 760 | 1.4 s | 80 (air) | armpt_aamissile | B | RMB |
| Armada | Sprinter | armfast | 1 | Rapid-firing close-quarters g2g plasma guns | Plasma | Air+Ground | 230 | 0.5 s | 12 | armfast_arm_fast | A | LMB |
| Armada | Starlight | armmanni | 1 | Heavy long-range g2g tachyon beam | Beam laser | Air+Ground | 950 | 4.7 s | 2500 | armmanni_atam | A | LMB |
| Armada | Stiletto | armstil | 1 | Heavy a2g EMP warheads | Bomb | Air+Ground | 1280 | 7.0 s | 6000 | armstil_stiletto_bomb | A | LMB |
| Armada | Stormbringer | armthund | 1 | Light a2g impulse warheads | Bomb | Air+Ground | 1280 | 6.0 s | 110 | armthund_armbomb | A | LMB |
| Armada | Stout | armstump | 1 | Light g2g plasma cannon | Plasma | Air+Ground | 350 | 1.2 s | 97 | armstump_arm_lightcannon | A | LMB |
| Armada | Sweeper | armah | 1 | Missiles | Cannon | - | 830 | 0.5 s | 0 | armah_bogus_missile | - | - |
| Armada | Sweeper | armah | 2 | Light g2a missile launcher | Missile | Air | 700 | 2.2 s | 62 (air) | armah_armah_weapon | A | LMB |
| Armada | Thor | armthor | 1 | Heavy Lighting Cannon | Lightning | Air+Ground | 540 | 3.1 s | 300 | armthor_thunder | B | RMB |
| Armada | Thor | armthor | 2 | Heavy long-range g2g EMP starburst rocket | Starburst missile | Air+Ground | 1050 | 3.0 s | 80000 | armthor_empmissile | C | MMB |
| Armada | Thor | armthor | 3 | Long Range EMP laser | Beam laser | Air+Ground | 350 | 0.2 s | 300 | armthor_emp | A | LMB |
| Armada | Thor | armthor | 4 | Long Range EMP laser | Beam laser | Air+Ground | 350 | 0.2 s | 300 | armthor_emp | A | LMB |
| Armada | Tick | armflea | 1 | Light Close-Quarters Fast-Firing g2g Laser | Beam laser | Ground | 140 | 0.6 s | 24 | armflea_flea_laser | A | LMB |
| Armada | Titan | armbanth | 1 | Close-quarters impulsion blaster | Laser | Air+Ground | 465 | 1.4 s | 730 | armbanth_armbantha_fire | A | LMB |
| Armada | Titan | armbanth | 2 | High-energy long-range g2g/g2a lazor of DEEEEEEWWWWWWMMMMMM | Beam laser | Air+Ground | 800 | 7.5 s | 6000 | armbanth_tehlazerofdewm | B | RMB |
| Armada | Titan | armbanth | 3 | Heavy g2g/g2a guided starburst missile launcher | Starburst missile | Air+Ground | 860 | 7.0 s | 900 | armbanth_bantha_rocket | C | MMB |
| Armada | Titan | armbanth | 4 | BanthStep | Cannon | - | 0 | 1.5 s | 0 | armbanth_banthfootstep | - | - |
| Armada | Torpedo Ship | armtorps | 1 | Torpedo | Torpedo | All | 300 | 10.0 s | 455 | armtorps_torpedo | A | LMB |
| Armada | Trident | armtrident | 1 | Depth Charge Drones | Cannon | Water | 1300 | 2.5 s | 0 | armtrident_plasma | - | - |
| Armada | Trident | armtrident | 2 | Depthcharge launcher | Torpedo | All | 600 | 1.5 s | 255 | armtrident_trident_depthcharge | A | LMB |
| Armada | Tsunami | armsb | 1 | Medium a2g impulse warheads | Bomb | Air+Ground | 1280 | 7.0 s | 200 | armsb_arm_seaadvbomb | A | LMB |
| Armada | Tumbleweed | armvader | 1 | Crawlingbomb Dummy Weapon | Melee | Water | 42 | 0.1 s | 0 | armvader_crawl_dummy | - | - |
| Armada | Tumbleweed | armvader | 2 | Self-destruction | Cannon | Air+Ground | 1 | 0.1 s | 1000 | armvader_crawl_detonator | A | LMB |
| Armada | Turtle | armcroc | 1 | Medium g2g gauss-cannon | Cannon | Air+Ground | 480 | 1.6 s | 225 | armcroc_arm_triton | A | LMB |
| Armada | Turtle | armcroc | 2 | Light g2a missile launcher | Missile | Air | 765 | 1.7 s | 60 (air) | armcroc_armcl_missile | B | RMB |
| Armada | Umbrella | armscab | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 500 | armscab_armscab_weapon | - | - |
| Armada | units.names.armcomnew | armcomnew | 1 | Light close-quarters g2g/g2a laser | Beam laser | Air+Ground | 300 | 0.4 s | 75 | armcomnew_armcomlaser | B | RMB |
| Armada | units.names.armcomnew | armcomnew | 2 | Light underwater-combat laser | Beam laser | All | 300 | 1.0 s | 200 | armcomnew_armcomsealaser | C | MMB |
| Armada | units.names.armcomnew | armcomnew | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | armcomnew_disintegrator | A | LMB |
| Armada | units.names.armprowl | armprowl | 1 | Double close-quarters gauss cannon | Cannon | Air+Ground | 350 | 0.7 s | 235 | armprowl_armmech_cannon | A | LMB |
| Armada | units.names.armprowl | armprowl | 2 | Guided g2a missile launcher | Missile | Air | 600 | 2.0 s | 85 (air) | armprowl_armamph_missile | B | RMB |
| Armada | Vanguard | armvang | 1 | Heavy long-range g2g plasma cannon | Plasma | Air+Ground | 1450 | 8.0 s | 1265 | armvang_shocker_low | A | LMB |
| Armada | Vanguard | armvang | 2 | Heavy long-range g2g plasma cannon | Plasma | Air+Ground | 1450 | 8.0 s | 1265 | armvang_shocker_high | B | RMB |
| Armada | Vanguard | armvang | 3 | Heavy long-range g2g plasma cannon | Plasma | - | 1450 | 8.0 s | 0 | armvang_smart_trajectory_dummy | - | - |
| Armada | Webber | armspid | 1 | Close-quarters light EMP laser | Beam laser | Air+Ground | 280 | 1.7 s | 850 | armspid_spider | A | LMB |
| Armada | Welder | armzeus | 1 | Close-quarters g2g lightning rifle | Lightning | Air+Ground | 280 | 1.7 s | 22 | armzeus_lightning | A | LMB |
| Armada | Whistler | armsam | 1 | Light g2a missile launcher | Missile | Air | 700 | 3.3 s | 160 (air) | armsam_armtruck_aa | B | RMB |
| Armada | Whistler | armsam | 2 | Light g2g missile launcher | Missile | Air+Ground | 550 | 3.3 s | 86 | armsam_armtruck_missile | A | LMB |
| Armada | Zapper | armzapper | 1 | Light EMP laser | Beam laser | Air+Ground | 220 | 1.2 s | 800 | armzapper_bladewing_lyzer | A | LMB |
| Cortex | Adjudicator | coresuppt3 | 1 | Ultra Heavy Juggernaut-Spec Heatray | Beam laser | Air+Ground | 900 | 4.0 s | 5500 | coresuppt3_laser | A | LMB |
| Cortex | Adjudicator | coresuppt3 | 2 | Ultra Heavy Juggernaut-Spec Heatray | Beam laser | Air+Ground | 900 | 4.0 s | 5500 | coresuppt3_laser | A | LMB |
| Cortex | Advanced Exploiter | cormexp | 1 | High energy g2g laser | Beam laser | Air+Ground | 650 | 0.5 s | 215 | cormexp_corsumo_weapon | A | LMB |
| Cortex | Advanced Exploiter | cormexp | 2 | Heavy g2g/g2a barrage missile launcher | Missile | Air+Ground | 650 | 5.9 s | 260 | cormexp_cormexp_rocket | B | RMB |
| Cortex | Aggravator | corstorm | 1 | Rockets | Missile | Air+Ground | 475 | 3.8 s | 157 | corstorm_cor_bot_rocket | A | LMB |
| Cortex | Agitator | corpun | 1 | Long-range g2g plasma cannon | Plasma | Air+Ground | 1245 | 3.2 s | 350 | corpun_plasma | A | LMB |
| Cortex | Agitator | corpun | 2 | Long-range g2g plasma cannon | Plasma | Air+Ground | 1245 | 3.2 s | 350 | corpun_plasma_high | B | RMB |
| Cortex | Agitator | corpun | 3 | Long-range g2g plasma cannon | Plasma | - | 1245 | 3.2 s | 0 | corpun_smart_trajectory_dummy | - | - |
| Cortex | Alligator | corseal | 1 | PlasmaCannon | Plasma | Air+Ground | 440 | 0.9 s | 116 | corseal_cor_croc | A | LMB |
| Cortex | Angler | cortitan | 1 | Heavy homing torpedo launcher | Torpedo | All | 400 | 8.0 s | 1200 | cortitan_heavy_torpedo | A | LMB |
| Cortex | Apocalypse | corsilo | 1 | Intercontinental thermonuclear ballistic missile | Starburst missile | Air+Ground | 72000 | 30.0 s | 15000 | corsilo_crblmssl | A | LMB |
| Cortex | Apocalypse | corsilo | 2 | Nuclear Launch | Cannon | - | 0 | 30.0 s | 0 | corsilo_nuclear_launch | - | - |
| Cortex | Arbiter | corhrk | 1 | HeavyRockets | Starburst missile | Air+Ground | 1210 | 8.0 s | 850 | corhrk_corhrk_rocket | A | LMB |
| Cortex | Archaic Dragon | corcrw | 1 | High energy a2g laser | Beam laser | Air+Ground | 525 | 1.3 s | 250 | corcrw_krowlaser2 | A | LMB |
| Cortex | Archaic Dragon | corcrw | 2 | HighEnergyLaser | Beam laser | Air+Ground | 575 | 0.6 s | 90 | corcrw_krowlaser | B | RMB |
| Cortex | Archaic Dragon | corcrw | 3 | HighEnergyLaser | Beam laser | Air+Ground | 575 | 0.6 s | 90 | corcrw_krowlaser | B | RMB |
| Cortex | Archaic Karkinos | corkark | 1 | Light g2g Heat Ray | Beam laser | Air+Ground | 360 | 2.0 s | 160 | corkark_corwar_laser | B | RMB |
| Cortex | Archaic Karkinos | corkark | 2 | RiotCannon | Cannon | Air+Ground | 220 | 5.0 s | 190 | corkark_corlevlr_weapon | A | LMB |
| Cortex | Arrow Storm | corarch | 1 | Missiles | Cannon | - | 800 | 0.5 s | 0 | corarch_bogus_missile | - | - |
| Cortex | Arrow Storm | corarch | 2 | AA2Missile | Missile | Air | 870 | 1.6 s | 125 | corarch_ga2 | B | RMB |
| Cortex | Arrow Storm | corarch | 3 | FlakCannon | Cannon | Air | 775 | 0.7 s | 200 (air) | corarch_mobileflak | A | LMB |
| Cortex | Atoll | corfgate | 1 | NavalPlasmaRepulsor | Shield | - | 10 | 1.0 s | 0 | corfgate_sea_repulsor | - | - |
| Cortex | Attack Drone | cordrone | 1 | HeatRay | Beam laser | Air+Ground | 360 | 1.3 s | 60 | cordrone_heat_ray | A | LMB |
| Cortex | Attack Drone | cordroneold | 1 | HeatRay | Beam laser | Air+Ground | 360 | 4.8 s | 80 | cordroneold_heat_ray | A | LMB |
| Cortex | Banisher | corban | 1 | Banisher | Missile | Air+Ground | 800 | 7.5 s | 1000 | corban_banisher | A | LMB |
| Cortex | Basilisk | corint | 1 | Long-range plasma cannon | Plasma | Air+Ground | 4950 | 16.0 s | 2000 | corint_lrpc | A | LMB |
| Cortex | Bat | corsfig | 1 | Guided a2a missile launcher | Missile | Air | 710 | 0.8 s | 12 | corsfig_corsfig_weapon | A | LMB |
| Cortex | Bat | corsfig2 | 1 | Guided a2a missile launcher | Missile | Air | 710 | 0.8 s | 12 | corsfig2_corsfig_weapon | A | LMB |
| Cortex | Bat | corsfig2 | 2 | Guided a2a missile launcher | Missile | Air | 710 | 0.8 s | 12 | corsfig2_small_weapon | B | RMB |
| Cortex | Bedbug | corroach | 1 | Crawlingbomb Dummy Weapon | Melee | Water | 42 | 0.1 s | 0 | corroach_crawl_dummy | - | - |
| Cortex | Bedbug | corroach | 2 | Self-destruction | Cannon | - | 1 | 0.1 s | 0 | corroach_crawl_detonator | - | - |
| Cortex | Behemoth | corjugg | 1 | GaussCannon | D-gun | Air+Ground | 590 | 4.0 s | 1200 | corjugg_juggernaut_fire | C | MMB |
| Cortex | Behemoth | corjugg | 2 | LightLaser | Beam laser | Air+Ground | 435 | 0.3 s | 75 | corjugg_juggernaut_bottom | A | LMB |
| Cortex | Behemoth | corjugg | 3 | LightLaser | Beam laser | Air+Ground | 435 | 0.3 s | 75 | corjugg_juggernaut_bottom | A | LMB |
| Cortex | Behemoth | corjugg | 4 | LightLaser | Beam laser | Air+Ground | 550 | 0.5 s | 150 | corjugg_juggernaut_top | B | RMB |
| Cortex | Behemoth | corjugg | 5 | JuggStep | Cannon | - | 0 | 1.5 s | 0 | corjugg_juggfootstep | - | - |
| Cortex | Birdeater | corah | 1 | Missiles | Cannon | - | 800 | 0.5 s | 0 | corah_bogus_missile | - | - |
| Cortex | Birdeater | corah | 2 | Missiles | Missile | Air | 700 | 2.2 s | 62 (air) | corah_corah_weapon | A | LMB |
| Cortex | Birdshot | corflak | 1 | Heavy g2a flak cannon | Cannon | Air | 850 | 0.5 s | 250 (air) | corflak_armflak_gun | A | LMB |
| Cortex | Black Hydra | corblackhy | 1 | BattleshipCannon | Cannon | Air+Ground | 2550 | 5.5 s | 600 | corblackhy_heavyplasma | B | RMB |
| Cortex | Black Hydra | corblackhy | 2 | HighEnergyLaser | Beam laser | Air+Ground | 830 | 0.9 s | 270 | corblackhy_heavylaser | A | LMB |
| Cortex | Black Hydra | corblackhy | 3 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 840 | 1.7 s | 150 (air) | corblackhy_ferret_missile | C | MMB |
| Cortex | Black Hydra | corblackhy | 4 | HighEnergyLaser | Beam laser | Air+Ground | 830 | 0.9 s | 270 | corblackhy_heavylaser | A | LMB |
| Cortex | Black Hydra | corblackhy | 5 | HighEnergyLaser | Beam laser | Air+Ground | 830 | 0.9 s | 270 | corblackhy_heavylaser | A | LMB |
| Cortex | Black Hydra | corblackhy | 6 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 840 | 1.7 s | 150 (air) | corblackhy_ferret_missile | C | MMB |
| Cortex | Black Prince | corprince | 1 | Heavy Long-Range Plasma Bombardment Cannon | Plasma | Air+Ground | 3200 | 18.0 s | 2000 | corprince_heavyplasma | B | RMB |
| Cortex | Black Prince | corprince | 2 | Long-Range Plasma Bombardment Cannons | Plasma | Air+Ground | 2300 | 12.0 s | 1000 | corprince_navalplasma | A | LMB |
| Cortex | Black Prince | corprince | 3 | Long-Range Plasma Bombardment Cannons | Plasma | Air+Ground | 2300 | 12.0 s | 1000 | corprince_navalplasma | A | LMB |
| Cortex | Black Prince | corprince | 4 | Long-Range Plasma Bombardment Cannons | Plasma | Air+Ground | 2300 | 12.0 s | 1000 | corprince_navalplasma | A | LMB |
| Cortex | Black Prince | corprince | 5 | Anti-Air Flak Cannons | Cannon | Air | 775 | 1.5 s | 200 (air) | corprince_mobileflak | C | MMB |
| Cortex | Black Prince | corprince | 6 | Anti-Air Flak Cannons | Cannon | Air | 775 | 1.5 s | 200 (air) | corprince_mobileflak | C | MMB |
| Cortex | Brimstone | corfship | 1 | Heavy long range AoE flamethrower | Flamethrower | Air+Ground | 450 | 0.1 s | 25 | corfship_dmaw | A | LMB |
| Cortex | Brimstone | corfship | 2 | Missiles | Missile | Air | 710 | 2.0 s | 138 (air) | corfship_aamissile | B | RMB |
| Cortex | Brute | corraid | 1 | LightCannon | Cannon | Air+Ground | 350 | 1.2 s | 97 | corraid_arm_lightcannon | A | LMB |
| Cortex | Buccaneer | corcrus | 1 | HighEnergyLaser | Beam laser | Air+Ground | 500 | 1.1 s | 200 | corcrus_cor_crus | B | RMB |
| Cortex | Buccaneer | corcrus | 2 | L2DeckLaser | Beam laser | Air+Ground | 430 | 0.3 s | 75 | corcrus_adv_decklaser | A | LMB |
| Cortex | Buccaneer | corcrus | 3 | Medium depthcharge launcher | Torpedo | All | 450 | 1.8 s | 225 | corcrus_advdepthcharge | C | MMB |
| Cortex | Bulwark | cordoom | 1 | Long-range g2g tachyon accelerator | Beam laser | Air+Ground | 950 | 6.0 s | 4500 | cordoom_atadr | C | MMB |
| Cortex | Bulwark | cordoom | 2 | High energy g2g laser | Beam laser | Air+Ground | 650 | 0.5 s | 247 | cordoom_doomsday_green_laser | B | RMB |
| Cortex | Bulwark | cordoom | 3 | Light close-quarters g2g laser | Beam laser | Air+Ground | 370 | 0.3 s | 40 | cordoom_doomsday_red_laser | A | LMB |
| Cortex | Calamity | corbuzz | 1 | Rapid-fire long-range plasma cannon | Plasma | Air+Ground | 6100 | 0.7 s | 2000 | corbuzz_rflrpc | A | LMB |
| Cortex | Catalyst | cortron | 1 | Long range tactical g2g nuclear warheads | Starburst missile | Air+Ground | 2250 | 2.0 s | 4000 | cortron_cortron_weapon | A | LMB |
| Cortex | Cataphract | corsok | 1 | Disruptor Bolt | Laser | Air+Ground | 725 | 4.5 s | 750 | corsok_corsok_laser | A | LMB |
| Cortex | Cataphract | corsok | 2 | Depthcharge launcher | Torpedo | All | 400 | 2.0 s | 225 | corsok_depthcharge | B | RMB |
| Cortex | Catapult | corcat | 1 | CatapultRockets | Missile | Air+Ground | 1350 | 15.0 s | 450 | corcat_exp_heavyrocket | A | LMB |
| Cortex | Cayman | corsnap | 1 | MediumPlasmaCannon | Plasma | Air+Ground | 370 | 1.4 s | 98 | corsnap_armanac_weapon | A | LMB |
| Cortex | Cerberus | corbhmth | 1 | Heavy g2g barrage plasma battery | Plasma | Air+Ground | 1650 | 4.2 s | 450 | corbhmth_corbhmth_weapon | A | LMB |
| Cortex | Cerberus | corbhmth | 2 | Heavy g2g barrage plasma battery | Plasma | Air+Ground | 1650 | 4.2 s | 450 | corbhmth_corbhmth_weapon | A | LMB |
| Cortex | Cerberus | corbhmth | 3 | Heavy g2g barrage plasma battery | Plasma | Air+Ground | 1650 | 4.2 s | 450 | corbhmth_corbhmth_weapon | A | LMB |
| Cortex | Commander | cordecom | 1 | J7Laser | Beam laser | Air+Ground | 300 | 0.4 s | 75 | cordecom_armcomlaser | C | MMB |
| Cortex | Commander | cordecom | 2 | J7NSLaser | Beam laser | All | 260 | 1.0 s | 63 | cordecom_armcomsealaser | A | LMB |
| Cortex | Commander | cordecom | 3 | Disintegrator | D-gun | All | 262 | 0.9 s | 40 | cordecom_disintegrator | B | RMB |
| Cortex | Commando | cormando | 1 | CommandoBlaster | Laser | Air+Ground | 300 | 0.5 s | 100 | cormando_commando_blaster | A | LMB |
| Cortex | Coral | corfhlt | 1 | High energy g2g laser | Beam laser | Air+Ground | 630 | 1.0 s | 231 | corfhlt_corfhlt_laser | A | LMB |
| Cortex | Cortex Commander | corcom | 1 | J7Laser | Beam laser | Air+Ground | 300 | 0.4 s | 75 | corcom_corcomlaser | B | RMB |
| Cortex | Cortex Commander | corcom | 2 | J7NSLaser | Beam laser | All | 300 | 1.0 s | 200 | corcom_corcomsealaser | C | MMB |
| Cortex | Cortex Commander | corcom | 3 | Disintegrator | D-gun | All | 262 | 0.9 s | 99999 | corcom_disintegrator | A | LMB |
| Cortex | Cortex Commander | corcomcon | 1 | J7Laser | Beam laser | Air+Ground | 300 | 0.4 s | 75 | corcomcon_corcomlaser | B | RMB |
| Cortex | Cortex Commander | corcomcon | 2 | J7NSLaser | Beam laser | All | 300 | 1.0 s | 200 | corcomcon_corcomsealaser | C | MMB |
| Cortex | Cortex Commander | corcomcon | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomcon_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 10 | corcomlvl10 | 1 | Long range AoE flamethrower | Flamethrower | Air+Ground | 475 | 0.4 s | 120 | corcomlvl10_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 10 | corcomlvl10 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.4 s | 1400 | corcomlvl10_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 10 | corcomlvl10 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomlvl10_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 10 | corcomlvl10 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | corcomlvl10_repulsor | - | - |
| Cortex | Cortex Commander Level 10 | corcomlvl10 | 5 | EyeLaser | Beam laser | Air+Ground | 870 | 0.0 s | 80 | corcomlvl10_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 10 | corcomlvl10 | 6 | HeavyCannon | Cannon | Air+Ground | 750 | 3.0 s | 2000 | corcomlvl10_armcannon | D | MMB |
| Cortex | Cortex Commander Level 10 | cordecomlvl10 | 1 | Long range AoE flamethrower | Flamethrower | Air+Ground | 475 | 0.4 s | 120 | cordecomlvl10_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 10 | cordecomlvl10 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.4 s | 1400 | cordecomlvl10_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 10 | cordecomlvl10 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | cordecomlvl10_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 10 | cordecomlvl10 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | cordecomlvl10_repulsor | - | - |
| Cortex | Cortex Commander Level 10 | cordecomlvl10 | 5 | EyeLaser | Beam laser | Air+Ground | 870 | 0.0 s | 80 | cordecomlvl10_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 10 | cordecomlvl10 | 6 | HeavyCannon | Cannon | Air+Ground | 750 | 3.0 s | 2000 | cordecomlvl10_armcannon | D | MMB |
| Cortex | Cortex Commander Level 2 | corcomlvl2 | 1 | HighEnergyLaser | Beam laser | Air+Ground | 300 | 0.5 s | 215 | corcomlvl2_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 2 | corcomlvl2 | 2 | J7NSLaser | Beam laser | All | 300 | 0.5 s | 200 | corcomlvl2_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 2 | corcomlvl2 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomlvl2_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 2 | corcomlvl2 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | corcomlvl2_repulsor | - | - |
| Cortex | Cortex Commander Level 2 | cordecomlvl2 | 1 | HighEnergyLaser | Beam laser | Air+Ground | 300 | 0.5 s | 215 | cordecomlvl2_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 2 | cordecomlvl2 | 2 | J7NSLaser | Beam laser | All | 300 | 0.5 s | 200 | cordecomlvl2_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 2 | cordecomlvl2 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | cordecomlvl2_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 2 | cordecomlvl2 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | cordecomlvl2_repulsor | - | - |
| Cortex | Cortex Commander Level 3 | corcomlvl3 | 1 | HighEnergyLaser | Beam laser | Air+Ground | 350 | 0.4 s | 380 | corcomlvl3_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 3 | corcomlvl3 | 2 | J7NSLaser | Beam laser | All | 450 | 0.4 s | 300 | corcomlvl3_corcomsealaser | D | MMB |
| Cortex | Cortex Commander Level 3 | corcomlvl3 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomlvl3_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 3 | corcomlvl3 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | corcomlvl3_repulsor | - | - |
| Cortex | Cortex Commander Level 3 | corcomlvl3 | 5 | Eye laser | Beam laser | Air+Ground | 435 | 0.5 s | 75 | corcomlvl3_corcomeyelaser | C | MMB |
| Cortex | Cortex Commander Level 3 | cordecomlvl3 | 1 | HighEnergyLaser | Beam laser | Air+Ground | 350 | 0.4 s | 380 | cordecomlvl3_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 3 | cordecomlvl3 | 2 | J7NSLaser | Beam laser | All | 450 | 0.4 s | 300 | cordecomlvl3_corcomsealaser | D | MMB |
| Cortex | Cortex Commander Level 3 | cordecomlvl3 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | cordecomlvl3_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 3 | cordecomlvl3 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | cordecomlvl3_repulsor | - | - |
| Cortex | Cortex Commander Level 3 | cordecomlvl3 | 5 | Eye laser | Beam laser | Air+Ground | 435 | 0.5 s | 75 | cordecomlvl3_corcomeyelaser | C | MMB |
| Cortex | Cortex Commander Level 4 | corcomlvl4 | 1 | HighEnergyLaser | Beam laser | Air+Ground | 350 | 0.3 s | 550 | corcomlvl4_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 4 | corcomlvl4 | 2 | J7NSLaser | Beam laser | All | 450 | 0.4 s | 400 | corcomlvl4_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 4 | corcomlvl4 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomlvl4_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 4 | corcomlvl4 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | corcomlvl4_repulsor | - | - |
| Cortex | Cortex Commander Level 4 | corcomlvl4 | 5 | Eye laser | Beam laser | Air+Ground | 550 | 0.3 s | 85 | corcomlvl4_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 4 | corcomlvl4 | 6 | HeavyCannon | Cannon | Air+Ground | 500 | 3.0 s | 450 | corcomlvl4_armcannon | D | MMB |
| Cortex | Cortex Commander Level 4 | cordecomlvl4 | 1 | HighEnergyLaser | Beam laser | Air+Ground | 350 | 0.3 s | 550 | cordecomlvl4_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 4 | cordecomlvl4 | 2 | J7NSLaser | Beam laser | All | 450 | 0.4 s | 400 | cordecomlvl4_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 4 | cordecomlvl4 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | cordecomlvl4_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 4 | cordecomlvl4 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | cordecomlvl4_repulsor | - | - |
| Cortex | Cortex Commander Level 4 | cordecomlvl4 | 5 | Eye laser | Beam laser | Air+Ground | 550 | 0.3 s | 85 | cordecomlvl4_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 4 | cordecomlvl4 | 6 | HeavyCannon | Cannon | Air+Ground | 500 | 3.0 s | 450 | cordecomlvl4_armcannon | D | MMB |
| Cortex | Cortex Commander Level 5 | corcomlvl5 | 1 | Anti-swarm AoE flamethrower | Flamethrower | Air+Ground | 400 | 1.1 s | 90 | corcomlvl5_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 5 | corcomlvl5 | 2 | UltravioletRayBeam | Beam laser | All | 475 | 0.9 s | 1200 | corcomlvl5_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 5 | corcomlvl5 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomlvl5_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 5 | corcomlvl5 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | corcomlvl5_repulsor | - | - |
| Cortex | Cortex Commander Level 5 | corcomlvl5 | 5 | Eye laser | Beam laser | Air+Ground | 620 | 0.2 s | 120 | corcomlvl5_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 5 | corcomlvl5 | 6 | HeavyCannon | Cannon | Air+Ground | 600 | 3.0 s | 450 | corcomlvl5_armcannon | D | MMB |
| Cortex | Cortex Commander Level 5 | cordecomlvl5 | 1 | Anti-swarm AoE flamethrower | Flamethrower | Air+Ground | 400 | 1.1 s | 90 | cordecomlvl5_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 5 | cordecomlvl5 | 2 | UltravioletRayBeam | Beam laser | All | 475 | 0.9 s | 1200 | cordecomlvl5_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 5 | cordecomlvl5 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | cordecomlvl5_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 5 | cordecomlvl5 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | cordecomlvl5_repulsor | - | - |
| Cortex | Cortex Commander Level 5 | cordecomlvl5 | 5 | Eye laser | Beam laser | Air+Ground | 620 | 0.2 s | 120 | cordecomlvl5_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 5 | cordecomlvl5 | 6 | HeavyCannon | Cannon | Air+Ground | 600 | 3.0 s | 450 | cordecomlvl5_armcannon | D | MMB |
| Cortex | Cortex Commander Level 6 | corcomlvl6 | 1 | Anti-swarm AoE flamethrower | Flamethrower | Air+Ground | 400 | 0.9 s | 90 | corcomlvl6_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 6 | corcomlvl6 | 2 | UltravioletRayBeam | Beam laser | All | 475 | 0.7 s | 1200 | corcomlvl6_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 6 | corcomlvl6 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomlvl6_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 6 | corcomlvl6 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | corcomlvl6_repulsor | - | - |
| Cortex | Cortex Commander Level 6 | corcomlvl6 | 5 | EyeLaser | Beam laser | Air+Ground | 730 | 0.0 s | 26 | corcomlvl6_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 6 | corcomlvl6 | 6 | HeavyCannon | Cannon | Air+Ground | 600 | 3.0 s | 675 | corcomlvl6_armcannon | D | MMB |
| Cortex | Cortex Commander Level 6 | cordecomlvl6 | 1 | Anti-swarm AoE flamethrower | Flamethrower | Air+Ground | 400 | 0.9 s | 90 | cordecomlvl6_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 6 | cordecomlvl6 | 2 | UltravioletRayBeam | Beam laser | All | 475 | 0.7 s | 1200 | cordecomlvl6_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 6 | cordecomlvl6 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | cordecomlvl6_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 6 | cordecomlvl6 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | cordecomlvl6_repulsor | - | - |
| Cortex | Cortex Commander Level 6 | cordecomlvl6 | 5 | EyeLaser | Beam laser | Air+Ground | 730 | 0.0 s | 26 | cordecomlvl6_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 6 | cordecomlvl6 | 6 | HeavyCannon | Cannon | Air+Ground | 600 | 3.0 s | 675 | cordecomlvl6_armcannon | D | MMB |
| Cortex | Cortex Commander Level 7 | corcomlvl7 | 1 | Anti-swarm AoE flamethrower | Flamethrower | Air+Ground | 400 | 0.8 s | 90 | corcomlvl7_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 7 | corcomlvl7 | 2 | UltravioletRayBeam | Beam laser | All | 500 | 0.5 s | 1200 | corcomlvl7_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 7 | corcomlvl7 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomlvl7_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 7 | corcomlvl7 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | corcomlvl7_repulsor | - | - |
| Cortex | Cortex Commander Level 7 | corcomlvl7 | 5 | EyeLaser | Beam laser | Air+Ground | 730 | 0.0 s | 34 | corcomlvl7_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 7 | corcomlvl7 | 6 | HeavyCannon | Cannon | Air+Ground | 700 | 3.0 s | 900 | corcomlvl7_armcannon | D | MMB |
| Cortex | Cortex Commander Level 7 | cordecomlvl7 | 1 | Anti-swarm AoE flamethrower | Flamethrower | Air+Ground | 400 | 0.8 s | 90 | cordecomlvl7_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 7 | cordecomlvl7 | 2 | UltravioletRayBeam | Beam laser | All | 500 | 0.5 s | 1200 | cordecomlvl7_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 7 | cordecomlvl7 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | cordecomlvl7_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 7 | cordecomlvl7 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | cordecomlvl7_repulsor | - | - |
| Cortex | Cortex Commander Level 7 | cordecomlvl7 | 5 | EyeLaser | Beam laser | Air+Ground | 730 | 0.0 s | 34 | cordecomlvl7_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 7 | cordecomlvl7 | 6 | HeavyCannon | Cannon | Air+Ground | 700 | 3.0 s | 900 | cordecomlvl7_armcannon | D | MMB |
| Cortex | Cortex Commander Level 8 | corcomlvl8 | 1 | Long range AoE flamethrower | Flamethrower | Air+Ground | 475 | 0.4 s | 80 | corcomlvl8_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 8 | corcomlvl8 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.5 s | 1400 | corcomlvl8_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 8 | corcomlvl8 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomlvl8_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 8 | corcomlvl8 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | corcomlvl8_repulsor | - | - |
| Cortex | Cortex Commander Level 8 | corcomlvl8 | 5 | EyeLaser | Beam laser | Air+Ground | 800 | 0.0 s | 42 | corcomlvl8_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 8 | corcomlvl8 | 6 | HeavyCannon | Cannon | Air+Ground | 700 | 3.0 s | 1050 | corcomlvl8_armcannon | D | MMB |
| Cortex | Cortex Commander Level 8 | cordecomlvl8 | 1 | Long range AoE flamethrower | Flamethrower | Air+Ground | 475 | 0.4 s | 80 | cordecomlvl8_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 8 | cordecomlvl8 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.5 s | 1400 | cordecomlvl8_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 8 | cordecomlvl8 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | cordecomlvl8_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 8 | cordecomlvl8 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | cordecomlvl8_repulsor | - | - |
| Cortex | Cortex Commander Level 8 | cordecomlvl8 | 5 | EyeLaser | Beam laser | Air+Ground | 800 | 0.0 s | 42 | cordecomlvl8_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 8 | cordecomlvl8 | 6 | HeavyCannon | Cannon | Air+Ground | 700 | 3.0 s | 1050 | cordecomlvl8_armcannon | D | MMB |
| Cortex | Cortex Commander Level 9 | corcomlvl9 | 1 | Long range AoE flamethrower | Flamethrower | Air+Ground | 475 | 0.4 s | 96 | corcomlvl9_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 9 | corcomlvl9 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.4 s | 1400 | corcomlvl9_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 9 | corcomlvl9 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | corcomlvl9_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 9 | corcomlvl9 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | corcomlvl9_repulsor | - | - |
| Cortex | Cortex Commander Level 9 | corcomlvl9 | 5 | EyeLaser | Beam laser | Air+Ground | 870 | 0.0 s | 58 | corcomlvl9_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 9 | corcomlvl9 | 6 | HeavyCannon | Cannon | Air+Ground | 750 | 3.0 s | 1350 | corcomlvl9_armcannon | D | MMB |
| Cortex | Cortex Commander Level 9 | cordecomlvl9 | 1 | Long range AoE flamethrower | Flamethrower | Air+Ground | 475 | 0.4 s | 96 | cordecomlvl9_corcomlaser | B | RMB |
| Cortex | Cortex Commander Level 9 | cordecomlvl9 | 2 | UWSupernovaBeam | Beam laser | All | 500 | 0.4 s | 1400 | cordecomlvl9_corcomsealaser | C | MMB |
| Cortex | Cortex Commander Level 9 | cordecomlvl9 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | cordecomlvl9_disintegrator | A | LMB |
| Cortex | Cortex Commander Level 9 | cordecomlvl9 | 4 | PlasmaRepulsor | Shield | - | 100 | 1.0 s | 0 | cordecomlvl9_repulsor | - | - |
| Cortex | Cortex Commander Level 9 | cordecomlvl9 | 5 | EyeLaser | Beam laser | Air+Ground | 870 | 0.0 s | 58 | cordecomlvl9_corcomeyelaser | E | MMB |
| Cortex | Cortex Commander Level 9 | cordecomlvl9 | 6 | HeavyCannon | Cannon | Air+Ground | 750 | 3.0 s | 1350 | cordecomlvl9_armcannon | D | MMB |
| Cortex | Cutlass | corcut | 1 | RiotCannon | Cannon | Air+Ground | 430 | 1.3 s | 47 | corcut_vtol_rocket2 | A | LMB |
| Cortex | Cyclops | cornavaldefturret | 1 | Heavy Plasma Blast Cannon | Plasma | Air+Ground | 720 | 3.0 s | 495 | cornavaldefturret_t1_heavy_plasma_cannon | A | LMB |
| Cortex | Dam Buster | corsb | 1 | CorSeaAdvancedBombs | Bomb | Air+Ground | 1280 | 8.0 s | 50 | corsb_cor_seaadvbomb | A | LMB |
| Cortex | Deadeye | cordeadeye | 1 | HeavyBlaster | Laser | Air+Ground | 850 | 12.0 s | 834 | cordeadeye_cor_burst_laser | A | LMB |
| Cortex | Demon | cordemon | 1 | Demon's Maw, Heavy long range AoE flamethrower | Flamethrower | Air+Ground | 500 | 0.4 s | 48 | cordemon_newdmaw | A | LMB |
| Cortex | Demon | cordemon | 2 | ShoulderRockets | Missile | Air | 700 | 0.6 s | 100 | cordemon_karg_shoulder | B | RMB |
| Cortex | Depth Charge Drone | cortdrone | 1 | Depthcharge launcher | Torpedo | All | 200 | 6.0 s | 255 | cortdrone_cotd_depthcharge | A | LMB |
| Cortex | Desolator | cordesolator | 1 | Torpedo launcher | Torpedo | All | 750 | 8.0 s | 850 | cordesolator_waterballon | A | LMB |
| Cortex | Desolator | cordesolator | 2 | Intercontinental thermonuclear ballistic missile | Starburst missile | All | 72000 | 30.0 s | 15000 | cordesolator_crblmssl | B | RMB |
| Cortex | Desolator | cordesolator | 3 | Nuclear Launch | Cannon | - | 0 | 30.0 s | 0 | cordesolator_nuclear_launch | - | - |
| Cortex | Despot | corbats | 1 | BattleshipCannon | Cannon | Air+Ground | 950 | 4.0 s | 450 | corbats_cor_bats | B | RMB |
| Cortex | Despot | corbats | 2 | BattleshipCannon | Cannon | Air+Ground | 950 | 4.0 s | 450 | corbats_cor_bats | B | RMB |
| Cortex | Despot | corbats | 3 | BattleshipCannon | Cannon | Air+Ground | 950 | 4.0 s | 450 | corbats_cor_bats | B | RMB |
| Cortex | Despot | corbats | 4 | HighEnergyLaser | Beam laser | Air+Ground | 700 | 0.9 s | 300 | corbats_cor_batslaser | A | LMB |
| Cortex | Devastator | corfdoom | 1 | Medium-range g2g plasma cannon | Plasma | Air+Ground | 900 | 2.1 s | 420 | corfdoom_cortoast_gun | C | MMB |
| Cortex | Devastator | corfdoom | 2 | High energy g2g laser | Beam laser | Air+Ground | 630 | 1.0 s | 231 | corfdoom_doomsday_green_laser | B | RMB |
| Cortex | Devastator | corfdoom | 3 | Light close-quarters g2g laser | Beam laser | Air+Ground | 370 | 0.3 s | 40 | corfdoom_doomsday_red_laser | A | LMB |
| Cortex | Disgruntler | cords | 1 | AK Bomb | Bomb | Air+Ground | 1280 | 10.0 s | 100 | cords_corbomb | A | LMB |
| Cortex | Disperser | cordronecarry | 1 | HeavyCannon | Cannon | - | 1300 | 2.5 s | 0 | cordronecarry_plasma | - | - |
| Cortex | Disperser | cordronecarry | 2 | Missiles | Missile | Air | 710 | 2.0 s | 138 (air) | cordronecarry_aamissile | A | LMB |
| Cortex | Disperser Omni | cordronecarryair | 1 | HeavyCannon | Cannon | - | 1200 | 2.5 s | 0 | cordronecarryair_plasma | - | - |
| Cortex | Dragon | corcrwh | 1 | Dragon's Maw: heavy medium range AoE flamethrower | Flamethrower | Air+Ground | 450 | 0.4 s | 6 | corcrwh_dragonmawh | A | LMB |
| Cortex | Dragon | corcrwh | 2 | Advanced d2a rapid missile launcher | Missile | Air | 840 | 0.8 s | 76 (air) | corcrwh_dragon_missileh | C | MMB |
| Cortex | Dragon | corcrwh | 3 | HighEnergyLaser | Beam laser | Air+Ground | 575 | 0.8 s | 90 | corcrwh_krowlaserh | B | RMB |
| Cortex | Dragon | corcrwh | 4 | HighEnergyLaser | Beam laser | Air+Ground | 575 | 0.8 s | 90 | corcrwh_krowlaserh | B | RMB |
| Cortex | Dragon | corcrwh | 5 | HighEnergyLaser | Beam laser | Air+Ground | 575 | 0.8 s | 90 | corcrwh_krowlaserh | B | RMB |
| Cortex | Dragon | corcrwh | 6 | HighEnergyLaser | Beam laser | Air+Ground | 575 | 0.8 s | 90 | corcrwh_krowlaserh | B | RMB |
| Cortex | Dragon's Maw | cormaw | 1 | Pop-up anti-swarm AoE flamethrower | Flamethrower | Air+Ground | 410 | 1.1 s | 22 | cormaw_dmaw | A | LMB |
| Cortex | Dragon's Rage | cormwall | 1 | CatapultRockets | Missile | Air+Ground | 675 | 15.0 s | 450 | cormwall_exp_heavyrocket | A | LMB |
| Cortex | Duck | coramph | 1 | Torpedo | Torpedo | All | 400 | 6.0 s | 250 | coramph_coramph_weapon1 | B | RMB |
| Cortex | Duck | coramph | 2 | HighEnergyLaser | Beam laser | Air+Ground | 300 | 1.1 s | 150 | coramph_coramph_weapon2 | A | LMB |
| Cortex | Epic Bulwark | cordoomt3 | 1 | Armageddon Heat Ray | Beam laser | Air+Ground | 1350 | 4.0 s | 7500 | cordoomt3_armagmheat | C | MMB |
| Cortex | Epic Bulwark | cordoomt3 | 2 | Long-range g2g tachyon accelerator | Beam laser | Air+Ground | 950 | 6.0 s | 4500 | cordoomt3_armageddon_blue_laser | B | RMB |
| Cortex | Epic Bulwark | cordoomt3 | 3 | High energy g2g laser | Beam laser | Air+Ground | 650 | 0.2 s | 247 | cordoomt3_armageddon_green_laser | A | LMB |
| Cortex | Epic Commander - Final Boss | corcomboss | 1 | J8Laser | Beam laser | Air+Ground | 1250 | 0.0 s | 200 | corcomboss_corcomlaserboss | B | RMB |
| Cortex | Epic Commander - Final Boss | corcomboss | 2 | J8NSLaser | Beam laser | All | 1250 | 0.0 s | 200 | corcomboss_corcomsealaserboss | C | MMB |
| Cortex | Epic Commander - Final Boss | corcomboss | 3 | Darkmatter Photon-Disruptor | D-gun | Air+Ground | 750 | 5.0 s | 999999 | corcomboss_disintegratorxl | A | LMB |
| Cortex | Epic Commando | cormandot4 | 1 | Close-quarters EMP Scattergun | Beam laser | Air+Ground | 250 | 2.2 s | 2000 | cormandot4_commando_stunner | A | LMB |
| Cortex | Epic Commando | cormandot4 | 2 | Disintegrator | D-gun | All | 250 | 0.9 s | 2400 | cormandot4_commando_back_cannon | B | RMB |
| Cortex | Epic Dragon | corcrwt4 | 1 | Demon's Maw, Heavy long range AoE flamethrower | Flamethrower | Air+Ground | 500 | 0.4 s | 40 | corcrwt4_kmaw | A | LMB |
| Cortex | Epic Dragon | corcrwt4 | 2 | Advanced Rapid-Fire Anti-Air Missile Launcher | Missile | Air | 840 | 0.4 s | 400 (air) | corcrwt4_edragon_missile | C | MMB |
| Cortex | Epic Dragon | corcrwt4 | 3 | Ultra HighEnergyLaser | Beam laser | Air+Ground | 625 | 2.5 s | 2000 | corcrwt4_krowbosslaser | B | RMB |
| Cortex | Epic Dragon | corcrwt4 | 4 | Ultra HighEnergyLaser | Beam laser | Air+Ground | 625 | 2.5 s | 2000 | corcrwt4_krowbosslaser | B | RMB |
| Cortex | Epic Dragon | corcrwt4 | 5 | Ultra HighEnergyLaser | Beam laser | Air+Ground | 625 | 2.5 s | 2000 | corcrwt4_krowbosslaser | B | RMB |
| Cortex | Epic Dragon | corcrwt4 | 6 | Ultra HighEnergyLaser | Beam laser | Air+Ground | 625 | 2.5 s | 2000 | corcrwt4_krowbosslaser | B | RMB |
| Cortex | Epic Grunt | corakt4 | 1 | Laser | Beam laser | Air+Ground | 600 | 0.1 s | 100 | corakt4_gator_laser | A | LMB |
| Cortex | Epic Karganeth | corkarganetht4 | 1 | KarganethMissiles | Missile | Air+Ground | 750 | 0.4 s | 700 | corkarganetht4_super_missile | A | LMB |
| Cortex | Epic Karganeth | corkarganetht4 | 2 | ShoulderRockets | Missile | Air | 1050 | 10.0 s | 750 (air) | corkarganetht4_karg_shoulder | B | RMB |
| Cortex | Epic Tzar | corgolt4 | 1 | Huge g2g plasma cannon | Plasma | Air+Ground | 1000 | 4.5 s | 8000 | corgolt4_corlevlr_weapon | B | RMB |
| Cortex | Epic Tzar | corgolt4 | 2 | HighEnergyLaser | Beam laser | Air+Ground | 475 | 0.8 s | 750 | corgolt4_corgol_sidelaser | A | LMB |
| Cortex | Epic Tzar | corgolt4 | 3 | HighEnergyLaser | Beam laser | Air+Ground | 475 | 0.8 s | 750 | corgolt4_corgol_sidelaser | A | LMB |
| Cortex | Eradicator | corerad | 1 | Long-range rapid-fire g2a missile launcher | Missile | Air | 1200 | 1.6 s | 250 (air) | corerad_cor_erad | A | LMB |
| Cortex | Exploiter | corexp | 1 | Light close-quarters g2g laser turret | Beam laser | Air+Ground | 435 | 0.5 s | 75 | corexp_hllt_bottom | A | LMB |
| Cortex | Fiend | corpyro | 1 | FlameThrower | Flamethrower | Air+Ground | 230 | 1.1 s | 17 | corpyro_flamethrower | A | LMB |
| Cortex | Flying Black Hydra | corfblackhyt4 | 1 | BattleshipCannon | Cannon | Air+Ground | 2550 | 5.5 s | 600 | corfblackhyt4_heavyplasma | B | RMB |
| Cortex | Flying Black Hydra | corfblackhyt4 | 2 | HighEnergyLaser | Beam laser | Air+Ground | 830 | 0.9 s | 270 | corfblackhyt4_heavylaser | A | LMB |
| Cortex | Flying Black Hydra | corfblackhyt4 | 3 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 840 | 1.7 s | 150 (air) | corfblackhyt4_ferret_missile | C | MMB |
| Cortex | Flying Black Hydra | corfblackhyt4 | 4 | HighEnergyLaser | Beam laser | Air+Ground | 830 | 0.9 s | 270 | corfblackhyt4_heavylaser | A | LMB |
| Cortex | Flying Black Hydra | corfblackhyt4 | 5 | HighEnergyLaser | Beam laser | Air+Ground | 830 | 0.9 s | 270 | corfblackhyt4_heavylaser | A | LMB |
| Cortex | Flying Black Hydra | corfblackhyt4 | 6 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 840 | 1.7 s | 150 (air) | corfblackhyt4_ferret_missile | C | MMB |
| Cortex | Forge | corforge | 1 | FlameThrower | Flamethrower | Air+Ground | 410 | 1.1 s | 5 | corforge_flamethrower_ce | A | LMB |
| Cortex | Fury | corsent | 1 | Missiles | Cannon | - | 800 | 0.5 s | 0 | corsent_bogus_missile | - | - |
| Cortex | Fury | corsent | 2 | FlakCannon | Cannon | Air | 775 | 0.7 s | 200 (air) | corsent_mobileflak | A | LMB |
| Cortex | Garpike | corgarp | 1 | PincerCannon | Cannon | Air+Ground | 305 | 1.5 s | 116 | corgarp_arm_pincer_gauss | A | LMB |
| Cortex | Goon | corsh | 1 | Light Close-Quarters Fast-Firing g2g Laser | Beam laser | Air+Ground | 230 | 0.6 s | 36 | corsh_armsh_weapon | A | LMB |
| Cortex | Grunt | corak | 1 | Laser | Beam laser | Air+Ground | 215 | 0.5 s | 37 | corak_gator_laser | A | LMB |
| Cortex | Guard | corllt | 1 | Light g2g laser | Beam laser | Air+Ground | 435 | 0.5 s | 75 | corllt_cor_lightlaser | A | LMB |
| Cortex | Gun Platform | corgplat | 1 | Light g2g plasma cannon | Plasma | Air+Ground | 520 | 0.5 s | 97 | corgplat_gun | A | LMB |
| Cortex | Hailstorm | corhurc | 1 | Heavy a2g incinerating warheads | Bomb | Air+Ground | 1280 | 7.0 s | 333 | corhurc_coradvbomb | A | LMB |
| Cortex | Halberd | corhal | 1 | HighEnergyLaser | Beam laser | Air+Ground | 300 | 0.8 s | 275 | corhal_cor_canlaser | A | LMB |
| Cortex | Heat Tiger | corftiger | 1 | HeatRay | Beam laser | Air+Ground | 410 | 0.7 s | 15 | corftiger_cor_tiger_laser | A | LMB |
| Cortex | Heavy Mine | corfmine3 | 1 | Crawlingbomb Dummy Weapon | Melee | - | 64 | 1.0 s | 0 | corfmine3_minerange | - | - |
| Cortex | Heavy Mine | cormine3 | 1 | Crawlingbomb Dummy Weapon | Melee | - | 64 | 1.0 s | 0 | cormine3_minerange | - | - |
| Cortex | Herring | corpt | 1 | Light g2a missile launcher | Missile | Air | 750 | 2.0 s | 120 (air) | corpt_cortruck_aa | B | RMB |
| Cortex | Herring | corpt | 2 | Missiles | Missile | Air+Ground | 650 | 2.0 s | 47 | corpt_cortruck_missile | A | LMB |
| Cortex | Incisor | corgator | 1 | Laser | Beam laser | Air+Ground | 230 | 0.8 s | 75 | corgator_gator_laserx | A | LMB |
| Cortex | Janitor | corfrock | 1 | Advanced g2a rapid missile launcher | Missile | Air | 840 | 0.4 s | 76 (air) | corfrock_aamissile | A | LMB |
| Cortex | Jellyfish | cordl | 1 | Depthcharge launcher | Torpedo | All | 600 | 1.5 s | 225 | cordl_coax_depthcharge | A | LMB |
| Cortex | Juggernaut | corkorg | 1 | GaussCannon | Cannon | Air+Ground | 590 | 1.4 s | 165 | corkorg_corkorg_fire | B | RMB |
| Cortex | Juggernaut | corkorg | 2 | Experimental g2g Eradicator Heat Ray | Beam laser | Air+Ground | 900 | 4.0 s | 5500 | corkorg_corkorg_laser | C | RMB |
| Cortex | Juggernaut | corkorg | 3 | HeavyRockets | Starburst missile | Air+Ground | 950 | 6.0 s | 1000 | corkorg_corkorg_rocket | D | MMB |
| Cortex | Juggernaut | corkorg | 4 | KrogCrush | Cannon | Air+Ground | 55 | 0.2 s | 150 | corkorg_krogkick | A | LMB |
| Cortex | Juggernaut | corkorg | 5 | KrogCrush | Cannon | Air+Ground | 55 | 0.2 s | 150 | corkorg_krogkick | A | LMB |
| Cortex | Juggernaut | corkorg | 6 | KrogStep | Cannon | - | 0 | 1.5 s | 0 | corkorg_krogfootstep | - | - |
| Cortex | Juggernaut | corkorg | 7 | KrogAim | Cannon | - | 10 | 1.0 s | 0 | corkorg_krogweaponaim | - | - |
| Cortex | Juggernaut | corkorg | 8 | KrogRestore | Cannon | - | 10 | 1.0 s | 0 | corkorg_krogweaponrestore | - | - |
| Cortex | Juno | corjuno | 1 | Anti radar/minefield/jammer magnetic impulse rocket | Starburst missile | - | 32000 | 2.0 s | 0 | corjuno_juno_pulse | - | - |
| Cortex | Karganeth | corkarg | 1 | KarganethMissiles | Missile | Air+Ground | 600 | 0.3 s | 180 | corkarg_super_missile | A | LMB |
| Cortex | Karganeth | corkarg | 2 | ShoulderRockets | Missile | Air | 700 | 0.6 s | 100 | corkarg_karg_shoulder | B | RMB |
| Cortex | Kraken | corssub | 1 | AdvTorpedo | Torpedo | All | 850 | 8.0 s | 1650 | corssub_armserp_weapon | A | LMB |
| Cortex | Lamprey | coratl | 1 | Long-range advanced torpedo launcher | Torpedo | All | 890 | 3.0 s | 1100 | coratl_coratl_torpedo | A | LMB |
| Cortex | Laser Tiger | corgatreap | 1 | High energy g2g laser | Beam laser | Air+Ground | 620 | 0.8 s | 261 | corgatreap_cor_laserh1 | A | LMB |
| Cortex | Lasher | cormist | 1 | Light g2a missile launcher | Missile | Air | 700 | 2.5 s | 120 (air) | cormist_cortruck_aa | B | RMB |
| Cortex | Lasher | cormist | 2 | Light g2g missile launcher | Missile | Air+Ground | 575 | 2.5 s | 63 | cormist_cortruck_missile | A | LMB |
| Cortex | Leviathan | corslrpc | 1 | Heavy long range g2g AoE plasma cannon | Plasma | Air+Ground | 4950 | 16.0 s | 2000 | corslrpc_cor_intimidator | A | LMB |
| Cortex | Light Mine | cormine1 | 1 | Crawlingbomb Dummy Weapon | Melee | - | 64 | 1.0 s | 0 | cormine1_minerange | - | - |
| Cortex | Mammoth | corsumo | 1 | HighEnergyLaser | Beam laser | Air+Ground | 650 | 0.6 s | 302 | corsumo_corsumo_weapon | A | LMB |
| Cortex | Mammoth | corsumo | 2 | Laserroar | Cannon | - | 10 | 1.0 s | 0 | corsumo_sumohvylaserroar | - | - |
| Cortex | Mangonel | cormh | 1 | Rocket | Starburst missile | Air+Ground | 700 | 9.0 s | 550 | cormh_cormh_weapon | A | LMB |
| Cortex | Manticore | coraak | 1 | Missiles | Missile | Air | 1300 | 1.4 s | 250 (air) | coraak_coraabot_missile1 | B | RMB |
| Cortex | Manticore | coraak | 2 | Heavy g2a flak cannon | Cannon | Air | 775 | 5.5 s | 300 (air) | coraak_botflak | A | LMB |
| Cortex | Medium Mine | cormine2 | 1 | Crawlingbomb Dummy Weapon | Melee | - | 64 | 1.0 s | 0 | cormine2_minerange | - | - |
| Cortex | Medium Mine | cormine4 | 1 | Crawlingbomb Dummy Weapon | Melee | - | 64 | 1.0 s | 0 | cormine4_minerange | - | - |
| Cortex | Messenger | cormship | 1 | Heavy long-range g2g starburst rocket launcher | Cannon | Air+Ground | 1550 | 8.0 s | 1100 | cormship_rocket | A | LMB |
| Cortex | Messenger | cormship | 2 | Medium Range g2a AA Missiles | Missile | Air | 710 | 2.0 s | 138 (air) | cormship_missile | B | RMB |
| Cortex | Mini Calamity | corminibuzz | 1 | Mini Rapid-fire long-range plasma cannon | Plasma | Air+Ground | 1450 | 0.4 s | 210 | corminibuzz_corminibuzz_weapon | A | LMB |
| Cortex | Monsoon | corseap | 1 | Homing torpedo launcher | Torpedo | All | 600 | 4.0 s | 342 | corseap_armseap_weapon1 | A | LMB |
| Cortex | Naval Birdshot | corenaa | 1 | Heavy g2a flak cannon | Cannon | Air | 850 | 0.5 s | 250 (air) | corenaa_armflak_gun | A | LMB |
| Cortex | Negotiator | corvroc | 1 | Rocket | Starburst missile | Air+Ground | 1310 | 15.0 s | 1700 | corvroc_cortruck_rocket | A | LMB |
| Cortex | Nighthawk | corvamp | 1 | Guided a2a/a2g missile launcher | Missile | Air | 690 | 1.0 s | 24 | corvamp_corvtol_advmissile | A | LMB |
| Cortex | Oasis | corantiship | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 1500 | corantiship_amd_rocket | - | - |
| Cortex | Oasis | corcarry | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 1500 | corcarry_fmd_rocket | - | - |
| Cortex | Obligator | corobligator | 1 | Long range missile battery | Missile | Air+Ground | 1145 | 3.0 s | 255 | corobligator_obligator_missile | B | RMB |
| Cortex | Obligator | corobligator | 2 | Heavy vertical rocket pod | Starburst missile | Air+Ground | 948 | 11.5 s | 671 | corobligator_obligator_rocket | A | LMB |
| Cortex | Onager | coronager | 1 | Medium long-range s2g missile launcher | Starburst missile | All | 600 | 9.0 s | 360 | coronager_stoa_missile | A | LMB |
| Cortex | Oppressor | corroy | 1 | HeavyCannon | Cannon | Air+Ground | 710 | 2.5 s | 385 | corroy_plasma | A | LMB |
| Cortex | Oppressor | corroy | 2 | Depthcharge launcher | Torpedo | All | 400 | 1.9 s | 225 | corroy_depthcharge | B | RMB |
| Cortex | Orca | corsub | 1 | Light torpedo launcher | Torpedo | All | 500 | 2.5 s | 342 | corsub_torpedo | A | LMB |
| Cortex | Orthrus | coranavaldefturret | 1 | Disruptor Bolt | Laser | Air+Ground | 950 | 4.0 s | 900 | coranavaldefturret_cortex_medium_energy_blaster | B | RMB |
| Cortex | Orthrus | coranavaldefturret | 2 | Heavy Plasma Blast Cannon | Plasma | Air+Ground | 750 | 1.5 s | 525 | coranavaldefturret_t1_heavy_plasma_cannon | A | LMB |
| Cortex | Overlord | corhltfus | 1 | High energy g2g laser | Beam laser | Air+Ground | 630 | 0.7 s | 750 | corhltfus_corfhlt_laser | A | LMB |
| Cortex | Overseer | corgate | 1 | PlasmaRepulsor | Shield | - | 10 | 1.0 s | 0 | corgate_repulsor | - | - |
| Cortex | Persecutor | cortoast | 1 | Pop-up long-range heavy g2g plasma cannon | Plasma | Air+Ground | 1390 | 2.1 s | 420 | cortoast_cortoast_gun | A | LMB |
| Cortex | Persecutor | cortoast | 2 | Pop-up long-range heavy g2g plasma cannon | Plasma | Air+Ground | 1390 | 2.1 s | 420 | cortoast_cortoast_gun_high | B | RMB |
| Cortex | Persecutor | cortoast | 3 | Pop-up long-range heavy g2g plasma cannon | Plasma | - | 1390 | 2.1 s | 0 | cortoast_smart_trajectory_dummy | - | - |
| Cortex | Poison Arrow | corparrow | 1 | PoisonArrowCannon | Cannon | Air+Ground | 575 | 1.8 s | 370 | corparrow_cor_parrow | A | LMB |
| Cortex | Pounder | corlevlr | 1 | RiotCannon | Cannon | Air+Ground | 315 | 1.8 s | 190 | corlevlr_corlevlr_weapon | A | LMB |
| Cortex | Predator | corshark | 1 | Rapid armor-piercing torpedoes | Torpedo | All | 400 | 2.2 s | 350 | corshark_armsmart_torpedo | A | LMB |
| Cortex | Prevailer | corfmd | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 1500 | corfmd_fmd_rocket | - | - |
| Cortex | Quad Guard | corhllllt | 1 | Close-quarters light g2g laser | Beam laser | Air+Ground | 475 | 0.2 s | 75 | corhllllt_hllt_1 | A | LMB |
| Cortex | Quad Guard | corhllllt | 2 | Close-quarters light g2g laser | Beam laser | Air+Ground | 475 | 0.3 s | 75 | corhllllt_hllt_2 | B | RMB |
| Cortex | Quad Guard | corhllllt | 3 | Close-quarters light g2g laser | Beam laser | Air+Ground | 475 | 0.4 s | 75 | corhllllt_hllt_3 | C | MMB |
| Cortex | Quad Guard | corhllllt | 4 | Close-quarters light g2g laser | Beam laser | Air+Ground | 475 | 0.5 s | 75 | corhllllt_hllt_4 | D | MMB |
| Cortex | Quaker | cormart | 1 | PlasmaCannon | Plasma | Air+Ground | 800 | 5.0 s | 420 | cormart_cor_artillery | A | LMB |
| Cortex | Rascal | corfav | 1 | Light Close-Quarters g2g Laser | Beam laser | Ground | 180 | 1.1 s | 35 | corfav_cor_laser | A | LMB |
| Cortex | Riptide | corpship | 1 | LightCannon | Cannon | Air+Ground | 480 | 0.8 s | 96 | corpship_plasma | A | LMB |
| Cortex | Salamander | corsala | 1 | Medium g2g Heat Ray | Beam laser | Air+Ground | 340 | 1.1 s | 18 | corsala_cor_heat_laser | A | LMB |
| Cortex | SAM | cormadsam | 1 | Advanced g2a rapid missile launcher | Missile | Air | 950 | 0.4 s | 90 (air) | cormadsam_madsam_missile | A | LMB |
| Cortex | Sanctuary | corgatet3 | 1 | PlasmaRepulsor | Shield | - | 825 | 1.0 s | 0 | corgatet3_repulsor | - | - |
| Cortex | Saviour | cormabm | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 500 | cormabm_cormabm_weapon | - | - |
| Cortex | Scorpion | corvipe | 1 | Heavy g2g sabot rocket launcher | Missile | Air+Ground | 730 | 2.0 s | 825 | corvipe_vipersabot | A | LMB |
| Cortex | Screamer | corscreamer | 1 | Long-range heavy g2a missile launcher | Missile | Air | 2400 | 1.8 s | 750 (air) | corscreamer_cor_advsam | A | LMB |
| Cortex | Sentinel | corsentinel | 1 | Depth Charge Drones | Cannon | Water | 1300 | 2.5 s | 0 | corsentinel_plasma | - | - |
| Cortex | Sentinel | corsentinel | 2 | Depthcharge launcher | Torpedo | All | 600 | 1.5 s | 255 | corsentinel_sentinel_depthcharge | A | LMB |
| Cortex | Sheldon | cormort | 1 | PlasmaCannon | Plasma | Air+Ground | 850 | 1.6 s | 105 | cormort_cor_mort | A | LMB |
| Cortex | Shiva | corshiva | 1 | HeavyCannon | Cannon | Air+Ground | 650 | 2.0 s | 600 | corshiva_shiva_gun | A | LMB |
| Cortex | Shiva | corshiva | 2 | HeavyRockets | Starburst missile | Air+Ground | 800 | 7.0 s | 750 | corshiva_shiva_rocket | B | RMB |
| Cortex | Shuriken | corbw | 1 | Light EMP laser | Beam laser | Air+Ground | 220 | 1.2 s | 600 | corbw_bladewing_lyzer | A | LMB |
| Cortex | Siegebreaker | corsiegebreaker | 1 | Overcharged Dreadshot Ion Accelerator | Beam laser | Air+Ground | 910 | 8.0 s | 4000 | corsiegebreaker_dreadovercharge | A | LMB |
| Cortex | Skuttle | corsktl | 1 | Crawlingbomb Dummy Weapon | Melee | Water | 42 | 0.1 s | 0 | corsktl_crawl_dummy | - | - |
| Cortex | Skuttle | corsktl | 2 | Mine Detonator | Cannon | - | 1 | 0.1 s | 0 | corsktl_crawl_detonator | - | - |
| Cortex | Slingshot | corfrt | 1 | Light g2a missile launcher | Missile | Air | 765 | 1.7 s | 115 (air) | corfrt_corrl_missile | A | LMB |
| Cortex | Spectre | corspy | 1 | Dummy Weapon | Melee | Water | 100 | 0.1 s | 0 | corspy_crawl_dummy | - | - |
| Cortex | Sumo | corcan | 1 | HighEnergyLaser | Beam laser | Air+Ground | 275 | 0.8 s | 275 | corcan_cor_canlaser | A | LMB |
| Cortex | Sumo | corcan | 2 | Laserroar | Cannon | - | 10 | 1.0 s | 0 | corcan_canhvylaserroar | - | - |
| Cortex | Supporter | coresupp | 1 | LightLaser | Beam laser | Air+Ground | 280 | 0.9 s | 41 | coresupp_laser | A | LMB |
| Cortex | Supporter | coresupp | 2 | LightLaser | Beam laser | Air+Ground | 280 | 0.9 s | 41 | coresupp_laser | A | LMB |
| Cortex | Termite | cortermite | 1 | HeatRay | Beam laser | Air+Ground | 340 | 0.8 s | 265 | cortermite_cor_termite_laser | A | LMB |
| Cortex | Thermite | corthermite | 1 | Thermite Heatray | Beam laser | Air+Ground | 900 | 4.0 s | 2000 | corthermite_thermite_laser | B | RMB |
| Cortex | Thermite | corthermite | 2 | Thermite heavy medium range AoE flamethrower | Flamethrower | Air+Ground | 350 | 0.4 s | 30 | corthermite_tmaw | A | LMB |
| Cortex | Thistle | corrl | 1 | Light g2a missile launcher | Missile | Air | 765 | 1.7 s | 115 (air) | corrl_corrl_missile | A | LMB |
| Cortex | Thug | corthud | 1 | PlasmaCannon | Plasma | Air+Ground | 380 | 1.7 s | 104 | corthud_arm_ham | A | LMB |
| Cortex | Tiger | correap | 1 | PlasmaCannon | Plasma | Air+Ground | 410 | 0.8 s | 120 | correap_cor_reap | A | LMB |
| Cortex | Torch | cortorch | 1 | Flamethrower | Missile | Air+Ground | 280 | 0.7 s | 85 | cortorch_flame_thrower | A | LMB |
| Cortex | Trapper | cormlv | 1 | Seismic charge | Cannon | Air+Ground | 220 | 3.0 s | 15 | cormlv_minesweep | A | LMB |
| Cortex | Trasher | corcrash | 1 | Missiles | Missile | Air | 760 | 2.0 s | 110 (air) | corcrash_corbot_missile | A | LMB |
| Cortex | Tremor | cortrem | 1 | RapidArtillery | Artillery | Air+Ground | 1470 | 0.5 s | 200 | cortrem_tremor_spread_fire | A | LMB |
| Cortex | Twin Guard | corhllt | 1 | Close-quarters light g2g laser | Beam laser | Air+Ground | 490 | 0.5 s | 75 | corhllt_hllt_top | B | RMB |
| Cortex | Twin Guard | corhllt | 2 | Close-quarters light g2g laser | Beam laser | Air+Ground | 400 | 0.5 s | 75 | corhllt_hllt_bottom | A | LMB |
| Cortex | Tzar | corgol | 1 | HeavyCannon | Cannon | Air+Ground | 650 | 3.5 s | 900 | corgol_cor_gol | A | LMB |
| Cortex | Urchin | cortl | 1 | Torpedo launcher | Torpedo | All | 500 | 1.5 s | 280 | cortl_torpedo | A | LMB |
| Cortex | Valiant | corveng | 1 | Light guided a2a missile launcher | Missile | Air | 680 | 0.9 s | 12 | corveng_corvtol_missile | A | LMB |
| Cortex | Vesuvius | corves | 1 | Huge g2g plasma cannon | Plasma | Air+Ground | 1000 | 4.5 s | 8000 | corves_corlevlr_weapon | B | RMB |
| Cortex | Vesuvius | corves | 2 | Banisher | Missile | Air+Ground | 800 | 7.5 s | 1000 | corves_banisher | C | MMB |
| Cortex | Vesuvius | corves | 3 | Banisher | Missile | Air+Ground | 800 | 7.5 s | 1000 | corves_banisher | C | MMB |
| Cortex | Vesuvius | corves | 4 | Demon's Maw, Heavy long range AoE flamethrower | Flamethrower | Air+Ground | 400 | 0.4 s | 48 | corves_flamethrower | A | LMB |
| Cortex | Warden | corhlt | 1 | High energy g2g laser | Beam laser | Air+Ground | 620 | 1.2 s | 261 | corhlt_cor_laserh1 | A | LMB |
| Cortex | Wasp | corape | 1 | Heavy a2g shrapnel rockets | Missile | Air+Ground | 410 | 1.1 s | 122 | corape_vtol_rocket | A | LMB |
| Cortex | Whirlwind | corshad | 1 | Medium a2g incinerating warheads | Bomb | Air+Ground | 1280 | 6.0 s | 112 | corshad_corbomb | A | LMB |
| Cortex | Wolverine | corwolv | 1 | LightArtillery | Artillery | Air+Ground | 710 | 7.1 s | 300 | corwolv_corwolv_gun | A | LMB |
| Legion | Aegis | legabm | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 1500 | legabm_fmd_rocket | - | - |
| Legion | Aesacus | legatorpbomber | 1 | Medium Homing Torpedo Launcher | Torpedo | All | 400 | 7.0 s | 750 | legatorpbomber_legair_torp | A | LMB |
| Legion | Aesacus | legatorpbomber | 2 | Medium Homing Torpedo Launcher | Torpedo | All | 400 | 7.0 s | 750 | legatorpbomber_legair_torp | A | LMB |
| Legion | Ajax | legafigdef | 1 | Heavy A2A Gatling Guns | Laser | Air | 600 | 1.0 s | 80 (air) | legafigdef_leggun | A | LMB |
| Legion | Alaris | leghades | 1 | Dual-Feed Medium Shotgun | Laser | Air+Ground | 211 | 1.2 s | 10 | leghades_legion_shotgun | A | LMB |
| Legion | Alpheus | legah | 1 | Light G2A Gatling Gun | Laser | Air+Ground | 700 | 0.4 s | 5 | legah_aagun | A | LMB |
| Legion | Amputator | legcluster | 1 | Long-Range g2g Cluster Plasma Cannon | Plasma | Air+Ground | 1000 | 6.0 s | 300 | legcluster_plasma | A | LMB |
| Legion | Amputator | legcluster | 2 | Long-Range g2g Cluster Plasma Cannon | Plasma | Air+Ground | 1000 | 6.0 s | 300 | legcluster_plasma_high | B | RMB |
| Legion | Amputator | legcluster | 3 | Long-Range g2g Cluster Plasma Cannon | Plasma | - | 1000 | 4.0 s | 0 | legcluster_smart_trajectory_dummy | - | - |
| Legion | Apollyon | legapollyon | 1 | Heavy rotary cannon | Laser | Air+Ground | 750 | 0.4 s | 50 | legapollyon_legapollyon_gatling_big | B | RMB |
| Legion | Apollyon | legapollyon | 2 | Heavy rotary cannon | Laser | Air+Ground | 750 | 0.4 s | 50 | legapollyon_legapollyon_gatling_big | B | RMB |
| Legion | Apollyon | legapollyon | 3 | Heavy rotary cannon | Laser | Air+Ground | 750 | 0.4 s | 50 | legapollyon_legapollyon_gatling_big | B | RMB |
| Legion | Apollyon | legapollyon | 4 | Heavy rotary cannon | Laser | Air+Ground | 750 | 0.4 s | 50 | legapollyon_legapollyon_gatling_big | B | RMB |
| Legion | Apollyon | legapollyon | 5 | Heavy rotary cannon | Laser | Air+Ground | 450 | 0.4 s | 20 | legapollyon_legapollyon_gatling_small | A | LMB |
| Legion | Apollyon | legapollyon | 6 | Heavy rotary cannon | Laser | Air+Ground | 450 | 0.4 s | 20 | legapollyon_legapollyon_gatling_small | A | LMB |
| Legion | Apollyon | legapollyon | 7 | Dual Rotary Microflak Cannons | Cannon | Air | 800 | 0.2 s | 58 (air) | legapollyon_legapollyon_gatling_aa | C | MMB |
| Legion | Apollyon | legapollyon | 8 | Dual Rotary Microflak Cannons | Cannon | Air | 800 | 0.2 s | 58 (air) | legapollyon_legapollyon_gatling_aa | C | MMB |
| Legion | Apollyon | legapollyon | 9 | CatapultRockets | Missile | Air+Ground | 1200 | 8.0 s | 465 | legapollyon_legapollyon_missile | D | MMB |
| Legion | Apollyon | legapollyon | 10 | CatapultRockets | Missile | Air+Ground | 1200 | 8.0 s | 465 | legapollyon_legapollyon_missile | D | MMB |
| Legion | Aquilon | legadvaabot | 1 | Rotary Microflak Cannon | Cannon | Air | 700 | 0.4 s | 40 (air) | legadvaabot_leg_t2_microflak_mobile | A | LMB |
| Legion | Aquilon | legadvaabot | 2 | Light Anti-Air Railgun | Laser | Air | 1151 | 3.0 s | 225 (air) | legadvaabot_aa_railgun | B | RMB |
| Legion | Archaic Sol Invictus | legeheatraymech_old | 1 | Targeting System | Cannon | - | 750 | 2.5 s | 0 | legeheatraymech_old_aimhull | - | - |
| Legion | Archaic Sol Invictus | legeheatraymech_old | 2 | Experimental Thermal Ordnance Generators | Beam laser | Air+Ground | 800 | 0.0 s | 33 | legeheatraymech_old_heatray1 | A | LMB |
| Legion | Archaic Sol Invictus | legeheatraymech_old | 3 | Experimental Thermal Ordnance Generators | Beam laser | Air+Ground | 800 | 0.0 s | 33 | legeheatraymech_old_heatray1 | A | LMB |
| Legion | Archaic Sol Invictus | legeheatraymech_old | 4 | Experimental Thermal Ordnance Generators | Beam laser | Air+Ground | 800 | 0.0 s | 33 | legeheatraymech_old_heatray1 | A | LMB |
| Legion | Archaic Sol Invictus | legeheatraymech_old | 5 | Experimental Thermal Ordnance Generators | Beam laser | Air+Ground | 800 | 0.0 s | 33 | legeheatraymech_old_heatray1 | A | LMB |
| Legion | Archaic Sol Invictus | legeheatraymech_old | 6 | Anti-Air Flak Cannon | Cannon | Air | 700 | 0.9 s | 190 (air) | legeheatraymech_old_legflak_gun | B | RMB |
| Legion | Archaic Sol Invictus | legeheatraymech_old | 7 | Footsteps | Cannon | - | 0 | 1.5 s | 0 | legeheatraymech_old_bigfootstep | - | - |
| Legion | Architeuthis | leganavybattlesub | 1 | Packhound Torpedo System | Torpedo | All | 600 | 2.5 s | 150 | leganavybattlesub_torpedo_swarm | A | LMB |
| Legion | Argonaut | legnavyfrigate | 1 | Deck Torpedo Launcher | Torpedo | All | 460 | 1.3 s | 140 | legnavyfrigate_leg_torpedo_launcher | A | LMB |
| Legion | Argonaut | legnavyfrigate | 2 | Deck Torpedo Launcher | Torpedo | All | 460 | 1.3 s | 140 | legnavyfrigate_leg_alt_torpedo_launcher | B | RMB |
| Legion | Arquebus | legsrail | 1 | Railgun | Laser | Air+Ground | 850 | 7.0 s | 850 | legsrail_railgunt2 | A | LMB |
| Legion | Astraeus | legelrpcmech | 1 | Long-Range g2g Heavy Cluster Plasma Cannon | Plasma | Air+Ground | 3100 | 14.4 s | 600 | legelrpcmech_shocker_low | A | LMB |
| Legion | Astrapios | legspfighter | 1 | Light Salvo Missile Launcher | Missile | Air | 760 | 0.8 s | 37 (air) | legspfighter_leg_light_antiair_missile | A | LMB |
| Legion | Ballista | legbal | 1 | Rockets | Missile | Air+Ground | 460 | 5.5 s | 250 | legbal_leg_bot_rocket | A | LMB |
| Legion | Barrage | legbar | 1 | Napalm Launcher | Cannon | Air+Ground | 535 | 5.0 s | 60 | legbar_clusternapalm | A | LMB |
| Legion | Bastion | legbastion | 1 | Heavy Sustained Sweepfire Heat Ray | Beam laser | Air+Ground | 1100 | 3.0 s | 155 | legbastion_t2heatray | A | LMB |
| Legion | Belcher | legbart | 1 | Heavy Napalm Launcher | Cannon | Air+Ground | 625 | 4.0 s | 60 | legbart_clusternapalm | A | LMB |
| Legion | Blindfold | legcib | 1 | Anti radar/minefield/jammer magnetic impulse bomb | Missile | - | 450 | 10.0 s | 0 | legcib_juno_pulse_mini | - | - |
| Legion | Bombardier | legbombard | 1 | Pop-up heavy g2g grenade launcher | Cannon | Air+Ground | 750 | 3.0 s | 375 | legbombard_bombardier_weapon | A | LMB |
| Legion | Boreas | legavroc | 1 | Heavy Long-Range g2g High-Trajectory Starburst Rocket Launcher | Starburst missile | Air+Ground | 1300 | 18.0 s | 2000 | legavroc_armtruck_rocket | A | LMB |
| Legion | Bramble | legrl | 1 | Light g2a Missile Launcher | Missile | Air | 765 | 1.7 s | 115 (air) | legrl_legrl_missile | A | LMB |
| Legion | Cacophony | legmg | 1 | Heavy Rapid-fire Machine Gun | Laser | Air+Ground | 575 | 0.4 s | 17 | legmg_armmg_weapon | A | LMB |
| Legion | Cardea | legcar | 1 | Medium Shotgun | Laser | Air+Ground | 321 | 2.0 s | 40 | legcar_shot | A | LMB |
| Legion | Cetus | legamphtank | 1 | Light Close-quarters Gauss Cannon | Cannon | Air+Ground | 305 | 1.5 s | 116 | legamphtank_leg_amph_gauss | A | LMB |
| Legion | Charon | legvflak | 1 | Dual Rotary Microflak Cannons | Cannon | Air | 800 | 0.2 s | 40 (air) | legvflak_leg_t2_microflak_mobile | A | LMB |
| Legion | Charybdis | legehovertank | 1 | Heavy Sweepfire Heatray | Beam laser | Air+Ground | 425 | 3.0 s | 25 | legehovertank_heat_ray | A | LMB |
| Legion | Charybdis | legehovertank | 2 | Depthcharge Launcher | Torpedo | All | 400 | 2.0 s | 225 | legehovertank_depthcharge | B | RMB |
| Legion | Charybdis | legehovertank | 3 | Parabolic Trajectory Multi-Rocket Launcher | Missile | Air+Ground | 500 | 6.0 s | 100 | legehovertank_parabolic_rockets | C | RMB |
| Legion | Charybdis | legehovertank | 4 | Parabolic Trajectory Multi-Rocket Launcher | Missile | Air+Ground | 500 | 6.0 s | 100 | legehovertank_parabolic_rockets | C | RMB |
| Legion | Chimera | legapopupdef | 1 | Heavy Riot Blast Cannon | Cannon | Air+Ground | 730 | 1.7 s | 280 | legapopupdef_advanced_riot_cannon | B | RMB |
| Legion | Chimera | legapopupdef | 2 | Dual Rotary Machine Guns | Laser | Air+Ground | 600 | 0.4 s | 10 | legapopupdef_standard_minigun | A | LMB |
| Legion | Chimera | legapopupdef | 3 | Dual Rotary Machine Guns | Laser | Air+Ground | 600 | 0.4 s | 10 | legapopupdef_standard_minigun | A | LMB |
| Legion | Cleaver | legamcluster | 1 | Long-range g2g plasma cannon | Plasma | Air+Ground | 930 | 7.2 s | 300 | legamcluster_cluster_artillery | A | LMB |
| Legion | Combat Commander | legcomt2com | 1 | Rapid-fire a2g machine guns | Laser | Air+Ground | 400 | 0.2 s | 20 | legcomt2com_armmg_weapon | B | RMB |
| Legion | Combat Commander | legcomt2com | 2 | Level1TorpedoLauncher | Torpedo | All | 400 | 1.5 s | 250 | legcomt2com_torpedo | C | MMB |
| Legion | Combat Commander | legcomt2com | 3 | EMP Grenade | EMP cannon | Air+Ground | 300 | 8.0 s | 10000 | legcomt2com_disintegrator | A | LMB |
| Legion | Combat Commander | legcomt2com | 4 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 450 | 0.8 s | 150 (air) | legcomt2com_ferret_missile | D | MMB |
| Legion | Combat Commander | legcomt2com | 5 | Parabolic trajectory g2g multi-rocket launcher | Missile | Air+Ground | 600 | 1.2 s | 200 | legcomt2com_adv_rocket | E | MMB |
| Legion | Corinth | leganavyartyship | 1 | Dual Quad-Barrelled Long-Range Cluster Plasma Cannon | Plasma | Air+Ground | 2100 | 8.4 s | 350 | leganavyartyship_leg_mobile_cluster_lrpc_cannon | B | RMB |
| Legion | Corinth | leganavyartyship | 2 | Heavy Artillery Cluster Plasma Cannon | Plasma | Air+Ground | 1600 | 2.8 s | 250 | leganavyartyship_leg_mobile_cluster_plasma | A | LMB |
| Legion | Corinth | leganavyartyship | 3 | Heavy Artillery Cluster Plasma Cannon | Plasma | Air+Ground | 1600 | 2.8 s | 250 | leganavyartyship_leg_mobile_cluster_plasma | A | LMB |
| Legion | Corinth | leganavyartyship | 4 | Heavy Artillery Cluster Plasma Cannon | Plasma | Air+Ground | 1600 | 2.8 s | 250 | leganavyartyship_leg_mobile_cluster_plasma | A | LMB |
| Legion | Daedalus | legerailtank | 1 | Siege Rail Accelerator | Laser | Air+Ground | 1000 | 3.0 s | 800 | legerailtank_t3_rail_accelerator | A | LMB |
| Legion | Daedalus | legerailtank | 2 | Siege Rail Accelerator | Laser | Air+Ground | 1000 | 3.0 s | 800 | legerailtank_t3_rail_accelerator | A | LMB |
| Legion | Daedalus | legerailtank | 3 | Siege Rail Accelerator | Laser | Air+Ground | 1000 | 3.0 s | 800 | legerailtank_t3_rail_accelerator | A | LMB |
| Legion | Decurion | leggat | 1 | Rapid-fire Machine Gun | Laser | Air+Ground | 361 | 0.4 s | 12 | leggat_armmg_weapon | A | LMB |
| Legion | Delphinus | leganavaltorpturret | 1 | Long-range advanced torpedo launcher | Torpedo | All | 890 | 3.0 s | 1100 | leganavaltorpturret_leganavaltorpturret_torpedo | A | LMB |
| Legion | Dragon's Claw | legdtl | 1 | Close-quarters g2g lightning turret | Lightning | Air+Ground | 440 | 1.1 s | 21 | legdtl_dclaw | A | LMB |
| Legion | Dragon's Constitution | legrwall | 1 | Compact Railgun | Laser | Air+Ground | 950 | 4.5 s | 1000 | legrwall_railgunt2 | A | LMB |
| Legion | Dragon's Jaw | legdtr | 1 | Area Control Riot Cannon | Cannon | Air+Ground | 400 | 2.0 s | 240 | legdtr_corlevlr_weapon | A | LMB |
| Legion | Dragon's Maw | legdtf | 1 | Pop-up anti-swarm AoE flamethrower | Flamethrower | Air+Ground | 410 | 1.1 s | 16 | legdtf_dmaw | A | LMB |
| Legion | Dragon's Tail | legdtm | 1 | Rocket | Starburst missile | Air+Ground | 500 | 5.0 s | 550 | legdtm_cormh_weapon | A | LMB |
| Legion | Economy Commander | legcomecon | 1 | RiotCannon | Cannon | Air+Ground | 280 | 2.4 s | 190 | legcomecon_corlevlr_weapon | A | LMB |
| Legion | Economy Commander | legcomecon | 2 | Level1TorpedoLauncher | Torpedo | All | 300 | 2.0 s | 250 | legcomecon_torpedo | C | MMB |
| Legion | Economy Commander | legcomecon | 3 | EMP Grenade | EMP cannon | Air+Ground | 300 | 8.0 s | 10000 | legcomecon_disintegrator | B | RMB |
| Legion | Economy Commander | legcomecon | 4 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 450 | 1.2 s | 150 (air) | legcomecon_ferret_missile | D | MMB |
| Legion | Eidolon | legaspy | 1 | coconut.jpg | Melee | Water | 100 | 0.1 s | 0 | legaspy_crawl_dummy | - | - |
| Legion | Elysium | leggatet3 | 1 | PlasmaRepulsor | Shield | - | 710 | 1.0 s | 0 | leggatet3_repulsor | - | - |
| Legion | Enyo | legspsurfacegunship | 1 | Area Control Riot Cannon | Cannon | Air+Ground | 400 | 3.5 s | 200 | legspsurfacegunship_leg_riot_cannon | A | LMB |
| Legion | Epic Arquebus | legsrailt4 | 1 | Railgun | Laser | Air+Ground | 1600 | 4.0 s | 6000 | legsrailt4_railgunt2 | A | LMB |
| Legion | Epic Goblin | leggobt3 | 1 | Rapid-fire close quarters machine guns | Laser | Air+Ground | 475 | 0.6 s | 224 | leggobt3_semiauto | A | LMB |
| Legion | Epic Mosquito | legmost3 | 1 | CatapultRockets | Missile | Air+Ground | 700 | 3.0 s | 200 | legmost3_exp_heavyrocket | A | LMB |
| Legion | Epic Tyrannus | legfortt4 | 1 | PlasmaCannon | Plasma | Air+Ground | 1200 | 1.0 s | 480 | legfortt4_plasma | B | RMB |
| Legion | Epic Tyrannus | legfortt4 | 2 | PlasmaCannon | Plasma | Air+Ground | 1200 | 1.0 s | 480 | legfortt4_plasma | B | RMB |
| Legion | Epic Tyrannus | legfortt4 | 3 | scav rapid fire plasma gun | Laser | Air+Ground | 800 | 0.1 s | 50 | legfortt4_semiauto | A | LMB |
| Legion | Epic Tyrannus | legfortt4 | 4 | scav rapid fire plasma gun | Laser | Air+Ground | 800 | 0.1 s | 50 | legfortt4_semiauto | A | LMB |
| Legion | Epic Tyrannus | legfortt4 | 5 | scav rapid fire plasma gun | Laser | Air+Ground | 800 | 0.1 s | 50 | legfortt4_semiauto | A | LMB |
| Legion | Epic Tyrannus | legfortt4 | 6 | Advanced d2a rapid missile launcher | Starburst missile | Air | 1240 | 0.2 s | 154 (air) | legfortt4_aa_missiles | C | MMB |
| Legion | Euryale | legctl | 1 | Homing Torpedo Launcher | Torpedo | All | 600 | 1.5 s | 225 | legctl_torplauncher | A | LMB |
| Legion | Eviscerator | legacluster | 1 | Pop-Up Long-range g2g Cluster Plasma Cannon | Plasma | Air+Ground | 1380 | 3.5 s | 414 | legacluster_plasma | A | LMB |
| Legion | Eviscerator | legacluster | 2 | Pop-Up Long-range g2g Cluster Plasma Cannon | Plasma | Air+Ground | 1380 | 3.5 s | 414 | legacluster_plasma_high | B | RMB |
| Legion | Eviscerator | legacluster | 3 | Pop-Up Long-range g2g Cluster Plasma Cannon | Plasma | - | 1380 | 2.6 s | 0 | legacluster_smart_trajectory_dummy | - | - |
| Legion | Fulmen | leganavalaaturret | 1 | Dual Rotary Microflak Cannons | Cannon | Air | 875 | 0.2 s | 58 (air) | leganavalaaturret_leg_t2_microflak | A | LMB |
| Legion | Gelasma | legfmg | 1 | Rapid-Fire Gatling Gun | Laser | Air+Ground | 575 | 0.4 s | 18 | legfmg_gatling_gun | A | LMB |
| Legion | Gladiator | legaskirmtank | 1 | Heavy Rotary Plasma Cannon | Plasma | Air+Ground | 600 | 2.0 s | 70 | legaskirmtank_legmgplasma | A | LMB |
| Legion | Glaucus | legsh | 1 | Light Close-Quarters g2g Heat Ray | Beam laser | Air+Ground | 260 | 1.0 s | 60 | legsh_heat_ray | A | LMB |
| Legion | Goblin | leggob | 1 | Rapid-fire a2g machine guns | Laser | Air+Ground | 261 | 0.9 s | 12 | leggob_semiauto | A | LMB |
| Legion | Harbinger | legmineb | 1 | LegionMineBomb | Bomb | - | 1600 | 10.0 s | 0 | legmineb_cor_seaadvbomb | - | - |
| Legion | Heavy Mine | legmine3 | 1 | BOOM | Melee | - | 64 | 1.0 s | 0 | legmine3_minerange | - | - |
| Legion | Hecate | leganavyantinukecarrier | 1 | Multi-Drone Control Matrix | Cannon | - | 1300 | 2.5 s | 0 | leganavyantinukecarrier_leg_drone_controller | - | - |
| Legion | Hecate | leganavyantinukecarrier | 2 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 1500 | leganavyantinukecarrier_amd_rocket | - | - |
| Legion | Hecatoncheir | legspcarrier | 1 | Drone Targeting System | Cannon | - | 1000 | 2.5 s | 0 | legspcarrier_leg_drone_controller | - | - |
| Legion | Helios | leghelios | 1 | Light g2g Heat Ray | Beam laser | Air+Ground | 320 | 1.3 s | 135 | leghelios_heat_ray | A | LMB |
| Legion | Hera | legavantinuke | 1 | ICBM Interceptor Missile Launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 500 | legavantinuke_legavantinuke_weapon | - | - |
| Legion | Hippocampus | legnavyscout | 1 | Twin Rapid-fire Machine Guns | Laser | Air+Ground | 351 | 0.4 s | 12 | legnavyscout_mg_guns | A | LMB |
| Legion | Hive | leghive | 1 | HeavyCannon | Cannon | - | 1100 | 2.5 s | 0 | leghive_plasma | - | - |
| Legion | Hoplite | legstr | 1 | Twin Rapid-fire Machine Guns | Laser | Air+Ground | 280 | 0.4 s | 8 | legstr_armmg_weapon | A | LMB |
| Legion | Iapetus | legnavyaaship | 1 | Advanced g2a Salvo Missile Launcher | Missile | Air | 760 | 0.6 s | 24 (air) | legnavyaaship_light_antiair_missile | A | LMB |
| Legion | Incinerator | leginc | 1 | Heavy g2g Sustained Heat Ray | Beam laser | Air+Ground | 725 | 0.0 s | 33 | leginc_heatraylarge | A | LMB |
| Legion | Inferno | leginf | 1 | Heavy Burst-Fire Napalm Artillery Tri-Cannons | Artillery | Air+Ground | 1200 | 7.0 s | 60 | leginf_rapidnapalm | A | LMB |
| Legion | Infestor | leginfestor | 1 | Close-Quarters Light Heat Ray | Beam laser | Air+Ground | 300 | 1.0 s | 120 | leginfestor_festorbeam | A | LMB |
| Legion | Ionia | leganavaldefturret | 1 | Dual Rotary Heavy-Calibre Machine Guns | Laser | Air+Ground | 700 | 0.4 s | 24 | leganavaldefturret_legion_heavy_minigun | B | RMB |
| Legion | Ionia | leganavaldefturret | 2 | Dual Heavy Assault Kinetic Shotgun | Laser | Air+Ground | 501 | 1.2 s | 30 | leganavaldefturret_advanced_shotgun | A | LMB |
| Legion | Javelin | legjav | 1 | Twin Rapid-fire Machine Guns | Laser | Air+Ground | 450 | 0.4 s | 12 | legjav_mg_guns | A | LMB |
| Legion | Javelin | legjav | 2 | Light AA Rotary Gun | Laser | Air | 700 | 0.4 s | 10 (air) | legjav_aa_gun | B | RMB |
| Legion | Juno | legjuno | 1 | Anti-Radar/Jammer/Mine Electromagnetic Payload | Starburst missile | - | 32000 | 2.0 s | 0 | legjuno_juno_pulse | - | - |
| Legion | Karkinos | legkark | 1 | Light g2g Heat Ray | Beam laser | Air+Ground | 360 | 1.8 s | 160 | legkark_heat_ray | B | RMB |
| Legion | Karkinos | legkark | 2 | Dual-Feed Medium Shotgun | Laser | Air+Ground | 251 | 2.0 s | 20 | legkark_legion_shotgun | A | LMB |
| Legion | Keres | legkeres | 1 | Heavy riot cannon | Cannon | Air+Ground | 450 | 1.7 s | 400 | legkeres_legkeres_cannon | A | LMB |
| Legion | Keres | legkeres | 2 | Heavy rotary cannon | Laser | Air+Ground | 481 | 0.4 s | 10 | legkeres_legkeres_gatling | B | RMB |
| Legion | Keres | legkeres | 3 | Heavy rotary cannon | Laser | Air+Ground | 481 | 0.4 s | 10 | legkeres_legkeres_gatling | B | RMB |
| Legion | Ketea | legnavysub | 1 | Submerged Torpedo Launcher | Torpedo | All | 400 | 1.5 s | 140 | legnavysub_leg_torpedo_launcher | A | LMB |
| Legion | Ladon | legsptorpgunship | 1 | VTOL Torpedo Launcher | Torpedo | All | 460 | 4.5 s | 140 | legsptorpgunship_leg_torpedo_launcher | A | LMB |
| Legion | Lance | legrail | 1 | Railgun | Laser | Air+Ground | 650 | 7.5 s | 200 | legrail_railgun | A | LMB |
| Legion | Lance | legrail | 2 | Railgun | Laser | Air | 750 | 4.0 s | 300 (air) | legrail_aa_railgun | B | RMB |
| Legion | Legion Commander | legcom | 1 | Close-Quarters Heatray | Beam laser | Air+Ground | 300 | 0.8 s | 175 | legcom_legcomlaser | B | RMB |
| Legion | Legion Commander | legcom | 2 | Underwater Torpedo Launcher | Torpedo | All | 300 | 2.0 s | 250 | legcom_torpedo | C | MMB |
| Legion | Legion Commander | legcom | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcom_disintegrator | A | LMB |
| Legion | Legion Commander | legcom | 4 | Anti-Air Missile Launcher | Missile | Air | 300 | 1.2 s | 150 (air) | legcom_aa_missile | D | MMB |
| Legion | Legion Commander | legdecom | 1 | Close-Quarters Heatray | Beam laser | Air+Ground | 300 | 0.8 s | 175 | legdecom_legcomlaser | B | RMB |
| Legion | Legion Commander | legdecom | 2 | Underwater Torpedo Launcher | Torpedo | All | 300 | 2.0 s | 250 | legdecom_torpedo | C | MMB |
| Legion | Legion Commander | legdecom | 3 | Disintegrator | D-gun | All | 262 | 0.9 s | 40 | legdecom_disintegrator | A | LMB |
| Legion | Legion Commander | legdecom | 4 | Anti-Air Missile Launcher | Missile | Air | 450 | 1.2 s | 150 (air) | legdecom_aa_missile | D | MMB |
| Legion | Legion Commander Level 10 | legcomlvl10 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 500 | 0.3 s | 500 | legcomlvl10_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 10 | legcomlvl10 | 2 | MK-X Torpedo Launcher | Torpedo | All | 600 | 0.8 s | 400 | legcomlvl10_torpedo | D | MMB |
| Legion | Legion Commander Level 10 | legcomlvl10 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcomlvl10_disintegrator | A | LMB |
| Legion | Legion Commander Level 10 | legcomlvl10 | 4 | Railgun | Laser | Air+Ground | 950 | 2.0 s | 500 | legcomlvl10_railgunt2 | C | RMB |
| Legion | Legion Commander Level 10 | legcomlvl10 | 5 | Long range bot cannon | Cannon | - | 700 | 0.9 s | 0 | legcomlvl10_botcannon | - | - |
| Legion | Legion Commander Level 10 | legdecomlvl10 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 500 | 0.3 s | 500 | legdecomlvl10_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 10 | legdecomlvl10 | 2 | MK-X Torpedo Launcher | Torpedo | All | 600 | 0.8 s | 400 | legdecomlvl10_torpedo | D | MMB |
| Legion | Legion Commander Level 10 | legdecomlvl10 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | legdecomlvl10_disintegrator | A | LMB |
| Legion | Legion Commander Level 10 | legdecomlvl10 | 4 | Railgun | Laser | Air+Ground | 950 | 2.0 s | 500 | legdecomlvl10_railgunt2 | C | RMB |
| Legion | Legion Commander Level 10 | legdecomlvl10 | 5 | Long range bot cannon | Cannon | - | 700 | 0.9 s | 0 | legdecomlvl10_botcannon | - | - |
| Legion | Legion Commander Level 2 | legcomlvl2 | 1 | Rapid-Fire Machine Gun | Laser | Air+Ground | 300 | 0.4 s | 25 | legcomlvl2_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 2 | legcomlvl2 | 2 | MK-II Torpedo Launcher | Torpedo | All | 350 | 1.6 s | 250 | legcomlvl2_torpedo | C | MMB |
| Legion | Legion Commander Level 2 | legcomlvl2 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcomlvl2_disintegrator | A | LMB |
| Legion | Legion Commander Level 2 | legcomlvl2 | 4 | Anti-Air Missile Launcher | Missile | Air | 450 | 1.2 s | 150 (air) | legcomlvl2_aa_missile | D | MMB |
| Legion | Legion Commander Level 2 | legdecomlvl2 | 1 | Rapid-Fire Machine Gun | Laser | Air+Ground | 300 | 0.4 s | 25 | legdecomlvl2_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 2 | legdecomlvl2 | 2 | MK-II Torpedo Launcher | Torpedo | All | 350 | 1.6 s | 250 | legdecomlvl2_torpedo | C | MMB |
| Legion | Legion Commander Level 2 | legdecomlvl2 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | legdecomlvl2_disintegrator | A | LMB |
| Legion | Legion Commander Level 2 | legdecomlvl2 | 4 | Anti-Air Missile Launcher | Missile | Air | 450 | 1.2 s | 150 (air) | legdecomlvl2_aa_missile | D | MMB |
| Legion | Legion Commander Level 3 | legcomlvl3 | 1 | Rapid-Fire Machine Gun | Laser | Air+Ground | 350 | 0.4 s | 30 | legcomlvl3_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 3 | legcomlvl3 | 2 | MK-III Torpedo Launcher | Torpedo | All | 500 | 1.2 s | 250 | legcomlvl3_torpedo | D | MMB |
| Legion | Legion Commander Level 3 | legcomlvl3 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcomlvl3_disintegrator | A | LMB |
| Legion | Legion Commander Level 3 | legcomlvl3 | 4 | Anti-Air Missile Launcher | Missile | Air | 400 | 1.2 s | 150 (air) | legcomlvl3_aa_missile | C | MMB |
| Legion | Legion Commander Level 3 | legcomlvl3 | 5 | Long range bot cannon | Cannon | - | 400 | 0.9 s | 0 | legcomlvl3_botcannon | - | - |
| Legion | Legion Commander Level 3 | legdecomlvl3 | 1 | Rapid-Fire Machine Gun | Laser | Air+Ground | 350 | 0.4 s | 30 | legdecomlvl3_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 3 | legdecomlvl3 | 2 | MK-III Torpedo Launcher | Torpedo | All | 500 | 1.2 s | 250 | legdecomlvl3_torpedo | D | MMB |
| Legion | Legion Commander Level 3 | legdecomlvl3 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | legdecomlvl3_disintegrator | A | LMB |
| Legion | Legion Commander Level 3 | legdecomlvl3 | 4 | Anti-Air Missile Launcher | Missile | Air | 400 | 1.2 s | 150 (air) | legdecomlvl3_aa_missile | C | MMB |
| Legion | Legion Commander Level 3 | legdecomlvl3 | 5 | Long range bot cannon | Cannon | - | 400 | 0.9 s | 0 | legdecomlvl3_botcannon | - | - |
| Legion | Legion Commander Level 4 | legcomlvl4 | 1 | Rapid-Fire Machine Gun | Laser | Air+Ground | 350 | 0.4 s | 40 | legcomlvl4_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 4 | legcomlvl4 | 2 | MK-IV Torpedo Launcher | Torpedo | All | 450 | 0.8 s | 250 | legcomlvl4_torpedo | D | MMB |
| Legion | Legion Commander Level 4 | legcomlvl4 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcomlvl4_disintegrator | A | LMB |
| Legion | Legion Commander Level 4 | legcomlvl4 | 4 | Railgun | Laser | Air+Ground | 550 | 2.7 s | 250 | legcomlvl4_railgunt2 | C | RMB |
| Legion | Legion Commander Level 4 | legcomlvl4 | 5 | Long range bot cannon | Cannon | - | 500 | 0.9 s | 0 | legcomlvl4_botcannon | - | - |
| Legion | Legion Commander Level 4 | legdecomlvl4 | 1 | Rapid-Fire Machine Gun | Laser | Air+Ground | 350 | 0.4 s | 40 | legdecomlvl4_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 4 | legdecomlvl4 | 2 | MK-IV Torpedo Launcher | Torpedo | All | 450 | 0.8 s | 250 | legdecomlvl4_torpedo | D | MMB |
| Legion | Legion Commander Level 4 | legdecomlvl4 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | legdecomlvl4_disintegrator | A | LMB |
| Legion | Legion Commander Level 4 | legdecomlvl4 | 4 | Railgun | Laser | Air+Ground | 550 | 2.7 s | 250 | legdecomlvl4_railgunt2 | C | RMB |
| Legion | Legion Commander Level 4 | legdecomlvl4 | 5 | Long range bot cannon | Cannon | - | 500 | 0.9 s | 0 | legdecomlvl4_botcannon | - | - |
| Legion | Legion Commander Level 5 | legcomlvl5 | 1 | Rapid-Fire Machine Gun | Laser | Air+Ground | 350 | 0.4 s | 50 | legcomlvl5_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 5 | legcomlvl5 | 2 | MK-V Torpedo Launcher | Torpedo | All | 500 | 0.8 s | 250 | legcomlvl5_torpedo | D | MMB |
| Legion | Legion Commander Level 5 | legcomlvl5 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcomlvl5_disintegrator | A | LMB |
| Legion | Legion Commander Level 5 | legcomlvl5 | 4 | Railgun | Laser | Air+Ground | 620 | 2.7 s | 250 | legcomlvl5_railgunt2 | C | RMB |
| Legion | Legion Commander Level 5 | legcomlvl5 | 5 | Long range bot cannon | Cannon | - | 600 | 0.9 s | 0 | legcomlvl5_botcannon | - | - |
| Legion | Legion Commander Level 5 | legdecomlvl5 | 1 | Rapid-Fire Machine Gun | Laser | Air+Ground | 350 | 0.4 s | 50 | legdecomlvl5_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 5 | legdecomlvl5 | 2 | MK-V Torpedo Launcher | Torpedo | All | 500 | 0.8 s | 250 | legdecomlvl5_torpedo | D | MMB |
| Legion | Legion Commander Level 5 | legdecomlvl5 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | legdecomlvl5_disintegrator | A | LMB |
| Legion | Legion Commander Level 5 | legdecomlvl5 | 4 | Railgun | Laser | Air+Ground | 620 | 2.7 s | 250 | legdecomlvl5_railgunt2 | C | RMB |
| Legion | Legion Commander Level 5 | legdecomlvl5 | 5 | Long range bot cannon | Cannon | - | 600 | 0.9 s | 0 | legdecomlvl5_botcannon | - | - |
| Legion | Legion Commander Level 6 | legcomlvl6 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 425 | 0.3 s | 360 | legcomlvl6_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 6 | legcomlvl6 | 2 | MK-VI Torpedo Launcher | Torpedo | All | 500 | 0.8 s | 300 | legcomlvl6_torpedo | D | MMB |
| Legion | Legion Commander Level 6 | legcomlvl6 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcomlvl6_disintegrator | A | LMB |
| Legion | Legion Commander Level 6 | legcomlvl6 | 4 | Railgun | Laser | Air+Ground | 730 | 2.7 s | 250 | legcomlvl6_railgunt2 | C | RMB |
| Legion | Legion Commander Level 6 | legcomlvl6 | 5 | Long range bot cannon | Cannon | - | 600 | 0.9 s | 0 | legcomlvl6_botcannon | - | - |
| Legion | Legion Commander Level 6 | legdecomlvl6 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 425 | 0.3 s | 360 | legdecomlvl6_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 6 | legdecomlvl6 | 2 | MK-VI Torpedo Launcher | Torpedo | All | 500 | 0.8 s | 300 | legdecomlvl6_torpedo | D | MMB |
| Legion | Legion Commander Level 6 | legdecomlvl6 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | legdecomlvl6_disintegrator | A | LMB |
| Legion | Legion Commander Level 6 | legdecomlvl6 | 4 | Railgun | Laser | Air+Ground | 730 | 2.7 s | 250 | legdecomlvl6_railgunt2 | C | RMB |
| Legion | Legion Commander Level 6 | legdecomlvl6 | 5 | Long range bot cannon | Cannon | - | 600 | 0.9 s | 0 | legdecomlvl6_botcannon | - | - |
| Legion | Legion Commander Level 7 | legcomlvl7 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 425 | 0.3 s | 400 | legcomlvl7_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 7 | legcomlvl7 | 2 | MK-VII Torpedo Launcher | Torpedo | All | 550 | 0.8 s | 300 | legcomlvl7_torpedo | D | MMB |
| Legion | Legion Commander Level 7 | legcomlvl7 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcomlvl7_disintegrator | A | LMB |
| Legion | Legion Commander Level 7 | legcomlvl7 | 4 | Railgun | Laser | Air+Ground | 730 | 2.6 s | 250 | legcomlvl7_railgunt2 | C | RMB |
| Legion | Legion Commander Level 7 | legcomlvl7 | 5 | Long range bot cannon | Cannon | - | 700 | 0.9 s | 0 | legcomlvl7_botcannon | - | - |
| Legion | Legion Commander Level 7 | legdecomlvl7 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 425 | 0.3 s | 400 | legdecomlvl7_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 7 | legdecomlvl7 | 2 | MK-VII Torpedo Launcher | Torpedo | All | 550 | 0.8 s | 300 | legdecomlvl7_torpedo | D | MMB |
| Legion | Legion Commander Level 7 | legdecomlvl7 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | legdecomlvl7_disintegrator | A | LMB |
| Legion | Legion Commander Level 7 | legdecomlvl7 | 4 | Railgun | Laser | Air+Ground | 730 | 2.6 s | 250 | legdecomlvl7_railgunt2 | C | RMB |
| Legion | Legion Commander Level 7 | legdecomlvl7 | 5 | Long range bot cannon | Cannon | - | 700 | 0.9 s | 0 | legdecomlvl7_botcannon | - | - |
| Legion | Legion Commander Level 8 | legcomlvl8 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 500 | 0.2 s | 475 | legcomlvl8_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 8 | legcomlvl8 | 2 | MK-VIII Torpedo Launcher | Torpedo | All | 550 | 0.8 s | 350 | legcomlvl8_torpedo | D | MMB |
| Legion | Legion Commander Level 8 | legcomlvl8 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcomlvl8_disintegrator | A | LMB |
| Legion | Legion Commander Level 8 | legcomlvl8 | 4 | Railgun | Laser | Air+Ground | 800 | 2.4 s | 300 | legcomlvl8_railgunt2 | C | RMB |
| Legion | Legion Commander Level 8 | legcomlvl8 | 5 | Long range bot cannon | Cannon | - | 700 | 0.9 s | 0 | legcomlvl8_botcannon | - | - |
| Legion | Legion Commander Level 8 | legdecomlvl8 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 500 | 0.2 s | 475 | legdecomlvl8_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 8 | legdecomlvl8 | 2 | MK-VIII Torpedo Launcher | Torpedo | All | 550 | 0.8 s | 350 | legdecomlvl8_torpedo | D | MMB |
| Legion | Legion Commander Level 8 | legdecomlvl8 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | legdecomlvl8_disintegrator | A | LMB |
| Legion | Legion Commander Level 8 | legdecomlvl8 | 4 | Railgun | Laser | Air+Ground | 800 | 2.4 s | 300 | legdecomlvl8_railgunt2 | C | RMB |
| Legion | Legion Commander Level 8 | legdecomlvl8 | 5 | Long range bot cannon | Cannon | - | 700 | 0.9 s | 0 | legdecomlvl8_botcannon | - | - |
| Legion | Legion Commander Level 9 | legcomlvl9 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 500 | 0.4 s | 500 | legcomlvl9_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 9 | legcomlvl9 | 2 | MK-IX Torpedo Launcher | Torpedo | All | 550 | 0.8 s | 350 | legcomlvl9_torpedo | D | MMB |
| Legion | Legion Commander Level 9 | legcomlvl9 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 99999 | legcomlvl9_disintegrator | A | LMB |
| Legion | Legion Commander Level 9 | legcomlvl9 | 4 | Railgun | Laser | Air+Ground | 870 | 2.2 s | 400 | legcomlvl9_railgunt2 | C | RMB |
| Legion | Legion Commander Level 9 | legcomlvl9 | 5 | Long range bot cannon | Cannon | - | 700 | 0.9 s | 0 | legcomlvl9_botcannon | - | - |
| Legion | Legion Commander Level 9 | legdecomlvl9 | 1 | Rapid-Fire Plasma Cannon | Plasma | Air+Ground | 500 | 0.4 s | 500 | legdecomlvl9_armmg_weapon | B | RMB |
| Legion | Legion Commander Level 9 | legdecomlvl9 | 2 | MK-IX Torpedo Launcher | Torpedo | All | 550 | 0.8 s | 350 | legdecomlvl9_torpedo | D | MMB |
| Legion | Legion Commander Level 9 | legdecomlvl9 | 3 | Disintegrator | D-gun | All | 250 | 0.9 s | 40 | legdecomlvl9_disintegrator | A | LMB |
| Legion | Legion Commander Level 9 | legdecomlvl9 | 4 | Railgun | Laser | Air+Ground | 870 | 2.2 s | 400 | legdecomlvl9_railgunt2 | C | RMB |
| Legion | Legion Commander Level 9 | legdecomlvl9 | 5 | Long range bot cannon | Cannon | - | 700 | 0.9 s | 0 | legdecomlvl9_botcannon | - | - |
| Legion | Legion Drone | legdrone | 1 | Burst-fire Machine Gun | Laser | Air+Ground | 300 | 0.9 s | 12 | legdrone_semiauto | A | LMB |
| Legion | Legion Heavy Drone | legheavydrone | 1 | a2g Heat Ray | Beam laser | Ground | 430 | 0.8 s | 10 | legheavydrone_heat_ray | A | LMB |
| Legion | Legion Heavy Drone | legheavydronesmall | 1 | a2g Heat Ray | Beam laser | Ground | 430 | 0.8 s | 10 | legheavydronesmall_heat_ray | A | LMB |
| Legion | Legionnaire | legionnaire | 1 | Rapid-fire dual A2A machine guns | Laser | Air | 600 | 1.0 s | 80 (air) | legionnaire_leggun | A | LMB |
| Legion | Leocampus | leganavyantiswarm | 1 | Medium Blast Riot Cannon | Cannon | Air+Ground | 350 | 1.1 s | 210 | leganavyantiswarm_legion_riot_cannon_t2 | A | LMB |
| Legion | Leocampus | leganavyantiswarm | 2 | Advanced g2a Salvo Missile Launcher | Missile | Air | 760 | 1.2 s | 24 (air) | leganavyantiswarm_light_antiair_missile | B | RMB |
| Legion | Light Mine | legmine1 | 1 | BOOM | Melee | - | 64 | 1.0 s | 0 | legmine1_minerange | - | - |
| Legion | Lupara | leglupara | 1 | Medium g2a Flak Blunderbuss | Cannon | Air | 1200 | 1.8 s | 255 (air) | leglupara_legflak_gun | A | LMB |
| Legion | Mantis | legvcarry | 1 | Drone Targeting System | Cannon | - | 1000 | 2.5 s | 0 | legvcarry_targeting | - | - |
| Legion | Martyr | legkam | 1 | Martyr trigger | Laser | - | 500 | 10.0 s | 0 | legkam_trigger | - | - |
| Legion | Martyr | legkam | 2 | Mine Detonator | Cannon | Air | 1 | 0.5 s | 1000 (air) | legkam_crawl_detonator | B | RMB |
| Legion | Martyr | legkam | 3 | Crawlingbomb Dummy Weapon | Bomb | Air+Ground | 500 | 10.0 s | 440 | legkam_martyrbomb | A | LMB |
| Legion | Medium Mine | legmine2 | 1 | BOOM | Melee | - | 64 | 1.0 s | 0 | legmine2_minerange | - | - |
| Legion | Medusa | legmed | 1 | Targeting System | Beam laser | - | 1000 | 0.1 s | 0 | legmed_laser | - | - |
| Legion | Medusa | legmed | 2 | Hexaburst Homing Siege Rockets | Starburst missile | Air+Ground | 1000 | 12.0 s | 500 | legmed_legmed_missile | A | LMB |
| Legion | Mini Starfall | legministarfall | 1 | Long-Range High-Trajectory 63-Salvo Plasma Launcher | Plasma | Air+Ground | 1400 | 7.0 s | 125 | legministarfall_starfire | A | LMB |
| Legion | Mini Starfall | legministarfall | 2 | Mini Plasma Volley Energy Charger (supplies energy to Mini Starfall cannon) | Plasma | - | 1 | 1.0 s | 0 | legministarfall_energycharger | - | - |
| Legion | Mosquito | legmos | 1 | Rockets | Missile | Air+Ground | 380 | 0.8 s | 44 | legmos_cor_bot_rocket | A | LMB |
| Legion | Mukade | legpede | 1 | Rapid-fire a2g machine guns | Laser | Air+Ground | 575 | 0.4 s | 21 | legpede_armmg_weapon | A | LMB |
| Legion | Mukade | legpede | 2 | Railgun | Laser | Air+Ground | 850 | 4.5 s | 500 | legpede_railgunt2 | B | RMB |
| Legion | Mukade | legpede | 3 | Parabolic trajectory g2g multi-rocket launcher | Missile | Air+Ground | 600 | 3.7 s | 200 | legpede_adv_rocket | C | MMB |
| Legion | Mukade | legpede | 4 | Parabolic trajectory g2g multi-rocket launcher | Missile | Air+Ground | 600 | 3.7 s | 200 | legpede_adv_rocket | C | MMB |
| Legion | Mukade | legpede | 5 | Railgun | Laser | Air+Ground | 850 | 4.5 s | 500 | legpede_railgunt2 | B | RMB |
| Legion | Mukade | legpede | 6 | Rapid-fire a2g machine guns | Laser | Air+Ground | 575 | 0.4 s | 21 | legpede_armmg_weapon | A | LMB |
| Legion | Myrmidon | legeallterrainmech | 1 | Heavy Long-Range Cluster Plasma Cannon | Plasma | Air+Ground | 1100 | 2.3 s | 345 | legeallterrainmech_plasma_low | A | LMB |
| Legion | Myrmidon | legeallterrainmech | 2 | Heavy Long-Range High-Trajectory Cluster Plasma Cannon | Plasma | Air+Ground | 1100 | 2.3 s | 345 | legeallterrainmech_plasma_high | B | RMB |
| Legion | Myrmidon | legeallterrainmech | 3 | Smart Artillery Targeting System | Artillery | - | 1380 | 2.6 s | 0 | legeallterrainmech_smart_trajectory_dummy | - | - |
| Legion | Myrmidon | legeallterrainmech | 4 | Advanced g2a Salvo Missile Launcher | Missile | Air | 760 | 2.0 s | 37 (air) | legeallterrainmech_light_antiair_missile | C | MMB |
| Legion | Myrmidon | legeallterrainmech | 5 | Dual-Unit Heatray-Drone Control Matrix | Cannon | - | 1300 | 2.5 s | 0 | legeallterrainmech_drone_controller | - | - |
| Legion | Naval Hive | legfhive | 1 | HeavyCannon | Cannon | - | 1100 | 2.5 s | 0 | legfhive_plasma | - | - |
| Legion | Neptune | leganavyflagship | 1 | Targeting System | Cannon | - | 700 | 2.5 s | 0 | leganavyflagship_targeting_system | - | - |
| Legion | Neptune | leganavyflagship | 2 | Dual Experimental Thermal Ordnance Generators | Beam laser | Air+Ground | 700 | 0.0 s | 33 | leganavyflagship_leg_experimental_heatray | A | LMB |
| Legion | Neptune | leganavyflagship | 3 | Dual Experimental Thermal Ordnance Generators | Beam laser | Air+Ground | 700 | 0.0 s | 33 | leganavyflagship_leg_experimental_heatray | A | LMB |
| Legion | Neptune | leganavyflagship | 4 | Dual Naval-Series Rail Accelerators | Laser | Air+Ground | 1000 | 3.0 s | 800 | leganavyflagship_leg_experimental_railgun | B | RMB |
| Legion | Neptune | leganavyflagship | 5 | Dual Naval-Series Rail Accelerators | Laser | Air+Ground | 1000 | 3.0 s | 800 | leganavyflagship_leg_experimental_railgun | B | RMB |
| Legion | Neptune | leganavyflagship | 6 | Dual Naval-Series Rail Accelerators | Laser | Air+Ground | 1000 | 3.0 s | 800 | leganavyflagship_leg_experimental_railgun | B | RMB |
| Legion | Neptune | leganavyflagship | 7 | Dual Naval-Series Rail Accelerators | Laser | Air+Ground | 1000 | 3.0 s | 800 | leganavyflagship_leg_experimental_railgun | B | RMB |
| Legion | Nereus | legner | 1 | Medium g2g plasma cannon | Plasma | Air+Ground | 370 | 0.9 s | 55 | legner_legner_weapon | A | LMB |
| Legion | Noctua | legfig | 1 | Burst-Fire A2A Machine Gun | Laser | Air | 600 | 0.6 s | 36 (air) | legfig_semiauto | A | LMB |
| Legion | Notus | leganavyaaship | 1 | Dual Rotary Microflak Cannons | Cannon | Air | 800 | 0.2 s | 40 (air) | leganavyaaship_leg_t2_microflak_mobile | A | LMB |
| Legion | Notus | leganavyaaship | 2 | Advanced Salvo Anti-Air Missile Launcher | Missile | Air | 860 | 1.0 s | 20 (air) | leganavyaaship_light_antiair_missile | B | RMB |
| Legion | Notus | leganavyaaship | 3 | Advanced Salvo Anti-Air Missile Launcher | Missile | Air | 860 | 1.0 s | 20 (air) | leganavyaaship_light_antiair_missile | B | RMB |
| Legion | Octeres | legnavyartyship | 1 | Long-Range Naval Cluster Artillery Cannon | Artillery | Air+Ground | 960 | 10.1 s | 300 | legnavyartyship_leg_cluster_artillery_cannon | A | LMB |
| Legion | Octeres | legnavyartyship | 2 | Long-Range Naval Cluster Artillery Cannon | Artillery | Air+Ground | 960 | 10.0 s | 300 | legnavyartyship_leg_cluster_artillery_cannon_2 | B | RMB |
| Legion | Offensive Commander | legcomoff | 1 | Rapid-fire a2g machine guns | Laser | Air+Ground | 400 | 0.4 s | 26 | legcomoff_armmg_weapon | B | RMB |
| Legion | Offensive Commander | legcomoff | 2 | Level1TorpedoLauncher | Torpedo | All | 300 | 2.0 s | 250 | legcomoff_torpedo | C | MMB |
| Legion | Offensive Commander | legcomoff | 3 | EMP Grenade | EMP cannon | Air+Ground | 300 | 8.0 s | 10000 | legcomoff_disintegrator | A | LMB |
| Legion | Offensive Commander | legcomoff | 4 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 450 | 1.2 s | 150 (air) | legcomoff_ferret_missile | D | MMB |
| Legion | Olympus | leglrpc | 1 | Long-Range g2g Heavy Cluster Plasma Cannon | Plasma | Air+Ground | 4800 | 18.0 s | 600 | leglrpc_lrpc | A | LMB |
| Legion | Perdition | legperdition | 1 | Long-Range Tactical Hellfire Napalm Shell | Cannon | Air+Ground | 2300 | 2.0 s | 1200 | legperdition_napalmmissile | A | LMB |
| Legion | Phalanx | legshot | 1 | Medium Blast Riot Cannon | Cannon | Air+Ground | 280 | 2.0 s | 210 | legshot_legion_riot_cannon_t2 | A | LMB |
| Legion | Pharos | leglht | 1 | Light g2g Heat Ray | Beam laser | Air+Ground | 430 | 1.1 s | 200 | leglht_heat_ray | A | LMB |
| Legion | Phobos | legcen | 1 | Close-quarters g2g gauss-cannon | Cannon | Air+Ground | 180 | 1.4 s | 75 | legcen_gauss | A | LMB |
| Legion | Phoenix | legphoenix | 1 | Targeting System | Bomb | - | 1280 | 7.0 s | 0 | legphoenix_legphtarg | - | - |
| Legion | Phoenix | legphoenix | 2 | Heavy a2g Phoenix Flame Heat Ray | Beam laser | Air+Ground | 950 | 8.0 s | 145 | legphoenix_skybeam | A | LMB |
| Legion | Phoenix | legphoenix | 3 | PhoenixBlast | Cannon | - | 10 | 1.0 s | 0 | legphoenix_legphsound | - | - |
| Legion | Phorcys | legnavaldefturret | 1 | Dual-Salvo Medium Rocket Launcher | Missile | Air+Ground | 720 | 2.5 s | 95 | legnavaldefturret_leg_med_anti_naval_salvo_rocket | A | LMB |
| Legion | Pilum | legbunk | 1 | Targeting System | Cannon | - | 650 | 0.1 s | 0 | legbunk_aimhull | - | - |
| Legion | Pilum | legbunk | 2 | Hard-Plasma Mining Tool | D-gun | All | 150 | 2.0 s | 300 | legbunk_piledriver | A | LMB |
| Legion | Pilum | legbunk | 3 | Snub-Nose Railgun | Laser | Air+Ground | 650 | 3.0 s | 475 | legbunk_railgunt2 | B | RMB |
| Legion | Pluto | legflak | 1 | Dual Rotary Microflak Cannons | Cannon | Air | 875 | 0.2 s | 58 (air) | legflak_leg_t2_microflak | A | LMB |
| Legion | Polybolos | legfrl | 1 | Light g2a Missile Launcher | Missile | Air | 765 | 1.7 s | 115 (air) | legfrl_legrl_missile | A | LMB |
| Legion | Praetorian | legeshotgunmech | 1 | Targeting System | Cannon | - | 420 | 2.5 s | 0 | legeshotgunmech_aimhull | - | - |
| Legion | Praetorian | legeshotgunmech | 2 | Dual Heavy Assault Kinetic Shotgun | Laser | Air+Ground | 420 | 0.9 s | 60 | legeshotgunmech_shotgun | A | LMB |
| Legion | Praetorian | legeshotgunmech | 3 | Parabolic Trajectory Multi-Rocket Launcher | Missile | Air+Ground | 700 | 6.0 s | 150 | legeshotgunmech_adv_rocket | B | RMB |
| Legion | Praetorian | legeshotgunmech | 4 | Rotary Microflak Cannon | Cannon | Air | 800 | 0.2 s | 30 (air) | legeshotgunmech_leg_t2_microflak_mobile | C | RMB |
| Legion | Prometheus | legaheattank | 1 | Heavy g2g Cleansing Heat Ray | Beam laser | Air+Ground | 450 | 0.0 s | 25 | legaheattank_heat_ray | A | LMB |
| Legion | Pyrphoros | legspbomber | 1 | Advanced Scatterfire Warheads | Bomb | Air+Ground | 1280 | 8.0 s | 50 | legspbomber_leg_seaplane_bomb | A | LMB |
| Legion | Quickshot | legmrv | 1 | Two-Round Burst Fire Plasma Cannon | Plasma | Air+Ground | 240 | 1.2 s | 72 | legmrv_quickshot_cannon | A | LMB |
| Legion | Rampart | legrampart | 1 | ICBM intercepting missile launcher | Starburst missile | Air+Ground | 72000 | 2.0 s | 1500 | legrampart_fmd_rocket | - | - |
| Legion | Rampart | legrampart | 2 | HeavyCannon | Cannon | - | 1600 | 2.5 s | 0 | legrampart_plasma | - | - |
| Legion | Rhapsis | legrhapsis | 1 | Advanced g2a Salvo Missile Launcher | Missile | Air | 950 | 0.5 s | 15 (air) | legrhapsis_burst_aa_missile | A | LMB |
| Legion | Salacia | legmh | 1 | Rocket | Starburst missile | Air+Ground | 700 | 7.5 s | 400 | legmh_legmh_weapon | A | LMB |
| Legion | Sapper | legmlv | 1 | Seismic charge | Cannon | Air+Ground | 220 | 3.0 s | 15 | legmlv_minesweep | A | LMB |
| Legion | Satyr | leglob | 1 | Forwards Plasma Cannon | Plasma | Air+Ground | 400 | 2.5 s | 75 | leglob_close_plasma | A | LMB |
| Legion | Scylla | leganavybattleship | 1 | Heavy long-range g2g plasma cannon | Plasma | Air+Ground | 750 | 2.7 s | 270 | leganavybattleship_burst_plasma_t2 | C | MMB |
| Legion | Scylla | leganavybattleship | 2 | Heavy long-range g2g plasma cannon | Plasma | Air+Ground | 700 | 2.4 s | 300 | leganavybattleship_burst_plasma_t2_land | B | RMB |
| Legion | Scylla | leganavybattleship | 3 | Medium Shotgun | Laser | Air+Ground | 500 | 2.0 s | 20 | leganavybattleship_legion_shotgun | A | LMB |
| Legion | Scylla | leganavybattleship | 4 | Medium Shotgun | Laser | Air+Ground | 500 | 2.0 s | 20 | leganavybattleship_legion_shotgun | A | LMB |
| Legion | Snapper | legsnapper | 1 | Crawlingbomb Dummy Weapon | Melee | Water | 42 | 0.1 s | 0 | legsnapper_crawl_dummy | - | - |
| Legion | Snapper | legsnapper | 2 | Self-destruction | Cannon | - | 1 | 0.1 s | 0 | legsnapper_crawl_detonator | - | - |
| Legion | Sol Invictus | legeheatraymech | 1 | Targeting System | Cannon | - | 700 | 2.5 s | 0 | legeheatraymech_aimhull | - | - |
| Legion | Sol Invictus | legeheatraymech | 2 | Experimental Thermal Ordnance Generators | Beam laser | Air+Ground | 800 | 0.0 s | 33 | legeheatraymech_heatray1 | B | RMB |
| Legion | Sol Invictus | legeheatraymech | 3 | Experimental Thermal Ordnance Generators | Beam laser | Air+Ground | 800 | 0.0 s | 33 | legeheatraymech_heatray1 | B | RMB |
| Legion | Sol Invictus | legeheatraymech | 4 | Ultra Heavy Riot Autocannon | Cannon | Air+Ground | 550 | 1.2 s | 420 | legeheatraymech_ultraheavyriotcannon | A | LMB |
| Legion | Sol Invictus | legeheatraymech | 5 | Ultra Heavy Riot Autocannon | Cannon | Air+Ground | 550 | 1.2 s | 420 | legeheatraymech_ultraheavyriotcannon | A | LMB |
| Legion | Sol Invictus | legeheatraymech | 6 | Anti-Air Flak Cannon | Cannon | Air | 700 | 1.8 s | 190 (air) | legeheatraymech_legflak_gun | C | MMB |
| Legion | Sol Invictus | legeheatraymech | 7 | Footsteps | Cannon | - | 0 | 1.5 s | 0 | legeheatraymech_bigfootstep | - | - |
| Legion | Soteria | legdeflector | 1 | PlasmaRepulsor | Shield | - | 10 | 1.0 s | 0 | legdeflector_repulsor | - | - |
| Legion | Sphyrna | leganavyheavysub | 1 | Long-Range Heavy Torpedo | Torpedo | All | 850 | 8.0 s | 1650 | leganavyheavysub_torpedo_large | A | LMB |
| Legion | Starfall | legstarfall | 1 | Very Long-Range High-Trajectory 63-Salvo Plasma Launcher | Plasma | Air+Ground | 6100 | 14.0 s | 600 | legstarfall_starfire | A | LMB |
| Legion | Starfall | legstarfall | 2 | Plasma Volley Energy Charger (supplies energy to Starfall cannon) | Plasma | - | 1 | 1.0 s | 0 | legstarfall_energycharger | - | - |
| Legion | Stheno | legtl | 1 | Torpedo Launcher | Torpedo | All | 500 | 1.5 s | 280 | legtl_torpedo | A | LMB |
| Legion | Stronghold | legstronghold | 1 | Medium Shotgun | Laser | Air+Ground | 450 | 1.6 s | 30 | legstronghold_shotgun | A | LMB |
| Legion | Supernova | legsilo | 1 | Intercontinental Thermonuclear Ballistic Missile | Starburst missile | Air+Ground | 72000 | 30.0 s | 15000 | legsilo_legicbm | A | LMB |
| Legion | Supernova | legsilo | 2 | Nuclear Launch | Cannon | - | 0 | 30.0 s | 0 | legsilo_nuclear_launch | - | - |
| Legion | Syracusia | legnavydestro | 1 | Medium Sweepfire Heatray | Beam laser | Air+Ground | 700 | 2.4 s | 410 | legnavydestro_leg_medium_heatray | A | LMB |
| Legion | Syracusia | legnavydestro | 2 | Dual Ballistics Drone Control Matrix | Cannon | - | 700 | 2.5 s | 0 | legnavydestro_drone_control_matrix | - | - |
| Legion | Tactical Defense Commander | legcomt2def | 1 | RiotCannon | Cannon | Air+Ground | 315 | 1.8 s | 190 | legcomt2def_corlevlr_weapon | B | RMB |
| Legion | Tactical Defense Commander | legcomt2def | 2 | Level1TorpedoLauncher | Torpedo | All | 400 | 1.5 s | 250 | legcomt2def_torpedo | C | MMB |
| Legion | Tactical Defense Commander | legcomt2def | 3 | EMP Grenade | EMP cannon | Air+Ground | 300 | 8.0 s | 10000 | legcomt2def_empgrenade | A | LMB |
| Legion | Tactical Defense Commander | legcomt2def | 4 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 450 | 0.8 s | 150 (air) | legcomt2def_ferret_missile | D | MMB |
| Legion | Tactical Defense Commander | legcomt2def | 5 | PlasmaRepulsor | Shield | - | 150 | 1.0 s | 0 | legcomt2def_repulsor | - | - |
| Legion | Tactical Offense Commander | legcomt2off | 1 | Rapid-fire a2g machine guns | Laser | Air+Ground | 400 | 0.4 s | 26 | legcomt2off_armmg_weapon | B | RMB |
| Legion | Tactical Offense Commander | legcomt2off | 2 | Level1TorpedoLauncher | Torpedo | All | 400 | 1.5 s | 250 | legcomt2off_torpedo | C | MMB |
| Legion | Tactical Offense Commander | legcomt2off | 3 | EMP Grenade | EMP cannon | Air+Ground | 300 | 8.0 s | 10000 | legcomt2off_disintegrator | A | LMB |
| Legion | Tactical Offense Commander | legcomt2off | 4 | Pop-up rapid-fire g2a missile launcher | Missile | Air | 450 | 0.8 s | 150 (air) | legcomt2off_ferret_missile | D | MMB |
| Legion | Telchine | legamph | 1 | Heavy g2g Cleansing Heat Ray | Beam laser | Air+Ground | 450 | 0.0 s | 33 | legamph_heat_ray | A | LMB |
| Legion | Telchine | legamph | 2 | Depthcharge launcher | Torpedo | All | 600 | 3.0 s | 350 | legamph_coax_depthcharge | B | RMB |
| Legion | Thalassa | leganavycruiser | 1 | Twin Rapid-fire Machine Guns | Laser | Air+Ground | 500 | 0.4 s | 24 | leganavycruiser_mg_guns | A | LMB |
| Legion | Thalassa | leganavycruiser | 2 | Medium depthcharge launcher | Torpedo | All | 450 | 1.8 s | 225 | leganavycruiser_advdepthcharge | B | RMB |
| Legion | Thanatos | leghrk | 1 | CatapultRockets | Missile | Air+Ground | 1200 | 8.0 s | 150 | leghrk_rocket_barrage | A | LMB |
| Legion | Toxotai | legaabot | 1 | Advanced g2a Salvo Missile Launcher | Missile | Air | 760 | 2.0 s | 37 (air) | legaabot_light_antiair_missile | A | LMB |
| Legion | Triton | legfloat | 1 | Medium g2g gauss cannon | Cannon | Air+Ground | 550 | 2.5 s | 250 | legfloat_legfloat_gauss | B | RMB |
| Legion | Triton | legfloat | 2 | Rapid-fire machine gun | Laser | Air+Ground | 400 | 0.4 s | 7 | legfloat_legfloat_gatling | A | LMB |
| Legion | Tyrannus | legfort | 1 | PlasmaCannon | Plasma | Air+Ground | 915 | 1.7 s | 166 | legfort_plasma | B | RMB |
| Legion | Tyrannus | legfort | 2 | PlasmaCannon | Plasma | Air+Ground | 915 | 1.7 s | 166 | legfort_plasma | B | RMB |
| Legion | Tyrannus | legfort | 3 | Burst-fire Machine Gun | Laser | Air+Ground | 650 | 0.9 s | 36 | legfort_semiauto | A | LMB |
| Legion | Tyrannus | legfort | 4 | Burst-fire Machine Gun | Laser | Air+Ground | 650 | 0.9 s | 36 | legfort_semiauto | A | LMB |
| Legion | Tyrannus | legfort | 5 | Burst-fire Machine Gun | Laser | Air+Ground | 650 | 0.9 s | 36 | legfort_semiauto | A | LMB |
| Legion | Tyrannus | legfort | 6 | Advanced d2a rapid missile launcher | Starburst missile | Air | 840 | 0.8 s | 76 (air) | legfort_aa_missiles | C | MMB |
| Legion | Ultor | leganavymissileship | 1 | Heavy Long-Range Vertical Salvo Rocket Launcher | Cannon | Air+Ground | 1550 | 9.0 s | 450 | leganavymissileship_leg_salvo_vertical_rocket | A | LMB |
| Legion | Ultor | leganavymissileship | 2 | Salvo Anti-Air Missile Launcher | Missile | Air | 760 | 2.0 s | 20 (air) | leganavymissileship_leg_light_aa_missile | B | RMB |
| Legion | Venator | legvenator | 1 | Birdshot Cannon | Cannon | Air+Ground | 700 | 2.5 s | 24 | legvenator_birdshot | A | LMB |
| Legion | Wheelie | legscout | 1 | Burst-fire Machine Gun | Laser | Ground | 169 | 1.4 s | 11 | legscout_gun | A | LMB |
| Legion | Wildfire | legnap | 1 | Heavy a2g napalm warheads | Bomb | Air+Ground | 1280 | 10.0 s | 50 | legnap_napalmbombs | A | LMB |
| Legion | Xyston | leglraa | 1 | Heavy Anti-Air Railgun | Laser | Air | 2000 | 5.0 s | 700 (air) | leglraa_railgunt2 | A | LMB |
