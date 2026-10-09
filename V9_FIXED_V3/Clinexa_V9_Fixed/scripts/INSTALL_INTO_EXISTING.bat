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
where py >nul 2>&1
if not errorlevel 1 (
  py -3 "%SOURCE%\scripts\preflight_install.py" "%DEST%"
) else (
  python "%SOURCE%\scripts\preflight_install.py" "%DEST%"
)
if errorlevel 1 exit /b 1
if /i "%SOURCE%"=="%DEST%" (
  call "%DEST%\scripts\UPGRADE_CLINEXA_V9.bat"
  exit /b
)
for /f %%T in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd_HHmmss"') do set "STAMP=%%T"
set "BACKUP=%DEST%\backups\source_pre_v9_%STAMP%"
echo Backing up existing source to %BACKUP%
for %%D in (backend\app backend\tests backend\alembic frontend\lib frontend\test scripts deploy .github) do (
  if exist "%DEST%\%%D" (
    robocopy "%DEST%\%%D" "%BACKUP%\%%D" /E /NFL /NDL /NJH /NJS >nul
    if errorlevel 8 exit /b 1
  )
)
copy /Y "%DEST%\frontend\pubspec.yaml" "%BACKUP%\pubspec.yaml" >nul
if errorlevel 1 exit /b 1
mkdir "%BACKUP%\frontend\android\app\src\main" >nul 2>&1
for %%F in (build.gradle.kts build.gradle settings.gradle.kts settings.gradle) do (
  if exist "%DEST%\frontend\android\%%F" copy /Y "%DEST%\frontend\android\%%F" "%BACKUP%\frontend\android\%%F" >nul
)
for %%F in (build.gradle.kts build.gradle) do (
  if exist "%DEST%\frontend\android\app\%%F" copy /Y "%DEST%\frontend\android\app\%%F" "%BACKUP%\frontend\android\app\%%F" >nul
)
if exist "%DEST%\frontend\android\app\src\main\AndroidManifest.xml" copy /Y "%DEST%\frontend\android\app\src\main\AndroidManifest.xml" "%BACKUP%\frontend\android\app\src\main\AndroidManifest.xml" >nul
for %%F in (requirements.txt constraints-tested.txt alembic.ini Dockerfile) do (
  if exist "%DEST%\backend\%%F" (
    copy /Y "%DEST%\backend\%%F" "%BACKUP%\%%F" >nul
    if errorlevel 1 exit /b 1
  )
)
for %%F in (README.md README_V9.md COVERAGE_V9.md compose.yaml INSTALL_V9.bat) do (
  if exist "%DEST%\%%F" (
    copy /Y "%DEST%\%%F" "%BACKUP%\%%F" >nul
    if errorlevel 1 exit /b 1
  )
)
echo Applying V9 source. Native platform folders, environment and patient database are preserved.
for %%D in (backend\app backend\tests backend\alembic frontend\lib frontend\test scripts deploy .github) do (
  robocopy "%SOURCE%\%%D" "%DEST%\%%D" /E /NFL /NDL /NJH /NJS >nul
  if errorlevel 8 exit /b 1
)
copy /Y "%SOURCE%\frontend\pubspec.yaml" "%DEST%\frontend\pubspec.yaml" >nul
if errorlevel 1 exit /b 1
copy /Y "%SOURCE%\backend\requirements.txt" "%DEST%\backend\requirements.txt" >nul
if errorlevel 1 exit /b 1
copy /Y "%SOURCE%\backend\constraints-tested.txt" "%DEST%\backend\constraints-tested.txt" >nul
if errorlevel 1 exit /b 1
for %%F in (README.md README_V9.md COVERAGE_V9.md compose.yaml INSTALL_V9.bat) do (
  copy /Y "%SOURCE%\%%F" "%DEST%\%%F" >nul
  if errorlevel 1 exit /b 1
)
copy /Y "%SOURCE%\backend\Dockerfile" "%DEST%\backend\Dockerfile" >nul
if errorlevel 1 exit /b 1
copy /Y "%SOURCE%\backend\alembic.ini" "%DEST%\backend\alembic.ini" >nul
if errorlevel 1 exit /b 1
call "%DEST%\scripts\UPGRADE_CLINEXA_V9.bat"
if errorlevel 1 exit /b 1
echo Installation complete. Source backup: %BACKUP%
endlocal
