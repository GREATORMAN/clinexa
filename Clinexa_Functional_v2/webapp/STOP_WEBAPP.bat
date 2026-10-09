@echo off
setlocal enabledelayedexpansion
title Stop Clinexa WebApp
cd /d "%~dp0"

echo ====================================================
echo             STOP CLINEXA WEBAPP
echo ====================================================
echo.

set FOUND=0
for /f "tokens=5" %%a in ('netstat -ano ^| findstr LISTENING ^| findstr ":8000"') do (
    set PID=%%a
    if not "!PID!"=="" (
        set FOUND=1
        echo Found process on port 8000 with PID: !PID!
        taskkill /F /PID !PID! >nul 2>&1
        if not errorlevel 1 (
            echo Successfully stopped PID !PID!.
        ) else (
            echo Could not terminate PID !PID!.
        )
    )
)

if "!FOUND!"=="0" (
    echo No process was found running on port 8000.
) else (
    echo.
    echo Clinexa WebApp stopped cleanly.
)

echo.
pause
