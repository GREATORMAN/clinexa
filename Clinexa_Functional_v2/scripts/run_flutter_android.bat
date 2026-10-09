@echo off
setlocal
cd /d "%~dp0..\frontend"

where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter was not found in PATH.
  pause
  exit /b 1
)

if not exist android (
  call flutter create . --platforms=web,android,ios
  if errorlevel 1 exit /b 1
)

rem Allow local FastAPI HTTP during development only.
powershell -NoProfile -Command "$p='android\app\src\main\AndroidManifest.xml'; $c=Get-Content $p -Raw; if($c -notmatch 'usesCleartextTraffic'){ $c=$c -replace '<application', '<application android:usesCleartextTraffic=\"true\"'; Set-Content $p $c -Encoding UTF8 }"

call flutter pub get
if errorlevel 1 exit /b 1

set ADB=adb
where adb >nul 2>&1
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe
  ) else (
    echo ADB was not found. Run flutter doctor -v and check the Android SDK path.
    pause
    exit /b 1
  )
)

"%ADB%" reverse tcp:8000 tcp:8000
if errorlevel 1 (
  echo Could not reverse port 8000. Make sure USB debugging is enabled and the phone is authorized.
  pause
  exit /b 1
)

echo.
echo Connected Android devices:
call flutter devices
set /p DEVICE_ID=Enter your Android device ID ^(example ZD2224F6K4^): 

call flutter run -d %DEVICE_ID% --dart-define=CLINEXA_API_URL=http://127.0.0.1:8000
