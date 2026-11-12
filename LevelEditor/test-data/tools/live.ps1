# Live test: sends commands to the running test game started with  pve_test.ps1 -Ren -Live ... (the widget zz_live.lua reads them once a second).
#   live.ps1 -Reload                       copies the widget files of the repository (renegade.lua) into the game's LuaUI\Widgets and reloads all widgets ("luaui reload")
#   live.ps1 -Shot                         takes a picture (<Work>\data\screenshots)
#   live.ps1 -Cmd 'cmd x', 'lua x', 'say x'  own lines (see zz_live.lua); they run after -Reload and before -Shot
#   -Wait n                                seconds to wait afterwards, then the new [zzlive] / [zz...] / [Renegade] lines of the log are shown
# Gadgets (renegade_game.lua) are not reloaded: they are synchronized, a change of them needs a new start.
param([switch]$Reload, [switch]$Shot, [string[]]$Cmd = @(), [int]$Wait = 4, [string]$Work = (Join-Path $env:TEMP 'pve_test'))
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
$d = Join-Path $Work 'data'
$log = Join-Path $d 'infolog.txt'
if (-not (Test-Path $log)) { 'no running test game (no infolog)'; exit 1 }
$before = @(Get-Content $log).Count
$lines = @()
if ($Reload) {
    Copy-Item (Join-Path $repo 'LevelEditor\scripts\renegade.lua') (Join-Path $d 'LuaUI\Widgets\renegade.lua') -Force
    Copy-Item (Join-Path $tools 'zz_live.lua') (Join-Path $d 'LuaUI\Widgets\zz_live.lua') -Force
    $lines += 'cmd luaui reload'
}
$lines += $Cmd
if ($Shot) { $lines += 'cmd screenshot png' }
$id = [Guid]::NewGuid().ToString('N').Substring(0, 8)
[IO.File]::WriteAllText((Join-Path $d 'LuaUI\Config\live_cmd.txt'), ($id + "`n" + ($lines -join "`n") + "`n"), (New-Object Text.UTF8Encoding $false))
Start-Sleep $Wait
Get-Content $log | Select-Object -Skip $before | Select-String -Pattern '\[zz|\[Renegade\]|Error|rror in|Failed' | ForEach-Object { $_.Line } | Select-Object -First 60
if ($Shot) { Get-ChildItem (Join-Path $d 'screenshots') | Sort-Object LastWriteTime | Select-Object -Last 1 | ForEach-Object { 'picture: ' + $_.FullName } }
