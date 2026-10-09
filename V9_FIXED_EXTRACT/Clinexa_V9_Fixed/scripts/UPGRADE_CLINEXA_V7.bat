@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "BACKEND=%ROOT%\backend"
set "FRONTEND=%ROOT%\frontend"
set "PYTHON=%BACKEND%\.venv\Scripts\python.exe"

echo === Clinexa V7 Showcase Upgrade ===
echo V7 is a frontend/responsive upgrade. Your existing .env and database are not replaced.

if exist "%PYTHON%" (
  echo [1/2] Verifying backend Python source...
  "%PYTHON%" -m compileall -q "%BACKEND%\app"
  if errorlevel 1 exit /b 1
) else (
  echo WARNING: Backend virtual environment was not found. Skipping Python source verification.
)

pushd "%FRONTEND%"
echo [2/2] Resolving Flutter dependencies...
call flutter pub get
if errorlevel 1 (popd & exit /b 1)
popd

echo.
echo Clinexa V7 showcase upgrade completed.
echo Next: scripts\START_CLINEXA_V7.bat
endlocal
