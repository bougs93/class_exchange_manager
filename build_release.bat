@echo off
chcp 65001 >nul
echo ========================================
echo  수업 교체 관리자 - Windows 릴리즈 빌드
echo ========================================
echo.

echo [1/3] Flutter 의존성 확인 중...
call flutter pub get
if errorlevel 1 (
    echo 오류: Flutter 의존성 설치 실패
    pause
    exit /b 1
)
echo.

echo [2/3] Windows 릴리즈 빌드 중...
call flutter build windows --release
if errorlevel 1 (
    echo 오류: 빌드 실패
    pause
    exit /b 1
)
echo.

echo [3/3] 배포 폴더 생성 중...
if exist dist rmdir /s /q dist
mkdir dist
xcopy /E /I /Y /Q build\windows\x64\runner\Release dist\ >nul
if errorlevel 1 (
    echo 오류: 배포 폴더 생성 실패
    pause
    exit /b 1
)
echo.

echo ========================================
echo  빌드 완료!
echo ========================================
echo.
echo 배포 폴더: dist\
echo 실행 파일: dist\class_exchange_manager.exe
echo.
echo 이 폴더 전체를 배포하시면 됩니다.
echo.
pause

