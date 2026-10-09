@echo off
setlocal
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "FRONTEND=%ROOT%\frontend"
set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
if defined CLINEXA_DEVICE (
  set "DEVICE=%CLINEXA_DEVICE%"
) else (
  set "DEVICE=ZD2224F6K4"
)

echo === Clinexa V5 Android launcher ===
netstat -ano | findstr LISTENING | findstr ":8000" >nul
if errorlevel 1 (
  echo Starting FastAPI backend...
  start "Clinexa Backend" "%ComSpec%" /k call "%~dp0START_BACKEND_V5.bat"
  timeout /t 3 /nobreak >nul
) else (
  echo Backend already listening on port 8000.
)

if exist "%ADB%" (
  "%ADB%" get-state >nul 2>&1
  if errorlevel 1 (
    echo ERROR: No authorized Android device detected by ADB.
    echo Connect the phone, enable USB debugging, and accept the authorization prompt.
    exit /b 1
  )
  "%ADB%" reverse tcp:8000 tcp:8000
) else (
  echo ERROR: adb.exe not found at %ADB%
  exit /b 1
)

pushd "%FRONTEND%"
call flutter pub get
if errorlevel 1 (
  popd
  echo ERROR: flutter pub get failed.
  exit /b 1
)
call flutter run -d "%DEVICE%" --dart-define=CLINEXA_API_URL=http://127.0.0.1:8000
set "EXITCODE=%ERRORLEVEL%"
popd
endlocal & exit /b %EXITCODE%
