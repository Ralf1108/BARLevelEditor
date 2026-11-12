# Starts an Evolution game at once (called by start_evolution.bat): you in team 0 and one computer player in team 1 (each in an ally team of its own), the game
# options of Evolution (lanevolution=1) with the debug mode (lanevodebug=1), the extra game "Level Editor Scenarios" of the installation (data\games\LevelEditorScenarios.txt).
#   -Map "Hooked 1.1"   the map (the name as BAR knows it)
#   -Ai SimpleAI        the computer player (SimpleAI, SimpleDefenderAI, ... or NullAI)
#   -DebugMode 0            without the debug mode
param([string]$Data, [string]$Map = 'Hooked 1.1', [string]$Ai = 'SimpleAI', [int]$DebugMode = 1)
$here = $PSScriptRoot
$repo = Split-Path (Split-Path $here -Parent) -Parent
. (Join-Path (Join-Path $repo 'shared') 'bar_common.ps1')
if (-not $Data) { $memo = Join-Path $env:LOCALAPPDATA 'BAR-Level-Editor\bar_path.txt'; $Data = Join-Path (Find-Bar @() $memo) 'data' }   # no -Data: the installation is searched (and remembered)
$pointer = Join-Path $Data "games\$ScenarioGamePointer"
if (-not (Test-Path $pointer)) { Fail 'The extra game of the Level Editor is not installed: run install_editor.bat first.' }
$game = (Get-Content $pointer)[1].Trim()
$spec = Get-AiSpec $Ai
$exe = Join-Path (Get-Engine $Data).FullName 'spring.exe'
$dbg = if ($DebugMode) { ' lanevodebug=1;' } else { '' }
$script = @"
[game]
{
	[allyteam0] { numallies=0; }
	[allyteam1] { numallies=0; }
	[team0] { allyteam=0; teamleader=0; side=Legion; handicap=0; }
	[team1] { allyteam=1; teamleader=0; side=Legion; handicap=0; }
	[ai0] { shortname=$($spec.Short); version=$($spec.Version); team=1; host=0; name=$($spec.Short)1; }
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; experimentallegionfaction=1; experimentalextraunits=1; lanplay=1; lanevolution=1;$dbg }
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
$file = Join-Path $repo 'LevelEditor\evolution_script_installed.txt'
[IO.File]::WriteAllText($file, $script, (New-Object Text.UTF8Encoding $false))
Write-Host "Evolution on $Map against $($spec.Short)$(if ($DebugMode) { ', debug mode on' }) ..." -ForegroundColor Cyan
# (spring.exe is a window application: "&" does not wait for it and $LASTEXITCODE stays empty, so Start-Process -Wait)
$proc = Start-Process -FilePath $exe -ArgumentList @('--write-dir', "`"$Data`"", "`"$file`"") -Wait -PassThru
if ($proc.ExitCode -ne 0) { Write-Host "The game ended with an error, see $Data\infolog.txt" -ForegroundColor Yellow; exit 1 }
