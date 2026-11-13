# Test widgets (`tools/zz_*.lua`)

Made by `generators/make_test_index.py` from the first lines of every widget: change the widget, not this file. How to run them: [README](README.md), pitfalls: [TESTING](TESTING.md).

139 widgets. The name of the log lines is in the widget (`[zz...]`); the game starts with the command in the last column.

| Widget | What it checks | Started with |
|---|---|---|
| `zz_aitake.lua` | does the computer player take radars? | `pve_test.ps1 -Evo -Widget zz_aitake.lua (one instance)` |
| `zz_alt.lua` | cruise altitude of all aircraft definitions, lines [zzalt] | `pve_test.ps1 (a normal game)` |
| `zz_area_shot.lua` | the picture of the area attack (XR) for the README | `arena_test.ps1 -Widget zz_area_shot.lua` |
| `zz_arena.lua` | plays through the Arena page | `arena_test.ps1` |
| `zz_arena_fight.lua` | what the armies shoot at after the area attack | `arena_test.ps1 -Widget zz_arena_fight.lua` |
| `zz_arena_shots.lua` | sets up the Arena pictures of the README | `arena_test.ps1 -Shots` |
| `zz_bld.lua` | Evolution buildings change to T2 and back | `pve_test.ps1 -Evo -EvoStage 6 -EvoTest -Debug -Widget zz_bld.lua (one instance, speed 10)` |
| `zz_bpfaction.lua` | BluePrinter turns a blueprint into the faction of the builders | `bp_test.ps1 -Widget zz_bpfaction.lua (player and commander of Cortex)` |
| `zz_bpg.lua` | ghosts after undo |  |
| `zz_bpo.lua` | plans on plans and buildings |  |
| `zz_bpt.lua` | BluePrinter plan tests |  |
| `zz_brood.lua` | a raptor healer builds a Raptor Brood Chamber, the chamber grows raptors | `pve_test.ps1 -Brood -Widget zz_brood.lua` |
| `zz_cam.lua` | which camera states take a direction | `pve_test.ps1 -Ren -Widget zz_cam.lua` |
| `zz_cloak.lua` | does the Cloak ability work on the own unit? | `pve_test.ps1 -Evo -EvoTest -Widget zz_cloak.lua (one instance)` |
| `zz_cmdbuttons.lua` | the buttons Area / Split / Focus Attack in the command menu | `arena_test.ps1 -Widget zz_cmdbuttons.lua` |
| `zz_copy.lua` | copy / paste (Ctrl+C / Ctrl+V), button W, save and load of a level | `arena_test.ps1 -Widget zz_copy.lua` |
| `zz_cycle.lua` | Ctrl + mouse wheel chooses the blueprint (grid:cycle) | `arena_test.ps1 -Widget zz_cycle.lua` |
| `zz_docshot.lua` | pictures of Evolution for the manual | `pve_test.ps1 -Evo -EvoTest -Shot <mode> -Widget zz_docshot.lua (one instance, -Bots n computer players)` |
| `zz_dpsdump.lua` | test only |  |
| `zz_evo2.lua` | Evolution energy, wild units, towers, radars | `lan_test.ps1 -Mode evo -Solo (one instance` |
| `zz_evo_all.lua` | several Evolution rules in one game | `pve_test.ps1 -Evo -EvoTest -Debug -Bots 1 -Widget zz_evo_all.lua (one instance, speed 10, ends at frame 4200). One game, several checks, lines "[zzall]"` |
| `zz_evocam.lua` | the camera at the start of Evolution | `pve_test.ps1 -Evo -Widget zz_evocam.lua` |
| `zz_evoshot.lua` | a picture of the Evolution panels | `pve_test.ps1 -Evo -Widget zz_evoshot.lua` |
| `zz_export.lua` | the export buttons of the settings page (O) | `arena_test.ps1 -Widget zz_export.lua` |
| `zz_features.lua` | moves a feature (tree) and undoes it | `arena_test.ps1 -Widget zz_features.lua` |
| `zz_gates.lua` | Gates of Hell and the debug buttons | `pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_gates.lua (one instance, speed 10)` |
| `zz_hell.lua` | Hell on Earth and Heaven on Earth | `pve_test.ps1 -Evo -EvoTest -Debug [-Gift 1\|2] -Widget zz_hell.lua (one instance, speed 10)` |
| `zz_keep.lua` | settings changed while the Arena runs stay after Stop | `arena_test.ps1 -Widget zz_keep.lua` |
| `zz_lantest.lua` | test only |  |
| `zz_live.lua` | runs the commands of live.ps1 (file LuaUI/Config/live_cmd.txt in the data folder) in the running test game | `pve_test.ps1 -Live. Once a second it reads LuaUI/Config/live_cmd.txt of the write folder. The first line is an id; a command is run once per id (the engine setting zzliveLast keeps it over a "luaui reload", which loads the widgets again and forgets WG). The other lines` |
| `zz_long.lua` | Evolution option Long range | `pve_test.ps1 -Evo -Debug [-Long] -Widget zz_long.lua (one instance, speed 10)` |
| `zz_mem.lua` | how much Lua memory per second the Level Editor allocates | `arena_test.ps1 -Widget zz_mem.lua` |
| `zz_mem_big.lua` | how much Lua memory per second the Level Editor allocates | `arena_test.ps1 -Widget zz_mem_big.lua (zz_mem.lua with the level demo_td_serpentine, 2460 units, loaded)` |
| `zz_mem_calls.lua` | Lua memory allocated by every call-in of the Level Editor | `arena_test.ps1 -Widget zz_mem_calls.lua` |
| `zz_menu.lua` | menu switching |  |
| `zz_mix.lua` | Raptors vs Scavengers |  |
| `zz_modes.lua` | Tower Defense, Capture the Flag and Reclaim the Fame with the alliances of page T | `arena_test.ps1 -Widget zz_modes.lua` |
| `zz_nocloak.lua` | a unit that can cloak does not cloak by itself in Evolution | `pve_test.ps1 -Evo -EvoTest -Widget zz_nocloak.lua (one instance, speed 10)` |
| `zz_place.lua` | window position, start position, ready | `lan_test.ps1 -Mode pve. (The window is placed by the Chobby settings that lan_test.ps1 writes` |
| `zz_pve.lua` | orders to the units of a Scavengers / Raptors AI team | `pve_test.ps1` |
| `zz_ren3.lua` | Renegade proof of concept 3 and 4 | `pve_test.ps1 -Ren -RenTest -Widget zz_ren3.lua` |
| `zz_ren4.lua` | Renegade shots anywhere | `pve_test.ps1 -Ren -Widget zz_ren4.lua` |
| `zz_ren5.lua` | Renegade bots, debug unit menu, respawn | `pve_test.ps1 -Ren -RenTest -RenBots 3 -Widget zz_ren5.lua` |
| `zz_ren6.lua` | Renegade shot latency, two buttons, turret, menu, energy | `pve_test.ps1 -Ren -RenTest -Widget zz_ren6.lua` |
| `zz_ren7.lua` | Renegade search field and a ship on land | `pve_test.ps1 -Ren -RenTest -Widget zz_ren7.lua` |
| `zz_ren8.lua` | Renegade three buttons and weapon groups | `pve_test.ps1 -Ren -RenTest -Widget zz_ren8.lua` |
| `zz_ren9.lua` | Renegade respawn with countdown, barrel lines | `pve_test.ps1 -Ren -RenTest -Widget zz_ren9.lua` |
| `zz_ren10.lua` | Renegade anti-air circle and lock | `pve_test.ps1 -Ren -RenTest -Widget zz_ren10.lua` |
| `zz_ren11.lua` | Renegade ground and air missile (Titan starburst, middle button): lock at aircraft, aim at the ground | `pve_test.ps1 -Ren -RenTest -Widget zz_ren11.lua` |
| `zz_ren12.lua` | Renegade spawn enemy button | `pve_test.ps1 -Ren -RenTest -Widget zz_ren12.lua` |
| `zz_ren13.lua` | Renegade ground and air missile (Titan laser, right button): lock at aircraft, aim at the ground | `pve_test.ps1 -Ren -RenTest -Widget zz_ren13.lua` |
| `zz_ren14.lua` | Renegade one click = one shot | `pve_test.ps1 -Ren -RenTest -Widget zz_ren14.lua` |
| `zz_ren15.lua` | Renegade the turret follows the view without firing, facing arrow | `pve_test.ps1 -Ren -RenTest -Widget zz_ren15.lua` |
| `zz_ren16.lua` | Renegade commander: laser left, Disintegrator (D-gun) right | `pve_test.ps1 -Ren -RenTest -Widget zz_ren16.lua` |
| `zz_ren17.lua` | Renegade Calamity: continuous fire | `pve_test.ps1 -Ren -RenTest -Widget zz_ren17.lua` |
| `zz_ren18.lua` | Renegade bomber: the bombs fall at once | `pve_test.ps1 -Ren -RenTest -Widget zz_ren18.lua` |
| `zz_ren19.lua` | Renegade gunship fires at a ground unit | `pve_test.ps1 -Ren -RenTest -Widget zz_ren19.lua` |
| `zz_ren20.lua` | Renegade gunship: how steep can it fire down | `pve_test.ps1 -Ren -RenTest -Widget zz_ren20.lua` |
| `zz_ren21.lua` | Renegade gunship: height with Space / Ctrl | `pve_test.ps1 -Ren -RenTest -Widget zz_ren21.lua` |
| `zz_ren23.lua` | how a gunship attacks in the normal game | `pve_test.ps1 -Ren -RenTest -Widget zz_ren23.lua` |
| `zz_ren26.lua` | Renegade gunship flying backward | `pve_test.ps1 -Ren -RenTest -Widget zz_ren26.lua` |
| `zz_ren27.lua` | Renegade aircraft takes off once and never lands by itself | `pve_test.ps1 -Ren -RenTest -Widget zz_ren27.lua` |
| `zz_ren28.lua` | Renegade aircraft lands when the lower key is held at the bottom | `pve_test.ps1 -Ren -RenTest -Widget zz_ren28.lua` |
| `zz_ren29.lua` | what height does a gunship fly at with a plain move order (no Renegade height control) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren29.lua` |
| `zz_ren30.lua` | height of a gunship that flies in the normal game, with the height fields of its definition | `pve_test.ps1 -Ren -RenTest -Widget zz_ren30.lua` |
| `zz_ren31.lua` | height of fixed-wing aircraft in the normal game against their cruise altitude | `pve_test.ps1 -Ren -RenTest -Widget zz_ren31.lua` |
| `zz_ren33.lua` | crosshair and weapon rows colour by range | `pve_test.ps1 -Ren -RenTest -Widget zz_ren33.lua` |
| `zz_ren34.lua` | Renegade bomber keeps its height above the ground on slopes | `pve_test.ps1 -Ren -RenTest -Widget zz_ren34.lua` |
| `zz_ren35.lua` | Renegade bomber with Space held never gets over its highest height | `pve_test.ps1 -Ren -RenTest -Widget zz_ren34.lua` |
| `zz_ren36.lua` | Renegade bomber drops bombs at which heights | `pve_test.ps1 -Ren -RenTest -Widget zz_ren36.lua` |
| `zz_ren37.lua` | Renegade bomber, one short click | `pve_test.ps1 -Ren -RenTest -Widget zz_ren37.lua` |
| `zz_ren38.lua` | Renegade bomber, one short click at 400 above the ground (the gadget drops the bombs itself) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren37.lua` |
| `zz_ren39.lua` | at what height does the engine's own bomb release fire, for every bomber | `pve_test.ps1 -Ren -RenTest -Widget zz_ren39.lua` |
| `zz_ren40.lua` | our own bomb release for every bomber | `pve_test.ps1 -Ren -RenTest -Widget zz_ren39.lua` |
| `zz_ren41.lua` | a bomber drops only up to its attack altitude | `pve_test.ps1 -Ren -RenTest -Widget zz_ren41.lua` |
| `zz_ren42.lua` | pictures of a shot of the Juggernaut in first person | `pve_test.ps1 -Ren -RenTest -Widget zz_ren42.lua` |
| `zz_ren43.lua` | picture of a weapon in the panel | `pve_test.ps1 -Ren -RenTest -Widget zz_ren43.lua` |
| `zz_ren44.lua` | weapon pictures of the Pulsar and the Juggernaut | `pve_test.ps1 -Ren -RenTest -Widget zz_ren44.lua` |
| `zz_ren45.lua` | weapon pictures of plasma, cannon, missile, starburst, salvo and torpedo units | `pve_test.ps1 -Ren -RenTest -Widget zz_ren45.lua` |
| `zz_ren46.lua` | the AUTO row of the anti-nuke launchers | `pve_test.ps1 -Ren -RenTest -Widget zz_ren46.lua` |
| `zz_ren47.lua` | the new panel (Juggernaut, Prevailer, a bomber) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren47.lua` |
| `zz_ren48.lua` | the wider panel, the pointers and the list of the players | `pve_test.ps1 -Ren -RenTest -Widget zz_ren47.lua` |
| `zz_ren49.lua` | firing cone (mainDir, maxAngleDif) of the weapons | `pve_test.ps1 -Ren -RenTest -Widget zz_ren49.lua` |
| `zz_ren50.lua` | the turret angle of the Mauser (armmart) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren50.lua` |
| `zz_ren51.lua` | which weapons shoot in an arc | `pve_test.ps1 -Ren -RenTest -Widget zz_ren51.lua` |
| `zz_ren52.lua` | the Mauser fires at the sky (arc weapons) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren52.lua` |
| `zz_ren53.lua` | anti-air lock still works with the shot-down check; aircraftState of the aircraft | `pve_test.ps1 -Ren -RenTest -Widget zz_ren53.lua` |
| `zz_ren54.lua` | which Spring functions know about crashing aircraft | `pve_test.ps1 -Ren -RenTest -Widget zz_ren54.lua` |
| `zz_ren55.lua` | the third person camera (Shift) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren55.lua` |
| `zz_ren56.lua` | the groups and the weapons of the Karganeth (corkarg) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren56.lua` |
| `zz_ren57.lua` | the shoulder rockets of the Karganeth (right button, air only) lock on an aircraft | `pve_test.ps1 -Ren -RenTest -Widget zz_ren57.lua` |
| `zz_ren58.lua` | air-only weapons and the flight of the missiles | `pve_test.ps1 -Ren -RenTest -Widget zz_ren58.lua` |
| `zz_ren59.lua` | direct and indirect missiles | `pve_test.ps1 -Ren -RenTest -Widget zz_ren59.lua` |
| `zz_ren60.lua` | which missiles count as arc weapons (R.lobbed) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren60.lua` |
| `zz_ren61.lua` | all turrets follow the view (the D-gun too) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren61.lua` |
| `zz_ren62.lua` | a weapon fires only when it is loaded and the button is down | `pve_test.ps1 -Ren -RenTest -Widget zz_ren62.lua` |
| `zz_ren63.lua` | switch between Renegade and the normal game | `pve_test.ps1 -Ren -RenTest -Widget zz_ren63.lua` |
| `zz_ren64.lua` | the Exploiters (extractors with weapons) fire | `pve_test.ps1 -Ren -RenTest -Widget zz_ren64.lua` |
| `zz_ren65.lua` | energy and metal cost of the shots of the Exploiters and the resources of the teams | `pve_test.ps1 -Ren -RenTest -Widget zz_ren65.lua` |
| `zz_ren67.lua` | the Rattlesnake (armamb) and its trajectory state | `pve_test.ps1 -Ren -RenTest -Widget zz_ren67.lua` |
| `zz_ren68.lua` | the firing cones of the Exploiters | `pve_test.ps1 -Ren -RenTest -Widget zz_ren68.lua` |
| `zz_ren69.lua` | an Exploiter fires at an enemy unit | `pve_test.ps1 -Ren -RenTest -Widget zz_ren69.lua` |
| `zz_ren70.lua` | a spider walks backwards (S) without turning round | `pve_test.ps1 -Ren -RenTest -Widget zz_ren70.lua` |
| `zz_ren71.lua` | the binoculars and the speedometer | `pve_test.ps1 -Ren -RenTest -Widget zz_ren71.lua` |
| `zz_ren72.lua` | the information line of the unit menu | `pve_test.ps1 -Ren -RenTest -Widget zz_ren72.lua` |
| `zz_ren73.lua` | Renegade Flying Black Hydra on slopes | `pve_test.ps1 -Ren -RenTest -Widget zz_ren73.lua` |
| `zz_ren74.lua` | Renegade bomber ceiling and the bomb sight colour | `pve_test.ps1 -Ren -RenTest -Widget zz_ren74.lua` |
| `zz_ren75.lua` | Renegade laser aimed through the enemy at the point behind it | `pve_test.ps1 -Ren -RenTest -Widget zz_ren75.lua` |
| `zz_ren76.lua` | does the Juggernaut (corkorg) move from the start point? | `pve_test.ps1 -Ren -RenTest -Widget zz_ren76.lua` |
| `zz_ren77.lua` | Laser Tiger fires at the ground out of range | `pve_test.ps1 -Ren -RenTest -Widget zz_ren77.lua` |
| `zz_ren78.lua` | Renegade reverse gear | `pve_test.ps1 -Ren -RenTest -Widget zz_ren78.lua` |
| `zz_ren79.lua` | how smooth is the reverse gear | `pve_test.ps1 -Ren -RenTest -Widget zz_ren79.lua (game speed 1)` |
| `zz_ren80.lua` | Renegade take-over mode (the mode key takes over a unit and leaves it) | `pve_test.ps1 -Ren -RenTake -Widget zz_ren80.lua` |
| `zz_ren81.lua` | Renegade take-over mode with Evolution: the player takes over the evolved unit | `pve_test.ps1 -Ren -RenTake -Evo -EvoTest -Widget zz_ren81.lua` |
| `zz_ren82.lua` | the game's unit bars are off in Renegade | `pve_test.ps1 -Ren` |
| `zz_ren83.lua` | layout of the panels, the unit bars widget comes back | `pve_test.ps1 -Ren` |
| `zz_ren84.lua` | a Renegade aircraft with no health left crashes | `pve_test.ps1 -Ren -RenTest -Widget zz_ren84.lua (variants` |
| `zz_ren85.lua` | the distance of the third person camera | `pve_test.ps1 -Ren -RenTest -Widget zz_ren85.lua` |
| `zz_ren86.lua` | reverse from standing starts with a short forward drive | `pve_test.ps1 -Ren -RenTest -Widget zz_ren86.lua` |
| `zz_ren87.lua` | walking within 10 degrees of the view points the body exactly along it | `pve_test.ps1 -Ren -RenTest -Widget zz_ren87.lua` |
| `zz_ren88.lua` | fires at the nearest enemy to see the damage numbers | `pve_test.ps1 -Ren -RenTest -RenBots 3 -Widget zz_ren88.lua` |
| `zz_ren89.lua` | a hurt unit reclaims wrecks and heals (green plus signs and +N) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren89.lua` |
| `zz_ren.lua` | Renegade proof of concept 1 and 2 | `pve_test.ps1 -Ren -Widget zz_ren.lua. Steers renegade.lua through WG.renegade (no real mouse or keys) and logs "[zzren]" lines` |
| `zz_reveal.lua` | a player on level 8 shows on the radar of the others | `pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_reveal.lua (one instance, speed 10)` |
| `zz_save.lua` | works the Save page (button S) | `arena_test.ps1 -Widget zz_save.lua` |
| `zz_scenario.lua` | works the Scenario info page (button I) | `arena_test.ps1 -Widget zz_scenario.lua` |
| `zz_shots_all.lua` | sets up the scenes of the pictures of the README | `arena_test.ps1 -Widget zz_shots_all.lua (with -Map "Full Metal Plate 1.7")` |
| `zz_smart.lua` | units with smart weapon selection (priority / backup trajectory weapons) | `pve_test.ps1 -Widget zz_smart.lua (without -Quick` |
| `zz_spider.lua` | the movement classes of the units (spiders) | `pve_test.ps1 -Widget zz_spider.lua (without -Quick)` |
| `zz_split.lua` | the split attack (XS) on two Arena armies | `arena_test.ps1 -Widget zz_split.lua` |
| `zz_split_ally.lua` | split and focus attack never target own or allied units | `arena_test.ps1 -Widget zz_split_ally.lua` |
| `zz_split_shot.lua` | the picture of the split attack for the README | `arena_test.ps1 -Widget zz_split_shot.lua` |
| `zz_teams.lua` | plays through the teams page T and the alliances | `arena_test.ps1 -Widget zz_teams.lua` |
| `zz_tech.lua` | tech level and metal cost of every armed unit, lines [zztech] | `pve_test.ps1 -Ren -Widget zz_tech.lua` |
| `zz_unitdump.lua` | every mobile Armada, Cortex and Legion unit with its numbers | `pve_test.ps1 -Widget zz_unitdump.lua` |
| `zz_unitinfo.lua` | facts of some unit definitions (movement, building flags) | `pve_test.ps1 -Widget zz_unitinfo.lua (without -Quick` |
| `zz_watch.lua` | wild units that a player sees keep their level | `pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_watch.lua (one instance, speed 10)` |
| `zz_weapondump.lua` | every weapon of every Armada, Cortex and Legion unit | `pve_test.ps1 -Ren -Widget zz_weapondump.lua` |
| `zz_wildhp.lua` | health of the wild (Gaia) units of Evolution | `pve_test.ps1 -Evo -Widget zz_wildhp.lua (one instance, speed 10)` |
