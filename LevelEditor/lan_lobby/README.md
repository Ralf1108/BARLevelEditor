# LAN Lobby (prototype)

A widget for the official lobby (Chobby) of Beyond All Reason. It adds a small **LAN** button (top left) with a window to host or join a game in the local network, without the lobby server in the cloud. Prototype: plain BAR game and a map, no scenarios yet.

## Install (by hand, prototype)

1. In `data\LuaMenu\Config\IGL_data.lua` the setting `["Chili lobby"] = { loadLocalWidgets = true }` has to be there (the lobby loads widgets from `data\LuaMenu\Widgets` first; the lobby itself is not changed).
2. Copy `lan_lobby.lua` to `data\LuaMenu\Widgets\`.

## Use

- **Host LAN game:** name and map in the window, then the button. The widget listens on TCP port 18460.
- **Find games:** asks the addresses `x.y.z.1 .. 254` of the own network (a /24 network is assumed) on port 18460; a found game is a button that joins it. Or type the address and press Join.
- **Start the game:** (host) with at least two players. The host starts the engine with a start script (`HostIP=0.0.0.0`, port 8452), the joiners start theirs 4 s later (`IsHost=0`). Both use `Spring.Reload`, the same call the lobby uses for its own games.

## Protocol (TCP lines)

`WHO` -> `LANHOST <name>|<map>|<players>` (discovery); `HELLO <name>` -> `OK <map>|<game>`; `ROSTER a,b,c` (to all); `START <game port> <password>`.

## What the sandbox test showed (2026-10-23)

Two sandbox instances of the real lobby on one computer, host with `auto=host`, joiner with `auto=join` (file `lanlobby_cfg.txt` in the write dir: `auto`, `name`, `map`, `game`, `players`, `ip`): the joiner found the host by the scan (127.0.0.1 and the LAN address), joined, the host started, both engines loaded Hooked 1.1 with the game and the host log says "Player Jonas finished loading and is now ingame" and the same for the host.

Facts about the lobby's sockets (same test): TCP listen and connect to any address are allowed (`TCPAllowConnect = *`, `TCPAllowListen = *`), UDP receive is allowed, **UDP send is refused** (`UDPAllowConnect` is empty) unless `springsettings.cfg` has `UDPAllowConnect = *`; the widget cannot change that at run time. So the prototype uses TCP only.

## Not done / not tested

- Clicking the buttons (only the same functions through the test file).
- Two computers (both were on the same computer).
- Scenarios, own maps, version check, update: the prototype starts the plain game.
- A /24 network is assumed for the scan; the lobby cannot ask the operating system for the netmask.
