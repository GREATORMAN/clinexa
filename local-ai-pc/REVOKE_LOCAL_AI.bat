@echo off
cd /d "%~dp0"
where py >nul 2>nul
if not errorlevel 1 (
  py -3 local_ai_bridge.py unpair
) else (
  python local_ai_bridge.py unpair
)
pause
