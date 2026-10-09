@echo off
setlocal
cd /d "%~dp0.."

echo === Clinexa V4 Android launcher ===

netstat -ano | findstr LISTENING | findstr :8000 >nul
if errorlevel 1 (
  echo Starting Clinexa backend in a new window...
  start "Clinexa Backend" cmd /k "cd /d %CD%\backend && call .venv\Scripts\activate.bat && python -m uvicorn app.main:app --host 127.0.0.1 --port 8000"
  timeout /t 3 /nobreak >nul
) else (
  echo Backend already listening on port 8000.
)

powershell -ExecutionPolicy Bypass -File "%CD%\scripts\prepare_android_v4.ps1"
if errorlevel 1 exit /b 1

set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if not exist "%ADB%" (
  echo ADB was not found at %ADB%
  exit /b 1
)

"%ADB%" devices
"%ADB%" reverse tcp:8000 tcp:8000

cd /d "%CD%\frontend"
call flutter pub get
if errorlevel 1 exit /b 1
call flutter run -d ZD2224F6K4 --dart-define=CLINEXA_API_URL=http://127.0.0.1:8000
