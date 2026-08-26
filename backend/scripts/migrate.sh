#!/bin/sh
set -e

echo "[MIGRATION] Controlled Alembic Database Migration Initializing..."
echo "[MIGRATION] Executing alembic upgrade head..."
alembic upgrade head
echo "[MIGRATION] Alembic database migration successfully applied to head."
