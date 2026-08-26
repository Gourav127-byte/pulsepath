# Gunicorn Production Process Manager Configuration for Uvicorn Workers
import os
import multiprocessing

# Server socket
bind = "0.0.0.0:8000"
backlog = 2048

# Worker processes (Optimized for low-memory 512MB RAM containers)
default_workers = int(os.getenv("WEB_CONCURRENCY", "2"))
workers = int(os.getenv("GUNICORN_WORKERS", default_workers))
worker_class = "uvicorn.workers.UvicornWorker"
worker_connections = 1000
timeout = 30
keepalive = 2

# Logging
loglevel = os.getenv("LOG_LEVEL", "info")
accesslog = "-"
errorlog = "-"
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(L)ss'

# Process naming
proc_name = "pulsepath_api"

# Server mechanics
daemon = False
pidfile = None
umask = 0
user = None
group = None
tmp_upload_dir = None
