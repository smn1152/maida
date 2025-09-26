#!/usr/bin/env bash
set -e
source .venv/bin/activate
echo "Python: $(python --version)"
echo "Django: $(python -c 'import django; print(django.get_version())')"
python - <<'PY'
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE','config.settings.local')
django.setup()
from django.conf import settings
print("✓ Django setup OK")
print("✓ DEBUG =", settings.DEBUG)
print("✓ DB =", settings.DATABASES["default"]["ENGINE"])
PY
python manage.py check
python manage.py showmigrations | sed -n '1,80p'
