@echo off
setlocal EnableExtensions
for %%I in ("%~dp0..") do set "SOURCE=%%~fI"
if "%~1"=="" (
  echo Usage: INSTALL_INTO_EXISTING.bat "C:\path\to\Clinexa_Functional_v2"
  exit /b 1
)
set "DEST=%~f1"
if not exist "%DEST%\frontend\pubspec.yaml" (
  echo ERROR: Target does not contain the existing Clinexa frontend.
  exit /b 1
)
if not exist "%DEST%\backend\app\main.py" (
  echo ERROR: Target does not contain the existing Clinexa backend.
  exit /b 1
)
if /i "%SOURCE%"=="%DEST%" (
  call "%DEST%\scripts\UPGRADE_CLINEXA_V8.bat"
  exit /b
)
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%T"
set "BACKUP=%DEST%\backups\source_pre_v8_%STAMP%"
echo Backing up existing source to %BACKUP%
for %%D in (backend\app backend\tests frontend\lib frontend\test scripts) do (
  if exist "%DEST%\%%D" (
    robocopy "%DEST%\%%D" "%BACKUP%\%%D" /E /NFL /NDL /NJH /NJS >nul
    if errorlevel 8 exit /b 1
  )
)
copy /Y "%DEST%\frontend\pubspec.yaml" "%BACKUP%\pubspec.yaml" >nul
if errorlevel 1 exit /b 1
if exist "%DEST%\backend\requirements.txt" copy /Y "%DEST%\backend\requirements.txt" "%BACKUP%\requirements.txt" >nul
echo Applying V8 source. Native platform folders, environment and patient database are preserved.
for %%D in (backend\app backend\tests frontend\lib frontend\test scripts) do (
  robocopy "%SOURCE%\%%D" "%DEST%\%%D" /E /NFL /NDL /NJH /NJS >nul
  if errorlevel 8 exit /b 1
)
copy /Y "%SOURCE%\frontend\pubspec.yaml" "%DEST%\frontend\pubspec.yaml" >nul
if errorlevel 1 exit /b 1
copy /Y "%SOURCE%\backend\requirements.txt" "%DEST%\backend\requirements.txt" >nul
if errorlevel 1 exit /b 1
copy /Y "%SOURCE%\backend\constraints-tested.txt" "%DEST%\backend\constraints-tested.txt" >nul
if errorlevel 1 exit /b 1
copy /Y "%SOURCE%\README_V8.md" "%DEST%\README_V8.md" >nul
call "%DEST%\scripts\UPGRADE_CLINEXA_V8.bat"
if errorlevel 1 exit /b 1
echo Installation complete. Source backup: %BACKUP%
endlocal
