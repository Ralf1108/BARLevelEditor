# Lobby before a hosted game (dot-sourced by start_scenario.ps1; needs player_mapping.ps1 for ConvertTo-PlayerName and the last mapping).
# The host sees one box per team; every player who joins lands in a team box at once (the team he had last time if it is free, otherwise the first
# team without a player) and the host moves them. The joiners only send their name; a joiner whose connection breaks is removed.
# Protocol (one text line each, UTF-8, TCP): joiner -> host: "HELLO <name>", "BYE", later "READY"; host -> joiner: "OK <name as the host
# knows it>" or "ERR <reason>", then "TEAM <n> <text>" and "ROSTER <name>=<team>;..." whenever something changes, at the end "START" (the
# joiners prepare: extra game, map) or "CANCEL"; when every joiner has said "READY" and the host's game is running the host sends "GO" and the
# joiners connect to it.
# The focus starts on "Start game" (the last box): Enter or F5 starts at once.
# Keys of the host: Tab / Shift+Tab or Left / Right = next box, Up / Down = player in the box, Enter = pick the player up (then Up / Down /
# Left / Right move him into the neighbouring box, Enter drops him, Esc brings him back), Enter on "Start game" (the last stop) or F5 = start,
# Esc twice = cancel.

function New-LobbyState($teamInfo, [string]$hostName, [int]$port) {
    return @{ Teams = @($teamInfo); HostName = $hostName; Port = $port; Addr = ''; Players = (New-Object Collections.ArrayList); Pending = (New-Object Collections.ArrayList)
              Focus = @($teamInfo).Count; Cursor = 0; Held = $null; HeldFrom = 0; Msg = ''; Info = ''; ConfirmCancel = $false; Dirty = $true; Done = $null }
}

function Get-BoxPlayers($st, [int]$box) { return @($st.Players | Where-Object { $_.Box -eq $box }) }

# The team of a new player: the one of the last mapping (by name) if nobody is there, otherwise the first team without a player, otherwise team 0
function Add-LobbyPlayer($st, [string]$name, $client) {
    $box = -1
    foreach ($e in @(Read-LastMapping)) {
        if ($e.Name.ToLower() -eq $name.ToLower() -and $e.Team -lt $st.Teams.Count -and @(Get-BoxPlayers $st $e.Team).Count -eq 0) { $box = $e.Team }
    }
    if ($box -lt 0) {
        for ($b = 0; $b -lt $st.Teams.Count; $b++) { if (@(Get-BoxPlayers $st $b).Count -eq 0) { $box = $b; break } }
    }
    if ($box -lt 0) { $box = 0 }
    $p = [pscustomobject]@{ Name = $name; Box = $box; Client = $client; Buf = (New-Object Text.StringBuilder); Sent = ''; Closed = $false }
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
    Add-L '' 0
    for ($b = 0; $b -lt $t; $b++) {
        Add-L ('{0} {1}' -f $(if ($st.Focus -eq $b) { '>' } else { ' ' }), $st.Teams[$b]) $(if ($st.Focus -eq $b) { 3 } else { 1 })
        $pl = @(Get-BoxPlayers $st $b)
        if ($pl.Count -eq 0) { Add-L '      (empty)' 2 }
        for ($i = 0; $i -lt $pl.Count; $i++) {
            $p = $pl[$i]
            $txt = '    ' + $p.Name + $(if ($p.Client -eq $null) { '  (host)' } else { '' })
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

# accepts new connections, reads the lines of everybody, drops the ones that went away and tells the joiners where they are
function Update-LobbyNet($st, $listener) {
    while ($listener.Pending()) {
        $c = $listener.AcceptTcpClient()
        [void]$st.Pending.Add([pscustomobject]@{ Client = $c; Buf = (New-Object Text.StringBuilder); Closed = $false; Name = $null; T = (Get-Date) })
    }
    foreach ($q in @($st.Pending)) {
        $hello = $null
        foreach ($l in @(Read-LobbyLines $q)) { if ($l -like 'HELLO *') { $hello = $l.Substring(6).Trim() } }
        if ($hello) {
            $nm = ConvertTo-PlayerName $hello
            $taken = @($st.Players | Where-Object { $_.Name.ToLower() -eq $nm.ToLower() }).Count -gt 0
            if (-not $nm) { Send-LobbyLine $q 'ERR The name has no usable letters.'; $q.Closed = $true }
            elseif ($taken) { Send-LobbyLine $q 'ERR That name is used already.'; $q.Closed = $true }
            else {
                Send-LobbyLine $q "OK $nm"
                [void](Add-LobbyPlayer $st $nm $q.Client)
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
        foreach ($l in @(Read-LobbyLines $p)) { if ($l -eq 'BYE') { $p.Closed = $true } }
        if ($p.Closed) { $st.Info = "$($p.Name) left."; Remove-LobbyPlayer $st $p; continue }
        $state = ('TEAM {0} {1}' -f $p.Box, $st.Teams[$p.Box]) + '|' + $roster
        if ($state -ne $p.Sent) { Send-LobbyLine $p ('TEAM {0} {1}' -f $p.Box, $st.Teams[$p.Box]); Send-LobbyLine $p "ROSTER $roster"; $p.Sent = $state }
    }
}

function New-LobbyKey([string]$key, [switch]$Shift) {
    $ch = switch ($key) { 'Enter' { [char]13 } 'Tab' { [char]9 } 'Escape' { [char]27 } default { [char]0 } }
    return New-Object ConsoleKeyInfo($ch, [ConsoleKey]$key, [bool]$Shift, $false, $false)
}

# The lobby of the host. Returns the roster (entries Name, Team; host first) when the host starts, $null when he cancels.
# $keyFeed (tests): keys (ConsoleKeyInfo) and numbers (wait in milliseconds) are used instead of the keyboard; $dumpFile: the last screen is written
# there instead of the console (no console needed); $timeoutSec: ends with a cancel after this time
function Invoke-HostLobby($teamInfo, [string]$hostName, [int]$port = 8453, $keyFeed = $null, [string]$dumpFile = $null, [int]$timeoutSec = 0, [int]$autoStart = 0) {
    $st = New-LobbyState $teamInfo $hostName $port
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
function Join-Lobby([string]$ip, [int]$port, [string]$name, [int]$timeoutSec = 0, [string]$dumpFile = $null) {
    $c = New-Object Net.Sockets.TcpClient
    $ar = $c.BeginConnect($ip, $port, $null, $null)
    if (-not $ar.AsyncWaitHandle.WaitOne(5000)) { $c.Close(); return 'noconnect' }
    try { $c.EndConnect($ar) } catch { $c.Close(); return 'noconnect' }
    $p = [pscustomobject]@{ Name = $name; Box = 0; Client = $c; Buf = (New-Object Text.StringBuilder); Sent = ''; Closed = $false }
    $script:JoinerLobby = $p; $script:JoinerName = $name
    Send-LobbyLine $p "HELLO $name"
    $console = -not $dumpFile
    $status = 'connecting ...'; $team = '-'; $roster = ''; $result = $null
    $until = if ($timeoutSec -gt 0) { (Get-Date).AddSeconds($timeoutSec) } else { [DateTime]::MaxValue }
    $dirty = $true
    try {
        if ($console) { Clear-Host; [Console]::CursorVisible = $false }
        while (-not $result) {
            foreach ($l in @(Read-LobbyLines $p)) {
                $dirty = $true
                if ($l -eq 'OK' -or $l -like 'OK *') { $status = 'waiting for the host to start the game'; if ($l.Length -gt 3) { $script:JoinerName = $l.Substring(3).Trim() } }
                elseif ($l -like 'ERR *') { $result = 'refused: ' + $l.Substring(4) }
                elseif ($l -like 'TEAM *') { $team = ($l.Substring(5) -replace '^\d+ ', '') }
                elseif ($l -like 'ROSTER *') { $roster = $l.Substring(7) }
                elseif ($l -eq 'START') { $result = 'start' }
                elseif ($l -eq 'CANCEL') { $result = 'cancel' }
            }
            if (-not $result -and $p.Closed) { $result = 'lost' }
            if (-not $result -and (Get-Date) -gt $until) { $result = 'left' }
            if (-not $result -and $console) {
                try { if ([Console]::KeyAvailable -and [Console]::ReadKey($true).Key -eq 'Escape') { Send-LobbyLine $p 'BYE'; $result = 'left' } } catch { }
            }
            if ($dirty) {
                $dirty = $false
                $who = ($roster -replace '=(\d+)', ' (team $1)') -replace ';', ', '
                $lines = @("Lobby of $($ip):$port - you are $name", '', "Status: $status", "Your team: $team", '', "Players: $who", '', 'Esc = leave')
                if ($console) { Show-LobbyLines ([pscustomobject]@{ Lines = $lines; Kinds = @(1, 0, 0, 7, 0, 0, 0, 2) }) }
                else { [IO.File]::WriteAllLines($dumpFile, [string[]]$lines) }
            }
            Start-Sleep -Milliseconds 40
        }
        return $result
    } finally {
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
