# Makes sure the junctions in the BAR data folder point to the levels and blueprints folders next to the scripts folder.
# Called by start_level_editor.bat before every start, so a moved or renamed project folder does not break saving.
param([Parameter(Mandatory)][string]$Data)
$here = $PSScriptRoot
$root = Split-Path $here -Parent         # LevelEditor
$repo = Split-Path $root -Parent         # repository
. (Join-Path (Join-Path $repo 'shared') 'bar_common.ps1')
Set-Junction (Join-Path $Data 'LevelEditor') (Join-Path $root 'levels')
Set-Junction (Join-Path $Data 'LevelEditorBlueprints') (Join-Path $root 'blueprints')
