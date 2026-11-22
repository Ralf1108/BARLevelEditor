# Test widgets (`tools/zz_*.lua`, `tools/probes/zz_*.lua`)

Made by `generators/make_test_index.py` from the first lines of every widget: change the widget, not this file. How to run them: [README](README.md), pitfalls: [TESTING](TESTING.md).

165 widgets (29 set, 1 test, 98 check, 11 pictures, 26 probe). The name of the log lines is in the widget (`[zz...]`); the game starts with the command in the last column.

| Kind | Meaning |
|---|---|
| set | a test of the regression set: `tools\run_game_tests.ps1` runs it and gives a verdict |
| test | logs OK / WRONG (or PASS / FAIL) lines: the tool that starts it ends with a verdict and an exit code |
| check | logs values of a behaviour: the log is read (no verdict) |
| pictures | takes the pictures of a manual |
| probe | measured or dumped something once (`tools\probes`): not a test |

| Widget | Kind | What it checks | Started with |
|---|---|---|---|
| `zz_aitake.lua` | probe | does the computer player take radars? | `pve_test.ps1 -Evo -Widget zz_aitake.lua (one instance)` |
| `zz_alt.lua` | probe | cruise altitude of all aircraft definitions, lines [zzalt] | `pve_test.ps1 (a normal game)` |
| `zz_area_shot.lua` | pictures | the picture of the area attack (XR) for the README | `arena_test.ps1 -Widget zz_area_shot.lua` |
| `zz_arena.lua` | set | plays through the Arena page | `arena_test.ps1` |
| `zz_arena_fight.lua` | check | what the armies shoot at after the area attack | `arena_test.ps1 -Widget zz_arena_fight.lua` |
| `zz_arena_shots.lua` | pictures | sets up the Arena pictures of the README | `arena_test.ps1 -Shots` |
| `zz_beacon.lua` | check | Evolution power-up beacons of powerups.lua: a unit drives over one, takes the power-up, the beacon comes back | `pve_test.ps1 -Evo -EvoTest -Widget zz_beacon.lua` |
| `zz_bld.lua` | check | Evolution buildings change to T2 and back | `pve_test.ps1 -Evo -EvoStage 6 -EvoTest -Debug -Widget zz_bld.lua (one instance, speed 10)` |
| `zz_bpfaction.lua` | set | BluePrinter turns a blueprint into the faction of the builders | `bp_test.ps1 -Widget zz_bpfaction.lua (player and commander of Cortex)` |
| `zz_bpg.lua` | check | ghosts after undo | `bp_test.ps1 -Widget zz_bpg.lua` |
| `zz_bpo.lua` | set | plans on plans and buildings | `bp_test.ps1 -Widget zz_bpo.lua` |
| `zz_bpt.lua` | set | BluePrinter plan tests | `bp_test.ps1 -Widget zz_bpt.lua` |
| `zz_brood.lua` | set | a raptor healer builds a Raptor Brood Chamber, the chamber grows raptors | `pve_test.ps1 -Brood -Widget zz_brood.lua` |
| `zz_cam.lua` | probe | which camera states take a direction | `pve_test.ps1 -Ren -Widget zz_cam.lua` |
| `zz_camreset.lua` | set | a game without Renegade starts with the normal camera | `arena_test.ps1 -Widget zz_camreset.lua` |
| `zz_cloak.lua` | check | does the Cloak ability work on the own unit? | `pve_test.ps1 -Evo -EvoTest -Widget zz_cloak.lua (one instance)` |
| `zz_cmdbuttons.lua` | set | the buttons Area / Split / Focus Attack in the command menu | `arena_test.ps1 -Widget zz_cmdbuttons.lua` |
| `zz_copy.lua` | set | copy / paste (Ctrl+C / Ctrl+V), button W, save and load of a level | `arena_test.ps1 -Widget zz_copy.lua` |
| `zz_cycle.lua` | set | Ctrl + mouse wheel chooses the blueprint (grid:cycle) | `arena_test.ps1 -Widget zz_cycle.lua` |
| `zz_docshot.lua` | pictures | pictures of Evolution for the manual | `pve_test.ps1 -Evo -EvoTest -Shot <mode> -Widget zz_docshot.lua (one instance, -Bots n computer players)` |
| `zz_dpsdump.lua` | probe | damage per second and numbers of every armed mobile ground unit | `arena_test.ps1 -Widget zz_dpsdump.lua` |
| `zz_evo2.lua` | test | Evolution energy, wild units, towers, radars | `lan_test.ps1 -Mode evo -Solo (one instance` |
| `zz_evo97.lua` | check | Evolution, choose the unit of the next level | `pve_test.ps1 -Evo -EvoTest -Debug -EvoChoose -Widget zz_evo97.lua` |
| `zz_evo98.lua` | check | Team Evolution (at most one level above the lowest mate) | `pve_test.ps1 -Evo -EvoTest -Debug -EvoTeam -Bots 2 -Widget zz_evo98.lua` |
| `zz_evo_all.lua` | check | several Evolution rules in one game | `pve_test.ps1 -Evo -EvoTest -Debug -Bots 1 -Widget zz_evo_all.lua (one instance, speed 10, ends at frame 4200). One game, several checks, lines "[zzall]"` |
| `zz_evocam.lua` | check | the camera at the start of Evolution | `pve_test.ps1 -Evo -Widget zz_evocam.lua` |
| `zz_evoshot.lua` | pictures | a picture of the Evolution panels | `pve_test.ps1 -Evo -Widget zz_evoshot.lua` |
| `zz_expdemo.lua` | set | the test start of the Experimental Units (lanexpdemo=1) | `arena_test.ps1 -Widget zz_expdemo.lua -ModOptions 'lanexpdemo=1;' (what start_experimental.bat starts)` |
| `zz_export.lua` | set | the export buttons of the settings page (O) | `arena_test.ps1 -Widget zz_export.lua` |
| `zz_expunits.lua` | set | which Experimental Units the game has | `arena_test.ps1 -Widget zz_expunits.lua [-ModOptions 'lanexpunits=0;']` |
| `zz_features.lua` | set | moves a feature (tree) and undoes it | `arena_test.ps1 -Widget zz_features.lua` |
| `zz_gates.lua` | check | Gates of Hell and the debug buttons | `pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_gates.lua (one instance, speed 10)` |
| `zz_hell.lua` | check | Hell on Earth and Heaven on Earth | `pve_test.ps1 -Evo -EvoTest -Debug [-Gift 1\|2] -Widget zz_hell.lua (one instance, speed 10)` |
| `zz_keep.lua` | set | settings changed while the Arena runs stay after Stop | `arena_test.ps1 -Widget zz_keep.lua` |
| `zz_lanevo.lua` | check | Team Evolution over LAN Play | `lan_test.ps1 -Mode evoteam (host PlayerA and joiner PlayerB in one room team, a BARb computer in the other; Evolution and Team Evolution on, game option lanevodebug=1)` |
| `zz_lanrace.lua` | check | Renegade Race over LAN Play | `lan_test.ps1 -Mode race (host PlayerA and joiner PlayerB, Race switched on in the room, game option lanrenotest=1)` |
| `zz_lantest.lua` | check | the game started by a LAN or console lobby test | `lan_test.ps1 (every mode) and console_test.ps1` |
| `zz_lava.lua` | set | Volcano, Lava Extractor and Carrier | `arena_test.ps1 -Widget zz_lava.lua` |
| `zz_lavaauto.lua` | set | vehicles haul on their own only on Maneuver or Roam | `arena_test.ps1 -Widget zz_lavaauto.lua` |
| `zz_lavabelt.lua` | set | the crates on the four belts of a Lava Extractor ride alike to the pads | `arena_test.ps1 -Widget zz_lavabelt.lua` |
| `zz_lavafork.lua` | set | the Forklift of the Lava Extractor | `arena_test.ps1 -Widget zz_lavafork.lua` |
| `zz_lavagen.lua` | set | the model of the Lava Extractor and the blocks on its storage pads | `arena_test.ps1 -Widget zz_lavagen.lua` |
| `zz_lavaroad.lua` | set | the Carriers load at the storage pads outside a Volcano | `arena_test.ps1 -Widget zz_lavaroad.lua` |
| `zz_lavatruck.lua` | set | the Cargo Truck of the Lava Extractor | `arena_test.ps1 -Widget zz_lavatruck.lua` |
| `zz_live.lua` | check | runs the commands of live.ps1 (file LuaUI/Config/live_cmd.txt in the data folder) in the running test game | `pve_test.ps1 -Live. Once a second it reads LuaUI/Config/live_cmd.txt of the write folder. The first line is an id; a command is run once per id (the engine setting zzliveLast keeps it over a "luaui reload", which loads the widgets again and forgets WG). The other lines` |
| `zz_long.lua` | check | Evolution option Long range | `pve_test.ps1 -Evo -Debug [-Long] -Widget zz_long.lua (one instance, speed 10)` |
| `zz_mem.lua` | probe | how much Lua memory per second the Level Editor allocates | `arena_test.ps1 -Widget zz_mem.lua` |
| `zz_mem_big.lua` | probe | how much Lua memory per second the Level Editor allocates | `arena_test.ps1 -Widget zz_mem_big.lua (zz_mem.lua with the level demo_td_serpentine, 2460 units, loaded)` |
| `zz_mem_calls.lua` | probe | Lua memory allocated by every call-in of the Level Editor | `arena_test.ps1 -Widget zz_mem_calls.lua` |
| `zz_menu.lua` | check | menu switching | `arena_test.ps1 -Widget zz_menu.lua` |
| `zz_mix.lua` | check | Raptors vs Scavengers | `lan_test.ps1 -Mode mix (copied to the host)` |
| `zz_modes.lua` | set | Tower Defense, Capture the Flag and Reclaim the Fame with the alliances of page T | `arena_test.ps1 -Widget zz_modes.lua` |
| `zz_nocloak.lua` | check | a unit that can cloak does not cloak by itself in Evolution | `pve_test.ps1 -Evo -EvoTest -Widget zz_nocloak.lua (one instance, speed 10)` |
| `zz_place.lua` | check | window position, start position, ready | `lan_test.ps1 -Mode pve. (The window is placed by the Chobby settings that lan_test.ps1 writes` |
| `zz_pve.lua` | set | orders to the units of a Scavengers / Raptors AI team | `pve_test.ps1` |
| `zz_ren3.lua` | check | Renegade proof of concept 3 and 4 | `pve_test.ps1 -Ren -RenTest -Widget zz_ren3.lua` |
| `zz_ren4.lua` | check | Renegade shots anywhere | `pve_test.ps1 -Ren -Widget zz_ren4.lua` |
| `zz_ren5.lua` | check | Renegade bots, debug unit menu, respawn | `pve_test.ps1 -Ren -RenTest -RenBots 3 -Widget zz_ren5.lua` |
| `zz_ren6.lua` | check | Renegade shot latency, two buttons, turret, menu, energy | `pve_test.ps1 -Ren -RenTest -Widget zz_ren6.lua` |
| `zz_ren7.lua` | check | Renegade search field and a ship on land | `pve_test.ps1 -Ren -RenTest -Widget zz_ren7.lua` |
| `zz_ren8.lua` | check | Renegade three buttons and weapon groups | `pve_test.ps1 -Ren -RenTest -Widget zz_ren8.lua` |
| `zz_ren9.lua` | check | Renegade respawn with countdown, barrel lines | `pve_test.ps1 -Ren -RenTest -Widget zz_ren9.lua` |
| `zz_ren10.lua` | check | Renegade anti-air circle and lock | `pve_test.ps1 -Ren -RenTest -Widget zz_ren10.lua` |
| `zz_ren11.lua` | check | Renegade ground and air missile (Titan starburst, middle button): lock at aircraft, aim at the ground | `pve_test.ps1 -Ren -RenTest -Widget zz_ren11.lua` |
| `zz_ren12.lua` | check | Renegade spawn enemy button | `pve_test.ps1 -Ren -RenTest -Widget zz_ren12.lua` |
| `zz_ren13.lua` | check | Renegade ground and air missile (Titan laser, right button): lock at aircraft, aim at the ground | `pve_test.ps1 -Ren -RenTest -Widget zz_ren13.lua` |
| `zz_ren14.lua` | check | Renegade one click = one shot | `pve_test.ps1 -Ren -RenTest -Widget zz_ren14.lua` |
| `zz_ren15.lua` | check | Renegade the turret follows the view without firing, facing arrow | `pve_test.ps1 -Ren -RenTest -Widget zz_ren15.lua` |
| `zz_ren16.lua` | check | Renegade commander: laser left, Disintegrator (D-gun) right | `pve_test.ps1 -Ren -RenTest -Widget zz_ren16.lua` |
| `zz_ren17.lua` | check | Renegade Calamity: continuous fire | `pve_test.ps1 -Ren -RenTest -Widget zz_ren17.lua` |
| `zz_ren18.lua` | check | Renegade bomber: the bombs fall at once | `pve_test.ps1 -Ren -RenTest -Widget zz_ren18.lua` |
| `zz_ren19.lua` | check | Renegade gunship fires at a ground unit | `pve_test.ps1 -Ren -RenTest -Widget zz_ren19.lua` |
| `zz_ren20.lua` | probe | Renegade gunship: how steep can it fire down | `pve_test.ps1 -Ren -RenTest -Widget zz_ren20.lua` |
| `zz_ren21.lua` | check | Renegade gunship: height with Space / Ctrl | `pve_test.ps1 -Ren -RenTest -Widget zz_ren21.lua` |
| `zz_ren23.lua` | probe | how a gunship attacks in the normal game | `pve_test.ps1 -Ren -RenTest -Widget zz_ren23.lua` |
| `zz_ren26.lua` | check | Renegade gunship flying backward | `pve_test.ps1 -Ren -RenTest -Widget zz_ren26.lua` |
| `zz_ren27.lua` | check | Renegade aircraft takes off once and never lands by itself | `pve_test.ps1 -Ren -RenTest -Widget zz_ren27.lua` |
| `zz_ren28.lua` | check | Renegade aircraft lands when the lower key is held at the bottom | `pve_test.ps1 -Ren -RenTest -Widget zz_ren28.lua` |
| `zz_ren29.lua` | probe | what height does a gunship fly at with a plain move order (no Renegade height control) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren29.lua` |
| `zz_ren30.lua` | probe | height of a gunship that flies in the normal game, with the height fields of its definition | `pve_test.ps1 -Ren -RenTest -Widget zz_ren30.lua` |
| `zz_ren31.lua` | probe | height of fixed-wing aircraft in the normal game against their cruise altitude | `pve_test.ps1 -Ren -RenTest -Widget zz_ren31.lua` |
| `zz_ren33.lua` | check | crosshair and weapon rows colour by range | `pve_test.ps1 -Ren -RenTest -Widget zz_ren33.lua` |
| `zz_ren34.lua` | check | Renegade bomber keeps its height above the ground on slopes | `pve_test.ps1 -Ren -RenTest -Widget zz_ren34.lua` |
| `zz_ren35.lua` | check | Renegade bomber with Space held never gets over its highest height | `pve_test.ps1 -Ren -RenTest -Widget zz_ren35.lua` |
| `zz_ren36.lua` | probe | Renegade bomber drops bombs at which heights | `pve_test.ps1 -Ren -RenTest -Widget zz_ren36.lua` |
| `zz_ren37.lua` | check | Renegade bomber, one short click | `pve_test.ps1 -Ren -RenTest -Widget zz_ren37.lua` |
| `zz_ren38.lua` | check | Renegade bomber, one short click at 400 above the ground (the gadget drops the bombs itself) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren38.lua` |
| `zz_ren39.lua` | probe | at what height does the engine's own bomb release fire, for every bomber | `pve_test.ps1 -Ren -RenTest -Widget zz_ren39.lua` |
| `zz_ren40.lua` | check | our own bomb release for every bomber | `pve_test.ps1 -Ren -RenTest -Widget zz_ren40.lua` |
| `zz_ren41.lua` | check | a bomber drops only up to its attack altitude | `pve_test.ps1 -Ren -RenTest -Widget zz_ren41.lua` |
| `zz_ren42.lua` | pictures | pictures of a shot of the Juggernaut in first person | `pve_test.ps1 -Ren -RenTest -Widget zz_ren42.lua` |
| `zz_ren43.lua` | pictures | picture of a weapon in the panel | `pve_test.ps1 -Ren -RenTest -Widget zz_ren43.lua` |
| `zz_ren44.lua` | pictures | weapon pictures of the Pulsar and the Juggernaut | `pve_test.ps1 -Ren -RenTest -Widget zz_ren44.lua` |
| `zz_ren45.lua` | pictures | weapon pictures of plasma, cannon, missile, starburst, salvo and torpedo units | `pve_test.ps1 -Ren -RenTest -Widget zz_ren45.lua` |
| `zz_ren46.lua` | check | the AUTO row of the anti-nuke launchers | `pve_test.ps1 -Ren -RenTest -Widget zz_ren46.lua` |
| `zz_ren48.lua` | check | the wider panel, the pointers and the list of the players | `pve_test.ps1 -Ren -RenTest -Widget zz_ren48.lua` |
| `zz_ren49.lua` | probe | firing cone (mainDir, maxAngleDif) of the weapons | `pve_test.ps1 -Ren -RenTest -Widget zz_ren49.lua` |
| `zz_ren50.lua` | probe | the turret angle of the Mauser (armmart) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren50.lua` |
| `zz_ren51.lua` | probe | which weapons shoot in an arc | `pve_test.ps1 -Ren -RenTest -Widget zz_ren51.lua` |
| `zz_ren52.lua` | check | the Mauser fires at the sky (arc weapons) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren52.lua` |
| `zz_ren53.lua` | check | anti-air lock still works with the shot-down check; aircraftState of the aircraft | `pve_test.ps1 -Ren -RenTest -Widget zz_ren53.lua` |
| `zz_ren54.lua` | probe | which Spring functions know about crashing aircraft | `pve_test.ps1 -Ren -RenTest -Widget zz_ren54.lua` |
| `zz_ren55.lua` | check | the third person camera (Shift) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren55.lua` |
| `zz_ren56.lua` | probe | the groups and the weapons of the Karganeth (corkarg) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren56.lua` |
| `zz_ren57.lua` | check | the shoulder rockets of the Karganeth (right button, air only) lock on an aircraft | `pve_test.ps1 -Ren -RenTest -Widget zz_ren57.lua` |
| `zz_ren58.lua` | check | air-only weapons and the flight of the missiles | `pve_test.ps1 -Ren -RenTest -Widget zz_ren58.lua` |
| `zz_ren59.lua` | check | direct and indirect missiles | `pve_test.ps1 -Ren -RenTest -Widget zz_ren59.lua` |
| `zz_ren60.lua` | probe | which missiles count as arc weapons (R.lobbed) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren60.lua` |
| `zz_ren61.lua` | check | all turrets follow the view (the D-gun too) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren61.lua` |
| `zz_ren62.lua` | check | a weapon fires only when it is loaded and the button is down | `pve_test.ps1 -Ren -RenTest -Widget zz_ren62.lua` |
| `zz_ren63.lua` | check | switch between Renegade and the normal game | `pve_test.ps1 -Ren -RenTest -Widget zz_ren63.lua` |
| `zz_ren64.lua` | check | the Exploiters (extractors with weapons) fire | `pve_test.ps1 -Ren -RenTest -Widget zz_ren64.lua` |
| `zz_ren65.lua` | check | energy and metal cost of the shots of the Exploiters and the resources of the teams | `pve_test.ps1 -Ren -RenTest -Widget zz_ren65.lua` |
| `zz_ren67.lua` | check | the Rattlesnake (armamb) and its trajectory state | `pve_test.ps1 -Ren -RenTest -Widget zz_ren67.lua` |
| `zz_ren68.lua` | check | the firing cones of the Exploiters | `pve_test.ps1 -Ren -RenTest -Widget zz_ren68.lua` |
| `zz_ren69.lua` | check | an Exploiter fires at an enemy unit | `pve_test.ps1 -Ren -RenTest -Widget zz_ren69.lua` |
| `zz_ren70.lua` | check | a spider walks backwards (S) without turning round | `pve_test.ps1 -Ren -RenTest -Widget zz_ren70.lua` |
| `zz_ren71.lua` | check | the binoculars and the speedometer | `pve_test.ps1 -Ren -RenTest -Widget zz_ren71.lua` |
| `zz_ren72.lua` | check | the information line of the unit menu | `pve_test.ps1 -Ren -RenTest -Widget zz_ren72.lua` |
| `zz_ren73.lua` | check | Renegade Flying Black Hydra on slopes | `pve_test.ps1 -Ren -RenTest -Widget zz_ren73.lua` |
| `zz_ren74.lua` | check | Renegade bomber ceiling and the bomb sight colour | `pve_test.ps1 -Ren -RenTest -Widget zz_ren74.lua` |
| `zz_ren75.lua` | check | Renegade laser aimed through the enemy at the point behind it | `pve_test.ps1 -Ren -RenTest -Widget zz_ren75.lua` |
| `zz_ren76.lua` | check | does the Juggernaut (corkorg) move from the start point? | `pve_test.ps1 -Ren -RenTest -Widget zz_ren76.lua` |
| `zz_ren77.lua` | check | Laser Tiger fires at the ground out of range | `pve_test.ps1 -Ren -RenTest -Widget zz_ren77.lua` |
| `zz_ren78.lua` | check | Renegade reverse gear | `pve_test.ps1 -Ren -RenTest -Widget zz_ren78.lua` |
| `zz_ren79.lua` | check | how smooth is the reverse gear | `pve_test.ps1 -Ren -RenTest -Widget zz_ren79.lua (game speed 1)` |
| `zz_ren80.lua` | check | Renegade takeover mode (the mode key takes over a unit and leaves it) | `pve_test.ps1 -Ren -RenTakeover -Widget zz_ren80.lua` |
| `zz_ren81.lua` | check | Renegade takeover mode with Evolution: the player takes over the evolved unit | `pve_test.ps1 -Ren -RenTakeover -Evo -EvoTest -Widget zz_ren81.lua` |
| `zz_ren82.lua` | check | the game's unit bars are off in Renegade | `pve_test.ps1 -Ren` |
| `zz_ren83.lua` | check | layout of the panels, the unit bars widget comes back | `pve_test.ps1 -Ren` |
| `zz_ren84.lua` | check | a Renegade aircraft with no health left crashes | `pve_test.ps1 -Ren -RenTest -Widget zz_ren84.lua (variants` |
| `zz_ren85.lua` | check | the distance of the third person camera | `pve_test.ps1 -Ren -RenTest -Widget zz_ren85.lua` |
| `zz_ren86.lua` | check | reverse from standing starts with a short forward drive | `pve_test.ps1 -Ren -RenTest -Widget zz_ren86.lua` |
| `zz_ren87.lua` | check | walking within 10 degrees of the view points the body exactly along it | `pve_test.ps1 -Ren -RenTest -Widget zz_ren87.lua` |
| `zz_ren88.lua` | check | fires at the nearest enemy to see the damage numbers | `pve_test.ps1 -Ren -RenTest -RenBots 3 -Widget zz_ren88.lua` |
| `zz_ren89.lua` | check | a hurt unit reclaims wrecks and heals (green plus signs and +N) | `pve_test.ps1 -Ren -RenTest -Widget zz_ren89.lua` |
| `zz_ren90.lua` | check | Renegade jump (Space) of a unit with two legs; tank and spider do not jump | `pve_test.ps1 -Ren -RenTest -Quick -Widget zz_ren90.lua` |
| `zz_ren91.lua` | check | Renegade with Evolution: the keys 1 to 5 use the power-ups (Sprint, Radar Pulse, Cloak) | `pve_test.ps1 -Ren -RenTakeover -RenTest -Evo -EvoTest -Debug -Quick -Widget zz_ren91.lua` |
| `zz_ren92.lua` | check | Renegade power-ups without Evolution (beacons, keys 1 to 5, the bar) | `pve_test.ps1 -Ren -RenTest -RenPowerups -Quick -Widget zz_ren92.lua` |
| `zz_ren93.lua` | check | Renegade kill goal, kill feed, banner of the end | `pve_test.ps1 -Ren -RenTest -RenBots 2 -RenGoal 3 -Widget zz_ren93.lua` |
| `zz_ren94.lua` | check | spawn shield and comeback bonus (Renegade and Evolution) | `pve_test.ps1 -Ren -RenTest -RenPowerups -Widget zz_ren94.lua (Renegade) or pve_test.ps1 -Evo -EvoTest -Widget zz_ren94.lua (Evolution)` |
| `zz_ren95.lua` | check | the sounds of Renegade and Evolution (mode_ui.lua) and the hit marker | `pve_test.ps1 -Ren -RenTest -RenPowerups -Widget zz_ren95.lua` |
| `zz_ren96.lua` | check | the hints for beginners of Renegade (mode_ui.lua) | `pve_test.ps1 -Ren -RenTest -RenPowerups -RenGoal 20 -Widget zz_ren96.lua` |
| `zz_ren97.lua` | check | Renegade, the mode Survival | `pve_test.ps1 -Ren -RenTest -RenMode survival -Widget zz_ren97.lua` |
| `zz_ren98.lua` | set | Renegade, the mode Race | `pve_test.ps1 -Ren -RenTest -RenMode race -Widget zz_ren98.lua` |
| `zz_ren.lua` | check | Renegade proof of concept 1 and 2 | `pve_test.ps1 -Ren -Widget zz_ren.lua. Steers renegade.lua through WG.renegade (no real mouse or keys) and logs "[zzren]" lines` |
| `zz_rendoc.lua` | pictures | pictures of Renegade for the manual | `pve_test.ps1 -Ren -RenTest [-RenMode race\|survival] [-RenBots 3] -Widget zz_rendoc.lua (one instance)` |
| `zz_reveal.lua` | check | a player on level 8 shows on the radar of the others | `pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_reveal.lua (one instance, speed 10)` |
| `zz_save.lua` | set | works the Save page (button S) | `arena_test.ps1 -Widget zz_save.lua` |
| `zz_scenario.lua` | set | works the Scenario info page (button I) | `arena_test.ps1 -Widget zz_scenario.lua` |
| `zz_shots_all.lua` | pictures | sets up the scenes of the pictures of the README | `arena_test.ps1 -Widget zz_shots_all.lua (with -Map "Full Metal Plate 1.7")` |
| `zz_sight.lua` | check | the sight of a unit with Renegade (3 times) and the Radar Pulse of Evolution (G.setSight) | `pve_test.ps1 -Ren -RenTakeover -Evo -EvoTest -Debug -Widget zz_sight.lua` |
| `zz_smart.lua` | probe | units with smart weapon selection (priority / backup trajectory weapons) | `pve_test.ps1 -Widget zz_smart.lua (without -Quick` |
| `zz_spider.lua` | probe | the movement classes of the units (spiders) | `pve_test.ps1 -Widget zz_spider.lua (without -Quick)` |
| `zz_split.lua` | check | the split attack (XS) on two Arena armies | `arena_test.ps1 -Widget zz_split.lua` |
| `zz_split_ally.lua` | set | split and focus attack never target own or allied units | `arena_test.ps1 -Widget zz_split_ally.lua` |
| `zz_split_shot.lua` | pictures | the picture of the split attack for the README | `arena_test.ps1 -Widget zz_split_shot.lua` |
| `zz_teams.lua` | set | plays through the teams page T and the alliances | `arena_test.ps1 -Widget zz_teams.lua` |
| `zz_tech.lua` | probe | tech level and metal cost of every armed unit, lines [zztech] | `pve_test.ps1 -Ren -Widget zz_tech.lua` |
| `zz_unitdump.lua` | probe | every mobile Armada, Cortex and Legion unit with its numbers | `pve_test.ps1 -Widget zz_unitdump.lua` |
| `zz_unitinfo.lua` | probe | facts of some unit definitions (movement, building flags) | `pve_test.ps1 -Widget zz_unitinfo.lua (without -Quick` |
| `zz_volcano.lua` | set | the model of the Volcano and its lava | `arena_test.ps1 -Widget zz_volcano.lua` |
| `zz_watch.lua` | check | wild units that a player sees keep their level | `pve_test.ps1 -Evo -EvoTest -Debug -Widget zz_watch.lua (one instance, speed 10)` |
| `zz_weapondump.lua` | probe | every weapon of every Armada, Cortex and Legion unit | `pve_test.ps1 -Ren -Widget zz_weapondump.lua` |
| `zz_wildhp.lua` | check | health of the wild (Gaia) units of Evolution | `pve_test.ps1 -Evo -Widget zz_wildhp.lua (one instance, speed 10)` |
