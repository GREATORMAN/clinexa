@echo off
setlocal
cd /d "%~dp0..\frontend"

where flutter >nul 2>&1
if errorlevel 1 (
  echo Flutter was not found in PATH.
  pause
  exit /b 1
)

if not exist web (
  call flutter create . --platforms=web,android,ios
  if errorlevel 1 exit /b 1
)

call flutter pub get
if errorlevel 1 exit /b 1
call flutter run -d chrome --dart-define=CLINEXA_API_URL=http://127.0.0.1:8000
