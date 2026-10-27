# Installs the BluePrinter widget in the official Beyond All Reason (run through install_blueprinter.bat).
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$common = Join-Path (Join-Path (Split-Path $here -Parent) 'shared') 'bar_common.ps1'
if (-not (Test-Path $common)) { Write-Host "ERROR: $common missing (the folder shared must lie next to BluePrinter)." -ForegroundColor Red; exit 1 }
. $common

# Find BAR
$bar = Find-Bar
$data = Join-Path $bar 'data'
Write-Host "BAR found: $bar"

# Shared code of the Level Editor and the BluePrinter (folder shared next to BluePrinter): checked before anything is copied
$sharedSrc = Join-Path (Join-Path (Split-Path $here -Parent) 'shared') 'editor_common.lua'
if (-not (Test-Path $sharedSrc)) { Fail 'File editor_common.lua missing (copy the shared folder next to BluePrinter as well).' }
$rulesSrc = Join-Path (Join-Path (Split-Path $here -Parent) 'shared') 'bar_rules.lua'
if (-not (Test-Path $rulesSrc)) { Fail 'File bar_rules.lua missing (copy the shared folder next to BluePrinter as well).' }

# Copy the widget
$wdir = Join-Path $data 'LuaUI\Widgets'
New-Item -ItemType Directory -Force $wdir | Out-Null
Copy-Item (Join-Path $here 'bluePrinter.lua') (Join-Path $wdir 'bluePrinter.lua') -Force
Write-Host "Widget copied to $wdir"

$idir = Join-Path $data 'LuaUI\Include'
New-Item -ItemType Directory -Force $idir | Out-Null
Copy-Item $sharedSrc (Join-Path $idir 'editor_common.lua') -Force
Copy-Item $rulesSrc (Join-Path $idir 'bar_rules.lua') -Force
Write-Host "Shared code copied to $idir"

# Folders for blueprints, via junction in the write folder of the game. User widgets in BAR may only write under LuaUI\Config
# (and only read under LuaUI), so the junctions live there.
$cfgDir = Join-Path $data 'LuaUI\Config'
New-Item -ItemType Directory -Force $cfgDir | Out-Null
Set-Junction (Join-Path $cfgDir 'BluePrinter') (Join-Path $here 'blueprints')
# Blueprints of the Level Editor (if the LevelEditor folder lies next to BluePrinter)
$leDir = Join-Path (Join-Path (Split-Path $here -Parent) 'LevelEditor') 'blueprints'
if (Test-Path $leDir) { Set-Junction (Join-Path $cfgDir 'LevelEditorBlueprints') $leDir }
Write-Host ''
Write-Host 'Done. In the game: Settings -> allow user widgets ("Allow user widgets") and then'
Write-Host 'F11 (widget list) -> switch BluePrinter on, if it is not on already.'
