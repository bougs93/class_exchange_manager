@echo off
REM Debug web run: build worker, then run on Chrome with Firebase config.
REM
REM Set these env vars once before running (values stay out of git):
REM   setx FIREBASE_API_KEY "xxx"  (then reopen the terminal)
REM Required: FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_APP_ID
REM Optional: FIREBASE_AUTH_DOMAIN, FIREBASE_STORAGE_BUCKET, FIREBASE_MESSAGING_SENDER_ID
cd /d "%~dp0"

if "%FIREBASE_API_KEY%"=="" goto :missing
if "%FIREBASE_PROJECT_ID%"=="" goto :missing
if "%FIREBASE_APP_ID%"=="" goto :missing

echo [1/2] Building worker...
call dart run tool/build_web.dart --worker-only
if errorlevel 1 (
  echo Worker build FAILED.
  pause
  exit /b 1
)

echo [2/2] Running on Chrome...
call flutter run -d chrome --web-port=5000 --dart-define=FIREBASE_API_KEY=%FIREBASE_API_KEY% --dart-define=FIREBASE_AUTH_DOMAIN=%FIREBASE_AUTH_DOMAIN% --dart-define=FIREBASE_PROJECT_ID=%FIREBASE_PROJECT_ID% --dart-define=FIREBASE_STORAGE_BUCKET=%FIREBASE_STORAGE_BUCKET% --dart-define=FIREBASE_MESSAGING_SENDER_ID=%FIREBASE_MESSAGING_SENDER_ID% --dart-define=FIREBASE_APP_ID=%FIREBASE_APP_ID%
pause
exit /b 0

:missing
echo Missing Firebase env vars. Set at least FIREBASE_API_KEY, FIREBASE_PROJECT_ID, FIREBASE_APP_ID, then reopen the terminal and retry.
pause
exit /b 1
