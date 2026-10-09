@echo off
cd /d "%~dp0.."
docker compose up -d postgres redis
if errorlevel 1 (echo Failed. Start Docker Desktop first.&pause&exit /b 1)
echo PostgreSQL and Redis started.
pause
