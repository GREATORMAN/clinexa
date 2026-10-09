FROM python:3.12-slim
ENV PYTHONDONTWRITEBYTECODE=1 PYTHONUNBUFFERED=1
WORKDIR /app
RUN apt-get update && apt-get install -y --no-install-recommends tesseract-ocr && rm -rf /var/lib/apt/lists/*
COPY requirements.txt constraints-tested.txt ./
RUN pip install --no-cache-dir -r requirements.txt -c constraints-tested.txt
COPY app ./app
COPY alembic ./alembic
COPY alembic.ini ./
RUN useradd --create-home clinexa && mkdir -p /app/storage && chown -R clinexa:clinexa /app
USER clinexa
EXPOSE 8080
CMD ["sh","-c","exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8080} --workers 1"]
