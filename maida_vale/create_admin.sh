#!/bin/bash
# Create Admin User Script

source .venv/bin/activate 2>/dev/null || source venv/bin/activate
export DJANGO_SETTINGS_MODULE=config.settings.local
export DATABASE_URL=sqlite:///db.sqlite3

echo "Creating admin user..."
python manage_safe.py createsuperuser
