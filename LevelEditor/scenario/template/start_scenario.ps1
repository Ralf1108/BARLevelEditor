# Starts a scenario with the official Beyond All Reason (nothing in the game is changed).
# Run through "Start Scenario.bat" in the same folder. The file scenario.txt is the finished start script
# with two placeholders (__GAMETYPE__ = installed game version, __PLAYERNAME__ = player name).
# Several players in the same network (LAN): -HostGame [-Players n] hosts the game (the other players use -JoinIp <address> and the name the
# host shows), -Port is the UDP port of the host (default 8452), -Wait the seconds the others have to join after the host has loaded (default 90).
# Without -JoinIp the join mode (Join Game.bat passes -Join) asks for the address.
# Split screen (start menu of the Level Editor, several games on one computer): -WindowRect x,y,w,h starts the game in a framed window on this
# rectangle of the screen (outer size, pixels) instead of the settings of the user (which are only read, never changed); -HostIp 127.0.0.1 lets
# the host listen on this computer only; -NoBuild has no effect any more (the extra game is only built when it is missing); -WaitForHost
# waits (up to 2 minutes) until a host listens on the port before the game is started.
# From the start menu of the Level Editor this script runs from the editor's own folder (scenario\template) with -ScenarioDir <folder of the scenario:
# scenario.txt> and -EditorDir <the LevelEditor folder>: the gadgets (td_waves, ctf_game, rtf_game, unit_restrictions ... in scripts\, bar_rules in
# ..\shared), the starter, the lobby and the briefing are always the current ones of the editor, so a scenario built earlier is never out of date. Started
# from the unpacked package of a scenario (Start Scenario.bat) both are empty: everything comes from the package folder.
# -Bundle (start menu key 6, "Play a level"): the scenario is a bundle in the cache (%LOCALAPPDATA%\BAR-Scenario\Cache\<hash>: scenario.txt and the gadgets, made from a
# level by scenario_builder.ps1 -BundleDir and put there by Install-Bundle): the host gives -ScenarioDir <that folder>, a joiner gives no -ScenarioDir (he gets the
# scenario through the lobby, as in every hosted game). Needs -EditorDir (starter, lobby and gadgets are the editor's own).
# -LobbyMapKey D or H (tests, automation): a joiner without the map takes this answer at once (D = download it, H = get it from the host).
# The map of a hosted game: a joiner in the same network as the host gets it from the host, everybody else downloads it from the internet (nothing is asked).
# In a hosted game with the lobby everybody plays the host's game: the host offers a bundle (scenario.txt and the Lua files of his extra game) and the
# joiners build their extra game from it. Only the lobby version (lobby.ps1) must be the same; another one is refused ("update the Level Editor manually").
# Lobby (-Lobby with -HostGame or -Join): before anything is built the host sees a box per team and distributes the players who joined (TCP port
# -LobbyPort, default 8453); a joiner only sends his name. When the host starts, everybody prepares (extra game, map), the host's game starts and
# the joiners connect to it (lobby.ps1). -LobbyAutoStart n: the host starts by itself when n players are in (tests, automation). Hosting without -Lobby: who plays which team is asked (player_mapping.ps1; the last one used is offered), or given as -Mapping "PlayerA=0,Anna=2" (first = host).
param([string]$BarPath = $null, [string]$Name = $null, [switch]$ScriptOnly, [switch]$HostGame, [switch]$Join,[int]$Players = 0, [string]$JoinIp = $null, [int]$Port = 8452, [int]$Wait = 90, [string]$WindowRect = $null, [string]$HostIp = '0.0.0.0', [switch]$NoBuild, [switch]$WaitForHost, [string]$Mapping = $null, [switch]$Lobby, [int]$LobbyPort = 8453, [int]$LobbyAutoStart = 0, [string]$ScenarioDir = $null, [string]$EditorDir = $null, [switch]$Bundle, [string]$LobbyMapKey = $null)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$here = $PSScriptRoot
$pkg = if ($ScenarioDir) { $ScenarioDir } else { $here }   # the folder of the scenario (scenario.txt; in a package also the Lua files of the extra game)
. (Join-Path $here 'player_mapping.ps1')
. (Join-Path $here 'lobby.ps1')

# the shared search of BAR, the engine and the game version (shared\bar_common.ps1): next to this script in a package, in the editor in ..\..\..\shared
$common = Join-Path $here 'bar_common.ps1'
if (-not (Test-Path $common)) { $common = Join-Path (Split-Path (Split-Path (Split-Path $here -Parent) -Parent) -Parent) 'shared\bar_common.ps1' }
if (-not (Test-Path $common)) { Write-Host "ERROR: bar_common.ps1 is missing (it belongs next to start_scenario.ps1)." -ForegroundColor Red; Read-Host 'Press Enter to exit'; exit 1 }
. $common
function Fail($t) { Write-Host ""; Write-Host "ERROR: $t" -ForegroundColor Red; Read-Host 'Press Enter to exit'; exit 1 }

# ---------------------------------------------------------------- Find BAR, the engine and the installed game version
$memo = if ($Bundle) { Join-Path $env:LOCALAPPDATA 'BAR-Scenario\bar_path.txt' } else { Join-Path $pkg 'bar_path.txt' }   # (a bundle in the cache holds data only)
$bar = Find-Bar @($BarPath) $memo
$data = Join-Path $bar 'data'
$engineDir = Get-Engine $data
$game = Get-GameVersion $data

# ---------------------------------------------------------------- Fill the start script
$script = ''   # (a joiner with -Bundle gets the scenario through the lobby, see below)
if (-not ($Bundle -and -not $ScenarioDir)) { $script = [IO.File]::ReadAllText((Join-Path $pkg 'scenario.txt')) }
$map = [regex]::Match($script, '(?m)^\s*mapname\s*=\s*(.+?);').Groups[1].Value.Trim()
if ($Join -and -not $JoinIp) {
    # the last 10 addresses are kept for every scenario of this user (not in the scenario folder): pick one by its number or type a new one
    $addrFile = Join-Path $env:LOCALAPPDATA 'BAR-Scenario\Last Joined Addresses.txt'
    $recent = @()
    if (Test-Path $addrFile) { $recent = @(Get-Content $addrFile | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -First 10) }
    $JoinIp = $null
    if ($recent.Count -gt 0) {
        Write-Host 'Recent addresses:'
        for ($i = 0; $i -lt $recent.Count; $i++) { Write-Host ("  {0}) {1}" -f ($i + 1), $recent[$i]) }
        $in = (Read-Host "Number of an address, or a new address (shown in the host window, e.g. 192.168.1.20); Enter = 1").Trim()
        if (-not $in) { $in = '1' }
        $n = 0
        if ([int]::TryParse($in, [ref]$n) -and $n -ge 1 -and $n -le $recent.Count) { $JoinIp = $recent[$n - 1] } else { $JoinIp = $in }
    } else {
        $JoinIp = (Read-Host 'Address of the host (shown in the host window, e.g. 192.168.1.20)').Trim()
    }
    if (-not $JoinIp) { Fail 'Aborted.' }
    New-Item -ItemType Directory -Force (Split-Path $addrFile) | Out-Null
    Set-Content -Path $addrFile -Value (@($JoinIp) + @($recent | Where-Object { $_ -ne $JoinIp }) | Select-Object -First 10) -Encoding ASCII
    # the name has to be the one the host gave this player; the last one used is offered
    $nameFile = Join-Path $env:LOCALAPPDATA 'BAR-Scenario\Last Player Name.txt'
    $lastName = ConvertTo-PlayerName $env:USERNAME
    if (-not $lastName) { $lastName = 'Player2' }
    if (Test-Path $nameFile) { $ln = ([IO.File]::ReadAllText($nameFile)).Trim(); if ($ln) { $lastName = $ln } }
    $in = (Read-Host "Your name (Enter = $lastName)").Trim()
    $Name = if ($in) { $in } else { $lastName }
    Set-Content -Path $nameFile -Value $Name -Encoding ASCII
}
if (-not $Name) { $Name = $env:USERNAME }
if (-not $Name) { $Name = 'Player' }
$Name = $Name -replace '[^A-Za-z0-9_\-\[\]]', ''
if (-not $Name) { $Name = 'Player' }
# Joiners of a Split screen start before the host: they wait until the host listens (the lobby port, or the game port without a lobby)
if ($WaitForHost) {
    $what = if ($Lobby) { "lobby port $LobbyPort" } else { "port $Port" }
    Write-Host "Waiting for the host on $what ..."
    $until = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $until) {
        $ip = [Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties()
        $listeners = if ($Lobby) { @($ip.GetActiveTcpListeners() | Where-Object { $_.Port -eq $LobbyPort }) } else { @($ip.GetActiveUdpListeners() | Where-Object { $_.Port -eq $Port }) }
        if ($listeners.Count -gt 0) { break }
        Start-Sleep -Milliseconds 500
    }
}
# The files of the extra game of the scenarios (see below): the current ones of the editor (-EditorDir) or the ones of the package; a joiner of a
# lobby takes the host's (the bundle)
$gameDirs = if ($EditorDir) { @((Join-Path $EditorDir 'scripts'), (Join-Path (Split-Path $EditorDir -Parent) 'shared'), $here) } else { @($pkg) }
# The lobby, before the extra game is built and the map is fetched (lobby.ps1). The host distributes the players; when he starts, the script goes on
# with the roster as -Mapping (the host builds the game and starts it, the joiners prepare and wait for GO)
if ($Lobby -and ($HostGame -or $JoinIp)) {
    if ($HostGame) {
        $teamInfo = @(Get-TeamInfo $script)
        if ($teamInfo.Count -lt 2) { Fail 'This scenario has only one team, there is nobody to play against.' }
        # the scenario and the Lua files of the game this computer runs ($gameDirs) go to the joiners: everybody plays the host's game
        $hostBundle = New-HostBundle $pkg $gameDirs
        $hostBundle.Map = Get-HostMap $data $map   # the map archive, for a joiner who has not got the map (he has to ask and the host has to agree)
        if (-not $hostBundle.Map) { Write-Host "Note: the archive of the map '$map' was not found, a joiner without the map has to download it from the internet." -ForegroundColor Yellow }
        $gameDirs = @($hostBundle.Dir)
        $lobbyRoster = Invoke-HostLobby $teamInfo $Name $LobbyPort $null $null 0 $LobbyAutoStart $hostBundle
        if (-not $lobbyRoster) { Write-Host 'The lobby was cancelled.'; exit 0 }
        Save-Mapping $lobbyRoster
        $Mapping = ConvertTo-MappingText $lobbyRoster
        if (-not $PSBoundParameters.ContainsKey('Wait')) { $Wait = 15 }   # everybody is known: the joiners connect at once
        Write-Host "Lobby finished: $Mapping"
    } else {
        $res = Join-Lobby $JoinIp $LobbyPort $Name 0 $null @{ Data = $data; Downloader = (Join-Path $engineDir.FullName 'pr-downloader.exe'); Auto = $LobbyMapKey }
        switch -Wildcard ($res) {
            'noconnect' { Fail "No lobby of a host found at $($JoinIp):$LobbyPort." }
            'refused*'  { Fail "The host refused you: $($res.Substring(9))" }
            'cancel'    { Write-Host 'The host cancelled the lobby.'; exit 0 }
            'lost'      { Write-Host 'The connection to the host was lost.'; exit 0 }
            'left'      { exit 0 }
        }
        $Name = $script:JoinerName
        # the scenario and the Lua files the host gave through the lobby (in the cache): this computer plays exactly the host's game
        if (-not $script:BundleDir) { Fail 'The host did not give a scenario.' }
        $pkg = $script:BundleDir
        $gameDirs = @($pkg)
        $script = [IO.File]::ReadAllText((Join-Path $pkg 'scenario.txt'))
        $map = [regex]::Match($script, '(?m)^\s*mapname\s*=\s*(.+?);').Groups[1].Value.Trim()
        Write-Host 'The host started the game. Getting ready ...'
    }
}
# The extra game of the scenarios ("Level Editor Scenarios <version>", Write-ScenarioGame in bar_common.ps1): the gadgets of all game modes, the
# restrictions and the indestructible buildings, built on the installed official game (nothing of the official game is changed). Its files: the
# current ones of the editor (-EditorDir: scripts\ and ..\shared, so a scenario built earlier never runs outdated code) or the ones of the package.
# The version comes from the files: the editor's setup has built the same game already, so normally nothing is built here.
$scGame = Write-ScenarioGame $data $game $gameDirs
$gametype = $scGame.Name
$script = $script.Replace('__GAMETYPE__', $gametype)
if ($HostGame) {
    # Every human gets the team the mapping says (player_mapping.ps1: name = team, the first is the host); a team with a human loses its computer
    # opponent, a team without one keeps (or gets) one
    $script = $script.Replace("`r`n", "`n")
    $teamInfo = @(Get-TeamInfo $script)
    $teams = $teamInfo.Count
    if ($teams -lt 2) { Fail 'This scenario has only one team, there is nobody to play against.' }
    if ($Mapping) {
        $roster = @(ConvertFrom-MappingText $Mapping)
        foreach ($e in $roster) { if ($e.Team -ge $teams) { Fail "Team $($e.Team) of the mapping does not exist (the scenario has the teams 0 to $($teams - 1))." } }
    } else {
        if ($Players -lt 2) {
            $in = Read-Host "How many human players (2 to $teams, you are one of them)"
            if (-not [int]::TryParse($in, [ref]$Players)) { $Players = 2 }
        }
        $Players = [Math]::Max(2, [Math]::Min($teams, $Players))
        $roster = @(Get-PlayerMapping $Players $teamInfo $Name)
    }
    $Players = $roster.Count
    $Name = $roster[0].Name
    $aiPat = "(?s)\t\[ai\d+\]\s*\{{[^}}]*\bTeam={0};[^}}]*\}}\n"
    $tpl = [regex]::Match($script, '(?s)\t\[ai\d+\]\s*\{[^}]*\}\n').Value
    $aiName = [regex]::Match($tpl, '(?i)ShortName=([^;]*);').Groups[1].Value; if (-not $aiName) { $aiName = 'NullAI' }
    $aiVer = [regex]::Match($tpl, '(?i)Version=([^;]*);').Groups[1].Value; if (-not $aiVer) { $aiVer = '0.1' }
    foreach ($e in $roster) { $script = [regex]::Replace($script, ($aiPat -f $e.Team), '') }
    $aiId = 0 + (@([regex]::Matches($script, '(?m)^\t\[ai(\d+)\]') | ForEach-Object { [int]$_.Groups[1].Value }) | Measure-Object -Maximum).Maximum + 1
    $addAi = New-Object Text.StringBuilder
    for ($tm = 0; $tm -lt $teams; $tm++) {
        if (@($roster | Where-Object { $_.Team -eq $tm }).Count -gt 0) { continue }
        if ([regex]::IsMatch($script, ($aiPat -f $tm))) { continue }
        [void]$addAi.Append("`t[ai$aiId]`n`t{`n`t`tShortName=$aiName;`n`t`tName=${aiName}_$tm;`n`t`tTeam=$tm;`n`t`tHost=0;`n`t`tVersion=$aiVer;`n`t}`n")
        $aiId++
    }
    $script = [regex]::Replace($script, '(?s)(\[player0\]\s*\{[^}]*?\bTeam=)\d+;', ('${1}' + $roster[0].Team + ';'))
    $extra = New-Object Text.StringBuilder
    for ($k = 1; $k -lt $Players; $k++) {
        [void]$extra.Append("`t[player$k]`n`t{`n`t`tName=$($roster[$k].Name);`n`t`tTeam=$($roster[$k].Team);`n`t`tspectator=0;`n`t`trank=0;`n`t}`n")
    }
    $script = $script.Replace("`t[player0]", $addAi.ToString() + "`t[player0]")
    $script = $script.Replace("`t[modoptions]", $extra.ToString() + "`t[modoptions]")
    $ais = ([regex]::Matches($script, '(?m)^\t\[ai\d+\]')).Count
    # hostip 0.0.0.0 = listen on all network cards, 127.0.0.1 = this computer only (without a value the engine listens on the loopback address only)
    $script = $script.Replace('hostip=127.0.0.1;', "hostip=$HostIp;").Replace('hostport=0;', "hostport=$Port;")
    # The game starts GameStartDelay seconds after the host has loaded; whoever connects later is refused ("Game has already started"), so this
    # is the time the others have to start "Join Game.bat" (found in the test of 2026-10-22: with 3 seconds a player who joined after 25 s was refused)
    $script = [regex]::Replace($script, 'GameStartDelay=\d+;', "GameStartDelay=$Wait;")
    $script = [regex]::Replace($script, 'numplayers=\d+;', "numplayers=$Players;")
    $script = [regex]::Replace($script, 'numusers=\d+;', "numusers=$($Players + $ais);")
}
$script = $script.Replace('__PLAYERNAME__', $Name)
$out = Join-Path $env:TEMP ('bar_scenario_start_' + $Name + '.txt') # one file per player: several games of one computer must not overwrite each other's script
[IO.File]::WriteAllText($out, $script, (New-Object Text.UTF8Encoding($false)))
Write-Host "Game: $game"
Write-Host "Map: $map"
if ($ScriptOnly) { Write-Host "Start script: $out"; exit 0 }

# ---------------------------------------------------------------- Check the map, otherwise download it
$cache = Get-ChildItem (Join-Path $data 'cache') -Filter 'ArchiveCache*.lua' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
$have = $false
if ($cache) { $have = ([IO.File]::ReadAllText($cache.FullName)).Contains('name = "' + $map + '"') }
if (-not $have) { $have = Test-MapExtra $map }   # a map that a host sent (in the extra data folder of the cache)
if (-not $have) {
    Write-Host ''
    Write-Host "This scenario needs the map '$map'. It is not installed on this computer yet." -ForegroundColor Yellow
    Write-Host 'It has to be downloaded from the internet (the official BAR map service, can take a few minutes).'
    if (-not (Read-Yes 'Download the map now and start the scenario? (y/n)')) { Fail 'Aborted. The scenario cannot start without the map.' }
    Write-Host 'Downloading the map ...'
    $dl = Join-Path $engineDir.FullName 'pr-downloader.exe'
    if (-not (Test-Path $dl)) { Fail 'The map downloader (pr-downloader.exe) was not found. Please start BAR once and install the map there.' }
    & $dl --filesystem-writepath $data --download-map $map
}

# The briefing window and the start of a Copilot game are game widgets of the extra game now. Older starters copied them into the user widgets of
# BAR (data\LuaUI\Widgets), where they were loaded in every game: those copies go. shared_start.lua stays where LAN Play is installed (its setup
# puts it there for the Copilot games on official maps).
$wdir = Join-Path $data 'LuaUI\Widgets'
Remove-Item (Join-Path $wdir 'scenario_briefing.lua') -Force -ErrorAction SilentlyContinue
if (-not (Test-Path (Join-Path $data 'LuaMenu\Widgets\lan_lobby.lua'))) { Remove-Item (Join-Path $wdir 'shared_start.lua') -Force -ErrorAction SilentlyContinue }

$spring = Join-Path $engineDir.FullName 'spring.exe'
# maps that a host sent are in an extra data folder of the cache (the engine reads maps\ of every folder of SPRING_DATADIR; the folder of the player stays as it is)
$mapsExtra = Get-MapExtraRoot
if (Test-Path (Join-Path $mapsExtra 'maps')) { $env:SPRING_DATADIR = (@($env:SPRING_DATADIR, $mapsExtra) | Where-Object { $_ }) -join ';' }

# Runs the game; with -WindowRect in a framed window on that rectangle: an own copy of the settings of the user (the original is only read)
# with the window values replaced, and after the window has appeared its outer rectangle is set exactly (the frame is part of it)
function Start-Spring([string[]]$sargs, [scriptblock]$afterLaunch = $null) {
    if (-not $WindowRect -and -not $afterLaunch) { & $spring @sargs; return }
    if (-not $WindowRect) {
        $p = Start-Process -FilePath $spring -ArgumentList @($sargs | ForEach-Object { '"' + $_ + '"' }) -PassThru
        & $afterLaunch
        $p.WaitForExit()
        return
    }
    $r = @($WindowRect.Split(',') | ForEach-Object { [int]$_.Trim() })
    if ($r.Count -ne 4) { Fail "-WindowRect needs x,y,w,h (got '$WindowRect')." }
    $mine = @('Fullscreen', 'WindowBorderless', 'XResolution', 'YResolution', 'XResolutionWindowed', 'YResolutionWindowed', 'WindowPosX', 'WindowPosY', 'InitialNetworkTimeout', 'NetworkTimeout')
    $src = Join-Path $data 'springsettings.cfg'
    $lines = @()
    if (Test-Path $src) { $lines = @(Get-Content $src | Where-Object { $l = $_; -not ($mine | Where-Object { $l -match ('^\s*' + $_ + '\s*=') }) }) }
    $lines += @('Fullscreen = 0', 'WindowBorderless = 0', "XResolutionWindowed = $($r[2] - 16)", "YResolutionWindowed = $($r[3] - 47)", "XResolution = $($r[2] - 16)", "YResolution = $($r[3] - 47)", "WindowPosX = $($r[0])", "WindowPosY = $($r[1])",
               'InitialNetworkTimeout = 600', 'NetworkTimeout = 600') # several games loading at once on one computer are slow: the server must not drop a game that is still loading
    $cfgDir = Join-Path $env:TEMP 'BAR-Scenario'
    New-Item -ItemType Directory -Force $cfgDir | Out-Null
    $cfg = Join-Path $cfgDir ("window_$Name.cfg")
    [IO.File]::WriteAllLines($cfg, $lines)
    Add-Type @'
using System;
using System.Runtime.InteropServices;
public class SplitWin {
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
}
'@
    [void][SplitWin]::SetProcessDPIAware()
    $all = @('--config', $cfg) + $sargs   # every caller passes --write-dir itself
    $p = Start-Process -FilePath $spring -ArgumentList @($all | ForEach-Object { '"' + $_ + '"' }) -PassThru
    $start = Get-Date
    $launched = $false
    while (-not $p.HasExited) {
        if ($afterLaunch -and -not $launched) { $launched = $true; & $afterLaunch }
        $p.Refresh()
        if ($p.MainWindowHandle -ne [IntPtr]::Zero -and ((Get-Date) - $start).TotalSeconds -lt 90) {
            $cur = New-Object SplitWin+RECT
            [void][SplitWin]::GetWindowRect($p.MainWindowHandle, [ref]$cur)
            if ($cur.L -ne $r[0] -or $cur.T -ne $r[1] -or ($cur.R - $cur.L) -ne $r[2] -or ($cur.B - $cur.T) -ne $r[3]) {
                [void][SplitWin]::SetWindowPos($p.MainWindowHandle, [IntPtr]::Zero, $r[0], $r[1], $r[2], $r[3], 0x0014) # no z-order change, no activation
            }
        }
        Start-Sleep -Milliseconds 500
    }
}
if ($JoinIp) {
    if ($Lobby) {
        # the extra game and the map are ready: tell the host and wait until his game is running
        Write-Host 'Ready. Waiting for the host to start his game ...'
        $go = Wait-JoinerGo 300
        if ($go -ne 'go') { Write-Host "The game was not started ($go)." -ForegroundColor Yellow; exit 0 }
    }
    Write-Host "Joining $($JoinIp):$Port as '$Name' ..."
    Start-Spring @('--write-dir', $data, "spring://$Name@$($JoinIp):$Port")
    exit 0
}
if ($HostGame -and -not $Lobby) {
    $addr = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | ForEach-Object { $_.IPAddress })
    Write-Host ''
    Write-Host "You host this game as '$Name' (team $($roster[0].Team)) on UDP port $Port. The other players start ""Join Game.bat"" and enter:" -ForegroundColor Cyan
    Write-Host "  address: $($addr -join ' or ')" -ForegroundColor Cyan
    for ($k = 1; $k -lt $Players; $k++) { Write-Host "  name $($roster[$k].Name) (team $($roster[$k].Team))" -ForegroundColor Cyan }
    Write-Host "The game loads for you first; the others have about $Wait seconds after that to start ""Join Game.bat"" (a countdown runs in the game)." -ForegroundColor Cyan
    Write-Host 'If Windows asks about the firewall: allow spring.exe in the private network.'
}
if ($HostGame -and $Lobby) {
    # every joiner has the extra game and the map: start the game, give the engine a moment to listen, then let the joiners connect
    if (-not (Wait-LobbyReady 300)) { Close-Lobby; Fail 'The game was not started: not everybody got ready.' }
    Write-Host 'Starting the game ...'
    Start-Spring @('--write-dir', $data, $out) { Start-Sleep -Seconds 5; Send-LobbyGo }
    Close-Lobby
    exit 0
}
Write-Host 'Starting the game ...'
# without --write-dir the engine uses its own folder as data folder (found 2026-10-23: "Dependent archive ... not found" for a map that was just downloaded)
Start-Spring @('--write-dir', $data, $out)
