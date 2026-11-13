# Starts a Renegade game at once (called by start_renegade.bat): you in team 0 (a Peewee in the first person view instead of the commander) and one computer
# player in team 1 (each in an ally team of its own), game option lanrenegade=1, the extra game "Level Editor Scenarios" of the installation (data\games\LevelEditorScenarios.txt).
#   -Map "Hooked 1.1"   the map (the name as BAR knows it)
#   -Ai NullAI          the computer player (NullAI does nothing itself; SimpleAI, ... build and fight)
#   -Bots 3             computer Peewees of that player that walk around and fight you (a lost one comes back; 0 = none)
#   -DebugMode 0        without the debug menu (the button above the weapon: turn into another unit)
#   -QuickTest          for quick tests: without the Legion units, the extra units of the release candidates and the Scavenger and Raptor units (they take time to load); without it all of them are loaded
param([switch]$DryRun, [string]$Data, [string]$Map = 'Hooked 1.1', [string]$Ai = 'NullAI', [int]$Bots = 3, [int]$DebugMode = 1, [switch]$QuickTest)
$here = $PSScriptRoot
$repo = Split-Path (Split-Path $here -Parent) -Parent
. (Join-Path (Join-Path $repo 'shared') 'bar_common.ps1')
$ctx = Resolve-ExtraGame $Data
$Data = $ctx.Data
$game = $ctx.Game
$spec = Get-AiSpec $Ai
$script = @"
[game]
{
	[allyteam0] { numallies=0; }
	[allyteam1] { numallies=0; }
	[team0] { allyteam=0; teamleader=0; side=Armada; handicap=0; }
	[team1] { allyteam=1; teamleader=0; side=Cortex; handicap=0; }
	[ai0] { shortname=$($spec.Short); version=$($spec.Version); team=1; host=0; name=$($spec.Short)1; }
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend;$(if (-not $QuickTest) { ' experimentallegionfaction=1; experimentalextraunits=1; releasecandidates=1; forceallunits=1;' }) lanplay=1; lanrenegade=1; lanrenebots=$Bots;$(if ($DebugMode) { ' lanrenedebug=1;' }) }
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
$file = Join-Path $repo 'LevelEditor\renegade_script_installed.txt'
$message = "Renegade on $Map against $($spec.Short) with $Bots Peewees: mouse = look, W A S D = walk, left / right / middle button = short range / long range / missiles, Insert (or the key left of the 1) = normal camera and back$(if ($DebugMode) { ", Tab = free mouse for the debug menu" }) ..."
Start-ExtraGame $ctx $script $file $message -dryRun:$DryRun
