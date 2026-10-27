# Called by start_level_editor.bat before every start: brings an installed BluePrinter up to date, and runs the setup (install_editor.ps1 -Quick) when the extra game is missing or does not
# match the files of this folder (changed code, new BAR version). Nothing is done while the game is running (it holds the file).
param([Parameter(Mandatory)][string]$Data)
$here = $PSScriptRoot
$repo = Split-Path (Split-Path $here -Parent) -Parent   # repository
. (Join-Path (Join-Path $repo 'shared') 'bar_common.ps1')
. (Join-Path $here 'editor_stamp.ps1')
# The BluePrinter (widget for normal games) shares code with the editor but is only copied by its own setup: when it is installed, bring it up to
# date here too (three small files; a running game does not matter, it loads them at its next start or /luaui reload).
$bpDir = Join-Path $repo 'BluePrinter'
$bpPairs = @(
    @((Join-Path $bpDir 'bluePrinter.lua'), (Join-Path $Data 'LuaUI\Widgets\bluePrinter.lua')),
    @((Join-Path (Join-Path $repo 'shared') 'editor_common.lua'), (Join-Path $Data 'LuaUI\Include\editor_common.lua')),
    @((Join-Path (Join-Path $repo 'shared') 'bar_rules.lua'), (Join-Path $Data 'LuaUI\Include\bar_rules.lua')))
if ((Test-Path (Join-Path $bpDir 'bluePrinter.lua')) -and (Test-Path $bpPairs[0][1])) {
    $bpStale = $false
    foreach ($p in $bpPairs) { if ((Test-Path $p[0]) -and (-not (Test-Path $p[1]) -or (Get-FileHash $p[0]).Hash -ne (Get-FileHash $p[1]).Hash)) { $bpStale = $true } }
    if ($bpStale) {
        try {
            foreach ($p in $bpPairs) { if (Test-Path $p[0]) { Copy-Item $p[0] $p[1] -Force } }
            Write-Host 'The BluePrinter was updated (start a new game or type /luaui reload in a running one).' -ForegroundColor Cyan
        } catch { Write-Host ('The BluePrinter could not be updated: ' + $_.Exception.Message) -ForegroundColor Yellow }
    }
}
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
