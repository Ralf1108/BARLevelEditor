# Removes the Level Editor again, the way install_editor.ps1 set it up.
# Run through uninstall_editor.bat. The official game stays unchanged. Saved levels and blueprints are kept:
# they live in the folders levels and blueprints next to this script; only the junctions to them are removed.
# -Yes: without asking. -WithSettings: also delete the editor's settings files in the game folder (LuaUI\Config).
param([switch]$Yes, [switch]$WithSettings)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot

function Step($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }
function Fail($t) { Write-Host "ERROR: $t" -ForegroundColor Red; exit 1 }

# ---------------------------------------------------------------- Find BAR (as during setup)
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

# ---------------------------------------------------------------- What is removed
$desktop = [Environment]::GetFolderPath('Desktop')
$items = @(
    @{ Path = (Join-Path $data 'games\LevelEditorMod.sdz'); Text = 'Extra game "Level Editor" (data\games\LevelEditorMod.sdz)'; Kind = 'file' },
    @{ Path = (Join-Path $data 'LevelEditor'); Text = 'Junction data\LevelEditor (the levels themselves stay in levels)'; Kind = 'junction' },
    @{ Path = (Join-Path $data 'LevelEditorBlueprints'); Text = 'Junction data\LevelEditorBlueprints (the blueprints themselves stay in blueprints)'; Kind = 'junction' },
    @{ Path = (Join-Path $desktop 'BAR Level Editor.lnk'); Text = 'Desktop shortcut "BAR Level Editor"'; Kind = 'file' },
    @{ Path = (Join-Path $here 'start_level_editor.bat'); Text = 'start_level_editor.bat'; Kind = 'file' },
    @{ Path = (Join-Path $here 'editor_script_installed.txt'); Text = 'editor_script_installed.txt (start script)'; Kind = 'file' }
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
Write-Host "Kept: levels ($(Join-Path $here 'levels')), blueprints ($(Join-Path $here 'blueprints')), this folder and the official game."
if (-not $Yes) {
    $a = Read-Host 'Remove now? (y/n)'
    if ($a.Trim().ToLower() -notin @('y', 'yes', 'j', 'ja')) { Write-Host 'Aborted, nothing changed.'; exit 0 }
}

# ---------------------------------------------------------------- Remove
Step 'Remove'
foreach ($i in $found) {
    if ($i.Kind -eq 'junction') {
        # only unhook the junction: rmdir does not delete the contents of the target
        $item = Get-Item -LiteralPath $i.Path -Force
        if ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) {
            cmd /c rmdir "$($i.Path)" | Out-Null
        } else {
            Write-Host "  skipped (not a junction but a real folder): $($i.Path)" -ForegroundColor Yellow
            continue
        }
    } else {
        Remove-Item -LiteralPath $i.Path -Force
    }
    Write-Host "  removed: $($i.Text)"
}
Write-Host ''
Write-Host 'Done. To set it up again run install_editor.bat.' -ForegroundColor Green
