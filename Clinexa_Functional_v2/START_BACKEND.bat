@echo off
title Clinexa Backend Server
cd /d "%~dp0\backend"

echo ===================================================
echo             CLINEXA BACKEND SERVER
echo ===================================================
echo.

if not exist ".venv\Scripts\python.exe" (
    echo [ERROR] Virtual environment not found in backend\.venv
    echo Please make sure the virtual environment is installed.
    pause
    exit /b 1
)

netstat -ano | findstr LISTENING | findstr ":8000" >nul
if not errorlevel 1 (
    echo [WARNING] Port 8000 is already in use!
    echo Backend is already running or another service is on port 8000.
    echo.
)

echo Activating Python virtual environment...
call .venv\Scripts\activate.bat

echo.
echo Starting FastAPI with Uvicorn on http://127.0.0.1:8000 ...
echo Swagger UI docs available at: http://127.0.0.1:8000/docs
echo.
python -m uvicorn app.main:app --host 127.0.0.1 --port 8000 --reload
pause
