FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PORT=8000

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

COPY backend/requirements.txt ./
RUN pip install --no-cache-dir -r requirements.txt

# Backend code and seed scripts
COPY backend/app ./app
COPY backend/alembic ./alembic
COPY backend/alembic.ini ./alembic.ini
COPY backend/.env.example ./.env
COPY scripts ./scripts
COPY backend/clinexa_dev.db ./clinexa_dev.db
RUN mkdir -p /app/storage

# Compiled Flutter Web frontend (served by FastAPI at /)
COPY webapp/frontend /app/frontend

EXPOSE 8000

# Ensure DB exists, migrations are applied, and accounts are seeded, then launch Uvicorn
CMD ["sh", "-c", "python -m app.cli.migrate 2>/dev/null || true; python scripts/seed_all_entity_passwords.py 2>/dev/null || true; exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]
