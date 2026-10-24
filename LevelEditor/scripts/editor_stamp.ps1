# Fingerprint of what install_editor.ps1 packs into the extra game (dot-sourced by install_editor.ps1 and ensure_installed.ps1):
# if it differs from the one stored at the last setup, the setup has to run again.
$EditorFiles = @('unit_level_editor.lua', 'lvl_level_editor.lua', 'td_waves.lua', 'ctf_game.lua', 'led_ctf.lua', 'rtf_game.lua', 'led_rtf.lua', 'unit_restrictions.lua', 'led_restrictions.lua', 'help_texts.lua', 'pve_supply_drops_stub.lua')
$SharedFiles = @('editor_common.lua', 'bar_rules.lua')

function Get-EditorStamp([string]$here, [string]$game) {
    $sha = [Security.Cryptography.SHA256]::Create()
    $bytes = New-Object System.Collections.Generic.List[byte]
    $bytes.AddRange([Text.Encoding]::UTF8.GetBytes($game))
    $paths = @($EditorFiles | ForEach-Object { Join-Path $here $_ }) + @($SharedFiles | ForEach-Object { Join-Path (Join-Path (Split-Path (Split-Path $here -Parent) -Parent) 'shared') $_ })
    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { return $null }
        $bytes.AddRange([IO.File]::ReadAllBytes($p))
    }
    return ([BitConverter]::ToString($sha.ComputeHash($bytes.ToArray())) -replace '-', '')
}
