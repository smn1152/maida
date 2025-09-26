#!/bin/bash
# Foolproof server start script

echo "Starting Salbion server..."

# Always use the venv Python
source .venv/bin/activate

# Set environment
export DJANGO_SETTINGS_MODULE=config.settings.local
export DATABASE_URL=sqlite:///db.sqlite3

# Use the venv Python explicitly
.venv/bin/python manage_safe.py runserver 0.0.0.0:8000
