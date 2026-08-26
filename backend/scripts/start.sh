#!/bin/sh
set -e

echo "[STARTUP] PulsePath API Production Container Initializing..."
echo "[STARTUP] Executing Alembic database migrations..."
alembic upgrade head
echo "[STARTUP] Alembic database migrations complete."

echo "[STARTUP] Launching Gunicorn server with Uvicorn workers..."
exec gunicorn -c gunicorn.conf.py app.main:app
