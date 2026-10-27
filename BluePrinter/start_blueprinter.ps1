# Makes sure the newest BluePrinter is installed and starts the normal Beyond All Reason (the launcher) with it (run through start_blueprinter.bat).
# The BluePrinter is a widget: in the game switch on Settings -> allow user widgets, then F11 -> BluePrinter (once; BAR remembers it).
# For a small test game with a passive opponent use start_blueprinter_test.bat.
$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'update_blueprinter.ps1')
$exe = Join-Path $bar 'Beyond-All-Reason.exe'
if (-not (Test-Path $exe)) { Fail "Beyond-All-Reason.exe not found in $bar" }
Write-Host 'Starting Beyond All Reason ...'
Start-Process $exe -WorkingDirectory $bar
