# ============================================================
# Unmount LAN test probe (tests/NetTest.gd) autoload.
# Usage: pwsh tests/unmount_probe.ps1
# Restores the commented mount line (probe file stays reusable).
# NOTE: modifying project.godot while the Godot editor is open
# will trigger an external-change prompt in the editor.
# ============================================================
$ErrorActionPreference = "Stop"
$proj = Join-Path (Split-Path $PSScriptRoot -Parent) "project.godot"

# Warn if the Godot editor is running (never touch it)
$editors = Get-CimInstance Win32_Process -Filter "Name like 'godot%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -notmatch "--nettest" }
if ($editors) {
    Write-Host "[unmount] WARNING: Godot editor is running (pid $($editors.ProcessId -join ','))."
    Write-Host "        project.godot will change; editor may prompt to reload project settings."
}

$content = [System.IO.File]::ReadAllText($proj)
$mountLine = 'NetTest="*res://tests/NetTest.gd"'
$commentLine = '; NetTest="*res://tests/NetTest.gd"'
$lines = $content -split "`r?`n"
$hasMount = $lines -contains $mountLine
$hasComment = $lines -contains $commentLine

if (-not $hasMount) {
    Write-Host "[unmount] already unmounted"
} else {
    $content = $content.Replace($mountLine, $commentLine)
    [System.IO.File]::WriteAllText($proj, $content)
    Write-Host "[unmount] commented"
}

$checkLines = ([System.IO.File]::ReadAllText($proj)) -split "`r?`n"
if ($checkLines -contains $commentLine -and -not ($checkLines -contains $mountLine)) {
    Write-Host "[unmount] OK"
} else {
    Write-Host "[unmount] FAILED"
    Select-String -Path $proj -Pattern "autoload|NetTest" -Encoding UTF8 | ForEach-Object { $_.Line }
    exit 1
}
