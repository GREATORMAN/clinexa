@echo off
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "BACKEND=%ROOT%\backend"
set "PYTHON=%BACKEND%\.venv\Scripts\python.exe"
cd /d "%BACKEND%"
if not exist "%PYTHON%" (
  echo ERROR: Missing %PYTHON%
  pause
  exit /b 1
)
"%PYTHON%" -m uvicorn app.main:app --host 127.0.0.1 --port 8000
endlocal
