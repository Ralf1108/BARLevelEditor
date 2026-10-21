# Called by start_level_editor.bat before every start: runs the setup (install_editor.ps1 -Quick) when the extra game is missing or does not
# match the files of this folder (changed code, new BAR version). Nothing is done while the game is running (it holds the file).
param([Parameter(Mandatory)][string]$Data)
$here = $PSScriptRoot
. (Join-Path (Join-Path (Split-Path $here -Parent) 'shared') 'bar_common.ps1')
. (Join-Path $here 'editor_stamp.ps1')
$game = Get-GameVersion $Data
$sdz = Join-Path $Data 'games\LevelEditorMod.sdz'
$stampFile = Join-Path $Data 'games\LevelEditorMod.stamp'
$want = Get-EditorStamp $here $game
$have = if (Test-Path $stampFile) { (Get-Content $stampFile -Raw).Trim() } else { '' }
if ((Test-Path $sdz) -and $want -and $have -eq $want) { exit 0 }
if (Get-Process spring -ErrorAction SilentlyContinue) {
    Write-Host 'The Level Editor is not up to date, but a game is running: the update is skipped. Close the game and start again.' -ForegroundColor Yellow
    exit 0
}
Write-Host 'The Level Editor is not up to date: running the setup ...' -ForegroundColor Cyan
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $here 'install_editor.ps1') -Quick
if ($LASTEXITCODE -ne 0) { Write-Host 'The setup failed: the Level Editor starts with what is installed.' -ForegroundColor Yellow }
