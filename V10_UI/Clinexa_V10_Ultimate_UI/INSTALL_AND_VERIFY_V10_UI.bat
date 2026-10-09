@echo off
setlocal EnableExtensions
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=C:\Users\VISHAL\Documents\pdd\Clinexa_Full_v2\Clinexa_Functional_v2"
echo ============================================================
echo Clinexa V10 Ultimate UI - safe install + full verification
echo Target: %TARGET%
echo ============================================================
echo.
call "%~dp0INSTALL_AND_VERIFY_V9_FIXED.bat" "%TARGET%"
if errorlevel 1 exit /b 1
echo.
echo Clinexa V10 UI layer installed on the verified V9/V5 platform.
endlocal
