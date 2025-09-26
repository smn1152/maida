#!/bin/bash
# Guaranteed Server Start Script

echo "Starting Salbion Development Server (SQLite mode)..."

# Activate virtual environment
source .venv/bin/activate 2>/dev/null || source venv/bin/activate

# Force SQLite configuration
export DJANGO_SETTINGS_MODULE=config.settings.local
export DATABASE_URL=sqlite:///db.sqlite3

# Try different ways to start the server
echo "Attempting to start server..."

# Method 1: Use safe manage.py
if [ -f "manage_safe.py" ]; then
    echo "Using manage_safe.py..."
    python manage_safe.py runserver 0.0.0.0:8000
    exit 0
fi

# Method 2: Regular manage.py with forced settings
echo "Using regular manage.py with forced settings..."
python manage.py runserver 0.0.0.0:8000 --settings=config.settings.local
