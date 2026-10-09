@echo off
cd /d "%~dp0.."
start "Clinexa Backend" cmd /k call scripts\start_backend.bat
timeout /t 3 /nobreak >nul
start "Clinexa Web" cmd /k call scripts\run_flutter_web.bat
