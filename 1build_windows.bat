@echo off
REM class_exchange_manager Windows release build entry.
REM Double-click or run from the repo root. Korean messages are printed by
REM tool\build_windows.ps1 (UTF-8 BOM). This .bat stays ASCII so cmd.exe
REM does not mojibake echo lines. Do NOT use chcp 65001 (breaks pause).
REM
REM After a successful build, ask to copy newest dist\class_exchange_manager-*
REM folder to D:\Users\user\Documents\WONGIL_2026\my_project\class_exchange_manager\<same-folder-name>\
REM Default is Y (Enter copies). Type n to skip.
REM Prompt text is ASCII here; Korean build messages stay in the .ps1.

cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -NoLogo -File "%~dp0tool\build_windows.ps1"
set "PSERR=%ERRORLEVEL%"
if not "%PSERR%"=="0" (
  echo.
  echo Build failed. See the messages above.
  echo.
  pause
  exit /b 1
)

set "COPY_ROOT=D:\Users\user\Documents\WONGIL_2026\my_project\class_exchange_manager"
set "DIST_NAME="
for /f "delims=" %%D in ('dir /b /ad /o-d "%~dp0dist\class_exchange_manager-*" 2^>nul') do (
  set "DIST_NAME=%%D"
  goto :have_dist
)

echo.
echo Dist folder not found. Skip copy.
goto :end_ok

:have_dist
set "DIST_SRC=%~dp0dist\%DIST_NAME%"
set "COPY_DEST=%COPY_ROOT%\%DIST_NAME%"
echo.
echo Copy destination:
echo   %COPY_DEST%
echo.
set "ANS=Y"
REM Avoid parentheses in this prompt - cmd parses them inside IF blocks.
set /p "ANS=Copy now? [Y/n]: "
if /i "%ANS%"=="n" goto :skip_copy

if not exist "%COPY_ROOT%" mkdir "%COPY_ROOT%"
REM robocopy exit 0-7 = success. Do NOT put "(" inside an IF (...) echo line -
REM cmd parses both branches and reports: ". was unexpected" on Korean Windows.
robocopy "%DIST_SRC%" "%COPY_DEST%" /E /NFL /NDL /NJH /NJS /nc /ns /np
set "RC=%ERRORLEVEL%"
if %RC% GEQ 8 goto :copy_fail
echo.
echo Copied to:
echo   %COPY_DEST%
explorer "%COPY_DEST%"
goto :end_ok

:copy_fail
echo.
echo Copy failed - robocopy exit %RC%. Source is still at:
echo   %DIST_SRC%
goto :end_ok

:skip_copy
echo Copy skipped.

:end_ok
echo.
pause
exit /b 0
