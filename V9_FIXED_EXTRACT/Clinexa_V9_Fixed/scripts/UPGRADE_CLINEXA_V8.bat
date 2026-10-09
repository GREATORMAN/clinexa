@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "PYTHON=%ROOT%\backend\.venv\Scripts\python.exe"
echo Clinexa V8 - backed-up upgrade
if not exist "%PYTHON%" (
  pushd "%ROOT%\backend"
  py -3 -m venv .venv
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
"%PYTHON%" -m compileall -q app
if errorlevel 1 (popd & exit /b 1)
popd
pushd "%ROOT%\frontend"
call flutter pub get
if errorlevel 1 (popd & exit /b 1)
popd
echo Upgrade complete. Restart the old backend terminal with Ctrl+C before launching V8.
echo Run scripts\VERIFY_CLINEXA_V8.bat then scripts\START_CLINEXA_V8.bat
endlocal
