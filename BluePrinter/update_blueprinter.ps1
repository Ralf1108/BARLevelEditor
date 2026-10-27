# Brings the installed BluePrinter up to date: runs the setup (install_blueprinter.ps1) when a file differs from the repository or the BluePrinter
# is not installed. Dot-sourced by start_blueprinter.ps1 and start_blueprinter_test.ps1; sets $bar and $data.
$here = $PSScriptRoot
$shared = Join-Path (Split-Path $here -Parent) 'shared'
. (Join-Path $shared 'bar_common.ps1')
$bar = Find-Bar
$data = Join-Path $bar 'data'
$pairs = @(
    @((Join-Path $here 'bluePrinter.lua'), (Join-Path $data 'LuaUI\Widgets\bluePrinter.lua')),
    @((Join-Path $shared 'editor_common.lua'), (Join-Path $data 'LuaUI\Include\editor_common.lua')),
    @((Join-Path $shared 'bar_rules.lua'), (Join-Path $data 'LuaUI\Include\bar_rules.lua')))
$stale = -not (Test-Path (Join-Path $data 'LuaUI\Config\BluePrinter'))
foreach ($p in $pairs) {
    if (-not (Test-Path $p[1]) -or (Get-FileHash $p[0]).Hash -ne (Get-FileHash $p[1]).Hash) { $stale = $true }
}
if ($stale) {
    Write-Host 'The BluePrinter is not up to date: running the setup ...' -ForegroundColor Cyan
    . (Join-Path $here 'install_blueprinter.ps1')
} else {
    Write-Host 'The BluePrinter is up to date.'
}
