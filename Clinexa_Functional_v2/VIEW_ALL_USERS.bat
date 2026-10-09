@echo off
title View Clinexa Users
cd /d "%~dp0"

echo ==============================================================================
echo                         CLINEXA REGISTERED USERS
echo ==============================================================================
echo.

if exist "backend\.venv\Scripts\python.exe" (
    backend\.venv\Scripts\python.exe -c "import sqlite3; con = sqlite3.connect('backend/clinexa_dev.db'); rows = con.execute('SELECT u.email, u.full_name, COALESCE(p.account_type, \"None\") FROM users u LEFT JOIN user_account_profiles p ON u.id = p.user_id').fetchall(); print(f'Total Users: {len(rows)}\n'); [print(f' - {r[0]:<30} | {r[1]:<25} | {r[2]}') for r in rows]"
) else (
    type DATABASE_USERS.md
)

echo.
echo ==============================================================================
pause
