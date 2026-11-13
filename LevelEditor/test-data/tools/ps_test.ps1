# Tests of the PowerShell code outside the game (no BAR needed, a dummy data folder in the temp folder):
#   - shared\bar_common.ps1: Get-Engine (newest version, not the newest name; a folder without spring.exe is ignored), Get-VersionsText (any rapid\<repository>\byar\versions.gz),
#     Get-GameVersion, Get-AiSpec, Resolve-ExtraGame
#   - the quick start scripts start_renegade.ps1 and start_evolution.ps1 with -DryRun: the start script they write (map, computer player, game options, the extra game)
#   - every tracked .ps1 file parses, and no tracked text file holds a control character (what a backslash in a patch script turns into: \b, \t, \r)
# Call: powershell -NoProfile -ExecutionPolicy Bypass -File LevelEditor\test-data\tools\ps_test.ps1      (exit code 1 when a check fails)
$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
. (Join-Path $repo 'shared\bar_common.ps1')
$script:failed = 0; $script:checks = 0
function Check([bool]$ok, [string]$text) {
    $script:checks++
    if (-not $ok) { $script:failed++; Write-Host "  FAIL $text" -ForegroundColor Red }
}
function Group([string]$name) { Write-Host "== $name" }

$work = Join-Path ([IO.Path]::GetTempPath()) ('ps_test_' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$data = Join-Path $work 'data'
try {
    # ---- the dummy data folder: engines, a version list in an unusual repository folder, a package, the pointer of the extra game
    foreach ($e in @('recoil_2025.04.7', 'recoil_2025.04.10', 'recoil_2024.12.20')) {
        New-Item -ItemType Directory -Force (Join-Path $data "engine\$e") | Out-Null
        Set-Content (Join-Path $data "engine\$e\spring.exe") 'x'
    }
    New-Item -ItemType Directory -Force (Join-Path $data 'engine\recoil_2099.01.1') | Out-Null   # (no spring.exe: ignored)
    $rapid = Join-Path $data 'rapid\repos.example.org\byar'
    New-Item -ItemType Directory -Force $rapid, (Join-Path $data 'packages'), (Join-Path $data 'games') | Out-Null
    $lines = "byar:test,aaaa1111,,Beyond All Reason test-27000-abcdef`nbyar:stable,bbbb2222,,Beyond All Reason test-26000-123456`n"
    $fs = [IO.File]::Create((Join-Path $rapid 'versions.gz'))
    $gz = New-Object IO.Compression.GZipStream($fs, [IO.Compression.CompressionMode]::Compress)
    $bytes = [Text.Encoding]::UTF8.GetBytes($lines); $gz.Write($bytes, 0, $bytes.Length); $gz.Close(); $fs.Close()
    Set-Content (Join-Path $data 'packages\bbbb2222.sdp') 'x'
    Set-Content (Join-Path $data "games\$ScenarioGamePointer") "pointer`nLevel Editor Scenarios abc12345"

    Group 'Get-Engine'
    $engine = Get-Engine $data
    Check ($engine.Name -eq 'recoil_2025.04.10') "the newest version is taken, not the newest name (2025.04.10 after 2025.04.7): $($engine.Name)"

    Group 'Get-VersionsText, Get-GameVersion'
    $text = Get-VersionsText $data
    Check ($text -and $text.Contains('byar:test,aaaa1111')) 'a versions.gz in any rapid\<repository>\byar folder is found'
    $empty = Join-Path $work 'empty'
    New-Item -ItemType Directory -Force $empty | Out-Null
    Check ($null -eq (Get-VersionsText $empty)) 'without a rapid folder: no text'
    $env:BAR_GAME_VERSION = $null
    Check ((Get-GameVersion $data) -eq 'Beyond All Reason test-26000-123456') 'the game whose package is installed (stable), not the newer test line without a package'
    Remove-Item (Join-Path $data 'packages\bbbb2222.sdp')
    Check ((Get-GameVersion $data) -eq 'Beyond All Reason test-27000-abcdef') 'no package installed: the first line of byar:test is taken'

    Group 'Get-AiSpec'
    Check ((Get-AiSpec 'BARb').Short -eq 'BARb' -and (Get-AiSpec 'BARb').Version -eq 'stable') 'BARb'
    Check ((Get-AiSpec 'CircuitAI easy').Short -eq 'CircuitAI' -and (Get-AiSpec 'CircuitAI easy').Profile -eq 'easy') 'CircuitAI easy: the profile'
    Check ((Get-AiSpec 'ScavengersAI').Short -eq 'ScavengersAI' -and (Get-AiSpec 'SimpleAI').Version -eq '<not-versioned>') 'a Lua AI keeps its name and has no version'
    Check ((Get-AiSpec 'nonsense').Short -eq 'NullAI') 'an unknown name gives NullAI'

    Group 'Resolve-ExtraGame'
    $ctx = Resolve-ExtraGame $data
    Check ($ctx.Game -eq 'Level Editor Scenarios abc12345') "the name of the extra game is the second line of the pointer: $($ctx.Game)"
    Check ($ctx.Exe -eq (Join-Path $engine.FullName 'spring.exe') -and $ctx.Data -eq $data) 'the engine and the data folder'

    Group 'start_renegade.ps1 -DryRun'
    $ren = Join-Path $repo 'LevelEditor\scripts\start_renegade.ps1'
    $renFile = Join-Path $repo 'LevelEditor\renegade_script_installed.txt'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ren -Data $data -DryRun -Map 'Some Map 1.0' -Ai BARb -Bots 4 -QuickTest | Out-Null
    $s = Get-Content $renFile -Raw
    Check ($LASTEXITCODE -eq 0) 'the script ends without an error'
    Check ($s -match 'mapname=Some Map 1\.0;') 'the map'
    Check ($s -match 'gametype=Level Editor Scenarios abc12345;') 'the extra game'
    Check ($s -match 'shortname=BARb;') 'the computer player'
    Check ($s -match 'lanrenegade=1;' -and $s -match 'lanrenebots=4;' -and $s -match 'lanrenedebug=1;') 'the game options of Renegade'
    Check ($s -notmatch 'forceallunits') '-QuickTest: no extra units'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $ren -Data $data -DryRun -DebugMode 0 | Out-Null
    $s = Get-Content $renFile -Raw
    Check ($s -match 'forceallunits=1;' -and $s -match 'releasecandidates=1;') 'without -QuickTest: all units'
    Check ($s -notmatch 'lanrenedebug') '-DebugMode 0: no debug menu'
    Check ($s -match 'mapname=Hooked 1\.1;' -and $s -match 'lanrenebots=3;' -and $s -match 'shortname=NullAI;') 'the defaults: Hooked 1.1, 3 bots, NullAI'

    Group 'start_evolution.ps1 -DryRun'
    $evo = Join-Path $repo 'LevelEditor\scripts\start_evolution.ps1'
    $evoFile = Join-Path $repo 'LevelEditor\evolution_script_installed.txt'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $evo -Data $data -DryRun -Map 'Other Map' -Ai SimpleAI | Out-Null
    $s = Get-Content $evoFile -Raw
    Check ($LASTEXITCODE -eq 0) 'the script ends without an error'
    Check ($s -match 'mapname=Other Map;' -and $s -match 'shortname=SimpleAI;') 'the map and the computer player'
    Check ($s -match 'lanevolution=1;' -and $s -match 'lanevodebug=1;' -and $s -match 'experimentallegionfaction=1;') 'the game options of Evolution'
    & powershell -NoProfile -ExecutionPolicy Bypass -File $evo -Data $data -DryRun -DebugMode 0 | Out-Null
    Check ((Get-Content $evoFile -Raw) -notmatch 'lanevodebug') '-DebugMode 0: no debug mode'

    Group 'no extra game installed'
    $bare = Join-Path $work 'bare\data'
    New-Item -ItemType Directory -Force (Join-Path $bare 'games'), (Join-Path $bare 'engine\recoil_1.0\') | Out-Null
    $out = & powershell -NoProfile -ExecutionPolicy Bypass -File $ren -Data $bare -DryRun 2>&1 | Out-String
    Check ($out -match 'not installed') 'a missing pointer says to run install_editor.bat'
} finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}

Group 'parse every tracked .ps1 file'
$files = @(& git -C $repo ls-files '*.ps1')
Check ($files.Count -gt 20) "the list of files: $($files.Count)"
foreach ($f in $files) {
    $errs = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile((Join-Path $repo $f), [ref]$null, [ref]$errs)
    Check ($errs.Count -eq 0) "$f parses ($($errs.Count) errors; first: $(if ($errs.Count) { $errs[0].Message + ' line ' + $errs[0].Extent.StartLineNumber }))"
}

Group 'no control characters in tracked text files'
$text = @(& git -C $repo ls-files '*.lua' '*.ps1' '*.py' '*.md' '*.bat' '*.csv' '*.txt')
foreach ($f in $text) {
    $path = Join-Path $repo $f
    if (-not (Test-Path $path)) { continue }
    $bytes = [IO.File]::ReadAllBytes($path)
    $bad = $null
    for ($i = 0; $i -lt $bytes.Length; $i++) {
        $b = $bytes[$i]
        if ($b -lt 32 -and $b -ne 9 -and $b -ne 10 -and $b -ne 13) { $bad = "byte $b at $i"; break }
    }
    Check ($null -eq $bad) "$f has a control character ($bad)"
}

Write-Host ("{0} checks, {1} failed" -f $script:checks, $script:failed)
if ($script:failed) { exit 1 }
Write-Host 'ps tests: all passed'
