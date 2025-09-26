#!/usr/bin/env python
"""Django's command-line utility - SAFE VERSION"""
import os
import sys

if __name__ == "__main__":
    # Force local settings with SQLite
    os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings.local")
    
    # Force SQLite database URL
    os.environ["DATABASE_URL"] = "sqlite:///db.sqlite3"
    
    try:
        from django.core.management import execute_from_command_line
    except ImportError as exc:
        raise ImportError(
            "Couldn't import Django. Are you sure it's installed?"
        ) from exc
    
    execute_from_command_line(sys.argv)
