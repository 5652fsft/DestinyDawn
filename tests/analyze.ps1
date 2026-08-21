# ============================================================
# LAN game dual-end log analyzer (tests/analyze.ps1)
# Usage:  pwsh tests/analyze.ps1 [-Scenario s0] [-LogDir tests/logs]
# Compares host/client logs for:
#   1. Settlement consistency (winner string + BATTLE-OVER both ends)
#   2. Server-side attack guard rejections (drift evidence)
#   3. HP drift between ends (sampled; may include sampling skew, see #4)
#   4. Final-state comparison from BATTLE-OVER snapshots (authoritative)
# NOTE: ASCII-only on purpose (avoids PS encoding issues with BOM-less files).
# ============================================================
param(
    [string]$Scenario = "s0",
    [string]$LogDir = "tests/logs"
)

$hostLog = Join-Path $LogDir "${Scenario}_host.log"
$clientLog = Join-Path $LogDir "${Scenario}_client.log"
if (-not (Test-Path $hostLog) -or -not (Test-Path $clientLog)) {
    Write-Host "[analyze] logs not found: $hostLog / $clientLog"
    exit 1
}

function Get-LastWinner($logPath) {
    $win = ""
    $lines = Get-Content $logPath -Encoding UTF8
    foreach ($line in $lines) {
        if ($line -match '\[Phase\]') {
            $tokens = $line -split ' '
            if ($tokens.Count -gt 0) { $win = $tokens[$tokens.Count - 1] }
        }
    }
    return $win
}

function Get-HpSamples($logPath) {
    $samples = @()
    $lines = Get-Content $logPath -Encoding UTF8
    foreach ($line in $lines) {
        if ($line -match 't=([\d.]+) phase=\S+ host_turn=\S+ my_turn=\S+ chars=\d+ (\[.*\])') {
            $t = [double]$Matches[1]
            $chars = @{}
            $listStr = $Matches[2]
            foreach ($m in [regex]::Matches($listStr, '([A-Za-z0-9_@]+)\(hp(\d+)\)')) {
                $chars[$m.Groups[1].Value] = [int]$m.Groups[2].Value
            }
            $samples += @{ t = $t; chars = $chars }
        }
    }
    return $samples
}

function Get-FinalChars($logPath) {
    $chars = @{}
    $lines = Get-Content $logPath -Encoding UTF8
    $inSnap = $false
    foreach ($line in $lines) {
        if ($line -match 'NetTest\] ====') { $inSnap = $true; continue }
        if ($inSnap) {
            if ($line -match '(\S+) hp=(\d+) pos=') {
                $chars[$Matches[1]] = [int]$Matches[2]
            } elseif ($line -match 'NetTest\] (t=|位置|====)') {
                break
            }
        }
    }
    return $chars
}

Write-Host "===== analyze scenario $Scenario ====="

# 1. settlement consistency
$hostWin = Get-LastWinner $hostLog
$clientWin = Get-LastWinner $clientLog
$hostOver = (Select-String -Path $hostLog -Pattern 'BATTLE-OVER' -Encoding UTF8).Count -gt 0
$clientOver = (Select-String -Path $clientLog -Pattern 'BATTLE-OVER' -Encoding UTF8).Count -gt 0
Write-Host "1) settlement: host=$hostWin (over=$hostOver) client=$clientWin (over=$clientOver)"
if ($hostWin -and $clientWin -and $hostWin -ne $clientWin) {
    Write-Host "   [!!] WINNER MISMATCH - both ends show victory"
} elseif ($hostOver -ne $clientOver) {
    Write-Host "   [!!] SETTLEMENT STATE MISMATCH"
} else {
    Write-Host "   [OK] settlement consistent"
}

# 2. attack guard rejections
Write-Host ""
Write-Host "2) attack guard rejections:"
$rejects = @{}
foreach ($log in @($hostLog, $clientLog)) {
    Select-String -Path $log -Pattern 'AttackDebug\] (SERVER|CLIENT) REJECT (\w+)' -Encoding UTF8 | ForEach-Object {
        $side = $_.Matches[0].Groups[1].Value
        $reason = $_.Matches[0].Groups[2].Value
        $key = "$side/$reason"
        if (-not $rejects.ContainsKey($key)) { $rejects[$key] = 0 }
        $rejects[$key] += 1
    }
}
if ($rejects.Count -eq 0) { Write-Host "   none" }
foreach ($k in ($rejects.Keys | Sort-Object)) {
    Write-Host "   $k = $($rejects[$k])"
}
$serverRejectTotal = ($rejects.GetEnumerator() | Where-Object { $_.Key -like "SERVER/*" } | Measure-Object -Property Value -Sum).Sum
if ($serverRejectTotal -gt 0) {
    Write-Host "   [!!] server rejected $serverRejectTotal times"
} else {
    Write-Host "   [OK] server zero rejection"
}

# 3. hp drift (sampled; reference only - sampling skew possible)
Write-Host ""
Write-Host "3) hp drift (sampled, reference):"
$hostSamples = Get-HpSamples $hostLog
$clientSamples = Get-HpSamples $clientLog
$driftEvents = @()
foreach ($hs in $hostSamples) {
    foreach ($cs in $clientSamples) {
        if ([Math]::Abs($hs.t - $cs.t) -gt 3.0) { continue }
        foreach ($name in $hs.chars.Keys) {
            if ($cs.chars.ContainsKey($name)) {
                $diff = $hs.chars[$name] - $cs.chars[$name]
                if ([Math]::Abs($diff) -gt 0) {
                    $driftEvents += [PSCustomObject]@{ t = $hs.t; name = $name; host = $hs.chars[$name]; client = $cs.chars[$name]; diff = $diff }
                }
            }
        }
        break
    }
}
if ($driftEvents.Count -eq 0) {
    Write-Host "   none"
} else {
    Write-Host "   $($driftEvents.Count) events; max: " -NoNewline
    $maxDrift = $driftEvents | Sort-Object { [Math]::Abs($_.diff) } -Descending | Select-Object -First 1
    Write-Host ("t={0} {1} host={2} client={3} diff={4}" -f $maxDrift.t, $maxDrift.name, $maxDrift.host, $maxDrift.client, $maxDrift.diff)
}

# 4. final-state comparison (authoritative)
Write-Host ""
Write-Host "4) final state (BATTLE-OVER snapshot) comparison:"
$hostFinal = Get-FinalChars $hostLog
$clientFinal = Get-FinalChars $clientLog
$allNames = @($hostFinal.Keys + $clientFinal.Keys | Select-Object -Unique)
$mismatch = 0
foreach ($n in $allNames) {
    $h = if ($hostFinal.ContainsKey($n)) { $hostFinal[$n] } else { -1 }
    $c = if ($clientFinal.ContainsKey($n)) { $clientFinal[$n] } else { -1 }
    if ($h -ne $c) {
        $mismatch++
        Write-Host ("   [!!] {0}: host={1} client={2}" -f $n, $h, $c)
    }
}
if ($mismatch -eq 0) {
    Write-Host "   [OK] final states identical"
} else {
    Write-Host "   [!!] $mismatch final-state mismatches"
}

# 5. unregister info (server-only log; informational)
Write-Host ""
Write-Host "5) host unregister count (server-only, informational):"
$hostUnreg = (Select-String -Path $hostLog -Pattern 'unregister char=' -Encoding UTF8 | Where-Object { $_.Line -notmatch 'skip battle_over' }).Count
Write-Host "   $hostUnreg"

Write-Host ""
Write-Host "===== done ====="
