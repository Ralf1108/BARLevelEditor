# Scenario builder

Builds a finished scenario from a saved level of the Level Editor that anyone can play with the **official Beyond All Reason**. Nothing in the game is changed and no mod is needed (only a Tower Defense scenario builds a small extra game next to the official one, see below).

## Using it
1. Save the level in the Level Editor (Ctrl+S). It then lies in `..\levels`.
2. In the start menu of the Level Editor press key 3 and choose the level (at the end it lists the values stored in the level, asks for the title (Enter keeps it) and then shows the target name = the ID of the scenario (a new title proposes a new name): Enter takes it, another name changes it and is stored in the level; an existing scenario of that name is only overwritten after a question; then it builds without more questions from the info in the level; or by hand `powershell -File scenario_builder.ps1`, which asks everything in the window, Enter takes the default):
   - which level (list with numbers; `_last` is the automatically backed up state)
   - title, author, summary, briefing (several lines, an empty line ends)
   - role of every team in the level: **Player** (exactly one), **Allied AI**, **Enemy (AI)**
   - behavior of the AI: BARb (expands and attacks) or NullAI (does nothing)
   - win condition (commander / all units / no end), start metal, start energy, **grace period** (as minutes:seconds, e.g. 2:30, or minutes like 2.5; 0 = none), **tech per team** (T1/T2/T3 allowed individually, e.g. enemy only T1), ID
   All answers are then stored **in the level itself** (block `scenario` at the start of the level file). On the next run with the same level they are the defaults, Enter takes them. The Level Editor leaves the block unchanged when saving (it reads it before overwriting and writes it back; with "save under" a new name it takes the block of the level loaded last). The block carries a version number (`version`) so later changes do not make old levels unusable: older versions are converted when reading, unknown fields from newer versions are kept. The ID belongs to the level and stays the same; a new run replaces `scenarios\<id>\`.
3. The result is in `scenarios\<id>\` and as `scenarios\<id>.zip`. You pass the zip file on.

Change the info: in the Level Editor with the I button (it is stored in the level); then key 3 again. `scenario_builder.ps1 -Edit` still works by hand.

Non-interactive (tests): `powershell -File scenario_builder.ps1 -Level name -Auto`.

## Playing (for the recipient)
Unpack the zip, double-click `Start Scenario.bat`. BAR must be installed and started once. The script finds BAR (otherwise it asks for the folder), determines the installed game version, asks before downloading a missing map (y/n; with "n" it aborts) and then starts the game. The folder may lie anywhere.

## Capture the Flag scenarios
If Capture the Flag is switched on in the level (page **CF** of the editor, with at least one flag point and one collection point), the package contains its settings (game option `ctfconfig`) and the gadget `ctf_game.lua`; like for Tower Defense `Start Scenario.bat` builds the small extra game **"Tower Defense Scenario"** (`data\games\TowerDefenseScenario.sdz`, builds on the installed BAR, no official file is changed) and starts with it. The computer opponents get no AI (NullAI) and the win condition is "no end": the gadget decides (the first team with the wanted number of flags wins; 0 = no end). The scenario starter starts one human player, so it is mainly for trying a level out; the real game is human against human on the editor's test run or in a game you host yourself. Tower Defense and Capture the Flag exclude each other in the editor; a level file with both on is refused by the script.

## Tower Defense scenarios
If Tower Defense is switched on in the level (page **TD** of the editor, with spawn point, goal and at least one wave), the package contains **everything of that page**: the waves, the route (spawn point, waypoints, goal), the allowed number of enemies through, the forbidden towers and tech levels, the restriction to towers (and economy), fog of war and the indestructible walls. The enemy waves come from a gadget, which the official game cannot load; therefore `Start Scenario.bat` builds a small extra game **"Tower Defense Scenario"** next to the official game (`data\games\TowerDefenseScenario.sdz`; it only adds the gadget and builds on the installed BAR, no official file is changed; delete the file if you do not want it any more) and starts with it. Notes: the enemy team gets no AI of its own (NullAI) and the win condition is "no end" (the waves decide: all beaten = won, too many through = lost); there is no grace period (the no-rush rules of the game keep every unit in its start area while it runs, so the enemy waves could not leave the spawn point; the saved value stays in the level); the start commander of the player is removed when the waves start, so the level needs builders; a level with only one team gets an extra enemy team for the waves.

## What is in the package
| File | Content |
|---|---|
| `Start Scenario.bat` | double-click start |
| `start_scenario.ps1` | finds BAR and the engine, puts the game version and player name into the start script, downloads the map, starts `spring.exe` |
| `scenario.txt` | start script: teams, allies and enemies, AIs, game options and `scenariooptions` |
| `scenario_briefing.lua` | user widget with the briefing window (the starter puts it into `data\LuaUI\Widgets`; the mission display of the game otherwise only shows "No additional briefing data found") |
| `README.txt` | briefing and instructions |
| `ctf_game.lua` | only in a Capture the Flag scenario: the gadget that runs flags, collection points and rewards |
| `td_waves.lua` | only in a Tower Defense scenario: the gadget that runs the waves and the restriction to towers (see below) |
| `unit_restrictions.lua` | only if the level has restrictions (units the player cannot build, set with the X marks of the Place menu): the gadget that refuses them; the starter then builds the small extra game "Tower Defense Scenario" also for an ordinary level (game option `restrictions`) |

## How it works
The official game knows scenarios: the game option `scenariooptions` contains the unit list (`unitloadout`) and the feature list (`featureloadout`). The game sets them up at the start and then places no start commanders. The option is in the start script as `base64url(zlib(json))`. The level files of the editor have exactly this format.
- Wrecks (features `<unit>_dead`) get `resurrectas` in the scenario so that resurrection bots can resurrect them (reclaiming always worked). Heaps (`_heap`) cannot be resurrected. In the level file it appears as `resurrectas = 'unit'` at the wreck (the editor writes it too). In the editor itself the gadget sets the resurrection when it creates a wreck, too.
- Nuclear silos start **empty** in a scenario (the editor loads them for testing, but the missiles are not stored in the level).
- Resurrected units are set to hold position (by the briefing widget, for the player's own units).
- Gaia units (button G in the editor) are in the level with `gaia = true`. In the scenario they get the Gaia number of the game (= number of real teams). Gaia is always an enemy to everyone and is not controlled by an AI.
- The teams of the level are renumbered to 0 to n-1 (player = 0), because the engine needs gapless numbers.
- Game options that the level needs (Legion, extra pack, release candidates) are taken from the level file into the game options of the scenario.
- The unit limit (`maxunits`) is taken from the level (`unitlimit`, set in the editor settings, default 32000) so levels with very many units are set up completely.
- The faction picker is switched off (`disablefactionpicker`), the side of a team follows its units.
- Briefing and title are in `README.txt` and in `scenariooptions`. The mission display in the game only shows scenarios from the game archive; that is why `scenario_briefing.lua` shows the briefing at the start and through the "Mission" button (`/briefing` opens it again). It needs user widgets to be allowed.

- **Grace period** (the game's no-rush): the script defines a start area for every side (frame around its units plus 300 units margin, as a fraction of the map; with 30 or more units the outer 3 % of each edge do not count; overlapping or too close areas are separated, the one of the player side stays whole and between the sides a strip of 500 units without area remains), sets `norushtimer` and the start mode "choose in the game" (`startpostype=2`; the start areas only work this way). Until it ends no side can leave its area and each is safe from damage there. The choice of the start position that the game then demands is done by the briefing widget itself (middle of the own area, then "ready"); the player does not have to click anything. The map size is in newly saved levels (`mapsize`); for old levels the script asks once.
- **Tech restriction** per team (T1/T2/T3 individually on/off, default all on; button I in the editor or question in the script): e.g. enemy only T1. Locked units and buildings cannot be built by the team (not in factories either); existing ones stay. The briefing widget sets the locks at the start of the game and names them in the briefing. Tier 1.5 (hover, amphibious, seaplane factories) counts as T2.

## Limitations
- The builders that the editor creates with Ctrl+D are not part of the level.
- Without internet the map must already be installed at the recipient.
