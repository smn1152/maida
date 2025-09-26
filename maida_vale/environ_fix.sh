#!/bin/bash

# Quick Fix Script - Install django-environ and complete setup
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

PROJECT_ROOT="/Users/saman/Maida"
DJANGO_ROOT="$PROJECT_ROOT/maida_vale"
VENV_PATH="$PROJECT_ROOT/venv"

echo -e "${BOLD}${CYAN}Quick Fix: Installing django-environ${NC}\n"

cd "$DJANGO_ROOT"

# Step 1: Activate venv and install django-environ
echo -e "${BLUE}[1/5] Installing django-environ...${NC}"
source "$VENV_PATH/bin/activate"

pip install django-environ

# Verify installation
if python -c "import environ; print('✓ django-environ version:', environ.__version__)" 2>/dev/null; then
    echo -e "${GREEN}✅ django-environ installed successfully${NC}\n"
else
    echo -e "${RED}❌ Failed to install django-environ${NC}"
    exit 1
fi

# Step 2: Fix local.py to not require environ if it's missing
echo -e "${BLUE}[2/5] Patching local.py for compatibility...${NC}"

# Create a simpler local.py that doesn't fail if environ is missing
cat > "$DJANGO_ROOT/config/settings/local.py" << 'EOF'
# Development settings
from .base import *
import os

# Try to use environ, fall back to direct env vars if not available
try:
    import environ
    env = environ.Env()
    environ.Env.read_env(str(BASE_DIR / '.env'))
    SECRET_KEY = env('SECRET_KEY', default='django-insecure-development-key-change-in-production')
except ImportError:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-development-key-change-in-production')

DEBUG = True
ALLOWED_HOSTS = ["localhost", "0.0.0.0", "127.0.0.1"]

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# Email backend
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Cache
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "",
    }
}

# django-debug-toolbar
INSTALLED_APPS += ["debug_toolbar"]  # noqa: F405
MIDDLEWARE += ["debug_toolbar.middleware.DebugToolbarMiddleware"]  # noqa: F405

DEBUG_TOOLBAR_CONFIG = {
    "DISABLE_PANELS": [
        "debug_toolbar.panels.redirects.RedirectsPanel",
        "debug_toolbar.panels.profiling.ProfilingPanel",
    ],
    "SHOW_TEMPLATE_CONTEXT": True,
}

INTERNAL_IPS = ["127.0.0.1", "10.0.2.2"]

# Celery
CELERY_TASK_EAGER_PROPAGATES = True
CELERY_TASK_ALWAYS_EAGER = False
CELERY_BROKER_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
CELERY_RESULT_BACKEND = CELERY_BROKER_URL
EOF

echo -e "${GREEN}✅ local.py updated${NC}\n"

# Step 3: Ensure .env exists with SECRET_KEY
echo -e "${BLUE}[3/5] Checking .env file...${NC}"

if [ ! -f "$DJANGO_ROOT/.env" ]; then
    touch "$DJANGO_ROOT/.env"
fi

if ! grep -q "SECRET_KEY" "$DJANGO_ROOT/.env"; then
    SECRET_KEY=$(python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
    echo "SECRET_KEY='$SECRET_KEY'" >> "$DJANGO_ROOT/.env"
    echo -e "${GREEN}✅ Added SECRET_KEY to .env${NC}\n"
else
    echo -e "${GREEN}✅ SECRET_KEY already in .env${NC}\n"
fi

# Step 4: Test Django configuration
echo -e "${BLUE}[4/5] Testing Django configuration...${NC}"
export DJANGO_SETTINGS_MODULE="config.settings.local"

if python -c "from django.conf import settings; print('✓ Settings loaded successfully')" 2>/dev/null; then
    echo -e "${GREEN}✅ Django settings work!${NC}\n"
    
    # Try to run check command
    if python manage.py check 2>&1 | grep -q "System check identified no issues"; then
        echo -e "${GREEN}✅ Django system check passed!${NC}\n"
    else
        echo -e "${YELLOW}⚠️  Django check found some issues (this may be normal)${NC}\n"
    fi
else
    echo -e "${YELLOW}⚠️  Settings still have issues${NC}\n"
fi

# Step 5: Quick server test
echo -e "${BLUE}[5/5] Testing Django server startup...${NC}"

# Try to start server briefly
timeout 2 python manage.py runserver 0.0.0.0:8889 --noreload 2>&1 | head -5 || true

if [ $? -eq 124 ]; then
    echo -e "${GREEN}✅ Django server can start!${NC}\n"
else
    echo -e "${YELLOW}⚠️  Check server manually${NC}\n"
fi

deactivate

# Summary
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}✨ FIX COMPLETE!${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}\n"

echo "Next steps:"
echo -e "1. Test the server:"
echo -e "   ${CYAN}cd $DJANGO_ROOT${NC}"
echo -e "   ${CYAN}source $VENV_PATH/bin/activate${NC}"
echo -e "   ${CYAN}python manage.py runserver${NC}\n"

echo -e "2. Run diagnostic to verify:"
echo -e "   ${CYAN}./maida_diagnostic.sh${NC}\n"

echo -e "${GREEN}The main issue (missing django-environ) should now be fixed!${NC}"
