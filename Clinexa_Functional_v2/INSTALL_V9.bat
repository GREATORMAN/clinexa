@echo off
setlocal
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=C:\Users\VISHAL\Documents\pdd\Clinexa_Full_v2\Clinexa_Functional_v2"
echo Target: %TARGET%
echo Stop the running backend and Flutter app before continuing.
call "%~dp0scripts\INSTALL_INTO_EXISTING.bat" "%TARGET%"
if errorlevel 1 (echo Installation failed. Read the error above. & pause & exit /b 1)
echo Run the verification script in the target project's scripts folder.
pause
