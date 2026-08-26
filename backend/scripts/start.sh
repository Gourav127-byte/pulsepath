#!/bin/sh
set -e

echo "[STARTUP] PulsePath API Production Container Initializing..."
echo "[STARTUP] Executing Alembic database migrations..."
alembic upgrade head
echo "[STARTUP] Alembic migrations complete."

echo "[STARTUP] Launching Uvicorn server..."
exec uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers ${GUNICORN_WORKERS:-4}
