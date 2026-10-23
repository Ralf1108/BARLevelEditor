# LAN Play (prototype)

A widget for the official lobby (Chobby) of Beyond All Reason: the main menu entry **LAN Play** (right after Multiplayer) to host or join a game in the local network **with the official multiplayer battle room** (map, options, AIs, colours, teams, chat), without the lobby server in the cloud.

## How it works

The host's lobby runs a very small lobby server inside the widget (the "TASServer" text protocol the official lobby speaks, plus the part of an autohost the room needs). The lobby of every player then behaves as on a normal server:

- **Host a LAN game:** the widget listens on TCP port 8453, the lobby of the host connects to it (the server address of the lobby is changed for the time of the LAN game and put back when you leave), logs in and joins the battle. The battle room opens.
- **Find LAN games:** while the LAN Play page is open (and this computer neither hosts nor plays a LAN game) the widget looks for games by itself every few seconds: it asks `WHO` on port 8453 at the addresses `x.y.z.1 .. 254` of the own network (a /24 network is assumed; the lobby cannot ask for the netmask). A computer that hosts does not scan, so it never finds itself. A found game is a button; a click joins it (or type the address and press Join). The joiner's lobby connects to the host's server and joins the battle.
- **The menu button:** the tab "LAN Play" is added to the finished main menu, right below Multiplayer (the menu is one column; there is no place beside it). It is checked every second, because the lobby builds its menu again at times.
- **Normal Multiplayer is untouched:** the widget never changes the server address of the lobby (the lobby saves its configuration when it ends; an earlier version changed it and the official games were gone). It connects its own LAN connection with the LAN address only. "Leave LAN play" and leaving the battle room log the lobby in to the normal server again and bring the player back to the LAN Play page; after a game the lobby starts again and the widget opens the LAN Play page (marker file `lan_return.txt`).
- **Server side (what the widget answers):** `LOGIN`, `PING`, `JOINBATTLE`, `LEAVEBATTLE`, `MYBATTLESTATUS` (relayed as `CLIENTBATTLESTATUS`), `SAYBATTLE` / `SAYBATTLEEX` (chat, relayed), `ADDBOT` / `REMOVEBOT` / `UPDATEBOT` (AIs), and the autohost commands the room sends as chat: `!map`, `!bSet` (game options, relayed as `SETSCRIPTTAGS`), `!cv start` / `!start`. Only the host may use the `!` commands. Everything else (score, ratings, friends, channels, queues) is not answered.
- **Start:** `!cv start` makes the autohost set its status to "in game"; every lobby in the battle then connects to the game as for any game on a server (`ConnectToBattle`, with the script password the player sent when joining). The lobby of the **host** is the one that runs the game server: its `ConnectToBattle` is replaced by a `Spring.Reload` with a start script built from the state of the room (game, map, options, players with password, teams, ally teams, colours, sides, AIs, `HostIP=0.0.0.0`, port 8452).

## Install

The Level Editor setup (`install_editor.bat`) does it: it runs `install_lan_play.ps1` (copies `lan_lobby.lua` to `data\LuaMenu\Widgets\` and sets `["Chili lobby"].loadLocalWidgets = true` in `data\LuaMenu\Config\IGL_data.lua`, with a backup of that file; the game and launcher must be closed) and makes the junction `data\LevelEditorScenarios` -> `scenario\scenarios`. `uninstall_editor.bat` removes both. By hand: `powershell -File install_lan_play.ps1` (`-Uninstall` removes it again).

## What the sandbox test showed (2026-10-24)

Two sandbox instances of the real lobby on one computer (test file `lanlobby_cfg.txt` in the write dir: `auto=host|join`, `name`, `map`, `players`, `ip`): the joiner found the host by the scan, both logged in to the small server, both joined the battle, the host's lobby chose the map (`!map`) and pressed Start (`lobby:StartBattle()`, the call of the room's Start button, which sends `!cv start`); the autohost set "in game", the host built the start script (2 players with the passwords the lobbies had sent, Hooked 1.1, the game of the lobby, `HostIP=0.0.0.0`), both engines loaded the game, and the host log says "Connection attempt from ..." for both and "Player Hanna finished loading and is now ingame".

Sockets of the lobby: TCP listen and connect to any address are allowed, UDP receive too, **UDP send is refused** (`UDPAllowConnect` is empty). So TCP only.

## Not done / not tested

- Clicking (the test calls the same functions) and how the menu entry and the room look (screenshots of the OpenGL window come out black here).
- Chat is relayed by the server, but it was not checked that it shows up in the other room. Game options (`!bSet`), AIs and team/colour changes are answered but were not tried.
- Two computers. The join of a lobby that is logged in to the normal server (it is disconnected for the LAN game; coming back to the normal server is `Leave LAN play`).
- Own maps (a joiner without the map), scenarios, version check, update.
- Scenario button (planned): a list of the scenarios built in the Level Editor folder; start positions of a scenario are fixed.
- `RapidTagResolutionOrder` has to be in the springsettings in the sandbox (the launcher sets it in the real install).

## Scenarios from the lobby (checked 2026-10-24, not built yet)

Through the junction `data\LevelEditorScenarios` the lobby can list the built scenarios (`VFS.SubDirs`) and read `scenario.txt` (the lobby cannot read folders outside the game folder, so the junction is needed). A sandbox lobby did this, found the extra game "Tower Defense Scenario 1" (`VFS.HasArchive`), replaced `__GAMETYPE__` and `__PLAYERNAME__` in `scenario.txt`, started it with `Spring.Reload`, and the log says "Loaded synced gadget: Capture the Flag". The extra game has to be installed on every computer before the start (the engine takes the game named in the start script from the installed archives; the lobby cannot build or download one). Open: the extra game is built per scenario by `start_scenario.ps1` today.
