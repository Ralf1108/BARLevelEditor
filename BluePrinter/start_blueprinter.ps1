# Installs the BluePrinter widget when it is not up to date and starts a small test game with it (run through start_blueprinter.bat).
# Use it to look at the menu after changing bluePrinter.lua or shared\editor_common.lua.
param([string]$Map = $null)
$ErrorActionPreference = 'Stop'

# 1. Install, but only when the installed files differ from the ones in this repository (the setup also sets $bar and $data)
$here = $PSScriptRoot
$shared = Join-Path (Split-Path $here -Parent) 'shared'
. (Join-Path $shared 'bar_common.ps1')
$bar = Find-Bar
$data = Join-Path $bar 'data'
$pairs = @(
    @((Join-Path $here 'bluePrinter.lua'), (Join-Path $data 'LuaUI\Widgets\bluePrinter.lua')),
    @((Join-Path $shared 'editor_common.lua'), (Join-Path $data 'LuaUI\Include\editor_common.lua')),
    @((Join-Path $shared 'bar_rules.lua'), (Join-Path $data 'LuaUI\Include\bar_rules.lua')))
$stale = -not (Test-Path (Join-Path $data 'LuaUI\Config\BluePrinter'))
foreach ($p in $pairs) {
    if (-not (Test-Path $p[1]) -or (Get-FileHash $p[0]).Hash -ne (Get-FileHash $p[1]).Hash) { $stale = $true }
}
if ($stale) {
    Write-Host 'The BluePrinter is not up to date: running the setup ...' -ForegroundColor Cyan
    . (Join-Path $here 'install_blueprinter.ps1')
} else {
    Write-Host 'The BluePrinter is up to date.'
}

# 2. Engine
$engineDir = Get-Engine $data

# 3. Installed game version
$game = Get-GameVersion $data

# 4. Map: given one, otherwise the first installed map
if (-not $Map) {
    $cache = Get-ChildItem (Join-Path $data 'cache') -Filter 'ArchiveCache*.lua' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($cache) {
        $m = [regex]::Match([IO.File]::ReadAllText($cache.FullName), 'modtype = 3,\s*name = "([^"]+)"')
        if ($m.Success) { $Map = $m.Groups[1].Value }
    }
}
if (-not $Map) { Fail 'No installed map found. Start BAR once and download a map, or pass -Map "Map Name".' }

# 5. Start script: one player with a commander against a passive AI
$script = @"
[game]
{
	[allyteam0] { numallies=0; }
	[allyteam1] { numallies=0; }
	[team0] { allyteam=0; teamleader=0; side=Armada; handicap=0; }
	[team1] { allyteam=1; teamleader=0; side=Cortex; handicap=0; }
	[ai0] { shortname=NullAI; team=1; host=0; name=Null1; }
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; }
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
$out = Join-Path $env:TEMP 'bar_blueprinter_start.txt'
[IO.File]::WriteAllText($out, $script, (New-Object Text.UTF8Encoding($false)))
Write-Host "Game: $game"
Write-Host "Map: $Map"
Write-Host 'Starting the game ... (BluePrinter: Settings -> allow user widgets, then F11 -> switch BluePrinter on; /luaui reload after changes)'
& (Join-Path $engineDir.FullName 'spring.exe') --write-dir $data $out
