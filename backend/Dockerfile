# Backend PADAN untuk Hugging Face Spaces (Docker).
# HF meneruskan traffic ke port 7860.
FROM python:3.12-slim

WORKDIR /code

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app ./app
COPY alembic ./alembic
COPY alembic.ini .
RUN mkdir -p uploads

# Env wajib diisi di Settings → Variables and secrets:
#   DATABASE_URL, SECRET_KEY
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-7860}"]
