# Arena test: one sandbox game of the Level Editor (built from the files of this repository: nothing of the installed game is changed) with four
# teams on a flat map and the test widget zz_arena.lua, which works the Arena page (settings, Generate, move, undo, Start, Stop, Clear) and logs
# "[zzar]" lines into infolog.txt of the sandbox (<Work>\data\infolog.txt). The game ends itself (quitforce) when the test is through.
param([int]$WaitSec = 420, [string]$Work = (Join-Path $env:TEMP 'arena_test'), [string]$Data = '', [string]$Map = 'Full Metal Plate 1.7', [switch]$Shots, [switch]$AlongsideGame, [string]$Widget = '')
$tools = $PSScriptRoot
$repo = Split-Path (Split-Path (Split-Path $tools -Parent) -Parent) -Parent
. (Join-Path $repo 'shared\bar_common.ps1'); . (Join-Path $repo 'LevelEditor\scripts\editor_manifest.ps1'); . (Join-Path $tools 'test_common.ps1')
$Data = Resolve-TestData $Data   # the data folder of the installation (-Data, otherwise Find-Bar of bar_common.ps1)
if (-not $AlongsideGame -and (Get-Process spring -ErrorAction SilentlyContinue)) { 'A game is running: aborted'; return }
$exe = (Get-Engine $Data).FullName + '\spring.exe'   # the newest engine (sorted by version, Get-Engine of bar_common.ps1)
$d = New-SandboxData $Work $Data @('LevelEditor')
Copy-Item ("$tools\" + $(if ($Widget) { $Widget } elseif ($Shots) { 'zz_arena_shots.lua' } else { 'zz_arena.lua' })) "$d\LuaUI\Widgets\"
Copy-Item "$tools\..\levels\*.lua" "$d\LevelEditor\"   # the test levels (td_test, ctf_test, rtf_test) for the widgets that load them
Copy-Item "$repo\LevelEditor\levels\demo_*.lua" "$d\LevelEditor\"   # the demo levels (the memory test, the pictures)
if (Test-Path "$repo\LevelEditor\blueprints") { New-Item -ItemType Directory "$d\LevelEditorBlueprints" -Force | Out-Null; Copy-Item "$repo\LevelEditor\blueprints\*" "$d\LevelEditorBlueprints\" -Recurse }   # the sample blueprints (the pictures)

# the extra game "Level Editor" from the files of the repository (as install_editor.ps1 builds it)
Write-EditorGame "$d\games\LevelEditorMod.sdz" (Get-GameVersion $Data)

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
Write-SandboxSettings "$Work\springsettings.cfg" @(60, 60, 2400, 1300) @('LogFlushLevel = 0', 'VSync = 0', 'VSyncGame = 0', 'IdleFpsDivider = 0')
Invoke-SandboxGame $exe "$Work\springsettings.cfg" $d "$d\script.txt" $WaitSec '\[zzar\]|Failed to load|Error'
