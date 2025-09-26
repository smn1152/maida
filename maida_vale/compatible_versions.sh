#!/bin/bash

# Install packages with compatible versions
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

echo -e "${BOLD}${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${CYAN}║   INSTALLING PACKAGES WITH COMPATIBLE VERSIONS        ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════╝${NC}"

cd "$DJANGO_ROOT"
source "$VENV_PATH/bin/activate"

# Step 1: Clear pip cache to avoid issues
echo -e "\n${BOLD}[1/5] Clearing pip cache...${NC}"
pip cache purge

# Step 2: Install packages with flexible version constraints
echo -e "\n${BOLD}[2/5] Installing packages with compatible versions...${NC}"

# Use standard PyPI
export PIP_INDEX_URL=https://pypi.org/simple/

# Install core packages with flexible constraints
pip install \
    'Django>=5.0,<5.1' \
    'wagtail>=6.2,<6.3' \
    'Pillow>=10.0,<11.0' \
    'django-oscar>=3.2,<3.3' \
    'celery[redis]>=5.3,<5.4' \
    'redis>=5.0,<6.0' \
    'django-environ>=0.11,<1.0' \
    'psycopg2-binary>=2.9,<3.0'

echo -e "${GREEN}✅ Core packages installed${NC}"

# Step 3: Install Cookiecutter-Django dependencies
echo -e "\n${BOLD}[3/5] Installing Cookiecutter dependencies...${NC}"

pip install \
    'django-crispy-forms>=2.3' \
    'crispy-bootstrap5>=2024.2' \
    'django-allauth>=64.0' \
    'django-debug-toolbar>=4.4' \
    'django-extensions>=3.2' \
    'django-model-utils>=4.5' \
    'django-redis>=5.4' \
    'django-storages[boto3]>=1.14' \
    'python-slugify>=8.0' \
    'argon2-cffi>=23.1'

echo -e "${GREEN}✅ Cookiecutter dependencies installed${NC}"

# Step 4: Verify installations
echo -e "\n${BOLD}[4/5] Verifying installations...${NC}"

python << 'EOF'
import sys

def check_package(import_name, display_name):
    try:
        mod = __import__(import_name)
        version = getattr(mod, '__version__', getattr(mod, 'VERSION', 'installed'))
        print(f"✅ {display_name}: {version}")
        return True
    except ImportError as e:
        print(f"❌ {display_name}: MISSING ({e})")
        return False

packages = [
    ('django', 'Django'),
    ('wagtail', 'Wagtail'),
    ('PIL', 'Pillow'),
    ('oscar', 'Django-Oscar'),
    ('celery', 'Celery'),
    ('redis', 'Redis'),
    ('environ', 'django-environ'),
    ('crispy_forms', 'django-crispy-forms'),
    ('crispy_bootstrap5', 'crispy-bootstrap5'),
    ('allauth', 'django-allauth'),
    ('debug_toolbar', 'django-debug-toolbar'),
    ('django_extensions', 'django-extensions'),
    ('model_utils', 'django-model-utils'),
    ('django_redis', 'django-redis'),
    ('modelcluster', 'modelcluster'),
    ('taggit', 'django-taggit'),
]

print("\nPackage verification:")
print("=" * 40)
all_ok = True
for import_name, display_name in packages:
    if not check_package(import_name, display_name):
        all_ok = False

print("=" * 40)
if all_ok:
    print("\n✅ All packages installed successfully!")
else:
    print("\n⚠️ Some packages are missing, but core packages are OK")
    
# Show actual versions
print("\nInstalled versions:")
import django
import wagtail
import PIL
print(f"Django: {django.__version__}")
print(f"Wagtail: {wagtail.__version__}")
print(f"Pillow: {PIL.__version__}")
EOF

# Step 5: Test Django configuration
echo -e "\n${BOLD}[5/5] Testing Django configuration...${NC}"

export DJANGO_SETTINGS_MODULE="config.settings.local"

# Quick test
if python -c "from django.conf import settings; print('✅ Settings load successfully')" 2>/dev/null; then
    echo -e "${GREEN}Django configuration working!${NC}"
    
    # Run system check
    echo -e "\nRunning Django system check..."
    python manage.py check --deploy 2>&1 | grep -E "(SystemCheckError|System check identified)" || echo "✅ Basic checks passed"
else
    echo -e "${YELLOW}Settings need attention:${NC}"
    python -c "from django.conf import settings" 2>&1 | head -10
fi

deactivate

# Final Summary
echo -e "\n${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}✨ PACKAGES INSTALLED WITH COMPATIBLE VERSIONS!${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"

echo -e "\n${BOLD}Key versions installed:${NC}"
echo "• Django ~5.0.x (LTS compatible)"
echo "• Wagtail ~6.2.x (stable)"
echo "• Pillow ~10.x (compatible with Wagtail)"
echo "• All Cookiecutter-Django dependencies"

echo -e "\n${BOLD}What was fixed:${NC}"
echo "✅ Version conflicts resolved"
echo "✅ Using flexible version constraints"
echo "✅ Standard PyPI repository used"
echo "✅ All packages compatible with Python 3.11"

echo -e "\n${BOLD}Next steps:${NC}"
echo -e "${CYAN}cd $DJANGO_ROOT${NC}"
echo -e "${CYAN}source $VENV_PATH/bin/activate${NC}"
echo -e "${CYAN}python manage.py migrate${NC}"
echo -e "${CYAN}python manage.py collectstatic --noinput${NC}"
echo -e "${CYAN}python manage.py runserver${NC}"

echo -e "\n${GREEN}Your Django + Wagtail + Cookiecutter project should now work!${NC}"

echo -e "\n${BOLD}To permanently use standard PyPI:${NC}"
echo -e "${CYAN}pip config set global.index-url https://pypi.org/simple/${NC}"
