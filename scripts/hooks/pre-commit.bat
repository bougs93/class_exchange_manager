@echo off
REM Pre-commit: bump app version + build stamp and stage them.
REM Called by scripts/hooks/pre-commit (sh shim) or by the universal-git.exe
REM wrapper (Cursor commit button convention: <root>\scripts\hooks\pre-commit.bat).
setlocal
cd /d "%~dp0\..\.."

if not exist ".dart_tool" mkdir ".dart_tool"
>> ".dart_tool\version-hook.log" echo %DATE% %TIME% pre-commit start

REM Skip entirely when explicitly disabled (wrapper and hook both honor this).
if defined SKIP_APP_VERSION_BUMP (
  exit /b 0
)

REM Already bumped and staged for this commit? Skip (avoid double bump).
git diff --cached -- lib/constants/app_info.dart | findstr /R /C:"^+.*static const String version" >nul
if not errorlevel 1 (
  exit /b 0
)

set "DART_BAT="
if exist "C:\dev\flutter\bin\dart.bat" set "DART_BAT=C:\dev\flutter\bin\dart.bat"
if not defined DART_BAT if defined FLUTTER_ROOT if exist "%FLUTTER_ROOT%\bin\dart.bat" set "DART_BAT=%FLUTTER_ROOT%\bin\dart.bat"
if not defined DART_BAT if exist "%LOCALAPPDATA%\flutter\bin\dart.bat" set "DART_BAT=%LOCALAPPDATA%\flutter\bin\dart.bat"

if defined DART_BAT (
  call "%DART_BAT%" run tool/bump_version.dart
) else (
  dart run tool/bump_version.dart
)
if errorlevel 1 (
  echo pre-commit: failed to bump version. >&2
  echo   try: dart run tool/bump_version.dart >&2
  exit /b 1
)
git add lib\constants\app_info.dart pubspec.yaml
exit /b 0
