# LAN Play test with two instances of the game (host PlayerA, joiner PlayerB) and the real lobby on this computer, in two small windows.
#   -Sync same | missing | other   the extra game of the joiners: the host's version, none (default), or another version of their own
#   -Lobby same | other   the lobby widget of the joiners: the same file as the host's, or with one more comment line (another version)
#   -NoMap   the joiners have an empty maps folder (not the junction to the installed maps): the map comes from the host over LAN Play
#   -KeepOnline   with -NoMap: the lobby of the joiner may download the map online (without it the test cancels that download)
#   -MapList none | official | wrong   the list of official map md5 of the joiners: none, the real one (fetched online), or one with a wrong md5
#   -AlongsideGame   run next to a game you are playing (only the processes of the test are ever stopped)
#   -Clients 1 | 2   joiners (PlayerB, PlayerC)
#   -ClickAt 56   (evoroom) at that second a click into the chat area of the host's window: the menus of the room must close (with -Shots after it)
#   -Shots 20,45   pictures of the window of the host (seconds after the start): shot_<s>.png in -Work (PrintWindow: the window may stay behind others;
#                  gl.SaveImage and a copy of the screen come out black or disturb); -FrontShots: the window is brought to the front and the screen is copied
#                  (for the lobby, when PrintWindow gives a white picture; it takes the focus for a moment)
#   -Mode ctf | rtf | td   the test level of that name (test-data\levels) as a scenario; cp = Copilot (two humans, one player, official map);
#         evo = Evolution on an official map (-Map, default Comet Catcher Remake 1.8): the host presses the button Evolution, PlayerA, PlayerB and a BARb computer
#               (-Ai, default BARb) play each other; zz_lantest.lua logs the stages and sends the units of both players into the middle and takes screenshots;
#               -EvoStage 10: everybody starts on that stage (Armageddon at once; PlayerA chooses the gift Gates of Hell, PlayerB Hell on Earth)
#         evoroom = one instance, the host's room with Evolution switched on (the window with the rules, closed at 40 s of the lobby; then the menu of the button LAN Play opens) and a BARb computer, no game: pictures with -Shots, -WaitSec ends it
#         boss = the host makes the joiner boss (the menu's Make Boss: !boss <name>) and takes it away again; log lines "test: ... isBoss" in the infolog of the host
#         pve = the host adds a Raptors computer (-Ai RaptorsAI | ScavengersAI) to its ally team, both players place their start position (a click into the middle of the window, the
#               widget zz_place.lua points the camera at the start box) and press ready; zz_pve.lua (host) measures the orders of the AI and of the human (lan_pve_hold.lua)
#         preset = (-PresetFile <optionsPresets.json> -PresetName <preset in it>, otherwise a small own preset) one instance, the host's room, the Option Presets of the lobby: a preset file is written, the real panel opened, the preset chosen and loaded; log "test: preset"
#               lines with the values of the room before and after (no game is started: -WaitSec 90)
#         rejoin = host + joiner place their start positions, the game runs; then the joiner's game is killed and started again (same folder, auto join): does the room offer a rejoin?
#               (log of the first run: infolog_first.txt of the joiner; use -QuitFrame 60000)
#         -Solo with evo: one instance, the host and the computer only; zz_evo2.lua checks energy, wild units and towers, the radars (taking, cannot be destroyed, T2)
#               (best with -EvoStage 5 -QuitFrame 9000)
#         brood = one instance: the host alone with a Raptors computer in its ally team (the lobby adds the Raptor Brood Chamber, game option tweakdefs<N>); places its start
#               position, zz_brood.lua has a healer build the chamber and the chamber grow raptors (use -QuitFrame 60000: zz_brood.lua ends the game itself)
#         mix = Raptors against Scavengers: host (PlayerA) with a Raptors computer in team 1, joiner (PlayerB) with a Scavengers computer in team 2, both place their start position;
#               zz_mix.lua (host, not with -Play) speeds the game up and logs units, distances and deaths of both computers. -Play: a game to play (no test widgets, no speed-up, no end by itself)
#         page = one instance, the LAN Play page opened and left alone (pictures of the page with -Shots, -WaitSec 60 ends it)
#         teams = the buttons "3 teams" / "2 per team" of the room (log: lan_status.txt in the data folder of the host; pictures with -Shots)
# Everything is built in -Work (own write dir per instance, junctions to the engine and game files of the installation): nothing of the installed game is changed.
# Run the Level Editor setup first (install_editor.bat): the lobby widget of the installation is not used, the one of this repository is, but the game files come from -Data.
# The widget zz_lantest.lua logs "[zzlan]" lines (teams, scores) into infolog.txt of both instances and quits the game at -QuitFrame.
param([string]$Mode = 'ctf', [switch]$Solo, [int]$ClickAt = 0, [int]$WaitSec = 420, [int]$QuitFrame = 4500, [string]$Sync = 'missing', [int]$Clients = 1, [string]$Lobby = 'same', [switch]$NoMap, [switch]$KeepOnline, [string]$MapList = 'none', [string]$Ai = 'RaptorsAI', [string]$PresetFile = '', [string]$PresetName = '', [string]$Work = (Join-Path $env:TEMP 'lan_test'), [string]$Data = '', [string]$Shots = '', [switch]$AlongsideGame, [switch]$Play, [string]$Map = 'Comet Catcher Remake 1.8', [switch]$FrontShots, [int]$EvoStage = 0)
$sp = $Work
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
. (Join-Path $repo 'shared\bar_common.ps1'); . (Join-Path $repo 'LevelEditor\scripts\editor_manifest.ps1')   # Write-ScenarioGame and its files
. (Join-Path $tools 'test_common.ps1')   # the sandbox data folder, the window settings, starting a game behind the other windows
$Data = Resolve-TestData $Data   # the data folder of the installation (-Data, otherwise Find-Bar of bar_common.ps1)
$real = $Data
New-Item -ItemType Directory -Force $sp | Out-Null
if (-not $AlongsideGame -and (Get-Process spring -ErrorAction SilentlyContinue)) { 'A game is running: aborted'; return }
$exe = (Get-Engine $real).FullName + '\spring.exe'   # the newest engine (sorted by version, Get-Engine of bar_common.ps1)
$scn = "${Mode}_test"
if ($Mode -notin 'cp', 'teams', 'page', 'boss', 'pve', 'preset', 'rejoin', 'latejoin', 'mix', 'evo', 'evoroom') {
    if (Test-Path "$sp\bundle_$scn") { Remove-Item "$sp\bundle_$scn" -Recurse -Force }
    & powershell -NoProfile -ExecutionPolicy Bypass -File "$repo\LevelEditor\scenario\scenario_builder.ps1" -Level $scn -LevelDir "$repo\LevelEditor\test-data\levels" -Auto -BundleDir "$sp\bundle_$scn" | Out-Null
}
# windows: the left half of the screen in quarters (host top left, first joiner bottom left, second joiner top right); the size is the inside of the window (title bar and frame left out)
Add-Type -AssemblyName System.Windows.Forms
Add-Type -Name Dpi -Namespace W7 -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[void][W7.Dpi]::SetProcessDPIAware()   # otherwise the screen size is the scaled one (2560 x 1440 for 3840 x 2160 at 150 %), the engine works with the real pixels
$wa = [Windows.Forms.Screen]::PrimaryScreen.Bounds
$qw = [int]($wa.Width / 2) - 16; $qh = [int]($wa.Height / 2) - 80
$rects = @{ H = @(0, 0, $qw, $qh); J = @(0, [int]($wa.Height / 2), $qw, $qh); K = @([int]($wa.Width / 2), 0, $qw, $qh) }
$who2 = if ($Mode -in 'page', 'preset', 'evoroom', 'brood' -or ($Mode -eq 'evo' -and $Solo)) { @('H') } else { @('H', 'J') + $(if ($Clients -ge 2) { 'K' }) }
$names = @{ H = 'PlayerA'; J = 'PlayerB'; K = 'PlayerC' }
$procs = @{}
$prev = [SbxWin]::GetForegroundWindow()
$menu = Get-SandboxLobby $real   # the installed lobby package (its name changes with every lobby update)
foreach ($who in $who2) {
    $sbx = "$sp\sbx_$who"
    $d = New-SandboxData $sbx $real @('LuaMenu\Config', 'LuaMenu\Widgets', 'LevelEditor') -NoMaps:($NoMap -and $who -ne 'H')
    Copy-Item "$repo\LevelEditor\lan_lobby\lan_lobby.lua" "$d\LuaMenu\Widgets\"
    Copy-Item "$repo\LevelEditor\lan_lobby\raptor_brood_defs.lua" "$d\LuaMenu\Config\lan_raptor_brood.txt"   # as install_lan_play.ps1 does
    if ($who -ne 'H' -and $Lobby -eq 'other') { Add-Content "$d\LuaMenu\Widgets\lan_lobby.lua" "`n-- another version for the version test" -Encoding ASCII }
    Copy-Item "$repo\LevelEditor\scenario\template\shared_start.lua" "$d\LuaUI\Widgets\"
    if (-not $Play) { Copy-Item "$tools\zz_lantest.lua" "$d\LuaUI\Widgets\" }   # -Play: no test widgets, the game is played
    if ($Mode -eq 'mix' -and $who -eq 'H' -and -not $Play) { Copy-Item "$tools\zz_mix.lua" "$d\LuaUI\Widgets\" }
    if ($Mode -in 'pve', 'rejoin', 'mix', 'brood' -or ($Mode -eq 'latejoin' -and $who -eq 'H')) { Copy-Item "$tools\zz_place.lua" "$d\LuaUI\Widgets\" }
    if ($Mode -eq 'evo' -and $Solo -and $who -eq 'H' -and -not $Play) { Copy-Item "$tools\zz_evo2.lua" "$d\LuaUI\Widgets\" }   # energy, wild units, towers, radars
    if ($Mode -eq 'brood' -and -not $Play) { Copy-Item "$tools\zz_brood.lua" "$d\LuaUI\Widgets\" }   # the Raptor Brood Chamber through the real lobby
    if ($Mode -eq 'pve' -and $who -eq 'H') { Copy-Item "$tools\zz_pve.lua" "$d\LuaUI\Widgets\" }
    [IO.File]::WriteAllText("$d\zz_mode.txt", $Mode); [IO.File]::WriteAllText("$d\zz_quit.txt", "$QuitFrame")
    # the lobby (Chobby) puts the window to the full screen in the menu and again when a game starts, unless its window mode is 6 (manual window): lobby and game in this window
    $rc = $rects[$who]; $box = "{ x = $($rc[0]), y = $($rc[1]), width = $($rc[2]), height = $($rc[3]) }"
    Set-Content "$d\LuaMenu\Config\IGL_data.lua" "return { [`"Chili lobby`"] = { loadLocalWidgets = true, lobby_fullscreen = 6, game_fullscreen = 6, manualWindowed = { lobby = $box, game = $box } } }" -Encoding ASCII
    # the news popup of the lobby (tournaments etc., one per phase with its own "do not notify again") covers the battle room and catches the clicks of the test: switched off (0 = off)
    Set-Content "$d\LuaMenu\Config\IGL_order.lua" 'return { ["Super Announcement Notifier 1.02"] = 0 }' -Encoding ASCII
    Set-Content "$d\chobby_config.json" '{ "server": { "address": "127.0.0.1", "port": 8200, "protocol": "spring", "serverName": "LOCAL" }, "game": "byar" }' -Encoding ASCII
    if ($who -eq 'H') {
        New-Item -ItemType Directory "$d\LevelEditorScenarios" -Force | Out-Null
        if ($Mode -notin 'cp', 'teams', 'page', 'boss', 'pve', 'preset', 'rejoin', 'latejoin', 'mix', 'evo', 'evoroom', 'brood') { Copy-Item "$sp\bundle_$scn" "$d\LevelEditorScenarios\$scn" -Recurse }
        # the extra game of the scenarios from the files of this repository, as the setup builds it (with the file that names it)
        $sg = Write-ScenarioGame $d (Get-GameVersion $real) (Get-ScenarioGameDirs)
        Set-Content "$d\games\$ScenarioGamePointer" @($sg.File, $sg.Name) -Encoding ASCII
        $sg0 = $sg; $hostData = $d
        $auto = if ($Mode -eq 'boss') { "auto=host`nname=PlayerA`nplayers=2`nmap=Full Metal Plate 1.7`nboss=1`nstartDelay=600" } elseif ($Mode -eq 'page') { "openTab=1`nname=PlayerA" } elseif ($Mode -eq 'teams') { "auto=host`nname=PlayerA`nplayers=2`nmap=Full Metal Plate 1.7`nteams=3`nteamSize=2`ndump=14`nstartDelay=600" } elseif ($Mode -eq 'preset') { "auto=host`nname=PlayerA`nplayers=99`nmap=Hooked 1.1`npresetTest=1$(if ($PresetName) { "`npresetName=$PresetName" })" } elseif ($Mode -eq 'mix') { "auto=host`nname=PlayerA`nplayers=2`nmap=Full Metal Plate 1.7`nbot=RaptorsAI`nbotAlly=0`nbot2=ScavengersAI`nbot2Ally=1`nstartDelay=25" } elseif ($Mode -eq 'latejoin') { "auto=host`nname=PlayerA`nplayers=1`nmap=Full Metal Plate 1.7`nlateJoin=1`nstartDelay=25" } elseif ($Mode -eq 'rejoin') { "auto=host`nname=PlayerA`nplayers=2`nmap=Full Metal Plate 1.7`nstartDelay=25" } elseif ($Mode -eq 'pve') { "auto=host`nname=PlayerA`nplayers=2`nmap=Full Metal Plate 1.7`nbot=$Ai`nbotAlly=0`nstartDelay=25" } elseif ($Mode -eq 'brood') { "auto=host`nname=PlayerA`nplayers=1`nmap=Full Metal Plate 1.7`nbot=RaptorsAI`nbotAlly=0`nstartDelay=25" } elseif ($Mode -eq 'evoroom') { "auto=host`nname=PlayerA`nplayers=99`nmap=$Map`nevolution=1`nevolutionClose=40`nlanMenu=44`nevoMenu=48`nbot=BARb`nbotVersion=stable`nbotAlly=1" } elseif ($Mode -eq 'evo') { "auto=host`nname=PlayerA`nplayers=$(if ($Solo) { 1 } else { 2 })`nmap=$Map`nevolution=1$(if ($EvoStage -gt 0) { "`nevolutionStage=$EvoStage" })`nbot=$(if ($Ai -eq 'RaptorsAI') { 'BARb' } else { $Ai })`nbotVersion=stable`nbotAlly=2`nstartDelay=$(if ($Shots) { 70 } else { 25 })" } elseif ($Mode -eq 'cp') { "auto=host`nname=PlayerA`nplayers=2`nmap=Full Metal Plate 1.7`ncopilot=PlayerB`nstartDelay=14" } else { "auto=host`nname=PlayerA`nplayers=$($Clients + 1)`nscenario=$scn" }
    } else {
        $auto = "auto=join`nname=$($names[$who])`nip=127.0.0.1`nautoAccept=1$(if ($NoMap -and -not $KeepOnline) { "`nnoOnline=1" })"
        if ($MapList -eq 'official') { Update-MapHashes $d }
        elseif ($MapList -eq 'wrong') { Set-Content "$d\games\$MapHashesFile" @('# etag=x', 'Full Metal Plate 1.7|00000000000000000000000000000000') -Encoding ASCII }
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
    if ($Mode -eq 'preset' -and $PresetFile) { Copy-Item $PresetFile "$d\optionsPresets.json" }   # a preset file of a user: -PresetFile <path> -PresetName <name>
    [IO.File]::WriteAllText("$d\lanlobby_cfg.txt", $auto)
    $r = $rects[$who]
    Write-SandboxSettings "$sbx\springsettings.cfg" $r @('LogFlushLevel = 0', 'VSync = 0', 'VSyncGame = 0', 'IdleFpsDivider = 0', 'InitialNetworkTimeout = 600', 'NetworkTimeout = 600', 'RapidTagResolutionOrder = repos-cdn.beyondallreason.dev;repos.beyondallreason.dev')
    if ($Mode -eq 'latejoin' -and $who -eq 'J') { continue }   # started when the game of the host runs
    $procs[$who] = Start-SandboxProcess $exe @('--config', "$sbx\springsettings.cfg", '--write-dir', $d, '--menu', $menu) 20   # (window kept behind the others for 20 s)
    "started $who pid $($procs[$who].Id)"
}
if ($Mode -eq 'latejoin') { $who2 = @('H') }
Add-Type -AssemblyName System.Drawing
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W6 { [StructLayout(LayoutKind.Sequential)] public struct P { public int X, Y; }
 [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out W3.R r);
 [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr h, ref P p);
 [DllImport("user32.dll")] public static extern bool SetCursorPos(int x, int y);
 [DllImport("user32.dll")] public static extern void mouse_event(uint f, int dx, int dy, uint d, UIntPtr e); }
public class W3 { [StructLayout(LayoutKind.Sequential)] public struct R { public int L, T, Rt, B; }
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out R r);
 [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint flags); }
'@
function Save-Shot($proc, $name) {
    $h = $proc.MainWindowHandle
    $r = New-Object W3+R; [void][W3]::GetWindowRect($h, [ref]$r)
    $w = $r.Rt - $r.L; $ht = $r.B - $r.T
    if ($w -lt 50 -or $ht -lt 50) { "shot $name : window not found"; return }
    $bmp = New-Object Drawing.Bitmap $w, $ht
    $g = [Drawing.Graphics]::FromImage($bmp)
    if ($FrontShots) {
        [void][SbxWin]::SetWindowPos($h, [IntPtr]0, 0, 0, 0, 0, 0x0013); [void][SbxWin]::SetForegroundWindow($h); Start-Sleep -Milliseconds 900
        $g.CopyFromScreen($r.L, $r.T, 0, 0, (New-Object Drawing.Size $w, $ht))
        [void][SbxWin]::SetWindowPos($h, [IntPtr]1, 0, 0, 0, 0, 0x0013); [void][SbxWin]::SetForegroundWindow($prev)
    } else {
        $dc = $g.GetHdc(); [void][W3]::PrintWindow($h, $dc, 2); $g.ReleaseHdc($dc)
    }
    $g.Dispose(); $bmp.Save("$sp\$name", [Drawing.Imaging.ImageFormat]::Png); $bmp.Dispose()
    "shot $name ($w x $ht)"
}
# -Mode pve: the engine takes a start position only from a mouse click: when the widget zz_place.lua has pointed the camera at the position, click the middle of the window
function Click-Middle($proc, $dir) {
    $h = $proc.MainWindowHandle
    [void][SbxWin]::SetWindowPos($h, [IntPtr]0, 0, 0, 0, 0, 0x0013); [void][SbxWin]::SetForegroundWindow($h); Start-Sleep -Milliseconds 700
    $r = New-Object W3+R; [void][W6]::GetClientRect($h, [ref]$r)
    # a message box in the middle of the window (the Scavengers' "Warning, Scavengers are active in this region") closes with a click beside it: first a click near the top left corner
    $pt = New-Object W6+P; $pt.X = [int]($r.Rt * 0.06); $pt.Y = [int]($r.B * 0.12); [void][W6]::ClientToScreen($h, [ref]$pt)
    [void][W6]::SetCursorPos($pt.X, $pt.Y); Start-Sleep -Milliseconds 300
    [W6]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 150; [W6]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 500
    $pt = New-Object W6+P; $pt.X = [int]($r.Rt / 2); $pt.Y = [int]($r.B / 2); [void][W6]::ClientToScreen($h, [ref]$pt)
    [void][W6]::SetCursorPos($pt.X, $pt.Y); Start-Sleep -Milliseconds 300
    [W6]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 150; [W6]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 300
    [void][SbxWin]::SetWindowPos($h, [IntPtr]1, 0, 0, 0, 0, 0x0013); [void][SbxWin]::SetForegroundWindow($prev)
    "clicked the middle of the window of $dir"
}
$clicked = @{}; $hostEnded = $null; $killedAt = $null; $placedAt = $null; $rjShot = @{}
$shotAt = @(); foreach ($s in ($Shots -split '[,\s]+' | ? { $_ })) { $shotAt += [int]$s }
$start = Get-Date
while (((Get-Date) - $start).TotalSeconds -lt $WaitSec -and ((@($who2 | ? { -not $procs[$_].HasExited }).Count -gt 0))) {
    foreach ($who in $who2) { if (-not $procs[$who].HasExited) { $procs[$who].Refresh(); [void][SbxWin]::SetWindowPos($procs[$who].MainWindowHandle, [IntPtr]1, 0, 0, 0, 0, 0x0013) } }
    $el = ((Get-Date) - $start).TotalSeconds
    if ($ClickAt -gt 0 -and $el -ge $ClickAt -and -not $procs['H'].HasExited) {
        $ClickAt = 0; $h = $procs['H'].MainWindowHandle; $r = New-Object W3+R; [void][W3]::GetWindowRect($h, [ref]$r)
        [void][SbxWin]::SetWindowPos($h, [IntPtr]0, 0, 0, 0, 0, 0x0013); [void][SbxWin]::SetForegroundWindow($h); Start-Sleep -Milliseconds 700
        [void][W6]::SetCursorPos([int]($r.L + ($r.Rt - $r.L) * 0.30), [int]($r.T + ($r.B - $r.T) * 0.82)); Start-Sleep -Milliseconds 300
        [W6]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 150; [W6]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
        [void][SbxWin]::SetWindowPos($h, [IntPtr]1, 0, 0, 0, 0, 0x0013); [void][SbxWin]::SetForegroundWindow($prev); 'clicked beside the menus'
    }
    foreach ($s in @($shotAt)) { if ($el -ge $s -and -not $procs['H'].HasExited) {
        $shotAt = @($shotAt | ? { $_ -ne $s }); $procs['H'].Refresh()
        Save-Shot $procs['H'] "shot_$s.png"
    } }
    if ($Mode -eq 'latejoin' -and -not $killedAt -and (Select-String -Path "$sp\sbx_H\data\infolog.txt" -Pattern '\[zzplace\] (placed|GameStart)' -Quiet -ErrorAction SilentlyContinue)) {
        if (-not $placedAt) { $placedAt = Get-Date }
        elseif (((Get-Date) - $placedAt).TotalSeconds -gt 40) {
            $sbx = "$sp\sbx_J"; $dj = "$sbx\data"
            $procs['J'] = Start-SandboxProcess $exe @('--config', "$sbx\springsettings.cfg", '--write-dir', $dj, '--menu', $menu)
            $who2 = @('H', 'J'); $killedAt = Get-Date; 'latejoin test: PlayerB started (the game of PlayerA runs)'
        }
    }
    if ($Mode -in 'pve', 'rejoin', 'latejoin', 'mix', 'brood') {
        # click the middle of the window (the widget points the camera at the start position) until the widget logs "placed"; in the draft mode the players place one after the other
        foreach ($who in $who2) {
            $dd = "$sp\sbx_$who\data"
            if ($procs[$who].HasExited -or $clicked[$who] -ge 40 -or ($Mode -eq 'latejoin' -and $who -ne 'H')) { continue }
            $log = "$dd\infolog.txt"
            if (-not (Select-String -Path $log -Pattern 'Random draft order' -Quiet -ErrorAction SilentlyContinue)) { continue }
            if (Select-String -Path $log -Pattern '\[zzplace\] (placed|GameStart)' -Quiet -ErrorAction SilentlyContinue) { $clicked[$who] = 99; continue }
            if (-not $clicked.ContainsKey($who)) { Start-Sleep 5 }   # the game is loaded: wait until it takes input
            $clicked[$who] = 1 + [int]$clicked[$who]; Click-Middle $procs[$who] $dd
        }
    }
    # the host's game ended (quitforce of the test widget): the joiners stay in their lobby, end them after some seconds
    if ($Mode -in 'pve', 'mix' -and $procs['H'].HasExited) { if (-not $hostEnded) { $hostEnded = Get-Date } elseif (((Get-Date) - $hostEnded).TotalSeconds -gt 10) { break } }
    if ($Mode -eq 'rejoin' -and -not $killedAt -and (Select-String -Path "$sp\sbx_H\data\infolog.txt" -Pattern '\[zzplace\] (placed|GameStart)' -Quiet -ErrorAction SilentlyContinue) -and (Select-String -Path "$sp\sbx_J\data\infolog.txt" -Pattern '\[zzplace\] (placed|GameStart)' -Quiet -ErrorAction SilentlyContinue)) {
        if (-not $placedAt) { $placedAt = Get-Date }
        elseif (((Get-Date) - $placedAt).TotalSeconds -gt 40) {
            'rejoin test: killing the game of PlayerB (a crash)'; Stop-Process -Id $procs['J'].Id -Force; $killedAt = Get-Date; Start-Sleep 5
            $dj = "$sp\sbx_J\data"; Copy-Item "$dj\infolog.txt" "$dj\infolog_first.txt" -Force
            $procs['J'] = Start-SandboxProcess $exe @('--config', "$sp\sbx_J\springsettings.cfg", '--write-dir', $dj, '--menu', $menu)
            'rejoin test: PlayerB started again'
        }
    }
    if ($Mode -in 'rejoin', 'latejoin' -and $killedAt) {
        $k = ((Get-Date) - $killedAt).TotalSeconds
        foreach ($s in 40, 80, 110) { if ($k -ge $s -and -not $rjShot[$s]) { $rjShot[$s] = 1; $procs['J'].Refresh(); Save-Shot $procs['J'] "rejoin_J_$s.png" } }
        if ($k -ge 45 -and -not $rjShot['click']) {
            # the Rejoin button of the room (bottom right of the room page, as in rejoin_J_40.png: 52 % of the width, 66 % of the height of the window)
            $rjShot['click'] = 1; $h = $procs['J'].MainWindowHandle; $r = New-Object W3+R; [void][W3]::GetWindowRect($h, [ref]$r)
            [void][SbxWin]::SetWindowPos($h, [IntPtr]0, 0, 0, 0, 0, 0x0013); [void][SbxWin]::SetForegroundWindow($h); Start-Sleep -Milliseconds 700
            [void][W6]::SetCursorPos([int]($r.L + ($r.Rt - $r.L) * 0.524), [int]($r.T + ($r.B - $r.T) * 0.666)); Start-Sleep -Milliseconds 300
            [W6]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero); Start-Sleep -Milliseconds 150; [W6]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
            [void][SbxWin]::SetWindowPos($h, [IntPtr]1, 0, 0, 0, 0, 0x0013); [void][SbxWin]::SetForegroundWindow($prev); 'rejoin test: clicked Rejoin'
        }
        if ($k -gt 130) { break }
    }
    Start-Sleep 3
}
foreach ($who in $who2) { if (-not $procs[$who].HasExited) { "timeout: killing $who"; try { Stop-Process -Id $procs[$who].Id -Force } catch {} } else { "$who ended itself" } }
