FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    ENVIRONMENT=production \
    STORAGE_PATH=/app/storage \
    PORT=8080

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends tesseract-ocr \
    && rm -rf /var/lib/apt/lists/*

COPY Clinexa_Functional_v2/backend/requirements.txt ./requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Runtime configuration and secrets are supplied by Google Cloud.
# Local databases, environment files and demo account seeders are excluded.
COPY Clinexa_Functional_v2/backend/app ./app
COPY Clinexa_Functional_v2/backend/alembic ./alembic
COPY Clinexa_Functional_v2/backend/alembic.ini ./alembic.ini
COPY Clinexa_Functional_v2/webapp/frontend ./frontend

RUN useradd --uid 10001 --create-home clinexa \
    && mkdir -p /app/storage \
    && ln -s /run/secrets/clinexa/env /app/.env \
    && chown -R clinexa:clinexa /app
USER clinexa

EXPOSE 8080

# Stop on migration errors rather than launching against an invalid schema.
CMD ["sh", "-c", "python -m app.cli.migrate && python -m app.cli.bootstrap_cloud && exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1"]
