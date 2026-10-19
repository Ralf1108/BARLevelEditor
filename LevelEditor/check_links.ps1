# Makes sure the junctions in the BAR data folder point to the levels and blueprints folders next to this script.
# Called by start_level_editor.bat before every start, so a moved or renamed project folder does not break saving.
param([Parameter(Mandatory)][string]$Data)
$here = $PSScriptRoot
. (Join-Path (Join-Path (Split-Path $here -Parent) 'shared') 'bar_common.ps1')
Set-Junction (Join-Path $Data 'LevelEditor') (Join-Path $here 'levels')
Set-Junction (Join-Path $Data 'LevelEditorBlueprints') (Join-Path $here 'blueprints')
