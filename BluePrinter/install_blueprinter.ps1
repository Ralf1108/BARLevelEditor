# Installs the BluePrinter widget in the official Beyond All Reason (run through install_blueprinter.bat).
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
function Fail($t) { Write-Host "ERROR: $t" -ForegroundColor Red; exit 1 }

# Find BAR
$candidates = @()
$candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Beyond-All-Reason')
$parents = @('Games', 'Spiele', 'Program Files', 'Program Files (x86)', 'Programme', '')
$names = @('Beyond-All-Reason', 'Beyond All Reason', 'BeyondAllReason')
foreach ($drive in [IO.DriveInfo]::GetDrives()) {
    if ($drive.DriveType -ne 'Fixed' -or -not $drive.IsReady) { continue }
    foreach ($par in $parents) {
        foreach ($n in $names) { $candidates += (Join-Path (Join-Path $drive.RootDirectory.FullName $par) $n) }
    }
}
$bar = $null
foreach ($c in $candidates) { if (Test-Path (Join-Path $c 'data\engine')) { $bar = $c; break } }
while (-not $bar) {
    $in = Read-Host 'BAR not found. Please enter the installation folder (Beyond-All-Reason.exe is in it)'
    if ($in -and (Test-Path (Join-Path $in 'data\engine'))) { $bar = $in } elseif (-not $in) { Fail 'Aborted.' } else { Write-Host 'There is no data\engine folder there.' }
}
$data = Join-Path $bar 'data'
Write-Host "BAR found: $bar"

# Copy the widget
$wdir = Join-Path $data 'LuaUI\Widgets'
New-Item -ItemType Directory -Force $wdir | Out-Null
Copy-Item (Join-Path $here 'bluePrinter.lua') (Join-Path $wdir 'bluePrinter.lua') -Force
Write-Host "Widget copied to $wdir"

# shared code (Level Editor and BluePrinter): folder shared next to BluePrinter, otherwise a copy next to the widget
$sharedSrc = Join-Path (Join-Path (Split-Path $here -Parent) 'shared') 'editor_common.lua'
if (-not (Test-Path $sharedSrc)) { $sharedSrc = Join-Path $here 'editor_common.lua' }
if (-not (Test-Path $sharedSrc)) { Fail 'File editor_common.lua missing (copy the shared folder next to BluePrinter as well).' }
$idir = Join-Path $data 'LuaUI\Include'
New-Item -ItemType Directory -Force $idir | Out-Null
Remove-Item (Join-Path $idir 'bp_shared.lua') -Force -ErrorAction SilentlyContinue # old name
Copy-Item $sharedSrc (Join-Path $idir 'editor_common.lua') -Force
Write-Host "Shared code copied to $idir"

# Folders for blueprints, via junction in the write folder of the game. User widgets in BAR may only write under LuaUI\Config
# (and only read under LuaUI), so the junctions live there.
function Repoint($path, $target) {
    # a junction left over from a moved or renamed project folder is removed so it can be created again
    $item = Get-Item $path -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -and (@($item.Target)[0] -ne $target)) {
        cmd /c rmdir "$path" | Out-Null
        Write-Host "Stale junction removed: $path -> $(@($item.Target)[0])"
    }
}
function Link($path, $target) {
    Repoint $path $target
    if (Test-Path $path) {
        Write-Host "Junction already exists: $path"
    } else {
        cmd /c mklink /J "$path" "$target" | Out-Null
        Write-Host "Junction: $path -> $target"
    }
}
$cfgDir = Join-Path $data 'LuaUI\Config'
New-Item -ItemType Directory -Force $cfgDir | Out-Null
$bpDir = Join-Path $here 'blueprints'
New-Item -ItemType Directory -Force $bpDir | Out-Null
Link (Join-Path $cfgDir 'BluePrinter') $bpDir
# Blueprints of the Level Editor (if the LevelEditor folder lies next to BluePrinter)
$leDir = Join-Path (Join-Path (Split-Path $here -Parent) 'LevelEditor') 'blueprints'
if (Test-Path $leDir) { Link (Join-Path $cfgDir 'LevelEditorBlueprints') $leDir }
# remove the old junction from earlier versions (data\BluePrinter); the widget may not access it
$old = Join-Path $data 'BluePrinter'
if ((Test-Path $old) -and ((Get-Item $old).Attributes -band [IO.FileAttributes]::ReparsePoint)) {
    cmd /c rmdir "$old" | Out-Null
    Write-Host "Old junction removed: $old"
}
Write-Host ''
Write-Host 'Done. In the game: Settings -> allow user widgets ("Allow user widgets") and then'
Write-Host 'F11 (widget list) -> switch BluePrinter on, if it is not on already.'
