@echo off
cd /d "%~dp0..\backend"
call .venv\Scripts\activate.bat
python -m app.cli.seed_demo
pause
