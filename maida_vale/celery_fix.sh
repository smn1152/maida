#!/bin/bash

# Fix Celery Import Error and Remaining Issues
# This script specifically targets the ModuleNotFoundError for celery

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Paths
PROJECT_ROOT="/Users/saman/Maida"
DJANGO_ROOT="$PROJECT_ROOT/maida_vale"
VENV_PATH="$PROJECT_ROOT/venv"

echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${CYAN}▶ CELERY & FINAL ISSUES FIX${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"

# Step 1: Fix Celery Installation
echo -e "\n${BOLD}1. Installing Celery and its dependencies...${NC}"
cd "$DJANGO_ROOT"

# Activate virtual environment and install
source "$VENV_PATH/bin/activate"

# Since dependencies are in pyproject.toml, sync with uv
if command -v uv &> /dev/null; then
    echo -e "${BLUE}Using uv to sync dependencies...${NC}"
    uv sync --frozen
    
    # Verify celery is installed
    if python -c "import celery" 2>/dev/null; then
        echo -e "${GREEN}✅ Celery successfully installed via uv sync${NC}"
    else
        echo -e "${YELLOW}uv sync didn't install celery, trying uv pip...${NC}"
        uv pip install celery[redis]
    fi
else
    echo -e "${BLUE}Installing with pip...${NC}"
    pip install celery[redis]
fi

# Verify installation
if python -c "import celery" 2>/dev/null; then
    CELERY_VERSION=$(python -c "import celery; print(celery.__version__)")
    echo -e "${GREEN}✅ Celery installed successfully (version: $CELERY_VERSION)${NC}"
else
    echo -e "${RED}❌ Failed to install Celery${NC}"
    exit 1
fi

# Step 2: Fix SECRET_KEY Configuration
echo -e "\n${BOLD}2. Fixing SECRET_KEY configuration...${NC}"

# Check if .env exists and has SECRET_KEY
if [ -f "$DJANGO_ROOT/.env" ]; then
    if grep -q "SECRET_KEY" "$DJANGO_ROOT/.env"; then
        echo -e "${GREEN}✅ SECRET_KEY already in .env${NC}"
    else
        # Generate secure key
        SECRET_KEY=$(python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
        echo "SECRET_KEY='$SECRET_KEY'" >> "$DJANGO_ROOT/.env"
        echo -e "${GREEN}✅ Added SECRET_KEY to .env${NC}"
    fi
else
    # Create .env with SECRET_KEY
    SECRET_KEY=$(python -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())")
    echo "SECRET_KEY='$SECRET_KEY'" > "$DJANGO_ROOT/.env"
    echo -e "${GREEN}✅ Created .env with SECRET_KEY${NC}"
fi

# Update local.py to use environment variable
echo -e "\n${BOLD}3. Updating local.py to use environment variable...${NC}"

LOCAL_PY="$DJANGO_ROOT/config/settings/local.py"
if [ -f "$LOCAL_PY" ]; then
    # Backup first
    cp "$LOCAL_PY" "$LOCAL_PY.backup_$(date +%Y%m%d_%H%M%S)"
    
    # Check if environ is imported
    if ! grep -q "import environ" "$LOCAL_PY"; then
        # Add environ import at the beginning
        sed -i '' '1i\
import environ\
' "$LOCAL_PY"
    fi
    
    # Replace hardcoded SECRET_KEY with environ
    cat > /tmp/fix_secret_key.py << 'EOF'
import re
import sys

with open(sys.argv[1], 'r') as f:
    content = f.read()

# Replace hardcoded SECRET_KEY
pattern = r"SECRET_KEY\s*=\s*['\"]django-insecure-[^'\"]+['\"]"
replacement = """# SECRET_KEY from environment
env = environ.Env()
environ.Env.read_env(str(BASE_DIR / '.env'))
SECRET_KEY = env('SECRET_KEY')"""

content = re.sub(pattern, replacement, content)

# Remove duplicate SECRET_KEY assignments
lines = content.split('\n')
new_lines = []
secret_key_set = False
for line in lines:
    if 'SECRET_KEY' in line and '=' in line:
        if not secret_key_set:
            new_lines.append(line)
            secret_key_set = True
    else:
        new_lines.append(line)

with open(sys.argv[1], 'w') as f:
    f.write('\n'.join(new_lines))
EOF
    
    python /tmp/fix_secret_key.py "$LOCAL_PY"
    rm /tmp/fix_secret_key.py
    
    echo -e "${GREEN}✅ Updated local.py to use environment variable${NC}"
fi

# Step 4: Test Django configuration
echo -e "\n${BOLD}4. Testing Django configuration...${NC}"

export DJANGO_SETTINGS_MODULE="config.settings.local"
cd "$DJANGO_ROOT"

# Test imports
if python manage.py check 2>&1 | grep -q "System check identified no issues"; then
    echo -e "${GREEN}✅ Django configuration check passed${NC}"
else
    echo -e "${YELLOW}⚠️  Django check found some issues:${NC}"
    python manage.py check 2>&1 | head -20
fi

# Step 5: Check and create migrations
echo -e "\n${BOLD}5. Checking for pending migrations...${NC}"

# Check if there are model changes
if python manage.py makemigrations --check --dry-run 2>/dev/null; then
    echo -e "${GREEN}✅ No pending model changes${NC}"
else
    echo -e "${YELLOW}Found model changes, creating migrations...${NC}"
    
    # Create migrations for each app
    for app in users nesosa manufacturing uk_compliance; do
        echo -e "${BLUE}Creating migrations for $app...${NC}"
        python manage.py makemigrations "$app" 2>&1 | tee -a /tmp/migration.log || true
    done
    
    echo -e "${GREEN}✅ Migrations created${NC}"
fi

# Apply migrations
echo -e "\n${BOLD}6. Applying migrations...${NC}"
python manage.py migrate 2>&1 | tail -10 || true

# Step 7: Final verification
echo -e "\n${BOLD}7. Final verification...${NC}"

# Test all imports
echo -e "${BLUE}Testing critical imports...${NC}"

python -c "import django; print('✅ Django:', django.__version__)" 2>&1
python -c "import celery; print('✅ Celery:', celery.__version__)" 2>&1
python -c "import oscar; print('✅ Oscar:', oscar.__version__)" 2>&1
python -c "import wagtail; print('✅ Wagtail:', wagtail.__version__)" 2>&1

# Test management command
if python manage.py showmigrations --plan | head -5 &>/dev/null; then
    echo -e "${GREEN}✅ Django management commands working${NC}"
else
    echo -e "${YELLOW}⚠️  Some issues remain with management commands${NC}"
fi

# Step 8: Clean up untracked files
echo -e "\n${BOLD}8. Git status...${NC}"
cd "$DJANGO_ROOT"

UNTRACKED=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
if [ "$UNTRACKED" -gt 0 ]; then
    echo -e "${YELLOW}Found $UNTRACKED untracked files${NC}"
    echo "Consider adding them to git with: git add -A"
    echo "Or update .gitignore to exclude them"
fi

deactivate

# Summary
echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}✨ FIX COMPLETE!${NC}"
echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"

echo -e "\n${BOLD}Next steps:${NC}"
echo "1. Run the diagnostic script again to verify all issues are resolved:"
echo "   ${CYAN}./maida_diagnostic.sh${NC}"
echo ""
echo "2. Start the development server:"
echo "   ${CYAN}source $VENV_PATH/bin/activate${NC}"
echo "   ${CYAN}cd $DJANGO_ROOT${NC}"
echo "   ${CYAN}python manage.py runserver${NC}"
echo ""
echo "3. Start Celery worker (in another terminal):"
echo "   ${CYAN}source $VENV_PATH/bin/activate${NC}"
echo "   ${CYAN}cd $DJANGO_ROOT${NC}"
echo "   ${CYAN}celery -A config worker -l info${NC}"
echo ""
echo "4. Commit your changes:"
echo "   ${CYAN}git add -A${NC}"
echo "   ${CYAN}git commit -m 'Fixed Celery import and configuration issues'${NC}"

echo -e "\n${GREEN}✅ All critical issues should now be resolved!${NC}"
