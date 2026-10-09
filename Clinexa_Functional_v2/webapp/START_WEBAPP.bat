@echo off
setlocal enabledelayedexpansion
title Clinexa WebApp Launcher
cd /d "%~dp0"

echo ====================================================
echo        CLINEXA UNIFIED WEB APPLICATION
echo        (FastAPI Backend + Flutter Web UI)
echo ====================================================
echo.

REM 1. Check Python Interpreter
set "PYTHON_EXE="
if exist "%~dp0backend\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%~dp0backend\.venv\Scripts\python.exe"
) else if exist "%~dp0..\backend\.venv\Scripts\python.exe" (
    set "PYTHON_EXE=%~dp0..\backend\.venv\Scripts\python.exe"
) else (
    where python >nul 2>nul
    if not errorlevel 1 (
        echo [INFO] Creating Python virtual environment in backend\.venv...
        cd /d "%~dp0backend"
        python -m venv .venv
        call .venv\Scripts\activate.bat
        pip install -r requirements.txt
        cd /d "%~dp0"
        set "PYTHON_EXE=%~dp0backend\.venv\Scripts\python.exe"
    )
)

if "%PYTHON_EXE%"=="" (
    echo [ERROR] Python environment not found!
    echo Please make sure Python 3.10+ is installed on your system.
    pause
    exit /b 1
)

echo [OK] Using Python: %PYTHON_EXE%

REM 2. Check if port 8000 is already running
netstat -ano | findstr LISTENING | findstr ":8000" >nul
if not errorlevel 1 (
    echo.
    echo [INFO] Port 8000 is already running.
    echo Opening browser to http://127.0.0.1:8000 ...
    start http://127.0.0.1:8000
    echo.
    echo Clinexa WebApp is ready!
    echo - Web Application: http://127.0.0.1:8000/
    echo - API Swagger Docs: http://127.0.0.1:8000/docs
    echo.
    pause
    exit /b 0
)

REM 3. Launch Backend with Web Static Mount
echo [1/2] Starting Clinexa Server (Hosting Web UI + REST API)...
start "Clinexa Web Server" cmd /k "cd /d "%~dp0backend" && "%PYTHON_EXE%" -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload"

echo [2/2] Waiting for server to initialize...
timeout /t 3 /nobreak >nul

REM 4. Launch Browser
echo Opening browser...
start http://127.0.0.1:8000

echo.
echo ====================================================
echo  CLINEXA WEBAPP IS RUNNING!
echo ====================================================
echo  - Frontend Web UI:  http://127.0.0.1:8000/
echo  - API Swagger Docs: http://127.0.0.1:8000/docs
echo  - Interactive ReDoc: http://127.0.0.1:8000/redoc
echo.
echo  Keep the "Clinexa Web Server" console window open while using the app.
echo  To stop the application, close the console or run STOP_WEBAPP.bat
echo ====================================================
echo.
pause
