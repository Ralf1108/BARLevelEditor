# Scavengers / Raptors AI test: one sandbox game (own write folder, nothing of the installed game is changed) of the extra game of the scenarios built from the files of
# this repository (with the gadget lan_pve_hold.lua), one human and a Raptors or Scavengers AI. The widget zz_pve.lua speeds the game up, counts the units of the AI that have
# an order of the AI, gives some units a move order as the human and looks whether it stays. It runs next to a game you are playing: only the test's own process is stopped.
#   -Ai Raptors | Scavengers          the Lua AI of team 1
#   -Hold 1 | 0                       game option lanpvehold (0 = control run: the AI's orders are not dropped)
#   -Layout ally | separate           the AI in the ally team of the human, or in an ally team of its own
#   -Enemy 1                          a third team (NullAI, own ally team) that the Scavengers / Raptors can attack
#   -Brood                            game option tweakdefs9 = lan_lobby\raptor_brood_defs.lua (the Raptor Brood Chamber, as the LAN lobby sets it; with -Widget zz_brood.lua)
#   -Widget zz_pve.lua                the test widget (a file in tools)
#   -EvoTest                          with -Evo: game option lanevotest=1 (evo|test|1 gives all abilities; with -Widget zz_cloak.lua: does Cloak work?)
#   -Evo [-EvoStage n]                an Evolution game instead (game option lanevolution=1, every player starts on level n): the human and a NullAI in its own
#                                     ally team, a larger window (with -Widget zz_evoshot.lua: a picture of the panels in <Work>\data\screenshots)
param([int]$WaitSec = 420, [string]$Work = (Join-Path $env:TEMP 'pve_test'), [string]$Data = '', [string]$Map = 'Full Metal Plate 1.7',
      [string]$Ai = 'Raptors', [int]$Hold = 1, [string]$Layout = 'ally', [int]$Enemy = 0, [switch]$Brood, [string]$Widget = 'zz_pve.lua', [switch]$Evo, [int]$EvoStage = 1, [switch]$EvoTest, [switch]$NoAim, [int]$Bots = 1, [string]$Shot = '', [switch]$Debug, [int]$Gift = 1, [int]$Mult = 1)
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
. (Join-Path $repo 'shared\bar_common.ps1'); . (Join-Path $repo 'LevelEditor\scripts\editor_manifest.ps1'); . (Join-Path $tools 'test_common.ps1')
$Data = Resolve-TestData $Data   # the data folder of the installation (-Data, otherwise Find-Bar of bar_common.ps1)
$exe = (Get-Engine $Data).FullName + '\spring.exe'   # the newest engine (sorted by version, Get-Engine of bar_common.ps1)
$d = New-SandboxData $Work $Data @('LuaUI\Config')
Copy-Item "$tools\$Widget" "$d\LuaUI\Widgets\"
$game = Get-GameVersion $Data
$sg = Write-ScenarioGame $d $game (Get-ScenarioGameDirs)
$short = if ($Ai -eq 'Scavengers') { 'ScavengersAI' } else { 'RaptorsAI' }
if ($Evo) { $Layout = 'separate' }
$ally1 = if ($Layout -eq 'ally') { 0 } else { 1 }
# start boxes: the Scavenger spawner places its beacons outside the boxes of the players
$box0 = "startrectleft=0; startrecttop=0; startrectright=0.2; startrectbottom=1;"
$box1 = "startrectleft=0.8; startrecttop=0; startrectright=1; startrectbottom=1;"
$allies = if ($Layout -eq 'ally') { "`t[allyteam0] { numallies=0; $box0 }" } else { "`t[allyteam0] { numallies=0; $box0 }`n`t[allyteam1] { numallies=0; $box1 }" }
if ($Enemy) {
    $allies += "`n`t[allyteam2] { numallies=0; startrectleft=0.4; startrecttop=0; startrectright=0.6; startrectbottom=1; }"
    $enemyTeams = "`n`t[team2] { allyteam=2; teamleader=0; side=Armada; handicap=0; }`n`t[ai1] { shortname=NullAI; team=2; host=0; name=Null2; }"
} else { $enemyTeams = '' }
# Evolution: -Bots n = n computer players in all (team 1 and n - 1 more, each in an ally team of its own)
$extra = if ($Evo) { [Math]::Max(0, $Bots - 1) } else { 0 }
for ($k = 2; $k -lt 2 + $extra; $k++) {
    $allies += "`n`t[allyteam$k] { numallies=0; }"
    $enemyTeams += "`n`t[team$k] { allyteam=$k; teamleader=0; side=Armada; handicap=0; }`n`t[ai$($k - 1)] { shortname=NullAI; team=$k; host=0; name=Null$k; }"
}
# the game option tweakdefs: the Lua text in base64url without padding (the game's string.base64Decode reads it; = would end the value in the start script)
$tweak = if ($Brood) { ' tweakdefs9=' + ([Convert]::ToBase64String([IO.File]::ReadAllBytes((Join-Path $repo 'LevelEditor\lan_lobby\raptor_brood_defs.lua'))).TrimEnd('=').Replace('+', '-').Replace('/', '_')) + ';' } else { '' }
$script = @"
[game]
{
$allies
	[team0] { allyteam=0; teamleader=0; side=Cortex; handicap=0; }
	[team1] { allyteam=$ally1; teamleader=0; side=Armada; handicap=0; }
$(if ($Evo) { "`t[ai0] { shortname=NullAI; team=1; host=0; name=Null1; }" } else { "`t[ai0] { shortname=$short; version=<not-versioned>; team=1; host=0; name=${short}1; }" })$enemyTeams
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; experimentallegionfaction=1; lanpvehold=$(if ($Evo) { 0 } else { $Hold }); lanplay=1; forceallunits=1;$tweak$(if ($Evo) { " lanevolution=1; lanevolutionstage=$EvoStage;$(if ($EvoTest) { ' lanevotest=1;' })$(if ($NoAim) { ' lanevoaim=0;' })$(if ($Debug) { ' lanevodebug=1;' })$(if ($Shot) { " lanevoshot=$Shot;" })$(if ($Gift -ne 1) { " lanevogift=$Gift;" })$(if ($Mult -gt 1) { " lanevomult=$Mult;" })" }) }
	ishost=1;
	hostip=127.0.0.1;
	hostport=18456;
	myplayername=Player;
	gametype=$($sg.Name);
	mapname=$Map;
	startpostype=0;
	numplayers=1;
	numusers=$(2 + $Enemy + $extra);
	nohelperais=0;
}
"@
[IO.File]::WriteAllText("$d\script.txt", $script, (New-Object Text.UTF8Encoding $false))
Write-SandboxSettings "$Work\springsettings.cfg" $(if ($Evo) { , @(40, 40, 1600, 900) } else { , @(40, 40, 1200, 700) }) @('Sound = 0', 'MaxSounds = 0')
Invoke-SandboxGame $exe "$Work\springsettings.cfg" $d "$d\script.txt" $WaitSec '\[zzdoc\]|\[zzhell\]|\[zzgates\]|\[zzaim\]|\[zzaitake\]|\[zzcloak\]|\[zzpve\]|\[zzbrood\]|\[zzevoshot\]|\[Evolution\]|\[LAN\]|Failed to load|Error|tweakdef' 80 " ($Ai, hold $Hold, layout $Layout, game $($sg.Name))"
