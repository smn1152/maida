#!/usr/bin/env bash
# quick_start_v2.sh — migrate, ensure superuser, runserver
set -e
source .venv/bin/activate
python manage.py migrate
python - <<'PY'
from django.contrib.auth import get_user_model
U = get_user_model()
if not U.objects.filter(username='admin').exists():
    U.objects.create_superuser('admin','admin@example.com','admin123')
    print('✓ Superuser created: admin/admin123')
else:
    print('✓ Superuser exists')
PY
python manage.py runserver 0.0.0.0:8000
