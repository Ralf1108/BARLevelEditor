# Starts Beyond All Reason with LAN Play: makes sure the newest widget is installed, creates <data>\lan_play.flag (the widget is active only while it exists),
# starts the game launcher, waits until the game and the launcher have ended and removes the flag again. Started by the desktop shortcut
# "Beyond All Reason - LAN Play" (install_lan_play.ps1 creates it).
param([string]$BarPath = $null)
Add-Type -AssemblyName System.Windows.Forms
function Fail($m) { [void][Windows.Forms.MessageBox]::Show($m, 'LAN Play', 'OK', 'Warning'); exit 1 }

if (-not $BarPath) {
    foreach ($d in (Get-PSDrive -PSProvider FileSystem | ForEach-Object { $_.Root })) {
        foreach ($p in 'Games\Beyond-All-Reason', 'Program Files\Beyond-All-Reason', 'Beyond-All-Reason') {
            if (Test-Path (Join-Path $d "$p\data")) { $BarPath = Join-Path $d $p; break }
        }
        if ($BarPath) { break }
    }
}
if (-not $BarPath) { Fail 'Beyond All Reason was not found.' }
if (Get-Process -Name 'spring', 'Beyond-All-Reason' -ErrorAction SilentlyContinue) { Fail 'Beyond All Reason is running already. Close it and start it again with this shortcut.' }

# the newest widget (only copies when it differs; no shortcut)
$out = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File (Join-Path $PSScriptRoot 'install_lan_play.ps1') -BarPath $BarPath -NoShortcut 2>&1
if ($LASTEXITCODE -ne 0) { Fail ("The LAN Play widget could not be installed:`r`n" + ($out -join "`r`n")) }

$flag = Join-Path $BarPath 'data\lan_play.flag'
[IO.File]::WriteAllText($flag, (Get-Date -Format 's'))
try {
    Start-Process (Join-Path $BarPath 'Beyond-All-Reason.exe') -WorkingDirectory $BarPath
    # wait until the launcher or the game shows up, then until both are gone
    $t0 = Get-Date
    while (-not (Get-Process -Name 'spring', 'Beyond-All-Reason' -ErrorAction SilentlyContinue) -and ((Get-Date) - $t0).TotalSeconds -lt 90) { Start-Sleep -Seconds 2 }
    while (Get-Process -Name 'spring', 'Beyond-All-Reason' -ErrorAction SilentlyContinue) { Start-Sleep -Seconds 3 }
} finally {
    Remove-Item $flag -Force -ErrorAction SilentlyContinue
}
