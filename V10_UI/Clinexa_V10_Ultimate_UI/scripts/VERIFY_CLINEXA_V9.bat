@echo off
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
pushd "%ROOT%\backend"
".venv\Scripts\python.exe" -m pytest -q
if errorlevel 1 (popd & exit /b 1)
popd
pushd "%ROOT%\frontend"
call flutter analyze --no-fatal-infos --no-fatal-warnings
if errorlevel 1 (popd & exit /b 1)
call flutter test
if errorlevel 1 (popd & exit /b 1)
call flutter build apk --debug --dart-define=CLINEXA_API_URL=http://127.0.0.1:8000
if errorlevel 1 (popd & exit /b 1)
popd
echo Tests and debug Android build passed on this machine.
endlocal
