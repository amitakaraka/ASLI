#!/bin/bash

# Ensure virtual environment is activated
if [ -z "$VIRTUAL_ENV" ]; then
    echo "Activating virtual environment..."
    source .venv/bin/activate
fi

# Run migrations, then Gunicorn with eventlet workers to support WebSockets
if [ "${ASLI_SKIP_MIGRATIONS:-0}" != "1" ]; then
    echo "Running database migrations..."
    alembic upgrade head
fi

echo "Starting ASLI Backend in Production mode (Gunicorn + Eventlet)..."
gunicorn wsgi:app --worker-class eventlet -w 1 --bind 127.0.0.1:5001 --access-logfile - --error-logfile -
