# ============================================================
# Mount LAN test probe (tests/NetTest.gd) as autoload.
# Usage: pwsh tests/mount_probe.ps1
# Auto-rebuilds the mount comment if missing, then verifies.
# NOTE: modifying project.godot while the Godot editor is open
# will trigger an external-change prompt in the editor.
# ============================================================
$ErrorActionPreference = "Stop"
$proj = Join-Path (Split-Path $PSScriptRoot -Parent) "project.godot"

# Warn if the Godot editor is running (never touch it)
$editors = Get-CimInstance Win32_Process -Filter "Name like 'godot%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -notmatch "--nettest" }
if ($editors) {
    Write-Host "[mount] WARNING: Godot editor is running (pid $($editors.ProcessId -join ','))."
    Write-Host "        project.godot will change; editor may prompt to reload project settings."
}

$content = [System.IO.File]::ReadAllText($proj)
$mountLine = 'NetTest="*res://tests/NetTest.gd"'
$commentLine = '; NetTest="*res://tests/NetTest.gd"'
$nl = if ($content.Contains("`r`n")) { "`r`n" } else { "`n" }
$lines = $content -split "`r?`n"
$hasMount = $lines -contains $mountLine
$hasComment = $lines -contains $commentLine

if ($hasMount) {
    Write-Host "[mount] already mounted"
} elseif ($hasComment) {
    $content = $content.Replace($commentLine, $mountLine)
    [System.IO.File]::WriteAllText($proj, $content)
    Write-Host "[mount] uncommented"
} else {
    $anchor = "[autoload]" + $nl + $nl
    $ins = $anchor + "; LAN test probe (tests/NetTest.gd). Uncomment next line to mount:" + $nl + $commentLine + $nl
    $content = $content.Replace($anchor, $ins)
    [System.IO.File]::WriteAllText($proj, $content)
    Write-Host "[mount] inserted"
}

$checkLines = ([System.IO.File]::ReadAllText($proj)) -split "`r?`n"
if ($checkLines -contains $mountLine -and -not ($checkLines -contains $commentLine)) {
    Write-Host "[mount] OK"
} else {
    Write-Host "[mount] FAILED - autoload section:"
    Select-String -Path $proj -Pattern "autoload|NetTest" -Encoding UTF8 | ForEach-Object { $_.Line }
    exit 1
}
