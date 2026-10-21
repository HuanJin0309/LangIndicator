# LangIndicator 发布脚本
# 用法:
#   .\publish.ps1                      # 按 csproj 中现有版本发布并压缩
#   .\publish.ps1 -Version v1.0.0      # 同步版本号到 csproj 后发布并压缩
# 工具链解析:
#   优先使用仓库同级 tools 目录下的便携工具链 (tools\dotnet / tools\7zip)，
#   不存在时回退到系统 PATH 中的 dotnet / 7z（适用于 GitHub Actions 等环境）。
param(
    [string]$Version
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$main = Join-Path $repoRoot "src\LangIndicator\LangIndicator.csproj"
$mainProfile = Join-Path $repoRoot "src\LangIndicator\Properties\PublishProfiles\FolderProfile.pubxml"
$publishDir = Join-Path $repoRoot "publish"
$toolsRoot = Join-Path $repoRoot "..\tools"

# ---------- 解析便携工具链 ----------
$portableDotnet = Join-Path $toolsRoot "dotnet\dotnet.exe"
$portableNugetConfig = Join-Path $toolsRoot "nuget.config"
$portableSevenZip = Join-Path $toolsRoot "7zip\7z.exe"

$dotnet = if (Test-Path -LiteralPath $portableDotnet) { $portableDotnet } else { "dotnet" }

if (Test-Path -LiteralPath $portableDotnet) {
    # 便携 SDK：把用户级目录重定向到工作区，避免写入系统用户目录
    $env:DOTNET_CLI_HOME = Join-Path $toolsRoot "dotnet-home"
    $env:APPDATA = Join-Path $toolsRoot "appdata"
    $env:LOCALAPPDATA = Join-Path $toolsRoot "localappdata"
    $env:NUGET_PACKAGES = Join-Path $toolsRoot "nuget-packages"
    $env:DOTNET_SKIP_FIRST_TIME_EXPERIENCE = "1"
    $env:DOTNET_CLI_TELEMETRY_OPTOUT = "1"
}

# ---------- 版本处理 ----------
function Get-CleanVersion([string]$version) {
    $v = $version.TrimStart('v', 'V')
    if ($v -notmatch '^\d+\.\d+\.\d+$') {
        throw "无效的版本号: '$version'（示例: 1.0.0 或 v1.0.0）"
    }
    return $v
}

$releaseVersion = $null   # 用于 7z 文件名的版本（保留原始写法，如 v1.0.0）
if ($Version) {
    $releaseVersion = $Version
    $cleanVersion = Get-CleanVersion $Version
    # 同步 csproj 中的程序集版本
    $csprojContent = [System.IO.File]::ReadAllText($main)
    if ($csprojContent -notmatch '<AssemblyVersion>') {
        throw "csproj 中未找到 <AssemblyVersion>，无法同步版本"
    }
    $csprojContent = $csprojContent -replace '<AssemblyVersion>[^<]*</AssemblyVersion>', "<AssemblyVersion>$cleanVersion</AssemblyVersion>"
    $csprojContent = $csprojContent -replace '<FileVersion>[^<]*</FileVersion>', "<FileVersion>$cleanVersion</FileVersion>"
    [System.IO.File]::WriteAllText($main, $csprojContent)
    Write-Host "版本已同步: AssemblyVersion/FileVersion -> $cleanVersion"
}
else {
    $m = [regex]::Match([System.IO.File]::ReadAllText($main), '<AssemblyVersion>([^<]*)</AssemblyVersion>')
    $cleanVersion = if ($m.Success) { $m.Groups[1].Value } else { "0.0.1" }
    $releaseVersion = $cleanVersion
    Write-Host "未指定版本，使用 csproj 中的版本: $cleanVersion"
}

# ---------- 清理旧发布目录 ----------
if (Test-Path -LiteralPath $publishDir) {
    Write-Host "[Cache] 删除旧发布目录 $publishDir ..."
    Remove-Item -LiteralPath $publishDir -Recurse -Force
    Write-Host "[Cache] 已删除 $publishDir"
}
else {
    Write-Host "[Cache] $publishDir 不存在，无需清理"
}

# ---------- 发布 ----------
Write-Host ""
Write-Host "========================================"
Write-Host "开始发布 $main"
Write-Host "========================================"

$restoreArgs = @()
if (Test-Path -LiteralPath $portableNugetConfig) {
    $restoreArgs = @("-p:RestoreConfigFile=$portableNugetConfig")
}

& $dotnet publish $main -c Release "-p:PublishProfile=$mainProfile" @restoreArgs
if ($LASTEXITCODE -ne 0) {
    throw "dotnet publish 失败，退出码 $LASTEXITCODE"
}

Write-Host "========================================"
Write-Host "发布完成。"
Write-Host "========================================"

# ---------- 压缩并计算 SHA256 ----------
$sevenZipScript = Join-Path $repoRoot "7z.ps1"
& $sevenZipScript -Version $releaseVersion
if ($LASTEXITCODE -ne 0) {
    throw "7z.ps1 执行失败，退出码 $LASTEXITCODE"
}

Write-Host ""
Write-Host "发布流程全部完成。"
