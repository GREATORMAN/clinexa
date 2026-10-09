@echo off
title Clinexa V4 Launcher
cd /d "%~dp0"

echo.
echo ==========================================
echo        CLINEXA V4 ADVANCED
echo ==========================================
echo.

REM ---- Check backend ----
netstat -ano | findstr LISTENING | findstr ":8000" >nul

if errorlevel 1 (
    echo [1/4] Starting Clinexa backend...

    start "Clinexa Backend" cmd /k ^
    "cd /d "%~dp0backend" && .venv\Scripts\activate.bat && python -m uvicorn app.main:app --host 127.0.0.1 --port 8000"

    echo Waiting for backend...
    timeout /t 4 /nobreak >nul
) else (
    echo [1/4] Backend already running.
)

REM ---- Check phone ----
echo [2/4] Checking Android device...

"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices

"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" get-state >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: Android phone not detected.
    echo Connect your phone and enable USB debugging.
    echo.
    pause
    exit /b
)

REM ---- ADB reverse ----
echo [3/4] Connecting phone to Clinexa backend...

"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" reverse tcp:8000 tcp:8000

REM ---- FIX #6: Auto-detect the connected device ID instead of hardcoding it.
REM   This reads the first connected device ID from adb so any phone works.
echo [4/4] Detecting connected device...

for /f "skip=1 tokens=1" %%i in ('"%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" devices') do (
    if not "%%i"=="" (
        set DEVICE_ID=%%i
        goto :found_device
    )
)

:found_device
echo Device found: %DEVICE_ID%
echo Launching Clinexa V4 on %DEVICE_ID%...

cd /d "%~dp0frontend"

call flutter pub get

call flutter run -d %DEVICE_ID% --dart-define=CLINEXA_API_URL=http://127.0.0.1:8000

pause