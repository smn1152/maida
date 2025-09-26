#!/bin/bash
# Quick start script for Salbion

source .venv/bin/activate 2>/dev/null || source venv/bin/activate
export DJANGO_SETTINGS_MODULE=config.settings.local
python manage.py migrate
python manage.py runserver
