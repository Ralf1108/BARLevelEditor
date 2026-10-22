# Map previews and map data in the console for choose_map.ps1 (dot-sourced).
# The thumbnails are not downloaded: the lobby of Beyond All Reason (package byar-chobby) ships them in
# LuaMenu/configs/gameConfig/byar/minimapThumbnail/<map name with _>.png. This file finds the package in
# <BAR\data>\packages\*.sdp, takes the thumbnail out of the pool (<data>\pool\xx\yyyy.gz) and draws it with half blocks
# (one character = two pixels, 24-bit colour; 16 colours if the console cannot do more). Without a package or thumbnail
# nothing is shown. Nothing is stored on disk: the index and the pictures are read into memory.
# The same package has configs/gameConfig/byar/mapDetails.lua (generated from the maps-metadata repository of BAR) with size, number of
# players and terrain of every map: Get-MapDetail / Get-MapInfoText give them to the filters and the line under the picture.

$script:PvIndex = $null     # lower case map name -> md5 of the picture in the pool
$script:PvData = $null
$script:PvCache = @{}       # map name -> [System.Drawing.Bitmap] or $false
$script:PvTrue = $false     # console understands 24-bit colour sequences
$script:PvReady = $false
$script:PvDetMd5 = $null   # md5 of mapDetails.lua in the pool
$script:PvDetails = $null  # normalized map name -> detail (parsed when first asked for); $false = not available

# Reads an .sdp (gzip: per file 1 byte name length, name, 16 bytes md5, 4 bytes crc, 4 bytes size) and returns the thumbnails in it (Thumbs) and the md5 of mapDetails.lua (Details)
function Read-SdpThumbs([string]$sdp) {
    $fs = [IO.File]::OpenRead($sdp)
    try {
        $gz = New-Object IO.Compression.GZipStream($fs, [IO.Compression.CompressionMode]::Decompress)
        $ms = New-Object IO.MemoryStream
        $gz.CopyTo($ms)
    } finally { $fs.Close() }
    $b = $ms.ToArray()
    $res = @{}
    $det = $null
    $p = 0
    while ($p -lt $b.Length) {
        $n = $b[$p]; $p++
        $name = [Text.Encoding]::ASCII.GetString($b, $p, $n); $p += $n
        # the names in the .sdp are lower case
        if ($name.EndsWith('.png') -and $name.Contains('/minimapthumbnail/')) {
            $md5 = New-Object Text.StringBuilder
            for ($i = 0; $i -lt 16; $i++) { [void]$md5.Append($b[$p + $i].ToString('x2')) }
            $res[[IO.Path]::GetFileNameWithoutExtension($name).ToLower()] = $md5.ToString()
        }
        elseif ($name.EndsWith('/byar/mapdetails.lua')) {
            $md5 = New-Object Text.StringBuilder
            for ($i = 0; $i -lt 16; $i++) { [void]$md5.Append($b[$p + $i].ToString('x2')) }
            $det = $md5.ToString()
        }
        $p += 24
    }
    return [pscustomobject]@{ Thumbs = $res; Details = $det }
}

# The file of the pool with this md5 as a MemoryStream (unpacked), $null if it is not there
function Get-PoolStream([string]$md5) {
    $pool = Join-Path $script:PvData ('pool\' + $md5.Substring(0, 2) + '\' + $md5.Substring(2) + '.gz')
    if (-not (Test-Path $pool)) { return $null }
    $in = [IO.File]::OpenRead($pool)
    try {
        $gz = New-Object IO.Compression.GZipStream($in, [IO.Compression.CompressionMode]::Decompress)
        $ms = New-Object IO.MemoryStream
        $gz.CopyTo($ms)
    } finally { $in.Close() }
    $ms.Position = 0
    return $ms
}

# Builds the index map name -> picture in the pool; $false if there is no package with thumbnails
function Initialize-MapPreview([string]$Data) {
    if ($script:PvReady) { return ($null -ne $script:PvIndex) }
    $script:PvReady = $true
    $script:PvData = $Data
    try {
        Add-Type -AssemblyName System.Drawing
        # 24-bit colour: switch on the escape sequences of the console (Windows Terminal has them, the old window needs the mode)
        try {
            Add-Type -Namespace Pv -Name K32 -MemberDefinition @'
[DllImport("kernel32.dll")] public static extern IntPtr GetStdHandle(int h);
[DllImport("kernel32.dll")] public static extern bool GetConsoleMode(IntPtr h, out int m);
[DllImport("kernel32.dll")] public static extern bool SetConsoleMode(IntPtr h, int m);
'@ -ErrorAction Stop
            $h = [Pv.K32]::GetStdHandle(-11); $m = 0
            if ([Pv.K32]::GetConsoleMode($h, [ref]$m)) { $script:PvTrue = [Pv.K32]::SetConsoleMode($h, ($m -bor 4)) }
            [Console]::OutputEncoding = [Text.Encoding]::UTF8
        } catch { $script:PvTrue = $false }
        $sdps = @(Get-ChildItem (Join-Path $Data 'packages') -Filter '*.sdp' -ErrorAction Stop | Sort-Object LastWriteTime -Descending)
        if ($sdps.Count -eq 0) { return $false }
        # the newest package that lists thumbnails
        foreach ($s in $sdps) {
            $r = Read-SdpThumbs $s.FullName
            if ($r.Thumbs.Count -eq 0) { continue }
            $script:PvIndex = $r.Thumbs
            $script:PvDetMd5 = $r.Details
            break
        }
        return ($null -ne $script:PvIndex)
    } catch { $script:PvIndex = $null; return $false }
}

# Picture of a map (Spring name, spaces allowed) as a Bitmap, $null if there is none
function Get-MapThumb([string]$spring) {
    if (-not $script:PvIndex) { return $null }
    $key = ($spring -replace ' ', '_').ToLower()
    if ($script:PvCache.ContainsKey($key)) { return $script:PvCache[$key] }
    $bmp = $null
    $md5 = $script:PvIndex[$key]
    if ($md5) {
        try {
            $ms = Get-PoolStream $md5
            if ($ms) { $bmp = New-Object Drawing.Bitmap($ms) }   # the stream has to stay open as long as the bitmap lives
        } catch { $bmp = $null }
    }
    if ($script:PvCache.Count -gt 60) { $script:PvCache = @{} }
    $script:PvCache[$key] = $bmp
    return $bmp
}

# Data of a map from mapDetails.lua: Size (XS..XXXL like the lobby: quantiles of the area over all maps), Width, Height, Players (number, 0 =
# unknown), Terrain (list: the special of the map, Flat, Hills, Water); $null if the map is not in the file
function Get-MapDetail([string]$spring) {
    if ($null -eq $script:PvDetails) {
        $script:PvDetails = $false
        try {
            $ms = if ($script:PvDetMd5) { Get-PoolStream $script:PvDetMd5 } else { $null }
            if ($ms) {
                $text = [Text.Encoding]::UTF8.GetString($ms.ToArray())
                $all = @{}
                $areas = New-Object Collections.Generic.List[double]
                foreach ($line in $text.Split("`n")) {
                    $m = [regex]::Match($line, "^\['([^']+)'\]=\{")
                    if (-not $m.Success) { continue }
                    $wm = [regex]::Match($line, 'Width=(\d+), Height=(\d+)')
                    if (-not $wm.Success) { continue }
                    $terrain = @()
                    $sp = [regex]::Match($line, "Special='([^']*)'")
                    if ($sp.Success -and $sp.Groups[1].Value) { $terrain += $sp.Groups[1].Value }
                    if ($line -match 'Flat=1') { $terrain += 'Flat' }
                    if ($line -match 'Hills=1') { $terrain += 'Hills' }
                    if ($line -match 'Water=1') { $terrain += 'Water' }
                    $pc = [regex]::Match($line, "PlayerCount='(\d+)")
                    $d = [pscustomobject]@{ Width = [int]$wm.Groups[1].Value; Height = [int]$wm.Groups[2].Value; Area = [int]$wm.Groups[1].Value * [int]$wm.Groups[2].Value; Size = ''
                        Players = $(if ($pc.Success) { [int]$pc.Groups[1].Value } else { 0 }); Terrain = $terrain }
                    $all[($m.Groups[1].Value -replace ' ', '_').ToLower()] = $d
                    if ($d.Area -gt 0) { $areas.Add($d.Area) }
                }
                # size classes as in the lobby (gui_maplist_panel.lua): the area of the map against quantiles of all areas
                $labels = @('XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL')
                $quant = @(0.08, 0.24, 0.40, 0.60, 0.78, 0.92)
                $sorted = @($areas | Sort-Object)
                $thr = @(); $lastV = $sorted[0]
                foreach ($q in $quant) {
                    $v = $sorted[[Math]::Max(0, [Math]::Min($sorted.Count - 1, [int][Math]::Floor(($sorted.Count - 1) * $q + 1) - 1))]
                    if ($v -lt $lastV) { $v = $lastV }
                    $thr += $v; $lastV = $v
                }
                foreach ($d in $all.Values) {
                    $d.Size = $labels[$labels.Count - 1]
                    for ($i = 0; $i -lt $thr.Count; $i++) { if ($d.Area -le $thr[$i]) { $d.Size = $labels[$i]; break } }
                }
                if ($all.Count -gt 0) { $script:PvDetails = $all }
            }
        } catch { $script:PvDetails = $false }
    }
    if (-not $script:PvDetails -or -not $spring) { return $null }
    return $script:PvDetails[($spring -replace ' ', '_').ToLower()]
}

# One line for under the picture: "12 x 12 (L), 4 players, Hills, Metal"
function Get-MapInfoText([string]$spring) {
    $d = Get-MapDetail $spring
    if (-not $d) { return '' }
    $parts = @(('{0} x {1} ({2})' -f $d.Width, $d.Height, $d.Size))
    if ($d.Players -gt 0) { $parts += ('{0} players' -f $d.Players) }
    $parts += $d.Terrain
    return ($parts -join ', ')
}

# nearest of the 16 console colours (fallback)
$script:PvPal = @(
    @(0, 0, 0), @(0, 0, 128), @(0, 128, 0), @(0, 128, 128), @(128, 0, 0), @(128, 0, 128), @(128, 128, 0), @(192, 192, 192),
    @(128, 128, 128), @(0, 0, 255), @(0, 255, 0), @(0, 255, 255), @(255, 0, 0), @(255, 0, 255), @(255, 255, 0), @(255, 255, 255))
function Get-Near16([int]$r, [int]$g, [int]$b) {
    $best = 0; $bd = [int]::MaxValue
    for ($i = 0; $i -lt 16; $i++) {
        $p = $script:PvPal[$i]
        $d = ($r - $p[0]) * ($r - $p[0]) + ($g - $p[1]) * ($g - $p[1]) + ($b - $p[2]) * ($b - $p[2])
        if ($d -lt $bd) { $bd = $d; $best = $i }
    }
    return [ConsoleColor]$best
}

# Draws the picture of a map into the rectangle (x, y, cols x rows characters); the rectangle is cleared first.
# Returns $true if a picture was drawn.
function Show-MapPreview([string]$spring, [int]$x, [int]$y, [int]$cols, [int]$rows) {
    $blank = ' ' * $cols
    for ($r = 0; $r -lt $rows; $r++) { [Console]::SetCursorPosition($x, $y + $r); [Console]::Write($blank) }
    $bmp = $null
    if ($spring) { $bmp = Get-MapThumb $spring }
    if (-not $bmp) {
        $t = if ($spring -and $script:PvIndex) { 'no preview' } else { '' }
        if ($t) { [Console]::SetCursorPosition($x, $y + [int]($rows / 2)); [Console]::ForegroundColor = 'DarkGray'; [Console]::Write($t); [Console]::ResetColor() }
        return $false
    }
    # fit the picture into cols x (2 * rows) pixels, keep the proportions
    $pw = $cols; $ph = 2 * $rows
    $sc = [Math]::Min($pw / $bmp.Width, $ph / $bmp.Height)
    $w = [Math]::Max(1, [int]($bmp.Width * $sc)); $h = [Math]::Max(2, [int]($bmp.Height * $sc))
    if ($h % 2 -eq 1) { $h++ }
    $small = New-Object Drawing.Bitmap($w, $h)
    $g = [Drawing.Graphics]::FromImage($small)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($bmp, 0, 0, $w, $h)
    $g.Dispose()
    $ox = $x + [int](($cols - $w) / 2); $oy = $y + [int](($rows - $h / 2) / 2)
    $esc = [char]27
    for ($row = 0; $row -lt $h / 2; $row++) {
        $sb = New-Object Text.StringBuilder
        if ($script:PvTrue) {
            for ($cx = 0; $cx -lt $w; $cx++) {
                $a = $small.GetPixel($cx, 2 * $row); $b = $small.GetPixel($cx, 2 * $row + 1)
                [void]$sb.Append("$esc[38;2;$($a.R);$($a.G);$($a.B);48;2;$($b.R);$($b.G);$($b.B)m" + [char]0x2580)
            }
            [void]$sb.Append("$esc[0m")
            [Console]::SetCursorPosition($ox, $oy + $row)
            [Console]::Write($sb.ToString())
        } else {
            [Console]::SetCursorPosition($ox, $oy + $row)
            $fg0 = [Console]::ForegroundColor; $bg0 = [Console]::BackgroundColor
            for ($cx = 0; $cx -lt $w; $cx++) {
                $a = $small.GetPixel($cx, 2 * $row); $b = $small.GetPixel($cx, 2 * $row + 1)
                [Console]::ForegroundColor = Get-Near16 $a.R $a.G $a.B
                [Console]::BackgroundColor = Get-Near16 $b.R $b.G $b.B
                [Console]::Write([char]0x2580)
            }
            [Console]::ForegroundColor = $fg0; [Console]::BackgroundColor = $bg0
        }
    }
    $small.Dispose()
    return $true
}
