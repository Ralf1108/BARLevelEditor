# LAN Play test with two instances of the game (host PlayerA, joiner PlayerB) and the real lobby on this computer, in two small windows.
#   -Sync same | missing | other   the extra game of the joiners: the host's version, none (default), or another version of their own
#   -Lobby same | other   the lobby widget of the joiners: the same file as the host's, or with one more comment line (another version)
#   -NoMap   the joiners have an empty maps folder (not the junction to the installed maps): the map comes from the host over LAN Play
#   -Clients 1 | 2   joiners (PlayerB, PlayerC)
#   -Mode ctf | rtf | td   the test level of that name (test-data\levels) as a scenario; cp = Copilot (two humans, one player, official map)
# Everything is built in -Work (own write dir per instance, junctions to the engine and game files of the installation): nothing of the installed game is changed.
# Run the Level Editor setup first (install_editor.bat): the lobby widget of the installation is not used, the one of this repository is, but the game files come from -Data.
# The widget zz_lantest.lua logs "[zzlan]" lines (teams, scores) into infolog.txt of both instances and quits the game at -QuitFrame.
param([string]$Mode = 'ctf', [int]$WaitSec = 420, [int]$QuitFrame = 4500, [string]$Sync = 'missing', [int]$Clients = 1, [string]$Lobby = 'same', [switch]$NoMap, [string]$Work = (Join-Path $env:TEMP 'lan_test'), [string]$Data = 'C:\Games\Beyond-All-Reason\data')
$sp = $Work; $real = $Data
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
. (Join-Path $repo 'shared\bar_common.ps1'); . (Join-Path $repo 'LevelEditor\scripts\editor_manifest.ps1')   # Write-ScenarioGame and its files
New-Item -ItemType Directory -Force $sp | Out-Null
if (Get-Process spring -ErrorAction SilentlyContinue) { 'A game is running: aborted'; return }
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W2 { [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); }
'@
$exe = (Get-ChildItem "$real\engine" -Directory | Select -Last 1).FullName + '\spring.exe'
$scn = "${Mode}_test"
if ($Mode -ne 'cp') {
    if (Test-Path "$sp\bundle_$scn") { Remove-Item "$sp\bundle_$scn" -Recurse -Force }
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\LevelEditor\scenario\scenario_builder.ps1" -Level $scn -LevelDir "$repo\LevelEditor\test-data\levels" -Auto -BundleDir "$sp\bundle_$scn" | Out-Null
}
$rects = @{ H = @(60, 60, 1300, 800); J = @(1400, 60, 1000, 700); K = @(1400, 780, 1000, 600) }
$who2 = @('H', 'J') + $(if ($Clients -ge 2) { 'K' })
$names = @{ H = 'PlayerA'; J = 'PlayerB'; K = 'PlayerC' }
$procs = @{}
$prev = [W2]::GetForegroundWindow()
foreach ($who in $who2) {
    $sbx = "$sp\sbx_$who"; $d = "$sbx\data"
    if (Test-Path $d) { foreach ($j in Get-ChildItem $d -Directory | ? { $_.Attributes -band 'ReparsePoint' }) { cmd /c rmdir "$($j.FullName)" } }
    if (Test-Path $sbx) { Remove-Item $sbx -Recurse -Force }
    New-Item -ItemType Directory "$d\cache", "$d\LuaMenu\Config", "$d\LuaMenu\Widgets", "$d\games", "$d\LuaUI\Widgets", "$d\LevelEditor" -Force | Out-Null
    foreach ($j in 'engine', 'packages', 'pool', 'rapid', 'maps') {
        if ($j -eq 'maps' -and $NoMap -and $who -ne 'H') { New-Item -ItemType Directory "$d\maps" -Force | Out-Null; continue }
        New-Item -ItemType Junction -Path "$d\$j" -Target "$real\$j" | Out-Null
    }
    Copy-Item (Get-ChildItem "$real\cache\ArchiveCache*.lua" | Sort LastWriteTime | Select -Last 1).FullName "$d\cache\"
    Copy-Item "$repo\LevelEditor\lan_lobby\lan_lobby.lua" "$d\LuaMenu\Widgets\"
    if ($who -ne 'H' -and $Lobby -eq 'other') { Add-Content "$d\LuaMenu\Widgets\lan_lobby.lua" "`n-- another version for the version test" -Encoding ASCII }
    Copy-Item "$repo\LevelEditor\scenario\template\shared_start.lua" "$d\LuaUI\Widgets\"
    Copy-Item "$tools\zz_lantest.lua" "$d\LuaUI\Widgets\"
    [IO.File]::WriteAllText("$d\zz_mode.txt", $Mode); [IO.File]::WriteAllText("$d\zz_quit.txt", "$QuitFrame")
    Set-Content "$d\LuaMenu\Config\IGL_data.lua" 'return { ["Chili lobby"] = { loadLocalWidgets = true } }' -Encoding ASCII
    Set-Content "$d\chobby_config.json" '{ "server": { "address": "127.0.0.1", "port": 8200, "protocol": "spring", "serverName": "LOCAL" }, "game": "byar" }' -Encoding ASCII
    if ($who -eq 'H') {
        New-Item -ItemType Directory "$d\LevelEditorScenarios" -Force | Out-Null
        if ($Mode -ne 'cp') { Copy-Item "$sp\bundle_$scn" "$d\LevelEditorScenarios\$scn" -Recurse }
        # the extra game of the scenarios from the files of this repository, as the setup builds it (with the file that names it)
        $sg = Write-ScenarioGame $d (Get-GameVersion $real) (Get-ScenarioGameDirs)
        Set-Content "$d\games\$ScenarioGamePointer" @($sg.File, $sg.Name) -Encoding ASCII
        $sg0 = $sg; $hostData = $d
        $auto = if ($Mode -eq 'cp') { "auto=host`nname=PlayerA`nplayers=2`nmap=Full Metal Plate 1.7`ncopilot=PlayerB`nstartDelay=14" } else { "auto=host`nname=PlayerA`nplayers=$($Clients + 1)`nscenario=$scn" }
    } else {
        $auto = "auto=join`nname=$($names[$who])`nip=127.0.0.1`nautoAccept=1$(if ($NoMap) { "`nnoOnline=1" })"
        if ($Sync -eq 'same') { Copy-Item (Join-Path $hostData "games\$($sg0.File)") "$d\games\"; Set-Content "$d\games\$ScenarioGamePointer" @($sg0.File, $sg0.Name) -Encoding ASCII }
        elseif ($Sync -eq 'other') {
            $alt = Join-Path $sp 'alt_src'; New-Item -ItemType Directory -Force $alt | Out-Null
            $first = $ScenarioGameFiles[0][0]
            $srcText = [IO.File]::ReadAllText((Join-Path (Get-EditorFolder 'scripts') $first)) + "`n-- another version for the sync test $who`n"
            [IO.File]::WriteAllText((Join-Path $alt $first), $srcText)
            $sgo = Write-ScenarioGame $d (Get-GameVersion $real) (@($alt) + (Get-ScenarioGameDirs))
            Set-Content "$d\games\$ScenarioGamePointer" @($sgo.File, $sgo.Name) -Encoding ASCII
            "joiner $who own version $($sgo.Version), host version $($sg0.Version)"
        }
    }
    [IO.File]::WriteAllText("$d\lanlobby_cfg.txt", $auto)
    $r = $rects[$who]
    [IO.File]::WriteAllLines("$sbx\springsettings.cfg", @('Fullscreen = 0', 'WindowBorderless = 0', "XResolution = $($r[2])", "YResolution = $($r[3])", "XResolutionWindowed = $($r[2])", "YResolutionWindowed = $($r[3])", "WindowPosX = $($r[0])", "WindowPosY = $($r[1])", 'LogFlushLevel = 0', 'InitialNetworkTimeout = 600', 'NetworkTimeout = 600', 'RapidTagResolutionOrder = repos-cdn.beyondallreason.dev;repos.beyondallreason.dev'))
    $procs[$who] = Start-Process $exe -ArgumentList @('--config', "`"$sbx\springsettings.cfg`"", '--write-dir', "`"$d`"", '--menu', '"BYAR Chobby test-4663-ecee530"') -PassThru
    "started $who pid $($procs[$who].Id)"
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt 20) { $procs[$who].Refresh(); if ($procs[$who].MainWindowHandle -ne [IntPtr]::Zero) { [void][W2]::SetWindowPos($procs[$who].MainWindowHandle, [IntPtr]1, 0, 0, 0, 0, 0x0013) }; [void][W2]::SetForegroundWindow($prev); Start-Sleep -Milliseconds 500 }
}
$start = Get-Date
while (((Get-Date) - $start).TotalSeconds -lt $WaitSec -and ((@($who2 | ? { -not $procs[$_].HasExited }).Count -gt 0))) {
    foreach ($who in $who2) { if (-not $procs[$who].HasExited) { $procs[$who].Refresh(); [void][W2]::SetWindowPos($procs[$who].MainWindowHandle, [IntPtr]1, 0, 0, 0, 0, 0x0013) } }
    Start-Sleep 3
}
foreach ($who in $who2) { if (-not $procs[$who].HasExited) { "timeout: killing $who"; try { Stop-Process -Id $procs[$who].Id -Force } catch {} } else { "$who ended itself" } }
