# Renegade: weapon categories for the pictures of the panel

[Renegade](renegade.md) · [Weapon table](renegade-weapons.md) · [Start page](../../README.md)

898 weapons on a mouse button, 819 different weapon definitions, grouped into **38 categories** (a picture each, 32 drawn so far). Made by `test-data/tools/weapon_categories.py` from `renegade_weapons.csv`; `renegade_weapon_categories.csv` has every weapon with its category (sorted by category and strength) and the picture; the pictures are drawn by `weapon_art.py` and `weapon_art2.py` (folder `weapon-images`).

## How a weapon gets its category

1. **Family** from the type and the description of the weapon: laser, plasma, cannon, missile, machine gun, torpedo, bomb, flak, d-gun ... and so on (the table below). The heat rays (description with "heat ray") are the family heatray (yellow).
2. **Size** (light, medium, heavy, ultra) only for the families laser, plasma, cannon, missile and machine-gun (all other families have one picture):
   - the base size comes from the **tech level of the unit** that carries the weapon: T1 light, T2 medium, T3 and T4 heavy (`renegade_unit_tech.csv`; a unit that is not in it counts as T2);
   - the damage per second (DPS: damage of one shot / reload) moves it: up to *Weak up to* one size down (a weak weapon), up to *Normal up to* it stays, up to *Strong up to* one size up (a strong weapon); never beyond heavy;
   - a weapon above *Strong up to* is **ultra** whatever the unit is. For the lasers also the tachyon and ion beams and every weapon with the word "ultra" in its description are ultra (laser-ultra: blue, very thick).
3. The limits are in `renegade_weapon_limits.csv` (change them in Excel, then run `update_renegade_weapons.bat`... or `python test-data/tools/weapon_categories.py`):

| Family | Weak up to | Normal up to | Strong up to | Ultra above |
|---|---|---|---|---|
| laser | 100 | 600 | 1500 | above 1500 |
| plasma | 60 | 400 | 1500 | above 1500 |
| cannon | 60 | 250 | 550 | above 550 |
| missile | 40 | 150 | 800 | above 800 |
| machine-gun | 20 | 80 |  | none |

(damage per second: a weapon with up to 100 DPS is weak, up to 600 normal, up to 1500 strong (laser example), above that ultra; an empty *Strong up to* means: no ultra size by damage)

## The categories

| Category | Picture | Weapons | Units | Examples |
|---|---|---|---|---|
| aa-missile |  | 14 | 12 | Legion Commander: Anti-Air Missile Launcher; Legion Commander Level 2: Anti-Air Missile Launcher; Legion Commander Level 3: Anti-Air Missile Launcher |
| artillery | <img src="weapon-images/weapon_artillery.png" width="384"> | 8 | 5 | Corinth: Heavy Artillery Cluster Plasma Cannon; Octeres: Long-Range Naval Cluster Artillery Cannon; Tremor: RapidArtillery |
| bomb |  | 11 | 11 | Blizzard: Heavy a2g impulse warheads; Epic Stormbringer: Ultra Heavy Bombs; Stiletto: Heavy a2g EMP warheads |
| cannon-light | <img src="weapon-images/weapon_cannon-light.png" width="384"> | 24 | 24 | Cortex Commander Level 4: HeavyCannon; Cortex Commander Level 5: HeavyCannon; Cortex Commander Level 6: HeavyCannon |
| cannon-medium | <img src="weapon-images/weapon_cannon-medium.png" width="384"> | 17 | 15 | Despot: BattleshipCannon; Cortex Commander Level 7: HeavyCannon; Cortex Commander Level 8: HeavyCannon |
| cannon-heavy | <img src="weapon-images/weapon_cannon-heavy.png" width="384"> | 7 | 6 | Sol Invictus: Ultra Heavy Riot Autocannon; Lunkhead: Heavy ballistic underwater cannon; Flying Black Hydra: BattleshipCannon |
| cannon-ultra | <img src="weapon-images/weapon_cannon-ultra.png" width="384"> | 3 | 3 | Cortex Commander Level 10: HeavyCannon; Perdition: Long-Range Tactical Hellfire Napalm Shell |
| d-gun | <img src="weapon-images/weapon_d-gun.png" width="384"> | 68 | 68 | Armada Commander: Disintegrator; Armada Commander Level 10: Disintegrator; Armada Commander Level 2: Disintegrator |
| depth-charge |  | 17 | 16 | Depth Charge Drone: Depthcharge launcher; Epic Skater: Depthcharge launcher; Anemone: Depthcharge launcher |
| emp-grenade | <img src="weapon-images/weapon_emp-grenade.png" width="384"> | 6 | 6 | Shockwave: Medium EMP turret; Combat Commander: EMP Grenade; Economy Commander: EMP Grenade |
| flak | <img src="weapon-images/weapon_flak.png" width="384"> | 22 | 20 | Black Prince: Anti-Air Flak Cannons; Apollyon: Dual Rotary Microflak Cannons; Arbalest: Heavy g2a flak cannon |
| flamethrower |  | 22 | 22 | Cortex Commander Level 10: Long range AoE flamethrower; Cortex Commander Level 5: Anti-swarm AoE flamethrower; Cortex Commander Level 6: Anti-swarm AoE flamethrower |
| gauss | <img src="weapon-images/weapon_gauss.png" width="384"> | 14 | 14 | Cauteriser: Dual Medium Plasma Gauss Cannons; Gorgon: Rapid-fire gauss cannon; Gremlin: Light close-quarters gauss cannon |
| heatray | <img src="weapon-images/weapon_heatray.png" width="384"> | 27 | 26 | Adjudicator: Ultra Heavy Juggernaut-Spec Heatray; Attack Drone: HeatRay; Legion Commander: Close-Quarters Heatray |
| heavy-rocket | <img src="weapon-images/weapon_heavy-rocket.png" width="384"> | 36 | 36 | Armada Commander Level 10: HeavyRockets; Armada Commander Level 3: HeavyRockets; Armada Commander Level 4: HeavyRockets |
| laser-light | <img src="weapon-images/weapon_laser-light.png" width="384"> | 66 | 55 | Armada Commander: Light close-quarters g2g/g2a laser; Armada Commander: Light underwater-combat laser; Armada Commander Level 2: Scatter Beamer |
| laser-medium | <img src="weapon-images/weapon_laser-medium.png" width="384"> | 51 | 35 | Dragon: HighEnergyLaser; Quad Guard: Close-quarters light g2g laser; Black Hydra: HighEnergyLaser |
| laser-heavy | <img src="weapon-images/weapon_laser-heavy.png" width="384"> | 25 | 13 | Archaic Sol Invictus: Experimental Thermal Ordnance Generators; Behemoth: LightLaser; Flying Black Hydra: HighEnergyLaser |
| laser-ultra | <img src="weapon-images/weapon_laser-ultra.png" width="384"> | 40 | 35 | Epic Dragon: Ultra HighEnergyLaser; Armada Commander Level 10: UWSupernovaBeam; Armada Commander Level 5: UltravioletRayBeam |
| lightning | <img src="weapon-images/weapon_lightning.png" width="384"> | 19 | 19 | Armada Commander Level 10: Short-Range Lightning Discharge; Armada Commander Level 5: Short-Range Lightning Discharge; Armada Commander Level 6: Short-Range Lightning Discharge |
| machine-gun-light | <img src="weapon-images/weapon_machine-gun-light.png" width="384"> | 16 | 16 | Legion Commander Level 2: Rapid-Fire Machine Gun; Legion Commander Level 3: Rapid-Fire Machine Gun; Attack Drone: Rapid-fire a2g machine guns |
| machine-gun-medium | <img src="weapon-images/weapon_machine-gun-medium.png" width="384"> | 15 | 12 | Tyrannus: Burst-fire Machine Gun; Chimera: Dual Rotary Machine Guns; Legion Commander Level 4: Rapid-Fire Machine Gun |
| machine-gun-heavy | <img src="weapon-images/weapon_machine-gun-heavy.png" width="384"> | 12 | 4 | Apollyon: Heavy rotary cannon; Keres: Heavy rotary cannon; Mukade: Rapid-fire a2g machine guns |
| missile-light | <img src="weapon-images/weapon_missile-light.png" width="384"> | 37 | 32 | Bat: Guided a2a missile launcher; Cyclone: Guided a2a missile launcher; Janus: Heavy g2g dual-missile launcher |
| missile-medium | <img src="weapon-images/weapon_missile-medium.png" width="384"> | 17 | 17 | Dragonslayer: Long-range g2a guided missile launcher; Hornet: Heavy a2g armor-piercing sabot missile launcher; Jaguar: Light g2a missile launcher |
| missile-heavy | <img src="weapon-images/weapon_missile-heavy.png" width="384"> | 15 | 12 | Vesuvius: Banisher; Apollyon: CatapultRockets; Marauder: Guided g2a missile launcher |
| missile-ultra | <img src="weapon-images/weapon_missile-ultra.png" width="384"> | 1 | 1 | Epic Karganeth: KarganethMissiles |
| nuclear |  | 8 | 8 | Armageddon: Intercontinental ballistic nuclear warhead; Epic Liche: Intercontinental ballistic nuclear warhead; Liche: Tactical nuclear homing missile |
| plasma-light | <img src="weapon-images/weapon_plasma-light.png" width="384"> | 34 | 29 | Dolphin: Rapid-fire close-quarters plasma turret; Ellysaw: Light long-range plasma cannon; Gauntlet: Heavy g2g long range plasma cannon |
| plasma-medium | <img src="weapon-images/weapon_plasma-medium.png" width="384"> | 42 | 28 | Epoch: Secondary rapid-fire heavy plasma cannon; Black Prince: Long-Range Plasma Bombardment Cannons; Cerberus: Heavy g2g barrage plasma battery |
| plasma-heavy | <img src="weapon-images/weapon_plasma-heavy.png" width="384"> | 24 | 13 | Flying Epoch: Secondary rapid-fire heavy plasma cannon; Epic Tyrannus: scav rapid fire plasma gun; Epic Dolphin: Mini Rapid-fire long-range plasma cannon |
| plasma-ultra | <img src="weapon-images/weapon_plasma-ultra.png" width="384"> | 8 | 8 | Legion Commander Level 10: Rapid-Fire Plasma Cannon; Legion Commander Level 8: Rapid-Fire Plasma Cannon; Ragnarok: Rapid-fire long-range plasma cannon |
| railgun |  | 32 | 25 | Neptune: Dual Naval-Series Rail Accelerators; Daedalus: Siege Rail Accelerator; Lance: Railgun |
| rocket-salvo | <img src="weapon-images/weapon_rocket-salvo.png" width="384"> | 34 | 27 | Epoch: Pop-up rapid-fire g2a missile launcher; Flying Epoch: Pop-up rapid-fire g2a missile launcher; Black Hydra: Pop-up rapid-fire g2a missile launcher |
| self-destruct | <img src="weapon-images/weapon_self-destruct.png" width="384"> | 5 | 3 | Epic Tumbleweed: Crawlingbomb Dummy Weapon; Epic Tumbleweed: Self-destruction; Tumbleweed: Self-destruction |
| shotgun | <img src="weapon-images/weapon_shotgun.png" width="384"> | 8 | 7 | Scylla: Medium Shotgun; Alaris: Dual-Feed Medium Shotgun; Cardea: Medium Shotgun |
| stun-beam | <img src="weapon-images/weapon_stun-beam.png" width="384"> | 33 | 17 | Armada Commander Level 10: Arcing Stun Beam; Armada Commander Level 10: EMP Damage-Mitigating Flashbang; Armada Commander Level 3: Arcing Stun Beam |
| torpedo | <img src="weapon-images/weapon_torpedo.png" width="384"> | 60 | 53 | Epic Serpent: Heavy guided torpedo launcher; Serpent: Heavy guided torpedo launcher; Aesacus: Medium Homing Torpedo Launcher |
