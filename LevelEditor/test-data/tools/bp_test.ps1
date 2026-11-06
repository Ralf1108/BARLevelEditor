# BluePrinter test: one sandbox game of the official BAR (own write folder, nothing of the installed game is changed) with the BluePrinter widget of this repository
# and a test widget from tools\ (-Widget zz_bpfaction.lua). It runs next to a game you are playing: only the test's own process is ever stopped.
# The widget logs "[zzar]" lines (infolog.txt in <Work>\data) and ends the game itself (quitforce).
#   -Side Armada | Cortex | Legion   the faction of the player (and its commander)
param([int]$WaitSec = 240, [string]$Work = (Join-Path $env:TEMP 'bp_test'), [string]$Data = 'C:\Games\Beyond-All-Reason\data', [string]$Map = 'Full Metal Plate 1.7', [string]$Widget = 'zz_bpfaction.lua', [string]$Side = 'Cortex')
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
. (Join-Path $repo 'shared\bar_common.ps1'); . (Join-Path $tools 'test_common.ps1')
$exe = (Get-Engine $Data).FullName + '\spring.exe'   # the newest engine (sorted by version, Get-Engine of bar_common.ps1)
$d = New-SandboxData $Work $Data @('LuaUI\Include', 'LuaUI\Config')
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
Write-SandboxSettings "$Work\springsettings.cfg" @(40, 40, 1800, 1000) @('Sound = 0', 'MaxSounds = 0')
Invoke-SandboxGame $exe "$Work\springsettings.cfg" $d "$d\script.txt" $WaitSec '\[zzar\]|Failed to load|Error'
