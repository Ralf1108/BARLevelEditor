# Scenarios with several players

The console lobby (`lobby.ps1`), split screen, direct host and join, and playing a level at once through a bundle. Everything is PowerShell in `LevelEditor\scenario\template\` (also copied into every package). The multiplayer room inside the game is [LAN Play](lan-play.md). Package, `scenario.txt` and starter: [Scenario builder](scenario-builder.md). User view: [Scenario builder manual](../LevelEditor/scenario/README.md) (Several players). Tested so far only on one computer.

## 1. Entries and options

- **Entries:** start menu key 4 → scenario → **Single player** (`start_scenario.ps1` without options), **Host** (`-HostGame -Lobby`), **Join** (`-Join -Lobby`) or **Split screen** (section 8); key 6 plays a level at once (section 4). Every package also has `Host Game.bat` and `Join Game.bat` with the same options (written by the builder next to `Start Scenario.bat`, together with `player_mapping.ps1` and `lobby.ps1`, which the starter dot-sources). All players need the same BAR version; every computer builds the extra game itself.
- **Options of `start_scenario.ps1`:**

| Option | Meaning |
|---|---|
| `-HostGame`, `-Join` | host / join (asks for address and name) |
| `-JoinIp <address>`, `-Name <name>` | join without the questions |
| `-Lobby` | use the lobby below |
| `-LobbyPort` | TCP, 8453 |
| `-LobbyAutoStart n` | the host starts by itself when n players are in (tests) |
| `-Port` | UDP game port, 8452, fixed |
| `-Wait` | seconds the game waits after the host has loaded: 90 without a lobby, 15 with a lobby, 10 for the split screen |
| `-Mapping "PlayerA=0,Anna=2"` | who plays which team, first = host |
| `-Players n` | without lobby and mapping: number of humans for the dialog |
| `-HostIp` | 0.0.0.0; the split screen gives 127.0.0.1 |
| `-WindowRect x,y,w,h` | place the window (section 8) |
| `-NoBuild`, `-WaitForHost`, `-ScriptOnly` | keep the extra game / wait until the host listens / only write the script |

- **Join:** the address comes from a list of the last 10 addresses (`%LOCALAPPDATA%\BAR-Scenario\Last Joined Addresses.txt`, newest first, shared by all scenarios): a number picks one, Enter = the newest, anything else is a new address. The name is asked next (default: the Windows user name cleaned to letters, digits and `_-[]`, afterwards the last one used, `Last Player Name.txt`).
- **Network:** TCP 8453 (lobby) and UDP 8452 (game) in the firewall of the host (Windows asks for `spring.exe` and `powershell`). The host's lobby (`Update-LobbyNet`) closes every connection whose address is not this computer or in a network of one of its network cards (`Test-SameLan`, the networks read once by `Get-LocalNets`; the VPN ranges 100.64.0.0/10 and 25.0.0.0/8 count as a whole when a card has an address there), with the note "A connection from ... (outside the local network) was refused."

## 2. The lobby (`lobby.ps1`)

Runs right after the scenario is read, before the extra game is built and the map is fetched.

- **Host screen** (`Get-LobbyLines`): a title line (host, addresses, port, number of players), one box per team (`Get-TeamInfo` reads `Side` and `AllyTeam` of `scenario.txt`: "Team n: Side, ally team m"; players below, "(host)" behind the host) and the last box "[ Start game ]" ("ready" or the reason). The focus starts on "Start game", so Enter or F5 starts at once once two players are in.
- **Placing:** everybody who joins lands in a team box at once: the team of the last mapping (by name, `Last Player Mapping.txt` in `%LOCALAPPDATA%\BAR-Scenario`) if nobody is there, otherwise the first team without a player, otherwise team 0. A team may hold several players. A joiner whose connection breaks (also without `BYE`) is removed.
- **Keys of the host:** `Tab` / `Shift+Tab` or `Left` / `Right` = next / previous box (the last stop is "Start game"); `Up` / `Down` = player in the box; `Enter` = pick the player up (yellow, "<- moving"), then the arrow keys move them into the neighbouring team box, `Enter` drops them, `Esc` puts them back; `N` = see section 3; `Enter` on "Start game" or `F5` = start (two players are needed, otherwise the reason is shown); `Esc` twice = cancel.
- **Protocol** (TCP, one UTF-8 line each): joiner `VERSION <protocol>`, `HELLO <name>`, `BYE`, later `READY`; host `OK <name as the host knows it>` (name used already or empty after cleaning: `ERR <reason>` and the connection is closed), `VERSION <protocol>`, then `TEAM <n> <text>` and `ROSTER name=team;...` whenever something changes, at the end `START` or `CANCEL`, and `GO`. The joiner (`Join-Lobby`) shows address, status, their team and the players; `Esc` leaves.
- **Version:** `$script:LobbyProtocol` in `lobby.ps1` (the protocol and what a joiner does with it; raise it when that changes). A host with another protocol answers `ERR ... please update the Level Editor manually` and closes the connection. The start menu shows the lobby version in its first line. Everybody plays the **host's game**: the gadget versions do not have to match (section 4). Nothing that runs on the computer itself comes from another computer; the editor is never updated through the lobby.
- **Start:** the host sends `START` and keeps the connections; the roster (name, team; host first) is saved as the last mapping and becomes `-Mapping`. Everybody prepares: the host builds the extra game, checks the map and writes the start script; every joiner does the same (extra game unless `-NoBuild`, map) and sends `READY` (`Wait-JoinerGo`). The host waits for all of them (`Wait-LobbyReady`, up to 300 s; if somebody went away or does not come, nothing is started and the others get `CANCEL`), starts `spring.exe`, waits 5 s (the engine listens after about 3 s) and sends `GO`; the joiners then start `spring://<name>@<address>:<port>` and the game begins `-Wait` seconds after the host has loaded.

## 3. Player numbers and Copilot in the lobby

The boxes of one ally team (`Get-BoxAlly`: the text "ally team n" of the team line; `Get-AllyBoxes`, `Get-SlotNumber`) are the players 1, 2, 3 ... of that team; the team line says "(player k of n in its team)", the line of a human "player k" and, when a box holds more than one human, "+ together with ...". Key **N** on the human under the cursor puts them into the next box of their ally team (`Step-LobbyNumber`). Humans in the same box play one player together (Copilot): the roster `Name=Team` has the same team twice, `start_scenario.ps1` gives every roster entry its own `[playerN]` with that `Team=`.

`shared_start.lua` (source `scenario\template\shared_start.lua`, also in the package and the bundle) is a game widget of the extra game; it acts only with `scenariooptions` or `lanplay=1` and removes itself otherwise. Why: two humans in different teams start by themselves after the delay of the start script, two humans in the same team stay in the pregame for ever; the widget of the host (player 0) sends `forcestart` three seconds after every human is `active` (only if some team has two or more humans). Not checked: a full hosted game through the console lobby with two humans in one box (the same mechanism ran through LAN Play).

## 4. The bundle: the host's scenario for everybody

In every hosted game with the lobby the host offers a bundle (`New-HostBundle`): `scenario.txt` and the Lua files of the extra game the scenario runs (gadgets, `bar_rules.lua`, `led_gadgets.lua`, `scenario_briefing.lua`, `shared_start.lua`, from the editor or the package). The joiners take it and build their extra game "Level Editor Scenarios <version>" from it (`$gameDirs` = the bundle); the host builds theirs from the same bundle.

- `scenario_builder.ps1 -Level <name> -BundleDir <folder>` (implies `-Auto`) writes only `scenario.txt` and the gadgets the scenario uses into the folder (no starters, bats, readme, zip; nothing is written into the level).
- `Install-Bundle` puts those files into the cache `%LOCALAPPDATA%\BAR-Scenario\Cache\<hash>\` (finished when `complete.txt` is there). The **hash** (SHA-256 over file names and bytes of the allowed files in a fixed order, `Get-BundleHash`) is the id, so the same level gives the same folder on every computer.
- `start_scenario.ps1 -Bundle` (needs `-EditorDir`; the BAR path is remembered in `%LOCALAPPDATA%\BAR-Scenario\bar_path.txt`): the host gives `-ScenarioDir <cache folder>`; a joiner gives none, takes the bundle from the lobby and reads `scenario.txt` from the cache.
- **Transfer** (additional lines): host after `OK` and `VERSION`: `OFFER <hash> <size of the zip>`. A joiner with the hash in their cache says `HAVE <hash>`; otherwise they open a **second connection** to the lobby port (so the text lines of the first one never see binary data), send `FETCH <hash>` and get `SIZE <n>` and the n bytes of a zip (`New-HostBundle` makes it from the bundle in the cache; the host sends 256 KB per round with `WriteAsync`, so a slow joiner never blocks the lobby). The joiner shows the progress (`PROGRESS <percent>` to the host every 5 %: "(loading the scenario: 45 %)" in their box), unpacks, **checks the hash** and says `HAVE <hash>`. The host cannot start until everybody has said `HAVE`.
- **Safety:** no program code comes from another computer. `Expand-BundleZip` accepts only the names of `$script:BundleFiles` (`scenario.txt` and the Lua files of the extra game; no paths, no `..`, no subfolders) and at most 64 MB in total; the hash of the unpacked files must be the offered one, otherwise everything is thrown away; an id from the network is only used as a folder name if it is 64 capital hex digits. A joiner is told exactly the size that was offered: `Step-BundleFetch` refuses a `SIZE` line with another number before any byte is read and reads at most `SIZE` bytes.
- Test: lobby with a 6 MB bundle (a joiner with an empty cache fetched it, hash equal); zips with `evil.ps1`, `..\scenario.txt` and `sub/scenario.txt` are refused; split screen of two players where the joiner has an empty cache.

## 5. The map

After the bundle the joiner reads `mapname` from `scenario.txt` and looks whether the map is installed (name in the archive cache of their data folder, or a map from a host in the extra data folder, `Test-MapInstalled`); they say `MAPOK`. Otherwise nothing is asked:

- Same network as the host (`Test-SameLan`: the host's address is on this computer or in the subnet of a network card, link-local addresses ignored) and the host offers the map: the joiner gets it from the host over the network (**H**).
- Every other case: download from the internet (**D**, `pr-downloader --download-map`, the official map service; `MAPOK` when it ends with exit code 0). Only if that fails the lobby shows the choice D (again) or H.
- The host offers its archive only if it finds it (`Get-HostMap`: the file of the map in the archive cache of its data folder, a name of letters, digits and `._()- ` ending in `.sd7` or `.sdz`, at most 1 GB; the SHA-256 is made once when the lobby opens): `MAP <size> <sha256> <file>` after `OFFER`.
- **Official hash:** the maps of the game have no stored hash, but the file server of BAR (used by `pr-downloader`) knows MD5 and size of every official map: `GET https://files-cdn.beyondallreason.dev/find?category=map&springname=<name>` gives `[{"filename","springname","md5","size",...}]`. With **H**, `Get-OfficialMap` asks that service (timeout 6 s) before `MAPREQ`: `official` (md5, size), `unknown` (empty answer: a map of your own) or `offline`. For `official` a host file of another size is refused at once and `Complete-MapFetch` compares the MD5 of the received file as well (besides the host's SHA-256); a difference throws the file away and the lobby shows "NOT the official map ..." with the choice D. For `unknown` and `offline` only the host's SHA-256 counts and the lobby says so.
- **Fetch with H:** the joiner sends `MAPREQ`; the host does not ask anybody: if the address of the joiner's connection is in their own network (`Test-SameLan`) they answer `MAPYES`, otherwise `MAPNO`. After `MAPYES` the joiner fetches the file on a second connection (`FETCHMAP <sha256> <their name>`, only for a joiner the host has agreed to, and only that file), shows the progress (`MAPPROGRESS <percent>` to the host: "(loading the map: 45 %)"), checks the hash and puts the file with a small `.mapinfo` file (name of the map, hash) into `%LOCALAPPDATA%\BAR-Scenario\Cache\Maps\maps\`. The engine finds it there because `start_scenario.ps1` adds that folder to `SPRING_DATADIR` (the player's data folder stays untouched). The host cannot start until everybody has said `MAPOK`. Test option: `-LobbyMapKey D|H`.
- **Exact size of every transfer:** `Start-BundleFetch` gets the offered size (`OFFER`, `MAP`) as `$expect`; a host can never make the joiner take more than offered (upper limits: 1 GB map, 64 MB scenario).

## 6. Cache and faults

What hosts gave lives in `%LOCALAPPDATA%\BAR-Scenario`: `Cache\<hash>` (scenarios), `Cache\Maps\maps` (maps with `.mapinfo`), `Backup\<time>` (files an older update replaced; never deleted).

- `Use-CacheItem` marks a scenario or map as used (its time is set when the cache is hit). `Remove-OldCache` runs when the start menu starts and deletes scenarios not used for 30 days, maps not used for 60 days and, oldest first, more maps while the maps are beyond 3 GB, `.part` / `.tmp` leftovers, and zips of hosts (`bar_bundle_*.zip`) older than a day in TEMP. Start menu key 8 lists the scenarios and maps of the cache one by one ([setup and start menu](level-editor-setup.md)). The zips a host made for the joiners are deleted when their lobby closes.
- A transfer that breaks off (`Step-BundleFetch` sees the closed connection, a wrong answer, a size beyond the limit) ends with the reason shown (scenario: the joiner leaves the lobby with "refused: scenario - error: ..."; map: back to the question) and `Close-Fetch` removes the half-finished file; a failing hash, name or unpacking throws everything away. A joiner who breaks off in the middle is removed by the host (the failed write ends the transfer) and the lobby goes on.
- Not checked: a full disk; a transfer over a real network (only loopback); two computers; a joiner from outside the network.

## 7. Who plays which team (start script)

Every human gets `[playerk]` with the name and the team of their entry (the host `player0`, `Name` and `Team` replaced). A team with a human loses its `[ai]` block; a team without human keeps its AI or gets one (copy of the first AI block: `ShortName`, `Version`, `Name=<ShortName>_<team>`, a new index). `numplayers` = humans, `numusers` = humans + AIs, `hostip`, `hostport`, `GameStartDelay` = `-Wait`. The start script is written to `%TEMP%\bar_scenario_start_<name>.txt` (one file per player: games of one computer must not overwrite each other's script).

Without `-Lobby` the mapping comes from `-Mapping` or from the dialog `Get-PlayerMapping` (`player_mapping.ps1`: the lines "name -> team (side)" start from the last mapping, a line number edits that line, a team of another player is swapped, Enter starts; `Get-TeamInfo`, `ConvertTo-PlayerName` and the file of the last mapping are used by the lobby as well); the joiners must then type the names of the mapping.

## 8. Split screen

Start menu key 4, fourth entry. Asks "How many players" (2 to 8, at most the number of `[team]` blocks; `Read-PlayerCount`: Enter without digits = the maximum, Esc = back) and starts all games from `choose_map.ps1`:

- the n-1 joiners first, each a minimized `start_scenario.ps1 -Join -JoinIp 127.0.0.1 -Lobby -Name <TopRight, BottomLeft, ... (Get-SplitNames; with three or four columns Top1, Top2, ...)> -NoBuild -WaitForHost -WindowRect <cell>`, which wait up to 2 minutes until the host listens on the lobby port (`GetActiveTcpListeners`; without a lobby until a UDP listener exists on the game port),
- then the host in the foreground: `-HostGame -Lobby -Name TopLeft -HostIp 127.0.0.1 -WindowRect <cell>`.

The players are in the same lobby (the local ones joined by themselves, the host distributes the teams) and start together after "Start game". Everything stays on this computer (`hostip=127.0.0.1`, no firewall question).

**Window layout** (`Get-SplitRects`): the work area of the main screen without the task bar in real pixels (`SetProcessDPIAware`, otherwise a 150 % screen reports scaled values); up to 4 players 2 x 2 cells, up to 6 players 3 x 2, up to 8 players 4 x 2, row by row from the top left, the host first. `-WindowRect x,y,w,h` (outer size): the starter writes an own copy of the user's settings into `%TEMP%\BAR-Scenario\window_<name>.cfg` (the original `springsettings.cfg` is only read) with `Fullscreen = 0`, `WindowBorderless = 0`, size and position (window values minus an estimated frame) and `InitialNetworkTimeout = 600`, `NetworkTimeout = 600`, starts `spring.exe --config <copy>` and, as long as the window is not exactly on the rectangle (first 90 s), sets the outer rectangle with `SetWindowPos` (no activation). `-NoBuild` keeps the extra game the host built.

## 9. Findings about the engine

1. Without `hostip`, or with 127.0.0.1, in a start script the engine listens on the loopback address only ("other users will not be able to connect"); `0.0.0.0` works for the LAN; an explicit `127.0.0.1` works for the split screen.
2. The server does not wait for a player who has not connected: with `GameStartDelay=3` the game started when the host had loaded and a player who connected 20 s later was refused with "Game has already started". That is why the lobby gets everybody together first.
3. Several games loading on one computer are slow (three games: one needed 77 s) and the server dropped a game that was still loading with "timeout": hence `InitialNetworkTimeout` and `NetworkTimeout` 600 in the copy of the settings.
4. Several games can share one data folder (`--write-dir`).
5. The extra game file is locked while a game runs; the versioned game is only built when it is missing.
6. A game that connects before the host's engine listens fails after 10 s; hence `READY` / `GO`.
7. The 8 GB of video memory of the test computer were almost full with three games (four still ran).

## 10. Not checked

Two computers (firewall: TCP 8453 and UDP 8452); 5 to 8 players; three or more players with the lobby start; a joiner from outside the network who has to download the map; the keys of the lobby on the real keyboard; the flags and the income with two humans.
