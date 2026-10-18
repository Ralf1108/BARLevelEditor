# Makes sure the junctions in the BAR data folder point to the levels and blueprints folders next to this script.
# Called by start_level_editor.bat before every start, so a moved or renamed project folder does not break saving.
param([Parameter(Mandatory)][string]$Data)
$here = $PSScriptRoot
function Ensure($path, $target) {
    New-Item -ItemType Directory -Force $target | Out-Null
    $item = Get-Item $path -Force -ErrorAction SilentlyContinue
    if ($item) {
        if (-not ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) { return } # a real folder: leave it alone
        if (@($item.Target)[0] -eq $target) { return }
        cmd /c rmdir "$path" | Out-Null
        Write-Host "Junction repointed: $path -> $target"
    }
    cmd /c mklink /J "$path" "$target" | Out-Null
}
Ensure (Join-Path $Data 'LevelEditor') (Join-Path $here 'levels')
Ensure (Join-Path $Data 'LevelEditorBlueprints') (Join-Path $here 'blueprints')
