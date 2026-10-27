# Shared helpers of the setup scripts (Level Editor, BluePrinter, LAN Play) and of the scenario starter: find BAR, the engine and the installed
# game version, create junctions. Dot-source it: . (Join-Path (Split-Path $PSScriptRoot -Parent) 'shared\bar_common.ps1')
# The scenario builder copies this file into every scenario package, so start_scenario.ps1 finds it next to itself on another computer too.

# (a script may define its own Fail after dot-sourcing this file, e.g. one that waits for a key)
function Fail($t) { Write-Host "ERROR: $t" -ForegroundColor Red; exit 1 }

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

# Version of the installed official game (byar:test, otherwise byar:stable; the first one whose package is installed)
function Get-GameVersion($data) {
    Add-Type -AssemblyName System.IO.Compression
    $versionsFile = Join-Path $data 'rapid\repos-cdn.beyondallreason.dev\byar\versions.gz'
    if (-not (Test-Path $versionsFile)) { Fail 'No game data found (rapid\...\byar\versions.gz). Please start BAR once and let a game load.' }
    $fs = [IO.File]::OpenRead($versionsFile)
    $gz = New-Object IO.Compression.GZipStream($fs, [IO.Compression.CompressionMode]::Decompress)
    $sr = New-Object IO.StreamReader($gz)
    $text = $sr.ReadToEnd(); $sr.Close(); $fs.Close()
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
