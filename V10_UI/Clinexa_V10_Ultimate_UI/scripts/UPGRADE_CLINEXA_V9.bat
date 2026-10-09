@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "PYTHON=%ROOT%\backend\.venv\Scripts\python.exe"
if not exist "%PYTHON%" (
  pushd "%ROOT%\backend"
  where py >nul 2>&1
  if not errorlevel 1 (py -3 -m venv .venv) else (python -m venv .venv)
  if errorlevel 1 (popd & exit /b 1)
  popd
)
pushd "%ROOT%\backend"
"%PYTHON%" -m pip install -r requirements.txt -c constraints-tested.txt
if errorlevel 1 (popd & exit /b 1)
"%PYTHON%" -m app.cli.setup_environment
if errorlevel 1 (popd & exit /b 1)
"%PYTHON%" -m app.cli.backup_database
if errorlevel 1 (popd & exit /b 1)
"%PYTHON%" -m app.cli.upgrade_v5
if errorlevel 1 (popd & exit /b 1)
"%PYTHON%" -m app.cli.upgrade_v6
if errorlevel 1 (popd & exit /b 1)
"%PYTHON%" -m app.cli.upgrade_v8
if errorlevel 1 (popd & exit /b 1)
"%PYTHON%" -m app.cli.migrate
if errorlevel 1 (popd & exit /b 1)
"%PYTHON%" -m compileall -q app
if errorlevel 1 (popd & exit /b 1)
popd
"%PYTHON%" "%ROOT%\scripts\configure_native_v9.py"
if errorlevel 1 exit /b 1
pushd "%ROOT%\frontend"
call flutter pub get
if errorlevel 1 (popd & exit /b 1)
popd
echo V9 source installed. Run VERIFY_CLINEXA_V9.bat before launching.
endlocal
