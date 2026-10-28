# Arena test: one sandbox game of the Level Editor (built from the files of this repository: nothing of the installed game is changed) with four
# teams on a flat map and the test widget zz_arena.lua, which works the Arena page (settings, Generate, move, undo, Start, Stop, Clear) and logs
# "[zzar]" lines into infolog.txt of the sandbox (<Work>\data\infolog.txt). The game ends itself (quitforce) when the test is through.
param([int]$WaitSec = 420, [string]$Work = (Join-Path $env:TEMP 'arena_test'), [string]$Data = 'C:\Games\Beyond-All-Reason\data', [string]$Map = 'Full Metal Plate 1.7', [switch]$Shots, [switch]$AlongsideGame, [string]$Widget = '')
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
. (Join-Path $repo 'shared\bar_common.ps1'); . (Join-Path $repo 'LevelEditor\scripts\editor_manifest.ps1')
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
if (-not $AlongsideGame -and (Get-Process spring -ErrorAction SilentlyContinue)) { 'A game is running: aborted'; return }
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W3 { [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); }
'@
$exe = (Get-ChildItem "$Data\engine" -Directory | Select -Last 1).FullName + '\spring.exe'
$d = "$Work\data"
if (Test-Path $d) { foreach ($j in Get-ChildItem $d -Directory | ? { $_.Attributes -band 'ReparsePoint' }) { cmd /c rmdir "$($j.FullName)" } }
if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
New-Item -ItemType Directory "$d\cache", "$d\games", "$d\LuaUI\Widgets", "$d\LevelEditor" -Force | Out-Null
foreach ($j in 'engine', 'packages', 'pool', 'rapid', 'maps') { New-Item -ItemType Junction -Path "$d\$j" -Target "$Data\$j" | Out-Null }
Copy-Item (Get-ChildItem "$Data\cache\ArchiveCache*.lua" | Sort LastWriteTime | Select -Last 1).FullName "$d\cache\"
Copy-Item ("$tools\" + $(if ($Widget) { $Widget } elseif ($Shots) { 'zz_arena_shots.lua' } else { 'zz_arena.lua' })) "$d\LuaUI\Widgets\"
Copy-Item "$tools\..\levels\*.lua" "$d\LevelEditor\"   # the test levels (td_test, ctf_test, rtf_test) for the widgets that load them

# the extra game "Level Editor" from the files of the repository (as install_editor.ps1 builds it)
$game = Get-GameVersion $Data
$modinfo = "return {`n`tname = `"Level Editor`",`n`tshortName = `"LevelEd`",`n`tversion = `"1`",`n`tgame = `"LevelEditorMod`",`n`tshortGame = `"LevelEd`",`n`tdescription = `"test`",`n`tmutator = `"Official`",`n`tmodtype = 1,`n`tdepend = { `"$game`" },`n}`n"
$entries = @(, @('modinfo.lua', $modinfo))
foreach ($e in (Get-EditorGameEntries)) {
    $text = Get-Content $e[1] -Raw
    if ($e[0] -eq 'luaui/widgets/lvl_level_editor.lua') { $text = ([regex]'enabled = false,').Replace($text, 'enabled = true,', 1) }
    $entries += , @($e[0], $text)
}
Write-GameZip "$d\games\LevelEditorMod.sdz" $entries

# ten teams like the editor game (choose_map.ps1), one human: every team belongs to its own ally team
$allies = (0..9 | ForEach-Object { "`t[allyteam$_] { numallies=0; }" }) -join "`n"
$teams = (0..9 | ForEach-Object { $side = if ($_ % 2 -eq 0) { 'Armada' } else { 'Cortex' }; "`t[team$_] { allyteam=$_; teamleader=0; side=$side; handicap=0; }" }) -join "`n"
$script = @"
[game]
{
$allies
$teams
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; maxunits=32000; leveleditor=1; experimentallegionfaction=1; experimentalextraunits=1; releasecandidates=1; forceallunits=1; }
	ishost=1;
	hostip=127.0.0.1;
	hostport=18453;
	myplayername=Player;
	gametype=Level Editor 1;
	mapname=$Map;
	startpostype=0;
	numplayers=1;
	numusers=1;
	nohelperais=0;
}
"@
[IO.File]::WriteAllText("$d\script.txt", $script, (New-Object Text.UTF8Encoding $false))
[IO.File]::WriteAllLines("$Work\springsettings.cfg", @('Fullscreen = 0', 'WindowBorderless = 0', 'XResolution = 2400', 'YResolution = 1300', 'XResolutionWindowed = 2400', 'YResolutionWindowed = 1300', 'WindowPosX = 60', 'WindowPosY = 60', 'LogFlushLevel = 0', 'VSync = 0', 'VSyncGame = 0', 'IdleFpsDivider = 0'))
$prev = [W3]::GetForegroundWindow()
$p = Start-Process $exe -ArgumentList @('--config', "`"$Work\springsettings.cfg`"", '--write-dir', "`"$d`"", "`"$d\script.txt`"") -PassThru
"started pid $($p.Id)"
$start = Get-Date
while (((Get-Date) - $start).TotalSeconds -lt $WaitSec -and -not $p.HasExited) {
    $p.Refresh()
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) { [void][W3]::SetWindowPos($p.MainWindowHandle, [IntPtr]1, 0, 0, 0, 0, 0x0013); [void][W3]::SetForegroundWindow($prev) }
    Start-Sleep 3
}
if (-not $p.HasExited) { 'timeout: killing the test game'; try { Stop-Process -Id $p.Id -Force } catch {} } else { 'the game ended itself' }
Select-String -Path "$d\infolog.txt" -Pattern '\[zzar\]|Failed to load|Error' -ErrorAction SilentlyContinue | % { $_.Line } | Select -First 120
