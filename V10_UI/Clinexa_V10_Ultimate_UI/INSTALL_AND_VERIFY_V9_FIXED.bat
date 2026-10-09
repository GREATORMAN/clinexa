@echo off
setlocal EnableExtensions
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=C:\Users\VISHAL\Documents\pdd\Clinexa_Full_v2\Clinexa_Functional_v2"

echo ============================================================
echo Clinexa V9 Fixed - backed-up install and verification
echo Target: %TARGET%
echo ============================================================
echo.
echo Stop any running Clinexa backend and Flutter app before continuing.
echo.

call "%~dp0scripts\INSTALL_INTO_EXISTING.bat" "%TARGET%"
if errorlevel 1 (
  echo.
  echo ERROR: Installation failed. Your existing project was backed up before source replacement where applicable.
  exit /b 1
)

echo.
echo Running full V9 verification...
call "%TARGET%\scripts\VERIFY_CLINEXA_V9.bat"
if errorlevel 1 (
  echo.
  echo ERROR: Verification failed. Do not launch until the error above is resolved.
  exit /b 1
)

echo.
echo ============================================================
echo Clinexa V9 Fixed installed and verified successfully.
echo To launch the Moto device:
echo   "%TARGET%\scripts\START_CLINEXA_V9.bat" ZD2224F6K4
echo ============================================================
endlocal
