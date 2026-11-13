# Runs every check that needs no game, one after the other, and says at the end which ones failed (exit code 1 when one did). Also what the GitHub Action runs.
#   lua_check.py   every Lua file compiles with Lua 5.1 (syntax, 200 locals, 60 upvalues, a call above the definition)
#   mock_test.py   the mock tests of the shared Lua code (tools\mock_*.lua)
#   doc_check.py   every link and anchor of the .md files
#   make_test_index.py --check   tests-index.md lists every test widget and is up to date
#   ps_test.ps1    the PowerShell code against a dummy data folder, the parse of every .ps1, no control characters
# Needs Python with the package lupa (pip install lupa) and git. The tests in the game (sandbox games) are not part of this, see specs\testing.md.
# Call: powershell -NoProfile -ExecutionPolicy Bypass -File LevelEditor\test-data\tools\run_checks.ps1
$tools = $PSScriptRoot
$python = if (Get-Command python -ErrorAction SilentlyContinue) { 'python' } elseif (Get-Command py -ErrorAction SilentlyContinue) { 'py' } else { $null }
if (-not $python) { Write-Host 'Python is not installed.' -ForegroundColor Red; exit 1 }
$results = @()
function Run-Check([string]$name, [scriptblock]$run) {
    Write-Host ""
    Write-Host "######## $name" -ForegroundColor Cyan
    & $run
    $ok = ($LASTEXITCODE -eq 0)
    $script:results += [pscustomobject]@{ Check = $name; Result = $(if ($ok) { 'ok' } else { 'FAILED' }) }
}
Run-Check 'lua_check.py' { & $python (Join-Path $tools 'lua_check.py') }
Run-Check 'mock_test.py' { & $python (Join-Path $tools 'mock_test.py') }
Run-Check 'doc_check.py' { & $python (Join-Path $tools 'doc_check.py') }
Run-Check 'test index' { & $python (Join-Path $tools '..\generators\make_test_index.py') --check }
Run-Check 'ps_test.ps1' { & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $tools 'ps_test.ps1') }
Remove-Item (Join-Path $tools '__pycache__') -Recurse -Force -ErrorAction SilentlyContinue
Write-Host ""
Write-Host "######## summary" -ForegroundColor Cyan
$results | Format-Table -AutoSize | Out-String | Write-Host
if ($results | Where-Object { $_.Result -ne 'ok' }) { exit 1 }
Write-Host 'all checks passed'
