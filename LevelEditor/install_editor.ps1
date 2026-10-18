# Sets up the Level Editor on a machine with Beyond All Reason installed.
# Run through install_editor.bat. Changes nothing in the official game: it only creates an extra game "Level Editor"
# (data\games\LevelEditorMod.sdz) that builds on the official BAR, plus a start file and a level folder.
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$here = $PSScriptRoot

function Step($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
function Fail($t) { Write-Host "ERROR: $t" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- 1. BAR finden
Step 'Find Beyond All Reason'
$candidates = @()
$candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason')
$parents = @('Games', 'Spiele', 'Program Files', 'Program Files (x86)', 'Programme', '')
$names = @('Beyond-All-Reason', 'Beyond All Reason', 'BeyondAllReason')
foreach ($drive in [IO.DriveInfo]::GetDrives()) {
    if ($drive.DriveType -ne 'Fixed' -or -not $drive.IsReady) { continue }
    foreach ($par in $parents) {
        foreach ($n in $names) {
            $candidates += (Join-Path (Join-Path $drive.RootDirectory.FullName $par) $n)
        }
    }
}
$bar = $null
foreach ($c in $candidates) {
    if (Test-Path (Join-Path $c 'data\engine')) { $bar = $c; break }
}
while (-not $bar) {
    $in = Read-Host 'BAR not found. Please enter the installation folder (Beyond-All-Reason.exe is in it)'
    if ($in -and (Test-Path (Join-Path $in 'data\engine'))) { $bar = $in } elseif (-not $in) { Fail 'Aborted.' } else { Write-Host 'There is no data\engine folder there.' }
}
$data = Join-Path $bar 'data'
Write-Host "BAR found: $bar"

# ---------------------------------------------------------------- 2. Engine
Step 'Find the engine'
$engineDir = Get-ChildItem (Join-Path $data 'engine') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'spring.exe') } | Sort-Object Name | Select-Object -Last 1
if (-not $engineDir) { Fail 'No engine found in data\engine. Please start BAR once so the launcher installs it.' }
Write-Host "Engine: $($engineDir.Name)"

# ---------------------------------------------------------------- 3. Version des offiziellen Spiels
Step 'Determine the version of the official game'
$versionsFile = Join-Path $data 'rapid\repos-cdn.beyondallreason.dev\byar\versions.gz'
if (-not (Test-Path $versionsFile)) { Fail 'No game data found (rapid\...\byar\versions.gz). Please start BAR once and let a game load.' }
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
if (-not $game) {
    $game = $fallback
    if ($game) { Write-Host "Note: installed game not identified clearly, taking $game" -ForegroundColor Yellow }
}
if (-not $game) { Fail 'Game version not found.' }
Write-Host "Game: $game"

# ---------------------------------------------------------------- 4. Build the extra game (zip)
Step 'Build the extra game "Level Editor"'
foreach ($f in @('unit_level_editor.lua', 'lvl_level_editor.lua')) {
    if (-not (Test-Path (Join-Path $here $f))) { Fail "File missing: $f (LevelEditor folder copied completely?)" }
}
# shared code of the Level Editor and the BluePrinter: folder shared next to LevelEditor (source) or a copy in the LevelEditor folder
$sharedFile = Join-Path (Join-Path (Split-Path $here -Parent) 'shared') 'editor_common.lua'
if (-not (Test-Path $sharedFile)) { $sharedFile = Join-Path $here 'editor_common.lua' }
if (-not (Test-Path $sharedFile)) { Fail "File missing: editor_common.lua (copy the shared folder next to LevelEditor as well)" }
$gamesDir = Join-Path $data 'games'
New-Item -ItemType Directory -Force $gamesDir | Out-Null
$zipPath = Join-Path $gamesDir 'LevelEditorMod.sdz'
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
$modinfo = @"
return {
	name = "Level Editor",
	shortName = "LevelEd",
	version = "1",
	game = "LevelEditorMod",
	shortGame = "LevelEd",
	description = "Beyond All Reason plus Level Editor",
	mutator = "Official",
	modtype = 1,
	depend = { "$game" },
}
"@
$widget = (Get-Content (Join-Path $here 'lvl_level_editor.lua') -Raw) -replace 'enabled = false,', 'enabled = true,'
$gadget = Get-Content (Join-Path $here 'unit_level_editor.lua') -Raw
$shared = Get-Content $sharedFile -Raw
$zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
$utf8 = New-Object Text.UTF8Encoding($false)
foreach ($e in @(
    @('modinfo.lua', $modinfo),
    @('luarules/gadgets/unit_level_editor.lua', $gadget),
    @('luaui/widgets/lvl_level_editor.lua', $widget),
    @('luaui/Include/editor_common.lua', $shared))) {
    $entry = $zip.CreateEntry($e[0])
    $w = New-Object IO.StreamWriter($entry.Open(), $utf8)
    $w.Write($e[1]); $w.Close()
}
$zip.Dispose()
Write-Host "Created: $zipPath"

# ---------------------------------------------------------------- 5. Folder for saved levels
Step 'Folder for saved levels'
$levels = Join-Path $here 'levels'
New-Item -ItemType Directory -Force $levels | Out-Null
$link = Join-Path $data 'LevelEditor'
function Repoint($path, $target) {
    # a junction left over from a moved or renamed project folder is removed so it can be created again
    $item = Get-Item $path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and (@($item.Target)[0] -ne $target)) {
        cmd /c rmdir "$path" | Out-Null
        Write-Host "Stale junction removed: $path -> $(@($item.Target)[0])"
    }
}
Repoint $link $levels
if (-not (Test-Path $link)) {
    cmd /c mklink /J "$link" "$levels" | Out-Null
    Write-Host "Junction: $link -> $levels"
} else {
    Write-Host 'Junction already exists.'
}

# Blueprints (Create / blueprint menu): own folder with its own junction
$bpDir = Join-Path $here 'blueprints'
New-Item -ItemType Directory -Force $bpDir | Out-Null
New-Item -ItemType Directory -Force (Join-Path $bpDir '_trash') | Out-Null
$bpLink = Join-Path $data 'LevelEditorBlueprints'
Repoint $bpLink $bpDir
if (-not (Test-Path $bpLink)) {
    cmd /c mklink /J "$bpLink" "$bpDir" | Out-Null
    Write-Host "Junction: $bpLink -> $bpDir"
} else {
    Write-Host 'Junction for blueprints already exists.'
}

# ---------------------------------------------------------------- 7. Start file (with map selection)
Step 'Write the start file'
$bat = @"
@echo off
rem Starts the Level Editor (created by install_editor.bat): first the map selection, then the game.
rem Run install_editor.bat again when BAR was updated.
setlocal
set "L=%~dp0"
set "DATA=$data"
set "ENGINE="
for /d %%D in ("%DATA%\engine\*") do if exist "%%D\spring.exe" set "ENGINE=%%D"
if not defined ENGINE (
	echo No engine found.
	pause & exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%check_links.ps1" -Data "%DATA%"
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%choose_map.ps1" -Data "%DATA%"
if errorlevel 1 exit /b 1
"%ENGINE%\spring.exe" --write-dir "%DATA%" "%L%editor_script_installed.txt"
echo Done. Saved levels are in %L%levels
endlocal
"@
Set-Content -Path (Join-Path $here 'start_level_editor.bat') -Value $bat -Encoding ASCII
Write-Host 'start_level_editor.bat written.'

# ---------------------------------------------------------------- 8. Desktop-Verknuepfungen
Step 'Desktop shortcuts'
$desktop = [Environment]::GetFolderPath('Desktop')
$wsh = New-Object -ComObject WScript.Shell
$barExe = Join-Path $bar 'Beyond-All-Reason.exe'

# Default game: only create if there is no BAR shortcut on the desktop yet
$existing = @(Get-ChildItem $desktop, ([Environment]::GetFolderPath('CommonDesktopDirectory')) -Filter '*.lnk' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -like '*Beyond*All*Reason*' })
if ($existing.Count -eq 0 -and (Test-Path $barExe)) {
    $lnk = $wsh.CreateShortcut((Join-Path $desktop 'Beyond All Reason.lnk'))
    $lnk.TargetPath = $barExe
    $lnk.WorkingDirectory = $bar
    $lnk.Save()
    Write-Host 'Shortcut "Beyond All Reason" created.'
} else {
    Write-Host 'Shortcut "Beyond All Reason" already exists (or BAR exe not found), nothing changed.'
}

$lnk = $wsh.CreateShortcut((Join-Path $desktop 'BAR Level Editor.lnk'))
$lnk.TargetPath = Join-Path $here 'start_level_editor.bat'
$lnk.WorkingDirectory = $here
$lnk.Description = 'Start Beyond All Reason with the Level Editor (map selection)'
if (Test-Path $barExe) { $lnk.IconLocation = "$barExe,0" }
$lnk.Save()
Write-Host 'Shortcut "BAR Level Editor" created.'

Write-Host ""
Write-Host "Done. Start via the desktop shortcut 'BAR Level Editor'." -ForegroundColor Green
Write-Host "In the game: /cheat, /globallos, /led_help  (the widget is already on)"
Write-Host "After a BAR update run this setup again."
