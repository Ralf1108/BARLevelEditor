# Installs (or removes) LAN Play for the lobby of Beyond All Reason.
#   1. copies lan_lobby.lua to <data>\LuaMenu\Widgets\ (only when it differs)
#   2. sets ["Chili lobby"].loadLocalWidgets = true in <data>\LuaMenu\Config\IGL_data.lua (only when it is not set; the file is saved next to itself first)
# The widget only adds the entry "LAN Play" to the main menu; it changes nothing as long as LAN Play is not used (the normal Multiplayer works as before).
# Run by install_editor.ps1 (the Level Editor setup). The game and the launcher must not run: the lobby writes IGL_data.lua when it ends and would
# overwrite the change. -Uninstall removes the widget and sets loadLocalWidgets = false again.
param([string]$BarPath = $null, [switch]$Uninstall)
$ErrorActionPreference = 'Stop'
function Fail($m) { Write-Host $m -ForegroundColor Red; exit 1 }

if (-not $BarPath) {
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root })) {
        foreach ($p in 'Games\Beyond-All-Reason', 'Program Files\Beyond-All-Reason', 'Beyond-All-Reason') {
            if (Test-Path (Join-Path $d "$p\data")) { $BarPath = Join-Path $d $p; break }
        }
        if ($BarPath) { break }
    }
}
if (-not $BarPath -or -not (Test-Path (Join-Path $BarPath 'data'))) { Fail 'Beyond All Reason was not found. Give its folder with -BarPath.' }
$data = Join-Path $BarPath 'data'
if (Get-Process -Name 'spring', 'Beyond-All-Reason' -ErrorAction SilentlyContinue) { Fail 'The game or the launcher is running. Close it first (the lobby would overwrite the setting when it ends).' }

$widgetDir = Join-Path $data 'LuaMenu\Widgets'
$cfgDir = Join-Path $data 'LuaMenu\Config'
$cfg = Join-Path $cfgDir 'IGL_data.lua'
$widget = Join-Path $widgetDir 'lan_lobby.lua'
New-Item -ItemType Directory -Force $widgetDir, $cfgDir | Out-Null

function Set-LocalWidgets([bool]$on) {
    $value = if ($on) { 'true' } else { 'false' }
    if (-not (Test-Path $cfg)) { [IO.File]::WriteAllText($cfg, "return {`r`n`t[`"Chili lobby`"] = {`r`n`t`tloadLocalWidgets = $value,`r`n`t},`r`n}`r`n"); return }
    $t = [IO.File]::ReadAllText($cfg)
    $i = $t.IndexOf('["Chili lobby"]')
    if ($i -ge 0 -and $t.Substring($i) -match "loadLocalWidgets\s*=\s*$value\b") { return }   # already as wanted: the file is not touched
    Copy-Item $cfg ($cfg + '.bak_' + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    if ($i -lt 0) {
        $t = $t -replace '^(\s*return\s*\{)', ('$1' + "`r`n`t[`"Chili lobby`"] = {`r`n`t`tloadLocalWidgets = $value,`r`n`t},")
    } else {
        $head = $t.Substring(0, $i); $tail = $t.Substring($i)
        if ($tail -match 'loadLocalWidgets\s*=\s*(true|false)') { $tail = [regex]::Replace($tail, 'loadLocalWidgets\s*=\s*(true|false)', "loadLocalWidgets = $value", 1) }
        else { $tail = [regex]::Replace($tail, '(\["Chili lobby"\]\s*=\s*\{)', ('$1' + "`r`n`t`tloadLocalWidgets = $value,"), 1) }
        $t = $head + $tail
    }
    [IO.File]::WriteAllText($cfg, $t)
}

if ($Uninstall) {
    foreach ($f in $widget) { if (Test-Path $f) { Remove-Item $f -Force } }
    Set-LocalWidgets $false
    Write-Host "LAN Play removed from $data (loadLocalWidgets = false)." -ForegroundColor Green
    exit 0
}
$src = Join-Path $PSScriptRoot 'lan_lobby.lua'
if (-not (Test-Path $src)) { Fail "lan_lobby.lua is not next to this script ($PSScriptRoot)." }
if (-not (Test-Path $widget) -or (Get-FileHash $src).Hash -ne (Get-FileHash $widget).Hash) { Copy-Item $src $widget -Force; Write-Host 'Widget copied.' }
Set-LocalWidgets $true
Write-Host "LAN Play installed in $data." -ForegroundColor Green
Write-Host 'Start the game as usual: the main menu has the entry "LAN Play" below Multiplayer.'
