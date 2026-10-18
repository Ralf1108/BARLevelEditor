# Installs the BluePrinter widget and starts a small test game with it (run through start_blueprinter.bat).
# Use it to look at the menu after changing bluePrinter.lua or shared\editor_common.lua.
param([string]$Map = $null)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression

# 1. Install (sets $bar and $data; exits with an error message if BAR is not found)
. (Join-Path $PSScriptRoot 'install_blueprinter.ps1')

# 2. Engine
$engineDir = Get-ChildItem (Join-Path $data 'engine') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'spring.exe') } | Sort-Object Name | Select-Object -Last 1
if (-not $engineDir) { Fail 'No engine found in data\engine. Please start BAR once so the launcher installs it.' }

# 3. Installed game version (as in install_editor.ps1)
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

# 4. Map: given one, otherwise the first installed map
if (-not $Map) {
    $cache = Get-ChildItem (Join-Path $data 'cache') -Filter 'ArchiveCache*.lua' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($cache) {
        $m = [regex]::Match([IO.File]::ReadAllText($cache.FullName), 'modtype = 3,\s*name = "([^"]+)"')
        if ($m.Success) { $Map = $m.Groups[1].Value }
    }
}
if (-not $Map) { Fail 'No installed map found. Start BAR once and download a map, or pass -Map "Map Name".' }

# 5. Start script: one player with a commander against a passive AI
$script = @"
[game]
{
	[allyteam0] { numallies=0; }
	[allyteam1] { numallies=0; }
	[team0] { allyteam=0; teamleader=0; side=Armada; handicap=0; }
	[team1] { allyteam=1; teamleader=0; side=Cortex; handicap=0; }
	[ai0] { shortname=NullAI; team=1; host=0; name=Null1; }
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; }
	ishost=1;
	hostip=127.0.0.1;
	myplayername=Player;
	gametype=$game;
	mapname=$Map;
	startpostype=0;
	numplayers=1;
	numusers=2;
	nohelperais=0;
}
"@
$out = Join-Path $env:TEMP 'bar_blueprinter_start.txt'
[IO.File]::WriteAllText($out, $script, (New-Object Text.UTF8Encoding($false)))
Write-Host "Game: $game"
Write-Host "Map: $Map"
Write-Host 'Starting the game ... (BluePrinter: Settings -> allow user widgets, then F11 -> switch BluePrinter on; /luaui reload after changes)'
& (Join-Path $engineDir.FullName 'spring.exe') --write-dir $data $out
