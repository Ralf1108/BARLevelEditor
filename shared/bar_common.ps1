# Shared helpers of the setup scripts (Level Editor, BluePrinter, LAN Play) and of the scenario starter: find BAR, the engine and the installed
# game version, create junctions. Dot-source it: . (Join-Path (Split-Path $PSScriptRoot -Parent) 'shared\bar_common.ps1')
# The scenario builder copies this file into every scenario package, so start_scenario.ps1 finds it next to itself on another computer too.

# (a script may define its own Fail after dot-sourcing this file, e.g. one that waits for a key)
function Fail($t) { Write-Host "ERROR: $t" -ForegroundColor Red; exit 1 }

# A heading of a step of a setup
function Step($t) { Write-Host ""; Write-Host "== $t" -ForegroundColor Cyan }

# True if the answer to the question is yes (y, yes, j, ja; any case)
function Read-Yes([string]$question) {
    $a = Read-Host $question
    return ([string]$a).Trim().ToLower() -in @('y', 'yes', 'j', 'ja')
}

# Installation folder of Beyond All Reason (the folder with data\engine); asks if it is not found.
# $preferred: folders to try first (e.g. a -BarPath); $memo: a file that remembers the folder found last (read first, written at the end)
function Find-Bar([string[]]$preferred = @(), [string]$memo = $null) {
    $candidates = @($preferred | Where-Object { $_ })
    if ($memo -and (Test-Path $memo)) { $candidates += ([IO.File]::ReadAllText($memo)).Trim() }
    $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason')
    $parents = @('Games', 'Spiele', 'Program Files', 'Program Files (x86)', 'Programme', '')
    $names = @('Beyond-All-Reason', 'Beyond All Reason', 'BeyondAllReason')
    foreach ($drive in [IO.DriveInfo]::GetDrives()) {
        if ($drive.DriveType -ne 'Fixed' -or -not $drive.IsReady) { continue }
        foreach ($par in $parents) {
            foreach ($n in $names) {
                $candidates += (Join-Path (Join-Path $drive.RootDirectory.FullName $par) $n)
            }
        }
    }
    $bar = $null
    foreach ($c in $candidates) {
        if ($c -and (Test-Path (Join-Path $c 'data\engine'))) { $bar = $c; break }
    }
    while (-not $bar) {
        $in = Read-Host 'BAR not found. Please enter the installation folder (Beyond-All-Reason.exe is in it)'
        if (-not $in) { Fail 'Aborted.' }
        if (Test-Path (Join-Path $in 'data\engine')) { $bar = $in } else { Write-Host 'There is no data\engine folder there.' }
    }
    if ($memo) {
        New-Item -ItemType Directory -Force (Split-Path $memo) | Out-Null
        [IO.File]::WriteAllText($memo, $bar)
    }
    return $bar
}

# Newest engine folder with spring.exe (sorted by the numbers in the name, so 105.1.1 comes before 2025.04.10 and 99 before 105)
function Get-Engine($data) {
    $byVersion = { [regex]::Replace($_.Name, '\d+', [Text.RegularExpressions.MatchEvaluator] { param($m) $m.Value.PadLeft(10, '0') }) }
    $engineDir = Get-ChildItem (Join-Path $data 'engine') -Directory | Where-Object { Test-Path (Join-Path $_.FullName 'spring.exe') } | Sort-Object $byVersion | Select-Object -Last 1
    if (-not $engineDir) { Fail 'No engine found in data\engine. Please start BAR once so the launcher installs it.' }
    return $engineDir
}

# The bytes of a gzip file
function Read-GzBytes([string]$file) {
    Add-Type -AssemblyName System.IO.Compression
    $fs = [IO.File]::OpenRead($file)
    try {
        $gz = New-Object IO.Compression.GZipStream($fs, [IO.Compression.CompressionMode]::Decompress)
        $ms = New-Object IO.MemoryStream; $gz.CopyTo($ms); $gz.Close()
        return , $ms.ToArray()
    } finally { $fs.Close() }
}

# The list of the game versions of rapid (versions.gz: lines "tag,package md5,,name"), read once per data folder; $null when it is not there
$script:VersionsText = @{}
function Get-VersionsText([string]$data) {
    if (-not $script:VersionsText.ContainsKey($data)) {
        $file = Join-Path $data 'rapid\repos-cdn.beyondallreason.dev\byar\versions.gz'
        $script:VersionsText[$data] = if (Test-Path $file) { [Text.Encoding]::UTF8.GetString((Read-GzBytes $file)) } else { $null }
    }
    return $script:VersionsText[$data]
}

# Version of the installed official game (byar:test, otherwise byar:stable; the first one whose package is installed)
function Get-GameVersion($data) {
    if ($env:BAR_GAME_VERSION) { return $env:BAR_GAME_VERSION }   # forced (tests): when the lobby has announced a newer game that is not downloaded yet
    $text = Get-VersionsText $data
    if ($null -eq $text) { Fail 'No game data found (rapid\...\byar\versions.gz). Please start BAR once and let a game load.' }
    $game = $null; $fallback = $null
    foreach ($tag in @('byar:test', 'byar:stable')) {
        foreach ($line in ($text -split "`n")) {
            if ($line.StartsWith($tag + ',')) {
                $f = $line.Trim().Split(',')
                if (-not $fallback) { $fallback = $f[3] }
                if (-not $game -and (Test-Path (Join-Path $data ("packages\" + $f[1] + '.sdp')))) { $game = $f[3] }
            }
        }
    }
    if (-not $game) {
        $game = $fallback
        if ($game) { Write-Host "Note: installed game not identified clearly, taking $game" -ForegroundColor Yellow }
    }
    if (-not $game) { Fail 'Game version not found.' }
    return $game
}

# Junction $path -> $target. A junction to another folder (left over from a moved or renamed project folder) is
# pointed to $target again; a real folder at $path is left alone. Prints only what it changes.
function Set-Junction($path, $target) {
    New-Item -ItemType Directory -Force $target | Out-Null
    $item = Get-Item $path -Force -ErrorAction SilentlyContinue
    if ($item) {
        if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            Write-Host "Note: $path is a real folder, not a junction; left unchanged." -ForegroundColor Yellow
            return
        }
        $old = @($item.Target)[0]
        if ($old -and ([IO.Path]::GetFullPath($old).TrimEnd('\') -eq [IO.Path]::GetFullPath($target).TrimEnd('\'))) { return }
        cmd /c rmdir "$path" | Out-Null
        Write-Host "Stale junction removed: $path -> $old"
    }
    cmd /c mklink /J "$path" "$target" | Out-Null
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path $path)) { Write-Host "WARNING: the junction $path -> $target could not be created." -ForegroundColor Yellow; return }
    Write-Host "Junction: $path -> $target"
}

# Removes a junction (only the link, never the contents of the target)
function Remove-Junction($path) {
    $item = Get-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
    if (-not $item) { return $false }
    if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
        Write-Host "  skipped (not a junction but a real folder): $path" -ForegroundColor Yellow
        return $false
    }
    cmd /c rmdir "$path" | Out-Null
    return $true
}

# Writes a zip with the entries @(name, text) to $path: first into a temporary file that then replaces the old one, so a failure in between
# leaves the old file in place. $fixedTime: optional time for all entries (equal archives on every computer).
function Write-GameZip([string]$path, $entries, $fixedTime = $null) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $tmp = $path + '.tmp'
    if (Test-Path $tmp) { Remove-Item $tmp -Force }
    $utf8 = New-Object Text.UTF8Encoding($false)
    $zip = [IO.Compression.ZipFile]::Open($tmp, 'Create')
    try {
        foreach ($e in $entries) {
            $entry = $zip.CreateEntry($e[0])
            if ($fixedTime) { $entry.LastWriteTime = $fixedTime }
            $w = New-Object IO.StreamWriter($entry.Open(), $utf8)
            try { $w.Write($e[1]) } finally { $w.Close() }
        }
    } finally { $zip.Dispose() }
    Move-Item $tmp $path -Force
}

# ---------------------------------------------------------------- AIs of a start script
# The AIs of the page T of the editor (led_teams.lua, tm.AIS) as the [ai] section of a start script needs them: Short (shortname), Version and Profile
# ('easy' for "CircuitAI easy", otherwise ''). The Lua AIs get an [ai] section too (the engine ignores LuaAI= in [team]); an unknown name is NullAI.
$LuaAiNames = @('SimpleAI', 'SimpleDefenderAI', 'SimpleConstructorAI', 'ScavengersAI', 'RaptorsAI')
function Get-AiSpec([string]$name) {
    if ($name -in $LuaAiNames) { return [pscustomobject]@{ Short = $name; Version = '<not-versioned>'; Profile = '' } }
    if ($name -eq 'CircuitAI easy') { return [pscustomobject]@{ Short = 'CircuitAI'; Version = 'stable'; Profile = 'easy' } }
    if ($name -in 'BARb', 'CircuitAI') { return [pscustomobject]@{ Short = $name; Version = 'stable'; Profile = '' } }
    return [pscustomobject]@{ Short = 'NullAI'; Version = '0.1'; Profile = '' }
}

# ---------------------------------------------------------------- The extra game of the scenarios: "Level Editor Scenarios <version>"
# One game for every scenario (Tower Defense, Capture the Flag, Reclaim the Fame, Evolution, restrictions, indestructible buildings, the briefing): the gadgets
# and widgets switch themselves on only by the game options of a scenario. The version is made of the texts of its files and of the BAR version it builds on
# (the first 8 hex digits of a SHA-256), the file is games\LevelEditorScenarios_<version>.sdz: different files give a different game, so a game that
# came from somewhere else (a LAN host, an older package) never replaces another one, and equal files give the same game on every computer.
# Files: source name -> name in the archive, in this order (the order of the version hash too).
$ScenarioGameFiles = @(
    @('td_waves.lua', 'luarules/gadgets/td_waves.lua'),
    @('ctf_game.lua', 'luarules/gadgets/ctf_game.lua'),
    @('rtf_game.lua', 'luarules/gadgets/rtf_game.lua'),
    @('evo_game.lua', 'luarules/gadgets/evo_game.lua'),
    @('renegade_game.lua', 'luarules/gadgets/renegade_game.lua'),
    @('unit_restrictions.lua', 'luarules/gadgets/unit_restrictions.lua'),
    @('unit_indestructible.lua', 'luarules/gadgets/unit_indestructible.lua'),
    @('lan_latejoin.lua', 'luarules/gadgets/lan_latejoin.lua'),   # LAN Play: a player who joins a running game is moved into a team
    @('lan_pve_hold.lua', 'luarules/gadgets/lan_pve_hold.lua'),   # LAN Play: drops the orders of a Scavengers / Raptors AI of the room
    @('pve_supply_drops_stub.lua', 'luarules/gadgets/pve_supply_drops.lua'),   # replaces the lootbox gadget of the game (it let enemies capture the flags)
    @('bar_rules.lua', 'luaui/Include/bar_rules.lua'),
    @('editor_common.lua', 'luaui/Include/editor_common.lua'),   # Renegade: the unit menu of the debug mode is the one of the Level Editor (also in the extra game "Level Editor", see Get-EditorGameEntries)
    @('area_attack.lua', 'luaui/Include/area_attack.lua'),   # loaded by editor_common.lua
    @('led_gadgets.lua', 'luaui/Include/led_gadgets.lua'),   # what the gadgets share (editor mode, messages, game options)
    @('evo_gift.lua', 'luaui/widgets/evo_gift.lua'),   # Evolution (LAN Play): the window of the gift of stage 10
    @('renegade.lua', 'luaui/widgets/renegade.lua'),   # Renegade (LAN Play): the first person view and the steering of the own unit
    @('scenario_briefing.lua', 'luaui/widgets/scenario_briefing.lua'),   # the briefing window (a game widget: no "Allow user widgets" needed)
    @('shared_start.lua', 'luaui/widgets/shared_start.lua'))             # starts a game in which several humans play one team (Copilot)
$ScenarioGamePointer = 'LevelEditorScenarios.txt'   # in data\games: file name and game name of the one the editor setup built (read by LAN Play)

# The official list of the maps with their md5 (maps-metadata of Beyond All Reason: about 60 KB), saved as data\games\LevelEditorMapHashes.txt:
# "# etag=...", "# fetched=...", then one line "<spring name>|<md5>" per map. LAN Play reads it to check a map that a host sends (a lobby widget cannot make
# an HTTPS call). Only changed when the server has a newer list (If-None-Match); offline or on any error the old list stays and nothing is thrown.
$MapHashesFile = 'LevelEditorMapHashes.txt'
function Update-MapHashes([string]$data) {
    $path = Join-Path (Join-Path $data 'games') $MapHashesFile
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
        $headers = @{}
        if (Test-Path $path) {
            $first = Get-Content $path -TotalCount 1
            if ($first -match '^# etag=(.+)$') { $headers['If-None-Match'] = $Matches[1] }
        }
        try {
            $r = Invoke-WebRequest -Uri 'https://maps-metadata.beyondallreason.dev/latest/live_maps.validated.json' -Headers $headers -UseBasicParsing -TimeoutSec 15
        } catch {
            if ($_.Exception.Response -and [int]$_.Exception.Response.StatusCode -eq 304) { Write-Host 'Map list (md5) is up to date.'; return }
            throw
        }
        $lines = @("# etag=$($r.Headers['ETag'])", "# fetched=$(Get-Date -Format 'yyyy-MM-dd HH:mm')")
        foreach ($m in ($r.Content | ConvertFrom-Json)) {
            if ($m.springName -and $m.springName -notmatch '[|\r\n]' -and $m.md5 -match '^[0-9a-fA-F]{32}$') { $lines += "$($m.springName)|$($m.md5.ToLower())" }
        }
        if ($lines.Count -lt 20) { throw 'the list has too few maps' }
        New-Item -ItemType Directory -Force (Split-Path $path) | Out-Null
        [IO.File]::WriteAllLines($path, $lines, (New-Object Text.UTF8Encoding $false))
        Write-Host "Map list (md5) saved: $($lines.Count - 2) maps."
    } catch {
        $have = if (Test-Path $path) { 'the old list stays' } else { 'there is no list: LAN Play asks before it takes a map from a host' }
        Write-Host "Map list (md5) not loaded ($($_.Exception.Message)); $have." -ForegroundColor Yellow
    }
}

# Builds the game from the files found in $dirs (for every file the first folder that has it; missing files are left out) unless it exists already.
# Returns Name (the game name for the start script), Version, Path and File (the file name).
# Files of the game itself that the extra game replaces by a changed copy (made from the installed game when the extra game is built, so the copy follows the
# game's updates): archive path, then pairs of text to find and text to put in. The Scavengers and Raptors spawners and the voice message of the game
# refuse (return false / say "leave the match") when both AIs are in a game: with the changed copies a Raptors AI and a Scavengers AI play against each other.
# The area healers of the game heal the units of one computer team (the Raptors'): the copy heals those of the Scavengers' team too.
# The Scavengers' waves only start when the player teams have power (units); in a room the humans play the computers' teams and the Raptors count as the opponent: their power is added.
# A file whose text has changed so that it does not fit any more is left out (the extra game is built without it, a note is shown).
$ScenarioGameDerived = @(
    @('luarules/gadgets/raptor_spawner_defense.lua', @(, @('if BAR.Utilities.Gametype.IsRaptors() and not BAR.Utilities.Gametype.IsScavengers() then', 'if BAR.Utilities.Gametype.IsRaptors() then'))),
    @('luarules/gadgets/scav_spawner_defense.lua', @(@('if BAR.Utilities.Gametype.IsScavengers() and not BAR.Utilities.Gametype.IsRaptors() then', 'if BAR.Utilities.Gametype.IsScavengers() then'), @('totalPlayerTeamPower = GG.PowerLib.TotalPlayerTeamsPower()', 'totalPlayerTeamPower = GG.PowerLib.TotalPlayerTeamsPower() + ((GG.PowerLib.RaptorTeam and GG.PowerLib.TeamPower(GG.PowerLib.RaptorTeam)) or 0)'))),
    @('luarules/gadgets/pve_areahealers.lua', @(@('if healersTable[unitDefID] and (unitTeam == pveTeamID) then', 'if healersTable[unitDefID] and (unitTeam == pveTeamID or unitTeam == BAR.Utilities.GetScavTeamID()) then'), @('statsTable.healingrange, pveTeamID)', 'statsTable.healingrange, statsTable.teamID)'))),
    @('luaui/widgets/snd_notifications.lua', @(, @('BAR.Utilities.Gametype.IsRaptors() and BAR.Utilities.Gametype.IsScavengers()', 'false')))
)

# The text of a file of the installed game ($game = its name, as Get-GameVersion gives it): the package list (.sdp of rapid: gzip of records name length, name, md5,
# crc, size) names the md5 of the file, the file itself lies in pool\xx\<rest of the md5>.gz. $null when it is not found.
function Get-GameFileText([string]$data, [string]$game, [string]$path) {
    $text = Get-VersionsText $data
    if ($null -eq $text) { return $null }
    $hash = $null
    foreach ($line in ($text -split "`n")) {
        $f = $line.Trim().Split(',')
        if ($f.Count -ge 4 -and $f[3] -eq $game -and (Test-Path (Join-Path $data ('packages\' + $f[1] + '.sdp')))) { $hash = $f[1]; break }
    }
    if (-not $hash) { return $null }
    $d = Read-GzBytes (Join-Path $data ('packages\' + $hash + '.sdp'))
    $want = [Text.Encoding]::UTF8.GetBytes($path)
    $i = 0
    while ($i -lt $d.Length) {
        $n = $d[$i]
        if ($n -eq $want.Length) {
            $same = $true
            for ($k = 0; $k -lt $n; $k++) { if ($d[$i + 1 + $k] -ne $want[$k]) { $same = $false; break } }
            if ($same) {
                $md5 = -join ($d[($i + 1 + $n)..($i + 16 + $n)] | ForEach-Object { $_.ToString('x2') })
                $pool = Join-Path $data ('pool\' + $md5.Substring(0, 2) + '\' + $md5.Substring(2) + '.gz')
                if (-not (Test-Path $pool)) { return $null }
                return [Text.Encoding]::UTF8.GetString((Read-GzBytes $pool))
            }
        }
        $i += 1 + $n + 24
    }
    return $null
}

function Write-ScenarioGame([string]$data, [string]$game, [string[]]$dirs) {
    $entries = @()
    $bytes = New-Object System.Collections.Generic.List[byte]
    $bytes.AddRange([Text.Encoding]::UTF8.GetBytes($game + "`n"))
    foreach ($f in $ScenarioGameFiles) {
        $src = $null
        foreach ($d in $dirs) { if ($d -and (Test-Path (Join-Path $d $f[0]))) { $src = Join-Path $d $f[0]; break } }
        if (-not $src) { continue }
        $text = [IO.File]::ReadAllText($src).Replace("`r", '')
        $entries += , @($f[1], $text)
        $bytes.AddRange([Text.Encoding]::UTF8.GetBytes($f[1] + "`n" + $text + "`n"))
    }
    foreach ($f in $ScenarioGameDerived) {
        $text = Get-GameFileText $data $game $f[0]
        if ($text) { $text = $text.Replace("`r", '') }
        foreach ($pair in $f[1]) { if ($text) { if ($text.Contains($pair[0])) { $text = $text.Replace($pair[0], $pair[1]) } else { $text = $null } } }
        if (-not $text) { Write-Host "Note: $($f[0]) of the game was not found or has changed: Raptors against Scavengers in one game is not possible." -ForegroundColor Yellow; continue }
        $entries += , @($f[0], $text)
        $bytes.AddRange([Text.Encoding]::UTF8.GetBytes($f[0] + "`n" + $text + "`n"))
    }
    $ver = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes.ToArray())) -replace '-', '').Substring(0, 8).ToLower()
    $name = "Level Editor Scenarios $ver"
    $file = "LevelEditorScenarios_$ver.sdz"
    $gamesDir = Join-Path $data 'games'
    New-Item -ItemType Directory -Force $gamesDir | Out-Null
    $path = Join-Path $gamesDir $file
    if (-not (Test-Path $path)) {
        $modinfo = "return {`n`tname = `"Level Editor Scenarios`",`n`tshortName = `"LEScn`",`n`tversion = `"$ver`",`n`tgame = `"LevelEditorScenarios`",`n`tshortGame = `"LEScn`",`n" +
                   "`tdescription = `"Beyond All Reason plus the gadgets of the scenarios of the Level Editor`",`n`tmutator = `"Official`",`n`tmodtype = 1,`n`tdepend = { `"$game`" },`n}`n"
        $fixedTime = New-Object DateTimeOffset (2000, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
        Write-GameZip $path (@(, @('modinfo.lua', $modinfo)) + $entries) $fixedTime
    }
    return [pscustomobject]@{ Name = $name; Version = $ver; Path = $path; File = $file }
}
