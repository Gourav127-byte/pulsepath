#!/bin/sh
set -e

echo "[STARTUP] PulsePath API Production Container Initializing..."
echo "[STARTUP] Launching Gunicorn server with Uvicorn workers..."
exec gunicorn -c gunicorn.conf.py app.main:app
