# Starts a scenario with the official Beyond All Reason (nothing in the game is changed).
# Run through "Start Scenario.bat" in the same folder. The file scenario.txt is the finished start script
# with two placeholders (__GAMETYPE__ = installed game version, __PLAYERNAME__ = player name).
# Several players in the same network (LAN): -HostGame [-Players n] hosts the game (the other players use -JoinIp <address> and the name the
# host shows), -Port is the UDP port of the host (default 8452), -Wait the seconds the others have to join after the host has loaded (default 90).
# Without -JoinIp the join mode (Join Game.bat passes -Join) asks for the address.
# Split screen (start menu of the Level Editor, several games on one computer): -WindowRect x,y,w,h starts the game in a framed window on this
# rectangle of the screen (outer size, pixels) instead of the settings of the user (which are only read, never changed); -HostIp 127.0.0.1 lets
# the host listen on this computer only; -NoBuild keeps the extra game that the host has built (it is locked while a game runs); -WaitForHost
# waits (up to 2 minutes) until a host listens on the port before the game is started.
# From the start menu of the Level Editor this script runs from the editor's own folder (scenario\template) with -ScenarioDir <folder of the scenario:
# scenario.txt, which gadgets it needs> and -EditorDir <the LevelEditor folder>: the gadgets (td_waves, ctf_game, unit_restrictions in scripts\, bar_rules in
# ..\shared), the starter, the lobby and the briefing are always the current ones of the editor, so a scenario built earlier is never out of date. Started
# from the unpacked package of a scenario (Start Scenario.bat) both are empty: everything comes from the package folder.
# Lobby (-Lobby with -HostGame or -Join): before anything is built the host sees a box per team and distributes the players who joined (TCP port
# -LobbyPort, default 8453); a joiner only sends his name. When the host starts, everybody prepares (extra game, map), the host's game starts and
# the joiners connect to it (lobby.ps1). -LobbyAutoStart n: the host starts by itself when n players are in (tests, automation). Hosting without -Lobby: who plays which team is asked (player_mapping.ps1; the last one used is offered), or given as -Mapping "Ralf=0,Anna=2" (first = host).
param([string]$BarPath = $null, [string]$Name = $null, [switch]$ScriptOnly, [switch]$HostGame, [switch]$Join,[int]$Players = 0, [string]$JoinIp = $null, [int]$Port = 8452, [int]$Wait = 90, [string]$WindowRect = $null, [string]$HostIp = '0.0.0.0', [switch]$NoBuild, [switch]$WaitForHost, [string]$Mapping = $null, [switch]$Lobby, [int]$LobbyPort = 8453, [int]$LobbyAutoStart = 0, [string]$ScenarioDir = $null, [string]$EditorDir = $null)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$here = $PSScriptRoot
$pkg = if ($ScenarioDir) { $ScenarioDir } else { $here }   # the folder of the scenario (scenario.txt, which gadgets are needed)
. (Join-Path $here 'player_mapping.ps1')
. (Join-Path $here 'lobby.ps1')

function Fail($t) { Write-Host ""; Write-Host "ERROR: $t" -ForegroundColor Red; Read-Host 'Press Enter to exit'; exit 1 }

# ---------------------------------------------------------------- Find BAR
# (the same search as Find-Bar, Get-Engine and Get-GameVersion in shared\bar_common.ps1; this script runs alone on the recipient's computer, so it
# carries its own copy: change both together)
$memo = Join-Path $pkg 'bar_path.txt'
$candidates = @()
if ($BarPath) { $candidates += $BarPath }
if (Test-Path $memo) { $candidates += ([IO.File]::ReadAllText($memo)).Trim() }
$candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason')
foreach ($drive in [IO.DriveInfo]::GetDrives()) {
    if ($drive.DriveType -ne 'Fixed' -or -not $drive.IsReady) { continue }
    foreach ($par in @('Games', 'Spiele', 'Program Files', 'Program Files (x86)', 'Programme', '')) {
        foreach ($n in @('Beyond-All-Reason', 'Beyond All Reason', 'BeyondAllReason')) {
            $candidates += (Join-Path (Join-Path $drive.RootDirectory.FullName $par) $n)
        }
    }
}
$bar = $null
foreach ($c in $candidates) { if ($c -and (Test-Path (Join-Path $c 'data\engine'))) { $bar = $c; break } }
while (-not $bar) {
    $in = Read-Host 'Beyond All Reason not found. Enter the installation folder (Beyond-All-Reason.exe is in it)'
    if (-not $in) { Fail 'Aborted.' }
    if (Test-Path (Join-Path $in 'data\engine')) { $bar = $in } else { Write-Host 'There is no data\engine folder there.' }
}
[IO.File]::WriteAllText($memo, $bar)
$data = Join-Path $bar 'data'

# ---------------------------------------------------------------- Engine
$engineDir = Get-ChildItem (Join-Path $data 'engine') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'spring.exe') } | Sort-Object Name | Select-Object -Last 1
if (-not $engineDir) { Fail 'No engine found in data\engine. Please start BAR once so the launcher installs it.' }

# ---------------------------------------------------------------- installed game version
$versionsFile = Join-Path $data 'rapid\repos-cdn.beyondallreason.dev\byar\versions.gz'
if (-not (Test-Path $versionsFile)) { Fail 'No game data found. Please start BAR once and let a game load.' }
$fs = [IO.File]::OpenRead($versionsFile)
$gz = New-Object IO.Compression.GZipStream($fs, [IO.Compression.CompressionMode]::Decompress)
$sr = New-Object IO.StreamReader($gz)
$text = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
$game = $null; $fallback = $null
foreach ($tag in @('byar:test', 'byar:stable')) {
    foreach ($line in ($text -split "`n")) {
        if ($line.StartsWith($tag + ',')) {
            $f = $line.Trim().Split(',')
            if (-not $fallback) { $fallback = $f[3] }
            if (-not $game -and (Test-Path (Join-Path $data ("packages\" + $f[1] + '.sdp')))) { $game = $f[3] }
        }
    }
}
if (-not $game) { $game = $fallback }
if (-not $game) { Fail 'Game version not found.' }

# ---------------------------------------------------------------- Fill the start script
$script = [IO.File]::ReadAllText((Join-Path $pkg 'scenario.txt'))
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
# The lobby, before the extra game is built and the map is fetched (lobby.ps1). The host distributes the players; when he starts, the script goes on
# with the roster as -Mapping (the host builds the game and starts it, the joiners prepare and wait for GO)
if ($Lobby -and ($HostGame -or $JoinIp)) {
    # the version of the files that decide how the game runs: the editor's (scripts, scenario\template, shared) or the package's
    $playVersion = Get-PlayVersion $(if ($EditorDir) { @((Join-Path $EditorDir 'scripts'), (Join-Path $EditorDir 'scenario\template'), (Join-Path (Split-Path $EditorDir -Parent) 'shared')) } else { @($here) })
    if ($HostGame) {
        $teamInfo = @(Get-TeamInfo $script)
        if ($teamInfo.Count -lt 2) { Fail 'This scenario has only one team, there is nobody to play against.' }
        $lobbyRoster = Invoke-HostLobby $teamInfo $Name $LobbyPort $null $null 0 $LobbyAutoStart $playVersion
        if (-not $lobbyRoster) { Write-Host 'The lobby was cancelled.'; exit 0 }
        Save-Mapping $lobbyRoster
        $Mapping = ConvertTo-MappingText $lobbyRoster
        if (-not $PSBoundParameters.ContainsKey('Wait')) { $Wait = 15 }   # everybody is known: the joiners connect at once
        Write-Host "Lobby finished: $Mapping"
    } else {
        $res = Join-Lobby $JoinIp $LobbyPort $Name 0 $null $playVersion
        switch -Wildcard ($res) {
            'noconnect' { Fail "No lobby of a host found at $($JoinIp):$LobbyPort." }
            'refused*'  { Fail "The host refused you: $($res.Substring(9))" }
            'cancel'    { Write-Host 'The host cancelled the lobby.'; exit 0 }
            'lost'      { Write-Host 'The connection to the host was lost.'; exit 0 }
            'left'      { exit 0 }
        }
        $Name = $script:JoinerName
        Write-Host 'The host started the game. Getting ready ...'
    }
}
# Tower Defense, Capture the Flag and restricted scenarios: the waves run in a gadget (td_waves.lua), the flags in another
# (ctf_game.lua), the restrictions in a third (unit_restrictions.lua). The
# official game cannot load them, so a small extra game "Tower Defense Scenario" is built on the installed official game (only the gadgets are
# added; nothing of the official game is changed).
$gametype = $game
# which gadgets the scenario needs: the ones its package holds; their text: the current one of the editor (-EditorDir) or the one of the package
$tdNeeded = Test-Path (Join-Path $pkg 'td_waves.lua')
$ctfNeeded = Test-Path (Join-Path $pkg 'ctf_game.lua')
$rstNeeded = Test-Path (Join-Path $pkg 'unit_restrictions.lua')
$gadgetDir = if ($EditorDir) { Join-Path $EditorDir 'scripts' } else { $pkg }
$tdGadget = Join-Path $gadgetDir 'td_waves.lua'
$ctfGadget = Join-Path $gadgetDir 'ctf_game.lua'
$rstGadget = Join-Path $gadgetDir 'unit_restrictions.lua'
$lootStub = Join-Path $gadgetDir 'pve_supply_drops_stub.lua'   # Capture the Flag: replaces the lootbox gadget of the game (it let enemies capture the flags)
if ($tdNeeded -or $ctfNeeded -or $rstNeeded) {
    $gamesDir = Join-Path $data 'games'
    New-Item -ItemType Directory -Force $gamesDir | Out-Null
    $zipPath = Join-Path $gamesDir 'TowerDefenseScenario.sdz'
    $build = -not ($NoBuild -and (Test-Path $zipPath))
    if ($build -and (Test-Path $zipPath)) { Remove-Item $zipPath -Force }
    $modinfo = @"
return {
	name = "Tower Defense Scenario",
	shortName = "TDScn",
	version = "1",
	game = "TowerDefenseScenario",
	shortGame = "TDScn",
	description = "Beyond All Reason plus the waves of a Tower Defense scenario",
	mutator = "Official",
	modtype = 1,
	depend = { "$game" },
}
"@
    $utf8n = New-Object Text.UTF8Encoding($false)
    $files = @(, @('modinfo.lua', $modinfo))
    if ($tdNeeded) { $files += , @('luarules/gadgets/td_waves.lua', [IO.File]::ReadAllText($tdGadget)) }
    if ($ctfNeeded) { $files += , @('luarules/gadgets/ctf_game.lua', [IO.File]::ReadAllText($ctfGadget)) }
    if ($ctfNeeded -and (Test-Path $lootStub)) { $files += , @('luarules/gadgets/pve_supply_drops.lua', [IO.File]::ReadAllText($lootStub)) }
    if ($rstNeeded) { $files += , @('luarules/gadgets/unit_restrictions.lua', [IO.File]::ReadAllText($rstGadget)) }
    $rulesFile = if ($EditorDir) { Join-Path (Join-Path (Split-Path $EditorDir -Parent) 'shared') 'bar_rules.lua' } else { Join-Path $pkg 'bar_rules.lua' } # shared rules (packages made before this file existed carry a gadget that does not need it)
    if (Test-Path $rulesFile) { $files += , @('luaui/Include/bar_rules.lua', [IO.File]::ReadAllText($rulesFile)) }
    if ($build) {
        $zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
        foreach ($e in $files) {
            $entry = $zip.CreateEntry($e[0])
            $w = New-Object IO.StreamWriter($entry.Open(), $utf8n)
            $w.Write($e[1]); $w.Close()
        }
        $zip.Dispose()
        Write-Host "Extra game built ($zipPath)"
    }
    $gametype = 'Tower Defense Scenario 1'
}
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
if (-not $have) {
    Write-Host ''
    Write-Host "This scenario needs the map '$map'. It is not installed on this computer yet." -ForegroundColor Yellow
    Write-Host 'It has to be downloaded from the internet (the official BAR map service, can take a few minutes).'
    $ans = Read-Host 'Download the map now and start the scenario? (y/n)'
    if ($ans.Trim().ToLower() -notin @('y', 'yes', 'j', 'ja')) { Fail 'Aborted. The scenario cannot start without the map.' }
    Write-Host 'Downloading the map ...'
    $dl = Join-Path $engineDir.FullName 'pr-downloader.exe'
    if (-not (Test-Path $dl)) { Fail 'The map downloader (pr-downloader.exe) was not found. Please start BAR once and install the map there.' }
    & $dl --filesystem-writepath $data --download-map $map
}

# Briefing window: small user widget (the mission display of the game only knows scenarios in the game archive)
$wsrc = Join-Path $here 'scenario_briefing.lua'
if (Test-Path $wsrc) {
    $wdir = Join-Path $data 'LuaUI\Widgets'
    New-Item -ItemType Directory -Force $wdir | Out-Null
    Copy-Item $wsrc (Join-Path $wdir 'scenario_briefing.lua') -Force
}

$spring = Join-Path $engineDir.FullName 'spring.exe'

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
    $all = @('--config', $cfg, '--write-dir', $data) + $sargs
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
    Start-Spring @($out) { Start-Sleep -Seconds 5; Send-LobbyGo }
    Close-Lobby
    exit 0
}
Write-Host 'Starting the game ...'
Start-Spring @($out)
