# LAN Play (prototype)

A widget for the official lobby (Chobby) of Beyond All Reason. It adds the main menu entry **LAN Play** (next to Multiplayer and Skirmish) to host or join a game in the local network, without the lobby server in the cloud. The game is set up in the **official Skirmish battle room** (map, options, AIs, colours, start boxes); the widget only adds the network part. Prototype: the plain BAR game, no scenarios yet.

## Install (by hand, prototype)

1. In `data\LuaMenu\Config\IGL_data.lua` the setting `["Chili lobby"] = { loadLocalWidgets = true }` has to be there (the lobby loads widgets from `data\LuaMenu\Widgets` first; the lobby itself is not changed). Planned: an installer with its own desktop shortcut that copies the newest widget, sets this and starts the normal launcher.
2. Copy `lan_lobby.lua` to `data\LuaMenu\Widgets\`.

## How it works

- **Host a LAN game:** listens on TCP port 8453 and opens the Skirmish room (the same call as a click on the Skirmish tab). The widget redirects the Start button of that room (`localLobby:StartBattle`): the players who joined are given to it as the "friends" of the Steam coop (they get a password and play **in the host's team**), the port is 8452 and the start script's `hostip = 127.0.0.1` is changed to `0.0.0.0` so that the engine listens on the network. Then the host starts with `Spring.Reload`, as the lobby does for its own games.
- **Find LAN games:** asks the addresses `x.y.z.1 .. 254` of the own network (a /24 network is assumed) on port 8453; a found game is a button that joins it. Or type the address and press Join.
- **Join:** the client says `HELLO <name>`, sees the roster, and when the host starts it gets `START <game port> <password> <game>|<map>`. A missing map is queued in the lobby's own downloader (`WG.DownloadHandler.QueueDownload(map, "map")`); the game starts 4 s after everything is there (`IsHost=0`, `HostIP`, `MyPasswd`).

Protocol (TCP lines, port 8453): `WHO` -> `LANHOST <name>|<map>|<players>`; `HELLO <name>` -> `OK`; `ROSTER a,b,c`; `START ...`.

## What the sandbox test showed (2026-10-23)

Two sandbox instances of the real lobby on one computer (`auto=host` / `auto=join` in `lanlobby_cfg.txt` of the write dir: `auto`, `name`, `map`, `players`, `ip`): the entry was added to the menu, the joiner found the host by the scan, joined, the host opened the Skirmish room, chose the map, and "pressed Start" with the call of the Start button. The official room produced the script (game `Beyond All Reason test-31691-a617033`, Hooked 1.1, Jonas as a player with the password in the host's team, `hostip = 0.0.0.0`, port 8452); both engines loaded the game and the host log has "Player Jonas finished loading and is now ingame".

Sockets of the lobby: TCP listen and connect to any address are allowed, UDP receive too, **UDP send is refused** (`UDPAllowConnect` is empty; `Spring.SetConfigString` at run time does not change it). So TCP only.

## Not done / not tested

- Clicking (the test calls the same functions): the tab, the buttons and how the entry looks. Screenshots of the OpenGL window come out black here, so nothing was looked at.
- Two computers. Scenarios, own maps, version check, update.
- The entry sits right after Multiplayer (the first entry of the singleplayer list), not above it.
- Humans against humans: the room's friend mechanism puts everybody into the host's team (coop against AIs).
- The map download of a client (`QueueDownload`) was not tried.
- In the sandbox `RapidTagResolutionOrder` has to be in the springsettings (the launcher sets it in the real install).
