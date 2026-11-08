# Shared parts of the sandbox test tools (arena_test, bp_test, pve_test, lan_test, console_test): a sandbox data folder with junctions to the game files of the
# installation, the window settings of a test game, starting a test game behind the other windows and reading its log. Dot-source it after
# shared\bar_common.ps1: . (Join-Path $PSScriptRoot 'test_common.ps1'). Nothing of the installed game is changed.

if (-not ('SbxWin' -as [type])) {
    Add-Type @'
using System; using System.Runtime.InteropServices;
public class SbxWin { [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); }
'@
}

# The data folder of the BAR installation for a test: $data when given, otherwise the installation that Find-Bar (bar_common.ps1) finds; the folder found is
# remembered in %LOCALAPPDATA%\BAR-Level-Editor\test_bar_path.txt
function Resolve-TestData([string]$data) {
    if ($data) { return $data }
    return Join-Path (Find-Bar @() (Join-Path $env:LOCALAPPDATA 'BAR-Level-Editor\test_bar_path.txt')) 'data'
}

# Makes the folder $root new with a data folder inside and returns the path of the data folder: the folders cache, games, LuaUI\Widgets and $dirs (relative to
# the data folder), junctions to engine, packages, pool, rapid and maps of the installation $real (-NoMaps: an empty maps folder instead) and the newest archive
# cache of the installation (so the engine does not scan every archive again). Junctions of an older run are unhooked before the folder is deleted.
function New-SandboxData([string]$root, [string]$real, [string[]]$dirs = @(), [switch]$NoMaps) {
    $d = Join-Path $root 'data'
    if (Test-Path $d) { foreach ($j in Get-ChildItem $d -Directory | Where-Object { $_.Attributes -band 'ReparsePoint' }) { cmd /c rmdir "$($j.FullName)" } }
    if (Test-Path $root) { Remove-Item $root -Recurse -Force }
    $all = @('cache', 'games', 'LuaUI\Widgets') + @($dirs | Where-Object { $_ })
    New-Item -ItemType Directory ($all | ForEach-Object { Join-Path $d $_ }) -Force | Out-Null
    foreach ($j in 'engine', 'packages', 'pool', 'rapid', 'maps') {
        if ($j -eq 'maps' -and $NoMaps) { New-Item -ItemType Directory "$d\maps" -Force | Out-Null; continue }
        New-Item -ItemType Junction -Path "$d\$j" -Target "$real\$j" | Out-Null
    }
    Copy-Item (Get-ChildItem "$real\cache\ArchiveCache*.lua" | Sort-Object LastWriteTime | Select-Object -Last 1).FullName "$d\cache\"
    return $d
}

# The name of the installed lobby (Chobby) package for --menu: the test version of the rapid repository whose package is installed (otherwise the first one)
function Get-SandboxLobby([string]$real) {
    $f = Join-Path $real 'rapid\repos-cdn.beyondallreason.dev\byar-chobby\versions.gz'
    if (-not (Test-Path $f)) { throw "No lobby package found ($f): start BAR once." }
    $text = [Text.Encoding]::UTF8.GetString((Read-GzBytes $f))
    $first = $null
    foreach ($line in ($text -split "`n")) {
        $p = $line.Trim().Split(',')
        if ($p.Count -lt 4 -or $p[0] -ne 'byar-chobby:test') { continue }
        if (-not $first) { $first = $p[3] }
        if (Test-Path (Join-Path $real ('packages\' + $p[1] + '.sdp'))) { return $p[3] }
    }
    if ($first) { return $first }
    throw 'No lobby version found in the rapid repository.'
}

# The settings file of a test game: a framed window of the size w x h at x, y (or none: $rect = $null) and the lines $extra
function Write-SandboxSettings([string]$path, $rect, [string[]]$extra = @()) {
    $lines = @()
    if ($rect) {
        $lines += @('Fullscreen = 0', 'WindowBorderless = 0', "XResolution = $($rect[2])", "YResolution = $($rect[3])", "XResolutionWindowed = $($rect[2])",
            "YResolutionWindowed = $($rect[3])", "WindowPosX = $($rect[0])", "WindowPosY = $($rect[1])")
    }
    [IO.File]::WriteAllLines($path, @($lines + $extra))
}

# Starts the engine with these arguments and keeps its window behind the window that had the focus (the computer stays usable while a test runs);
# returns the process. $holdSec: how long the window is pushed back (0 = not at all; the caller does it in its own loop)
function Start-SandboxProcess([string]$exe, [string[]]$arguments, [int]$holdSec = 0) {
    $prev = [SbxWin]::GetForegroundWindow()
    $p = Start-Process $exe -ArgumentList @($arguments | ForEach-Object { '"' + $_ + '"' }) -PassThru
    $t0 = Get-Date
    while (((Get-Date) - $t0).TotalSeconds -lt $holdSec -and -not $p.HasExited) { Push-SandboxWindow $p $prev; Start-Sleep -Milliseconds 500 }
    return $p
}

# Puts the window of the process behind the others and gives the focus back to $prev
function Push-SandboxWindow($p, [IntPtr]$prev) {
    $p.Refresh()
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) { [void][SbxWin]::SetWindowPos($p.MainWindowHandle, [IntPtr]1, 0, 0, 0, 0, 0x0013) }
    [void][SbxWin]::SetForegroundWindow($prev)
}

# One test game: starts it with the settings file $cfg, the data folder $d and the start script $script, keeps the window behind the others, waits until the game
# ends itself (quitforce of the test widget) or $waitSec run out (then it is closed, and stopped if it does not close), and prints the lines of infolog.txt that
# match $pattern (at most $maxLines). Only this process is ever stopped.
function Invoke-SandboxGame([string]$exe, [string]$cfg, [string]$d, [string]$script, [int]$waitSec, [string]$pattern, [int]$maxLines = 120, [string]$note = '') {
    $prev = [SbxWin]::GetForegroundWindow()
    $p = Start-SandboxProcess $exe @('--config', $cfg, '--write-dir', $d, $script)
    "started pid $($p.Id)$note"
    $start = Get-Date
    while (((Get-Date) - $start).TotalSeconds -lt $waitSec -and -not $p.HasExited) {
        $p.Refresh()
        if ($p.MainWindowHandle -ne [IntPtr]::Zero) { [void][SbxWin]::SetWindowPos($p.MainWindowHandle, [IntPtr]1, 0, 0, 0, 0, 0x0013); [void][SbxWin]::SetForegroundWindow($prev) }
        Start-Sleep 3
    }
    if (-not $p.HasExited) { 'timeout: ending the test game'; try { $p.CloseMainWindow() | Out-Null; Start-Sleep 5; if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force } } catch {} } else { 'the game ended itself' }
    Select-String -Path "$d\infolog.txt" -Pattern $pattern -ErrorAction SilentlyContinue | ForEach-Object { $_.Line } | Select-Object -First $maxLines
}
