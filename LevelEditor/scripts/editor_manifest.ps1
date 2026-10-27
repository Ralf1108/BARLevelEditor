# The files of the Level Editor setup in one place (dot-sourced by install_editor.ps1 and ensure_installed.ps1; needs shared\bar_common.ps1 first,
# which holds the list of the extra game of the scenarios, $ScenarioGameFiles). Where a file goes, which files make the stamp: only here.

# The folders of the sources, by key: scripts = LevelEditor\scripts, shared = ..\shared, template = LevelEditor\scenario\template, lan = LevelEditor\lan_lobby
function Get-EditorFolder([string]$key) {
    $scripts = $PSScriptRoot
    $root = Split-Path $scripts -Parent
    switch ($key) {
        'scripts'  { return $scripts }
        'shared'   { return Join-Path (Split-Path $root -Parent) 'shared' }
        'template' { return Join-Path $root 'scenario\template' }
        'lan'      { return Join-Path $root 'lan_lobby' }
    }
    throw "unknown folder key $key"
}

# The extra game "Level Editor" (data\games\LevelEditorMod.sdz): folder key, file, path in the archive. Besides these it holds the gadgets of the
# scenarios from $ScenarioGameFiles (the entries under luarules/ and luaui/Include/; the game widgets of the scenarios are not needed in the editor).
$EditorGameFiles = @(
    @('scripts', 'unit_level_editor.lua', 'luarules/gadgets/unit_level_editor.lua'),
    @('scripts', 'lvl_level_editor.lua', 'luaui/widgets/lvl_level_editor.lua'),   # switched on in the archive (enabled = true)
    @('shared', 'editor_common.lua', 'luaui/Include/editor_common.lua'),
    @('scripts', 'led_td.lua', 'luaui/Include/led_td.lua'),
    @('scripts', 'led_ctf.lua', 'luaui/Include/led_ctf.lua'),
    @('scripts', 'led_rtf.lua', 'luaui/Include/led_rtf.lua'),
    @('scripts', 'led_restrictions.lua', 'luaui/Include/led_restrictions.lua'),
    @('scripts', 'help_texts.lua', 'luaui/Include/led_help_texts.lua'))

# The folders where the sources of the extra game of the scenarios are looked for (Write-ScenarioGame)
function Get-ScenarioGameDirs { return @((Get-EditorFolder 'scripts'), (Get-EditorFolder 'shared'), (Get-EditorFolder 'template')) }

# Further files whose change has to run the setup again: the setup itself and what the LAN Play setup copies
$StampExtraFiles = @(
    @('scripts', 'install_editor.ps1'), @('scripts', 'editor_manifest.ps1'), @('shared', 'bar_common.ps1'),
    @('lan', 'lan_lobby.lua'), @('lan', 'install_lan_play.ps1'))

# The entries of LevelEditorMod.sdz: @(path in the archive, full path of the source)
function Get-EditorGameEntries {
    $list = @()
    foreach ($f in $EditorGameFiles) { $list += , @($f[2], (Join-Path (Get-EditorFolder $f[0]) $f[1])) }
    foreach ($f in $ScenarioGameFiles) {
        if ($f[1] -like 'luarules/*' -or $f[1] -like 'luaui/Include/*') {
            $src = $null
            foreach ($d in (Get-ScenarioGameDirs)) { if (Test-Path (Join-Path $d $f[0])) { $src = Join-Path $d $f[0]; break } }
            $list += , @($f[1], $(if ($src) { $src } else { Join-Path (Get-EditorFolder 'scripts') $f[0] }))
        }
    }
    return $list
}

# Every source file of the setup (for the check before building and for the stamp)
function Get-EditorSourceFiles {
    $paths = @(Get-EditorGameEntries | ForEach-Object { $_[1] })
    foreach ($f in $ScenarioGameFiles) {
        foreach ($d in (Get-ScenarioGameDirs)) { if (Test-Path (Join-Path $d $f[0])) { $paths += (Join-Path $d $f[0]); break } }
    }
    foreach ($f in $StampExtraFiles) { $paths += (Join-Path (Get-EditorFolder $f[0]) $f[1]) }
    return @($paths | Select-Object -Unique)
}

# Fingerprint of the setup: SHA-256 over the game version and every source file; if it differs from the one stored at the last setup
# (data\games\LevelEditorMod.stamp), start_level_editor.bat runs the setup again. $null when a file is missing.
function Get-EditorStamp([string]$game) {
    $bytes = New-Object System.Collections.Generic.List[byte]
    $bytes.AddRange([Text.Encoding]::UTF8.GetBytes($game))
    foreach ($p in (Get-EditorSourceFiles)) {
        if (-not (Test-Path $p)) { return $null }
        $bytes.AddRange([Text.Encoding]::UTF8.GetBytes($p.Substring((Split-Path (Get-EditorFolder 'shared') -Parent).Length) + "`n"))
        $bytes.AddRange([IO.File]::ReadAllBytes($p))
    }
    return ([BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes.ToArray())) -replace '-', '')
}
