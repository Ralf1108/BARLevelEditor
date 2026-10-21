# Builds a scenario for the official Beyond All Reason (without a mod) from a level of the Level Editor.
#
# Result in scenarios\<id>\ and scenarios\<id>.zip:
#   Start Scenario.bat   - double-click start for the recipient
#   start_scenario.ps1     - finds BAR, determines the game version, downloads the map, starts the game
#   scenario_briefing.lua  - user widget with the briefing window
#   scenario.txt           - start script (teams, AIs, game options, scenariooptions with units and features)
#   README.txt             - briefing and instructions
# The start script uses the scenario mechanism of the official game (scenariooptions.unitloadout and
# featureloadout), the game itself stays unchanged. Only PowerShell is needed, no Python.
#
# Call: start menu of the Level Editor, key 3 (build the package)
#   (or: powershell -File scenario_builder.ps1 [-Level name] [-Auto] [-Edit])
#   -Level name   choose a level from ..\levels without asking
#   -Auto         no questions, take the saved info or the defaults (tests)
#   -Edit         change the saved info in the level
#   -AskName      (start menu) show the target name (the ID) and ask whether to take it, change it or - if the scenario exists - overwrite it
param([string]$Level = $null, [switch]$Auto, [switch]$Edit, [switch]$AskName)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
# Set only the output to UTF-8: if the input is switched too, the console returns the character NUL for umlauts
try { [Console]::OutputEncoding = [Text.Encoding]::UTF8 } catch {}

$HERE = $PSScriptRoot
$LEVELS = Join-Path (Split-Path $HERE -Parent) 'levels'
$TEMPLATE = Join-Path $HERE 'template'
$OUT = Join-Path $HERE 'scenarios'
$utf8 = New-Object Text.UTF8Encoding($false)
# Block in the level file: scenario = [==[ json ]==],  (the Level Editor copies it back unchanged when saving)
$BLOCK_RX = [regex]::new("\n\tscenario = \[==\[(.*?)\]==\],[ \t\r]*(?=\n)", 'Singleline')
$UNIT_RX = [regex]::new("\{\s*name\s*=\s*'([^']+)'\s*,\s*x\s*=\s*(-?\d+)\s*,\s*y\s*=\s*(-?\d+)\s*,\s*z\s*=\s*(-?\d+)\s*,\s*rot\s*=\s*(-?\d+)\s*(?:,\s*team\s*=\s*(\d+))?\s*(?:,\s*neutral\s*=\s*(true|false))?\s*(?:,\s*gaia\s*=\s*(true))?\s*(?:,\s*indestructible\s*=\s*(true))?\s*\}")
$FEATURE_RX = [regex]::new("\{\s*name\s*=\s*'([^']+)'\s*,\s*x\s*=\s*(-?\d+)\s*,\s*y\s*=\s*(-?\d+)\s*,\s*z\s*=\s*(-?\d+)\s*,\s*rot\s*=\s*(-?\d+)\s*(?:,\s*resurrectas\s*=\s*'([^']+)')?\s*\}")
$COLORS = @('0 0.51 0.78', '0.9 0.1 0.29', '0.96 0.51 0.19', '1 0.88 0.1', '0.27 0.6 0.31', '0.57 0.12 0.71', '0.27 0.94 0.94', '0.94 0.2 0.9')
$SIDES = @{ arm = 'Armada'; cor = 'Cortex'; leg = 'Legion' }
$ROLE_TXT = @{ s = 'Player'; v = 'Allied AI'; e = 'Enemy (AI)' }
$WIN_TXT = @{ com = 'Commanders'; killall = 'All units'; neverend = 'No end' }

# Version of the "scenario" block. Raise it when the structure changes and convert the old form in Update-Block.
#   0 = block without "version" (first version, same fields as 1)
#   1 = fields: version, title, author, summary, briefing, roles, ai, win, metal, energy, sid
#   2 = adds: grace (grace period in minutes, 0 = none)
$SCENARIO_VERSION = 2
$KNOWN_FIELDS = @('version', 'title', 'author', 'summary', 'briefing', 'roles', 'ai', 'win', 'metal', 'energy', 'sid', 'grace', 'tiers')

# ---------------------------------------------------------------- Questions
function Ask([string]$prompt, $default = '') {
    if ($Auto) { return [string]$default }
    $suffix = if ("$default" -ne '') { " [$default]" } else { '' }
    Write-Host "${prompt}${suffix}: " -NoNewline
    $v = [Console]::ReadLine()
    if ($null -eq $v) { throw 'Input ended, aborted.' }
    $v = $v.Trim()
    if ($v) { return $v } else { return [string]$default }
}

# Like Ask, but also asks in the automatic mode (the start menu asks for the title and the name)
function AskLine([string]$prompt, $default = '') {
    $suffix = if ("$default" -ne '') { " [$default]" } else { '' }
    Write-Host "${prompt}${suffix}: " -NoNewline
    $v = [Console]::ReadLine()
    if ($null -eq $v) { throw 'Input ended, aborted.' }
    $v = $v.Trim()
    if ($v) { return $v } else { return [string]$default }
}

function AskChoice([string]$prompt, $options, [string]$default) {
    if (-not $Auto) { # in the automatic mode the saved answer is taken without showing the choices
        Write-Host $prompt
        foreach ($o in $options) { Write-Host ('   {0} = {1}' -f $o[0], $o[1]) }
    }
    $keys = @($options | ForEach-Object { $_[0] })
    while ($true) {
        $v = (Ask 'Choice' $default).ToLower()
        if ($keys -contains $v) { return $v }
        Write-Host '   Please enter one of the options.'
    }
}

function AskInt([string]$prompt, $default, [int]$lo, [int]$hi) {
    while ($true) {
        $v = Ask $prompt $default
        $n = 0
        if ([int]::TryParse($v, [ref]$n) -and $n -ge $lo -and $n -le $hi) { return $n }
        Write-Host "   Please enter a whole number from $lo to $hi."
    }
}

function ConvertTo-Tiers($v) {
    $s = ''
    foreach ($k in '1', '2', '3') { if ("$v".Contains($k)) { $s += $k } }
    return $s
}

# allowed tech tiers of a team, e.g. "123" (all), "12", "1"; empty = nothing
function AskTiers([string]$prompt, $default = '123') {
    while ($true) {
        $v = Ask "$prompt (digits of the allowed tiers, e.g. 123 = all, 12, 1)" $default
        if ($v -match '^[1-3]*$') { return (ConvertTo-Tiers $v) }
        Write-Host '   Please enter digits from 1, 2, 3.'
    }
}

function AskMultiline([string]$prompt, [string]$default = '') {
    if ($Auto) { return $default }
    Write-Host "$prompt (several lines possible; an empty line ends, Enter alone takes the default)"
    if ($default) { Write-Host "   Default: $default" }
    $lines = @()
    while ($true) {
        Write-Host '> ' -NoNewline
        $l = [Console]::ReadLine()
        if ($null -eq $l -or $l -eq '') { break }
        $lines += $l
    }
    if ($lines.Count -gt 0) { return ($lines -join "`n") } else { return $default }
}

# ---------------------------------------------------------------- Helpers
# Target of the package: shows the name (the ID of the scenario = folder and zip in scenarios\), lets the user change it and, if a scenario
# of that name exists, asks before it is overwritten. Returns the name to use (Get-Slug form).
function Confirm-ScenarioId([string]$sid) {
    while ($true) {
        $exists = (Test-Path (Join-Path $OUT $sid)) -or (Test-Path (Join-Path $OUT ($sid + '.zip')))
        Write-Host ''
        Write-Host "The scenario is built as: scenarios\$sid (folder) and scenarios\$sid.zip" -ForegroundColor Cyan
        if ($exists) { Write-Host 'A scenario of this name already exists.' -ForegroundColor Yellow }
        Write-Host "Name (the ID, lowercase letters and digits) - Enter takes '$sid', or type another name: " -NoNewline
        $v = [Console]::ReadLine()
        if ($null -eq $v) { throw 'Input ended, aborted.' }
        $v = $v.Trim()
        if ($v) { $sid = Get-Slug $v; $exists = (Test-Path (Join-Path $OUT $sid)) -or (Test-Path (Join-Path $OUT ($sid + '.zip'))) }
        if (-not $exists) { return $sid }
        Write-Host "'$sid' exists. Overwrite it? (y = overwrite, n = choose another name, c = cancel): " -NoNewline
        $a = ([Console]::ReadLine()).Trim().ToLower()
        if ($a.StartsWith('y') -or $a.StartsWith('j')) { return $sid }
        if ($a.StartsWith('c')) { throw 'Cancelled, nothing was built.' }
    }
}

# Grace period: minutes as a number; input "2:30" (minutes:seconds), "2,5" or "2.5" or "3"; output "m:ss"
function ConvertTo-Minutes([string]$text) {
    $t = $text.Trim().Replace(',', '.')
    $m = [regex]::Match($t, '^(\d+):([0-5]?\d)$')
    if ($m.Success) { return [double]$m.Groups[1].Value + [double]$m.Groups[2].Value / 60.0 }
    $d = 0.0
    if ([double]::TryParse($t, [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$d) -and $d -ge 0 -and $d -le 120) { return $d }
    return $null
}

function Format-Minutes($n) {
    $n = [double]$n
    if ($n -le 0) { return '0' }
    $total = [int][math]::Round($n * 60)
    return ('{0}:{1:00}' -f [math]::Floor($total / 60), ($total % 60))
}

function AskMinutes([string]$prompt, $default) {
    while ($true) {
        $v = Ask $prompt (Format-Minutes $default)
        $n = ConvertTo-Minutes $v
        if ($null -ne $n) { return [math]::Round($n * 60) / 60.0 }
        Write-Host '   Please enter minutes:seconds (e.g. 2:30) or minutes (e.g. 2.5), 0 to 120.'
    }
}

function Get-Slug([string]$text) {
    $s = ($text.ToLower() -creplace '[^a-z0-9]+', '')
    if ($s) { return $s } else { return 'scenario' }
}

function Get-AsciiName([string]$text) {
    $t = $text.Replace([string][char]0xE4, 'ae').Replace([string][char]0xF6, 'oe').Replace([string][char]0xFC, 'ue').Replace([string][char]0xC4, 'Ae').Replace([string][char]0xD6, 'Oe').Replace([string][char]0xDC, 'Ue').Replace([string][char]0xDF, 'ss')
    $t = ($t -creplace '[^A-Za-z0-9 _\-]+', '').Trim()
    if ($t) { return $t } else { return 'Scenario' }
}

function Get-Val($h, [string]$key, $default = $null) {
    if ($h.Contains($key) -and $null -ne $h[$key]) { return $h[$key] }
    return $default
}

# Write JSON: keys in insertion order. $indent >= 0: indented (1 space per level), otherwise compact.
# $ascii: non-ASCII characters as \uXXXX.
function ConvertTo-JsonText($v, [int]$indent = -1, [bool]$ascii = $false, [int]$level = 0) {
    if ($null -eq $v) { return 'null' }
    if ($v -is [bool]) { if ($v) { return 'true' } else { return 'false' } }
    if ($v -is [string]) {
        $sb = New-Object Text.StringBuilder
        [void]$sb.Append('"')
        foreach ($c in $v.ToCharArray()) {
            $code = [int]$c
            if ($c -eq '"') { [void]$sb.Append('\"') }
            elseif ($c -eq '\') { [void]$sb.Append('\\') }
            elseif ($c -eq "`n") { [void]$sb.Append('\n') }
            elseif ($c -eq "`r") { [void]$sb.Append('\r') }
            elseif ($c -eq "`t") { [void]$sb.Append('\t') }
            elseif ($code -lt 32 -or ($ascii -and $code -gt 126)) { [void]$sb.Append('\u{0:x4}' -f $code) }
            else { [void]$sb.Append($c) }
        }
        [void]$sb.Append('"')
        return $sb.ToString()
    }
    if ($v -is [System.Collections.IDictionary]) {
        if ($v.Count -eq 0) { return '{}' }
        $parts = @()
        foreach ($k in $v.Keys) {
            $kv = ConvertTo-JsonText $v[$k] $indent $ascii ($level + 1)
            if ($indent -ge 0) { $parts += ((' ' * ($indent * ($level + 1))) + (ConvertTo-JsonText ([string]$k) -1 $ascii) + ': ' + $kv) }
            else { $parts += ((ConvertTo-JsonText ([string]$k) -1 $ascii) + ':' + $kv) }
        }
        if ($indent -ge 0) { return "{`n" + ($parts -join ",`n") + "`n" + (' ' * ($indent * $level)) + '}' }
        return '{' + ($parts -join ',') + '}'
    }
    if ($v -is [System.Collections.IEnumerable]) {
        $items = @($v)
        if ($items.Count -eq 0) { return '[]' }
        $parts = @()
        foreach ($i in $items) {
            $iv = ConvertTo-JsonText $i $indent $ascii ($level + 1)
            if ($indent -ge 0) { $parts += ((' ' * ($indent * ($level + 1))) + $iv) } else { $parts += $iv }
        }
        if ($indent -ge 0) { return "[`n" + ($parts -join ",`n") + "`n" + (' ' * ($indent * $level)) + ']' }
        return '[' + ($parts -join ',') + ']'
    }
    return [string]::Format([Globalization.CultureInfo]::InvariantCulture, '{0}', $v)
}

# PSCustomObject from ConvertFrom-Json -> ordered table (nested)
function ConvertTo-Table($o) {
    if ($o -is [System.Management.Automation.PSCustomObject]) {
        $h = [ordered]@{}
        foreach ($p in $o.PSObject.Properties) { $h[$p.Name] = ConvertTo-Table $p.Value }
        return $h
    }
    if ($o -is [System.Array]) { return , @($o | ForEach-Object { ConvertTo-Table $_ }) }
    return $o
}

# ---------------------------------------------------------------- Tower Defense
# Position of the closing brace that belongs to the opening brace at $open
function Find-CloseBrace([string]$txt, [int]$open) {
    $depth = 0
    for ($i = $open; $i -lt $txt.Length; $i++) {
        $ch = $txt[$i]
        if ($ch -eq '{') { $depth++ } elseif ($ch -eq '}') { $depth--; if ($depth -eq 0) { return $i } }
    }
    return -1
}

# Section "towerdefense" of the level (written by the Level Editor): the settings of the tower defense page.
# $null when the section is missing, Tower Defense is off or spawn point, goal or waves are missing.
function Read-TowerDefense([string]$txt) {
    $m = [regex]::Match($txt, 'towerdefense\s*=\s*\{')
    if (-not $m.Success) { return $null }
    $open = $m.Index + $m.Length - 1
    $close = Find-CloseBrace $txt $open
    if ($close -lt 0) { return $null }
    $body = $txt.Substring($open + 1, $close - $open - 1)
    $en = [regex]::Match($body, '\benabled\s*=\s*(true|false)')
    if (-not ($en.Success -and $en.Groups[1].Value -eq 'true')) { return $null }
    function Flag($key) { $f = [regex]::Match($body, "\b$key\s*=\s*(true|false)"); return (-not $f.Success) -or ($f.Groups[1].Value -eq 'true') }
    function Pair($key) {
        $p = [regex]::Match($body, "\b$key\s*=\s*\{\s*(-?\d+)\s*,\s*(-?\d+)\s*\}")
        if ($p.Success) { return @([int]$p.Groups[1].Value, [int]$p.Groups[2].Value) }
        return $null
    }
    function Block($key) {
        $b = [regex]::Match($body, "\b$key\s*=\s*\{")
        if (-not $b.Success) { return '' }
        $o = $b.Index + $b.Length - 1
        $c = Find-CloseBrace $body $o
        if ($c -lt 0) { return '' }
        return $body.Substring($o + 1, $c - $o - 1)
    }
    $td = @{ spawn = (Pair 'spawn'); goal = (Pair 'goal'); economy = (Flag 'economy'); fog = (Flag 'fog'); leaks = 10; waypoints = @(); banned = @(); bannedTech = @(); waves = @() }
    $lk = [regex]::Match($body, '\bleaks\s*=\s*(\d+)')
    if ($lk.Success) { $td.leaks = [int]$lk.Groups[1].Value }
    foreach ($p in [regex]::Matches((Block 'waypoints'), '\{\s*(-?\d+)\s*,\s*(-?\d+)\s*\}')) { $td.waypoints += ,@([int]$p.Groups[1].Value, [int]$p.Groups[2].Value) }
    foreach ($b in [regex]::Matches((Block 'banned'), '"([^"]+)"')) { $td.banned += $b.Groups[1].Value }
    foreach ($b in [regex]::Matches((Block 'bannedTech'), '\d')) { $td.bannedTech += $b.Value }
    foreach ($wm in [regex]::Matches((Block 'waves'), '\{([^{}]*)\}')) {
        $w = @{ fac = 'arm'; kind = 'vb'; tech = '1'; count = 10; gap = 30; hp = 100 }
        foreach ($kv in [regex]::Matches($wm.Groups[1].Value, '(\w+)\s*=\s*("[^"]*"|-?\d+)')) {
            $v = $kv.Groups[2].Value.Trim('"')
            if ($kv.Groups[1].Value -in 'count', 'gap', 'hp') { $w[$kv.Groups[1].Value] = [int]$v } else { $w[$kv.Groups[1].Value] = $v }
        }
        # older values of the page: kind any / bot / vehicle
        $oldKinds = @{ any = 'vb'; bot = 'b'; vehicle = 'v' }
        if ($oldKinds.ContainsKey([string]$w.kind)) { $w.kind = $oldKinds[[string]$w.kind] }
        $td.waves += ,$w
    }
    if (-not $td.spawn -or -not $td.goal -or $td.waves.Count -eq 0) {
        Write-Host 'Note: Tower Defense is on in the level, but spawn point, goal or waves are missing: the scenario is built without waves.' -ForegroundColor Yellow
        return $null
    }
    return $td
}

# Section "capture" of the level (written by the Level Editor): the settings of the Capture the Flag page.
# $null when the section is missing, Capture the Flag is off or collection points or flag points are missing.
function Read-Capture([string]$txt) {
    $m = [regex]::Match($txt, '\bcapture\s*=\s*\{')
    if (-not $m.Success) { return $null }
    $open = $m.Index + $m.Length - 1
    $close = Find-CloseBrace $txt $open
    if ($close -lt 0) { return $null }
    $body = $txt.Substring($open + 1, $close - $open - 1)
    $en = [regex]::Match($body, '\benabled\s*=\s*(true|false)')
    if (-not ($en.Success -and $en.Groups[1].Value -eq 'true')) { return $null }
    function Num($key, $default) { $n = [regex]::Match($body, "\b$key\s*=\s*(\d+)"); if ($n.Success) { return [int]$n.Groups[1].Value } else { return $default } }
    function Txt($key, $default) { $n = [regex]::Match($body, "\b$key\s*=\s*`"(\w+)`""); if ($n.Success) { return $n.Groups[1].Value } else { return $default } }
    function Points($key) {
        $b = [regex]::Match($body, "\b$key\s*=\s*\{")
        $out = @()
        if (-not $b.Success) { return $out }
        $o = $b.Index + $b.Length - 1
        $c = Find-CloseBrace $body $o
        if ($c -lt 0) { return $out }
        foreach ($pm in [regex]::Matches($body.Substring($o + 1, $c - $o - 1), '\{([^{}]*)\}')) {
            $q = @{ team = -1; x = 0; z = 0 }
            foreach ($kv in [regex]::Matches($pm.Groups[1].Value, '(\w+)\s*=\s*(-?\d+)')) { $q[$kv.Groups[1].Value] = [int]$kv.Groups[2].Value }
            $out += ,$q
        }
        return $out
    }
    $vis = [regex]::Match($body, '\bvisible\s*=\s*(true|false)')
    $cap = @{ visible = ((-not $vis.Success) -or $vis.Groups[1].Value -eq 'true'); mode = (Txt 'mode' 'own'); reward = (Txt 'reward' 'once'); amount = (Num 'amount' 100); radius = (Num 'radius' 100); score = (Num 'score' 3); returnTime = (Num 'returnTime' 30); xp = (Num 'xp' 50); homes = (Points 'homes'); flags = (Points 'flags') }
    if ($cap.homes.Count -eq 0 -or $cap.flags.Count -eq 0) {
        Write-Host 'Note: Capture the Flag is on in the level, but collection points or flag points are missing: the scenario is built without it.' -ForegroundColor Yellow
        return $null
    }
    return $cap
}

# ---------------------------------------------------------------- Read the level
function Read-LevelFile([string]$path) {
    $txt = $BLOCK_RX.Replace([IO.File]::ReadAllText($path, $utf8), '')
    $m = [regex]::Match($txt, 'map\s*=\s*"([^"]+)"')
    if (-not $m.Success) { throw 'The level file contains no map (map = "...").' }
    $level = @{ map = $m.Groups[1].Value; mods = [ordered]@{}; units = @(); features = @(); mapX = 0; mapZ = 0; unitLimit = 32000 }
    $ms = [regex]::Match($txt, 'mapsize\s*=\s*\{\s*(\d+)\s*,\s*(\d+)\s*\}')
    if ($ms.Success) { $level.mapX = [int]$ms.Groups[1].Value; $level.mapZ = [int]$ms.Groups[2].Value }
    $ul = [regex]::Match($txt, 'unitlimit\s*=\s*(\d+)')
    if ($ul.Success) { $level.unitLimit = [math]::Max(500, [math]::Min(32000, [int]$ul.Groups[1].Value)) }
    $rm = [regex]::Match($txt, 'requiredmodoptions\s*=\s*\{([^}]*)\}')
    if ($rm.Success) {
        foreach ($kv in [regex]::Matches($rm.Groups[1].Value, '(\w+)\s*=\s*"([^"]*)"')) { $level.mods[$kv.Groups[1].Value] = $kv.Groups[2].Value }
    }
    $mu = [regex]::Match($txt, 'unitloadout\s*=\s*\{')
    $mf = [regex]::Match($txt, 'featureloadout\s*=\s*\{')
    $u0 = if ($mu.Success) { $mu.Index } else { -1 }
    $f0 = if ($mf.Success) { $mf.Index } else { -1 }
    if ($u0 -lt 0) { throw 'The level file contains no unitloadout list.' }
    if ($f0 -gt $u0) { $ubody = $txt.Substring($u0, $f0 - $u0); $fbody = $txt.Substring($f0) } else { $ubody = $txt.Substring($u0); $fbody = '' }
    $units = New-Object Collections.ArrayList
    foreach ($m in $UNIT_RX.Matches($ubody)) {
        $g = $m.Groups
        [void]$units.Add(@{ name = $g[1].Value; x = [int]$g[2].Value; y = [int]$g[3].Value; z = [int]$g[4].Value; rot = [int]$g[5].Value
                            team = $(if ($g[6].Success) { [int]$g[6].Value } else { 0 }); neutral = ($g[7].Value -eq 'true'); gaia = ($g[8].Value -eq 'true'); fixed = ($g[9].Value -eq 'true') })
    }
    $features = New-Object Collections.ArrayList
    foreach ($m in $FEATURE_RX.Matches($fbody)) {
        $g = $m.Groups
        $f = [ordered]@{ name = $g[1].Value; x = [int]$g[2].Value; y = [int]$g[3].Value; z = [int]$g[4].Value; rot = [int]$g[5].Value }
        # Make wrecks ("<unit>_dead") resurrectable: the scenario script of the game then sets the resurrection (resurrectas)
        if ($g[6].Success) { $f['resurrectas'] = $g[6].Value }
        elseif ($f.name -cmatch '^(.+)_dead$') { $f['resurrectas'] = $Matches[1] }
        [void]$features.Add($f)
    }
    if ($units.Count -eq 0) { throw 'The level contains no units.' }
    $level.units = @($units)
    $level.features = @($features)
    $level.td = Read-TowerDefense $txt
    $level.ctf = Read-Capture $txt
    return $level
}

function Select-LevelFile([string]$wanted) {
    $files = @(Get-ChildItem $LEVELS -Filter '*.lua' -ErrorAction SilentlyContinue | Sort-Object Name)
    if ($files.Count -eq 0) { throw "No levels found in $LEVELS. Save one in the editor with Ctrl+S." }
    if ($wanted) {
        $name = if ($wanted.EndsWith('.lua')) { $wanted } else { $wanted + '.lua' }
        $f = $files | Where-Object { $_.Name -eq $name } | Select-Object -First 1
        if (-not $f) { throw "Level $name not found. Available: " + (($files | ForEach-Object { $_.Name }) -join ', ') }
        return $f.FullName
    }
    Write-Host 'Saved levels:'
    for ($i = 0; $i -lt $files.Count; $i++) {
        Write-Host ('  {0,2}  {1}   ({2} KB)' -f ($i + 1), $files[$i].BaseName, [int][math]::Floor($files[$i].Length / 1024))
    }
    Write-Host '(_last = the last state backed up automatically by the editor)'
    $n = AskInt 'Number of the level' 1 1 $files.Count
    return $files[$n - 1].FullName
}

# ---------------------------------------------------------------- Block "scenario" in the level
function Update-Block($data) {
    $v = Get-Val $data 'version' 0
    if ($v -isnot [int] -and $v -isnot [long]) { $v = 0 }
    if ($v -gt $SCENARIO_VERSION) {
        Write-Host "Note: the info in the level comes from a newer version (version $v, this script knows $SCENARIO_VERSION)."
        Write-Host '         Known fields are taken over, unknown ones are kept when saving.'
        return $data
    }
    if ($v -lt 2 -and -not $data.Contains('grace')) { $data['grace'] = 0 } # version 2: grace period, none before
    $data['version'] = $SCENARIO_VERSION
    return $data
}

function Read-Block([string]$path) {
    $m = $BLOCK_RX.Match([IO.File]::ReadAllText($path, $utf8))
    if (-not $m.Success) { return $null }
    try {
        $t = ConvertTo-Table ($m.Groups[1].Value | ConvertFrom-Json)
        if ($t -isnot [System.Collections.IDictionary]) { return $null }
        return (Update-Block $t)
    } catch { return $null }
}

# Writes the answers as a 'scenario' block into the level file (replaces an existing one)
function Save-Block([string]$path, $answers) {
    $text = [IO.File]::ReadAllText($path, $utf8)
    $body = (ConvertTo-JsonText $answers 1 $true).Replace(']==]', '] ==]')
    $block = "`n`tscenario = [==[" + $body + ']==],'
    $m = $BLOCK_RX.Match($text)
    if ($m.Success) { $text = $text.Substring(0, $m.Index) + $block + $text.Substring($m.Index + $m.Length) }
    else {
        $i = $text.IndexOf('return {') + 'return {'.Length
        $text = $text.Substring(0, $i) + $block + $text.Substring($i)
    }
    [IO.File]::WriteAllText($path, $text, $utf8)
}

function Get-TeamSide($units, [int]$team) {
    $cnt = [ordered]@{}
    foreach ($u in $units) {
        if ($u.team -eq $team -and -not $u.gaia) {
            $p = $u.name.Substring(0, [math]::Min(3, $u.name.Length))
            if ($SIDES.ContainsKey($p)) { $cnt[$p] = 1 + [int]$cnt[$p] }
        }
    }
    # on a tie the side found first wins
    $best = $null
    foreach ($k in $cnt.Keys) { if ($null -eq $best -or $cnt[$k] -gt $cnt[$best]) { $best = $k } }
    if ($null -eq $best) { return 'Armada' }
    return $SIDES[$best]
}

# zlib stream (like Python zlib.compress): header 78 DA, deflate, Adler-32
function Compress-Zlib([byte[]]$raw) {
    $ms = New-Object IO.MemoryStream
    $ms.WriteByte(0x78); $ms.WriteByte(0xDA)
    $ds = New-Object IO.Compression.DeflateStream($ms, [IO.Compression.CompressionLevel]::Optimal, $true)
    $ds.Write($raw, 0, $raw.Length); $ds.Close()
    $a = [uint32]1; $b = [uint32]0
    foreach ($x in $raw) { $a = ($a + $x) % 65521; $b = ($b + $a) % 65521 }
    $adler = ([uint64]$b * 65536) + $a
    foreach ($sh in 24, 16, 8, 0) { $ms.WriteByte([byte](($adler -shr $sh) -band 255)) }
    return $ms.ToArray()
}

# ---------------------------------------------------------------- Build the scenario
function Build-Scenario([string]$levelName, [bool]$auto) {
    $script:Auto = $auto
    Write-Host "=== Scenario builder ===`n"
    $path = Select-LevelFile $levelName
    $base = [IO.Path]::GetFileNameWithoutExtension($path)
    $level = Read-LevelFile $path
    # info entered earlier is in the level itself (block "scenario"); the editor writes it back unchanged
    $saved = Read-Block $path
    if ($saved) { Write-Host 'Scenario info found in the level: Enter takes the saved answers.' } else { $saved = [ordered]@{} }
    $teamsFound = @($level.units | Where-Object { -not $_.gaia } | ForEach-Object { $_.team } | Sort-Object -Unique)
    $nGaia = @($level.units | Where-Object { $_.gaia }).Count
    if ($teamsFound.Count -eq 0) { throw 'The level contains only Gaia units, it needs at least one player team.' }
    $td = $level.td
    if ($td) {
        Write-Host "Tower Defense is on in the level: $($td.waves.Count) waves, $($td.waypoints.Count) waypoints. The waves are part of the scenario." -ForegroundColor Cyan
        # the waves belong to an enemy team: when the level has none, a team without units is added
        if ($teamsFound.Count -eq 1) { $teamsFound = @($teamsFound) + @([int]$teamsFound[0] + 1) }
    }
    $ctf = $level.ctf
    if ($ctf) {
        Write-Host "Capture the Flag is on in the level: $($ctf.flags.Count) flag points, $($ctf.homes.Count) collection points, $($ctf.mode) flags. It is part of the scenario (against a computer opponent that does not play it: only a game of your own)." -ForegroundColor Cyan
        if ($td) { Write-Host 'Tower Defense is on as well: whoever starts the scenario chooses which of the two modes to play.' -ForegroundColor Cyan }
        # every team with a collection point must exist (a team without units is added)
        $teamsFound = @(@($teamsFound) + @($ctf.homes | ForEach-Object { $_.team }) | Sort-Object -Unique)
    }
    $info = "`nLevel ${base}: map $($level.map), $($level.units.Count) units, $($level.features.Count) features, teams [$($teamsFound -join ', ')]"
    if ($nGaia) { $info += ", $nGaia Gaia units" }
    Write-Host ($info + "`n")

    $defTitle = if (-not $base.StartsWith('_')) { (Get-Culture).TextInfo.ToTitleCase(($base -replace '_', ' ').Trim()) } else { 'My scenario' }
    $title = Ask 'Title of the scenario' (Get-Val $saved 'title' $defTitle)
    $author = Ask 'Author (may stay empty)' (Get-Val $saved 'author' '')
    $summary = Ask 'Summary (one line)' (Get-Val $saved 'summary' '')
    $briefDef = Get-Val $saved 'briefing' $summary
    $briefing = AskMultiline 'Briefing / task' $briefDef

    # --- Teams
    if (-not $Auto) {
        Write-Host "`nRoles of the teams in the level. Player = the human (exactly one team), Allied = AI on the side of the player, Enemy = AI against the player." }
    $savedRoles = Get-Val $saved 'roles' ([ordered]@{})
    $roles = [ordered]@{}
    $opts = @(@('s', 'Player'), @('v', 'Allied AI'), @('e', 'Enemy (AI)'))
    foreach ($t in $teamsFound) {
        $n = @($level.units | Where-Object { $_.team -eq $t }).Count
        $side = Get-TeamSide $level.units $t
        $def = Get-Val $savedRoles ([string]$t) $(if ($t -eq $teamsFound[0]) { 's' } else { 'e' })
        $roles[[string]$t] = AskChoice "Team ${t}: $n units, side $side" $opts $def
    }
    while (@($roles.Values | Where-Object { $_ -eq 's' }).Count -ne 1) {
        if ($Auto) { throw 'There must be exactly one player team.' }
        Write-Host 'There must be exactly one player team, please try again:'
        foreach ($t in $teamsFound) { $roles[[string]$t] = AskChoice "Team $t" $opts $roles[[string]$t] }
    }
    $savedTiers = Get-Val $saved 'tiers' ([ordered]@{})
    $tiers = [ordered]@{}
    foreach ($t in $teamsFound) {
        $tiers[[string]$t] = AskTiers "Tech team $t" (Get-Val $savedTiers ([string]$t) '123')
    }
    $ai = Get-Val $saved 'ai' 'BARb'
    if (@($roles.Values | Where-Object { $_ -ne 's' }).Count -gt 0) {
        $c = AskChoice 'Behavior of the AI teams' @(@('1', 'BARb - expands and attacks'), @('2', 'NullAI - does nothing (targets)')) $(if ($ai -eq 'NullAI') { '2' } else { '1' })
        $ai = @{ '1' = 'BARb'; '2' = 'NullAI' }[$c]
    }

    # --- Game rules
    $winDef = @{ com = '1'; killall = '2'; neverend = '3' }[(Get-Val $saved 'win' 'com')]
    if (-not $winDef) { $winDef = '1' }
    $c = AskChoice "`nWin condition" @(@('1', 'Commanders: a team loses when its commander dies (BAR default)'),
                                       @('2', 'All units: a team only loses when everything is destroyed'),
                                       @('3', 'No end (sandbox)')) $winDef
    $win = @{ '1' = 'com'; '2' = 'killall'; '3' = 'neverend' }[$c]
    $metal = AskInt 'Start metal per team' (Get-Val $saved 'metal' 1000) 0 100000
    $energy = AskInt 'Start energy per team' (Get-Val $saved 'energy' 1000) 0 100000
    $grace = AskMinutes 'Grace period as minutes:seconds, e.g. 2:30 (as long as that, every team stays in its start area and is safe from damage there; 0 = none)' (Get-Val $saved 'grace' 0)
    $sid = Get-Val $saved 'sid' (Get-Slug $title)
    $sid = Get-Slug (Ask 'ID (lowercase letters and digits only)' $sid)
    # From the start menu, at the end: the values stored in the level, then the title (Enter keeps it) and the name (ID) of the package; a new
    # title proposes a new name, an existing scenario of that name is only overwritten after a question; title and ID are written into the level
    if ($AskName) {
        $roleTxt = ($roles.Keys | ForEach-Object { 'team {0} = {1}' -f $_, $ROLE_TXT[$roles[$_]] }) -join ', '
        $tierTxt = ($tiers.Keys | Where-Object { $tiers[$_] -ne '123' } | ForEach-Object { 'team {0} only T{1}' -f $_, (($tiers[$_].ToCharArray()) -join '+T') }) -join ', '
        Write-Host ''
        Write-Host 'Scenario info stored in the level:' -ForegroundColor Cyan
        foreach ($row in @(
                @('Title', $title), @('Author', $author), @('Summary', $summary), @('Briefing', ($briefing -replace "`r?`n", ' / ')), @('Roles', $roleTxt),
                @('Tech', $(if ($tierTxt) { $tierTxt } else { 'all tiers' })), @('AI behavior', $ai), @('Win condition', $WIN_TXT[$win]), @('Start metal', $metal),
                @('Start energy', $energy), @('Grace period', $(if ($grace -gt 0) { (Format-Minutes $grace) + ' min' } else { 'none' })), @('ID', $sid),
                @('Tower Defense', $(if ($td) { 'on: {0} waves, {1} waypoints' -f $td.waves.Count, $td.waypoints.Count } else { 'off' })),
                @('Capture the Flag', $(if ($ctf) { 'on: {0} flag points, {1} collection points' -f $ctf.flags.Count, $ctf.homes.Count } else { 'off' })))) {
            $v = [string]$row[1]
            if ($v.Length -gt 90) { $v = $v.Substring(0, 87) + '...' }
            Write-Host ('  {0,-15} {1}' -f $row[0], $v)
        }
        Write-Host ''
        $t2 = AskLine 'Title of the scenario' $title
        if ($t2 -ne $title) { $sid = Get-Slug $t2 }
        $title = $t2
        $sid = Confirm-ScenarioId $sid
    }
    # Map size for the start areas: from the level, otherwise from earlier info, otherwise ask
    $mapX = $level.mapX; $mapZ = $level.mapZ
    if ($grace -gt 0 -and $mapX -le 0) {
        $mf = Get-Val $saved 'mapfields' $null
        if ($mf -and @($mf).Count -eq 2) { $mapX = [int]$mf[0] * 512; $mapZ = [int]$mf[1] * 512 }
        elseif ($Auto -and -not $script:AllowAsk) { throw 'The map size is missing for the grace period (the level was saved before this feature). Save it again once in the Level Editor.' }
        else {
            Write-Host 'The map size is not in the level (old level). Please enter it in fields as in the map description (e.g. 16 x 16).'
            $script:Auto = $false # also ask when rebuilding after editing
            $fx = AskInt 'Width in fields' 16 1 64
            $fz = AskInt 'Height in fields' $fx 1 64
            $script:Auto = $auto
            $mapX = $fx * 512; $mapZ = $fz * 512
            $saved['mapfields'] = @($fx, $fz)
        }
    }
    # unknown fields from newer versions are kept, the version is never lowered
    # Tower Defense: the enemy team only gets the waves (no AI of its own that takes them over) and the gadget decides about winning and losing
    $aiRun = if ($td -or $ctf) { 'NullAI' } else { $ai }
    $winRun = if ($td -or $ctf) { 'neverend' } else { $win }
    $answers = [ordered]@{}
    foreach ($k in $saved.Keys) { if ($KNOWN_FIELDS -notcontains $k) { $answers[$k] = $saved[$k] } } # also mapfields
    $answers['version'] = [math]::Max($SCENARIO_VERSION, [int](Get-Val $saved 'version' 0))
    $answers['title'] = $title; $answers['author'] = $author; $answers['summary'] = $summary; $answers['briefing'] = $briefing
    $answers['roles'] = $roles; $answers['tiers'] = $tiers; $answers['ai'] = $ai; $answers['win'] = $win; $answers['metal'] = $metal; $answers['energy'] = $energy; $answers['grace'] = $grace; $answers['sid'] = $sid
    Save-Block $path $answers
    # Tower Defense: no grace period (the no-rush rules of the game keep every unit inside its start area while it runs, so the wave
    # units could not leave the spawn point); the saved answer stays in the level
    if ($td -and $grace -gt 0) {
        Write-Host 'Note: no grace period in a Tower Defense scenario (the enemy waves could not leave their start area).' -ForegroundColor Yellow
        $grace = 0
    }

    # --- Renumber the teams (0..n-1, player first)
    $order = @($teamsFound | Where-Object { $roles[[string]$_] -eq 's' }) + @($teamsFound | Where-Object { $roles[[string]$_] -ne 's' })
    $newid = @{}
    for ($i = 0; $i -lt $order.Count; $i++) { $newid[[int]$order[$i]] = $i }
    $ally = @{}
    foreach ($t in $teamsFound) { $ally[[int]$t] = $(if ($roles[[string]$t] -in 's', 'v') { 0 } else { 1 }) }

    # --- scenariooptions
    $units = New-Object Collections.ArrayList
    $sorted = $level.units | Sort-Object @{ Expression = { if ($_.gaia) { $order.Count } else { $newid[[int]$_.team] } } }, @{ Expression = { $_.name } }, @{ Expression = { $_.x } }, @{ Expression = { $_.z } }
    foreach ($u in $sorted) {
        # Gaia is the team after the last real team
        $e = [ordered]@{ name = $u.name; x = $u.x; y = $u.y; z = $u.z; rot = $u.rot; team = $(if ($u.gaia) { $order.Count } else { $newid[[int]$u.team] }) }
        if ($u.neutral) { $e['neutral'] = $true }
        [void]$units.Add($e)
    }
    # Tech restriction: only teams where not all tiers are allowed (key = new team number)
    $tierOut = [ordered]@{}
    foreach ($t in $order) { if ($tiers[[string]$t] -ne '123') { $tierOut[[string]$newid[[int]$t]] = $tiers[[string]$t] } }
    $so = [ordered]@{ scenarioid = $sid; scenariomaker = $true; grace = $grace; version = '1'; title = $title; author = $author; summary = $summary
                      briefing = $briefing; disablefactionpicker = $true; unitloadout = @($units); featureloadout = @($level.features) }
    if ($tierOut.Count -gt 0) { $so['tiers'] = $tierOut }
    $raw = $utf8.GetBytes((ConvertTo-JsonText $so -1 $false))
    $payload = [Convert]::ToBase64String((Compress-Zlib $raw)).Replace('+', '-').Replace('/', '_')

    # --- Start script
    $lines = New-Object Collections.ArrayList
    [void]$lines.Add('[game]'); [void]$lines.Add('{')
    # Grace period: start area per alliance = frame around its units (with a margin), as a fraction of the map.
    # With many units the outer 3 % on every edge do not count (outliers); overlapping areas
    # are separated, the area of the player side staying unchanged.
    $boxes = @{}
    if ($grace -gt 0) {
        $margin = 300
        $gap = 500
        $pick = { param($v, $f) $sorted = @($v | Sort-Object); $sorted[[int][math]::Floor($f * ($sorted.Count - 1))] }
        $bx = @{}
        foreach ($a in @($ally.Values | Sort-Object -Unique)) {
            $mine = @($level.units | Where-Object { -not $_.gaia -and $ally[[int]$_.team] -eq $a })
            $lo = 0.0; $hi = 1.0
            if ($mine.Count -ge 30) { $lo = 0.03; $hi = 0.97 }
            $xs = @($mine | ForEach-Object { [double]$_.x }); $zs = @($mine | ForEach-Object { [double]$_.z })
            $bx[$a] = @(((& $pick $xs $lo) - $margin), ((& $pick $zs $lo) - $margin), ((& $pick $xs $hi) + $margin), ((& $pick $zs $hi) + $margin))
        }
        $keys = @($bx.Keys | Sort-Object)
        for ($i = 0; $i -lt $keys.Count; $i++) { for ($j = $i + 1; $j -lt $keys.Count; $j++) {
            $p = $bx[$keys[$i]]; $q = $bx[$keys[$j]]
            # A strip without area stays between the areas ($gap), so the enemies do not stand right at the border
            $pe = @(($p[0] - $gap), ($p[1] - $gap), ($p[2] + $gap), ($p[3] + $gap))
            $ox = [math]::Min($pe[2], $q[2]) - [math]::Max($pe[0], $q[0])
            $oz = [math]::Min($pe[3], $q[3]) - [math]::Max($pe[1], $q[1])
            if ($ox -gt 0 -and $oz -gt 0) {
                # The area of the player side (smaller number) stays whole; the other one is cut back
                if ($ox -le $oz) {
                    if (($p[0] + $p[2]) -le ($q[0] + $q[2])) { $q[0] = $pe[2] } else { $q[2] = $pe[0] }
                } else {
                    if (($p[1] + $p[3]) -le ($q[1] + $q[3])) { $q[1] = $pe[3] } else { $q[3] = $pe[1] }
                }
                Write-Host 'Note: the start areas of the sides overlapped; the enemy area was cut back (with a gap to yours).' -ForegroundColor Yellow
            }
        } }
        foreach ($a in $keys) {
            $b = $bx[$a]
            # Double values (0.0 / 1.0): with integers [math]::Max would round to integers
            $boxes[$a] = @([math]::Max(0.0, $b[0] / [double]$mapX), [math]::Max(0.0, $b[1] / [double]$mapZ), [math]::Min(1.0, $b[2] / [double]$mapX), [math]::Min(1.0, $b[3] / [double]$mapZ))
        }
    }
    $inv = [Globalization.CultureInfo]::InvariantCulture
    foreach ($a in @($ally.Values | Sort-Object -Unique)) {
        $rect = ''
        if ($boxes.ContainsKey($a)) {
            $b = $boxes[$a]
            $rect = "`t`tStartRectLeft=" + $b[0].ToString('0.####', $inv) + ";`n`t`tStartRectTop=" + $b[1].ToString('0.####', $inv) + ";`n`t`tStartRectRight=" + $b[2].ToString('0.####', $inv) + ";`n`t`tStartRectBottom=" + $b[3].ToString('0.####', $inv) + ";`n"
        }
        [void]$lines.Add("`t[allyteam$a]`n`t{`n`t`tnumallies=0;`n$rect`t}")
    }
    foreach ($t in $order) {
        $i = $newid[[int]$t]
        $side = Get-TeamSide $level.units $t
        $color = $COLORS[$i % $COLORS.Count]
        [void]$lines.Add("`t[team$i]`n`t{`n`t`tAllyTeam=$($ally[[int]$t]);`n`t`tTeamLeader=0;`n`t`tSide=$side;`n`t`tHandicap=0;`n`t`tRgbColor=$color;`n`t}")
    }
    $k = 0
    foreach ($t in $order) {
        $i = $newid[[int]$t]
        if ($roles[[string]$t] -eq 's') { continue }
        $ver = if ($aiRun -eq 'BARb') { 'stable' } else { '0.1' }
        [void]$lines.Add("`t[ai$k]`n`t{`n`t`tShortName=$aiRun;`n`t`tName=${aiRun}_$i;`n`t`tTeam=$i;`n`t`tHost=0;`n`t`tVersion=$ver;`n`t}")
        $k++
    }
    [void]$lines.Add("`t[player0]`n`t{`n`t`tName=__PLAYERNAME__;`n`t`tTeam=0;`n`t`tspectator=0;`n`t`trank=0;`n`t}")
    $mods = [ordered]@{ deathmode = $winRun; maxunits = $level.unitLimit; startmetal = $metal; startenergy = $energy; scenariooptions = $payload }
    if ($td) {
        # settings for the gadget td_waves.lua (text made harmless for the start script: base64url, no ';' inside)
        $enemyOld = @($order | Where-Object { $roles[[string]$_] -eq 'e' })[0]
        if ($null -eq $enemyOld) { $enemyOld = @($order | Where-Object { $roles[[string]$_] -ne 's' })[0] }
        $enemyNew = $newid[[int]$enemyOld]
        $path = if ($td.waypoints.Count -gt 0) { ($td.waypoints | ForEach-Object { '{0},{1}' -f $_[0], $_[1] }) -join '/' } else { '-' }
        $waves = ($td.waves | ForEach-Object { '{0},{1},{2},{3},{4},{5}' -f $_.fac, $_.kind, $_.tech, $_.count, $_.gap, $_.hp }) -join '/'
        $banned = if ($td.banned.Count -gt 0) { $td.banned -join ',' } else { '-' }
        $bannedTech = if ($td.bannedTech.Count -gt 0) { $td.bannedTech -join ',' } else { '-' }
        $plain = (@($enemyNew, 0, $td.spawn[0], $td.spawn[1], $td.goal[0], $td.goal[1], $td.leaks, $path, $waves, $banned, $bannedTech, $(if ($td.economy) { 'economy' } else { 'towers' }), $(if ($td.fog) { '1' } else { '0' })) -join ';')
        $mods['tdconfig'] = [Convert]::ToBase64String($utf8.GetBytes($plain)).Replace('+', '-').Replace('/', '_').TrimEnd('=')
        # indestructible units (corridor walls, buildings marked with FX): name:x,z,x,z|name:...
        $fixed = @($level.units | Where-Object { $_.fixed })
        if ($fixed.Count -gt 0) {
            $groups = $fixed | Group-Object { $_.name } | ForEach-Object { $_.Name + ':' + (($_.Group | ForEach-Object { '{0},{1}' -f $_.x, $_.z }) -join ',') }
            $mods['tdfixed'] = [Convert]::ToBase64String($utf8.GetBytes(($groups -join '|'))).Replace('+', '-').Replace('/', '_').TrimEnd('=')
        }
        if ($win -ne 'neverend') { Write-Host "Note: the win condition is set to 'no end' for Tower Defense (the waves decide: all beaten = won, too many through = lost)." -ForegroundColor Yellow }
    }
    if ($td -and $ctf) {
        # both modes in one package: the starter asks which one to play and puts it here (the gadgets leave the other one alone, Tower Defense walls go in Capture the Flag)
        $mods['scenariomode'] = '__SCENARIOMODE__'
    }
    if ($ctf) {
        # settings for the gadget ctf_game.lua (mode;reward;amount;radius;score;returnTime;homes;flags;visible;xp, teams renumbered like the units)
        $homes = @($ctf.homes | Where-Object { $newid.ContainsKey([int]$_.team) } | ForEach-Object { '{0},{1},{2}' -f $newid[[int]$_.team], $_.x, $_.z }) -join '/'
        $flags = @($ctf.flags | ForEach-Object { '{0},{1},{2}' -f $(if ($ctf.mode -eq 'own' -and $newid.ContainsKey([int]$_.team)) { $newid[[int]$_.team] } else { -1 }), $_.x, $_.z }) -join '/'
        $plain = (@($ctf.mode, $ctf.reward, $ctf.amount, $ctf.radius, $ctf.score, $ctf.returnTime, $homes, $flags, $(if ($ctf.visible) { '1' } else { '0' }), $ctf.xp) -join ';')
        $mods['ctfconfig'] = [Convert]::ToBase64String($utf8.GetBytes($plain)).Replace('+', '-').Replace('/', '_').TrimEnd('=')
        if ($win -ne 'neverend') { Write-Host "Note: the win condition is set to 'no end' for Capture the Flag (the flags decide: the first team with $($ctf.score) flags wins; 0 = no end)." -ForegroundColor Yellow }
    }
    if ($grace -gt 0) { $mods['norushtimer'] = $grace.ToString('0.####', [Globalization.CultureInfo]::InvariantCulture) }
    foreach ($mk in $level.mods.Keys) { $mods[$mk] = $level.mods[$mk] }
    $mtxt = ($mods.Keys | ForEach-Object { "`t`t$_=$($mods[$_]);`n" }) -join ''
    [void]$lines.Add("`t[modoptions]`n`t{`n$mtxt`t}")
    foreach ($l in @('hostip=127.0.0.1;', 'hostport=0;', 'ishost=1;', 'myplayername=__PLAYERNAME__;', 'numplayers=1;', "numusers=$(1 + $k);", 'gametype=__GAMETYPE__;',
                     "mapname=$($level.map);", $(if ($grace -gt 0) { 'startpostype=2;' } else { 'startpostype=0;' }), 'GameStartDelay=3;', 'nohelperais=0;')) { [void]$lines.Add("`t$l") }
    [void]$lines.Add('}')
    $script = ($lines -join "`n") + "`n"

    # --- Write the package
    $folder = Join-Path $OUT $sid
    if (Test-Path $folder) { Remove-Item $folder -Recurse -Force }
    New-Item -ItemType Directory -Force $folder | Out-Null
    [IO.File]::WriteAllText((Join-Path $folder 'scenario.txt'), $script, $utf8)
    Copy-Item (Join-Path $TEMPLATE 'start_scenario.ps1') $folder
    Copy-Item (Join-Path $TEMPLATE 'scenario_briefing.lua') $folder
    if ($td -or $ctf) { Copy-Item (Join-Path (Join-Path (Split-Path (Split-Path $HERE -Parent) -Parent) 'shared') 'bar_rules.lua') (Join-Path $folder 'bar_rules.lua') } # rules the gadgets share with the editor
    if ($td) { Copy-Item (Join-Path (Split-Path $HERE -Parent) 'td_waves.lua') (Join-Path $folder 'td_waves.lua') } # the waves run in this gadget (the starter builds a small extra game from it)
    if ($ctf) { Copy-Item (Join-Path (Split-Path $HERE -Parent) 'ctf_game.lua') (Join-Path $folder 'ctf_game.lua') } # the flags run in this gadget (the starter builds a small extra game from it)
    $bat = "@echo off`r`nrem Starts the scenario `"$(Get-AsciiName $title)`" with the installed Beyond All Reason.`r`n" +
           "powershell -NoProfile -ExecutionPolicy Bypass -File `"%~dp0start_scenario.ps1`" %*`r`n"
    [IO.File]::WriteAllText((Join-Path $folder 'Start Scenario.bat'), $bat, [Text.Encoding]::ASCII)
    $winTxt = @{ com = 'destroy the commander'; killall = 'destroy all units'; neverend = 'no end' }[$winRun]
    if ($td) { $winTxt = "Tower Defense: beat all $($td.waves.Count) waves (at most $($td.leaks) enemies may get through)" }
    if ($ctf) { $winTxt = $(if ($ctf.score -gt 0) { "Capture the Flag: the first team with $($ctf.score) delivered flags wins" } else { 'Capture the Flag: no end' }) }
    $readme = New-Object Collections.ArrayList
    [void]$readme.Add($title); [void]$readme.Add('=' * $title.Length); [void]$readme.Add('')
    if ($author) { [void]$readme.Add("Author: $author"); [void]$readme.Add('') }
    if ($summary) { [void]$readme.Add($summary); [void]$readme.Add('') }
    if ($briefing -and $briefing -ne $summary) { [void]$readme.Add($briefing); [void]$readme.Add('') }
    foreach ($l in @("Map: $($level.map)", "Win condition: $winTxt", $(if ($grace -gt 0) { "Grace period: $(Format-Minutes $grace) minutes (until then every side stays in its start area and is safe from damage there)" } else { 'Grace period: none' }), "Start resources: $metal metal, $energy energy", '',
                     ('Teams: ' + (($order | ForEach-Object { '{0} = {1}' -f $newid[[int]$_], $ROLE_TXT[$roles[[string]$_]] }) -join ', ')), $(if ($tierOut.Count -gt 0) { 'Tech: ' + (($tierOut.Keys | ForEach-Object { 'Team {0} only T{1}' -f $_, (($tierOut[$_].ToCharArray()) -join '+T') }) -join '; ') } else { 'Tech: no restriction' }), '',
                     'How to play the scenario',
                     '1. Install Beyond All Reason and start it once (the launcher downloads the game and the engine).',
                     '2. Double-click "Start Scenario.bat". The script finds BAR itself (otherwise it asks for the folder),',
                     '   downloads the map if needed and starts the game. Nothing in the game itself is changed.',
                     '3. The units are there right away, there is no start commander except those in the scenario.',
                     $(if ($td -and $ctf) { '   This package holds Tower Defense and Capture the Flag: Start Scenario.bat asks which of the two you want to play (or: Start Scenario.bat -Mode td / -Mode ctf).' } else { '' }),
                     $(if ($ctf) { '   Capture the Flag: the starter also builds the small extra game "Tower Defense Scenario" (data\games\TowerDefenseScenario.sdz) with the flag gadget; no official file is changed.' } else { '' }),
                     $(if ($td) { '   Tower Defense: the starter also builds a small extra game "Tower Defense Scenario" (data\games\TowerDefenseScenario.sdz) that builds on your Beyond All Reason and runs the enemy waves; no official file is changed.' } else { '' }),
                     $(if ($grace -gt 0) { 'Grace period: before the start the start position selection appears. Click into your start area (marked frame) and press Ready.' } else { '' }),
                     '', 'Note: the folder may be copied to any place, also to another computer.')) { [void]$readme.Add($l) }
    [IO.File]::WriteAllText((Join-Path $folder 'README.txt'), (($readme -join "`r`n") + "`r`n"), (New-Object Text.UTF8Encoding($true)))
    $zpath = Join-Path $OUT ($sid + '.zip')
    if (Test-Path $zpath) { Remove-Item $zpath -Force }
    $zip = [IO.Compression.ZipFile]::Open($zpath, 'Create')
    try {
        foreach ($f in Get-ChildItem $folder -File) {
            [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.FullName, ($sid + '/' + $f.Name), [IO.Compression.CompressionLevel]::Optimal)
        }
    } finally { $zip.Dispose() }
    Write-Host ("`nDone: {0} units, {1} features, {2} KB start script." -f $units.Count, $level.features.Count, [int][math]::Floor($script.Length / 1024))
    Write-Host "Folder: $folder"
    Write-Host "Zip to pass on: $zpath"
    Write-Host 'Test: double-click Start Scenario.bat in the folder.'
}

# ---------------------------------------------------------------- Change the info
function Edit-Scenario([string]$levelName) {
    $script:Auto = $false
    Write-Host "=== Edit scenario ===`n"
    $path = Select-LevelFile $levelName
    $base = [IO.Path]::GetFileNameWithoutExtension($path)
    $saved = Read-Block $path
    if (-not $saved) { throw "The level $base has no (readable) scenario info yet. Create a scenario from it first (key 3)." }
    $level = Read-LevelFile $path
    $teams = @($level.units | Where-Object { -not $_.gaia } | ForEach-Object { $_.team } | Sort-Object -Unique)
    $savedRoles = Get-Val $saved 'roles' ([ordered]@{})
    $roles = [ordered]@{}
    foreach ($t in $teams) { $roles[[string]$t] = Get-Val $savedRoles ([string]$t) $(if ($t -eq $teams[0]) { 's' } else { 'e' }) }
    $opts = @(@('s', 'Player'), @('v', 'Allied AI'), @('e', 'Enemy (AI)'))
    $onePlayer = { @($roles.Values | Where-Object { $_ -eq 's' }).Count -eq 1 }
    $savedTiers = Get-Val $saved 'tiers' ([ordered]@{})

    while ($true) {
        $items = @(@('Title', 'title'), @('Author', 'author'), @('Summary', 'summary'), @('Briefing', 'briefing'))
        foreach ($t in $teams) { $items += , @("Role team $t", "role:$t") }
        foreach ($t in $teams) { $items += , @("Tech team $t", "tiers:$t") }
        $items += @(@('AI behavior', 'ai'), @('Win condition', 'win'), @('Start metal', 'metal'), @('Start energy', 'energy'), @('Grace period (min:sec)', 'grace'), @('ID', 'sid'))
        Write-Host "`nLevel $base - saved info:"
        for ($n = 0; $n -lt $items.Count; $n++) {
            $label = $items[$n][0]; $key = $items[$n][1]
            if ($key.StartsWith('role:')) { $val = $ROLE_TXT[$roles[$key.Substring(5)]] }
            elseif ($key.StartsWith('tiers:')) { $val = 'T' + ((Get-Val $savedTiers $key.Substring(6) '123').ToCharArray() -join '+T') }
            elseif ($key -eq 'win') { $val = $WIN_TXT[(Get-Val $saved 'win' 'com')] }
            elseif ($key -eq 'ai') { $val = Get-Val $saved 'ai' 'BARb' }
            elseif ($key -eq 'grace') { $val = Format-Minutes (Get-Val $saved 'grace' 0) }
            else {
                $val = ([string](Get-Val $saved $key '')).Replace("`n", ' / ')
                if ($val.Length -gt 60) { $val = $val.Substring(0, 57) + '...' }
            }
            Write-Host ('  {0,2}  {1}: {2}' -f ($n + 1), $label, $val)
        }
        $v = Ask 'Number to change (Enter = done)' ''
        if ($v -eq '') { break }
        $num = 0
        if (-not [int]::TryParse($v, [ref]$num) -or $num -lt 1 -or $num -gt $items.Count) { Write-Host '   Please enter a number from the list.'; continue }
        $label = $items[$num - 1][0]; $key = $items[$num - 1][1]
        if ($key.StartsWith('role:')) {
            $tk = $key.Substring(5)
            $roles[$tk] = AskChoice $label $opts $roles[$tk]
            if (-not (& $onePlayer)) { Write-Host '   Note: in the end there must be exactly one player team.' }
        }
        elseif ($key.StartsWith('tiers:')) {
            $tk = $key.Substring(6)
            $nt = [ordered]@{}
            foreach ($p in @($savedTiers.Keys)) { $nt[[string]$p] = $savedTiers[$p] }
            $nt[$tk] = AskTiers $label (Get-Val $savedTiers $tk '123')
            $savedTiers = $nt
            $saved['tiers'] = $nt
        }
        elseif ($key -eq 'briefing') { $saved['briefing'] = AskMultiline 'Briefing / task' (Get-Val $saved 'briefing' '') }
        elseif ($key -eq 'ai') {
            $c = AskChoice 'Behavior of the AI teams' @(@('1', 'BARb - expands and attacks'), @('2', 'NullAI - does nothing (targets)')) $(if ((Get-Val $saved 'ai' 'BARb') -eq 'NullAI') { '2' } else { '1' })
            $saved['ai'] = @{ '1' = 'BARb'; '2' = 'NullAI' }[$c]
        }
        elseif ($key -eq 'win') {
            $d = @{ com = '1'; killall = '2'; neverend = '3' }[(Get-Val $saved 'win' 'com')]
            if (-not $d) { $d = '1' }
            $c = AskChoice 'Win condition' @(@('1', 'Commanders'), @('2', 'All units'), @('3', 'No end (sandbox)')) $d
            $saved['win'] = @{ '1' = 'com'; '2' = 'killall'; '3' = 'neverend' }[$c]
        }
        elseif ($key -eq 'metal' -or $key -eq 'energy') { $saved[$key] = AskInt $label (Get-Val $saved $key 1000) 0 100000 }
        elseif ($key -eq 'grace') { $saved[$key] = AskMinutes $label (Get-Val $saved $key 0) }
        elseif ($key -eq 'sid') { $saved['sid'] = Get-Slug (Ask 'ID (lowercase letters and digits only)' (Get-Val $saved 'sid' '')) }
        else { $saved[$key] = Ask $label (Get-Val $saved $key '') }
        if (& $onePlayer) {
            $saved['roles'] = $roles
            $saved['version'] = [math]::Max($SCENARIO_VERSION, [int](Get-Val $saved 'version' 0))
            Save-Block $path $saved
            Write-Host '   Saved.'
        }
    }
    if (-not (& $onePlayer)) { throw 'Not saved: there must be exactly one player team.' }
    if ((Ask 'Rebuild the scenario package now? (y/n)' 'y').ToLower().StartsWith('y')) { $script:AllowAsk = $true; Build-Scenario $base $true }
}

try {
    if ($Edit) { Edit-Scenario $Level } else { Build-Scenario $Level ([bool]$Auto) }
} catch {
    Write-Host ''
    Write-Host $_.Exception.Message -ForegroundColor Yellow
}
