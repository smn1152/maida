#!/bin/bash
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    echo "Creating virtual environment..."
    /opt/homebrew/opt/python@3.11/bin/python3.11 -m venv .venv
    .venv/bin/pip install --upgrade pip
    .venv/bin/pip install django django-environ django-allauth psycopg2-binary redis celery whitenoise wagtail==6.0
fi

echo "Using Python: $VENV_PYTHON"
$VENV_PYTHON "$@"
