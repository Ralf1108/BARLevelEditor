-- Texts of the help board (the ? button) and of the chat help (/led_help): data only, loaded by lvl_level_editor.lua
-- (kept out of the widget file because that is close to the limit of 200 local variables).

-- Content of the help board: { section, { { key, explanation }, ... } }
local sections = {
	{ "Menu (right)", {
		{ "Header", "Two main menus: Place (Recent, Units, Features, Blueprints) and Generate (Units, Maze)." },
		{ "Button column at the far right", "V collapse, O settings (grid, unit limit, levels), I scenario info, T teams (human or AI, alliance, start resources), ? this help, P / G / TD / CF / RF pages, XL / XR / XC area attacks (experimental), FX / FD buildings indestructible / destructible (drag a rectangle)." },
		{ "Title row", "Drag the title \"Level Editor\" with the left mouse button: the whole menu (with the strip at the left and the button column) moves. Right click on the title: back to its place. The position is remembered." },
		{ "Click", "Arm a blueprint, unit or feature. Left click on the map places it, right click ends." },
		{ "Red X (Place menu)", "A small X on a unit picture, on a faction, a group or a tech button forbids it for the player in the game (Start, scenario): all units in it, or all units of a tech level. The X is on when all of them are forbidden and goes off when you allow one. Click again to allow. You can always place everything in the editor. The Tower Defense page shows the same list." },
		{ "Right click", "Anywhere: ends every mode (placing, delete, maze, generate, area attack). Without a mode it gives the order to the selected units." },
		{ "Mouse over a tile", "Large rotating 3D view (unit, blueprint, feature, recent item). Features: the list shows only pictures, below it the code name, metal, energy and description." },
		{ "Search field", "At the top of Place: one search over Recent, Units, Features and Blueprints at once (words of the description or the code). The tabs show the number of matches. Enter = done, Esc or X = clear." },
		{ "Blueprint tile", "Drag = sort, x = delete (click twice), double click on the name = rename, Create = save the selection." },
		{ "Recent", "Recently chosen blueprints and recently placed units." },
		{ "O", "Grid size, unit limit (written into the level for the scenario), columns and rows, below them the level list with load and save (second click confirms)." },
		{ "I", "Scenario info: title, author, summary, briefing, win condition, grace period, ID. Click a field and type; written with the level when you save it. Human or AI, alliances and start resources are on the page T." },
		{ "T", "Teams (0 to 9): per team Human or AI (click), the AI (click: NullAI, BARb, CircuitAI, Simple AIs, Scavengers, Raptors), the alliance (click: ten colors; teams with the same color are allies) and the start metal and energy. Saved with the level; the AI takes effect in the scenario (a running game cannot change an AI). Also: right click on a team button at the left chooses its alliance; the frame around the button shows it." },
		{ "CF", "Capture the Flag (button CF below TD): tick the box. Flag points belong to the team chosen in the strip (Gaia = neutral flags that every team may take); the box makes the flags visible on the whole map. Income: metal per second for every flag at the collection point (a carried or stolen flag pays nothing). Flags to hold at once to win (0 = no end), capture radius, time after which a dropped flag goes back (0 = it stays where the carrier died). A carrier cannot shoot and is slowed down to the top speed you set (default 50). Choose the team in the strip at the left, then Collection point and Flag point (as many of both as you like) and click on the map; Del over a point removes it. Start runs it, Stop brings the level back." },
		{ "RF", "Reclaim the Fame (button RF below CF): tick the box. Crystals are the nodes: click a tile at the bottom of the page (All / Small / Medium / Large filter), then click on the map; right click ends, Del deletes. Use an odd number. A construction unit that reclaims a crystal earns 1 point per second for every 100 build power for its team, times the factor of the crystal (default 100 / 200 / 400 %) and the rate; the crystal is never used up. Builders that score: Buildings (nano turrets), Ground, Ships, Air (default: ground and ships). Score limit of a team (0 = no end). Start runs it, Stop brings the level back." },
		{ "A", "Arena (button A between G and TD): armies of several teams fight each other. Radius: how far every army stands from the Arena Point. Table: one row per team, On / Off, the Units button (opens the list of allowed units: click a unit or the check boxes of faction, group and tech; Copy from takes over the list of another player), Count (units added by every Generate), Metal and Energy (budget, empty = no limit), and what is left of it. Arena Point: click the map; Alt + drag moves it, Shift + Alt + drag moves the whole setup, Del or X removes it. Generate: then click the map once, the point is set there and the armies stand around it. Clear removes what Generate placed. Formation attack (green = on): the armies keep their rectangles and walk at the speed of the slowest unit, then at full speed; off: every unit runs as fast as it can. Start sends all units of the rows that are on through the Arena Point (they fight on the way) and then back and forth (patrol) 250 Elmo behind and in front of it, Stop brings the state before back. Ctrl+Z undoes every step." },
		{ "TD", "Tower Defense (button TD below P and G): tick the box. Walls: choose Teeth or Walls; Single places single pieces (click or drag). Corridor (walls on both sides): Line (click points, right click builds) or Free (draw with the mouse held down) with the chosen width; the pieces are indestructible, Ctrl+Z undoes. Route: Spawn, Waypoint (click on the yellow line inserts, Alt + drag moves, Del removes) and Goal. Enemies allowed through, then waves with factions, tech, type (V vehicles, B bots, H hovercraft), count, gap in seconds and HP %. Restrictions: red X on a tower or tech level forbids it; Economy and Fog of war can be switched. Start at the bottom runs the waves in the editor, Stop brings the level back. Settings are saved with the level." },
	} },
	{ "Buttons left of the menu", {
		{ "W", "Write: on (green, default) = placing over something deletes what is in the way (Ctrl+Z brings it back); off = occupied spots are left free." },
		{ "DL  /  DR  /  DC", "Delete along a line, in a rectangle or in a circle (see Placing)." },
		{ "0, 1, 2 ...", "Team for new units and blueprints. With a selection: assigns the selection to this team." },
		{ "N", "Toggle: new units are neutral (flag, the team stays)." },
		{ "G", "Gaia team: belongs to no player, an enemy to everyone." },
		{ "L  R  S", "Only with a selection: rotate 90 degrees left, 90 degrees right, mirror left-right." },
	} },
	{ "Placing (mouse on the map)", {
		{ "[  ]", "Rotate (south, east, north, west), also for blueprints." },
		{ "Shift + drag", "Place a row. With Shift+Alt a rectangle." },
		{ "Shift+Mouse wheel, Alt+Z / X", "Spacing between the units of a row or rectangle." },
		{ "Generate", "Generate tab: choose faction, type (several possible: units, buildings, turrets, air, ships), tech T1-T3 and count (input field), press Rectangle or Circle (a circle is dragged from its center outwards) and drag the area on the map; random units appear in it for the chosen team. Ctrl+Z undoes them. The Maze sub-tab builds a random maze in the dragged area." },
		{ "DL  /  DR  /  DC", "Delete along a line, in a rectangle or in a circle: press the button (D = rectangle), then drag the shape on the map; everything in it (units, wrecks, features) is deleted. Ctrl+Z undoes it." },
		{ "XL  /  XR  /  XC", "Experimental area attacks (line, rectangle, circle): select bombers, artillery, rocket launchers or nukes, press the button and drag the shape on the map (circle from the center). Bombers form up and attack together, front targets first." },
		{ "M", "Maze: the key cycles through dragon teeth, walls, off (also the Maze sub-tab of the Generate tab). Then drag a rectangle or circle; a random maze appears in it (entrance top left, exit bottom right). Right click or arming something else ends the mode, Ctrl+Z undoes it." },
	} },
	{ "Editing the selection", {
		{ "Click / rectangle", "Select units of any team, enemies too (god mode is on in the editor); the command menu and the orders work for them." },
		{ "Alt + drag", "On a selected unit: move the selection (grid steps). On a feature (tree, rock, wreck) that is not a selected unit: move that feature. Ctrl+Z undoes it." },
		{ "Arrow keys", "Move the selection by one grid step (up = north). Without a selection they move the camera." },
		{ "Del", "Delete (the selection, otherwise the unit, wreck or feature under the cursor)." },
		{ "Ctrl+B", "Blow up, wrecks remain." },
		{ "Ctrl+C / X / V", "Copy / cut / paste." },
		{ "Ctrl+D", "Create the builders of all factions at the cursor." },
	} },
	{ "Undo and saving", {
		{ "Ctrl+Z / Ctrl+Y", "Undo / redo the last action: place, blueprint, paste, delete, blow up, move, rotate, mirror, team, features (a row counts as one step)." },
		{ "Ctrl+S", "Save the level (under the current name, otherwise as a new level_001 ...)." },
	} },
	{ "Start menu (console)", {
		{ "0  1  2  3", "0 continue the last state, 1 new level (search a map), 2 load a level, 3 build a scenario package (ZIP) from a level." },
	} },
	{ "Chat commands", {
		{ "/led_clear", "Clear the whole map (units; undo with Ctrl+Z). Level files: Ctrl+S and the settings (O)." },
		{ "/led_ghost", "Diagnose or switch the 3D preview of the placing ghost." },
		{ "/led_help", "Detailed help in the chat, with a topic, e.g. /led_help features." },
	} },
}

-- Layered help: /led_help shows the short version and the topics, /led_help <topic> the details
local topics = {
	{
		names = { "start" },
		lines = {
			"START: desktop shortcut 'BAR Level Editor'. Key 0 = continue the last state, key 1 = new level (search a map), key 2 = load a saved level, key 3 = build a scenario package (ZIP) from a level. You change the scenario info in the game with the I button.",
			"No /cheat is needed in the game. Placing, building, saving and loading work right away. Everything is free and finished instantly.",
			"Legion, the extra pack and release candidates are on. You start the normal multiplayer game through 'Beyond All Reason'.",
		},
	},
	{
		names = { "keys" },
		lines = {
			"KEYS (point the mouse at the map):",
			"[ and ] rotate the chosen unit or blueprint (south, east, north, west). You save a selection as a blueprint with Create in the blueprint menu, rename it with a double click.",
			"Del deletes and Ctrl+B blows up (wreck stays): works on the selection, without one on the unit, wreck or feature under the cursor. Ctrl+C copies, Ctrl+X cuts, Ctrl+V pastes, Ctrl+D creates the builders of all factions at the cursor.",
			"Ctrl+Z undoes the last action (also delete, blow up, move, rotate, team and features), Ctrl+Y redoes it. Ctrl+S saves the level.",
			"Hold the left mouse button and move to paint: with an armed unit or feature one is placed after every footprint (plus the spacing) of mouse movement, one undo step per stroke; places that are already occupied are skipped. Arrow keys move the selection by one grid step (up = north), Alt + drag moves it with the mouse. Shift + drag places a row, Shift+Alt + drag a rectangle, Shift+Mouse wheel changes the spacing.",
			"CHOOSING ENEMIES: in the editor the god mode is on, so you select units of EVERY team like your own (click or rectangle); the command menu and the orders work for them. Then delete, blow up, assign to a team, copy or save as a blueprint.",
		},
	},
	{
		names = { "place", "unit" },
		lines = {
			"PLACING: click a unit in the Units menu, left click on the map places it, right click ends. Choose the team with the buttons left of the menu.",
			"Team 0 = you; which team is player, ally or enemy in a scenario is set on the scenario page (button I). The grid is set in the settings (button O). The spacing of rows changes with Shift+Mouse wheel or Alt+Z / X.",
			"Air units appear in the air and stay in flight mode. Ships need water.",
		},
	},
	{
		names = { "units", "group", "generate", "buildings", "turrets", "air", "ships" },
		lines = {
			"GENERATE: the Generate menu (button G of the button column) fills a rectangle or a circle with random units, buildings, turrets, air or ships. Choose team, faction, type(s), tech levels and the count, then Generate and drag the area.",
			"The sub-tab Maze builds a random maze of dragon teeth or walls in the dragged area (also key M), corridors 32 to 192 Elmo wide. At most 12000 pieces; buildings and turrets stand on free building spots, units on passable ground.",
			"Enemies fight on their own within range. Air units appear in the air in flight mode.",
		},
	},
	{
		names = { "blueprint", "blueprints", "layout" },
		lines = {
			"BLUEPRINT: select units or buildings, then Create in the blueprint menu saves the layout (folder LevelEditor/blueprints).",
			"A click on a tile chooses it; left click on the map places it with the saved teams, or for the team chosen on the left.",
			"MENU: the Blueprints tab of the Place menu shows the tiles with preview pictures. Click a tile, then left click on the map places, right click ends, the mouse wheel scrolls.",
			"UNITS MENU: the Units tab of the Place menu. Choose faction, group (buildings, air, vehicles, bots, hover, ships) and tech (T1-T3), click a unit, left click on the map places it (blue outline), right click ends, [ and ] rotate. You choose the team with the buttons left of the menu.",
			"SORTING: drag a tile with the mouse and drop it elsewhere. DELETING: small x at the top right, click twice (trash: blueprints/_trash). RENAMING: double click on the name, Enter.",
			"Air units keep their height, landed air units stay landed. The layout is not checked for passability.",
			"PREVIEW: when you move the mouse over a tile, a large rotating 3D view of the blueprint appears (all units in place).",
		},
	},
	{
		names = { "save", "load", "last" },
		lines = {
			"SAVING: Ctrl+S writes the level to LevelEditor/levels/<name>.lua: all units (position, height, team) and all features (wrecks, trees, rocks).",
			"LOADING: the level list in the settings (button O) clears the map (except the builder rows) and sets the level up again. Features are replaced if the file contains any. /led_clear clears units only.",
			"Ctrl+S saves the level under the current name, otherwise as a new level_001, level_002 ...",
			"AUTOSAVE: the editor saves every 2 minutes and when you leave, as _last. At the next start key 0 ('Continue the last state') brings it back.",
			"Air units in the air are loaded in the air, air units on the ground landed. The file states which game options (e.g. extra pack) must be on in the main game.",
		},
	},
	{
		names = { "team", "teams", "assign" },
		lines = {
			"TEAM: a click on a team button gives the selected units to that team (0 = you, 1 = enemy).",
			"The chosen team also applies to new units and to the Generate tab.",
		},
	},
	{
		names = { "edit", "move", "rotate", "mirror" },
		lines = {
			"EDITING THE SELECTION: when units are selected, three buttons appear on the left above the team buttons: L = rotate 90 degrees left, R = right, S = mirror left-right (around the center of the selection). The selection is kept.",
			"MOVING: with the arrow keys the selection moves by one grid step. Or hold Alt, click a selected unit, drag, release. It moves in grid steps (green preview).",
			"TEAM: a click on a team button assigns the selected units to that team. N = neutral (toggle), G = Gaia team (at most 500 units: the engine gives Gaia a fixed limit; use N for many neutral units). A tooltip appears when you hover over the buttons.",
			"SELECTION INFO: at the top center you see the count, types and cost of the selection. Ctrl+Z undoes, Ctrl+Y redoes.",
		},
	},
	{
		names = { "features", "feature", "trees", "rocks", "wrecks" },
		lines = {
			"FEATURES: Place menu, tab 'Features'. Trees, rocks, wrecks and the rest. The list shows only preview pictures; when you hover over one, a large rotating 3D view appears, and below the menu the code name, metal, energy and (if any) the description.",
			"Click a feature, left click places it, right click ends, Del deletes the feature under the cursor.",
			"The rotation follows the facing ([ and ] rotate). Features are saved in the level with Ctrl+S.",
		},
	},
	{
		names = { "search", "recent", "levels" },
		lines = {
			"SEARCH: the Place menu has one search field at the top for Units, Features and Blueprints together. Click and type words of the description or the code; the tabs Recent, Units, Features and Blueprints show how many match and list the matches (across all factions, groups and tech levels). Enter ends the input, Esc or the X button next to it clears the search.",
			"RECENT: recently chosen blueprints and recently placed units, click to use them again (stored in LuaUI/Config/LevelEditorRecent.lua).",
			"LEVELS: 'O' opens the settings, below them the list of saved levels. Loading and saving need a second click as confirmation, 'Save as new' creates level_001, level_002 ...",
		},
	},
	{
		names = { "scenario", "info", "i" },
		lines = {
			"SCENARIO: the I button (button column at the far right) opens the scenario info: title, author, summary, briefing (Shift+Enter = new line), win condition, grace period (m:ss) and ID. Human or AI, alliances and start resources of the teams are on the page T.",
			"TECH: per team, switch T1, T2 and T3 on or off individually (default all on). An enemy with only T1 can only build tier 1 units and buildings.",
			"The info is saved with the level (Ctrl+S). You build the playable package in the start menu with key 3: choose a level, a folder and a ZIP are created in LevelEditor/scenario/scenarios.",
		},
	},
	{
		names = { "delete", "maze", "attack", "right" },
		lines = {
			"DELETE: the buttons DL, DR and DC in the strip left of the menu delete everything along a dragged line, in a dragged rectangle (also key D) or in a dragged circle: units, wrecks and features. Ctrl+Z brings it back.",
			"MAZE: Generate menu, sub-tab Maze (or key M): choose dragon teeth or walls, press Generate and drag the area; entrance top left, exit bottom right.",
			"AREA ATTACK (experimental): select bombers, artillery, rocket launchers or nukes, press XL, XR or XC and drag a line, rectangle or circle; the bombs and shots of all of them are spread evenly over it.",
			"RIGHT CLICK: anywhere it ends every mode (placing, delete, maze, generate, area attack); without a mode it gives the order to the selected units.",
		},
	},
	{
		names = { "build", "builder" },
		lines = {
			"BUILDING: at the start only the commander stands there. With Ctrl+D you create all mobile builders of every faction at the cursor, grouped by kind.",
			"With them you build factories and buildings as in the normal game: free and finished instantly. The builders stand on passable spots. They are only tools and are not saved in the level.",
		},
	},
}

return { sections = sections, topics = topics }
