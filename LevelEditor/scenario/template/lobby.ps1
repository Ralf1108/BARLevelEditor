# Lobby before a hosted game (dot-sourced by start_scenario.ps1; needs player_mapping.ps1 for ConvertTo-PlayerName and the last mapping).
# The host sees one box per team; every player who joins lands in a team box at once (the team he had last time if it is free, otherwise the first
# team without a player) and the host moves them. The joiners only send their name; a joiner whose connection breaks is removed.
# Protocol (one text line each, UTF-8, TCP): joiner -> host: "VERSION <hash> <date>" (the version of his files, see Get-PlayVersion), "HELLO <name>",
# "BYE", later "READY"; host -> joiner: "OK <name as the host knows it>" or "ERR <reason>", "VERSION <hash> <date>" (the host's), then
# "TEAM <n> <text>" and "ROSTER <name>=<team>;..." whenever something changes, at the end "START" (the
# joiners prepare: extra game, map) or "CANCEL"; when every joiner has said "READY" and the host's game is running the host sends "GO" and the
# joiners connect to it.
# The scenario itself (a bundle: scenario.txt and the gadgets it uses, data only, never programs) goes from the host to the joiners through the lobby:
# after "OK" and "VERSION" the host sends "OFFER <hash> <size>" (to a joiner with the same version); a joiner who has that hash in his cache
# (%LOCALAPPDATA%\BAR-Scenario\Cache\<hash>\) answers "HAVE <hash>", otherwise he opens a second connection to the same port, sends "FETCH <hash>", gets
# "SIZE <n>" and n bytes (a zip) and then says "HAVE <hash>"; "PROGRESS <percent>" tells the host how far he is. The host cannot start before everybody has it.
# The map: the host adds "MAP <size> <sha256> <file name>" to the offer (if he has the archive of the map). A joiner who has not got the map chooses
# nothing is asked: a joiner in the same network as the host (Test-SameLan: the address of the other one is in a subnet of one of his network cards) says
# "MAPREQ" at once and the host answers "MAPYES" (a request from outside the network gets "MAPNO"); everybody else downloads the map from the internet (the
# official map service). Only if that fails the joiner is offered D (download again) or H (ask the host). After "MAPYES" the joiner fetches the file on a second connection ("FETCHMAP <sha256> <his name>"), checks the hash, keeps it in the
# cache (an extra data folder of the engine) and says "MAPOK" (also when the map was there from the start); "MAPPROGRESS <percent>" shows how far he is.
# Update of the editor: to a joiner whose files are older than the host's (and only if the host runs the editor from a folder with scripts) the host adds
# "UPDATE <size> <sha256 of the zip> <number of files>" after VERSION; the joiner may fetch it ("FETCHUPDATE <sha256>" on a second connection), it is checked
# and unpacked into a folder of the cache, he sees which files would change and has to answer Y; only then the files are replaced (the old ones are saved
# first, a failure puts them back) and the joiner leaves the lobby (the editor has to be started again).
# A joiner whose files are not the same as the host's (other hash) stays in the lobby, marked, but the game cannot start until he has the same version.
# The focus starts on "Start game" (the last box): Enter or F5 starts at once.
# Keys of the host: Tab / Shift+Tab or Left / Right = next box, Up / Down = player in the box, Enter = pick the player up (then Up / Down /
# Left / Right move him into the neighbouring box, Enter drops him, Esc brings him back), Enter on "Start game" (the last stop) or F5 = start,
# Esc twice = cancel.

# The version of the files that decide how a game runs: the starter, the lobby, the briefing and the gadgets. Looked for by file name in the given
# folders (the editor: scripts, scenario\template, shared; the unpacked package of a scenario: one folder). The hash is made of the names and the texts
# (without carriage returns, so the line endings of git do not matter); the date (UTC) is the newest change of these files and only says who is
# probably newer: the hash decides whether two computers are the same. Returns Hash (hex), Date (yyyyMMddHHmmss), Count and Short (for the screen).
$script:PlayVersionFiles = @('bar_rules.lua', 'ctf_game.lua', 'lobby.ps1', 'player_mapping.ps1', 'pve_supply_drops_stub.lua', 'scenario_briefing.lua', 'start_scenario.ps1', 'td_waves.lua', 'unit_restrictions.lua')
function Get-PlayVersion([string[]]$dirs) {
    $bytes = New-Object System.Collections.Generic.List[byte]
    $newest = [DateTime]::MinValue; $count = 0
    foreach ($n in $script:PlayVersionFiles) {
        $f = $null
        foreach ($d in $dirs) { $c = Join-Path $d $n; if ($d -and (Test-Path $c)) { $f = $c; break } }
        if (-not $f) { continue }
        $bytes.AddRange([Text.Encoding]::UTF8.GetBytes($n + "`n"))
        $bytes.AddRange([Text.Encoding]::UTF8.GetBytes(([IO.File]::ReadAllText($f)).Replace("`r", '') + "`n"))
        $t = (Get-Item $f).LastWriteTimeUtc; if ($t -gt $newest) { $newest = $t }
        $count++
    }
    $hash = ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes.ToArray())) -replace '-', '')
    return [pscustomobject]@{ Hash = $hash; Date = $newest.ToString('yyyyMMddHHmmss'); Count = $count; Short = $hash.Substring(0, 8) }
}

# 'same' (same hash), 'older' (the other one is older than mine), 'newer' (the other one is newer than mine), 'differs' (other hash, same date)
function Compare-PlayVersion($mine, [string]$otherHash, [string]$otherDate) {
    if ($otherHash -eq $mine.Hash) { return 'same' }
    if ($otherDate -and $otherDate -lt $mine.Date) { return 'older' }
    if ($otherDate -and $otherDate -gt $mine.Date) { return 'newer' }
    return 'differs'
}

function Format-PlayDate([string]$d) {
    if ($d -match '^(\d{4})(\d\d)(\d\d)(\d\d)(\d\d)') { return '{0}-{1}-{2} {3}:{4}' -f $Matches[1], $Matches[2], $Matches[3], $Matches[4], $Matches[5] }
    return $d
}

# ---------------------------------------------------------------- Bundle: the scenario as data
# What a bundle may hold (names only, in this order for the hash). Lua files only run inside the game engine; nothing that runs on the computer itself
# (no .ps1, .bat) is ever taken from another computer.
$script:BundleFiles = @('bar_rules.lua', 'ctf_game.lua', 'pve_supply_drops_stub.lua', 'scenario.txt', 'td_waves.lua', 'unit_restrictions.lua')
$script:BundleMaxBytes = 64MB   # per bundle (zip and unpacked)

function Get-BundleCacheRoot { return (Join-Path $env:LOCALAPPDATA 'BAR-Scenario\Cache') }

# SHA-256 over the names and bytes of the files of a bundle in the folder (the id of the bundle: the same data give the same id on every computer)
function Get-BundleHash([string]$dir) {
    $bytes = New-Object System.Collections.Generic.List[byte]
    foreach ($n in $script:BundleFiles) {
        $f = Join-Path $dir $n
        if (-not (Test-Path $f)) { continue }
        $bytes.AddRange([Text.Encoding]::UTF8.GetBytes($n + "`n"))
        $bytes.AddRange([IO.File]::ReadAllBytes($f))
        $bytes.AddRange([Text.Encoding]::UTF8.GetBytes("`n"))
    }
    return ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes.ToArray())) -replace '-', '')
}

# the id comes from the network: only 64 hex digits may become a folder name
function Test-BundleId([string]$hash) { return ($hash -cmatch '^[0-9A-F]{64}$') }

function Test-BundleCached([string]$hash) {
    if (-not (Test-BundleId $hash)) { return $false }
    $dir = Join-Path (Get-BundleCacheRoot) $hash
    if (-not (Test-Path (Join-Path $dir 'complete.txt'))) { return $false }
    Use-CacheItem $dir   # (in use: not pruned for another 30 days)
    return $true
}

# puts the bundle files of a folder into the cache (folder <hash>, finished when complete.txt is there); returns Hash and Dir
function Install-Bundle([string]$srcDir) {
    $hash = Get-BundleHash $srcDir
    $dest = Join-Path (Get-BundleCacheRoot) $hash
    if (-not (Test-BundleCached $hash)) {
        if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
        New-Item -ItemType Directory -Force $dest | Out-Null
        foreach ($n in $script:BundleFiles) { if (Test-Path (Join-Path $srcDir $n)) { Copy-Item (Join-Path $srcDir $n) $dest } }
        Set-Content -Path (Join-Path $dest 'complete.txt') -Value 'complete' -Encoding ASCII
    }
    return [pscustomobject]@{ Hash = $hash; Dir = $dest }
}

# the zip that goes over the network (only the bundle files)
function New-BundleZip([string]$dir, [string]$zipPath) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    $zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
    try {
        foreach ($n in $script:BundleFiles) {
            if (Test-Path (Join-Path $dir $n)) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, (Join-Path $dir $n), $n, [IO.Compression.CompressionLevel]::Optimal) }
        }
    } finally { $zip.Dispose() }
}

# unpacks a zip from another computer into an empty folder: only the names of $script:BundleFiles, nothing else, no paths, at most BundleMaxBytes
function Expand-BundleZip([string]$zipPath, [string]$destDir) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $total = 0L
        foreach ($e in $zip.Entries) {
            $name = $script:BundleFiles | Where-Object { $_ -eq $e.FullName } | Select-Object -First 1
            if (-not $name) { throw "The scenario holds a file that is not allowed: $($e.FullName)" }
            $total += $e.Length
            if ($total -gt $script:BundleMaxBytes) { throw 'The scenario is too big.' }
            $in = $e.Open(); $out = [IO.File]::Create((Join-Path $destDir $name))
            try { $in.CopyTo($out) } finally { $out.Close(); $in.Close() }
        }
    } finally { $zip.Dispose() }
}

# the host's side: the bundle in the cache folder $dir as offered in the lobby (Hash, Size and the zip to send)
function New-HostBundle([string]$dir) {
    $zip = Join-Path $env:TEMP ('bar_bundle_' + [Guid]::NewGuid().ToString('N') + '.zip')
    New-BundleZip $dir $zip
    return [pscustomobject]@{ Hash = (Get-BundleHash $dir); Size = (Get-Item $zip).Length; Zip = $zip; Map = $null }
}

# ---------------------------------------------------------------- Update of the editor files
# Which files an update may hold (paths relative to the folder that holds LevelEditor and shared): programs of the editor only, no levels, no scenarios, no
# generated files (start_level_editor.bat is made for each computer)
$script:UpdateNameRx = '^(LevelEditor/(scripts|scenario|scenario/template)/[A-Za-z0-9_\-]+\.(ps1|lua)|LevelEditor/(install_editor|uninstall_editor)\.bat|shared/[A-Za-z0-9_\-]+\.(ps1|lua))$'
$script:UpdateMaxBytes = 16MB

# the files of the editor that an update carries: relative names (with /) and full paths
function Get-UpdateFiles([string]$root) {
    $res = @()
    foreach ($spec in @(@('LevelEditor/scripts', '*.ps1'), @('LevelEditor/scripts', '*.lua'), @('LevelEditor/scenario', '*.ps1'), @('LevelEditor/scenario/template', '*.ps1'),
                        @('LevelEditor/scenario/template', '*.lua'), @('LevelEditor', 'install_editor.bat'), @('LevelEditor', 'uninstall_editor.bat'), @('shared', '*.ps1'), @('shared', '*.lua'))) {
        $dir = Join-Path $root ($spec[0] -replace '/', '\')
        if (-not (Test-Path $dir)) { continue }
        foreach ($f in @(Get-ChildItem $dir -Filter $spec[1] -File)) {
            $rel = $spec[0] + '/' + $f.Name
            if ($rel -cmatch $script:UpdateNameRx) { $res += [pscustomobject]@{ Rel = $rel; Path = $f.FullName } }
        }
    }
    return $res
}

# the host's side: the zip of his editor files; Zip, Size, Hash (SHA-256 of the zip) and Count
function New-HostUpdate([string]$root) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $files = @(Get-UpdateFiles $root)
    if ($files.Count -eq 0) { return $null }
    $zipPath = Join-Path $env:TEMP ('bar_update_' + [Guid]::NewGuid().ToString('N') + '.zip')
    $zip = [IO.Compression.ZipFile]::Open($zipPath, 'Create')
    try { foreach ($f in $files) { [void][IO.Compression.ZipFileExtensions]::CreateEntryFromFile($zip, $f.Path, $f.Rel, [IO.Compression.CompressionLevel]::Optimal) } } finally { $zip.Dispose() }
    return [pscustomobject]@{ Zip = $zipPath; Size = (Get-Item $zipPath).Length; Hash = (Get-FileSha256 $zipPath); Count = $files.Count }
}

# unpacks an update from another computer into an empty folder: only names that match UpdateNameRx, nothing else, at most UpdateMaxBytes
function Expand-UpdateZip([string]$zipPath, [string]$destDir) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $total = 0L
        foreach ($e in $zip.Entries) {
            if ($e.FullName -cnotmatch $script:UpdateNameRx) { throw "The update holds a file that is not allowed: $($e.FullName)" }
            $total += $e.Length
            if ($total -gt $script:UpdateMaxBytes) { throw 'The update is too big.' }
            $target = Join-Path $destDir ($e.FullName -replace '/', '\')
            New-Item -ItemType Directory -Force (Split-Path $target) | Out-Null
            $in = $e.Open(); $out = [IO.File]::Create($target)
            try { $in.CopyTo($out) } finally { $out.Close(); $in.Close() }
        }
    } finally { $zip.Dispose() }
}

# the version (Get-PlayVersion) of the files in an unpacked update
function Get-StagedVersion([string]$stage) {
    return Get-PlayVersion @((Join-Path $stage 'LevelEditor\scripts'), (Join-Path $stage 'LevelEditor\scenario\template'), (Join-Path $stage 'shared'))
}

# fetched zip -> checked and unpacked folder (throws if something is wrong); $hostHash: the version hash of the host, the unpacked files must give it
function Complete-UpdateFetch($f, [string]$hostHash) {
    $f.File.Close(); try { $f.Client.Close() } catch { }
    try {
        if ((Get-FileSha256 $f.Part) -ne $f.Hash) { throw 'The update received is not the one that was offered (the hash is wrong).' }
        $stage = Join-Path (Join-Path $env:LOCALAPPDATA 'BAR-Scenario\Update') $f.Hash.Substring(0, 16)   # (a short name: the paths inside must stay below 260 characters)
        if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
        New-Item -ItemType Directory -Force $stage | Out-Null
        try {
            Expand-UpdateZip $f.Part $stage
            if ((Get-StagedVersion $stage).Hash -ne $hostHash) { throw 'The files of the update do not give the version of the host.' }
        } catch { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue; throw }
        return $stage
    } finally { Remove-Item $f.Part -Force -ErrorAction SilentlyContinue }
}

# which files of the unpacked update differ from the installed ones: Rel (with backslashes), Status 'new' or 'changed'
function Get-UpdateChanges([string]$stage, [string]$root) {
    if (-not $stage -or -not (Test-Path $stage -PathType Container)) { throw 'There is no unpacked update.' }
    if (-not $root -or -not (Test-Path $root -PathType Container)) { throw 'There is no editor folder to update.' }
    $res = @()
    foreach ($f in @(Get-ChildItem $stage -Recurse -File)) {
        $rel = $f.FullName.Substring($stage.Length).TrimStart('\')
        if ((($rel -replace '\\', '/') -cnotmatch $script:UpdateNameRx) -or -not ([IO.Path]::GetFullPath((Join-Path $root $rel))).StartsWith([IO.Path]::GetFullPath($root), [StringComparison]::OrdinalIgnoreCase)) { throw "The update holds a file that is not allowed: $rel" }
        $dest = Join-Path $root $rel
        if (-not (Test-Path $dest)) { $res += [pscustomobject]@{ Rel = $rel; Status = 'new' } }
        elseif ((Get-FileSha256 $dest) -ne (Get-FileSha256 $f.FullName)) { $res += [pscustomobject]@{ Rel = $rel; Status = 'changed' } }
    }
    return $res
}

# replaces the changed files of $root by the ones of the update; the old ones are saved first (%LOCALAPPDATA%\BAR-Scenario\Backup\<time>\); a failure puts everything back.
# Refuses a folder with a .git (a working copy is updated with git). Returns the number of files and the backup folder.
function Install-EditorUpdate([string]$stage, [string]$root) {
    if (Test-Path (Join-Path $root '.git')) { throw 'This folder is a git working copy: update it with git pull, not through the lobby.' }
    $changes = @(Get-UpdateChanges $stage $root)
    $backup = Join-Path (Join-Path $env:LOCALAPPDATA 'BAR-Scenario\Backup') (Get-Date -Format 'yyyyMMdd-HHmmss')
    $done = New-Object Collections.ArrayList
    try {
        foreach ($c in $changes) {
            $dest = Join-Path $root $c.Rel
            if ($c.Status -eq 'changed') {
                $b = Join-Path $backup $c.Rel
                New-Item -ItemType Directory -Force (Split-Path $b) | Out-Null
                Copy-Item $dest $b -Force
            }
            New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
            [void]$done.Add($c)
            Copy-Item (Join-Path $stage $c.Rel) $dest -Force
        }
    } catch {
        $err = $_.Exception.Message
        foreach ($c in $done) {
            $dest = Join-Path $root $c.Rel
            try { if ($c.Status -eq 'changed') { Copy-Item (Join-Path $backup $c.Rel) $dest -Force } else { Remove-Item $dest -Force -ErrorAction SilentlyContinue } } catch { }
        }
        throw "The update could not be installed ($err); the old files were put back."
    }
    return [pscustomobject]@{ Count = $changes.Count; Backup = $backup }
}

# ---------------------------------------------------------------- The cache: looking after it
# What came from other computers or was made for them lives in %LOCALAPPDATA%\BAR-Scenario: Cache\<hash> (scenarios), Cache\Maps\maps (maps), Update\ (unpacked
# updates); Backup\ (files an update replaced) is never touched here.
function Get-DirSize([string]$dir) {
    if (-not (Test-Path $dir)) { return [long]0 }
    $s = (Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    if ($s) { return [long]$s } else { return [long]0 }
}

function Get-UpdateCacheRoot { return (Join-Path (Split-Path (Get-BundleCacheRoot) -Parent) 'Update') }

# Bytes, Bundles and Maps (numbers) of the cache
function Get-CacheInfo {
    $root = Get-BundleCacheRoot
    $bundles = @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue | Where-Object { Test-BundleId $_.Name })
    $maps = @(Get-ChildItem (Join-Path $root 'Maps\maps') -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.sd7' -or $_.Extension -eq '.sdz' })
    return [pscustomobject]@{ Bytes = ((Get-DirSize $root) + (Get-DirSize (Get-UpdateCacheRoot))); Bundles = $bundles.Count; Maps = $maps.Count }
}

# marks something in the cache as used just now (the pruning goes by this time)
function Use-CacheItem([string]$path) { try { (Get-Item $path -Force).LastWriteTime = Get-Date } catch { } }

# Throws away what is not needed any more: scenarios not used for 30 days, maps not used for 60 days and (oldest first) as many more as are needed to stay
# below 3 GB, half-finished downloads and unpacked updates older than a day, zips of hosts that were left in TEMP. Returns the number of bytes freed.
function Remove-OldCache {
    $freed = [long]0
    $now = Get-Date
    $root = Get-BundleCacheRoot
    function Drop($item) { $script:dropped += (Get-DirSize $item.FullName) + $(if (-not $item.PSIsContainer) { $item.Length } else { 0 }); Remove-Item $item.FullName -Recurse -Force -ErrorAction SilentlyContinue }
    $script:dropped = [long]0
    if (Test-Path $root) {
        foreach ($d in @(Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
            if ((Test-BundleId $d.Name) -and ($now - $d.LastWriteTime).TotalDays -gt 30) { Drop $d }
            elseif ($d.Name -match '\.(part|tmp)$' -and ($now - $d.LastWriteTime).TotalDays -gt 1) { Drop $d }
        }
        foreach ($f in @(Get-ChildItem $root -File -Filter '*.part' -ErrorAction SilentlyContinue)) { if (($now - $f.LastWriteTime).TotalDays -gt 1) { Drop $f } }
        $mapDir = Join-Path $root 'Maps\maps'
        if (Test-Path $mapDir) {
            $maps = @(Get-ChildItem $mapDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -eq '.sd7' -or $_.Extension -eq '.sdz' } | Sort-Object LastWriteTime)
            $total = ($maps | Measure-Object -Property Length -Sum).Sum
            foreach ($m in $maps) {
                if (($now - $m.LastWriteTime).TotalDays -gt 60 -or $total -gt 3GB) {
                    $total -= $m.Length
                    Drop $m
                    if (Test-Path ($m.FullName + '.mapinfo')) { Remove-Item ($m.FullName + '.mapinfo') -Force -ErrorAction SilentlyContinue }
                }
            }
        }
    }
    $upd = Get-UpdateCacheRoot
    if (Test-Path $upd) { foreach ($d in @(Get-ChildItem $upd -Directory -ErrorAction SilentlyContinue)) { if (($now - $d.LastWriteTime).TotalDays -gt 1) { Drop $d } } }
    foreach ($f in @(Get-ChildItem $env:TEMP -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -like 'bar_bundle_*.zip' -or $_.Name -like 'bar_update_*.zip' })) { if (($now - $f.LastWriteTime).TotalDays -gt 1) { Drop $f } }
    return $script:dropped
}

# the menu's "clean the cache": everything that came from hosts goes (the scenarios are made again from the levels or fetched again, the maps fetched again)
function Clear-BundleCache {
    $freed = (Get-CacheInfo).Bytes
    foreach ($d in @((Get-BundleCacheRoot), (Get-UpdateCacheRoot))) { if (Test-Path $d) { Get-ChildItem $d -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue } }
    return $freed
}

# ---------------------------------------------------------------- The map from the host
$script:MapMaxBytes = 1GB
# an extra data folder of the engine (SPRING_DATADIR; the maps are in maps inside): maps from hosts stay there and the data folder of the player is not touched
function Get-MapExtraRoot { return (Join-Path (Get-BundleCacheRoot) 'Maps') }

# $true if the address is on this computer or in a subnet of one of its network cards (the same local network); $addr: an address or a name
function Test-SameLan([string]$addr) {
    try {
        $ip = $null
        if (-not [Net.IPAddress]::TryParse($addr, [ref]$ip)) { $ip = [Net.Dns]::GetHostAddresses($addr) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1 }
        if (-not $ip) { return $false }
        if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
        if ([Net.IPAddress]::IsLoopback($ip) -or $ip.AddressFamily -ne 'InterNetwork') { return [Net.IPAddress]::IsLoopback($ip) }
        $o = [BitConverter]::ToUInt32($ip.GetAddressBytes()[3..0], 0)
        foreach ($a in @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue)) {
            if ($a.IPAddress -like '169.254.*' -or $a.PrefixLength -lt 8) { continue }
            $m = [uint32](([uint64]4294967295 -shl (32 - $a.PrefixLength)) -band 4294967295)
            $l = [BitConverter]::ToUInt32(([Net.IPAddress]::Parse($a.IPAddress)).GetAddressBytes()[3..0], 0)
            if (($o -band $m) -eq ($l -band $m)) { return $true }
        }
    } catch { }
    return $false
}

function Test-MapFileName([string]$n) { return (($n -cmatch '^[A-Za-z0-9._() \-]{1,100}\.(sd7|sdz)$') -and ($n -notmatch '\.\.')) }

function Get-FileSha256([string]$path) {
    $fs = [IO.File]::OpenRead($path)
    try { return ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($fs)) -replace '-', '') } finally { $fs.Close() }
}

function Get-ArchiveCacheText([string]$dataDir) {
    $cache = Get-ChildItem (Join-Path $dataDir 'cache') -Filter 'ArchiveCache*.lua' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
    if ($cache) { return [IO.File]::ReadAllText($cache.FullName) }
    return ''
}

# the file of a map in the data folder of the game (found in the archive cache of the engine), $null if there is none
function Find-MapArchive([string]$dataDir, [string]$mapName) {
    $rx = New-Object Text.RegularExpressions.Regex('name = "([^"]+\.(?:sd7|sdz))",\s*path = "([^"]*maps/)",.*?modtype = 3,\s*name = "([^"]+)"', 'Singleline')
    foreach ($m in $rx.Matches((Get-ArchiveCacheText $dataDir))) {
        if ($m.Groups[3].Value -eq $mapName) { $f = Join-Path $m.Groups[2].Value $m.Groups[1].Value; if (Test-Path $f) { return $f } }
    }
    return $null
}

# what the host offers: Name, Path, File, Size and Hash of his map archive, or $null (no archive found, a name or size that cannot be sent)
function Get-HostMap([string]$dataDir, [string]$mapName) {
    $f = Find-MapArchive $dataDir $mapName
    if (-not $f) { return $null }
    $name = Split-Path $f -Leaf
    $len = (Get-Item $f).Length
    if (-not (Test-MapFileName $name) -or $len -gt $script:MapMaxBytes) { return $null }
    return [pscustomobject]@{ Name = $mapName; Path = $f; File = $name; Size = $len; Hash = (Get-FileSha256 $f) }
}

# a map that came from a host: the file in the extra data folder has a small file next to it with the name of the map and the hash
function Test-MapExtra([string]$mapName) {
    $dir = Join-Path (Get-MapExtraRoot) 'maps'
    if (-not (Test-Path $dir)) { return $false }
    foreach ($s in @(Get-ChildItem $dir -Filter '*.mapinfo' -ErrorAction SilentlyContinue)) {
        $l = @(Get-Content $s.FullName)
        if ($l.Count -ge 2 -and $l[0] -eq $mapName -and (Test-Path (Join-Path $dir ($s.Name -replace '\.mapinfo$', '')))) { Use-CacheItem (Join-Path $dir ($s.Name -replace '\.mapinfo$', '')); return $true }
    }
    return $false
}

function Test-MapInstalled([string]$dataDir, [string]$mapName) {
    return ((Get-ArchiveCacheText $dataDir).Contains('name = "' + $mapName + '"') -or (Test-MapExtra $mapName))
}

# the fetched file: check the hash, then into the extra data folder
function Complete-MapFetch($f, [string]$mapName, [string]$file) {
    $f.File.Close(); try { $f.Client.Close() } catch { }
    try {
        if ((Get-FileSha256 $f.Part) -ne $f.Hash) { throw 'The map received is not the one that was offered (the hash is wrong).' }
        $dir = Join-Path (Get-MapExtraRoot) 'maps'
        New-Item -ItemType Directory -Force $dir | Out-Null
        $dest = Join-Path $dir $file
        if (Test-Path $dest) { Remove-Item $dest -Force }
        Move-Item $f.Part $dest
        Set-Content -Path (Join-Path $dir ($file + '.mapinfo')) -Value @($mapName, $f.Hash) -Encoding ASCII
    } finally { Remove-Item $f.Part -Force -ErrorAction SilentlyContinue }
}

# the joiner's side of a transfer: a second connection that fetches the zip of the bundle. Returns the state for Step-BundleFetch / Complete-BundleFetch.
function Start-BundleFetch([string]$ip, [int]$port, [string]$hash, [string]$request = $null, [long]$max = 0) {
    if ($max -le 0) { $max = $script:BundleMaxBytes }
    if (-not $request) { $request = "FETCH $hash" }
    $root = Get-BundleCacheRoot
    New-Item -ItemType Directory -Force $root | Out-Null
    $c = New-Object Net.Sockets.TcpClient
    $ar = $c.BeginConnect($ip, $port, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne(5000)) { $c.Close(); throw 'No connection to the host for the scenario.' }
    $c.EndConnect($ar)
    $b = [Text.Encoding]::UTF8.GetBytes($request + "`n"); $c.GetStream().Write($b, 0, $b.Length)
    $part = Join-Path $root ($hash + '.part')
    return @{ Client = $c; Hash = $hash; Part = $part; File = [IO.File]::Create($part); Total = -1L; Got = 0L; Max = $max; Header = ''; Buf = (New-Object byte[] 262144) }
}

# reads what has arrived: 'working', 'done' or 'error: <reason>'
function Step-BundleFetch($f) {
    try {
        $c = $f.Client; $s = $c.GetStream()
        while ($f.Total -lt 0 -and $c.Available -gt 0) {   # the first line "SIZE <n>"
            $b = $s.ReadByte(); if ($b -lt 0) { break }
            if ($b -eq 10) {
                if ($f.Header -notmatch '^SIZE (\d+)$') { return 'error: the host answered something else' }
                $f.Total = [long]$Matches[1]
                if ($f.Total -gt $f.Max) { return 'error: it is too big' }
            } else {
                $f.Header += [char]$b
                if ($f.Header.Length -gt 40) { return 'error: the host answered something else' }
            }
        }
        if ($f.Total -ge 0) {
            while ($c.Available -gt 0 -and $f.Got -lt $f.Total) {
                $n = $s.Read($f.Buf, 0, [int][Math]::Min($f.Buf.Length, $f.Total - $f.Got))
                if ($n -le 0) { break }
                $f.File.Write($f.Buf, 0, $n); $f.Got += $n
            }
            if ($f.Got -ge $f.Total) { return 'done' }
        }
        if ($c.Available -eq 0 -and $c.Client.Poll(0, [Net.Sockets.SelectMode]::SelectRead)) { return 'error: the host closed the connection' }
        return 'working'
    } catch { return 'error: ' + $_.Exception.Message }
}

# gives up a fetch (error, leaving): closes the connection and the file and throws the half-finished file away
function Close-Fetch($f) {
    if (-not $f) { return }
    try { $f.File.Close() } catch { }
    try { $f.Client.Close() } catch { }
    Remove-Item $f.Part -Force -ErrorAction SilentlyContinue
}

# unpacks and checks what was fetched and puts it into the cache; returns the folder (throws if something is wrong)
function Complete-BundleFetch($f) {
    $f.File.Close(); try { $f.Client.Close() } catch { }
    $root = Get-BundleCacheRoot
    $tmp = Join-Path $root ($f.Hash + '.tmp')
    if (Test-Path $tmp) { Remove-Item $tmp -Recurse -Force }
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        Expand-BundleZip $f.Part $tmp
        if ((Get-BundleHash $tmp) -ne $f.Hash) { throw 'The scenario received is not the one that was offered (the hash is wrong).' }
    } catch { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue; throw } finally { Remove-Item $f.Part -Force -ErrorAction SilentlyContinue }
    $dest = Join-Path $root $f.Hash
    if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
    Move-Item $tmp $dest
    Set-Content -Path (Join-Path $dest 'complete.txt') -Value 'complete' -Encoding ASCII
    return $dest
}

function New-LobbyState($teamInfo, [string]$hostName, [int]$port, $version = $null, $bundle = $null, [string]$updateRoot = $null) {
    return @{ Teams = @($teamInfo); HostName = $hostName; Port = $port; Version = $version; Bundle = $bundle; Transfers = (New-Object Collections.ArrayList); UpdateRoot = $updateRoot; Update = $null; Addr = ''; Players = (New-Object Collections.ArrayList); Pending = (New-Object Collections.ArrayList)
              Focus = @($teamInfo).Count; Cursor = 0; Held = $null; HeldFrom = 0; Msg = ''; Info = ''; ConfirmCancel = $false; Dirty = $true; Done = $null }
}

function Get-BoxPlayers($st, [int]$box) { return @($st.Players | Where-Object { $_.Box -eq $box }) }

# The team of a new player: the one of the last mapping (by name) if nobody is there, otherwise the first team without a player, otherwise team 0
function Add-LobbyPlayer($st, [string]$name, $client, [string]$verState = 'same', [string]$data = 'ready', [string]$map = 'ready') {
    $box = -1
    foreach ($e in @(Read-LastMapping)) {
        if ($e.Name.ToLower() -eq $name.ToLower() -and $e.Team -lt $st.Teams.Count -and @(Get-BoxPlayers $st $e.Team).Count -eq 0) { $box = $e.Team }
    }
    if ($box -lt 0) {
        for ($b = 0; $b -lt $st.Teams.Count; $b++) { if (@(Get-BoxPlayers $st $b).Count -eq 0) { $box = $b; break } }
    }
    if ($box -lt 0) { $box = 0 }
    $p = [pscustomobject]@{ Name = $name; Box = $box; Client = $client; Buf = (New-Object Text.StringBuilder); Sent = ''; Closed = $false; VerState = $verState; Data = $data; Pct = 0; Map = $map; MapPct = 0; MapGrant = $false }
    [void]$st.Players.Add($p)
    $st.Dirty = $true
    return $p
}

function Remove-LobbyPlayer($st, $p) {
    if ($p.Client) { try { $p.Client.Close() } catch { } }
    $st.Players.Remove($p)
    if ($st.Held -eq $p) { $st.Held = $null }
    $st.Dirty = $true
}

# $null if the game can start, otherwise the reason
function Test-LobbyStart($st) {
    if ($st.Players.Count -lt 2) { return 'At least two players are needed.' }
    foreach ($p in $st.Players) {
        if ($p.VerState -ne 'same') { return ('{0} has {1} files than yours.' -f $p.Name, $(switch ($p.VerState) { 'older' { 'older' } 'newer' { 'newer' } default { 'other' } })) }
    }
    foreach ($p in $st.Players) { if ($p.Data -ne 'ready') { return ('{0} has not loaded the scenario yet.' -f $p.Name) } }
    foreach ($p in $st.Players) { if ($p.Map -ne 'ready') { return ('{0} has no map yet.' -f $p.Name) } }
    return $null
}

# the players as "Name=Team" entries, the host first
function Get-LobbyRoster($st) {
    $res = @()
    foreach ($p in $st.Players) { $res += [pscustomobject]@{ Name = $p.Name; Team = $p.Box } }
    return $res
}

function Move-LobbyHeld($st, [int]$dir) {
    $nb = [Math]::Max(0, [Math]::Min($st.Teams.Count - 1, $st.Held.Box + $dir))
    if ($nb -eq $st.Held.Box) { return }
    $st.Held.Box = $nb
    $st.Focus = $nb
    $st.Cursor = [Math]::Max(0, @(Get-BoxPlayers $st $nb).IndexOf($st.Held))
}

function Invoke-LobbyKey($st, $k) {
    $startBox = $st.Teams.Count   # the boxes are the teams 0 .. n-1, then "Start game"
    $st.Dirty = $true
    if ($st.ConfirmCancel) {
        if ($k.Key -eq 'Escape') { $st.Done = 'cancel'; return }
        $st.ConfirmCancel = $false
    }
    $st.Msg = ''
    if ($st.Held) {
        switch ($k.Key) {
            'UpArrow'    { Move-LobbyHeld $st -1 }
            'LeftArrow'  { Move-LobbyHeld $st -1 }
            'DownArrow'  { Move-LobbyHeld $st 1 }
            'RightArrow' { Move-LobbyHeld $st 1 }
            'Enter'      { $st.Held = $null }
            'Escape'     { $st.Held.Box = $st.HeldFrom; $st.Focus = $st.HeldFrom; $st.Held = $null }
        }
        return
    }
    $n = @(Get-BoxPlayers $st $st.Focus).Count
    switch ($k.Key) {
        'Tab' {
            if ($k.Modifiers -band [ConsoleModifiers]::Shift) { $st.Focus = ($st.Focus + $startBox) % ($startBox + 1) } else { $st.Focus = ($st.Focus + 1) % ($startBox + 1) }
            $st.Cursor = 0
        }
        'RightArrow' { $st.Focus = ($st.Focus + 1) % ($startBox + 1); $st.Cursor = 0 }
        'LeftArrow'  { $st.Focus = ($st.Focus + $startBox) % ($startBox + 1); $st.Cursor = 0 }
        'UpArrow'    { if ($st.Cursor -gt 0) { $st.Cursor-- } }
        'DownArrow'  { if ($st.Cursor -lt $n - 1) { $st.Cursor++ } }
        'Enter' {
            if ($st.Focus -eq $startBox) { $why = Test-LobbyStart $st; if ($why) { $st.Msg = $why } else { $st.Done = 'start' } }
            elseif ($n -gt 0) {
                $st.Held = @(Get-BoxPlayers $st $st.Focus)[[Math]::Min($st.Cursor, $n - 1)]
                $st.HeldFrom = $st.Focus
            }
        }
        'F5' { $why = Test-LobbyStart $st; if ($why) { $st.Msg = $why } else { $st.Done = 'start' } }
        'Escape' { $st.ConfirmCancel = $true; $st.Msg = 'Press Esc again to cancel the lobby (any other key goes on).' }
    }
}

# the screen as lines with a kind each: 0 normal, 1 title, 2 dim, 3 focused, 4 chosen player, 5 player in the hand, 6 note, 7 green
function Get-LobbyLines($st) {
    $lines = New-Object Collections.ArrayList
    $kinds = New-Object Collections.ArrayList
    function Add-L([string]$s, [int]$k) { [void]$lines.Add($s); [void]$kinds.Add($k) }
    $t = $st.Teams.Count
    # free lines between the boxes: two if the window is high enough, then one, then none
    $need = 2 + 4; foreach ($bx in 0..($t - 1)) { $need += 1 + [Math]::Max(1, @(Get-BoxPlayers $st $bx).Count) }
    $winH = 40; try { $winH = [Console]::WindowHeight } catch { }
    $gap = 2; while ($gap -gt 0 -and ($need + $gap * $t) -gt $winH - 2) { $gap-- }
    Add-L ("Lobby of {0}   address {1}   port {2}   {3} player(s)" -f $st.HostName, $st.Addr, $st.Port, $st.Players.Count) 1
    if ($st.Version) { Add-L ('Version {0} of {1} (UTC)' -f $st.Version.Short, (Format-PlayDate $st.Version.Date)) 2 } else { Add-L '' 0 }
    Add-L '' 0
    for ($b = 0; $b -lt $t; $b++) {
        Add-L ('{0} {1}' -f $(if ($st.Focus -eq $b) { '>' } else { ' ' }), $st.Teams[$b]) $(if ($st.Focus -eq $b) { 3 } else { 1 })
        $pl = @(Get-BoxPlayers $st $b)
        if ($pl.Count -eq 0) { Add-L '      (empty)' 2 }
        for ($i = 0; $i -lt $pl.Count; $i++) {
            $p = $pl[$i]
            $txt = '    ' + $p.Name + $(if ($p.Client -eq $null) { '  (host)' } else { '' })
            if ($p.VerState -ne 'same') { $txt += '   (files ' + $(switch ($p.VerState) { 'older' { 'older than yours: needs an update' } 'newer' { 'newer than yours' } default { 'differ from yours' } }) + ')' }
            if ($p.Data -eq 'ready' -and $p.Map -ne 'ready') { $txt += $(if ($p.Map -eq 'loading') { "   (loading the map from you: $($p.MapPct) %)" } else { '   (getting the map)' }) }
            if ($p.Data -ne 'ready') { $txt += $(if ($p.Data -eq 'loading') { "   (loading the scenario: $($p.Pct) %)" } else { '   (scenario not loaded yet)' }) }
            $kind = 0
            if ($st.Held -eq $p) { $txt += '   <- moving: arrows move, Enter drops, Esc puts back'; $kind = 5 }
            elseif ($st.Focus -eq $b -and [Math]::Min($st.Cursor, $pl.Count - 1) -eq $i) { $txt = '  > ' + $txt.Substring(4); $kind = 4 }
            Add-L $txt $kind
        }
        for ($g = 0; $g -lt $gap; $g++) { Add-L '' 0 }
    }
    $why = Test-LobbyStart $st
    Add-L ('{0} [ Start game ]{1}' -f $(if ($st.Focus -eq $t) { '>' } else { ' ' }), $(if ($why) { '   ' + $why } else { '   ready' })) $(if ($st.Focus -eq $t) { 3 } elseif ($why) { 2 } else { 7 })
    Add-L '' 0
    if ($st.Msg) { Add-L $st.Msg 6 }
    if ($st.Info) { Add-L $st.Info 2 }
    Add-L 'Tab/Left/Right = box, Up/Down = player, Enter = pick up/drop, F5 = start, Esc x2 = cancel' 2
    return [pscustomobject]@{ Lines = @($lines); Kinds = @($kinds) }
}

function Show-LobbyLines($screen) {
    $w = [Math]::Max(20, [Console]::WindowWidth - 1)
    [Console]::SetCursorPosition(0, 0)
    $fg0 = [Console]::ForegroundColor; $bg0 = [Console]::BackgroundColor
    for ($i = 0; $i -lt $screen.Lines.Count; $i++) {
        $s = $screen.Lines[$i]; if ($s.Length -gt $w) { $s = $s.Substring(0, $w) }
        switch ($screen.Kinds[$i]) {
            1 { [Console]::ForegroundColor = 'Cyan' }
            2 { [Console]::ForegroundColor = 'DarkGray' }
            3 { [Console]::ForegroundColor = 'Black'; [Console]::BackgroundColor = 'Gray' }
            4 { [Console]::ForegroundColor = 'Black'; [Console]::BackgroundColor = 'Cyan' }
            5 { [Console]::ForegroundColor = 'Black'; [Console]::BackgroundColor = 'Yellow' }
            6 { [Console]::ForegroundColor = 'Yellow' }
            7 { [Console]::ForegroundColor = 'Green' }
        }
        [Console]::Write($s.PadRight($w))
        [Console]::ForegroundColor = $fg0; [Console]::BackgroundColor = $bg0
        [Console]::Write("`n")
    }
    # clear what an older, longer screen left below
    for ($j = 0; $j -lt 3; $j++) { [Console]::Write(''.PadRight($w) + "`n") }
}

function Send-LobbyLine($p, [string]$line) {
    if ($p.Closed -or -not $p.Client) { return }
    try { $b = [Text.Encoding]::UTF8.GetBytes($line + "`n"); $p.Client.GetStream().Write($b, 0, $b.Length) } catch { $p.Closed = $true }
}

function Read-LobbyLines($p) {
    $res = @()
    try {
        $c = $p.Client
        while ($c.Available -gt 0) {
            $buf = New-Object byte[] 4096
            $n = $c.GetStream().Read($buf, 0, $buf.Length)
            if ($n -le 0) { break }
            [void]$p.Buf.Append([Text.Encoding]::UTF8.GetString($buf, 0, $n))
        }
        $txt = $p.Buf.ToString()
        $i = $txt.IndexOf("`n")
        while ($i -ge 0) {
            $res += $txt.Substring(0, $i).Trim()
            $txt = $txt.Substring($i + 1)
            $i = $txt.IndexOf("`n")
        }
        [void]$p.Buf.Clear(); [void]$p.Buf.Append($txt)
        if ($c.Client.Poll(0, [Net.Sockets.SelectMode]::SelectRead) -and $c.Available -eq 0) { $p.Closed = $true }
    } catch { $p.Closed = $true }
    return $res
}

# a joiner's second connection ("FETCH <hash>") gets the zip of the bundle: first the line "SIZE <n>", then the n bytes (sent in pieces by Update-LobbyTransfers)
function Start-LobbyTransfer($st, $q, [string]$line) {
    try {
        $w = @($line -split ' ')
        if ($w[0] -eq 'FETCH' -and $st.Bundle -and $w[1] -eq $st.Bundle.Hash) { $path = $st.Bundle.Zip; $size = $st.Bundle.Size }
        elseif ($w[0] -eq 'FETCHMAP' -and $st.Bundle -and $st.Bundle.Map -and $w[1] -eq $st.Bundle.Map.Hash -and $w.Count -ge 3 -and
                @($st.Players | Where-Object { $_.Name -eq $w[2] -and $_.MapGrant }).Count -gt 0) { $path = $st.Bundle.Map.Path; $size = $st.Bundle.Map.Size }
        elseif ($w[0] -eq 'FETCHUPDATE' -and $st.Update -and $w[1] -eq $st.Update.Hash) { $path = $st.Update.Zip; $size = $st.Update.Size }
        else { throw 'not offered' }
        $b = [Text.Encoding]::UTF8.GetBytes(('SIZE {0}' -f $size) + "`n")
        $s = $q.Client.GetStream(); $s.Write($b, 0, $b.Length)
        [void]$st.Transfers.Add(@{ Client = $q.Client; Stream = $s; File = [IO.File]::OpenRead($path); Total = $size; Sent = 0L; Task = $null; Last = 0; Buf = (New-Object byte[] 262144) })
    } catch { try { $q.Client.Close() } catch { } }
}

# one piece at a time per transfer, without waiting for a slow joiner
function Update-LobbyTransfers($st) {
    foreach ($t in @($st.Transfers)) {
        $done = $false
        try {
            if ($t.Task) {
                if (-not $t.Task.IsCompleted) { continue }
                if ($t.Task.IsFaulted -or $t.Task.IsCanceled) { throw 'write failed' }
                $t.Sent += $t.Last; $t.Task = $null
            }
            if ($t.Sent -ge $t.Total) { $done = $true }
            else {
                $n = $t.File.Read($t.Buf, 0, $t.Buf.Length)
                if ($n -le 0) { $done = $true } else { $t.Last = $n; $t.Task = $t.Stream.WriteAsync($t.Buf, 0, $n) }
            }
        } catch { $done = $true }
        if ($done) { try { $t.File.Close(); $t.Client.Close() } catch { }; [void]$st.Transfers.Remove($t) }
    }
}

# accepts new connections, reads the lines of everybody, drops the ones that went away and tells the joiners where they are
function Update-LobbyNet($st, $listener) {
    while ($listener.Pending()) {
        $c = $listener.AcceptTcpClient()
        [void]$st.Pending.Add([pscustomobject]@{ Client = $c; Buf = (New-Object Text.StringBuilder); Closed = $false; Name = $null; T = (Get-Date); VerHash = $null; VerDate = $null })
    }
    foreach ($q in @($st.Pending)) {
        $hello = $null; $fetch = $null
        foreach ($l in @(Read-LobbyLines $q)) {
            if ($l -like 'HELLO *') { $hello = $l.Substring(6).Trim() }
            elseif ($l -like 'FETCH *' -or $l -like 'FETCHMAP *' -or $l -like 'FETCHUPDATE *') { $fetch = $l.Trim() }
            elseif ($l -like 'VERSION *') { $v = @($l.Substring(8).Trim() -split ' '); $q.VerHash = $v[0]; if ($v.Count -gt 1) { $q.VerDate = $v[1] } }
        }
        if ($fetch) { Start-LobbyTransfer $st $q $fetch; [void]$st.Pending.Remove($q); continue }
        if ($hello) {
            $nm = ConvertTo-PlayerName $hello
            $taken = @($st.Players | Where-Object { $_.Name.ToLower() -eq $nm.ToLower() }).Count -gt 0
            if (-not $nm) { Send-LobbyLine $q 'ERR The name has no usable letters.'; $q.Closed = $true }
            elseif ($taken) { Send-LobbyLine $q 'ERR That name is used already.'; $q.Closed = $true }
            else {
                Send-LobbyLine $q "OK $nm"
                $vs = 'same'
                if ($st.Version) {
                    Send-LobbyLine $q ('VERSION {0} {1}' -f $st.Version.Hash, $st.Version.Date)
                    $vs = if ($q.VerHash) { Compare-PlayVersion $st.Version $q.VerHash $q.VerDate } else { 'differs' }
                    # older files (or other ones with the same date): the host offers his editor files if he runs from a folder that has them
                    if (($vs -eq 'older' -or $vs -eq 'differs') -and $st.UpdateRoot -and -not $st.Update) {
                        try { $st.Update = New-HostUpdate $st.UpdateRoot } catch { $st.Update = $null }
                    }
                    if (($vs -eq 'older' -or $vs -eq 'differs') -and $st.Update) { Send-LobbyLine $q ('UPDATE {0} {1} {2}' -f $st.Update.Size, $st.Update.Hash, $st.Update.Count) }
                }
                $dataState = 'ready'; $mapState = 'ready'
                if ($st.Bundle) {
                    $dataState = 'wait'; $mapState = 'missing'
                    if ($vs -eq 'same') {
                        Send-LobbyLine $q ('OFFER {0} {1}' -f $st.Bundle.Hash, $st.Bundle.Size)
                        if ($st.Bundle.Map) { Send-LobbyLine $q ('MAP {0} {1} {2}' -f $st.Bundle.Map.Size, $st.Bundle.Map.Hash, $st.Bundle.Map.File) }
                    }
                }
                [void](Add-LobbyPlayer $st $nm $q.Client $vs $dataState $mapState)
                $st.Info = "$nm joined."
                [void]$st.Pending.Remove($q)
                continue
            }
        }
        if ($q.Closed -or ((Get-Date) - $q.T).TotalSeconds -gt 10) { try { $q.Client.Close() } catch { }; [void]$st.Pending.Remove($q) }
    }
    $roster = (@($st.Players | ForEach-Object { '{0}={1}' -f $_.Name, $_.Box }) -join ';')
    foreach ($p in @($st.Players)) {
        if (-not $p.Client) { continue }
        foreach ($l in @(Read-LobbyLines $p)) {
            if ($l -eq 'BYE') { $p.Closed = $true }
            elseif ($l -like 'HAVE *' -and $st.Bundle -and $l.Substring(5).Trim() -eq $st.Bundle.Hash) { $p.Data = 'ready'; $st.Dirty = $true }
            elseif ($l -eq 'MAPOK') { $p.Map = 'ready'; $st.Dirty = $true }
            elseif ($l -eq 'MAPREQ' -and $st.Bundle -and $st.Bundle.Map -and $p.Map -ne 'ready') {
                # nothing is asked: a joiner of the same network gets the map, one from outside has to download it from the internet
                if (Test-SameLan ([string]$p.Client.Client.RemoteEndPoint.Address)) { $p.MapGrant = $true; $p.Map = 'loading'; $p.MapPct = 0; Send-LobbyLine $p 'MAPYES'; $st.Info = "The map goes to $($p.Name)." }
                else { Send-LobbyLine $p 'MAPNO' }
                $st.Dirty = $true
            }
            elseif ($l -like 'MAPPROGRESS *') { $pc = 0; if ([int]::TryParse($l.Substring(12).Trim(), [ref]$pc) -and $p.Map -eq 'loading') { $p.MapPct = $pc; $st.Dirty = $true } }
            elseif ($l -like 'PROGRESS *') { $pc = 0; if ([int]::TryParse($l.Substring(9).Trim(), [ref]$pc) -and $p.Data -ne 'ready') { $p.Pct = $pc; $p.Data = 'loading'; $st.Dirty = $true } }
        }
        if ($p.Closed) { $st.Info = "$($p.Name) left."; Remove-LobbyPlayer $st $p; continue }
        $state = ('TEAM {0} {1}' -f $p.Box, $st.Teams[$p.Box]) + '|' + $roster
        if ($state -ne $p.Sent) { Send-LobbyLine $p ('TEAM {0} {1}' -f $p.Box, $st.Teams[$p.Box]); Send-LobbyLine $p "ROSTER $roster"; $p.Sent = $state }
    }
    Update-LobbyTransfers $st
}

function New-LobbyKey([string]$key, [switch]$Shift) {
    $ch = switch ($key) { 'Enter' { [char]13 } 'Tab' { [char]9 } 'Escape' { [char]27 } default { [char]0 } }
    return New-Object ConsoleKeyInfo($ch, [ConsoleKey]$key, [bool]$Shift, $false, $false)
}

# The lobby of the host. Returns the roster (entries Name, Team; host first) when the host starts, $null when he cancels.
# $keyFeed (tests): keys (ConsoleKeyInfo) and numbers (wait in milliseconds) are used instead of the keyboard; $dumpFile: the last screen is written
# there instead of the console (no console needed); $timeoutSec: ends with a cancel after this time
function Invoke-HostLobby($teamInfo, [string]$hostName, [int]$port = 8453, $keyFeed = $null, [string]$dumpFile = $null, [int]$timeoutSec = 0, [int]$autoStart = 0, $version = $null, $bundle = $null, [string]$updateRoot = $null) {
    $st = New-LobbyState $teamInfo $hostName $port $version $bundle $updateRoot
    $addr = @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -notlike '127.*' -and $_.IPAddress -notlike '169.254.*' } | ForEach-Object { $_.IPAddress })
    $st.Addr = if ($addr.Count -gt 0) { $addr -join ' / ' } else { '127.0.0.1' }
    $listener = New-Object Net.Sockets.TcpListener([Net.IPAddress]::Any, $port)
    $listener.Start()
    [void](Add-LobbyPlayer $st $hostName $null)
    $console = -not $dumpFile
    $feed = @($keyFeed); $fi = 0; $nextFeed = Get-Date
    $until = if ($timeoutSec -gt 0) { (Get-Date).AddSeconds($timeoutSec) } else { [DateTime]::MaxValue }
    $autoAt = $null
    try {
        if ($console) { Clear-Host; [Console]::CursorVisible = $false }
        while (-not $st.Done) {
            Update-LobbyNet $st $listener
            $k = $null
            if ($keyFeed) {
                if ($fi -lt $feed.Count -and (Get-Date) -ge $nextFeed) {
                    $item = $feed[$fi]; $fi++
                    if ($item -is [int]) { $nextFeed = (Get-Date).AddMilliseconds($item) } else { $k = $item; $nextFeed = (Get-Date).AddMilliseconds(100) }
                }
            } elseif ($console -and [Console]::KeyAvailable) { $k = [Console]::ReadKey($true) }
            if ($k) { Invoke-LobbyKey $st $k }
            if ((Get-Date) -gt $until) { $st.Done = 'cancel' }
            if ($autoStart -gt 0 -and $st.Players.Count -ge $autoStart -and -not (Test-LobbyStart $st)) {
                if (-not $autoAt) { $autoAt = (Get-Date).AddSeconds(2) } elseif ((Get-Date) -gt $autoAt) { $st.Done = 'start' }  # test / automation: starts by itself when this many players are in
            }
            if ($st.Dirty) {
                $st.Dirty = $false
                $screen = Get-LobbyLines $st
                if ($console) { Show-LobbyLines $screen } else { [IO.File]::WriteAllLines($dumpFile, [string[]]$screen.Lines) }
            }
            Start-Sleep -Milliseconds 40
        }
        $final = if ($st.Done -eq 'start') { 'START' } else { 'CANCEL' }
        foreach ($p in $st.Players) { Send-LobbyLine $p $final }
        if ($st.Done -eq 'start') {
            $script:LobbyPlayers = $st.Players   # the connections stay open: READY and GO follow
            if ($console) { Clear-Host }
            return @(Get-LobbyRoster $st)
        }
        Start-Sleep -Milliseconds 200
        return $null
    } finally {
        if ($st.Done -ne 'start') { foreach ($p in $st.Players) { if ($p.Client) { try { $p.Client.Close() } catch { } } } }
        $listener.Stop()
        foreach ($t in @($st.Transfers)) { try { $t.File.Close(); $t.Client.Close() } catch { } }
        # the zips that were made for the joiners
        if ($st.Update) { Remove-Item $st.Update.Zip -Force -ErrorAction SilentlyContinue }
        if ($st.Bundle -and $st.Bundle.Zip) { Remove-Item $st.Bundle.Zip -Force -ErrorAction SilentlyContinue }
        if ($console) { [Console]::CursorVisible = $true }
    }
}

# After the start: waits until every joiner has said READY (extra game built, map there). $false if somebody went away or the time is over.
function Wait-LobbyReady([int]$timeoutSec = 300) {
    $remote = @($script:LobbyPlayers | Where-Object { $_.Client })
    $ready = @{}
    $until = (Get-Date).AddSeconds($timeoutSec)
    $shown = ''
    while ($ready.Count -lt $remote.Count) {
        foreach ($p in $remote) {
            foreach ($l in @(Read-LobbyLines $p)) { if ($l -eq 'READY') { $ready[$p.Name] = $true } }
            if ($p.Closed -and -not $ready.ContainsKey($p.Name)) { Write-Host "$($p.Name) went away." -ForegroundColor Yellow; return $false }
        }
        $waiting = (@($remote | Where-Object { -not $ready.ContainsKey($_.Name) } | ForEach-Object { $_.Name }) -join ', ')
        if ($waiting -ne $shown) { $shown = $waiting; if ($waiting) { Write-Host "Waiting for $waiting to get ready (extra game, map) ..." } }
        if ((Get-Date) -gt $until) { Write-Host "Timeout: $waiting did not get ready." -ForegroundColor Yellow; return $false }
        Start-Sleep -Milliseconds 100
    }
    return $true
}

# the host's game is running: the joiners may connect now
function Send-LobbyGo { foreach ($p in $script:LobbyPlayers) { Send-LobbyLine $p 'GO' } }

function Close-Lobby {
    foreach ($p in $script:LobbyPlayers) { if ($p.Client) { try { Send-LobbyLine $p 'CANCEL'; $p.Client.Close() } catch { } } }
    $script:LobbyPlayers = @()
}

# The lobby of a joiner. Returns 'start', 'cancel' (the host cancelled), 'lost' (the host went away), 'left' (Esc), 'update' (the joiner agreed to the update of
# his editor files: the unpacked update is in $script:UpdateStage, Install-EditorUpdate puts it in place), 'refused: <reason>' or 'noconnect'.
# $dumpFile / $timeoutSec: for tests like above
function Join-Lobby([string]$ip, [int]$port, [string]$name, [int]$timeoutSec = 0, [string]$dumpFile = $null, $version = $null, $mapCtx = $null) {
    $c = New-Object Net.Sockets.TcpClient
    $ar = $c.BeginConnect($ip, $port, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne(5000)) { $c.Close(); return 'noconnect' }
    try { $c.EndConnect($ar) } catch { $c.Close(); return 'noconnect' }
    $p = [pscustomobject]@{ Name = $name; Box = 0; Client = $c; Buf = (New-Object Text.StringBuilder); Sent = ''; Closed = $false }
    $script:JoinerLobby = $p; $script:JoinerName = $name
    if ($version) { Send-LobbyLine $p ('VERSION {0} {1}' -f $version.Hash, $version.Date) }
    Send-LobbyLine $p "HELLO $name"
    $console = -not $dumpFile
    $status = 'connecting ...'; $team = '-'; $roster = ''; $result = $null; $verText = ''; $verKind = 0
    $dataText = ''; $dataKind = 0; $fetch = $null; $lastPct = -10; $script:BundleDir = $null
    $verCmp = ''; $hostVerHash = ''; $updInfo = $null; $updState = ''; $updFetch = $null; $updStage = $null; $updLines = @(); $updAutoUsed = 0; $updLastPct = -10; $updChanges = @(); $updNote = ''; $updShown = $false
    $mapText = ''; $mapKind = 0; $mapState = ''; $mapName = ''; $mapInfo = $null; $mapFetch = $null; $mapKey = $null; $mapAutoUsed = $false; $mapLastPct = -10; $mapChosen = $false; $sameLan = Test-SameLan $ip
    $until = if ($timeoutSec -gt 0) { (Get-Date).AddSeconds($timeoutSec) } else { [DateTime]::MaxValue }
    $dirty = $true
    try {
        if ($console) { Clear-Host; [Console]::CursorVisible = $false }
        while (-not $result) {
            foreach ($l in @(Read-LobbyLines $p)) {
                $dirty = $true
                if ($l -eq 'OK' -or $l -like 'OK *') { $status = 'waiting for the host to start the game'; if ($l.Length -gt 3) { $script:JoinerName = $l.Substring(3).Trim() } }
                elseif ($l -like 'ERR *') { $result = 'refused: ' + $l.Substring(4) }
                elseif ($l -like 'VERSION *' -and $version) {
                    $v = @($l.Substring(8).Trim() -split ' ')
                    # the host's files seen from here: 'older' means the host is older than I am
                    $cmp = Compare-PlayVersion $version $v[0] $(if ($v.Count -gt 1) { $v[1] } else { '' })
                    $verText = switch ($cmp) {
                        'same'   { 'Files: the same as on the host (' + $version.Short + ')' }
                        'older'  { 'Files: NEWER than on the host - the host has to update (yours ' + $version.Short + ' of ' + (Format-PlayDate $version.Date) + ', his ' + $v[0].Substring(0, 8) + ' of ' + (Format-PlayDate $v[1]) + ')' }
                        'newer'  { 'Files: OLDER than on the host - you need an update (yours ' + $version.Short + ' of ' + (Format-PlayDate $version.Date) + ', his ' + $v[0].Substring(0, 8) + ' of ' + (Format-PlayDate $v[1]) + ')' }
                        default  { 'Files: different from the host (yours ' + $version.Short + ', his ' + $v[0].Substring(0, 8) + ')' }
                    }
                    $verKind = if ($cmp -eq 'same') { 7 } else { 6 }
                    $verCmp = $cmp; $hostVerHash = $v[0]
                }
                elseif ($l -like 'UPDATE *') {
                    $o = @($l.Substring(7).Trim() -split ' ')
                    if ($o.Count -ge 3 -and (Test-BundleId $o[1]) -and [long]$o[0] -le $script:UpdateMaxBytes -and ($verCmp -eq 'newer' -or $verCmp -eq 'differs')) {
                        $updInfo = @{ Size = [long]$o[0]; Hash = $o[1]; Count = $o[2] }; $updState = 'offer'; $dirty = $true
                    }
                }
                elseif ($l -like 'MAP *') {
                    $o = @($l.Substring(4).Trim() -split ' ', 3)
                    if ($o.Count -eq 3 -and (Test-BundleId $o[1]) -and (Test-MapFileName $o[2]) -and [long]$o[0] -le $script:MapMaxBytes) { $mapInfo = @{ Size = [long]$o[0]; Hash = $o[1]; File = $o[2] } }
                }
                elseif ($l -eq 'MAPYES' -and $mapState -eq 'waithost' -and $mapInfo) {
                    try { $mapFetch = Start-BundleFetch $ip $port $mapInfo.Hash ('FETCHMAP {0} {1}' -f $mapInfo.Hash, $script:JoinerName) $script:MapMaxBytes; $mapState = 'fetching'; $mapText = "Map: loading ..."; $mapKind = 6 }
                    catch { $mapState = 'prompt'; $mapText = 'Map: no connection for the map. ' }
                }
                elseif ($l -eq 'MAPNO' -and $mapState -eq 'waithost') { $mapState = 'prompt'; $mapText = 'Map: the host did not send it. '; $mapChosen = $true }
                elseif ($l -like 'OFFER *') {
                    $o = @($l.Substring(6).Trim() -split ' ')
                    if (-not (Test-BundleId $o[0]) -or $o.Count -lt 2 -or [long]$o[1] -gt $script:BundleMaxBytes) { $result = 'refused: the host offered a scenario that cannot be taken' }
                    elseif (Test-BundleCached $o[0]) {
                        $script:BundleDir = Join-Path (Get-BundleCacheRoot) $o[0]
                        Send-LobbyLine $p ('HAVE ' + $o[0]); $dataText = 'Scenario: already there (cache ' + $o[0].Substring(0, 8) + ')'; $dataKind = 7
                    } else {
                        try { $fetch = Start-BundleFetch $ip $port $o[0]; $dataText = 'Scenario: loading ...'; $dataKind = 6 }
                        catch { $result = 'refused: ' + $_.Exception.Message }
                    }
                }
                elseif ($l -like 'TEAM *') { $team = ($l.Substring(5) -replace '^\d+ ', '') }
                elseif ($l -like 'ROSTER *') { $roster = $l.Substring(7) }
                elseif ($l -eq 'START') { $result = 'start' }
                elseif ($l -eq 'CANCEL') { $result = 'cancel' }
            }
            if (-not $result -and $fetch) {
                $r = Step-BundleFetch $fetch
                if ($r -eq 'done') {
                    try { $script:BundleDir = Complete-BundleFetch $fetch; Send-LobbyLine $p ('HAVE ' + $fetch.Hash); $dataText = 'Scenario: loaded (' + $fetch.Hash.Substring(0, 8) + ')'; $dataKind = 7 }
                    catch { $result = 'refused: ' + $_.Exception.Message }
                    $fetch = $null; $dirty = $true
                } elseif ($r -ne 'working') { Close-Fetch $fetch; $fetch = $null; $result = 'refused: scenario - ' + $r; $dirty = $true }
                elseif ($fetch.Total -gt 0) {
                    $pct = [int][Math]::Floor(100 * $fetch.Got / $fetch.Total)
                    if ($pct -ne $lastPct) {
                        $dataText = 'Scenario: loading {0} % ({1} of {2} KB)' -f $pct, [int]($fetch.Got / 1024), [int]($fetch.Total / 1024); $dirty = $true
                        if ($pct -ge $lastPct + 5 -or $pct -ge 100) { Send-LobbyLine $p "PROGRESS $pct"; $lastPct = $pct }
                    }
                }
            }
            # the update of the editor files: U fetches it (nothing is replaced yet), then the changed files are shown and Y installs them
            if (-not $result -and $updState -eq 'offer') {
                $canUpdate = $mapCtx -and $mapCtx.UpdateRoot
                if (-not $updShown) {
                    $updLines = @(if ($updNote) { $updNote })
                    $updLines += $(if ($canUpdate) { @('Your files are older than the host''s (' + $updInfo.Count + ' files, ' + [Math]::Round($updInfo.Size / 1KB) + ' KB).', 'U = get the update from the host: it is only looked at first, nothing is replaced before you say Y') }
                                   else { @('Your files are older than the host''s. The update is not possible from here (no editor folder): get the new version of the editor or the scenario package.') })
                    $updShown = $true; $dirty = $true
                }
                if ($canUpdate -and -not $mapKey -and $mapCtx.AutoUpdate -and $updAutoUsed -eq 0) { $mapKey = 'U'; $updAutoUsed = 1 }
                if ($canUpdate -and $mapKey -eq 'U') {
                    try { $updFetch = Start-BundleFetch $ip $port $updInfo.Hash ('FETCHUPDATE ' + $updInfo.Hash) $script:UpdateMaxBytes; $updState = 'fetching'; $updLines = @('Update: loading ...') }
                    catch { $updNote = 'Update failed: ' + $_.Exception.Message; $updShown = $false }
                    $dirty = $true
                }
                $mapKey = $null
            }
            elseif (-not $result -and $updState -eq 'fetching' -and $updFetch) {
                $r = Step-BundleFetch $updFetch
                if ($r -eq 'done') {
                    try {
                        $updStage = Complete-UpdateFetch $updFetch $hostVerHash
                        $updChanges = @(Get-UpdateChanges $updStage $mapCtx.UpdateRoot)
                        $names = @($updChanges | Select-Object -First 8 | ForEach-Object { $_.Rel + ' (' + $_.Status + ')' })
                        $updLines = @("Update from the host is ready: $($updChanges.Count) of $($updInfo.Count) files would change.") + @($names | ForEach-Object { '   ' + $_ }) +
                                    $(if ($updChanges.Count -gt 8) { @('   ... and ' + ($updChanges.Count - 8) + ' more') } else { @() }) +
                                    @('These are programs: only do this if you trust the host. The old files are saved first.', 'Y = install the update   N = do not')
                        $updState = 'confirm'
                    } catch { $updState = 'offer'; $updNote = 'Update failed: ' + $_.Exception.Message; $updShown = $false }
                    $updFetch = $null; $dirty = $true
                } elseif ($r -ne 'working') { Close-Fetch $updFetch; $updState = 'offer'; $updNote = 'Update failed: ' + $r; $updShown = $false; $updFetch = $null; $dirty = $true }
                elseif ($updFetch.Total -gt 0) {
                    $pct = [int][Math]::Floor(100 * $updFetch.Got / $updFetch.Total)
                    if ($pct -ne $updLastPct) { $updLastPct = $pct; $updLines = @("Update: loading $pct % ($([int]($updFetch.Got / 1024)) of $([int]($updFetch.Total / 1024)) KB)"); $dirty = $true }
                }
            }
            elseif (-not $result -and $updState -eq 'confirm') {
                if (-not $mapKey -and $mapCtx.AutoUpdate -and $updAutoUsed -eq 1) { $mapKey = 'Y'; $updAutoUsed = 2 }
                if ($mapKey -eq 'Y') { $script:UpdateStage = $updStage; Send-LobbyLine $p 'BYE'; $result = 'update' }
                elseif ($mapKey -eq 'N') { Remove-Item $updStage -Recurse -Force -ErrorAction SilentlyContinue; $updStage = $null; $updState = 'offer'; $updNote = ''; $updShown = $false; $updAutoUsed = 3 }
                $mapKey = $null
            }
            # the map: as soon as the scenario is there, look whether its map is installed
            if (-not $result -and $script:BundleDir -and $mapState -eq '') {
                $sc = [IO.File]::ReadAllText((Join-Path $script:BundleDir 'scenario.txt'))
                $mapName = [regex]::Match($sc, '(?m)^\s*mapname\s*=\s*(.+?);').Groups[1].Value.Trim()
                if (-not $mapCtx -or (Test-MapInstalled $mapCtx.Data $mapName)) {
                    $mapState = 'ok'; Send-LobbyLine $p 'MAPOK'; $mapText = "Map: '$mapName' is there"; $mapKind = 7
                } else { $mapState = 'prompt'; $mapText = '' }
                $dirty = $true
            }
            if (-not $result -and $mapState -eq 'prompt') {
                $hostPart = if ($mapInfo) { '   H = get it from the host (' + [Math]::Round($mapInfo.Size / 1MB, 1) + ' MB, he has to agree)' } else { '' }
                $line = $mapText + "The map '$mapName' is not installed.   D = download it from the internet (official map service)" + $hostPart
                if ($line -ne $script:LastMapPrompt) { $script:LastMapPrompt = $line; $dirty = $true }
                $mapShown = $line; $mapKind = 6
                if (-not $mapKey -and $mapCtx -and $mapCtx.Auto -and -not $mapAutoUsed) { $mapKey = $mapCtx.Auto; $mapAutoUsed = $true }
                # nothing is asked: the same network as the host and he has the map: from him; otherwise from the internet. Only after a failure the choice is shown
                if (-not $mapKey -and -not $mapChosen) { $mapChosen = $true; $mapKey = $(if ($sameLan -and $mapInfo) { 'H' } else { 'D' }) }
                if ($mapKey -eq 'D') { $mapState = 'downloading'; $mapText = "Map: downloading '$mapName' from the internet ..."; $dirty = $true }
                elseif ($mapKey -eq 'H' -and $mapInfo) { $mapState = 'waithost'; $mapText = 'Map: waiting for the host to agree ...'; Send-LobbyLine $p 'MAPREQ'; $dirty = $true }
                $mapKey = $null
            }
            elseif (-not $result -and $mapState -eq 'downloading' -and -not $dirty) {
                $pd = Start-Process -FilePath $mapCtx.Downloader -ArgumentList ('--filesystem-writepath "{0}" --download-map "{1}"' -f $mapCtx.Data, $mapName) -Wait -PassThru -NoNewWindow
                if ($pd.ExitCode -eq 0) { $mapState = 'ok'; Send-LobbyLine $p 'MAPOK'; $mapText = "Map: '$mapName' downloaded"; $mapKind = 7 }
                else { $mapState = 'prompt'; $mapText = 'Map: the download failed. ' }
                $dirty = $true
            }
            if (-not $result -and $mapFetch) {
                $r = Step-BundleFetch $mapFetch
                if ($r -eq 'done') {
                    try { Complete-MapFetch $mapFetch $mapName $mapInfo.File; $mapState = 'ok'; Send-LobbyLine $p 'MAPOK'; $mapText = "Map: '$mapName' loaded from the host"; $mapKind = 7 }
                    catch { $mapState = 'prompt'; $mapText = 'Map: ' + $_.Exception.Message + ' ' }
                    $mapFetch = $null; $dirty = $true
                } elseif ($r -ne 'working') { Close-Fetch $mapFetch; $mapState = 'prompt'; $mapText = 'Map: ' + $r + '. '; $mapFetch = $null; $dirty = $true }
                elseif ($mapFetch.Total -gt 0) {
                    $pct = [int][Math]::Floor(100 * $mapFetch.Got / $mapFetch.Total)
                    if ($pct -ne $mapLastPct) {
                        $mapText = 'Map: loading {0} % ({1} of {2} MB)' -f $pct, [Math]::Round($mapFetch.Got / 1MB, 1), [Math]::Round($mapFetch.Total / 1MB, 1); $dirty = $true
                        if ($pct -ge $mapLastPct + 5 -or $pct -ge 100) { Send-LobbyLine $p "MAPPROGRESS $pct"; $mapLastPct = $pct }
                    }
                }
            }
            if (-not $result -and $p.Closed) { $result = 'lost' }
            if (-not $result -and (Get-Date) -gt $until) { $result = 'left' }
            if (-not $result -and $console) {
                try {
                    if ([Console]::KeyAvailable) {
                        $kk = [Console]::ReadKey($true).Key.ToString()
                        if ($kk -eq 'Escape') { Send-LobbyLine $p 'BYE'; $result = 'left' } else { $mapKey = $kk }
                    }
                } catch { }
            }
            if ($dirty) {
                $dirty = $false
                $who = ($roster -replace '=(\d+)', ' (team $1)') -replace ';', ', '
                $lines = @("Lobby of $($ip):$port - you are $name", '', "Status: $status", "Your team: $team", $verText, $dataText, $(if ($mapState -eq 'prompt') { $mapShown } else { $mapText }))
                $kinds = @(1, 0, 0, 7, $verKind, $dataKind, $mapKind)
                foreach ($ul in $updLines) { $lines += $ul; $kinds += 6 }
                $lines += @('', "Players: $who", '', 'Esc = leave'); $kinds += @(0, 0, 0, 2)
                if ($console) { Show-LobbyLines ([pscustomobject]@{ Lines = $lines; Kinds = $kinds }) }
                else { [IO.File]::WriteAllLines($dumpFile, [string[]]$lines) }
            }
            Start-Sleep -Milliseconds 40
        }
        return $result
    } finally {
        Close-Fetch $fetch; Close-Fetch $mapFetch; Close-Fetch $updFetch
        if ($result -ne 'start') { try { $c.Close() } catch { } }   # after the start the connection stays: READY and GO
        if ($console) { [Console]::CursorVisible = $true }
    }
}

# After "start": tells the host that this computer is ready and waits for GO. Returns 'go', 'cancel' or 'lost' (or 'timeout').
function Wait-JoinerGo([int]$timeoutSec = 300) {
    $p = $script:JoinerLobby
    Send-LobbyLine $p 'READY'
    $until = (Get-Date).AddSeconds($timeoutSec)
    while ((Get-Date) -lt $until) {
        foreach ($l in @(Read-LobbyLines $p)) {
            if ($l -eq 'GO') { try { $p.Client.Close() } catch { }; return 'go' }
            if ($l -eq 'CANCEL') { return 'cancel' }
        }
        if ($p.Closed) { return 'lost' }
        Start-Sleep -Milliseconds 100
    }
    return 'timeout'
}
