# Production Dockerfile for PulsePath FastAPI Backend
FROM python:3.12-slim as base

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install system dependencies needed for PostgreSQL build & curl health checks
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    libpq-dev \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

# Copy application source, migrations, and scripts
COPY app /app/app
COPY migrations /app/migrations
COPY alembic.ini /app/
COPY gunicorn.conf.py /app/
COPY scripts/start.sh /app/scripts/

# Set executable permissions on entrypoint script
RUN chmod +x /app/scripts/start.sh

# Create non-root system user for security
RUN useradd -m pulsepath && chown -R pulsepath:pulsepath /app
USER pulsepath

EXPOSE 8000

# Container health check via internal HTTP request to /health
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD curl -f http://localhost:8000/health || exit 1

ENTRYPOINT ["/app/scripts/start.sh"]
