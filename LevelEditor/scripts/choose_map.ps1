# Start selection for the Level Editor:
#   Main menu: arrow up/down + Enter or a digit key
#   0 = continue the last saved map (the state saved by the editor)
#   1 = new level (choose a map from the list, search while typing)
#   2 = load an existing level (saved levels from the levels folder, search while typing)
#   3 = build a scenario package from a level, 4 = start a built scenario (scenario\scenarios\<id>\scenario.txt with the current starter of scenario\template)
#   5 = build a package again from its level (upgrade), 6 = play a level at once (temporary scenario, nothing is built or saved; the other players of a
#   hosted game get it from the host through the lobby)
# Writes editor_script_installed.txt in the LevelEditor folder (and for "load" levels\_autoload.txt); remembers the last map and the map list in
# %LOCALAPPDATA%\BAR-Level-Editor. Return value 1 on abort.
# Call: choose_map.ps1 -Data <BAR\data>
# Tests without a keyboard: -Test "searchtext" (maps), -TestLevels (saved levels), -TestScenarios (built scenarios), -TestPreview "map name" (draws its preview)
param([Parameter(Mandatory = $true)][string]$Data, [string]$Test = $null, [switch]$TestLevels, [switch]$TestScenarios, [switch]$TestMenu, [switch]$TestOnline, [string]$TestDownload = $null, [string]$TestPreview = $null, [string]$MapsDir = $null)
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot                    # scripts
$root = Split-Path $here -Parent        # LevelEditor (levels, scenario, the generated start script)
$userDir = Join-Path $env:LOCALAPPDATA 'BAR-Level-Editor'   # what the editor remembers for the user: last map, cache of the map list
$levelsDir = Join-Path $root 'levels'
. (Join-Path $here 'map_preview.ps1')
$pvOk = Initialize-MapPreview $Data   # thumbnails from the lobby package of the game (map_preview.ps1); $false = no previews
. (Join-Path $root 'scenario\template\lobby.ps1')   # the lobby of a hosted game (the start menu starts it through start_scenario.ps1), its version and the cache
try { [void](Remove-OldCache) } catch { }   # old scenarios and maps from hosts, half-finished downloads (lobby.ps1)
$autoloadFile = Join-Path $levelsDir '_autoload.txt'
$lastFile = Join-Path $userDir 'Last Map.txt'
$scavFile = Join-Path $userDir 'Scav Units.txt'   # 1 = the editor loads the Scavenger and Raptor units (game option forceallunits; the start takes about 10 s longer)
function Get-ScavSetting { return ((Test-Path $scavFile) -and (([IO.File]::ReadAllText($scavFile)).Trim() -eq '1')) }

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
# The list of all maps comes from the map service of BAR. With a cached list the menu starts at once from the cache and a hidden background process
# fetches the new list for the next start (it writes the cache through a temporary file); only without a cache the list is fetched here (10 s at most).
$onlineOk = $false
$onlineMaps = @()
$jsonCache = Join-Path $userDir 'Online Maps Cache.json'
$mapListUrl = 'https://maps-metadata.beyondallreason.dev/latest/live_maps.validated.json'
if (Test-Path $jsonCache) {
    try { $parsed = ConvertFrom-Json -InputObject ([IO.File]::ReadAllText($jsonCache)); $onlineMaps = @($parsed | ForEach-Object { $_ }); $onlineOk = $true } catch { }
}
if ($onlineOk) {
    $refresh = "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; " +
               "try { `$c = (Invoke-WebRequest -Uri '$mapListUrl' -UseBasicParsing -TimeoutSec 30).Content; if (`$c -is [byte[]]) { `$c = [Text.Encoding]::UTF8.GetString(`$c) }; " +
               "[void](ConvertFrom-Json -InputObject `$c); `$tmp = '$jsonCache.tmp'; [IO.File]::WriteAllText(`$tmp, `$c, (New-Object Text.UTF8Encoding(`$false))); Move-Item `$tmp '$jsonCache' -Force } catch { }"
    try { Start-Process powershell -WindowStyle Hidden -ArgumentList @('-NoProfile', '-Command', $refresh) | Out-Null } catch { }
} else {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $ProgressPreference = 'SilentlyContinue'
        $resp = Invoke-WebRequest -Uri $mapListUrl -UseBasicParsing -TimeoutSec 10
        $content = $resp.Content
        if ($content -is [byte[]]) { $content = [Text.Encoding]::UTF8.GetString($content) }
        $parsed = ConvertFrom-Json -InputObject $content
        $onlineMaps = @($parsed | ForEach-Object { $_ })
        New-Item -ItemType Directory -Force $userDir | Out-Null
        [IO.File]::WriteAllText($jsonCache, $content, (New-Object Text.UTF8Encoding($false)))
        $onlineOk = $true
    } catch { }
}

$byName = @{}
$installedNames = New-Object 'System.Collections.Generic.HashSet[string]' ([StringComparer]::OrdinalIgnoreCase)   # (one lookup per online map instead of a search through all installed ones)
foreach ($m in $installedMaps) { [void]$installedNames.Add([string]$m.Spring) }
foreach ($o in $onlineMaps) {
    if (-not $o.springName) { continue }
    $stem = [IO.Path]::GetFileNameWithoutExtension($o.fileName)
    $inst = $installedNames.Contains([string]$o.springName)
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
    $m | Add-Member -NotePropertyName Label -NotePropertyValue $m.Display -Force
}
if ($maps.Count -eq 0) { Write-Host 'No maps found.' -ForegroundColor Red; exit 1 }

# Download a map (only after the selection): file into the maps folder, check the checksum
function Download-Map($m, [string]$dir) {
    if (-not $m.Url) { Write-Host 'No download address known.' -ForegroundColor Yellow; return $false }
    # the file name comes from the online list: only a plain map file name may become a path (Test-MapFileName of lobby.ps1)
    if (-not (Test-MapFileName ([string]$m.FileName))) { Write-Host "The map list names an unusable file name: '$($m.FileName)'." -ForegroundColor Yellow; return $false }
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
        $m.Label = $m.Display
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
    $forceAll = [bool]([regex]::IsMatch($t, 'requiredmodoptions\s*=\s*\{[^}]*forceallunits'))   # the level holds Scavenger or Raptor units
    $ai1 = [regex]::Match($t, '"teamai"\s*:\s*\{[^}]*"1"\s*:\s*"([^"]+)"')   # AI of team 1 from the AI page of the editor
    $name = [IO.Path]::GetFileNameWithoutExtension($f.Name)
    if (-not $displayName) { $displayName = $name }
    $featText = if ($featCount -gt 0) { ", $featCount Features" } else { '' }
    $label = '{0}   Map: {1}   {2} units{3}   {4}' -f $displayName, ($mapName -replace '_', ' '), $count, $featText, $f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
    if (-not $installed) { if ($loadable) { $label += '   (map is downloaded after you choose it)' } else { $label += '   (map not available!)' } }
    return [pscustomobject]@{ Ai1 = $(if ($ai1.Success) { $ai1.Groups[1].Value } else { '' }); ForceAll = $forceAll; Name = $name; Map = $mapName; Count = $count; Installed = $installed; Loadable = $loadable; MapItem = $mapItem; Time = $f.LastWriteTime; Label = $label; Search = ($displayName + ' ' + $mapName).ToLower() -replace '_', ' ' }
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
    $dir = Join-Path $root 'scenario\scenarios'
    if (-not (Test-Path $dir)) { return $res }
    foreach ($d in Get-ChildItem $dir -Directory) {
        $script = Join-Path $d.FullName 'scenario.txt'
        if (-not (Test-Path $script)) { continue }   # the starter is the current one of the editor, so a scenario only needs its scenario.txt
        $map = [regex]::Match([IO.File]::ReadAllText($script), '(?m)^\s*mapname\s*=\s*(.+?);').Groups[1].Value.Trim()
        $title = $d.Name
        $readme = Join-Path $d.FullName 'README.txt'
        if (Test-Path $readme) { $first = (Get-Content $readme -TotalCount 1 -Encoding UTF8); if ($first) { $title = $first.Trim([char]0xFEFF).Trim() } }
        $td = if ((Get-Content (Join-Path $d.FullName 'scenario.txt') -Raw -ErrorAction SilentlyContinue) -match 'tdconfig=') { '   Tower Defense' } else { '' }
        $label = '{0}   "{1}"   Map: {2}{3}   {4}' -f $d.Name, $title, ($map -replace '_', ' '), $td, $d.LastWriteTime.ToString('yyyy-MM-dd HH:mm')
        $res += [pscustomobject]@{ Name = $d.Name; Path = $d.FullName; Time = $d.LastWriteTime; Label = $label; Search = ($d.Name + ' ' + $title + ' ' + $map).ToLower() -replace '_', ' ' }
    }
    return @($res | Sort-Object Time -Descending)
}

# The level a built scenario came from: the one whose saved scenario info has the ID of the scenario ("sid" in the block scenario of the level file),
# otherwise the one whose name gives that ID (letters and digits only, lowercase)
function Find-ScenarioLevel([string]$sid) {
    $all = @(Get-Levels)
    foreach ($l in $all) {
        $t = [IO.File]::ReadAllText((Join-Path $levelsDir ($l.Name + '.lua')))
        $m = [regex]::Match($t, '"sid"\s*:\s*"([^"]*)"')
        if ($m.Success -and $m.Groups[1].Value -ieq $sid) { return $l }
    }
    foreach ($l in $all) { if (($l.Name.ToLower() -creplace '[^a-z0-9]+', '') -eq $sid.ToLower()) { return $l } }
    return $null
}

# Split screen: the window rectangles ("x,y,w,h", outer size in screen pixels) for n games on the work area of the main screen (without the task bar):
# up to 4 in 2 x 2, up to 6 in 3 x 2, up to 8 in 4 x 2 cells, row by row from the top left (the host is the first)
function Get-SplitRects([int]$n) {
    Add-Type @'
using System.Runtime.InteropServices;
public class SplitDpi { [DllImport("user32.dll")] public static extern bool SetProcessDPIAware(); }
'@
    [void][SplitDpi]::SetProcessDPIAware()   # real pixels, not the scaled ones of a 150 % screen
    Add-Type -AssemblyName System.Windows.Forms
    $a = [Windows.Forms.Screen]::PrimaryScreen.WorkingArea
    $cols = if ($n -le 4) { 2 } elseif ($n -le 6) { 3 } else { 4 }
    $w = [int][Math]::Floor($a.Width / $cols); $h = [int][Math]::Floor($a.Height / 2)
    $res = @()
    for ($i = 0; $i -lt $n; $i++) { $res += ('{0},{1},{2},{3}' -f ($a.X + ($i % $cols) * $w), ($a.Y + [Math]::Floor($i / $cols) * $h), $w, $h) }
    return $res
}

# Split screen: asks for the number of players (2 to $max, typed digits); Enter without digits = $max, Esc = $null (back)
function Read-PlayerCount([int]$max, [int]$teams) {
    $buf = ''
    Write-Host "Split screen: the scenario has $teams teams."
    while ($true) {
        Write-Host ("`rHow many players (2 to $max, Enter = $max, Esc = back): $buf ") -NoNewline
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Escape') { Write-Host ''; return $null }
        if ($k.Key -eq 'Enter') {
            if ($buf -eq '') { Write-Host ''; return $max }
            $n = [int]$buf
            if ($n -ge 2) { Write-Host ''; return [Math]::Min($n, $max) }
            $buf = ''   # 0 or 1 players: start again
        } elseif ($k.Key -eq 'Backspace') {
            if ($buf.Length -gt 0) { $buf = $buf.Substring(0, $buf.Length - 1) }
        } elseif ($k.KeyChar -match '^\d$' -and $buf.Length -lt 2) {
            $buf += [string]$k.KeyChar
        }
    }
}

# Split screen: the names of the local players in the lobby, by the cell of their window (TopLeft, TopRight, BottomLeft, ...; with 3 or 4 columns
# Top1, Top2, ...)
function Get-SplitNames([int]$n) {
    $cols = if ($n -le 4) { 2 } elseif ($n -le 6) { 3 } else { 4 }
    $res = @()
    for ($i = 0; $i -lt $n; $i++) {
        $row = if ([Math]::Floor($i / $cols) -eq 0) { 'Top' } else { 'Bottom' }
        $col = $i % $cols
        $res += $row + $(if ($cols -eq 2) { @('Left', 'Right')[$col] } else { [string]($col + 1) })
    }
    return $res
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

# ---------------------------------------------------------------- filters of the map list (data: mapDetails.lua of the lobby package, see map_preview.ps1)
# A map without data is hidden as soon as a filter is set
function New-MapFilter([string]$name, [string[]]$values, [scriptblock]$test) { return @{ Name = $name; Values = (@('all') + $values); Test = $test } }
$mapFilters = @(
    (New-MapFilter 'Size' @('XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL') { param($m, $v) $d = Get-MapDetail $m.Spring; [bool]($d -and $d.Size -eq $v) }),
    (New-MapFilter 'Players' @('2', '3-4', '5-6', '7-8', '9-12', '13-15', '16', '17+') {
        param($m, $v)
        $d = Get-MapDetail $m.Spring
        if (-not $d -or $d.Players -lt 1) { return $false }
        if ($v.EndsWith('+')) { return $d.Players -ge [int]$v.TrimEnd('+') }
        $p = $v.Split('-')
        return ($d.Players -ge [int]$p[0] -and $d.Players -le [int]$p[$p.Count - 1])
    }),
    (New-MapFilter 'Terrain' @('Flat', 'Hills', 'Water', 'Metal', 'Lava', 'Air', 'Asymmetrical') { param($m, $v) $d = Get-MapDetail $m.Spring; [bool]($d -and ($d.Terrain -contains $v)) })
)

# ---------------------------------------------------------------- selection with search while typing
# Returns the chosen element, $null on Esc
# $previewFn (optional): script block that returns the map name (Spring name) of an item; its picture and a line with its size, players and
#   terrain are drawn right of the list
# $filters (optional): array of @{ Name; Values (first = 'all'); Test = { param($item, $value) ... } }; shown in a row above the search line,
#   Tab / Shift+Tab choose a filter, Left/Right change its value
function Show-Chooser($items, [string]$title, [string]$hint, $firstFn, $previewFn = $null, $filters = $null) {
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
    $filters = @($filters)
    $fo = if ($filters.Count -gt 0 -and $filters[0]) { 1 } else { 0 }   # 1 = a row of filters above the search line
    if ($fo -eq 0) { $filters = @() }
    $fv = New-Object 'int[]' $filters.Count   # chosen value per filter (0 = all)
    $fFocus = -1                              # filter that Left/Right change; -1 = none
    $fKey = $null
    $fg0 = [Console]::ForegroundColor; $bg0 = [Console]::BackgroundColor
    while ($true) {
        $rq = $query + '|' + ($fv -join ',')
        if ($resQuery -ne $rq -or $null -eq $res) {
            $res = Get-Filtered $items $query $firstFn
            for ($j = 0; $j -lt $filters.Count; $j++) {
                if ($fv[$j] -gt 0) { $fj = $filters[$j]; $fval = $fj.Values[$fv[$j]]; $res = @($res | Where-Object { & $fj.Test $_ $fval }) }
            }
            $resQuery = $rq
            $flags = New-Object 'bool[]' $res.Count
            if ($firstFn) { for ($i = 0; $i -lt $res.Count; $i++) { $flags[$i] = [bool](& $firstFn $res[$i]) } }
        }
        if ($sel -ge $res.Count) { $sel = [Math]::Max(0, $res.Count - 1) }
        $w = [Console]::WindowWidth - 1
        $h = [Console]::WindowHeight
        if ($w -ne $lastW -or $h -ne $lastH) { $prev = @{}; $pvKey = $null; $fKey = $null; $lastW = $w; $lastH = $h; Clear-Host; Write-Host $title -ForegroundColor Cyan; Write-Host $hint -ForegroundColor DarkGray; Write-Host ''; $top = [Console]::CursorTop }
        $rows = [Math]::Max(3, [Math]::Min(20, $h - $top - 4 - $fo))
        # Preview: right of the list if the window is wide enough (the list keeps at least 55 characters)
        $lw = $w; $pvW = 0
        if ($previewFn -and $pvOk) {
            $pvW = [Math]::Min(2 * ($rows + 1 + $fo), 64)
            if ($w - $pvW - 2 -lt 55) { $pvW = $w - 2 - 55 }
            if ($pvW -lt 20) { $pvW = 0 } else { $lw = $w - $pvW - 2 }
        }
        if ($sel -lt $offset) { $offset = $sel }
        if ($sel -ge $offset + $rows) { $offset = $sel - $rows + 1 }
        # Build the lines: index 0 = row of the filters (if there are any, drawn below), then search, counter, lines of the list
        $lines = New-Object 'string[]' ($rows + 2 + $fo)
        $kinds = New-Object 'int[]' ($rows + 2 + $fo)   # 0 normal, 1 gelb, 2 grau, 3 markiert
        $lines[$fo] = ('Search: ' + $query + '_'); $kinds[$fo] = 1
        $lines[$fo + 1] = ("{0} of {1}" -f $res.Count, $items.Count); $kinds[$fo + 1] = 2
        for ($i = 0; $i -lt $rows; $i++) {
            $idx = $offset + $i
            $line = ''
            if ($idx -lt $res.Count) {
                $line = '  ' + $res[$idx].Label
                if ($flags[$idx]) { $line += '  (last)' }
                if ($idx -eq $sel) { $kinds[$i + 2 + $fo] = 3 }
            }
            $lines[$i + 2 + $fo] = $line
        }
        [Console]::CursorVisible = $false
        for ($i = $fo; $i -lt $lines.Count; $i++) {
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
        if ($fo -gt 0) {
            $k3 = ($fv -join ',') + "|$fFocus|$lw"
            if ($k3 -ne $fKey) {
                $fKey = $k3
                [Console]::SetCursorPosition(0, $top)
                $used = 0
                for ($j = 0; $j -lt $filters.Count; $j++) {
                    $seg = ('{0}: < {1} >' -f $filters[$j].Name, $filters[$j].Values[$fv[$j]])
                    if ($used + $seg.Length + 3 -gt $lw) { break }
                    if ($j -eq $fFocus) { [Console]::ForegroundColor = 'Black'; [Console]::BackgroundColor = 'Gray' }
                    elseif ($fv[$j] -gt 0) { [Console]::ForegroundColor = 'Cyan' }
                    else { [Console]::ForegroundColor = 'DarkGray' }
                    [Console]::Write($seg)
                    [Console]::ForegroundColor = $fg0; [Console]::BackgroundColor = $bg0
                    [Console]::Write('   ')
                    $used += $seg.Length + 3
                }
                $tipTxt = 'Tab = filters, Left/Right = change'
                if ($used + $tipTxt.Length -le $lw) { [Console]::ForegroundColor = 'DarkGray'; [Console]::Write($tipTxt); $used += $tipTxt.Length; [Console]::ForegroundColor = $fg0 }
                [Console]::Write(' ' * [Math]::Max(0, $lw - $used))
            }
        }
        if ($pvW -gt 0) {
            $spring = $null
            if ($res.Count -gt 0) { $spring = & $previewFn $res[$sel] }
            $k2 = "$spring|$pvW|$rows"
            if ($k2 -ne $pvKey) {
                $pvKey = $k2
                [void](Show-MapPreview $spring ($lw + 2) $top $pvW ($rows + 1 + $fo))
                $cap = Get-MapInfoText $spring
                if ($cap.Length -gt $pvW) { $cap = $cap.Substring(0, $pvW) }
                [Console]::SetCursorPosition($lw + 2, $top + $rows + 1 + $fo)
                [Console]::ForegroundColor = 'Cyan'; [Console]::Write($cap.PadRight($pvW)); [Console]::ForegroundColor = $fg0
            }
        }
        [Console]::SetCursorPosition(0, [Math]::Min($top + $rows + 2 + $fo, $h - 1))
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
                'Tab'       {
                    if ($filters.Count -gt 0) {
                        if ($k.Modifiers -band [ConsoleModifiers]::Shift) { $fFocus--; if ($fFocus -lt -1) { $fFocus = $filters.Count - 1 } }
                        else { $fFocus++; if ($fFocus -ge $filters.Count) { $fFocus = -1 } }
                    }
                }
                'LeftArrow' { if ($fFocus -ge 0) { $n = $filters[$fFocus].Values.Count; $fv[$fFocus] = ($fv[$fFocus] + $n - 1) % $n; $sel = 0; $offset = 0 } }
                'RightArrow' { if ($fFocus -ge 0) { $n = $filters[$fFocus].Values.Count; $fv[$fFocus] = ($fv[$fFocus] + 1) % $n; $sel = 0; $offset = 0 } }
                'Home'      { $sel = 0 }
                'End'       { $sel = [Math]::Max(0, $res.Count - 1) }
                'Backspace' { if ($query.Length -gt 0) { $query = $query.Substring(0, $query.Length - 1); $sel = 0; $offset = 0 } }
                default {
                    if ($k.KeyChar -ne [char]0 -and -not [char]::IsControl($k.KeyChar)) { $query += $k.KeyChar; $sel = 0; $offset = 0 }
                }
            }
        } while ([Console]::KeyAvailable)
        # Limit the selection after the last key press (the search is recomputed above)
        if ($resQuery -eq $rq -and $sel -ge $res.Count) { $sel = [Math]::Max(0, $res.Count - 1) }
    }
}

# ---------------------------------------------------------------- write the start script
function Write-StartScript([string]$mapSpring, [bool]$forceAll = $false, [string]$ai1 = '') {
    $game = 'Level Editor 1'
    # AI of team 1 (default and unknown names: NullAI, it does nothing); the Lua AIs are named in the team, the others get an [ai] section
    $luaAis = @('SimpleAI', 'SimpleDefenderAI', 'SimpleConstructorAI', 'ScavengersAI', 'RaptorsAI')
    $aiShort = if ($ai1 -in 'BARb', 'CircuitAI', 'CircuitAI easy', 'NullAI') { $ai1 -replace ' easy$', '' } else { 'NullAI' }
    $aiVer = if ($aiShort -eq 'NullAI') { '0.1' } else { 'stable' }
    $aiOpt = if ($ai1 -eq 'CircuitAI easy') { ' [Options] { profile=easy; }' } else { '' }
    $team1Lua = if ($ai1 -in $luaAis) { " LuaAI=$ai1;" } else { '' }
    $ai0 = if ($ai1 -in $luaAis) { '' } else { "[ai0] { shortname=$aiShort; version=$aiVer; team=1; host=0; name=${aiShort}1;$aiOpt }" }
    $fa = if ($forceAll) { ' forceallunits=1;' } else { '' }
    # ten teams, each in its own ally team (Arena needs them; teams 2 to 9 stay empty: the gadget removes their start commanders)
    $allies = (0..9 | ForEach-Object { "`t[allyteam$_] { numallies=0; }" }) -join "`n"
    $teams = (0..9 | ForEach-Object { $side = if ($_ % 2 -eq 0) { 'Armada' } else { 'Cortex' }; $extra = if ($_ -eq 1) { $team1Lua } else { '' }; "`t[team$_] { allyteam=$_; teamleader=0; side=$side; handicap=0;$extra }" }) -join "`n"
    $script = @"
[game]
{
$allies
$teams
	$ai0
	[player0] { name=Player; spectator=0; team=0; }
	[modoptions] { deathmode=neverend; maxunits=32000; leveleditor=1; experimentallegionfaction=1; experimentalextraunits=1; releasecandidates=1;$fa }
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
    [IO.File]::WriteAllText((Join-Path $root 'editor_script_installed.txt'), $script, (New-Object Text.UTF8Encoding($false)))
}

function Set-Autoload([string]$name) {
    New-Item -ItemType Directory -Force $levelsDir | Out-Null
    [IO.File]::WriteAllText($autoloadFile, $name, (New-Object Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------- Clean up (key 8)
# What can be removed: own levels and own built scenarios (they go into a _trash folder next to them, nothing is deleted for good), and what came from
# other players or was made for them (scenarios and maps in the cache %LOCALAPPDATA%\BAR-Scenario, versions of the extra game "Level Editor Scenarios"
# that are not the editor's own one): those are deleted, they are fetched again when needed. The maps of BAR itself (data\maps) are never offered.
function Get-CleanItems {
    $items = @()
    function Add-Item([string]$kind, [string]$label, [string[]]$paths, [bool]$trash, $time) {
        $size = [long]0
        foreach ($p in $paths) { if (Test-Path $p) { $it = Get-Item $p -Force; $size += $(if ($it.PSIsContainer) { Get-DirSize $p } else { $it.Length }) } }
        $script:cleanItems += [pscustomobject]@{ Kind = $kind; Label = $label; Paths = $paths; Trash = $trash; Size = $size; Time = $time; Marked = $false }
    }
    $script:cleanItems = @()
    if (Test-Path $levelsDir) {
        foreach ($f in @(Get-ChildItem $levelsDir -Filter '*.lua' -File | Where-Object { -not $_.Name.StartsWith('_') } | Sort-Object Name)) {
            Add-Item 'Level' $f.BaseName @($f.FullName) $true $f.LastWriteTime
        }
    }
    $scDir = Join-Path $root 'scenario\scenarios'
    if (Test-Path $scDir) {
        foreach ($d in @(Get-ChildItem $scDir -Directory | Where-Object { -not $_.Name.StartsWith('_') } | Sort-Object Name)) {
            Add-Item 'Scenario' $d.Name @($d.FullName, (Join-Path $scDir ($d.Name + '.zip'))) $true $d.LastWriteTime
        }
    }
    $cacheRoot = Get-BundleCacheRoot
    foreach ($d in @(Get-ChildItem $cacheRoot -Directory -ErrorAction SilentlyContinue | Where-Object { Test-BundleId $_.Name } | Sort-Object LastWriteTime -Descending)) {
        $txt = Join-Path $d.FullName 'scenario.txt'
        $map = if (Test-Path $txt) { [regex]::Match([IO.File]::ReadAllText($txt), '(?m)^\s*mapname\s*=\s*(.+?);').Groups[1].Value.Trim() } else { '?' }
        Add-Item 'From a host' ('scenario on {0} ({1})' -f $map, $d.Name.Substring(0, 8)) @($d.FullName) $false $d.LastWriteTime
    }
    foreach ($m in @(Get-ChildItem (Join-Path (Get-MapExtraRoot) 'maps') -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.sd7' -or $_.Extension -eq '.sdz' } | Sort-Object Name)) {
        Add-Item 'From a host' ('map ' + $m.Name) @($m.FullName, ($m.FullName + '.mapinfo')) $false $m.LastWriteTime
    }
    $ptr = Join-Path $Data 'games\LevelEditorScenarios.txt'
    $own = if (Test-Path $ptr) { @(Get-Content $ptr)[0] } else { '' }
    foreach ($g in @(Get-ChildItem (Join-Path $Data 'games') -Filter 'LevelEditorScenarios_*.sdz' -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $own })) {
        Add-Item 'Other version' ('extra game ' + $g.Name + ' (from a host or an older editor)') @($g.FullName) $false $g.LastWriteTime
    }
    return $script:cleanItems
}

# Removes one item: own files into the _trash folder next to them (with the time in the name when the name is taken), the rest is deleted
function Remove-CleanItem($item) {
    foreach ($p in $item.Paths) {
        if (-not (Test-Path $p)) { continue }
        if ($item.Trash) {
            $trash = Join-Path (Split-Path $p -Parent) '_trash'
            New-Item -ItemType Directory -Force $trash | Out-Null
            $dest = Join-Path $trash (Split-Path $p -Leaf)
            if (Test-Path $dest) { $dest = Join-Path $trash ((Get-Date -Format 'yyyyMMdd_HHmmss') + '_' + (Split-Path $p -Leaf)) }
            Move-Item $p $dest -Force
        } else {
            Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

# The list of key 8: arrow keys move, Space marks, A marks all of the kind under the cursor, Enter removes the marked ones (or the one under the cursor)
# after a question, Esc goes back
function Invoke-CleanMenu {
    $items = @(Get-CleanItems)
    $cur = 0; $msg = ''
    while ($true) {
        Clear-Host
        Write-Host 'Clean up' -ForegroundColor Cyan
        Write-Host 'Own levels and scenarios go into a _trash folder next to them; what came from other players is deleted (it is fetched again when needed).' -ForegroundColor DarkGray
        Write-Host 'Up/Down move, Space marks, A marks all of this kind, Enter removes the marked ones (or the one under the cursor), Esc back' -ForegroundColor DarkGray
        Write-Host ''
        if ($items.Count -eq 0) { Write-Host 'Nothing to clean up.'; Write-Host ''; Write-Host 'Continue with any key.'; [void][Console]::ReadKey($true); return }
        $h = [Math]::Max(5, [Console]::WindowHeight - 9)
        $top = [Math]::Max(0, [Math]::Min($cur - [int]($h / 2), $items.Count - $h))
        for ($i = $top; $i -lt [Math]::Min($items.Count, $top + $h); $i++) {
            $it = $items[$i]
            $line = '{0} [{1}] {2,-14} {3}   {4} MB   {5}' -f $(if ($i -eq $cur) { '>' } else { ' ' }), $(if ($it.Marked) { 'x' } else { ' ' }), $it.Kind, $it.Label, [Math]::Round($it.Size / 1MB, 1), $it.Time.ToString('yyyy-MM-dd')
            $w = [Console]::WindowWidth - 1
            if ($line.Length -gt $w) { $line = $line.Substring(0, $w) }
            if ($i -eq $cur) { Write-Host $line -ForegroundColor Black -BackgroundColor Gray } else { Write-Host $line }
        }
        Write-Host ''
        $marked = @($items | Where-Object { $_.Marked })
        Write-Host ('{0} of {1} marked, {2} MB' -f $marked.Count, $items.Count, [Math]::Round((($marked | Measure-Object -Property Size -Sum).Sum) / 1MB, 1)) -ForegroundColor DarkGray
        if ($msg) { Write-Host $msg -ForegroundColor Green; $msg = '' }
        $k = [Console]::ReadKey($true)
        switch ($k.Key) {
            'UpArrow'   { if ($cur -gt 0) { $cur-- } }
            'DownArrow' { if ($cur -lt $items.Count - 1) { $cur++ } }
            'PageUp'    { $cur = [Math]::Max(0, $cur - $h) }
            'PageDown'  { $cur = [Math]::Min($items.Count - 1, $cur + $h) }
            'Spacebar'  { $items[$cur].Marked = -not $items[$cur].Marked; if ($cur -lt $items.Count - 1) { $cur++ } }
            'A'         { $kind = $items[$cur].Kind; $all = @($items | Where-Object { $_.Kind -eq $kind -and -not $_.Marked }).Count -gt 0; foreach ($it in $items) { if ($it.Kind -eq $kind) { $it.Marked = $all } } }
            'Escape'    { return }
            'Enter' {
                $todo = @($items | Where-Object { $_.Marked })
                if ($todo.Count -eq 0) { $todo = @($items[$cur]) }
                Write-Host ''
                Write-Host ('Remove {0} item(s)? Own levels and scenarios go into _trash, the rest is deleted. (y/n)' -f $todo.Count) -ForegroundColor Yellow
                $a = [Console]::ReadKey($true)
                if ($a.KeyChar -eq 'y' -or $a.KeyChar -eq 'j') {
                    foreach ($it in $todo) { Remove-CleanItem $it }
                    $msg = '{0} item(s) removed.' -f $todo.Count
                    $items = @(Get-CleanItems)
                    $cur = [Math]::Min($cur, [Math]::Max(0, $items.Count - 1))
                }
            }
        }
    }
}

# ---------------------------------------------------------------- main menu
while ($true) {
    $global:LASTEXITCODE = 0
    $levels = @(Get-Levels)
    $lastLevel = Get-LastLevel
    # The menu always appears: 0 = continue the last state, 1 = new level, 2 = load a saved level, 3 = scenario package, 4 = start a scenario, 5 = upgrade one,
    # 6 = play a level at once
    # (the last two only if there are levels already). Choose with arrow up/down and Enter or with the digit key.
    $haveLevels = $levels.Count -gt 0
    $scenarios = @(Get-Scenarios)
    $cacheInfo = Get-CacheInfo
    $menu = @(
        @{ Key = '0'; Mode = 3; On = [bool]$lastLevel; Text = $(if ($lastLevel) { 'Continue last saved map: {0}' -f $lastLevel.Label } else { 'Continue last saved map (nothing saved yet)' }) },
        @{ Key = '1'; Mode = 1; On = $true; Text = 'Create a new level (choose a map)' },
        @{ Key = '2'; Mode = 2; On = $haveLevels; Text = $(if ($haveLevels) { 'Load an existing level ({0} saved)' -f $levels.Count } else { 'Load an existing level (no saved levels yet)' }) },
        @{ Key = '3'; Mode = 4; On = $haveLevels; Text = $(if ($haveLevels) { 'Create a scenario package (ZIP) from a level (to pass on, official game)' } else { 'Create a scenario package (ZIP) from a level (no saved levels yet)' }) },
        @{ Key = '4'; Mode = 5; On = ($scenarios.Count -gt 0); Text = $(if ($scenarios.Count -gt 0) { 'Start a scenario ({0} available)' -f $scenarios.Count } else { 'Start a scenario (none available yet: key 3)' }) },
        @{ Key = '5'; Mode = 6; On = ($scenarios.Count -gt 0); Text = $(if ($scenarios.Count -gt 0) { 'Upgrade a scenario package (build it again from its level, {0} available)' -f $scenarios.Count } else { 'Upgrade a scenario package (none available yet: key 3)' }) },
        @{ Key = '6'; Mode = 7; On = $true; Text = 'Play a level at once (single player, host, join or split screen; the others get it from the host)' },
        @{ Key = '7'; Mode = 9; On = $true; Text = $(if (Get-ScavSetting) { 'Scavenger and Raptor units in the Place menu: ON, loading takes about 10 seconds longer (Enter = switch off)' } else { 'Scavenger and Raptor units in the Place menu: off, when ON loading takes about 10 seconds longer (Enter = switch on)' }) }
        @{ Key = '8'; Mode = 8; On = $true; Text = ('Clean up: own levels and scenarios (into _trash), scenarios and maps from other players ({0} MB in %LOCALAPPDATA%\BAR-Scenario)' -f [Math]::Round($cacheInfo.Bytes / 1MB)) }
    )
    $sel = 0
    while (-not $menu[$sel].On) { $sel++ }
    Clear-Host
    Write-Host 'Level Editor' -ForegroundColor Cyan -NoNewline
    Write-Host ('   lobby version {0} (the same on every computer that plays together over the network)' -f $script:LobbyProtocol) -ForegroundColor DarkGray
    Write-Host ''
    $menuTop = [Console]::CursorTop
    Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''; Write-Host ''
    Write-Host ''
    Write-Host 'Arrow up/down + Enter or digit key, Esc = cancel' -ForegroundColor DarkGray
    $mode = 0
    $fg0 = [Console]::ForegroundColor; $bg0 = [Console]::BackgroundColor
    while ($mode -eq 0) {
        $w = [Console]::WindowWidth - 1
        for ($i = 0; $i -lt $menu.Count; $i++) {
            $line = ('  {0}  {1}' -f $menu[$i].Key, $menu[$i].Text)
            if ($line.Length -gt $w) { $line = $line.Substring(0, $w) }
            [Console]::SetCursorPosition(0, $menuTop + $i + $(if ($i -ge 7) { 2 } elseif ($i -ge 3) { 1 } else { 0 }))   # an empty line between the levels (0 to 2) and the scenarios (3 to 6), and before the settings (7, 8)
            if ($i -eq $sel) { [Console]::ForegroundColor = 'Black'; [Console]::BackgroundColor = 'Gray' }
            elseif (-not $menu[$i].On) { [Console]::ForegroundColor = 'DarkGray' }
            elseif ($menu[$i].Key -eq '0') { [Console]::ForegroundColor = 'Green' }
            [Console]::Write($line.PadRight($w))
            [Console]::ForegroundColor = $fg0; [Console]::BackgroundColor = $bg0
        }
        [Console]::SetCursorPosition(0, $menuTop + $menu.Count + 3)
        $k = [Console]::ReadKey($true)
        if ($k.Key -eq 'Escape') { Clear-Host; Write-Host 'Cancelled.'; exit 2 }   # 2 = cancelled (the start file ends quietly), 1 = error
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
        # then how to play it: alone, host a game for the same network or join one (the options of start_scenario.ps1, like Host Game.bat / Join Game.bat)
        $playModes = @(
            [pscustomobject]@{ Label = 'Single player'; Search = 'single player alone'; Args = @() },
            [pscustomobject]@{ Label = 'Host a game for others in the same network'; Search = 'host'; Args = @('-HostGame', '-Lobby') },
            [pscustomobject]@{ Label = 'Join a game hosted by another player'; Search = 'join'; Args = @('-Join', '-Lobby') },
            [pscustomobject]@{ Label = 'Split screen (host and joiners on this computer, one window each)'; Search = 'split screen local test'; Args = @(); Split = $true }
        )
        $players = 0
        $chosen = $null; $how = $null
        $starter = Join-Path $root 'scenario\template\start_scenario.ps1'   # always the current starter, lobby and gadgets of the editor, not the copies in the package
        while ($true) {
            $chosen = Show-Chooser $scenarios 'Start a scenario: choose one' 'Type to search, arrow up/down, Enter = next, Esc = back' $null
            if (-not $chosen) { break }
            $how = Show-Chooser $playModes ('Scenario ' + $chosen.Name + ': how do you want to play?') 'Arrow up/down, Enter = start, Esc = back to the scenarios' $null
            if (-not $how) { continue }
            if ($how.Split) {
                # Split screen: the number of players (at most 8, and not more than the scenario has teams)
                $teams = ([regex]::Matches([IO.File]::ReadAllText((Join-Path $chosen.Path 'scenario.txt')), '(?m)^\s*\[team\d+\]')).Count
                $maxP = [Math]::Min(8, $teams)
                Clear-Host
                if ($maxP -lt 2) { Write-Host 'This scenario has only one team, there is nobody to play against.' -ForegroundColor Yellow; Start-Sleep 2; continue }
                $players = Read-PlayerCount $maxP $teams
                if (-not $players) { $players = 0; continue }
            }
            break
        }
        if (-not $chosen) { continue }
        Clear-Host
        Write-Host ('Starting the scenario ' + $chosen.Name + ' (' + $how.Label + ') ...') -ForegroundColor Cyan
        if ($how.Split) {
            # The host first (top left), the joiners wait in minimized windows until the host listens (127.0.0.1: nothing leaves this computer)
            $rects = Get-SplitRects $players
            $names = Get-SplitNames $players
            $barDir = Split-Path $Data -Parent
            $common = @('-BarPath', $barDir, '-ScenarioDir', $chosen.Path, '-EditorDir', $root)
            for ($k = 1; $k -lt $players; $k++) {
                [void](Start-Process powershell -WindowStyle Minimized -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $starter + '"')) + @($common | ForEach-Object { '"' + $_ + '"' }) +
                    @('-Join', '-JoinIp', '127.0.0.1', '-Lobby', '-Name', $names[$k], '-NoBuild', '-WaitForHost', '-WindowRect', $rects[$k])))
            }
            & powershell -NoProfile -ExecutionPolicy Bypass -File $starter @common -HostGame -Lobby -Name $names[0] -HostIp 127.0.0.1 -WindowRect $rects[0]
            continue # the games ended: back to the menu
        }
        & powershell -NoProfile -ExecutionPolicy Bypass -File $starter -BarPath (Split-Path $Data -Parent) -ScenarioDir $chosen.Path -EditorDir $root $how.Args
        continue # the game ended (or could not start): back to the menu, the next one can be tried at once
    }

    if ($mode -eq 9) {
        # the switch for the Scavenger and Raptor units: remembered for the next starts
        New-Item -ItemType Directory -Force $userDir | Out-Null
        [IO.File]::WriteAllText($scavFile, $(if (Get-ScavSetting) { '0' } else { '1' }))
        continue
    }

    if ($mode -eq 8) {
        # Clean up: a list of own levels and scenarios (into _trash) and of what other players gave (deleted); nothing of the game itself
        Invoke-CleanMenu
        continue
    }

    if ($mode -eq 7) {
        # Play a level at once: the scenario is built from the level into a temporary bundle (scenario.txt and the gadgets, nothing is written into the level
        # and no package is made), put into the cache (Cache\<hash>) and played from there. The host offers it in the lobby, the others get it from him
        # (or from their cache) and only need the same version of the editor.
        $playModes = @(
            [pscustomobject]@{ Label = 'Single player'; Search = 'single player alone'; Args = @(); Level = $true },
            [pscustomobject]@{ Label = 'Host a game for others in the same network'; Search = 'host'; Args = @('-HostGame', '-Lobby'); Level = $true },
            [pscustomobject]@{ Label = 'Join a game hosted by another player (the level comes from the host)'; Search = 'join'; Args = @('-Join', '-Lobby'); Level = $false },
            [pscustomobject]@{ Label = 'Split screen (host and joiners on this computer, one window each)'; Search = 'split screen local test'; Args = @(); Split = $true; Level = $true }
        )
        $starter = Join-Path $root 'scenario\template\start_scenario.ps1'
        $barDir = Split-Path $Data -Parent
        $players = 0; $how = $null; $inst = $null; $lvl = $null
        while ($true) {
            $how = Show-Chooser $playModes 'Play a level at once: how do you want to play?' 'Arrow up/down, Enter = next, Esc = back' $null
            if (-not $how) { break }
            if (-not $how.Level) { break }
            $lvl = Show-Chooser $levels 'Play a level: choose a level' 'Type to search, arrow up/down, Enter = play, Esc = back' $null { param($l) $l.Map }
            if (-not $lvl) { continue }
            if (-not $lvl.Installed) {
                Clear-Host
                $loaded = $false
                if ($lvl.Loadable) { $loaded = Download-Map $lvl.MapItem $MapsDir }
                else { Write-Host ('The map ' + $lvl.Map + ' of this level is not installed and not in the map list.') -ForegroundColor Yellow }
                if (-not $loaded) { Write-Host 'Continue with any key.'; [void][Console]::ReadKey($true); continue }
            }
            Clear-Host
            Write-Host ('Playing the level ' + $lvl.Name + ': ' + $how.Label) -ForegroundColor Cyan
            $tmp = Join-Path $env:TEMP ('bar_bundle_' + [Guid]::NewGuid().ToString('N'))
            & (Join-Path $root 'scenario\scenario_builder.ps1') -Level $lvl.Name -BundleDir $tmp
            if (-not (Test-Path (Join-Path $tmp 'scenario.txt'))) {
                Write-Host 'The level could not be turned into a scenario (see above).' -ForegroundColor Yellow
                Write-Host 'Continue with any key.'; [void][Console]::ReadKey($true); continue
            }
            $inst = Install-Bundle $tmp
            Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
            if ($how.Split) {
                $teams = ([regex]::Matches([IO.File]::ReadAllText((Join-Path $inst.Dir 'scenario.txt')), '(?m)^\s*\[team\d+\]')).Count
                $maxP = [Math]::Min(8, $teams)
                Clear-Host
                if ($maxP -lt 2) { Write-Host 'This level has only one team, there is nobody to play against.' -ForegroundColor Yellow; Start-Sleep 2; continue }
                $players = Read-PlayerCount $maxP $teams
                if (-not $players) { $players = 0; continue }
            }
            break
        }
        if (-not $how -or ($how.Level -and -not $inst)) { continue }
        Clear-Host
        Write-Host ('Starting (' + $how.Label + ') ...') -ForegroundColor Cyan
        $common = @('-BarPath', $barDir, '-EditorDir', $root, '-Bundle')
        if ($how.Split) {
            $rects = Get-SplitRects $players
            $names = Get-SplitNames $players
            for ($k = 1; $k -lt $players; $k++) {
                [void](Start-Process powershell -WindowStyle Minimized -ArgumentList (@('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', ('"' + $starter + '"')) + @($common | ForEach-Object { '"' + $_ + '"' }) +
                    @('-Join', '-JoinIp', '127.0.0.1', '-Lobby', '-Name', $names[$k], '-NoBuild', '-WaitForHost', '-WindowRect', $rects[$k])))
            }
            & powershell -NoProfile -ExecutionPolicy Bypass -File $starter @common -ScenarioDir $inst.Dir -HostGame -Lobby -Name $names[0] -HostIp 127.0.0.1 -WindowRect $rects[0]
            continue
        }
        if ($how.Level) { & powershell -NoProfile -ExecutionPolicy Bypass -File $starter @common -ScenarioDir $inst.Dir $how.Args }
        else { & powershell -NoProfile -ExecutionPolicy Bypass -File $starter @common $how.Args }
        continue # the game ended (or could not start): back to the menu
    }

    if ($mode -eq 6) {
        # Upgrade a scenario package: it is built again from the level it came from, with the info saved in that level (key 3 without any question and
        # without choosing a level): the package gets the current starter, lobby and gadgets of the editor and the current units of the level
        $chosen = Show-Chooser $scenarios 'Upgrade a scenario package: choose one (it is built again from its level)' 'Type to search, arrow up/down, Enter = upgrade, Esc = back' $null
        if (-not $chosen) { continue }
        Clear-Host
        $lvl = Find-ScenarioLevel $chosen.Name
        if (-not $lvl) {
            Write-Host ("No level found for the scenario '" + $chosen.Name + "' (its ID is not in the saved scenario info of any level, and no level has that name).") -ForegroundColor Yellow
            Write-Host 'Build it again with key 3 from the level it was made from.'
        } else {
            Write-Host ("Upgrading the scenario '" + $chosen.Name + "' from the level '" + $lvl.Name + "' ...") -ForegroundColor Cyan
            $maker = Join-Path $root 'scenario\scenario_builder.ps1'
            & $maker -Level $lvl.Name -Auto
        }
        Write-Host ''
        Write-Host 'Continue with any key.'
        [void][Console]::ReadKey($true)
        continue
    }

    if ($mode -eq 4) {
        # The scenario info is stored in the level (edited in the editor with button I); only the package is built here.
        $chosen = Show-Chooser $levels 'Create a scenario package: choose a level' 'Type to search, arrow up/down, Enter = build, Esc = back' $null { param($l) $l.Map }
        if (-not $chosen) { continue }
        Clear-Host
        $maker = Join-Path $root 'scenario\scenario_builder.ps1'
        & $maker -Level $chosen.Name -Auto -AskName
        Write-Host ''
        Write-Host 'Continue with any key.'
        [void][Console]::ReadKey($true)
        continue
    }

    if ($mode -eq 1) {
        $lastMap = $last
        $chosen = Show-Chooser $maps ('New level: choose a map   (' + $maps.Count + ' maps, ' + @($maps | Where-Object { $_.Installed }).Count + ' installed)') 'Type to search, Tab = filters, arrow up/down, Enter = start (missing maps are only downloaded then), Esc = back' { param($m) $m.Spring -eq $lastMap } { param($m) $m.Spring } $mapFilters
        if (-not $chosen) { continue }
        if (-not $chosen.Installed) {
            Clear-Host
            if (-not (Download-Map $chosen $MapsDir)) {
                Write-Host 'Continue with any key.'
                [void][Console]::ReadKey($true)
                continue
            }
        }
        New-Item -ItemType Directory -Force $userDir | Out-Null
        Set-Content -Path $lastFile -Value $chosen.Spring -Encoding ASCII
        Write-StartScript $chosen.Spring (Get-ScavSetting)
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
    Write-StartScript $chosen.Map ((Get-ScavSetting) -or $chosen.ForceAll) $chosen.Ai1
    Set-Autoload $chosen.Name
    Clear-Host
    Write-Host ("Starting level '{0}' on {1} ({2} units are being loaded)" -f $chosen.Name, ($chosen.Map -replace '_', ' '), $chosen.Count) -ForegroundColor Green
    exit 0
}
