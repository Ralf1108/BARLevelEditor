# Who plays which team in a hosted game (dot-sourced by start_scenario.ps1 and by choose_map.ps1 of the Level Editor).
# The mapping (player name = team number, the first entry is the host) is shown, every line can be edited, and the last one used is kept for
# every scenario of the user in %LOCALAPPDATA%\BAR-Scenario\Last Player Mapping.txt (not in the scenario folder).
$script:MappingFile = Join-Path $env:LOCALAPPDATA 'BAR-Scenario\Last Player Mapping.txt'

# a name the engine accepts (letters, digits, _ - [ ])
function ConvertTo-PlayerName([string]$n) { return ($n -replace '[^A-Za-z0-9_\-\[\]]', '') }

function Read-LastMapping {
    $res = @()
    if (Test-Path $script:MappingFile) {
        foreach ($l in Get-Content $script:MappingFile) {
            $m = [regex]::Match($l, '^\s*([A-Za-z0-9_\-\[\]]+)\s*=\s*(\d+)\s*$')
            if ($m.Success) { $res += [pscustomobject]@{ Name = $m.Groups[1].Value; Team = [int]$m.Groups[2].Value } }
        }
    }
    return $res
}

function Save-Mapping($entries) {
    New-Item -ItemType Directory -Force (Split-Path $script:MappingFile) | Out-Null
    Set-Content -Path $script:MappingFile -Value @($entries | ForEach-Object { '{0}={1}' -f $_.Name, $_.Team }) -Encoding ASCII
}

# "Ralf=0,Player2=1" (the form of the parameter -Mapping) -> entries
function ConvertFrom-MappingText([string]$text) {
    $res = @()
    foreach ($p in $text.Split(',', [StringSplitOptions]::RemoveEmptyEntries)) {
        $m = [regex]::Match($p, '^\s*([A-Za-z0-9_\-\[\]]+)\s*=\s*(\d+)\s*$')
        if (-not $m.Success) { throw "Mapping entry '$p' is not Name=Team." }
        $res += [pscustomobject]@{ Name = $m.Groups[1].Value; Team = [int]$m.Groups[2].Value }
    }
    return $res
}
function ConvertTo-MappingText($entries) { return (@($entries | ForEach-Object { '{0}={1}' -f $_.Name, $_.Team }) -join ',') }

# The teams of a start script: one text per team ("Team 1: Cortex, ally team 1")
function Get-TeamInfo([string]$scriptText) {
    $res = @()
    foreach ($m in [regex]::Matches($scriptText, '(?s)\[team(\d+)\]\s*\{(.*?)\}')) {
        $side = [regex]::Match($m.Groups[2].Value, '(?i)Side=([^;]*);').Groups[1].Value
        $ally = [regex]::Match($m.Groups[2].Value, '(?i)AllyTeam=(\d+);').Groups[1].Value
        $res += ('Team {0}: {1}, ally team {2}' -f $m.Groups[1].Value, $side, $ally)
    }
    return $res
}

# The mapping for $count humans: starts from the last one used (missing or invalid entries are filled with PlayerK and a free team), shows it and
# lets the user edit single lines. Returns the entries (first = host); Enter on the question accepts.
function Get-PlayerMapping([int]$count, $teamInfo, [string]$hostName) {
    $teamCount = @($teamInfo).Count
    $last = @(Read-LastMapping)
    $entries = @(); $usedTeams = @{}; $usedNames = @{}
    for ($i = 0; $i -lt $count; $i++) {
        $nm = $null; $tm = $null
        if ($i -lt $last.Count) { $nm = $last[$i].Name; $tm = $last[$i].Team }
        if (-not $nm -or $usedNames.ContainsKey($nm.ToLower())) { $nm = if ($i -eq 0) { $hostName } else { "Player$($i + 1)" } }
        if ($usedNames.ContainsKey($nm.ToLower())) { $nm = "Player$($i + 1)" }
        if ($null -eq $tm -or $tm -ge $teamCount -or $usedTeams.ContainsKey($tm)) {
            $tm = 0; while ($usedTeams.ContainsKey($tm)) { $tm++ }
        }
        $usedTeams[$tm] = $true; $usedNames[$nm.ToLower()] = $true
        $entries += [pscustomobject]@{ Name = $nm; Team = $tm }
    }
    while ($true) {
        Write-Host ''
        Write-Host 'Who plays which team (the other teams keep their computer opponent):' -ForegroundColor Cyan
        for ($i = 0; $i -lt $entries.Count; $i++) {
            Write-Host ('  {0}) {1,-16} -> team {2}   ({3}){4}' -f ($i + 1), $entries[$i].Name, $entries[$i].Team, ($teamInfo[$entries[$i].Team] -replace '^Team \d+: ', ''), $(if ($i -eq 0) { '   host' } else { '' }))
        }
        Write-Host ('  Teams in the scenario: 0 to {0}' -f ($teamCount - 1)) -ForegroundColor DarkGray
        $in = (Read-Host 'Enter = start, a line number = edit that line').Trim()
        if (-not $in) { break }
        $n = 0
        if (-not ([int]::TryParse($in, [ref]$n) -and $n -ge 1 -and $n -le $entries.Count)) { Write-Host 'Not a line number.' -ForegroundColor Yellow; continue }
        $e = $entries[$n - 1]
        $nn = ConvertTo-PlayerName ((Read-Host "Name of line $n (Enter = $($e.Name))").Trim())
        if ($nn) {
            if (@($entries | Where-Object { $_ -ne $e -and $_.Name.ToLower() -eq $nn.ToLower() }).Count -gt 0) { Write-Host 'That name is used already.' -ForegroundColor Yellow } else { $e.Name = $nn }
        }
        $tt = (Read-Host "Team of line $n, 0 to $($teamCount - 1) (Enter = $($e.Team))").Trim()
        $tn = 0
        if ($tt) {
            if (-not ([int]::TryParse($tt, [ref]$tn) -and $tn -ge 0 -and $tn -lt $teamCount)) { Write-Host 'Not a team of this scenario.' -ForegroundColor Yellow }
            else {
                # a team that another player has is swapped with the team of this line
                $other = @($entries | Where-Object { $_ -ne $e -and $_.Team -eq $tn })
                if ($other.Count -gt 0) { $other[0].Team = $e.Team }
                $e.Team = $tn
            }
        }
    }
    Save-Mapping $entries
    return $entries
}
