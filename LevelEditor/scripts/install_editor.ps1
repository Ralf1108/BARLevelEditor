# Sets up the Level Editor on a machine with Beyond All Reason installed.
# Run through install_editor.bat. Changes nothing in the official game: it only creates an extra game "Level Editor"
# (data\games\LevelEditorMod.sdz) that builds on the official BAR, plus a start file and a level folder.
# -Quick (used by ensure_installed.ps1 from start_level_editor.bat): only builds the extra game and its stamp.
param([switch]$Quick)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$here = $PSScriptRoot                    # scripts
$root = Split-Path $here -Parent        # LevelEditor
$repo = Split-Path $root -Parent        # repository

function Step($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
$common = Join-Path (Join-Path $repo 'shared') 'bar_common.ps1'
if (-not (Test-Path $common)) { Write-Host "ERROR: $common missing (the folder shared must lie next to the folder LevelEditor)." -ForegroundColor Red; exit 1 }
. $common
. (Join-Path $here 'editor_manifest.ps1')   # which files go where (one list)

# ---------------------------------------------------------------- 1. Find BAR
Step 'Find Beyond All Reason'
$bar = Find-Bar
$data = Join-Path $bar 'data'
Write-Host "BAR found: $bar"
if (Get-Process spring -ErrorAction SilentlyContinue) { Fail 'The game is running: close it first (it holds the extra game files).' }

# ---------------------------------------------------------------- 2. Engine
Step 'Find the engine'
$engineDir = Get-Engine $data
Write-Host "Engine: $($engineDir.Name)"

# ---------------------------------------------------------------- 3. Version of the official game
Step 'Determine the version of the official game'
$game = Get-GameVersion $data
Write-Host "Game: $game"

# ---------------------------------------------------------------- 4. Build the extra game (zip)
Step 'Build the extra game "Level Editor"'
foreach ($p in (Get-EditorSourceFiles)) {
    if (-not (Test-Path $p)) { Fail "File missing: $p (the folders LevelEditor and shared copied completely, next to each other?)" }
}
$gamesDir = Join-Path $data 'games'
New-Item -ItemType Directory -Force $gamesDir | Out-Null
$zipPath = Join-Path $gamesDir 'LevelEditorMod.sdz'
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
# the files of the list (editor_manifest.ps1); the widget is switched on in the mod: only the first 'enabled = false,' (GetInfo), the same text
# appears in the code as data
$entries = @(, @('modinfo.lua', $modinfo))
foreach ($e in (Get-EditorGameEntries)) {
    $text = Get-Content $e[1] -Raw
    if ($e[0] -eq 'luaui/widgets/lvl_level_editor.lua') { $text = ([regex]'enabled = false,').Replace($text, 'enabled = true,', 1) }
    $entries += , @($e[0], $text)
}
Write-GameZip $zipPath $entries

Write-Host "Created: $zipPath"

# The extra game of the finished scenarios ("Level Editor Scenarios <version>", Write-ScenarioGame in bar_common.ps1): all gadgets of the scenarios in
# one game, each switches itself on only by the game options of a scenario. The scenario starter of the editor builds the same file from the same
# files; LAN Play reads its name from the pointer file. Other versions (received from LAN hosts, or of an older editor) stay; key 8 of the start
# menu cleans them. The files of the older names (one fixed version) are removed.
$prev = Join-Path $gamesDir $ScenarioGamePointer
$prevFile = if (Test-Path $prev) { @(Get-Content $prev)[0] } else { $null }
$scGame = Write-ScenarioGame $data $game (Get-ScenarioGameDirs)
Set-Content -Path $prev -Value @($scGame.File, $scGame.Name) -Encoding ASCII
Write-Host "Created: $($scGame.Path)"
if ($prevFile -and $prevFile -ne $scGame.File -and $prevFile -match '^LevelEditorScenarios_[0-9a-f]{8}\.sdz$') { Remove-Item (Join-Path $gamesDir $prevFile) -Force -ErrorAction SilentlyContinue }   # the editor's own older version
foreach ($old in 'LevelEditorScenarios.sdz', 'TowerDefenseScenario.sdz') { Remove-Item (Join-Path $gamesDir $old) -Force -ErrorAction SilentlyContinue }
Set-Content -Path (Join-Path $gamesDir 'LevelEditorMod.stamp') -Value (Get-EditorStamp $game) -Encoding ASCII # tells start_level_editor.bat that the setup is up to date

if ($Quick) {
    # the quick setup brings LAN Play up to date as well (it copies only what differs)
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'lan_lobby\install_lan_play.ps1') -BarPath $bar | Out-Null
    exit 0
}

# ---------------------------------------------------------------- 5. Folder for saved levels
Step 'Folder for saved levels'
$levels = Join-Path $root 'levels'
New-Item -ItemType Directory -Force $levels | Out-Null
Set-Junction (Join-Path $data 'LevelEditor') $levels

# Blueprints (Create / blueprint menu): own folder with its own junction
$bpDir = Join-Path $root 'blueprints'
New-Item -ItemType Directory -Force (Join-Path $bpDir '_trash') | Out-Null
Set-Junction (Join-Path $data 'LevelEditorBlueprints') $bpDir
Write-Host "Levels: $levels, blueprints: $bpDir"

# Built scenarios (scenario\scenarios): junction, so that the lobby (LAN Play) can read them (the lobby cannot read folders outside the game folder)
$scDir = Join-Path $root 'scenario\scenarios'
New-Item -ItemType Directory -Force $scDir | Out-Null
Set-Junction (Join-Path $data 'LevelEditorScenarios') $scDir

# ---------------------------------------------------------------- 5b. LAN Play (widget for the lobby; changes nothing of the official game)
Step 'LAN Play (widget for the lobby)'
try {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $root 'lan_lobby\install_lan_play.ps1') -BarPath $bar
    if ($LASTEXITCODE -ne 0) { Write-Host 'LAN Play was not installed (the reason is printed above). The rest of the setup is done; run this setup again to install LAN Play.' -ForegroundColor Yellow }
} catch { Write-Host "LAN Play was not installed: $($_.Exception.Message)" -ForegroundColor Yellow }

# ---------------------------------------------------------------- 6. Start file (with map selection)
Step 'Write the start file'
$bat = @"
@echo off
rem Starts the Level Editor (created by install_editor.bat): first the map selection, then the game.
rem The setup runs by itself (ensure_installed.ps1) when the code or the BAR version changed.
setlocal
set "L=%~dp0"
set "DATA=$data"
set "ENGINE="
rem the newest engine (Get-Engine of shared\bar_common.ps1: sorted by version, not by name)
for /f "delims=" %%E in ('powershell -NoProfile -ExecutionPolicy Bypass -Command ". '%L%..\shared\bar_common.ps1'; (Get-Engine '%DATA%').FullName"') do set "ENGINE=%%E"
if defined ENGINE if not exist "%ENGINE%\spring.exe" set "ENGINE="
if not defined ENGINE (
	echo No engine found.
	pause & exit /b 1
)
echo [1/3] Checking the installation ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\ensure_installed.ps1" -Data "%DATA%"
echo [2/3] Checking the links ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\check_links.ps1" -Data "%DATA%"
echo [3/3] Loading the map list and the levels ...
powershell -NoProfile -ExecutionPolicy Bypass -File "%L%scripts\choose_map.ps1" -Data "%DATA%"
rem exit code 2 = cancelled (Esc), 1 = an error: keep the window open so the message can be read
if errorlevel 2 exit /b 0
if errorlevel 1 (
	pause
	exit /b 1
)
"%ENGINE%\spring.exe" --write-dir "%DATA%" "%L%editor_script_installed.txt"
if errorlevel 1 (
	echo The game ended with an error, see %DATA%\infolog.txt
	pause
)
echo Done. Saved levels are in %L%levels
endlocal
"@
Set-Content -Path (Join-Path $root 'start_level_editor.bat') -Value $bat -Encoding ASCII
Write-Host 'start_level_editor.bat written.'

# ---------------------------------------------------------------- 7. Desktop shortcut
Step 'Desktop shortcut'
$desktop = [Environment]::GetFolderPath('Desktop')
$wsh = New-Object -ComObject WScript.Shell
$barExe = Join-Path $bar 'Beyond-All-Reason.exe'
$lnk = $wsh.CreateShortcut((Join-Path $desktop 'BAR Level Editor.lnk'))
$lnk.TargetPath = Join-Path $root 'start_level_editor.bat'
$lnk.WorkingDirectory = $root
$lnk.Description = 'Start Beyond All Reason with the Level Editor (map selection)'
if (Test-Path $barExe) { $lnk.IconLocation = "$barExe,0" }
$lnk.Save()
Write-Host 'Shortcut "BAR Level Editor" created.'

Write-Host ""
Write-Host "Done. Start via the desktop shortcut 'BAR Level Editor'." -ForegroundColor Green
Write-Host "In the game no /cheat is needed; the ? button shows all keys (the widget is already on)."
Write-Host "The start script updates the extra game by itself when the code or the BAR version changed."
