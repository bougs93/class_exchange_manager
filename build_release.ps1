# 수업 교체 도우미 - Windows 릴리즈 빌드 스크립트 (PowerShell)
Write-Host "========================================" -ForegroundColor Cyan
Write-Host " 수업 교체 도우미 - Windows 릴리즈 빌드" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "[1/3] Flutter 의존성 확인 중..." -ForegroundColor Yellow
flutter pub get
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: Flutter 의존성 설치 실패" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

Write-Host "[2/3] Windows 릴리즈 빌드 중..." -ForegroundColor Yellow
flutter build windows --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: 빌드 실패" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

Write-Host "[3/3] 배포 폴더 생성 중..." -ForegroundColor Yellow
if (Test-Path "dist") {
    Remove-Item -Recurse -Force "dist"
}
New-Item -ItemType Directory -Path "dist" | Out-Null
Copy-Item -Recurse -Force "build\windows\x64\runner\Release\*" "dist\"
if ($LASTEXITCODE -ne 0) {
    Write-Host "오류: 배포 폴더 생성 실패" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}
Write-Host ""

Write-Host "========================================" -ForegroundColor Green
Write-Host " 빌드 완료!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "배포 폴더: dist\" -ForegroundColor Cyan
Write-Host "실행 파일: dist\class_exchange_manager.exe" -ForegroundColor Cyan
Write-Host ""
Write-Host "이 폴더 전체를 배포하시면 됩니다." -ForegroundColor Yellow
Write-Host ""
Read-Host "Press Enter to exit"

