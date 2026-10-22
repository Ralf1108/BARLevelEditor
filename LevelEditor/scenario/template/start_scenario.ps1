# Starts a scenario with the official Beyond All Reason (nothing in the game is changed).
# Run through "Start Scenario.bat" in the same folder. The file scenario.txt is the finished start script
# with two placeholders (__GAMETYPE__ = installed game version, __PLAYERNAME__ = player name).
# Several players in the same network (LAN): -HostGame [-Players n] hosts the game (the other players use -JoinIp <address> and the name the
# host shows), -Port is the UDP port of the host (default 8452), -Wait the seconds the others have to join after the host has loaded (default 90).
# Without -JoinIp the join mode (Join Game.bat passes -Join) asks for the address.
param([string]$BarPath = $null, [string]$Name = $null, [switch]$ScriptOnly, [switch]$HostGame, [switch]$Join,[int]$Players = 0, [string]$JoinIp = $null, [int]$Port = 8452, [int]$Wait = 90)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
$here = $PSScriptRoot

function Fail($t) { Write-Host ""; Write-Host "ERROR: $t" -ForegroundColor Red; Read-Host 'Press Enter to exit'; exit 1 }

# ---------------------------------------------------------------- Find BAR
# (the same search as Find-Bar, Get-Engine and Get-GameVersion in shared\bar_common.ps1; this script runs alone on the recipient's computer, so it
# carries its own copy: change both together)
$memo = Join-Path $here 'bar_path.txt'
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
$script = [IO.File]::ReadAllText((Join-Path $here 'scenario.txt'))
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
    $in = (Read-Host 'Your name as the host shows it (Player2, Player3, ...; Enter = Player2)').Trim()
    $Name = if ($in) { $in } else { 'Player2' }
}
if (-not $Name) { $Name = $env:USERNAME }
if (-not $Name) { $Name = 'Player' }
$Name = $Name -replace '[^A-Za-z0-9_\-\[\]]', ''
if (-not $Name) { $Name = 'Player' }
# Tower Defense, Capture the Flag and restricted scenarios: the waves run in a gadget (td_waves.lua in this folder), the flags in another
# (ctf_game.lua), the restrictions in a third (unit_restrictions.lua). The
# official game cannot load them, so a small extra game "Tower Defense Scenario" is built on the installed official game (only the gadgets are
# added; nothing of the official game is changed).
$gametype = $game
$tdGadget = Join-Path $here 'td_waves.lua'
$ctfGadget = Join-Path $here 'ctf_game.lua'
$rstGadget = Join-Path $here 'unit_restrictions.lua'
if ((Test-Path $tdGadget) -or (Test-Path $ctfGadget) -or (Test-Path $rstGadget)) {
    $gamesDir = Join-Path $data 'games'
    New-Item -ItemType Directory -Force $gamesDir | Out-Null
    $zipPath = Join-Path $gamesDir 'TowerDefenseScenario.sdz'
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
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
    $zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
    $files = @(, @('modinfo.lua', $modinfo))
    if (Test-Path $tdGadget) { $files += , @('luarules/gadgets/td_waves.lua', [IO.File]::ReadAllText($tdGadget)) }
    if (Test-Path $ctfGadget) { $files += , @('luarules/gadgets/ctf_game.lua', [IO.File]::ReadAllText($ctfGadget)) }
    if (Test-Path $rstGadget) { $files += , @('luarules/gadgets/unit_restrictions.lua', [IO.File]::ReadAllText($rstGadget)) }
    $rulesFile = Join-Path $here 'bar_rules.lua' # shared rules (packages made before this file existed carry a gadget that does not need it)
    if (Test-Path $rulesFile) { $files += , @('luaui/Include/bar_rules.lua', [IO.File]::ReadAllText($rulesFile)) }
    foreach ($e in $files) {
        $entry = $zip.CreateEntry($e[0])
        $w = New-Object IO.StreamWriter($entry.Open(), $utf8n)
        $w.Write($e[1]); $w.Close()
    }
    $zip.Dispose()
    $gametype = 'Tower Defense Scenario 1'
    Write-Host "Extra game built ($zipPath)"
}
$script = $script.Replace('__GAMETYPE__', $gametype).Replace('__PLAYERNAME__', $Name)
if ($HostGame) {
    # Every extra human takes over the team of a computer opponent: team 1 for the second player, team 2 for the third, ...
    $script = $script.Replace("`r`n", "`n")
    $teams = ([regex]::Matches($script, '(?m)^\t\[team\d+\]')).Count
    if ($teams -lt 2) { Fail 'This scenario has only one team, there is nobody to play against.' }
    if ($Players -lt 2) {
        $in = Read-Host "How many human players (2 to $teams, you are one of them)"
        if (-not [int]::TryParse($in, [ref]$Players)) { $Players = 2 }
    }
    $Players = [Math]::Max(2, [Math]::Min($teams, $Players))
    $names = @($Name)
    $extra = New-Object Text.StringBuilder
    for ($k = 1; $k -lt $Players; $k++) {
        $pn = "Player$($k + 1)"
        $names += $pn
        $n0 = $script.Length
        $script = [regex]::Replace($script, "(?s)\t\[ai\d+\]\s*\{[^}]*\bTeam=$k;[^}]*\}\n", '')
        if ($script.Length -eq $n0) { Write-Host "Note: team $k had no computer opponent." -ForegroundColor Yellow }
        [void]$extra.Append("`t[player$k]`n`t{`n`t`tName=$pn;`n`t`tTeam=$k;`n`t`tspectator=0;`n`t`trank=0;`n`t}`n")
    }
    $script = $script.Replace("`t[modoptions]", $extra.ToString() + "`t[modoptions]")
    $ais = ([regex]::Matches($script, '(?m)^\t\[ai\d+\]')).Count
    # hostip 0.0.0.0 = listen on all network cards (without a value the engine listens on the loopback address only)
    $script = $script.Replace('hostip=127.0.0.1;', 'hostip=0.0.0.0;').Replace('hostport=0;', "hostport=$Port;")
    # The game starts GameStartDelay seconds after the host has loaded; whoever connects later is refused ("Game has already started"), so this
    # is the time the others have to start "Join Game.bat" (found in the test of 2026-10-22: with 3 seconds a player who joined after 25 s was refused)
    $script = [regex]::Replace($script, 'GameStartDelay=\d+;', "GameStartDelay=$Wait;")
    $script = [regex]::Replace($script, 'numplayers=\d+;', "numplayers=$Players;")
    $script = [regex]::Replace($script, 'numusers=\d+;', "numusers=$($Players + $ais);")
}
$out =Join-Path $env:TEMP 'bar_scenario_start.txt'
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
if ($JoinIp) {
    Write-Host "Joining $($JoinIp):$Port as '$Name' (the host has to be running; the name must be the one the host showed) ..."
    & $spring --write-dir $data "spring://$Name@$($JoinIp):$Port"
    exit 0
}
if ($HostGame) {
    $addr = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | ForEach-Object { $_.IPAddress })
    Write-Host ''
    Write-Host "You host this game as '$Name' on UDP port $Port. The other players start ""Join Game.bat"" and enter:" -ForegroundColor Cyan
    Write-Host "  address: $($addr -join ' or ')" -ForegroundColor Cyan
    for ($k = 1; $k -lt $Players; $k++) { Write-Host "  player $($k + 1): name Player$($k + 1)" -ForegroundColor Cyan }
    Write-Host "The game loads for you first; the others have about $Wait seconds after that to start ""Join Game.bat"" (a countdown runs in the game)." -ForegroundColor Cyan
    Write-Host 'If Windows asks about the firewall: allow spring.exe in the private network.'
}
Write-Host 'Starting the game ...'
& $spring --write-dir $data $out
