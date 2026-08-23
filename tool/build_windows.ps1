# class_exchange_manager Windows release build.
# Requires UTF-8 BOM encoding (Windows PowerShell 5.1 reads BOM-less files as CP949).
#
# 하는 일:
# 1) lib\constants\app_info.dart 의 AppInfo.version 을 읽어 --build-name 으로 넘긴다.
#    → class_exchange_manager.exe 속성(자세히)의 파일 버전 / 제품 버전에 들어간다.
# 2) dist\class_exchange_manager-<버전>-<날짜_시각>\ 폴더를 만들고
#    Release 산출물(dll·data 포함)을 통째로 복사한 뒤 VERSION.txt 를 기록한다.
# 3) 배포 복사는 1build_windows.bat 가 robocopy 로 수행한다.
#
# 사용: 프로젝트 루트에서
#   powershell -ExecutionPolicy Bypass -File tool\build_windows.ps1

$ErrorActionPreference = 'Stop'
if ([Console]::OutputEncoding.WebName -eq 'utf-8') {
    $OutputEncoding = [Console]::OutputEncoding
}

$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root

Write-Host ""
Write-Host "class_exchange_manager Windows 릴리스 빌드를 시작합니다."
Write-Host "버전은 lib\constants\app_info.dart 의 AppInfo.version 을 사용합니다."
Write-Host ""

function Read-AppVersion {
    $path = Join-Path $Root 'lib\constants\app_info.dart'
    $text = Get-Content -Raw -Path $path -Encoding UTF8
    $m = [regex]::Match($text, "static const String version\s*=\s*['""]([^'""]+)['""]")
    if (-not $m.Success) {
        throw "AppInfo.version 을 찾지 못했습니다: $path"
    }
    return $m.Groups[1].Value
}

$appVersion = Read-AppVersion
$builtAt    = Get-Date -Format 'yyyy-MM-dd HH:mm'
$dateStamp  = Get-Date -Format 'yyyy-MM-dd_HHmm'
$distName   = "class_exchange_manager-$appVersion-$dateStamp"
$distDir    = Join-Path $Root "dist\$distName"

Write-Host "앱 버전        : $appVersion"
Write-Host "빌드 시각      : $builtAt"
Write-Host "출력 폴더      : $distDir"
Write-Host ""

flutter build windows --release --build-name=$appVersion
if ($LASTEXITCODE -ne 0) {
    throw "flutter build windows 실패 (exit $LASTEXITCODE)"
}

$releaseDir = Join-Path $Root 'build\windows\x64\runner\Release'
$exeName = 'class_exchange_manager.exe'
if (-not (Test-Path (Join-Path $releaseDir $exeName))) {
    throw "빌드 산출물을 찾지 못했습니다: $releaseDir\$exeName"
}

if (Test-Path $distDir) {
    Remove-Item -Recurse -Force $distDir
}
New-Item -ItemType Directory -Path $distDir | Out-Null
Copy-Item -Path (Join-Path $releaseDir '*') -Destination $distDir -Recurse

$versionTxt = @"
class_exchange_manager (수업 교체 도우미 Beta)
Version: $appVersion
Built: $builtAt
Executable: $exeName
"@
Set-Content -Path (Join-Path $distDir 'VERSION.txt') -Value $versionTxt -Encoding utf8

$exe = Get-Item (Join-Path $distDir $exeName)
$info = $exe.VersionInfo
Write-Host ""
Write-Host "=== 파일 버전 정보 (탐색기 속성 → 자세히) ==="
Write-Host "ProductName    : $($info.ProductName)"
Write-Host "FileVersion    : $($info.FileVersion)"
Write-Host "ProductVersion : $($info.ProductVersion)"

# 마지막에 경로를 크게 안내한다. 초보 동료가 산출물을 못 찾는 일을 막기 위함.
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  빌드가 끝났습니다." -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "  실행 폴더 (이 폴더를 통째로 복사하세요):" -ForegroundColor Yellow
Write-Host "    $distDir" -ForegroundColor Green
Write-Host ""
Write-Host "  주의: exe 하나만 옮기면 실행되지 않습니다." -ForegroundColor Yellow
Write-Host "        dll 과 data 폴더가 반드시 함께 있어야 합니다." -ForegroundColor Yellow
Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan

# 탐색기에서 해당 폴더를 연다. 실패해도 빌드 전체를 실패로 보면 안 된다.
try {
    Invoke-Item -LiteralPath $distDir
} catch {
    Write-Host "탐색기를 열지 못했습니다: $distDir"
}
