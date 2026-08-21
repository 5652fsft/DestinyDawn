# ============================================================
# 联机开局同步测试运行器（配合 Global/NetTest.gd 临时探针）
# 用法:  pwsh tests/run_case.ps1 -Scenario s0|s1|s1full|s2|s3
# 会清理残留的测试 Godot 进程（命令行含 destiny-dawn 与 --nettest）
# ============================================================
param(
    [string]$Scenario = "s0",
    [string]$Godot = "C:/Program Files (x86)/Steam/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe",
    [string]$Project = "C:/Users/10932/Documents/GodotProject/destiny-dawn",
    [string]$LogDir = "tests/logs"
)

$hostTag = "s0"; $clientTag = "s0"
switch ($Scenario) {
    "s1"    { $hostTag = "s1";    $clientTag = "s0" }
    "s1full"{ $hostTag = "s1full";$clientTag = "s0" }
    "s2"    { $hostTag = "s0";    $clientTag = "s2" }
    "s3"    { $hostTag = "s0";    $clientTag = "s3" }
    "s4"    { $hostTag = "s0";    $clientTag = "s4" }
    "s5"    { $hostTag = "s0";    $clientTag = "s5" }
    "s6"    { $hostTag = "s0";    $clientTag = "s6" }
    "s7"    { $hostTag = "s0";    $clientTag = "s7" }
    "s8"    { $hostTag = "s8";    $clientTag = "s8" }
    "s9"    { $hostTag = "s9";    $clientTag = "s9" }
    "s11"   { $hostTag = "s11";   $clientTag = "s0" }
    "s12"   { $hostTag = "s12";   $clientTag = "s0" }
    default { $Scenario = "s0" }
}

New-Item -ItemType Directory -Force -Path $LogDir | Out-Null
$hostLog = Join-Path $LogDir "${Scenario}_host.log"
$clientLog = Join-Path $LogDir "${Scenario}_client.log"
$hostErr = Join-Path $LogDir "${Scenario}_host.err.log"
$clientErr = Join-Path $LogDir "${Scenario}_client.err.log"
Remove-Item $hostLog, $clientLog, $hostErr, $clientErr -ErrorAction SilentlyContinue

# 清理上次残留的测试进程（仅匹配命令行含 --nettest 的 godot 进程，
# 绝不触碰 Godot 编辑器/其他进程；进程名不含 .exe 后缀）
Get-CimInstance Win32_Process -Filter "Name like 'godot%'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -match "--nettest" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Start-Sleep -Milliseconds 500

Write-Host "[runner] 场景 $Scenario : host=$hostTag client=$clientTag"

$hostProc = Start-Process -FilePath $Godot -ArgumentList "--headless", "--path", $Project, "--nettest=host:$hostTag" `
    -RedirectStandardOutput $hostLog -RedirectStandardError $hostErr -PassThru -NoNewWindow
Write-Host "[runner] host 已启动 pid=$($hostProc.Id)，等待 2 秒后启动 client..."
Start-Sleep -Seconds 2

$clientProc = Start-Process -FilePath $Godot -ArgumentList "--headless", "--path", $Project, "--nettest=client:$clientTag" `
    -RedirectStandardOutput $clientLog -RedirectStandardError $clientErr -PassThru -NoNewWindow
Write-Host "[runner] client 已启动 pid=$($clientProc.Id)"

$deadline = (Get-Date).AddMinutes(11)
while ((Get-Date) -lt $deadline) {
    $hostExited = $hostProc.HasExited
    $clientExited = $clientProc.HasExited
    if ($hostExited -and $clientExited) { break }
    if ($hostExited -and -not $clientExited) {
        Write-Host "[runner] host 已退出(码 $($hostProc.ExitCode))，等待 client..."
    }
    if ($clientExited -and -not $hostExited) {
        Write-Host "[runner] client 已退出(码 $($clientProc.ExitCode))，等待 host..."
    }
    Start-Sleep -Seconds 5
}

$hostProc.WaitForExit(5000) | Out-Null
$clientProc.WaitForExit(5000) | Out-Null
$hostCode = if ($hostProc.HasExited) { $hostProc.ExitCode } else { Stop-Process -Id $hostProc.Id -Force -ErrorAction SilentlyContinue; "KILLED" }
$clientCode = if ($clientProc.HasExited) { $clientProc.ExitCode } else { Stop-Process -Id $clientProc.Id -Force -ErrorAction SilentlyContinue; "KILLED" }
Write-Host "[runner] 完成: host=$hostCode client=$clientCode"
Write-Host "[runner] 日志: $hostLog / $clientLog"
exit 0
