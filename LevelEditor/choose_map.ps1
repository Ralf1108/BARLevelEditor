# Start selection for the Level Editor:
#   Main menu: arrow up/down + Enter or a digit key
#   0 = continue the last state
#   1 = new level (choose a map from the list, search while typing)
#   2 = load an existing level (saved levels from the levels folder, search while typing)
#   3 = build a scenario package from a level, 4 = start a built scenario (scenario\scenarios\<id>\start_scenario.ps1)
# Writes editor_script_installed.txt (and for "load" levels\_autoload.txt). Return value 1 on abort.
# Call: choose_map.ps1 -Data <BAR\data>
# Tests without a keyboard: -Test "searchtext" (maps), -TestLevels (saved levels), -TestScenarios (built scenarios), -TestPreview "map name" (draws its preview)
param([Parameter(Mandatory = $true)][string]$Data, [string]$Test = $null, [switch]$TestLevels, [switch]$TestScenarios, [switch]$TestMenu, [switch]$TestOnline, [string]$TestDownload = $null, [string]$TestPreview = $null, [string]$MapsDir = $null)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
$levelsDir = Join-Path $here 'levels'
. (Join-Path $here 'map_preview.ps1')
$pvOk = Initialize-MapPreview $Data   # thumbnails from the lobby package of the game (map_preview.ps1); $false = no previews
$autoloadFile = Join-Path $levelsDir '_autoload.txt'
$lastFile = Join-Path $here 'last_map.txt'

# ---------------------------------------------------------------- installed maps from the archive cache
$cache = Get-ChildItem (Join-Path $Data 'cache') -Filter 'ArchiveCache*.lua' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
$maps = @()
if ($cache) {
    $text = [IO.File]::ReadAllText($cache.FullName)
    $rx = New-Object Text.RegularExpressions.Regex('name = "([^"]+)\.(?:sd7|sdz|sdd)",\s*path = "[^"]*maps/",.*?modtype = 3,\s*name = "([^"]+)"', 'Singleline')
    foreach ($m in $rx.Matches($text)) {
        $file = $m.Groups[1].Value
        $spring = $m.Groups[2].Value
        $maps += [pscustomobject]@{
            Display = ($spring -replace '_', ' ')
            Code    = $file
            Spring  = $spring
            Label   = ('{0}  [{1}]' -f ($spring -replace '_', ' '), $file)
            Search  = (($spring + ' ' + $file) -replace '_', ' ').ToLower()
        }
    }
}
if ($maps.Count -eq 0) {
    foreach ($f in Get-ChildItem (Join-Path $Data 'maps') -Include '*.sd7', '*.sdz' -Recurse -ErrorAction SilentlyContinue) {
        $n = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        $maps += [pscustomobject]@{ Display = ($n -replace '_', ' '); Code = $n; Spring = $n; Label = ('{0}  [{1}]' -f ($n -replace '_', ' '), $n); Search = ($n -replace '_', ' ').ToLower() }
    }
}
$installedMaps = @($maps | Sort-Object Display -Unique)
if (-not $MapsDir) { $MapsDir = Join-Path $Data 'maps' }

# ---------------------------------------------------------------- all BAR maps (online) together with the installed ones
$onlineOk = $false
$onlineMaps = @()
$jsonCache = Join-Path $here 'maps_online_cache.json'
try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $ProgressPreference = 'SilentlyContinue'
    $resp = Invoke-WebRequest -Uri 'https://maps-metadata.beyondallreason.dev/latest/live_maps.validated.json' -UseBasicParsing -TimeoutSec 10
    $content = $resp.Content
    if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
    $parsed = ConvertFrom-Json -InputObject $content
    $onlineMaps = @($parsed | ForEach-Object { $_ })
    [IO.File]::WriteAllText($jsonCache, $content, (New-Object Text.UTF8Encoding($false)))
    $onlineOk = $true
} catch {
    if (Test-Path $jsonCache) {
        try { $parsed = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($jsonCache)); $onlineMaps = @($parsed | ForEach-Object { $_ }); $onlineOk = $true } catch { }
    }
}

$byName = @{}
foreach ($o in $onlineMaps) {
    if (-not $o.springName) { continue }
    $stem = [IO.Path]::GetFileNameWithoutExtension($o.fileName)
    $inst = [bool]($installedMaps | Where-Object { $_.Spring -ieq $o.springName })
    $byName[$o.springName.ToLower()] = [pscustomobject]@{
        Display = ($o.springName -replace '_', ' '); Code = $stem; Spring = $o.springName; Installed = $inst
        Url = $o.downloadURL; FileName = $o.fileName; Md5 = $o.md5
        Search = (($o.springName + ' ' + $stem) -replace '_', ' ').ToLower()
    }
}
foreach ($m in $installedMaps) {
    if (-not $byName.ContainsKey($m.Spring.ToLower())) {
        $byName[$m.Spring.ToLower()] = [pscustomobject]@{
            Display = $m.Display; Code = $m.Code; Spring = $m.Spring; Installed = $true
            Url = $null; FileName = $null; Md5 = $null; Search = $m.Search
        }
    }
}
$maps = @($byName.Values | Sort-Object { $_.Display.ToLower() })
foreach ($m in $maps) {
    $suffix = ''
    if (-not $m.Installed) { $suffix = '   - downloaded after you choose it' }
    $m | Add-Member -NotePropertyName Label -NotePropertyValue ('{0}  [{1}]{2}' -f $m.Display, $m.Code, $suffix) -Force
}
if ($maps.Count -eq 0) { Write-Host 'No maps found.' -ForegroundColor Red; exit 1 }

# Download a map (only after the selection): file into the maps folder, check the checksum
function Download-Map($m, [string]$dir) {
    if (-not $m.Url) { Write-Host 'No download address known.' -ForegroundColor Yellow; return $false }
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        New-Item -ItemType Directory -Force $dir | Out-Null
        $target = Join-Path $dir $m.FileName
        $tmp = $target + '.part'
        if (Test-Path $tmp) { Remove-Item $tmp -Force }
        Write-Host ("Downloading map {0} ..." -f $m.Display) -ForegroundColor Cyan
        $wc = New-Object System.Net.WebClient
        $task = $wc.DownloadFileTaskAsync([Uri]$m.Url, $tmp)
        while (-not $task.IsCompleted) {
            Start-Sleep -Milliseconds 500
            if (Test-Path $tmp) { Write-Host ("`r  {0:N1} MB downloaded" -f ((Get-Item $tmp).Length / 1MB)) -NoNewline }
        }
        Write-Host ''
        if ($task.IsFaulted) { throw $task.Exception.GetBaseException() }
        if ($m.Md5) {
            $hash = (Get-FileHash $tmp -Algorithm MD5).Hash
            if ($hash -ine $m.Md5) { Remove-Item $tmp -Force; throw "Checksum does not match ($hash)" }
        }
        Move-Item $tmp $target -Force
        $m.Installed = $true
        $m.Label = ('{0}  [{1}]' -f $m.Display, $m.Code)
        return $true
    } catch {
        Write-Host ("Download failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
        return $false
    }
}

if ($TestOnline) {
    $onl = 'no'
    if ($onlineOk) { $onl = 'yes' }
    Write-Host ("Online list: {0}, maps in total: {1}, of them installed: {2}" -f $onl, $maps.Count, @($maps | Where-Object { $_.Installed }).Count)
    $maps | Where-Object { -not $_.Installed } | Select-Object -First 5 | ForEach-Object { Write-Host ("  missing: " + $_.Label) }
    exit 0
}
if ($TestPreview) {
    Write-Host ("Previews available: {0}, 24-bit colour: {1}" -f $pvOk, $script:PvTrue)
    Clear-Host
    $okp = Show-MapPreview $TestPreview 2 2 50 24
    [Console]::SetCursorPosition(0, 28)
    Write-Host ("Drawn: {0}" -f $okp)
    exit 0
}
if ($TestDownload) {
    $m = $maps | Where-Object { $_.Spring -ieq $TestDownload } | Select-Object -First 1
    if (-not $m) { Write-Host 'Map not found'; exit 1 }
    $ok = Download-Map $m $MapsDir
    Write-Host ("Result: {0}" -f $ok)
    exit 0
}

# ---------------------------------------------------------------- saved levels
# Reads a level file and returns name, map, number of units and notes about the map
function Read-Level($f, [string]$displayName) {
    $t = [IO.File]::ReadAllText($f.FullName)
    $mapName = ''
    $mm = [regex]::Match($t, 'map\s*=\s*"([^"]*)"')
    if ($mm.Success) { $mapName = $mm.Groups[1].Value }
    # Count units and features separately: the entries before featureloadout are units, those after it are features
    $fm = [regex]::Match($t, '(?m)^\s*featureloadout\s*=')
    $fi = if ($fm.Success) { $fm.Index } else { -1 }
    $unitPart = if ($fi -ge 0) { $t.Substring(0, $fi) } else { $t }
    $featPart = if ($fi -ge 0) { $t.Substring($fi) } else { '' }
    $count = ([regex]::Matches($unitPart, "name\s*=\s*'")).Count
    $featCount = ([regex]::Matches($featPart, "name\s*=\s*'")).Count
    $mapItem = $maps | Where-Object { $_.Spring -ieq $mapName } | Select-Object -First 1
    $installed = [bool]($mapItem -and $mapItem.Installed)
    $loadable = [bool]($mapItem -and -not $mapItem.Installed -and $mapItem.Url)
    $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    if (-not $displayName) { $displayName = $name }
    $featText = if ($featCount -gt 0) { ", $featCount Features" } else { '' }
    $label = '{0}   Map: {1}   {2} units{3}   {4}' -f $displayName, ($mapName -replace '_', ' '), $count, $featText, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
    if (-not $installed) { if ($loadable) { $label += '   (map is downloaded after you choose it)' } else { $label += '   (map not available!)' } }
    return [pscustomobject]@{ Name = $name; Map = $mapName; Count = $count; Installed = $installed; Loadable = $loadable; MapItem = $mapItem; Time = $f.LastWriteTime; Label = $label; Search = ($displayName + ' ' + $mapName).ToLower() -replace '_', ' ' }
}

function Get-Levels {
    $res = @()
    if (-not (Test-Path $levelsDir)) { return $res }
    foreach ($f in Get-ChildItem $levelsDir -Filter '*.lua' | Where-Object { -not $_.Name.StartsWith('_') }) {
        $res += Read-Level $f $null
    }
    return @($res | Sort-Object Time -Descending)
}

# Built scenarios: folders scenario\scenarios\<id> with a scenario.txt (made by key 3); newest first
function Get-Scenarios {
    $res = @()
    $dir = Join-Path $here 'scenario\scenarios'
    if (-not (Test-Path $dir)) { return $res }
    foreach ($d in Get-ChildItem $dir -Directory) {
        $start = Join-Path $d.FullName 'start_scenario.ps1'
        $script = Join-Path $d.FullName 'scenario.txt'
        if (-not ((Test-Path $start) -and (Test-Path $script))) { continue }
        $map = [regex]::Match([IO.File]::ReadAllText($script), '(?m)^\s*mapname\s*=\s*(.+?);').Groups[1].Value.Trim()
        $title = $d.Name
        $readme = Join-Path $d.FullName 'README.txt'
        if (Test-Path $readme) { $first = (Get-Content $readme -TotalCount 1 -Encoding UTF8); if ($first) { $title = $first.Trim([char]0xFEFF).Trim() } }
        $td = if (Test-Path (Join-Path $d.FullName 'td_waves.lua')) { '   Tower Defense' } else { '' }
        $label = '{0}   "{1}"   Map: {2}{3}   {4}' -f $d.Name, $title, ($map -replace '_', ' '), $td, $d.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        $res += [pscustomobject]@{ Name = $d.Name; Path = $d.FullName; Time = $d.LastWriteTime; Label = $label; Search = ($d.Name + ' ' + $title + ' ' + $map).ToLower() -replace '_', ' ' }
    }
    return @($res | Sort-Object Time -Descending)
}

# The state saved by the editor when leaving (and every 2 minutes)
function Get-LastLevel {
    $f = Join-Path $levelsDir '_last.lua'
    if (-not (Test-Path $f)) { return $null }
    return Read-Level (Get-Item $f) 'Last state'
}

if ($TestMenu) {
    $lv = @(Get-Levels)
    Write-Host ("Level folder: {0}" -f $levelsDir)
    Write-Host ("Saved levels found: {0}" -f $lv.Count)
    $hint = if ($lv.Count -eq 0) { ' (grayed out, no levels yet)' } else { '' }
    Write-Host ('Menu: 0 = Continue the last state, 1 = New level, 2 = Load an existing level, 3 = Scenario package' + $hint)
    $ll = Get-LastLevel
    if ($ll) { Write-Host ('       0 = Continue the last state: ' + $ll.Label) } else { Write-Host '       0 = Continue the last state (grayed out, no state saved yet)' }
    exit 0
}

if ($TestScenarios) {
    $sc = @(Get-Scenarios)
    Write-Host ("{0} built scenarios:" -f $sc.Count)
    $sc | ForEach-Object { Write-Host ("  " + $_.Label) }
    exit 0
}

if ($TestLevels) {
    $lv = @(Get-Levels)
    Write-Host ("{0} saved levels:" -f $lv.Count)
    $lv | ForEach-Object { Write-Host ("  " + $_.Label) }
    exit 0
}

$last = if (Test-Path $lastFile) { (Get-Content $lastFile -Raw).Trim() } else { '' }

function Get-Filtered($items, [string]$q, $first) {
    $tokens = @($q.ToLower().Split(' ', [StringSplitOptions]::RemoveEmptyEntries))
    $res = @($items | Where-Object { $s = $_.Search; -not ($tokens | Where-Object { -not $s.Contains($_) }) })
    if ($tokens.Count -eq 0 -and $first) {
        $res = @($res | Where-Object { & $first $_ }) + @($res | Where-Object { -not (& $first $_) })
    }
    return , $res
}

if ($Test -ne $null -and $Test -ne '') {
    $r = Get-Filtered $maps $Test $null
    Write-Host ("{0} maps in total, {1} hits for '{2}':" -f $maps.Count, $r.Count, $Test)
    $r | Select-Object -First 20 | ForEach-Object { Write-Host ("  {0}  -> {1}" -f $_.Label, $_.Spring) }
    exit 0
}

# ---------------------------------------------------------------- selection with search while typing
# Returns the chosen element, $null on Esc
# $previewFn (optional): script block that returns the map name (Spring name) of an item; its picture is drawn right of the list
function Show-Chooser($items, [string]$title, [string]$hint, $firstFn, $previewFn = $null) {
    $items = @($items)
    $query = ''; $sel = 0; $offset = 0
    Clear-Host
    Write-Host $title -ForegroundColor Cyan
    Write-Host $hint -ForegroundColor DarkGray
    Write-Host ''
    $top = [Console]::CursorTop
    $res = $null; $resQuery = $null
    $flags = $null   # '(last)' marker per hit, only computed on a new search
    $prev = @{}      # last drawn content per screen line; only changed lines are rewritten
    $lastW = -1; $lastH = -1
    $pvKey = $null   # what the preview area shows now
    $fg0 = [Console]::ForegroundColor; $bg0 = [Console]::BackgroundColor
    while ($true) {
        if ($resQuery -ne $query -or $null -eq $res) {
            $res = Get-Filtered $items $query $firstFn
            $resQuery = $query
            $flags = New-Object 'bool[]' $res.Count
            if ($firstFn) { for ($i = 0; $i -lt $res.Count; $i++) { $flags[$i] = [bool](& $firstFn $res[$i]) } }
        }
        if ($sel -ge $res.Count) { $sel = [Math]::Max(0, $res.Count - 1) }
        $w = [Console]::WindowWidth - 1
        $h = [Console]::WindowHeight
        if ($w -ne $lastW -or $h -ne $lastH) { $prev = @{}; $pvKey = $null; $lastW = $w; $lastH = $h; Clear-Host; Write-Host $title -ForegroundColor Cyan; Write-Host $hint -ForegroundColor DarkGray; Write-Host ''; $top = [Console]::CursorTop }
        $rows = [Math]::Max(3, [Math]::Min(20, $h - $top - 4))
        # Preview: right of the list if the window is wide enough (the list keeps at least 55 characters)
        $lw = $w; $pvW = 0
        if ($previewFn -and $pvOk) {
            $pvW = [Math]::Min(2 * ($rows + 2), 64)
            if ($w - $pvW - 2 -lt 55) { $pvW = $w - 2 - 55 }
            if ($pvW -lt 20) { $pvW = 0 } else { $lw = $w - $pvW - 2 }
        }
        if ($sel -lt $offset) { $offset = $sel }
        if ($sel -ge $offset + $rows) { $offset = $sel - $rows + 1 }
        # Build the lines: index 0 = search, 1 = counter, 2.. = lines of the list
        $lines = New-Object 'string[]' ($rows + 2)
        $kinds = New-Object 'int[]' ($rows + 2)   # 0 normal, 1 gelb, 2 grau, 3 markiert
        $lines[0] = ('Search: ' + $query + '_'); $kinds[0] = 1
        $lines[1] = ("{0} of {1}" -f $res.Count, $items.Count); $kinds[1] = 2
        for ($i = 0; $i -lt $rows; $i++) {
            $idx = $offset + $i
            $line = ''
            if ($idx -lt $res.Count) {
                $line = '  ' + $res[$idx].Label
                if ($flags[$idx]) { $line += '  (last)' }
                if ($idx -eq $sel) { $kinds[$i + 2] = 3 }
            }
            $lines[$i + 2] = $line
        }
        [Console]::CursorVisible = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $t = $lines[$i]
            if ($t.Length -gt $lw) { $t = $t.Substring(0, $lw) }
            $key = [string]$kinds[$i] + $t
            if ($prev[$i] -eq $key) { continue }
            $prev[$i] = $key
            [Console]::SetCursorPosition(0, $top + $i)
            switch ($kinds[$i]) {
                1 { [Console]::ForegroundColor = 'Yellow' }
                2 { [Console]::ForegroundColor = 'DarkGray' }
                3 { [Console]::ForegroundColor = 'Black'; [Console]::BackgroundColor = 'Gray' }
            }
            [Console]::Write($t.PadRight($lw))
            [Console]::ForegroundColor = $fg0; [Console]::BackgroundColor = $bg0
        }
        if ($pvW -gt 0) {
            $spring = $null
            if ($res.Count -gt 0) { $spring = & $previewFn $res[$sel] }
            $k2 = "$spring|$pvW|$rows"
            if ($k2 -ne $pvKey) { $pvKey = $k2; [void](Show-MapPreview $spring ($lw + 2) $top $pvW ($rows + 2)) }
        }
        [Console]::SetCursorPosition(0, [Math]::Min($top + $rows + 2, $h - 1))
        # Process the inputs; if several are pending (key held), process all first, then draw
        do {
            $k = [Console]::ReadKey($true)
            switch ($k.Key) {
                'Enter'     { if ($res.Count -gt 0) { [Console]::CursorVisible = $true; return $res[$sel] } }
                'Escape'    { [Console]::CursorVisible = $true; return $null }
                'UpArrow'   { if ($sel -gt 0) { $sel-- } }
                'DownArrow' { if ($sel -lt $res.Count - 1) { $sel++ } }
                'PageUp'    { $sel = [Math]::Max(0, $sel - $rows) }
                'PageDown'  { $sel = [Math]::Min([Math]::Max(0, $res.Count - 1), $sel + $rows) }
                'Home'      { $sel = 0 }
                'End'       { $sel = [Math]::Max(0, $res.Count - 1) }
                'Backspace' { if ($query.Length -gt 0) { $query = $query.Substring(0, $query.Length - 1); $sel = 0; $offset = 0 } }
                default {
                    if ($k.KeyChar -ne [char]0 -and -not [char]::IsControl($k.KeyChar)) { $query += $k.KeyChar; $sel = 0; $offset = 0 }
                }
            }
        } while ([Console]::KeyAvailable)
        # Limit the selection after the last key press (the search is recomputed above)
        if ($resQuery -eq $query -and $sel -ge $res.Count) { $sel = [Math]::Max(0, $res.Count - 1) }
    }
}

# ---------------------------------------------------------------- write the start script
function Write-StartScript([string]$mapSpring) {
    $game = 'Level Editor 1'
    $script = @"
[game]
{
	[allyteam0] { numallies=0; }
	[allyteam1] { numallies=0; }
	[team0] { allyteam=0; teamleader=0; side=Armada; handicap=0; }
	[team1] { allyteam=1; teamleader=0; side=Cortex; handicap=0; }
	[ai0] { shortname=NullAI; team=1; host=0; name=Null1; }
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; maxunits=32000; leveleditor=1; experimentallegionfaction=1; experimentalextraunits=1; releasecandidates=1; }
	ishost=1;
	hostip=127.0.0.1;
	myplayername=Player;
	gametype=$game;
	mapname=$mapSpring;
	startpostype=0;
	numplayers=1;
	numusers=2;
	nohelperais=0;
}
"@
    [IO.File]::WriteAllText((Join-Path $here 'editor_script_installed.txt'), $script, (New-Object Text.UTF8Encoding($false)))
}

function Set-Autoload([string]$name) {
    New-Item -ItemType Directory -Force $levelsDir | Out-Null
    [IO.File]::WriteAllText($autoloadFile, $name, (New-Object Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------- main menu
while ($true) {
    $levels = @(Get-Levels)
    $lastLevel = Get-LastLevel
    # The menu always appears: 0 = continue the last state, 1 = new level, 2 = load a saved level, 3 = scenario package
    # (the last two only if there are levels already). Choose with arrow up/down and Enter or with the digit key.
    $haveLevels = $levels.Count -gt 0
    $scenarios = @(Get-Scenarios)
    $menu = @(
        @{ Key = '0'; Mode = 3; On = [bool]$lastLevel; Text = $(if ($lastLevel) { 'Continue the last state: {0}' -f $lastLevel.Label } else { 'Continue the last state (no state saved yet)' }) },
        @{ Key = '1'; Mode = 1; On = $true; Text = 'Create a new level (choose a map)' },
        @{ Key = '2'; Mode = 2; On = $haveLevels; Text = $(if ($haveLevels) { 'Load an existing level ({0} saved)' -f $levels.Count } else { 'Load an existing level (no saved levels yet)' }) },
        @{ Key = '3'; Mode = 4; On = $haveLevels; Text = $(if ($haveLevels) { 'Create a scenario package (ZIP) from a level (to pass on, official game)' } else { 'Create a scenario package (ZIP) from a level (no saved levels yet)' }) },
        @{ Key = '4'; Mode = 5; On = ($scenarios.Count -gt 0); Text = $(if ($scenarios.Count -gt 0) { 'Start a scenario ({0} built)' -f $scenarios.Count } else { 'Start a scenario (none built yet: key 3)' }) }
    )
    $sel = 0
    while (-not $menu[$sel].On) { $sel++ }
    Clear-Host
    Write-Host 'Level Editor' -ForegroundColor Cyan
    Write-Host ''
    $menuTop = [Console]::CursorTop
    Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''
    Write-Host ''
    Write-Host 'Arrow up/down + Enter or digit key, Esc = cancel' -ForegroundColor DarkGray
    $mode = 0
    $fg0 = [Console]::ForegroundColor; $bg0 = [Console]::BackgroundColor
    while ($mode -eq 0) {
        $w = [Console]::WindowWidth - 1
        for ($i = 0; $i -lt $menu.Count; $i++) {
            $line = ('  {0}  {1}' -f $menu[$i].Key, $menu[$i].Text)
            if ($line.Length -gt $w) { $line = $line.Substring(0, $w) }
            [Console]::SetCursorPosition(0, $menuTop + $i)
            if ($i -eq $sel) { [Console]::ForegroundColor = 'Black'; [Console]::BackgroundColor = 'Gray' }
            elseif (-not $menu[$i].On) { [Console]::ForegroundColor = 'DarkGray' }
            elseif ($menu[$i].Key -eq '0') { [Console]::ForegroundColor = 'Green' }
            [Console]::Write($line.PadRight($w))
            [Console]::ForegroundColor = $fg0; [Console]::BackgroundColor = $bg0
        }
        [Console]::SetCursorPosition(0, $menuTop + $menu.Count + 2)
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Escape') { Clear-Host; Write-Host 'Cancelled.'; exit 1 }
        switch ($k.Key) {
            'Enter'     { $mode = $menu[$sel].Mode }
            'UpArrow'   { for ($j = $sel - 1; $j -ge 0; $j--) { if ($menu[$j].On) { $sel = $j; break } } }
            'DownArrow' { for ($j = $sel + 1; $j -lt $menu.Count; $j++) { if ($menu[$j].On) { $sel = $j; break } } }
            'Home'      { for ($j = 0; $j -lt $menu.Count; $j++) { if ($menu[$j].On) { $sel = $j; break } } }
            'End'       { for ($j = $menu.Count - 1; $j -ge 0; $j--) { if ($menu[$j].On) { $sel = $j; break } } }
            default     { foreach ($m in $menu) { if ($m.On -and $k.KeyChar -eq $m.Key[0]) { $mode = $m.Mode } } }
        }
    }

    if ($mode -eq 5) {
        # Start a built scenario: its own starter finds BAR, builds the extra game of a Tower Defense scenario and starts the game
        $chosen = Show-Chooser $scenarios 'Start a scenario: choose one' 'Type to search, arrow up/down, Enter = start, Esc = back' $null
        if (-not $chosen) { continue }
        Clear-Host
        Write-Host ('Starting the scenario ' + $chosen.Name + ' ...') -ForegroundColor Cyan
        & powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $chosen.Path 'start_scenario.ps1') -BarPath (Split-Path $Data -Parent)
        exit 1 # the scenario was played (or could not start): nothing else to start
    }

    if ($mode -eq 4) {
        # The scenario info is stored in the level (edited in the editor with button I); only the package is built here.
        $chosen = Show-Chooser $levels 'Create a scenario package: choose a level' 'Type to search, arrow up/down, Enter = build, Esc = back' $null { param($l) $l.Map }
        if (-not $chosen) { continue }
        Clear-Host
        $maker = Join-Path $PSScriptRoot 'scenario\scenario_builder.ps1'
        & $maker -Level $chosen.Name -Auto -AskName
        Write-Host ''
        Write-Host 'Continue with any key.'
        [void][Console]::ReadKey($true)
        continue
    }

    if ($mode -eq 1) {
        $lastMap = $last
        $chosen = Show-Chooser $maps ('New level: choose a map   (' + $maps.Count + ' maps, ' + @($maps | Where-Object { $_.Installed }).Count + ' installed)') 'Type to search, arrow up/down, Enter = start (missing maps are only downloaded then), Esc = back' { param($m) $m.Spring -eq $lastMap } { param($m) $m.Spring }
        if (-not $chosen) { continue }
        if (-not $chosen.Installed) {
            Clear-Host
            if (-not (Download-Map $chosen $MapsDir)) {
                Write-Host 'Continue with any key.'
                [void][Console]::ReadKey($true)
                continue
            }
        }
        Set-Content -Path $lastFile -Value $chosen.Spring -Encoding ASCII
        Write-StartScript $chosen.Spring
        if (Test-Path $autoloadFile) { Remove-Item $autoloadFile -Force }
        Clear-Host
        Write-Host ("Starting on: {0}" -f $chosen.Label) -ForegroundColor Green
        exit 0
    }

    if ($mode -eq 3) {
        $chosen = $lastLevel
    } else {
        $chosen = Show-Chooser $levels 'Load an existing level' 'Type to search, arrow up/down, Enter = load and start, Esc = back' $null { param($l) $l.Map }
    }
    if (-not $chosen) { continue }
    if (-not $chosen.Installed) {
        Clear-Host
        $loaded = $false
        if ($chosen.Loadable) { $loaded = Download-Map $chosen.MapItem $MapsDir }
        else { Write-Host ('The map ' + $chosen.Map + ' of this level is not installed and not in the map list.') -ForegroundColor Yellow }
        if (-not $loaded) {
            Write-Host 'Continue with any key.'
            [void][Console]::ReadKey($true)
            continue
        }
    }
    Write-StartScript $chosen.Map
    Set-Autoload $chosen.Name
    Clear-Host
    Write-Host ("Starting level '{0}' on {1} ({2} units are being loaded)" -f $chosen.Name, ($chosen.Map -replace '_', ' '), $chosen.Count) -ForegroundColor Green
    exit 0
}
