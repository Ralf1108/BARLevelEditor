# Lobby before a hosted game (dot-sourced by start_scenario.ps1; needs player_mapping.ps1 for ConvertTo-PlayerName and the last mapping).
# The host sees one box per team; every player who joins lands in a team box at once (the team he had last time if it is free, otherwise the first
# team without a player) and the host moves them. The joiners only send their name; a joiner whose connection breaks is removed.
# Protocol (one text line each, UTF-8, TCP): joiner -> host: "VERSION <protocol>" (the version of the lobby protocol, $script:LobbyProtocol), "HELLO <name>",
# "BYE", later "READY"; host -> joiner: "OK <name as the host knows it>" or "ERR <reason>" (also for another protocol: "please update the Level Editor
# manually"), "VERSION <protocol>", then "TEAM <n> <text>" and "ROSTER <name>=<team>;..." whenever something changes, at the end "START" (the joiners
# prepare: extra game, map) or "CANCEL"; when every joiner has said "READY" and the host's game is running the host sends "GO" and the joiners connect.
# The scenario itself goes from the host to the joiners through the lobby, in every hosted game: a bundle with scenario.txt and the Lua files of the
# game (the gadgets and game widgets the host runs; Lua runs only inside the game engine, nothing that runs on the computer itself - no .ps1, no .bat
# - is ever taken from another computer). So every player runs the host's game, whatever version of the editor he has. After "OK" and "VERSION" the
# host sends "OFFER <hash> <size>"; a joiner who has that hash in his cache (%LOCALAPPDATA%\BAR-Scenario\Cache\<hash>\) answers "HAVE <hash>",
# otherwise he opens a second connection to the same port, sends "FETCH <hash>", gets "SIZE <n>" and n bytes (a zip) and then says "HAVE <hash>";
# "PROGRESS <percent>" tells the host how far he is. The host cannot start before everybody has it.
# The map: the host adds "MAP <size> <sha256> <file name>" to the offer (if he has the archive of the map). A joiner who has not got the map is not
# asked: a joiner in the same network as the host (Test-SameLan: the address of the other one is in a subnet of one of his network cards) says
# "MAPREQ" at once and the host answers "MAPYES" (a request from outside the network gets "MAPNO"); everybody else downloads the map from the internet (the
# official map service). Only if that fails the joiner is offered D (download again) or H (ask the host). After "MAPYES" the joiner fetches the file on a second connection ("FETCHMAP <sha256> <his name>"), checks the hash, keeps it in the
# cache (an extra data folder of the engine) and says "MAPOK" (also when the map was there from the start); "MAPPROGRESS <percent>" shows how far he is.
# The focus starts on "Start game" (the last box): Enter or F5 starts at once.
# Keys of the host: Tab / Shift+Tab or Left / Right = next box, Up / Down = player in the box, Enter = pick the player up (then Up / Down /
# Left / Right move him into the neighbouring box, Enter drops him, Esc brings him back), Enter on "Start game" (the last stop) or F5 = start,
# Esc twice = cancel.
# Player numbers: a box is one player of the game (one team of the scenario) and the boxes of one ally team are its players 1, 2, 3 ...; every human who
# joins gets a box of his own if one is free. N on a human puts him into the next player of his ally team (after the last one the first again), so the humans with the
# same number play ONE player together (all of them can give orders to its units, they share its resources). Marked in the lobby: "player 2" after
# the name, "Copilot with Ben" when a box holds more than one human. The game of such a team does not start by itself (the engine waits for a
# second "ready" that never comes): the little widget shared_start.lua starts it from the host's game (see there).

# The version of the lobby protocol: host and joiners must speak the same one (the game itself comes from the host, see the bundle below). Raise it
# when the lines of the protocol or what a joiner does with them change. Version 1 was the hash of the files (VERSION <hash> <date>).
$script:LobbyProtocol = '2'

# ---------------------------------------------------------------- Bundle: the scenario as data
# What a bundle may hold (names only, in this order for the hash): scenario.txt and the Lua files of the extra game of the scenarios (gadgets, game
# widgets, bar_rules.lua). Lua files only run inside the game engine; nothing that runs on the computer itself (no .ps1, .bat) is ever taken from
# another computer.
$script:BundleFiles = @('bar_rules.lua', 'ctf_game.lua', 'pve_supply_drops_stub.lua', 'rtf_game.lua', 'scenario.txt', 'scenario_briefing.lua', 'shared_start.lua', 'td_waves.lua', 'unit_indestructible.lua', 'unit_restrictions.lua')
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
# (counted while unpacking, so a zip that hides its real size cannot fill the disk)
function Expand-BundleZip([string]$zipPath, [string]$destDir) {
    Add-Type -AssemblyName System.IO.Compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $zip = [IO.Compression.ZipFile]::OpenRead($zipPath)
    try {
        $total = 0L
        foreach ($e in $zip.Entries) {
            $name = $script:BundleFiles | Where-Object { $_ -eq $e.FullName } | Select-Object -First 1
            if (-not $name) { throw "The scenario holds a file that is not allowed: $($e.FullName)" }
            # the bytes really unpacked count (the length in the zip is only what the other computer wrote there)
            $in = $e.Open(); $out = [IO.File]::Create((Join-Path $destDir $name))
            try {
                $buf = New-Object byte[] 65536
                while (($n = $in.Read($buf, 0, $buf.Length)) -gt 0) {
                    $total += $n
                    if ($total -gt $script:BundleMaxBytes) { throw 'The scenario is too big.' }
                    $out.Write($buf, 0, $n)
                }
            } finally { $out.Close(); $in.Close() }
        }
    } finally { $zip.Dispose() }
}

# the host's side: the bundle as offered in the lobby (Hash, Size, Dir = its folder in the cache, Zip = the zip to send): scenario.txt of the folder
# $scenarioDir and the Lua files of the game the host runs (for every file the first of the folders $luaDirs that has it, the same search as
# Write-ScenarioGame), so the joiners build exactly the host's extra game from it
function New-HostBundle([string]$scenarioDir, [string[]]$luaDirs) {
    $stage = Join-Path $env:TEMP ('bar_bundle_' + [Guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $stage | Out-Null
    try {
        Copy-Item (Join-Path $scenarioDir 'scenario.txt') $stage
        foreach ($n in $script:BundleFiles) {
            if ($n -eq 'scenario.txt') { continue }
            foreach ($d in $luaDirs) { if ($d -and (Test-Path (Join-Path $d $n))) { Copy-Item (Join-Path $d $n) $stage; break } }
        }
        $inst = Install-Bundle $stage
    } finally { Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue }
    $zip = Join-Path $env:TEMP ('bar_bundle_' + [Guid]::NewGuid().ToString('N') + '.zip')
    New-BundleZip $inst.Dir $zip
    return [pscustomobject]@{ Hash = $inst.Hash; Size = (Get-Item $zip).Length; Dir = $inst.Dir; Zip = $zip; Map = $null }
}

# ---------------------------------------------------------------- The cache: looking after it
# What came from other computers or was made for them lives in %LOCALAPPDATA%\BAR-Scenario: Cache\<hash> (scenarios), Cache\Maps\maps (maps), Update\ (unpacked
# updates of older versions of the editor, which could update itself from a host); Backup\ (files such an update replaced) is never touched here.
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
# The networks of this computer: address and mask of every IPv4 network card (link-local ones left out), read once. A VPN card counts as well; the
# usual VPN ranges count as a whole even when the card shows a small prefix: 100.64.0.0/10 (Tailscale, carrier-grade NAT) and 25.0.0.0/8 (Hamachi).
function Get-LocalNets {
    if ($script:LocalNets) { return $script:LocalNets }
    $nets = @()
    foreach ($a in @(Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue)) {
        if ($a.IPAddress -like '169.254.*' -or $a.IPAddress -like '127.*' -or $a.PrefixLength -lt 8) { continue }
        $l = [BitConverter]::ToUInt32(([Net.IPAddress]::Parse($a.IPAddress)).GetAddressBytes()[3..0], 0)
        $prefix = [int]$a.PrefixLength
        if ($a.IPAddress -match '^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\.') { $prefix = [Math]::Min($prefix, 10) }
        elseif ($a.IPAddress -like '25.*') { $prefix = [Math]::Min($prefix, 8) }
        $m = [uint32](([uint64]4294967295 -shl (32 - $prefix)) -band 4294967295)
        $nets += , @(($l -band $m), $m)
    }
    $script:LocalNets = $nets
    return $nets
}

# True if the address is this computer (localhost) or lies in a network of one of its network cards (LAN, also a VPN)
function Test-SameLan([string]$addr) {
    try {
        $ip = $null
        if (-not [Net.IPAddress]::TryParse($addr, [ref]$ip)) { $ip = [Net.Dns]::GetHostAddresses($addr) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1 }
        if (-not $ip) { return $false }
        if ($ip.IsIPv4MappedToIPv6) { $ip = $ip.MapToIPv4() }
        if ([Net.IPAddress]::IsLoopback($ip) -or $ip.AddressFamily -ne 'InterNetwork') { return [Net.IPAddress]::IsLoopback($ip) }
        $o = [BitConverter]::ToUInt32($ip.GetAddressBytes()[3..0], 0)
        foreach ($n in @(Get-LocalNets)) { if (($o -band $n[1]) -eq $n[0]) { return $true } }
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

# what the official map service (the file server of BAR, the one pr-downloader uses) says about a map, independent of the host:
# Status 'official' (Md5, Size, File), 'unknown' (the service does not know the map: a map of your own) or 'offline' (no answer)
$script:OfficialMapUrl = 'https://files-cdn.beyondallreason.dev/find'
function Get-OfficialMap([string]$mapName) {
    try {
        $r = @(Invoke-RestMethod -Uri ($script:OfficialMapUrl + '?category=map&springname=' + [Uri]::EscapeDataString($mapName)) -TimeoutSec 6 -UseBasicParsing)
    } catch { return [pscustomobject]@{ Status = 'offline' } }
    foreach ($e in $r) {
        if ($e.springname -eq $mapName -and [string]$e.md5 -match '^[0-9a-fA-F]{32}$' -and [long]$e.size -gt 0) {
            return [pscustomobject]@{ Status = 'official'; Md5 = ([string]$e.md5).ToLower(); Size = [long]$e.size; File = [string]$e.filename }
        }
    }
    return [pscustomobject]@{ Status = 'unknown' }
}

function Get-FileMd5([string]$path) { return (Get-FileHash -Path $path -Algorithm MD5).Hash.ToLower() }

# the fetched file: check the hash (and, for an official map, the hash and the size of the official map service), then into the extra data folder
function Complete-MapFetch($f, [string]$mapName, [string]$file, $official = $null) {
    $f.File.Close(); try { $f.Client.Close() } catch { }
    try {
        if ((Get-FileSha256 $f.Part) -ne $f.Hash) { throw 'The map received is not the one that was offered (the hash is wrong).' }
        if ($official -and $official.Status -eq 'official' -and ((Get-Item $f.Part).Length -ne $official.Size -or (Get-FileMd5 $f.Part) -ne $official.Md5)) {
            throw 'The map from the host is NOT the official map (the hash of the official map service differs). It was thrown away.'
        }
        $dir = Join-Path (Get-MapExtraRoot) 'maps'
        New-Item -ItemType Directory -Force $dir | Out-Null
        $dest = Join-Path $dir $file
        if (Test-Path $dest) { Remove-Item $dest -Force }
        Move-Item $f.Part $dest
        Set-Content -Path (Join-Path $dir ($file + '.mapinfo')) -Value @($mapName, $f.Hash) -Encoding ASCII
    } finally { Remove-Item $f.Part -Force -ErrorAction SilentlyContinue }
}

# the joiner's side of a transfer: a second connection that fetches the zip of the bundle. Returns the state for Step-BundleFetch / Complete-BundleFetch.
function Start-BundleFetch([string]$ip, [int]$port, [string]$hash, [string]$request = $null, [long]$max = 0, [long]$expect = -1) {
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
    return @{ Client = $c; Hash = $hash; Part = $part; File = [IO.File]::Create($part); Total = -1L; Got = 0L; Max = $max; Expect = $expect; Header = ''; Buf = (New-Object byte[] 262144) }
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
                if ($f.Expect -ge 0 -and $f.Total -ne $f.Expect) { return 'error: the host sends another size than he offered' }
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

function New-LobbyState($teamInfo, [string]$hostName, [int]$port, $bundle = $null) {
    return @{ Teams = @($teamInfo); HostName = $hostName; Port = $port; Bundle = $bundle; Transfers = (New-Object Collections.ArrayList); Addr = ''; Players = (New-Object Collections.ArrayList); Pending = (New-Object Collections.ArrayList)
              Focus = @($teamInfo).Count; Cursor = 0; Held = $null; HeldFrom = 0; Msg = ''; Info = ''; ConfirmCancel = $false; Dirty = $true; Done = $null }
}

function Get-BoxPlayers($st, [int]$box) { return @($st.Players | Where-Object { $_.Box -eq $box }) }

# The ally team of a box (the text of a team is "Team 1: Cortex, ally team 1"); without that text the box is its own ally team
function Get-BoxAlly($st, [int]$box) {
    $m = [regex]::Match([string]$st.Teams[$box], 'ally team (\d+)')
    if ($m.Success) { return [int]$m.Groups[1].Value }
    return $box
}

# The boxes (= the players of the game) of the ally team that holds this box, in order
function Get-AllyBoxes($st, [int]$box) {
    $a = Get-BoxAlly $st $box
    return @(0..($st.Teams.Count - 1) | Where-Object { (Get-BoxAlly $st $_) -eq $a })
}

# The number of a box inside its ally team: 1, 2, 3 ...
function Get-SlotNumber($st, [int]$box) { return (@(Get-AllyBoxes $st $box).IndexOf($box)) + 1 }

# A human gets the next player number of his ally team (after the last one the first again); with the number of another human he plays that player together with him
function Step-LobbyNumber($st, $p) {
    $boxes = @(Get-AllyBoxes $st $p.Box)
    if ($boxes.Count -lt 2) { $st.Msg = 'This team has only one player: everybody in it is Copilot of that player.'; return }
    $nb = $boxes[($boxes.IndexOf($p.Box) + 1) % $boxes.Count]
    $p.Box = $nb
    $st.Focus = $nb
    $st.Cursor = [Math]::Max(0, @(Get-BoxPlayers $st $nb).IndexOf($p))
    $with = @(Get-BoxPlayers $st $nb | Where-Object { $_ -ne $p } | ForEach-Object { $_.Name })
    $st.Msg = if ($with.Count -gt 0) { '{0} is player {1} now and is Copilot with {2}.' -f $p.Name, (Get-SlotNumber $st $nb), ($with -join ', ') } else { '{0} is player {1} now (alone).' -f $p.Name, (Get-SlotNumber $st $nb) }
}

# The team of a new player: the one of the last mapping (by name) if nobody is there, otherwise the first team without a player, otherwise team 0
function Add-LobbyPlayer($st, [string]$name, $client, [string]$data = 'ready', [string]$map = 'ready') {
    $box = -1
    foreach ($e in @(Read-LastMapping)) {
        if ($e.Name.ToLower() -eq $name.ToLower() -and $e.Team -lt $st.Teams.Count -and @(Get-BoxPlayers $st $e.Team).Count -eq 0) { $box = $e.Team }
    }
    if ($box -lt 0) {
        for ($b = 0; $b -lt $st.Teams.Count; $b++) { if (@(Get-BoxPlayers $st $b).Count -eq 0) { $box = $b; break } }
    }
    if ($box -lt 0) { $box = 0 }
    $p = [pscustomobject]@{ Name = $name; Box = $box; Client = $client; Buf = (New-Object Text.StringBuilder); Sent = ''; Closed = $false; Data = $data; Pct = 0; Map = $map; MapPct = 0; MapGrant = $false }
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
        'N' {
            if ($st.Focus -lt $startBox -and $n -gt 0) {
                $who = @(Get-BoxPlayers $st $st.Focus)[[Math]::Min($st.Cursor, $n - 1)]
                Step-LobbyNumber $st $who
            }
        }
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
    Add-L ('Lobby version {0}: the game and the scenario are the ones of this computer' -f $script:LobbyProtocol) 2
    Add-L '' 0
    for ($b = 0; $b -lt $t; $b++) {
        $slots = @(Get-AllyBoxes $st $b).Count
        Add-L ('{0} {1}{2}' -f $(if ($st.Focus -eq $b) { '>' } else { ' ' }), $st.Teams[$b], $(if ($slots -gt 1) { '   (player {0} of {1} in its team)' -f (Get-SlotNumber $st $b), $slots } else { '' })) $(if ($st.Focus -eq $b) { 3 } else { 1 })
        $pl = @(Get-BoxPlayers $st $b)
        if ($pl.Count -eq 0) { Add-L '      (empty)' 2 }
        for ($i = 0; $i -lt $pl.Count; $i++) {
            $p = $pl[$i]
            $txt = '    ' + ($p.Name + $(if ($p.Client -eq $null) { '  (host)' } else { '' })).PadRight(24) + ('player {0}' -f (Get-SlotNumber $st $b))
            if ($pl.Count -gt 1) { $txt += '   + Copilot with ' + ((@($pl | Where-Object { $_ -ne $p } | ForEach-Object { $_.Name })) -join ', ') }
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
    Add-L 'Tab/Left/Right = box, Up/Down = player, Enter = pick up/drop, N = next player number (same number = Copilot: one player together), F5 = start, Esc x2 = cancel' 2
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
        # only this computer and the local network (a VPN included) may join: a connection from outside is closed at once
        $from = [string]$c.Client.RemoteEndPoint.Address
        if (-not (Test-SameLan $from)) { try { $c.Close() } catch { }; $st.Info = "A connection from $from (outside the local network) was refused."; $st.Dirty = $true; continue }
        [void]$st.Pending.Add([pscustomobject]@{ Client = $c; Buf = (New-Object Text.StringBuilder); Closed = $false; Name = $null; T = (Get-Date); Proto = $null })
    }
    foreach ($q in @($st.Pending)) {
        $hello = $null; $fetch = $null
        foreach ($l in @(Read-LobbyLines $q)) {
            if ($l -like 'HELLO *') { $hello = $l.Substring(6).Trim() }
            elseif ($l -like 'FETCH *' -or $l -like 'FETCHMAP *') { $fetch = $l.Trim() }
            elseif ($l -like 'VERSION *') { $q.Proto = @($l.Substring(8).Trim() -split ' ')[0] }
        }
        if ($fetch) { Start-LobbyTransfer $st $q $fetch; [void]$st.Pending.Remove($q); continue }
        if ($hello) {
            $nm = ConvertTo-PlayerName $hello
            $taken = @($st.Players | Where-Object { $_.Name.ToLower() -eq $nm.ToLower() }).Count -gt 0
            if (-not $nm) { Send-LobbyLine $q 'ERR The name has no usable letters.'; $q.Closed = $true }
            elseif ($taken) { Send-LobbyLine $q 'ERR That name is used already.'; $q.Closed = $true }
            elseif ($q.Proto -ne $script:LobbyProtocol) {
                # another version of the starter and the lobby: nothing is sent to him, he has to update by hand
                Send-LobbyLine $q ('ERR The host has another version of the Level Editor (lobby version {0}, yours {1}): please update the Level Editor manually (the same version on every computer).' -f $script:LobbyProtocol, $(if ($q.Proto) { $q.Proto } else { 'older' }))
                $q.Closed = $true
            }
            else {
                Send-LobbyLine $q "OK $nm"
                Send-LobbyLine $q ('VERSION {0}' -f $script:LobbyProtocol)
                $dataState = 'ready'; $mapState = 'ready'
                if ($st.Bundle) {
                    $dataState = 'wait'; $mapState = 'missing'
                    Send-LobbyLine $q ('OFFER {0} {1}' -f $st.Bundle.Hash, $st.Bundle.Size)
                    if ($st.Bundle.Map) { Send-LobbyLine $q ('MAP {0} {1} {2}' -f $st.Bundle.Map.Size, $st.Bundle.Map.Hash, $st.Bundle.Map.File) }
                }
                [void](Add-LobbyPlayer $st $nm $q.Client $dataState $mapState)
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
function Invoke-HostLobby($teamInfo, [string]$hostName, [int]$port = 8453, $keyFeed = $null, [string]$dumpFile = $null, [int]$timeoutSec = 0, [int]$autoStart = 0, $bundle = $null) {
    $st = New-LobbyState $teamInfo $hostName $port $bundle
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

# The lobby of a joiner. Returns 'start', 'cancel' (the host cancelled), 'lost' (the host went away), 'left' (Esc), 'refused: <reason>' or 'noconnect'.
# $dumpFile / $timeoutSec: for tests like above
function Join-Lobby([string]$ip, [int]$port, [string]$name, [int]$timeoutSec = 0, [string]$dumpFile = $null, $mapCtx = $null) {
    $c = New-Object Net.Sockets.TcpClient
    $ar = $c.BeginConnect($ip, $port, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne(5000)) { $c.Close(); return 'noconnect' }
    try { $c.EndConnect($ar) } catch { $c.Close(); return 'noconnect' }
    $p = [pscustomobject]@{ Name = $name; Box = 0; Client = $c; Buf = (New-Object Text.StringBuilder); Sent = ''; Closed = $false }
    $script:JoinerLobby = $p; $script:JoinerName = $name
    Send-LobbyLine $p ('VERSION {0}' -f $script:LobbyProtocol)
    Send-LobbyLine $p "HELLO $name"
    $console = -not $dumpFile
    $status = 'connecting ...'; $team = '-'; $roster = ''; $result = $null; $verText = ''; $verKind = 0
    $dataText = ''; $dataKind = 0; $fetch = $null; $lastPct = -10; $script:BundleDir = $null
    $mapText = ''; $mapKind = 0; $mapState = ''; $mapName = ''; $mapInfo = $null; $mapFetch = $null; $mapKey = $null; $mapAutoUsed = $false; $mapLastPct = -10; $mapChosen = $false; $sameLan = Test-SameLan $ip; $mapOfficial = $null; $mapOfficialNote = ''
    $until = if ($timeoutSec -gt 0) { (Get-Date).AddSeconds($timeoutSec) } else { [DateTime]::MaxValue }
    $dirty = $true
    try {
        if ($console) { Clear-Host; [Console]::CursorVisible = $false }
        while (-not $result) {
            foreach ($l in @(Read-LobbyLines $p)) {
                $dirty = $true
                if ($l -eq 'OK' -or $l -like 'OK *') { $status = 'waiting for the host to start the game'; if ($l.Length -gt 3) { $script:JoinerName = $l.Substring(3).Trim() } }
                elseif ($l -like 'ERR *') { $result = 'refused: ' + $l.Substring(4) }
                elseif ($l -like 'VERSION *') {
                    $v = @($l.Substring(8).Trim() -split ' ')[0]
                    if ($v -ne $script:LobbyProtocol) { $result = "refused: the host has another version of the Level Editor (lobby version $v, yours $($script:LobbyProtocol)): please update the Level Editor manually" }
                    else { $verText = 'Lobby version: the same as the host''s'; $verKind = 7 }
                }
                elseif ($l -like 'MAP *') {
                    $o = @($l.Substring(4).Trim() -split ' ', 3)
                    if ($o.Count -eq 3 -and (Test-BundleId $o[1]) -and (Test-MapFileName $o[2]) -and [long]$o[0] -le $script:MapMaxBytes) { $mapInfo = @{ Size = [long]$o[0]; Hash = $o[1]; File = $o[2] } }
                }
                elseif ($l -eq 'MAPYES' -and $mapState -eq 'waithost' -and $mapInfo) {
                    try { $mapFetch = Start-BundleFetch $ip $port $mapInfo.Hash ('FETCHMAP {0} {1}' -f $mapInfo.Hash, $script:JoinerName) $script:MapMaxBytes $mapInfo.Size; $mapState = 'fetching'; $mapText = "Map: loading ..."; $mapKind = 6 }
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
                        try { $fetch = Start-BundleFetch $ip $port $o[0] $null 0 ([long]$o[1]); $dataText = 'Scenario: loading ...'; $dataKind = 6 }
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
                elseif ($mapKey -eq 'H' -and $mapInfo) {
                    # the official hash first (independent of the host); no internet or a map of your own: only the hash of the host counts
                    $mapOfficial = Get-OfficialMap $mapName
                    $mapOfficialNote = switch ($mapOfficial.Status) { 'official' { ' (checked against the official hash)' } 'unknown' { ' (not an official map: only the hash of the host is checked)' } default { ' (official hash not reachable: only the hash of the host is checked)' } }
                    if ($mapOfficial.Status -eq 'official' -and $mapOfficial.Size -ne $mapInfo.Size) {
                        $mapState = 'prompt'; $mapText = 'Map: the file of the host is not the official map (other size). '; $mapInfo = $null
                    } else { $mapState = 'waithost'; $mapText = 'Map: waiting for the host to agree ...'; Send-LobbyLine $p 'MAPREQ' }
                    $dirty = $true
                }
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
                    try { Complete-MapFetch $mapFetch $mapName $mapInfo.File $mapOfficial; $mapState = 'ok'; Send-LobbyLine $p 'MAPOK'; $mapText = "Map: '$mapName' loaded from the host$mapOfficialNote"; $mapKind = 7 }
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
                $lines += @('', "Players: $who", '', 'Esc = leave'); $kinds += @(0, 0, 0, 2)
                if ($console) { Show-LobbyLines ([pscustomobject]@{ Lines = $lines; Kinds = $kinds }) }
                else { [IO.File]::WriteAllLines($dumpFile, [string[]]$lines) }
            }
            Start-Sleep -Milliseconds 40
        }
        return $result
    } finally {
        Close-Fetch $fetch; Close-Fetch $mapFetch
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
