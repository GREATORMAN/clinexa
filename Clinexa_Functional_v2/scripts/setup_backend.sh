#!/usr/bin/env bash
set -e
cd "$(dirname "$0")/../backend"
python3 -m venv .venv
source .venv/bin/activate
pip install --upgrade pip
pip install -r requirements.txt
[ -f .env ] || cp ../.env.example .env
python -m app.cli.init_db
