#!/usr/bin/env bash
# quick_verify_v2.sh — standalone verification wrapper
set -e
source .venv/bin/activate
echo "=== Quick Verify v2 ==="
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
