# Scavengers / Raptors AI test: one sandbox game (own write folder, nothing of the installed game is changed) of the extra game of the scenarios built from the files of
# this repository (with the gadget lan_pve_hold.lua), one human and a Raptors or Scavengers AI. The widget zz_pve.lua speeds the game up, counts the units of the AI that have
# an order of the AI, gives some units a move order as the human and looks whether it stays. It runs next to a game you are playing: only the test's own process is stopped.
#   -Ai Raptors | Scavengers          the Lua AI of team 1
#   -Hold 1 | 0                       game option lanpvehold (0 = control run: the AI's orders are not dropped)
#   -Layout ally | separate           the AI in the ally team of the human, or in an ally team of its own
#   -Enemy 1                          a third team (NullAI, own ally team) that the Scavengers / Raptors can attack
param([int]$WaitSec = 420, [string]$Work = (Join-Path $env:TEMP 'pve_test'), [string]$Data = 'C:\Games\Beyond-All-Reason\data', [string]$Map = 'Full Metal Plate 1.7',
      [string]$Ai = 'Raptors', [int]$Hold = 1, [string]$Layout = 'ally', [int]$Enemy = 0)
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
. (Join-Path $repo 'shared\bar_common.ps1'); . (Join-Path $repo 'LevelEditor\scripts\editor_manifest.ps1')
Add-Type @'
using System; using System.Runtime.InteropServices;
public class W5 { [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr a, int x, int y, int cx, int cy, uint f);
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow(); [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h); }
'@
$exe = (Get-ChildItem "$Data\engine" -Directory | Select -Last 1).FullName + '\spring.exe'
$d = "$Work\data"
if (Test-Path $d) { foreach ($j in Get-ChildItem $d -Directory | ? { $_.Attributes -band 'ReparsePoint' }) { cmd /c rmdir "$($j.FullName)" } }
if (Test-Path $Work) { Remove-Item $Work -Recurse -Force }
New-Item -ItemType Directory "$d\cache", "$d\games", "$d\LuaUI\Widgets", "$d\LuaUI\Config" -Force | Out-Null
foreach ($j in 'engine', 'packages', 'pool', 'rapid', 'maps') { New-Item -ItemType Junction -Path "$d\$j" -Target "$Data\$j" | Out-Null }
Copy-Item (Get-ChildItem "$Data\cache\ArchiveCache*.lua" | Sort LastWriteTime | Select -Last 1).FullName "$d\cache\"
Copy-Item "$tools\zz_pve.lua" "$d\LuaUI\Widgets\"
$game = Get-GameVersion $Data
$sg = Write-ScenarioGame $d $game (Get-ScenarioGameDirs)
$short = if ($Ai -eq 'Scavengers') { 'ScavengersAI' } else { 'RaptorsAI' }
$ally1 = if ($Layout -eq 'ally') { 0 } else { 1 }
# start boxes: the Scavenger spawner places its beacons outside the boxes of the players
$box0 = "startrectleft=0; startrecttop=0; startrectright=0.2; startrectbottom=1;"
$box1 = "startrectleft=0.8; startrecttop=0; startrectright=1; startrectbottom=1;"
$allies = if ($Layout -eq 'ally') { "`t[allyteam0] { numallies=0; $box0 }" } else { "`t[allyteam0] { numallies=0; $box0 }`n`t[allyteam1] { numallies=0; $box1 }" }
if ($Enemy) {
    $allies += "`n`t[allyteam2] { numallies=0; startrectleft=0.4; startrecttop=0; startrectright=0.6; startrectbottom=1; }"
    $enemyTeams = "`n`t[team2] { allyteam=2; teamleader=0; side=Armada; handicap=0; }`n`t[ai1] { shortname=NullAI; team=2; host=0; name=Null2; }"
} else { $enemyTeams = '' }
$script = @"
[game]
{
$allies
	[team0] { allyteam=0; teamleader=0; side=Cortex; handicap=0; }
	[team1] { allyteam=$ally1; teamleader=0; side=Armada; handicap=0; }
	[ai0] { shortname=$short; version=<not-versioned>; team=1; host=0; name=${short}1; }$enemyTeams
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; experimentallegionfaction=1; lanpvehold=$Hold; lanplay=1; forceallunits=1; }
	ishost=1;
	hostip=127.0.0.1;
	hostport=18456;
	myplayername=Player;
	gametype=$($sg.Name);
	mapname=$Map;
	startpostype=0;
	numplayers=1;
	numusers=$(2 + $Enemy);
	nohelperais=0;
}
"@
[IO.File]::WriteAllText("$d\script.txt", $script, (New-Object Text.UTF8Encoding $false))
[IO.File]::WriteAllLines("$Work\springsettings.cfg", @('Fullscreen = 0', 'WindowBorderless = 0', 'XResolution = 1200', 'YResolution = 700', 'XResolutionWindowed = 1200', 'YResolutionWindowed = 700', 'WindowPosX = 40', 'WindowPosY = 40', 'Sound = 0', 'MaxSounds = 0'))
$prev = [W5]::GetForegroundWindow()
$p = Start-Process $exe -ArgumentList @('--config', "`"$Work\springsettings.cfg`"", '--write-dir', "`"$d`"", "`"$d\script.txt`"") -PassThru
"started pid $($p.Id) ($Ai, hold $Hold, layout $Layout, game $($sg.Name))"
$start = Get-Date
while (((Get-Date) - $start).TotalSeconds -lt $WaitSec -and -not $p.HasExited) {
    $p.Refresh()
    if ($p.MainWindowHandle -ne [IntPtr]::Zero) { [void][W5]::SetWindowPos($p.MainWindowHandle, [IntPtr]1, 0, 0, 0, 0, 0x0013); [void][W5]::SetForegroundWindow($prev) }
    Start-Sleep 3
}
if (-not $p.HasExited) { 'timeout: ending the test game'; try { $p.CloseMainWindow() | Out-Null; Start-Sleep 5; if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force } } catch {} } else { 'the game ended itself' }
Select-String -Path "$d\infolog.txt" -Pattern '\[zzpve\]|\[LAN\]|Failed to load|Error' -ErrorAction SilentlyContinue | % { $_.Line } | Select -First 80
