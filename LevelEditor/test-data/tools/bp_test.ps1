# BluePrinter test: one sandbox game of the official BAR (own write folder, nothing of the installed game is changed) with the BluePrinter widget of this repository
# and a test widget from tools\ (-Widget zz_bpfaction.lua). It runs next to a game you are playing: only the test's own process is ever stopped.
# The widget logs "[zzar]" lines (infolog.txt in <Work>\data) and ends the game itself (quitforce).
#   -Side Armada | Cortex | Legion   the faction of the player (and its commander)
param([int]$WaitSec = 240, [string]$Work = (Join-Path $env:TEMP 'bp_test'), [string]$Data = 'C:\Games\Beyond-All-Reason\data', [string]$Map = 'Full Metal Plate 1.7', [string]$Widget = 'zz_bpfaction.lua', [string]$Side = 'Cortex')
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
. (Join-Path $repo 'shared\bar_common.ps1')
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W4 { [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); }
'@
$exe = (Get-Engine $Data).FullName + '\spring.exe'   # the newest engine (sorted by version, Get-Engine of bar_common.ps1)
$d = "$Work\data"
if (Test-Path $d) { foreach ($j in Get-ChildItem $d -Directory | ? { $_.Attributes -band 'ReparsePoint' }) { cmd /c rmdir "$($j.FullName)" } }
if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
New-Item -ItemType Directory "$d\cache", "$d\games", "$d\LuaUI\Widgets", "$d\LuaUI\Include", "$d\LuaUI\Config" -Force | Out-Null
foreach ($j in 'engine', 'packages', 'pool', 'rapid', 'maps') { New-Item -ItemType Junction -Path "$d\$j" -Target "$Data\$j" | Out-Null }
Copy-Item (Get-ChildItem "$Data\cache\ArchiveCache*.lua" | Sort LastWriteTime | Select -Last 1).FullName "$d\cache\"
Copy-Item "$repo\BluePrinter\bluePrinter.lua" "$d\LuaUI\Widgets\"
Copy-Item "$repo\shared\editor_common.lua", "$repo\shared\bar_rules.lua" "$d\LuaUI\Include\"
Copy-Item "$tools\$Widget" "$d\LuaUI\Widgets\"
$game = Get-GameVersion $Data
$script = @"
[game]
{
	[allyteam0] { numallies=0; }
	[allyteam1] { numallies=0; }
	[team0] { allyteam=0; teamleader=0; side=$Side; handicap=0; }
	[team1] { allyteam=1; teamleader=0; side=Armada; handicap=0; }
	[ai0] { shortname=NullAI; team=1; host=0; name=Null1; }
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; experimentallegionfaction=1; }
	ishost=1;
	hostip=127.0.0.1;
	hostport=18455;
	myplayername=Player;
	gametype=$game;
	mapname=$Map;
	startpostype=0;
	numplayers=1;
	numusers=2;
	nohelperais=0;
}
"@
[IO.File]::WriteAllText("$d\script.txt", $script, (New-Object Text.UTF8Encoding $false))
[IO.File]::WriteAllLines("$Work\springsettings.cfg", @('Fullscreen = 0', 'WindowBorderless = 0', 'XResolution = 1800', 'YResolution = 1000', 'XResolutionWindowed = 1800', 'YResolutionWindowed = 1000', 'WindowPosX = 40', 'WindowPosY = 40', 'Sound = 0', 'MaxSounds = 0'))
$prev = [W4]::GetForegroundWindow()
$p = Start-Process $exe -ArgumentList @('--config', "`"$Work\springsettings.cfg`"", '--write-dir', "`"$d`"", "`"$d\script.txt`"") -PassThru
"started pid $($p.Id)"
$start = Get-Date
while (((Get-Date) - $start).TotalSeconds -lt $WaitSec -and -not $p.HasExited) {
    $p.Refresh()
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) { [void][W4]::SetWindowPos($p.MainWindowHandle, [IntPtr]1, 0, 0, 0, 0, 0x0013); [void][W4]::SetForegroundWindow($prev) }
    Start-Sleep 3
}
if (-not $p.HasExited) { 'timeout: ending the test game'; try { $p.CloseMainWindow() | Out-Null; Start-Sleep 5; if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force } } catch {} } else { 'the game ended itself' }
Select-String -Path "$d\infolog.txt" -Pattern '\[zzar\]|Failed to load|Error' -ErrorAction SilentlyContinue | % { $_.Line } | Select -First 120
