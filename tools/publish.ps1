# Destiny Dawn 一键发布脚本
# 流程：提取版本号 -> Godot 无头导出 -> gh CLI 创建 GitHub Release 并上传资产
# 前置：Godot 4.7（含导出模板）、gh CLI（已登录：gh auth login）
# 用法：.\tools\publish.ps1            # 仅 Windows 单 exe
#       .\tools\publish.ps1 -Android   # 同时导出并上传 Android apk
#       .\tools\publish.ps1 -GodotExe "D:\Godot\godot.exe"

param(
    [switch]$Android,
    [string]$GodotExe = "godot"
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

# ---------- 1. 从 UpdateManager.gd 提取版本号 ----------
$versionMatch = Select-String -Path "Global\UpdateManager.gd" -Pattern 'const VERSION = "([^"]+)"' | Select-Object -First 1
if (-not $versionMatch) {
    throw "无法从 Global\UpdateManager.gd 提取 VERSION"
}
$Version = $versionMatch.Matches[0].Groups[1].Value
$Tag = "v$Version"
Write-Host "版本号: $Tag"

# ---------- 2. 前置检查 ----------
if (-not (Get-Command $GodotExe -ErrorAction SilentlyContinue)) {
    throw "未找到 Godot 可执行文件: $GodotExe（可用 -GodotExe 指定完整路径）"
}
if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
    throw "未找到 gh CLI，请先安装 https://cli.github.com/ 并执行 gh auth login"
}
gh auth status | Out-Null
if ($LASTEXITCODE -ne 0) {
    throw "gh 未登录，请先执行 gh auth login"
}

# ---------- 3. Godot 导出 ----------
Write-Host "导出 Windows（embed_pck 单 exe）..."
& $GodotExe --headless --export-release "Windows Desktop"
if ($LASTEXITCODE -ne 0) { throw "Windows 导出失败" }

$ExePath = "..\..\5652\DestinyDawn\release\DestinyDawn-v$Version\DestinyDawn-v$Version.exe"
if (-not (Test-Path $ExePath)) {
    throw "导出文件不存在: $ExePath"
}
$Assets = @($ExePath)
Write-Host "Windows 产物: $ExePath ($([math]::Round((Get-Item $ExePath).Length / 1MB)) MB)"

if ($Android) {
    Write-Host "导出 Android apk..."
    & $GodotExe --headless --export-release "Android"
    if ($LASTEXITCODE -ne 0) { throw "Android 导出失败" }
    $ApkPath = "..\..\5652\DestinyDawn\release\DestinyDawn-v$Version.apk"
    if (-not (Test-Path $ApkPath)) {
        throw "导出文件不存在: $ApkPath"
    }
    $Assets += $ApkPath
    Write-Host "Android 产物: $ApkPath"
}

# ---------- 4. 创建 Release ----------
Write-Host ""
$answer = Read-Host "确认发布 $Tag 到 GitHub Releases？(y/N)"
if ($answer -ne "y" -and $answer -ne "Y") {
    Write-Host "已取消"
    exit 1
}

$assetsArg = ($Assets | ForEach-Object { "`"$_`"" }) -join " "
$cmd = "gh release create $Tag $assetsArg --title `"$Tag`" --generate-notes --target master"
Write-Host "执行: $cmd"
Invoke-Expression $cmd
if ($LASTEXITCODE -ne 0) { throw "创建 Release 失败" }

Write-Host ""
Write-Host "发布完成: https://github.com/5652fsft/DestinyDawn/releases/tag/$Tag"