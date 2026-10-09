@echo off
cd /d "%~dp0..\backend"
where python >nul 2>&1 || (echo Python 3.11+ not found.&pause&exit /b 1)
if not exist .venv python -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
if not exist .env copy ..\.env.example .env >nul
python -m app.cli.init_db
echo Backend setup completed.
pause
