# LangIndicator 压缩脚本：把 publish 目录打包为 7z 并计算 SHA256
# 用法:
#   .\7z.ps1 -Version v1.0.0
# 工具链解析:
#   优先使用仓库同级 tools\7zip\7z.exe（便携版），否则使用系统 PATH 中的 7z。
param(
    [Parameter(Mandatory = $true)]
    [string]$Version
)

$ErrorActionPreference = "Stop"

$repoRoot = $PSScriptRoot
$toolsRoot = Join-Path $repoRoot "..\tools"
$portableSevenZip = Join-Path $toolsRoot "7zip\7z.exe"

$sevenZip = if (Test-Path -LiteralPath $portableSevenZip) { $portableSevenZip } else { "7z" }

$publishDir = Join-Path $repoRoot "publish"
if (-not (Test-Path -LiteralPath $publishDir)) {
    throw "发布目录不存在: $publishDir，请先运行 publish.ps1"
}

$archivePath = Join-Path $repoRoot "LangIndicator_${Version}_win-x64_7z.7z"
$hashPath = Join-Path $repoRoot "LangIndicator_${Version}_win-x64_sha256.txt"

# 删除可能存在的旧产物，保证打包内容为本次发布
if (Test-Path -LiteralPath $archivePath) { Remove-Item -LiteralPath $archivePath -Force }
if (Test-Path -LiteralPath $hashPath) { Remove-Item -LiteralPath $hashPath -Force }

Write-Host ""
Write-Host "压缩 publish 目录 -> $archivePath ..."
& $sevenZip a -t7z -y $archivePath "$publishDir\*"
if ($LASTEXITCODE -ne 0) {
    throw "7z 压缩失败，退出码 $LASTEXITCODE"
}

Write-Host ""
Write-Host "计算 SHA256 ..."
$hashOutput = & $sevenZip h -scrcsha256 $archivePath 2>&1
if ($LASTEXITCODE -ne 0) {
    throw "SHA256 计算失败，退出码 $LASTEXITCODE"
}
$hashLine = $hashOutput | Where-Object { $_ -match '^SHA256 for data:' } | Select-Object -First 1
if (-not $hashLine) {
    throw "未能从 7z 输出中解析 SHA256"
}
$hash = if ($hashLine -match 'SHA256 for data:\s+([0-9a-fA-F]+)') { $Matches[1] } else { throw "SHA256 格式无法解析: $hashLine" }
# 输出 sha256sum 风格: "<哈希>  <文件名>"
"$hash  $(Split-Path -Leaf $archivePath)" | Set-Content -LiteralPath $hashPath -Encoding ascii

Write-Host ""
Write-Host "========================================"
Write-Host "压缩与 SHA256 计算成功:"
Write-Host "  $archivePath"
Write-Host "  $hashPath"
Write-Host "========================================"
