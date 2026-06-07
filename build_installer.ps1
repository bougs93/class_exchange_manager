# 수업 교체 도우미 - Inno Setup 설치 프로그램 빌드 (베타 만료일 포함)
#
# tool/build_installer.json 의 EXPIRY_DATE 가 exe에 컴파일됩니다.
# Inno Setup 6/7: https://jrsoftware.org/isinfo.php

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 수업 교체 도우미 - 설치 프로그램 빌드" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$configPath = Join-Path $PSScriptRoot "tool\build_installer.json"
if (-not (Test-Path $configPath)) {
    Write-Host "오류: $configPath 파일을 찾을 수 없습니다." -ForegroundColor Red
if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}

$config = Get-Content $configPath -Raw | ConvertFrom-Json
$expiryDate = $config.EXPIRY_DATE
if ([string]::IsNullOrWhiteSpace($expiryDate)) {
    Write-Host "오류: tool/build_installer.json 에 EXPIRY_DATE 가 필요합니다." -ForegroundColor Red
if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}

$appInfoPath = Join-Path $PSScriptRoot "lib\constants\app_info.dart"
$versionMatch = Select-String -Path $appInfoPath -Pattern "static const String version = '([^']+)';"
if (-not $versionMatch) {
    Write-Host "오류: app_info.dart 에서 version 을 찾을 수 없습니다." -ForegroundColor Red
if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}
$appVersion = $versionMatch.Matches[0].Groups[1].Value

Write-Host "버전: $appVersion" -ForegroundColor Gray
Write-Host "베타 만료일: $expiryDate" -ForegroundColor Gray
Write-Host ""

# Debug data → installer/bundled_user_data 동기화 (있으면 최신 시간표 반영)
$syncScript = Join-Path $PSScriptRoot "tool\sync_bundled_data.ps1"
if (Test-Path $syncScript) {
    Write-Host "[0/4] 번들 시간표 데이터 동기화..." -ForegroundColor Yellow
    & $syncScript
    if ($LASTEXITCODE -ne 0) {
        Write-Host "경고: 번들 데이터 동기화 실패 — 기존 bundled_user_data 사용" -ForegroundColor Yellow
    }
    Write-Host ""
}

Write-Host "[1/4] Flutter 의존성 확인 중..." -ForegroundColor Yellow
Push-Location $PSScriptRoot
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: Flutter 의존성 설치 실패" -ForegroundColor Red
    Pop-Location
if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}
Write-Host ""

Write-Host "[2/4] Windows 릴리즈 빌드 (만료일 포함)..." -ForegroundColor Yellow
flutter build windows --release --dart-define=EXPIRY_DATE=$expiryDate
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: 빌드 실패" -ForegroundColor Red
    Pop-Location
if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}
Write-Host ""

Write-Host "[3/4] 배포 폴더 생성 중..." -ForegroundColor Yellow
$distPath = Join-Path $PSScriptRoot "dist"
if (Test-Path $distPath) {
    Remove-Item -Recurse -Force $distPath
}
New-Item -ItemType Directory -Path $distPath | Out-Null
Copy-Item -Recurse -Force (Join-Path $PSScriptRoot "build\windows\x64\runner\Release\*") $distPath

# installer/bundled_user_data → dist (초기 JSON만, Excel 제외)
$bundledRoot = Join-Path $PSScriptRoot "installer\bundled_user_data"
if (Test-Path $bundledRoot) {
    $bundledDataDir = Join-Path $bundledRoot "data"
    $distDataDir = Join-Path $distPath "data"

    if (Test-Path $bundledDataDir) {
        Get-ChildItem $bundledDataDir -Filter "*.json" | ForEach-Object {
            Copy-Item $_.FullName (Join-Path $distDataDir $_.Name) -Force
        }
        Write-Host "  JSON 설정·시간표 데이터 포함됨 (Excel 제외)" -ForegroundColor Gray
    }
} else {
    Write-Host "  경고: installer\bundled_user_data 없음 — tool\sync_bundled_data.ps1 실행 권장" -ForegroundColor Yellow
}
Write-Host ""

Write-Host "[4/4] Inno Setup 컴파일 중..." -ForegroundColor Yellow
$isccCandidates = @(
    "$env:LOCALAPPDATA\Programs\Inno Setup 7\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 7\ISCC.exe",
    "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
    "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
)
$iscc = $isccCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) {
    Write-Host "오류: Inno Setup(ISCC.exe)을 찾을 수 없습니다." -ForegroundColor Red
    Write-Host "      Inno Setup 7: winget install --id JRSoftware.InnoSetup.7 -e" -ForegroundColor Yellow
    Write-Host "      또는 https://jrsoftware.org/isdl.php 에서 설치 후 다시 실행하세요." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "dist\ 폴더는 생성되었습니다 (만료일 포함 exe)." -ForegroundColor Cyan
    Pop-Location
if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}

Write-Host "Inno Setup: $iscc" -ForegroundColor Gray

$setupIss = Join-Path $PSScriptRoot "installer\setup.iss"
& $iscc "/DMyAppVersion=$appVersion" "/DEXPIRY_DATE=$expiryDate" $setupIss
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: Inno Setup 컴파일 실패" -ForegroundColor Red
    Pop-Location
if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}

Pop-Location

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host " 설치 프로그램 빌드 완료!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "배포 폴더: dist\" -ForegroundColor Cyan
Write-Host "설치 파일: installer\output\수업교체도우미_Setup_${appVersion}.exe" -ForegroundColor Cyan
Write-Host "베타 만료일: $expiryDate (exe + 설치 프로그램 모두 적용)" -ForegroundColor Yellow
Write-Host ""
if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
