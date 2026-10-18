# Starts a scenario with the official Beyond All Reason (nothing in the game is changed).
# Run through "Start Scenario.bat" in the same folder. The file scenario.txt is the finished start script
# with two placeholders (__GAMETYPE__ = installed game version, __PLAYERNAME__ = player name).
param([string]$BarPath = $null, [string]$Name = $null, [switch]$ScriptOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
$here = $PSScriptRoot

function Fail($t) { Write-Host ""; Write-Host "ERROR: $t" -ForegroundColor Red; Read-Host 'Press Enter to exit'; exit 1 }

# ---------------------------------------------------------------- Find BAR
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
if (-not $Name) { $Name = $env:USERNAME }
if (-not $Name) { $Name = 'Player' }
$Name = $Name -replace '[^A-Za-z0-9_\-\[\]]', ''
if (-not $Name) { $Name = 'Player' }
$script = $script.Replace('__GAMETYPE__', $game).Replace('__PLAYERNAME__', $Name)
$out = Join-Path $env:TEMP 'bar_scenario_start.txt'
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
    # remove the widget file of earlier versions (it had a different name and would show a second window)
    $older = Join-Path $wdir ('szenario' + '_briefing.lua')
    if (Test-Path $older) { Remove-Item $older -Force }
}

Write-Host 'Starting the game ...'
& (Join-Path $engineDir.FullName 'spring.exe') --write-dir $data $out
