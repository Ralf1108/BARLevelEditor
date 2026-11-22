# Starts a test game of the Experimental Units at once (called by start_experimental.bat): you (Armada) in team 0 and a computer player that does
# nothing (NullAI) in team 1, the extra game "Level Editor Scenarios" of the installation. The game option lanexpdemo=1 makes the gadget
# lava_generator.lua place a Volcano with a Lava Extractor, a Carrier, a Cargo Truck, a Forklift and a vehicle plant next to your start.
#   -Map "Full Metal Plate 1.7"   the map (the name as BAR knows it)
param([switch]$DryRun, [string]$Data, [string]$Map = 'Full Metal Plate 1.7')
$here = $PSScriptRoot
$repo = Split-Path (Split-Path $here -Parent) -Parent
. (Join-Path (Join-Path $repo 'shared') 'bar_common.ps1')
$ctx = Resolve-ExtraGame $Data
$Data = $ctx.Data
$game = $ctx.Game
$spec = Get-AiSpec 'NullAI'
$script = @"
[game]
{
	[allyteam0] { numallies=0; }
	[allyteam1] { numallies=0; }
	[team0] { allyteam=0; teamleader=0; side=Armada; handicap=0; }
	[team1] { allyteam=1; teamleader=0; side=Cortex; handicap=0; }
	[ai0] { shortname=$($spec.Short); version=$($spec.Version); team=1; host=0; name=$($spec.Short)1; }
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; lanplay=1; lanexpunits=1; lanexpdemo=1; }
	ishost=1;
	hostip=127.0.0.1;
	myplayername=Player;
	gametype=$game;
	mapname=$Map;
	startpostype=0;
	numplayers=1;
	numusers=2;
	nohelperais=0;
}
"@
$file = Join-Path $repo 'LevelEditor\experimental_script_installed.txt'
$message = "Experimental Units on $($Map): a Volcano with a Lava Extractor, Carrier, Cargo Truck, Forklift and a vehicle plant next to your start ..."
Start-ExtraGame $ctx $script $file $message -dryRun:$DryRun
