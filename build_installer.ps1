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

# Debug data → installer/bundled_user_data 동기화
$userDataSyncScript = Join-Path $PSScriptRoot "tool\user_data_sync.ps1"
$bundledJsonNames = @()
if (Test-Path $userDataSyncScript) {
    Write-Host "[0/4] Debug data → 번들 JSON 동기화..." -ForegroundColor Yellow
    . $userDataSyncScript
    try {
        $bundledJsonNames = @(Sync-BundledUserDataFromDebug)
    } catch {
        Write-Host "오류: $($_.Exception.Message)" -ForegroundColor Red
        if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
        exit 1
    }
    Write-Host ""
} else {
    Write-Host "오류: tool\user_data_sync.ps1 을 찾을 수 없습니다." -ForegroundColor Red
    if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
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

# Release exe + Debug flutter_windows.dll 조합은 시작 직후 종료(exit 1)됩니다.
$releaseFlutterDll = Join-Path $PSScriptRoot "build\windows\x64\runner\Release\flutter_windows.dll"
$debugFlutterDll = Join-Path $PSScriptRoot "build\windows\x64\runner\Debug\flutter_windows.dll"
$distFlutterDll = Join-Path $distPath "flutter_windows.dll"
if (-not (Test-Path $distFlutterDll)) {
    Write-Host "오류: dist\flutter_windows.dll 이 없습니다." -ForegroundColor Red
    Pop-Location
    if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}
if ((Test-Path $debugFlutterDll) -and ((Get-Item $distFlutterDll).Length -eq (Get-Item $debugFlutterDll).Length)) {
    Write-Host "오류: dist에 Debug용 flutter_windows.dll 이 포함되어 있습니다." -ForegroundColor Red
    Write-Host "      flutter build windows --release 를 다시 실행한 뒤 재시도하세요." -ForegroundColor Yellow
    Pop-Location
    if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}
if ((Get-FileHash $distFlutterDll -Algorithm SHA256).Hash -ne (Get-FileHash $releaseFlutterDll -Algorithm SHA256).Hash) {
    Write-Host "오류: dist\flutter_windows.dll 이 Release 빌드와 일치하지 않습니다." -ForegroundColor Red
    Pop-Location
    if ([Environment]::UserInteractive -and -not $env:CI) { Read-Host "Press Enter to exit" }
    exit 1
}

# Debug 기준 번들 JSON → dist (Release 잔여 구버전 JSON 제거)
$distDataDir = Join-Path $distPath "data"
Write-Host "  Debug 기준 JSON 적용 및 구버전 제거..." -ForegroundColor Gray
Apply-BundledJsonToDataDir -TargetDataDir $distDataDir -AllowedNames $bundledJsonNames
Write-Host "  JSON $($bundledJsonNames.Count)개 포함 (런타임 JSON·구버전 제외)" -ForegroundColor Gray

# Release data 폴더도 동일하게 정리 (다음 빌드 시 dist 오염 방지)
$releaseDataDir = Join-Path $PSScriptRoot "build\windows\x64\runner\Release\data"
if (Test-Path $releaseDataDir) {
    Apply-BundledJsonToDataDir -TargetDataDir $releaseDataDir -AllowedNames $bundledJsonNames | Out-Null
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
