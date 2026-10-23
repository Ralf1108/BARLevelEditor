# Removes the Level Editor again, the way install_editor.ps1 set it up.
# Run through uninstall_editor.bat. The official game stays unchanged. Saved levels and blueprints are kept:
# they live in the folders levels and blueprints of the LevelEditor folder; only the junctions to them are removed.
# -Yes: without asking. -WithSettings: also delete the editor's settings files in the game folder (LuaUI\Config).
param([switch]$Yes, [switch]$WithSettings)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot                    # scripts
$root = Split-Path $here -Parent        # LevelEditor
$repo = Split-Path $root -Parent        # repository
$userDir = Join-Path $env:LOCALAPPDATA 'BAR-Level-Editor'   # last map and cache of the map list

function Step($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
$common = Join-Path (Join-Path $repo 'shared') 'bar_common.ps1'
if (-not (Test-Path $common)) { Write-Host "ERROR: $common missing (the folder shared must lie next to the folder LevelEditor)." -ForegroundColor Red; exit 1 }
. $common

# ---------------------------------------------------------------- Find BAR (as during setup)
Step 'Find Beyond All Reason'
$bar = Find-Bar
$data = Join-Path $bar 'data'
Write-Host "BAR found: $bar"

# ---------------------------------------------------------------- What is removed
$desktop = [Environment]::GetFolderPath('Desktop')
$items = @(
    @{ Path = (Join-Path $data 'games\LevelEditorMod.sdz'); Text = 'Extra game "Level Editor" (data\games\LevelEditorMod.sdz)'; Kind = 'file' },
    @{ Path = (Join-Path $data 'games\LevelEditorMod.stamp'); Text = 'Stamp of the extra game (data\games\LevelEditorMod.stamp)'; Kind = 'file' },
    @{ Path = (Join-Path $data 'games\LevelEditorScenarios.sdz'); Text = 'Extra game "Level Editor Scenarios" (data\games\LevelEditorScenarios.sdz)'; Kind = 'file' },
    @{ Path = (Join-Path $data 'LevelEditor'); Text = 'Junction data\LevelEditor (the levels themselves stay in levels)'; Kind = 'junction' },
    @{ Path = (Join-Path $data 'LevelEditorBlueprints'); Text = 'Junction data\LevelEditorBlueprints (the blueprints themselves stay in blueprints)'; Kind = 'junction' },
    @{ Path = (Join-Path $data 'LevelEditorScenarios'); Text = 'Junction data\LevelEditorScenarios (the built scenarios themselves stay in scenario\scenarios)'; Kind = 'junction' },
    @{ Path = (Join-Path $data 'LuaMenu\Widgets\lan_lobby.lua'); Text = 'LAN Play widget for the lobby (data\LuaMenu\Widgets\lan_lobby.lua)'; Kind = 'file' },
    @{ Path = (Join-Path $desktop 'BAR Level Editor.lnk'); Text = 'Desktop shortcut "BAR Level Editor"'; Kind = 'file' },
    @{ Path = (Join-Path $root 'start_level_editor.bat'); Text = 'start_level_editor.bat'; Kind = 'file' },
    @{ Path = (Join-Path $root 'editor_script_installed.txt'); Text = 'editor_script_installed.txt (start script)'; Kind = 'file' },
    @{ Path = (Join-Path $userDir 'Last Map.txt'); Text = 'Last Map.txt (last chosen map, in %LOCALAPPDATA%\BAR-Level-Editor)'; Kind = 'file' },
    @{ Path = (Join-Path $userDir 'Online Maps Cache.json'); Text = 'Online Maps Cache.json (cached map list, in %LOCALAPPDATA%\BAR-Level-Editor)'; Kind = 'file' }
)
if ($WithSettings) {
    foreach ($n in 'LevelEditorRecent.lua', 'LevelEditorUI.lua') {
        $items += @{ Path = (Join-Path $data "LuaUI\Config\$n"); Text = "Settings file LuaUI\Config\$n"; Kind = 'file' }
    }
}

Step 'This will be removed'
$found = @($items | Where-Object { Test-Path -LiteralPath $_.Path })
if ($found.Count -eq 0) { Write-Host 'Nothing to remove, the Level Editor is not set up.'; exit 0 }
foreach ($i in $found) { Write-Host "  - $($i.Text)" }
Write-Host ''
Write-Host "Kept: levels ($(Join-Path $root 'levels')), blueprints ($(Join-Path $root 'blueprints')), this folder and the official game."
if (-not $Yes) {
    $a = Read-Host 'Remove now? (y/n)'
    if ($a.Trim().ToLower() -notin @('y', 'yes', 'j', 'ja')) { Write-Host 'Aborted, nothing changed.'; exit 0 }
}

# ---------------------------------------------------------------- Remove
Step 'Remove'
foreach ($i in $found) {
    if ($i.Kind -eq 'junction') {
        # only unhook the junction: rmdir does not delete the contents of the target
        if (-not (Remove-Junction $i.Path)) { continue }
    } else {
        Remove-Item -LiteralPath $i.Path -Force
    }
    Write-Host "  removed: $($i.Text)"
}
Write-Host ''
Write-Host 'Done. To set it up again run install_editor.bat.' -ForegroundColor Green
