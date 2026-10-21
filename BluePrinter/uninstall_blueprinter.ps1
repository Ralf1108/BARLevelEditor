# Removes the BluePrinter widget again, the way install_blueprinter.ps1 set it up (run through uninstall_blueprinter.bat).
# The official game stays unchanged. The blueprints are kept: they live in the folder blueprints next to this script
# (and in the Level Editor); only the junctions to them are removed.
# -Yes: without asking. -WithSettings: also delete the settings file of the widget (LuaUI\Config\BluePrinterUI.lua).
param([switch]$Yes, [switch]$WithSettings)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$common = Join-Path (Join-Path (Split-Path $here -Parent) 'shared') 'bar_common.ps1'
if (-not (Test-Path $common)) { Write-Host "ERROR: $common missing (the folder shared must lie next to BluePrinter)." -ForegroundColor Red; exit 1 }
. $common

$bar = Find-Bar
$data = Join-Path $bar 'data'
Write-Host "BAR found: $bar"

# The shared code in LuaUI\Include is only used by the BluePrinter (the Level Editor carries its own copy in its extra game)
$items = @(
    @{ Path = (Join-Path $data 'LuaUI\Widgets\bluePrinter.lua'); Text = 'Widget LuaUI\Widgets\bluePrinter.lua'; Kind = 'file' },
    @{ Path = (Join-Path $data 'LuaUI\Include\editor_common.lua'); Text = 'Shared code LuaUI\Include\editor_common.lua'; Kind = 'file' },
    @{ Path = (Join-Path $data 'LuaUI\Include\bar_rules.lua'); Text = 'Shared code LuaUI\Include\bar_rules.lua'; Kind = 'file' },
    @{ Path = (Join-Path $data 'LuaUI\Config\BluePrinter'); Text = 'Junction LuaUI\Config\BluePrinter (the blueprints themselves stay in blueprints)'; Kind = 'junction' },
    @{ Path = (Join-Path $data 'LuaUI\Config\LevelEditorBlueprints'); Text = 'Junction LuaUI\Config\LevelEditorBlueprints (the Level Editor blueprints stay)'; Kind = 'junction' }
)
if ($WithSettings) {
    $items += @{ Path = (Join-Path $data 'LuaUI\Config\BluePrinterUI.lua'); Text = 'Settings file LuaUI\Config\BluePrinterUI.lua'; Kind = 'file' }
}

Write-Host ''
Write-Host 'This will be removed:'
$found = @($items | Where-Object { Test-Path -LiteralPath $_.Path })
if ($found.Count -eq 0) { Write-Host 'Nothing to remove, the BluePrinter is not installed.'; exit 0 }
foreach ($i in $found) { Write-Host "  - $($i.Text)" }
Write-Host ''
Write-Host "Kept: blueprints ($(Join-Path $here 'blueprints')), this folder and the official game."
Write-Host 'Queued plans and switches are stored by BAR in its widget configuration and stay there (harmless).'
if (-not $Yes) {
    $a = Read-Host 'Remove now? (y/n)'
    if ($a.Trim().ToLower() -notin @('y', 'yes', 'j', 'ja')) { Write-Host 'Aborted, nothing changed.'; exit 0 }
}

foreach ($i in $found) {
    if ($i.Kind -eq 'junction') {
        if (-not (Remove-Junction $i.Path)) { continue }
    } else {
        Remove-Item -LiteralPath $i.Path -Force
    }
    Write-Host "  removed: $($i.Text)"
}
Write-Host ''
Write-Host 'Done. To install it again run install_blueprinter.bat.' -ForegroundColor Green
