# Console lobby test ("Host Game" / "Join Game": start_scenario.ps1 -Lobby) with two starters on this computer, in two small windows.
#   -Mode ctf | rtf | td   the test level of that name (test-data\levels) built as a scenario
# Each starter gets its own "BAR folder" in -Work (barH, barJ: a data folder with junctions to engine, packages, pool, rapid, maps of the installation), so everything
# the starter writes (extra game, widgets, window settings) stays there; the installed game is not changed and must not be running.
# The starters run in minimized console windows (the lobby draws on a real console; hidden or redirected it fails).
# The widget zz_lantest.lua logs "[zzlan]" lines into infolog.txt (<work>\barH\data, <work>\barJ\data) and quits the game at the frame in zz_quit.txt (default 4500).
param([string]$Mode = 'ctf', [int]$WaitSec = 600, [string]$Work = (Join-Path $env:TEMP 'console_test'), [string]$Data = 'C:\Games\Beyond-All-Reason\data')
$ErrorActionPreference = 'Stop'
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
if (Get-Process spring -ErrorAction SilentlyContinue) { 'A game is running: aborted'; return }
$scn = "${Mode}_test"
New-Item -ItemType Directory -Force $Work | Out-Null
$bundle = "$Work\bundle_$scn"
if (Test-Path $bundle) { Remove-Item $bundle -Recurse -Force }
& powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\LevelEditor\scenario\scenario_builder.ps1" -Level $scn -LevelDir "$repo\LevelEditor\test-data\levels" -Auto -BundleDir $bundle | Out-Null
$rects = @{ H = '60,60,1300,800'; J = '1400,60,1000,700' }
foreach ($who in 'H', 'J') {
    $bar = "$Work\bar$who"; $d = "$bar\data"
    if (Test-Path $d) { foreach ($j in Get-ChildItem $d -Directory | ? { $_.Attributes -band 'ReparsePoint' }) { cmd /c rmdir "$($j.FullName)" } }
    if (Test-Path $bar) { Remove-Item $bar -Recurse -Force }
    New-Item -ItemType Directory "$d\cache", "$d\games", "$d\LuaUI\Widgets" -Force | Out-Null
    foreach ($j in 'engine', 'packages', 'pool', 'rapid', 'maps') { New-Item -ItemType Junction -Path "$d\$j" -Target "$Data\$j" | Out-Null }
    Copy-Item (Get-ChildItem "$Data\cache\ArchiveCache*.lua" | Sort LastWriteTime | Select -Last 1).FullName "$d\cache\"
    Copy-Item "$tools\zz_lantest.lua" "$d\LuaUI\Widgets\"
    [IO.File]::WriteAllLines("$d\springsettings.cfg", @('LogFlushLevel = 0', 'RapidTagResolutionOrder = repos-cdn.beyondallreason.dev;repos.beyondallreason.dev'))
}
$common = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$repo\LevelEditor\scenario\template\start_scenario.ps1", '-Lobby', '-HostIp', '127.0.0.1', '-ScenarioDir', $bundle, '-EditorDir', "$repo\LevelEditor")
$procs = @{}
$procs.H = Start-Process powershell -ArgumentList ($common + @('-BarPath', "$Work\barH", '-HostGame', '-Players', '2', '-LobbyAutoStart', '2', '-Name', 'Ralf', '-WindowRect', $rects.H)) -WindowStyle Minimized -PassThru
Start-Sleep 5
$procs.J = Start-Process powershell -ArgumentList ($common + @('-BarPath', "$Work\barJ", '-Join', '-JoinIp', '127.0.0.1', '-WaitForHost', '-Name', 'Ben', '-WindowRect', $rects.J)) -WindowStyle Minimized -PassThru
$start = Get-Date
while (((Get-Date) - $start).TotalSeconds -lt $WaitSec -and (-not $procs.H.HasExited -or -not $procs.J.HasExited)) { Start-Sleep 3 }
foreach ($who in 'H', 'J') {
    if (-not $procs[$who].HasExited) { "timeout: killing $who"; cmd /c "taskkill /T /F /PID $($procs[$who].Id)" | Out-Null } else { "$who ended itself" }
}
