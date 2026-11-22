# The regression set of the tests in the game: runs the test widgets that give a verdict (OK / WRONG lines), one sandbox game after the other (never two
# at once: a game needs 8 to 10 GB), and ends with a table; exit code 1 when one failed. A test takes 1 to 4 minutes, the whole set about an hour.
#   -List            only prints the set
#   -Only a,b        only the tests whose name holds one of these texts (e.g. -Only lava  or  -Only zz_teams,zz_save)
#   -Group editor|lava|modes|blueprinter   only one group
#   -AlongsideGame   also when a game runs (passed on to arena_test.ps1; pve_test.ps1 and bp_test.ps1 always run next to a game)
# A new test widget with OK / WRONG lines is added to $set below. The widgets that only log values or take pictures (tools\probes, see
# ..\README.md) are not part of it. The log of each game: <temp>\arena_test, pve_test or bp_test \data\infolog.txt (the last game of each tool).
# Call: powershell -NoProfile -ExecutionPolicy Bypass -File LevelEditor\test-data\tools\run_game_tests.ps1 [-Only lava]
param([switch]$List, [string[]]$Only = @(), [string]$Group = '', [switch]$AlongsideGame)
$tools = $PSScriptRoot
$set = @(
    @{ Group = 'editor'; Name = 'zz_arena'; Tool = 'arena_test.ps1'; Args = @{} }
    @{ Group = 'editor'; Name = 'zz_keep'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_keep.lua' } }
    @{ Group = 'editor'; Name = 'zz_teams'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_teams.lua' } }
    @{ Group = 'editor'; Name = 'zz_copy'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_copy.lua' } }
    @{ Group = 'editor'; Name = 'zz_features'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_features.lua' } }
    @{ Group = 'editor'; Name = 'zz_cycle'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_cycle.lua' } }
    @{ Group = 'editor'; Name = 'zz_save'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_save.lua' } }
    @{ Group = 'editor'; Name = 'zz_scenario'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_scenario.lua' } }
    @{ Group = 'editor'; Name = 'zz_export'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_export.lua' } }
    @{ Group = 'editor'; Name = 'zz_cmdbuttons'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_cmdbuttons.lua' } }
    @{ Group = 'editor'; Name = 'zz_split_ally'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_split_ally.lua' } }
    @{ Group = 'editor'; Name = 'zz_camreset'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_camreset.lua' } }
    @{ Group = 'modes'; Name = 'zz_modes'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_modes.lua' } }
    @{ Group = 'modes'; Name = 'zz_pve'; Tool = 'pve_test.ps1'; Args = @{} }
    @{ Group = 'modes'; Name = 'zz_brood'; Tool = 'pve_test.ps1'; Args = @{ Brood = $true; Widget = 'zz_brood.lua' } }
    @{ Group = 'modes'; Name = 'zz_ren98'; Tool = 'pve_test.ps1'; Args = @{ Ren = $true; RenTest = $true; RenMode = 'race'; Quick = $true; Widget = 'zz_ren98.lua' } }
    @{ Group = 'lava'; Name = 'zz_volcano'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_volcano.lua' } }
    @{ Group = 'lava'; Name = 'zz_lavagen'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_lavagen.lua' } }
    @{ Group = 'lava'; Name = 'zz_lavabelt'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_lavabelt.lua' } }
    @{ Group = 'lava'; Name = 'zz_lava'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_lava.lua' } }
    @{ Group = 'lava'; Name = 'zz_lavafork'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_lavafork.lua' } }
    @{ Group = 'lava'; Name = 'zz_lavatruck'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_lavatruck.lua' } }
    @{ Group = 'lava'; Name = 'zz_lavaroad'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_lavaroad.lua' } }
    @{ Group = 'lava'; Name = 'zz_lavaauto'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_lavaauto.lua' } }
    @{ Group = 'lava'; Name = 'zz_expunits'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_expunits.lua' } }
    @{ Group = 'lava'; Name = 'zz_expdemo'; Tool = 'arena_test.ps1'; Args = @{ Widget = 'zz_expdemo.lua'; ModOptions = 'lanexpdemo=1;' } }
    @{ Group = 'blueprinter'; Name = 'zz_bpfaction'; Tool = 'bp_test.ps1'; Args = @{ Widget = 'zz_bpfaction.lua' } }
    @{ Group = 'blueprinter'; Name = 'zz_bpt'; Tool = 'bp_test.ps1'; Args = @{ Widget = 'zz_bpt.lua' } }
    @{ Group = 'blueprinter'; Name = 'zz_bpo'; Tool = 'bp_test.ps1'; Args = @{ Widget = 'zz_bpo.lua' } }
)
$run = @(foreach ($t in $set) {
        if ($Group -and $t.Group -ne $Group) { continue }
        if ($Only.Count -and -not @($Only | Where-Object { $t.Name -like "*$_*" }).Count) { continue }
        $t
    })
if ($List) { $run | ForEach-Object { [pscustomobject]@{ Group = $_.Group; Test = $_.Name; Tool = $_.Tool } } | Format-Table -AutoSize | Out-String | Write-Host; Write-Host "$($run.Count) tests"; exit 0 }
if (-not $run.Count) { 'No test matches.'; exit 1 }
$results = @()
$i = 0
foreach ($t in $run) {
    $i++
    Write-Host ""
    Write-Host "######## $i / $($run.Count): $($t.Name) ($($t.Tool))" -ForegroundColor Cyan
    $a = $t.Args.Clone()
    if ($AlongsideGame -and $t.Tool -eq 'arena_test.ps1') { $a.AlongsideGame = $true }
    $t0 = Get-Date
    $out = @(& (Join-Path $tools $t.Tool) @a)
    $failed = ($LASTEXITCODE -ne 0)
    $verdict = @($out | Where-Object { $_ -match '^VERDICT: ' } | Select-Object -Last 1)
    $text = if ($verdict.Count) { $verdict[0] -replace '^VERDICT: ', '' } else { $failed = $true; 'not run: ' + (@($out | Select-Object -Last 1) -join '') }
    if ($failed) { $out | Where-Object { $_ -match '\[zz\w*\].*\b(WRONG|FAIL|FAILED)\b|attempt to|traceback|Error in ' } | Select-Object -First 15 | ForEach-Object { Write-Host "  $_" } }
    Write-Host "  $text"
    $results += [pscustomobject]@{ Test = $t.Name; Result = $(if ($failed) { 'FAILED' } else { 'ok' }); Seconds = [int]((Get-Date) - $t0).TotalSeconds; Verdict = $text }
}
Write-Host ""
Write-Host "######## summary" -ForegroundColor Cyan
$results | Format-Table -AutoSize -Wrap | Out-String | Write-Host
$bad = @($results | Where-Object { $_.Result -ne 'ok' }).Count
if ($bad) { Write-Host "$bad of $($results.Count) tests failed"; exit 1 }
Write-Host "all $($results.Count) tests passed"
