# LAN lobby: technical details

How LAN Play works inside. How to use it: [docs/lan-play.md](../../docs/lan-play.md). Full specification: `LevelEditor/SPECIFICATION.md` (14.2 and 14.3). Test notes: `LevelEditor/test-data/TESTING.md`.

## Parts

- `lan_lobby.lua`: a widget for the lobby of the game (Chobby). It adds the menu tab **LAN Play** and contains a small lobby server
- `install_lan_play.ps1`: copies the widget to `data\LuaMenu\Widgets\` and the game widget `shared_start.lua` to `data\LuaUI\Widgets\`
- The host's lobby runs the server inside the widget: the text protocol the official lobby speaks (TASServer) plus the part of an autohost that the battle room needs. Every player's lobby then behaves as on a normal server

## Network

- **Ports:** 8453 (TCP) is the lobby server of the host. 8452 is the game itself (`HostPort` of the start script, `HostIP=0.0.0.0`)
- **Accepted addresses:** only local ones: 127.x, 10.x, 172.16-31.x, 192.168.x, 169.254.x, and the VPN ranges 100.64-127.x (Tailscale) and 25.x (Hamachi). The lobby cannot list the network cards, so these ranges stand for "the LAN"
- **Firewall:** the lobby runs inside `spring.exe`. Windows asks once for the game on a new network: allow it on private networks. Both ports must be reachable between the computers
- **Finding games:** while the LAN Play page is open, the widget asks `WHO` on port 8453 at `x.y.z.1 .. 254` of its own network every few seconds. A /24 network is assumed (the lobby cannot ask for the netmask). A host does not scan. In bigger networks or over a VPN: type the address
- **Sockets of the lobby:** TCP listen and connect to any address are allowed, UDP receive too, **UDP send is refused**. So everything the widget sends is TCP
- **No web calls:** LuaSocket has no TLS and the file servers answer HTTP with a redirect to HTTPS. A widget cannot fetch anything online. What needs the internet is done by the setup (PowerShell) or by the lobby's own download handler

## Lobby and server

- **Name:** the lobby's login name (or the Steam name, else "Player"); a changed name is kept in `data\lan_name.txt`. The host refuses a second player with the same name
- **The server address of the lobby is never changed** (the lobby saves its configuration when it ends). The widget makes its own LAN connection. Leaving logs the lobby in to the normal server again; after a game a marker file (`lan_return.txt`) brings the player back to the LAN Play page
- **Menu tab:** added to the finished main menu below Multiplayer and checked every second (the lobby rebuilds its menu at times)
- **The server answers:** `LOGIN`, `PING`, `JOINBATTLE`, `LEAVEBATTLE`, `MYBATTLESTATUS`, `SAYBATTLE`/`SAYBATTLEEX`, `ADDBOT`/`REMOVEBOT`/`UPDATEBOT` and the autohost commands the room sends as chat (`!map`, `!bSet`, `!cv start`; only the host may use them). Scores, ratings, friends, channels and queues are not answered
- **Start:** `!cv start` sets the autohost "in game", every lobby connects to the game as on any server. The host's lobby replaces `ConnectToBattle` by `Spring.Reload` with a start script built from the room (game, map, options, players with passwords, teams, colours, AIs). With several humans in one team (Copilot) the game widget `shared_start.lua` sends `forcestart`, because the engine's pregame would wait for ever

## Short connections before login

- Commands on port 8453 that need no login, each answered with one line (or a file) and then closed:
  - `WHO`: the search for games
  - `COPILOT`: who has which Copilot number
  - `LANVER`: the version of the host
  - `MAPINFO <name>`: size, md5 and file name of the room's map
  - `FETCHGAME <hash>` and `FETCHMAP <first> <count> <name>`: the files (below)
- Why not game options: the room prints every game option as a text line and pushes its own buttons away

## Version check

- The joiner asks `LANVER` and gets `<hash of lan_lobby.lua>|<hash of shared_start.lua>|<number>|<date time>` and compares it with his own
- Equal: nothing. Different: one message window (version of host and joiner, who is newer, how to update). A warning, no lock
- `LAN_VERSION` at the top of `lan_lobby.lua` is raised with every change after the first release. The hashes also catch a changed file whose number stayed

## Maps

- The lobby would start its own online download of a missing map. The widget holds that call back until it knows where the map comes from
- The joiner asks `MAPINFO`. The host answers only for the map of its room and only for a `.sd7` / `.sdz` in `maps` (at most 300 MB)
- The list of official maps: the setup (`Update-MapHashes` in `shared\bar_common.ps1`) saves it as `data\games\LevelEditorMapHashes.txt` (`<spring name>|<md5>`, from `maps-metadata.beyondallreason.dev`, 227 maps, 60 KB, fetched with `If-None-Match`; offline the old list stays)
- **Same md5 as the list:** fetch from the host at once, no question. **Other md5:** a window warns and asks. **Not in the list or no list:** a window asks, the md5 is the host's word. The window offers "From the host" or "Online"
- **Transfer:** blocks of 64 KB on 8 connections at once (`MAP_STREAMS`), `FETCHMAP <first> <count> <name>` answers `BLOCKS ...` and the blocks. A widget moves about one buffer per connection and frame, so 1 connection gave 1.7 MB/s and 8 give about 10 MB/s (69 MB in 7 s on one computer)
- The blocks are written into `maps/<file>.part`. Size and md5 are checked, then it is renamed and `VFS.ScanAllDirs()` makes the game know it. A bad file is deleted and the lobby loads the map online. The start of the game waits for the map
- The lobby's Lua counts a file 3 bytes longer than it is (content and md5 are right), so the transfer is in blocks, not in bytes

## Scenario game

- A scenario runs in the extra game `Level Editor Scenarios <version>` (`data\games\LevelEditorScenarios_<version>.sdz`): only Lua files, the version is a hash of them
- The host announces version, hash and size (`lansync`). A joiner without that version is asked, fetches it with `FETCHGAME <hash>` (at most 4 MB), checks size and hash, and keeps it as a file of its own. His own version is never replaced

## What goes over the network

- Only two kinds of files: the scenario game (Lua, max 4 MB) and the map of the room (max 300 MB). Never programs, PowerShell or batch files. The lobby widget is never sent, only compared
- The host serves only the map of its room and its own scenario game
- The checks prove that a file is the one the host announced, not that the host is honest. Scenario scripts run on every player's computer: play with hosts you trust

## Install

- `install_editor.bat` runs `install_lan_play.ps1` (the game and the launcher must be closed): it copies the widgets and sets `["Chili lobby"].loadLocalWidgets = true` in `data\LuaMenu\Config\IGL_data.lua` (a backup of that file is made). It also makes the junction `data\LevelEditorScenarios` -> `scenario\scenarios` and saves the map list
- `uninstall_editor.bat` removes it again. By hand: `powershell -File install_lan_play.ps1` (`-Uninstall`)

## Tested

- Two real game instances on one computer (own test tool `lan_test.ps1`): join, start, scenarios, Capture the Flag, Reclaim the Fame, Tower Defense, Copilot, scenario transfer, map transfer with all list cases, version warning
- Not tested: two real computers, three or more players, the look of the windows and real clicks, declining or a failing transfer, maps that are folders (`.sdd`, not served)
