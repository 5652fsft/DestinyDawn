# ============================================================
# Kill leftover LAN test processes ONLY (command line contains
# "--nettest"). NEVER touches the Godot editor or other apps.
# Usage: pwsh tests/kill_test_procs.ps1
# ============================================================
$killed = @()
Get-CimInstance Win32_Process -Filter "Name like 'godot%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match "--nettest" } |
    ForEach-Object {
        $killed += $_.ProcessId
        Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue
    }
if ($killed.Count -gt 0) {
    Write-Host "[kill] killed test procs: $($killed -join ', ')"
} else {
    Write-Host "[kill] no leftover test processes"
}

# Sanity: report any non-test godot processes (editor etc.) - do NOT touch them
$others = Get-CimInstance Win32_Process -Filter "Name like 'godot%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -notmatch "--nettest" }
if ($others) {
    Write-Host "[kill] NOTE: non-test godot processes left untouched:"
    $others | ForEach-Object { Write-Host "   pid=$($_.ProcessId) cmd=$($_.CommandLine)" }
}
