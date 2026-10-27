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
. (Join-Path $here 'editor_stamp.ps1')

# ---------------------------------------------------------------- 1. Find BAR
Step 'Find Beyond All Reason'
$bar = Find-Bar
$data = Join-Path $bar 'data'
Write-Host "BAR found: $bar"
if (Get-Process spring -ErrorAction SilentlyContinue) { Fail 'The game is running: close it first (it holds the extra game files).' }

# Writes a zip with the entries @(name, text) to $path: first into a temporary file that then replaces the old one, so a failure in between
# leaves the old extra game in place. $fixedTime: optional time for all entries (equal archives on every computer).
function Write-GameZip([string]$path, $entries, $fixedTime = $null) {
    $tmp = $path + '.tmp'
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
    $utf8 = New-Object Text.UTF8Encoding($false)
    $zip = [IO.Compression.ZipFile]::Open($tmp, 'Create')
    try {
        foreach ($e in $entries) {
            $entry = $zip.CreateEntry($e[0])
            if ($fixedTime) { $entry.LastWriteTime = $fixedTime }
            $w = New-Object IO.StreamWriter($entry.Open(), $utf8)
            try { $w.Write($e[1]) } finally { $w.Close() }
        }
    } finally { $zip.Dispose() }
    Move-Item $tmp $path -Force
    Write-Host "Created: $path"
}

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
foreach ($f in $EditorFiles) {
    if (-not (Test-Path (Join-Path $here $f))) { Fail "File missing: $f (the folder scripts copied completely?)" }
}
# shared code of the Level Editor and the BluePrinter (folder shared next to LevelEditor)
$sharedFile = Join-Path (Join-Path $repo 'shared') 'editor_common.lua'
if (-not (Test-Path $sharedFile)) { Fail "File missing: editor_common.lua (copy the shared folder next to LevelEditor as well)" }
$rulesFile = Join-Path (Join-Path $repo 'shared') 'bar_rules.lua'
if (-not (Test-Path $rulesFile)) { Fail "File missing: bar_rules.lua (copy the shared folder next to LevelEditor as well)" }
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
# switch the widget on in the mod: only the first 'enabled = false,' (GetInfo); the same text appears in the code as data
$widget = ([regex]'enabled = false,').Replace((Get-Content (Join-Path $here 'lvl_level_editor.lua') -Raw), 'enabled = true,', 1)
$gadget = Get-Content (Join-Path $here 'unit_level_editor.lua') -Raw
$gadgetTd = Get-Content (Join-Path $here 'td_waves.lua') -Raw
$gadgetCtf = Get-Content (Join-Path $here 'ctf_game.lua') -Raw
$ctfPage = Get-Content (Join-Path $here 'led_ctf.lua') -Raw
$gadgetRtf = Get-Content (Join-Path $here 'rtf_game.lua') -Raw
$rtfPage = Get-Content (Join-Path $here 'led_rtf.lua') -Raw
$gadgetRst = Get-Content (Join-Path $here 'unit_restrictions.lua') -Raw
$gadgetFix = Get-Content (Join-Path $here 'unit_indestructible.lua') -Raw
$rstData = Get-Content (Join-Path $here 'led_restrictions.lua') -Raw
$helpTexts = Get-Content (Join-Path $here 'help_texts.lua') -Raw
$lootStub = Get-Content (Join-Path $here 'pve_supply_drops_stub.lua') -Raw # replaces the lootbox gadget of the game (it let enemies capture the flags and collection points)
$shared = Get-Content $sharedFile -Raw
$rules = Get-Content $rulesFile -Raw
Write-GameZip $zipPath @(
    @('modinfo.lua', $modinfo),
    @('luarules/gadgets/unit_level_editor.lua', $gadget),
    @('luarules/gadgets/td_waves.lua', $gadgetTd),
    @('luarules/gadgets/ctf_game.lua', $gadgetCtf),
    @('luarules/gadgets/rtf_game.lua', $gadgetRtf),
    @('luarules/gadgets/pve_supply_drops.lua', $lootStub),
    @('luarules/gadgets/unit_restrictions.lua', $gadgetRst),
    @('luarules/gadgets/unit_indestructible.lua', $gadgetFix),
    @('luaui/widgets/lvl_level_editor.lua', $widget),
    @('luaui/Include/editor_common.lua', $shared),
    @('luaui/Include/bar_rules.lua', $rules),
    @('luaui/Include/led_ctf.lua', $ctfPage),
    @('luaui/Include/led_rtf.lua', $rtfPage),
    @('luaui/Include/led_restrictions.lua', $rstData),
    @('luaui/Include/led_help_texts.lua', $helpTexts))

# The extra game for finished scenarios ("Level Editor Scenarios", used by LAN Play: the lobby starts a scenario with it): the gadgets of the scenarios, all
# in one game. Each one switches itself on only when the game options of the scenario ask for it (tdconfig, ctfconfig, rtfconfig, restrictions), so it is the same game
# for every scenario and every computer with this version of the editor. The zip entries get a fixed time so that the archives of two computers are equal.
$zipPath2 = Join-Path $gamesDir 'LevelEditorScenarios.sdz'
$modinfo2 = @"
return {
	name = "Level Editor Scenarios",
	shortName = "LEScn",
	version = "1",
	game = "LevelEditorScenarios",
	shortGame = "LEScn",
	description = "Beyond All Reason plus the gadgets of the scenarios of the Level Editor",
	mutator = "Official",
	modtype = 1,
	depend = { "$game" },
}
"@
$fixedTime = New-Object DateTimeOffset (2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
Write-GameZip $zipPath2 @(
    @('luarules/gadgets/td_waves.lua', $gadgetTd),
    @('luarules/gadgets/ctf_game.lua', $gadgetCtf),
    @('luarules/gadgets/rtf_game.lua', $gadgetRtf),
    @('luarules/gadgets/pve_supply_drops.lua', $lootStub),
    @('luarules/gadgets/unit_restrictions.lua', $gadgetRst),
    @('luarules/gadgets/unit_indestructible.lua', $gadgetFix),
    @('luaui/Include/bar_rules.lua', $rules),
    @('modinfo.lua', $modinfo2)) $fixedTime
Set-Content -Path (Join-Path $gamesDir 'LevelEditorMod.stamp') -Value (Get-EditorStamp $here $game) -Encoding ASCII # tells start_level_editor.bat that the setup is up to date

if ($Quick) { exit 0 }

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
for /d %%D in ("%DATA%\engine\*") do if exist "%%D\spring.exe" set "ENGINE=%%D"
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
