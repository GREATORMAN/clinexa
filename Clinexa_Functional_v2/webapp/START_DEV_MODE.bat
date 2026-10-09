@echo off
title Clinexa WebApp Dev Mode
cd /d "%~dp0"

echo ====================================================
echo        CLINEXA WEBAPP DEVELOPMENT MODE
echo ====================================================
echo.

REM 1. Check Python
set "PYTHON_EXE="
if exist "%~dp0backend\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%~dp0backend\.venv\Scripts\python.exe"
) else if exist "%~dp0..\backend\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%~dp0..\backend\.venv\Scripts\python.exe"
)

if "%PYTHON_EXE%"=="" (
    echo [ERROR] Python environment not found!
    pause
    exit /b 1
)

REM 2. Start Backend with reload
echo [1/2] Starting Backend API Server on http://127.0.0.1:8000 ...
start "Clinexa Backend (Dev)" cmd /k "cd /d "%~dp0backend" && "%PYTHON_EXE%" -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload"

echo [2/2] Checking for Flutter development workspace...
if exist "%~dp0..\frontend\lib\main.dart" (
    echo Detected Flutter frontend source at ..\frontend
    echo Opening Flutter Web with Chrome...
    start "Clinexa Flutter Web (Dev)" cmd /k "cd /d "%~dp0..\frontend" && flutter run -d chrome --web-port=3000 --dart-define=CLINEXA_API_URL=http://127.0.0.1:8000"
) else (
    echo Flutter source not found; launching compiled web app in browser: http://127.0.0.1:8000
    timeout /t 3 /nobreak >nul
    start http://127.0.0.1:8000
)

echo.
echo Development services launched!
pause
