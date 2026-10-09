@echo off
setlocal EnableExtensions EnableDelayedExpansion
for %%I in ("%~dp0..") do set "ROOT=%%~fI"
set "BACKEND=%ROOT%\backend"
set "FRONTEND=%ROOT%\frontend"
set "PYTHON=%BACKEND%\.venv\Scripts\python.exe"
set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
set "DEVICE=ZD2224F6K4"
if not "%~1"=="" set "DEVICE=%~1"
set "EXPECTED_VERSION=9.0.0"

echo === Clinexa V9 Showcase Android Launcher ===
if not exist "%PYTHON%" (
  echo ERROR: Backend virtual environment not found at %PYTHON%
  exit /b 1
)

set "RUNNING_VERSION="
for /f "usebackq delims=" %%V in (`powershell -NoProfile -Command "try { $r=Invoke-RestMethod -Uri 'http://127.0.0.1:8000/' -TimeoutSec 2; if($r.name -eq 'Clinexa'){[Console]::Write($r.version)} } catch {}"`) do set "RUNNING_VERSION=%%V"

if defined RUNNING_VERSION (
  if "!RUNNING_VERSION!"=="%EXPECTED_VERSION%" (
    echo Compatible Clinexa backend already running.
  ) else (
    echo Older Clinexa backend !RUNNING_VERSION! is running.
    echo Stop its terminal with Ctrl+C, then run this launcher again.
    exit /b 1
  )
)

if not defined RUNNING_VERSION (
  netstat -ano | findstr LISTENING | findstr ":8000" >nul
  if not errorlevel 1 (
    echo ERROR: Port 8000 is occupied by a process that did not identify itself as Clinexa.
    echo Close that process or inspect it with: netstat -ano ^| findstr LISTENING ^| findstr :8000
    exit /b 1
  )
  echo Starting FastAPI backend...
  start "Clinexa V9 Backend" cmd /k "cd /d ""%BACKEND%"" && ""%PYTHON%"" -m uvicorn app.main:app --host 127.0.0.1 --port 8000"
  echo Waiting for backend readiness...
  powershell -NoProfile -Command "$ok=$false; for($i=0;$i -lt 25;$i++){ try{$r=Invoke-RestMethod -Uri 'http://127.0.0.1:8000/' -TimeoutSec 1; if($r.version -eq '9.0.0'){$ok=$true;break}}catch{}; Start-Sleep -Milliseconds 500 }; if(-not $ok){exit 1}"
  if errorlevel 1 (
    echo ERROR: Clinexa backend did not become ready. Check the backend window for the real error.
    exit /b 1
  )
)

powershell -NoProfile -Command "try { $r=Invoke-RestMethod -Uri 'http://127.0.0.1:11434/api/tags' -TimeoutSec 1; Write-Host 'Ollama: available' } catch { Write-Host 'Ollama: offline - core Clinexa will still run' }"

if not exist "%ADB%" (
  echo ERROR: adb not found at %ADB%
  exit /b 1
)

echo Checking Android device...
"%ADB%" devices
"%ADB%" -s %DEVICE% get-state >nul 2>&1
if errorlevel 1 (
  echo ERROR: Moto device %DEVICE% is not connected/authorized.
  exit /b 1
)

echo Creating phone-to-backend bridge...
"%ADB%" -s "%DEVICE%" reverse tcp:8000 tcp:8000
if errorlevel 1 exit /b 1
"%ADB%" -s "%DEVICE%" reverse --list

pushd "%FRONTEND%"
echo Resolving Flutter dependencies...
call flutter pub get
if errorlevel 1 (popd & exit /b 1)
echo Launching Clinexa V9 showcase on Moto g51 5G...
call flutter run -d %DEVICE% --dart-define=CLINEXA_API_URL=http://127.0.0.1:8000
popd
endlocal
