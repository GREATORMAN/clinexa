@echo off
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "BACKEND=%ROOT%\backend"
set "FRONTEND=%ROOT%\frontend"
set "PYTHON=%BACKEND%\.venv\Scripts\python.exe"

echo === Clinexa V5 upgrade ===
if not exist "%PYTHON%" (
  echo ERROR: Backend virtual environment not found at:
  echo %PYTHON%
  echo Create/restore the backend .venv first.
  exit /b 1
)

pushd "%BACKEND%"
echo [1/3] Installing/updating backend dependencies...
"%PYTHON%" -m pip install -r requirements.txt
if errorlevel 1 (
  popd
  echo ERROR: Backend dependency installation failed.
  exit /b 1
)

echo [2/3] Creating V5 additive tables and backfilling medicine records...
"%PYTHON%" -m app.cli.upgrade_v5
if errorlevel 1 (
  popd
  echo ERROR: V5 database upgrade failed. Existing database was not intentionally deleted.
  exit /b 1
)
popd

pushd "%FRONTEND%"
echo [3/3] Resolving Flutter dependencies...
call flutter pub get
if errorlevel 1 (
  popd
  echo ERROR: flutter pub get failed.
  exit /b 1
)
popd

echo.
echo Clinexa V5 Phase 1 upgrade completed.
echo Your existing backend\.env and clinexa_dev.db were preserved.
endlocal
