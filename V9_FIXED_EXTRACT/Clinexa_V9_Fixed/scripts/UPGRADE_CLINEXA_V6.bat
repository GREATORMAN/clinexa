@echo off
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "BACKEND=%ROOT%\backend"
set "FRONTEND=%ROOT%\frontend"
set "PYTHON=%BACKEND%\.venv\Scripts\python.exe"

echo === Clinexa V6 Experience Upgrade ===
if not exist "%PYTHON%" (
  echo ERROR: Backend virtual environment not found at %PYTHON%
  exit /b 1
)

pushd "%BACKEND%"
echo [1/4] Installing backend dependencies...
"%PYTHON%" -m pip install -r requirements.txt
if errorlevel 1 (popd & exit /b 1)

echo [2/4] Applying V5 data upgrade idempotently...
"%PYTHON%" -m app.cli.upgrade_v5
if errorlevel 1 (popd & exit /b 1)

echo [3/4] Creating V6 catalog and pharmacy workflow...
"%PYTHON%" -m app.cli.upgrade_v6
if errorlevel 1 (popd & exit /b 1)
popd

pushd "%FRONTEND%"
echo [4/4] Resolving Flutter dependencies...
call flutter pub get
if errorlevel 1 (popd & exit /b 1)
popd

echo.
echo Clinexa V6 upgrade completed. Existing .env and local database were preserved.
endlocal
