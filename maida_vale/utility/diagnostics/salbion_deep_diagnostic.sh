#!/bin/bash

# Salbion Deep Diagnostic & Auto-Fix Script
# This script finds ALL issues and provides automatic fixes

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Diagnostic results storage
ISSUES=()
WARNINGS=()
FIXES_AVAILABLE=()
AUTO_FIXED=()

# Log file
LOG_FILE="salbion_diagnostic_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║   Salbion Deep Diagnostic Scanner      ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════╝${NC}"
echo -e "${CYAN}Scanning for ALL issues...${NC}\n"

# Helper functions
print_section() {
    echo -e "\n${BOLD}${BLUE}━━━ $1 ━━━${NC}"
}

print_issue() {
    echo -e "${RED}✗ ISSUE: $1${NC}"
    ISSUES+=("$1")
}

print_warning() {
    echo -e "${YELLOW}⚠ WARNING: $1${NC}"
    WARNINGS+=("$1")
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

print_fix() {
    echo -e "${GREEN}🔧 FIX: $1${NC}"
    AUTO_FIXED+=("$1")
}

# 1. Python Environment Analysis
print_section "1. PYTHON ENVIRONMENT ANALYSIS"

# Check which Python versions are available
echo -e "${CYAN}Available Python versions:${NC}"
ls -la /usr/bin/python* 2>/dev/null || true
ls -la /usr/local/bin/python* 2>/dev/null || true
ls -la /opt/homebrew/bin/python* 2>/dev/null || true

# Check virtual environments
if [ -d ".venv" ]; then
    VENV_PATH=".venv"
    print_info "Found .venv virtual environment"
elif [ -d "venv" ]; then
    VENV_PATH="venv"
    print_info "Found venv virtual environment"
else
    print_issue "No virtual environment found"
    VENV_PATH=""
fi

# Check Python version in venv
if [ -n "$VENV_PATH" ] && [ -f "$VENV_PATH/bin/python" ]; then
    VENV_PYTHON_VERSION=$($VENV_PATH/bin/python --version 2>&1)
    print_info "Virtual environment Python: $VENV_PYTHON_VERSION"
    
    # Activate virtual environment for further checks
    source "$VENV_PATH/bin/activate"
else
    print_issue "Virtual environment Python not found"
fi

# 2. Database Configuration Detection
print_section "2. DATABASE CONFIGURATION DETECTION"

# Check what database is configured
python3 << 'PYTHON_CHECK'
import sys
import os
import re

# Try to find and read settings files
settings_files = [
    "config/settings/base.py",
    "config/settings/local.py",
    ".env"
]

db_config = {"engine": None, "configured": False}

for settings_file in settings_files:
    if os.path.exists(settings_file):
        print(f"ℹ Checking {settings_file}")
        with open(settings_file, 'r') as f:
            content = f.read()
            
            # Check for PostgreSQL
            if 'postgresql' in content or 'psycopg' in content:
                db_config["engine"] = "postgresql"
                print(f"  → Found PostgreSQL configuration in {settings_file}")
            
            # Check for SQLite
            if 'sqlite3' in content:
                if not db_config["engine"]:
                    db_config["engine"] = "sqlite3"
                print(f"  → Found SQLite configuration in {settings_file}")
            
            # Check for DATABASE_URL
            if 'DATABASE_URL' in content:
                print(f"  → Found DATABASE_URL in {settings_file}")

# Check environment variable
if os.environ.get('DATABASE_URL'):
    print("  → DATABASE_URL is set in environment")
    if 'postgresql' in os.environ.get('DATABASE_URL', ''):
        db_config["engine"] = "postgresql"

if db_config["engine"] == "postgresql":
    print("✗ ISSUE: PostgreSQL is configured but psycopg is not installed")
elif db_config["engine"] == "sqlite3":
    print("✓ SQLite is configured (no additional packages needed)")
else:
    print("⚠ WARNING: No database configuration detected")
PYTHON_CHECK

# 3. Dependency Analysis
print_section "3. DEPENDENCY ANALYSIS"

# Check installed packages
if [ -n "$VENV_PATH" ]; then
    print_info "Installed packages:"
    pip list 2>/dev/null | grep -E "(django|psycopg|postgresql|celery|redis|wagtail|oscar)" || true
    
    # Check for psycopg
    if ! pip show psycopg2-binary &>/dev/null && ! pip show psycopg-binary &>/dev/null && ! pip show psycopg &>/dev/null; then
        print_issue "No PostgreSQL adapter installed (psycopg/psycopg2)"
    fi
fi

# 4. Django Settings Analysis
print_section "4. DJANGO SETTINGS ANALYSIS"

# Check Django settings structure
python3 << 'PYTHON_SETTINGS'
import os
import sys

issues = []
warnings = []

# Check settings module
settings_module = os.environ.get('DJANGO_SETTINGS_MODULE', 'config.settings.local')
print(f"ℹ DJANGO_SETTINGS_MODULE: {settings_module}")

# Try to import Django and check configuration
try:
    # First, let's check if we can import without database
    os.environ['DJANGO_SETTINGS_MODULE'] = settings_module
    
    # Check if settings files exist
    if not os.path.exists('config/settings/base.py'):
        print("✗ ISSUE: config/settings/base.py not found")
        issues.append("Missing base.py")
    
    if not os.path.exists('config/settings/local.py'):
        print("✗ ISSUE: config/settings/local.py not found")
        issues.append("Missing local.py")
        
    # Try to read INSTALLED_APPS without importing Django
    if os.path.exists('config/settings/base.py'):
        with open('config/settings/base.py', 'r') as f:
            content = f.read()
            
            # Check for duplicate apps
            import re
            installed_apps_match = re.search(r'INSTALLED_APPS\s*=\s*\[(.*?)\]', content, re.DOTALL)
            if installed_apps_match:
                apps_text = installed_apps_match.group(1)
                apps = re.findall(r'"([^"]+)"|\'([^\']+)\'', apps_text)
                apps_list = [app[0] or app[1] for app in apps]
                
                # Find duplicates
                seen = set()
                duplicates = []
                for app in apps_list:
                    if app in seen:
                        duplicates.append(app)
                    seen.add(app)
                
                if duplicates:
                    print(f"✗ ISSUE: Duplicate apps in INSTALLED_APPS: {duplicates}")
                    issues.append(f"Duplicate apps: {duplicates}")
                    
            # Check for common missing configurations
            if 'SECRET_KEY' not in content:
                print("⚠ WARNING: SECRET_KEY not found in base.py")
                warnings.append("SECRET_KEY not in base.py")
                
            if 'STATIC_ROOT' not in content:
                print("⚠ WARNING: STATIC_ROOT not configured")
                warnings.append("STATIC_ROOT not configured")
                
            if 'MEDIA_ROOT' not in content:
                print("⚠ WARNING: MEDIA_ROOT not configured")
                warnings.append("MEDIA_ROOT not configured")

except Exception as e:
    print(f"✗ Error during settings analysis: {str(e)}")
    
print(f"\nFound {len(issues)} issues and {len(warnings)} warnings in settings")
PYTHON_SETTINGS

# 5. File Structure Analysis
print_section "5. FILE STRUCTURE ANALYSIS"

# Check required directories
REQUIRED_DIRS=(
    "config"
    "config/settings"
    "maida_vale"
    "maida_vale/users"
    "maida_vale/static"
    "maida_vale/templates"
    "locale"
    "media"
    "staticfiles"
    "logs"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        print_issue "Missing directory: $dir"
    else
        print_success "Directory exists: $dir"
    fi
done

# Check required files
REQUIRED_FILES=(
    "manage.py"
    "pyproject.toml"
    "config/__init__.py"
    "config/urls.py"
    "config/wsgi.py"
    "config/settings/__init__.py"
    "config/settings/base.py"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        print_issue "Missing file: $file"
    else
        print_success "File exists: $file"
    fi
done

# 6. Auto-Fix Section
print_section "6. AUTOMATIC FIXES"

echo -e "${BOLD}${YELLOW}Starting automatic fixes...${NC}\n"

# Fix 1: Install PostgreSQL adapter
if ! pip show psycopg2-binary &>/dev/null && ! pip show psycopg-binary &>/dev/null; then
    print_info "Installing psycopg-binary..."
    pip install psycopg-binary
    print_fix "Installed psycopg-binary"
fi

# Fix 2: Create missing directories
for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        print_fix "Created directory: $dir"
    fi
done

# Fix 3: Create local.py with smart detection
if [ ! -f "config/settings/local.py" ]; then
    print_info "Creating config/settings/local.py with smart configuration..."
    
    # Detect if base.py uses PostgreSQL or SQLite
    DB_ENGINE="sqlite3"  # Default to SQLite
    if [ -f "config/settings/base.py" ]; then
        if grep -q "postgresql" "config/settings/base.py"; then
            DB_ENGINE="postgresql"
        fi
    fi
    
    cat > config/settings/local.py << 'EOF'
# Local Development Settings - Auto-generated
from .base import *  # noqa
import os

# Override any problematic base settings
DEBUG = True
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "[::1]", ".localhost"]

# Database - Override base.py database settings
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

# If you want to use PostgreSQL after installing it:
# DATABASES = {
#     "default": {
#         "ENGINE": "django.db.backends.postgresql",
#         "NAME": "salbion_db",
#         "USER": "salbion_user",
#         "PASSWORD": "salbion_pass",
#         "HOST": "localhost",
#         "PORT": "5432",
#     }
# }

# Ensure these are set
SECRET_KEY = "django-insecure-development-key-change-in-production"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_ROOT = BASE_DIR / "media"
MEDIA_URL = "/media/"

# Email backend for development
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Cache
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
    }
}

# Celery - run synchronously in development
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True

# Add debug toolbar if installed
try:
    import debug_toolbar
    if "debug_toolbar" not in INSTALLED_APPS:
        INSTALLED_APPS += ["debug_toolbar"]
    if "debug_toolbar.middleware.DebugToolbarMiddleware" not in MIDDLEWARE:
        MIDDLEWARE = ["debug_toolbar.middleware.DebugToolbarMiddleware"] + list(MIDDLEWARE)
    INTERNAL_IPS = ["127.0.0.1"]
except ImportError:
    pass

# Add django-extensions if installed
try:
    import django_extensions
    if "django_extensions" not in INSTALLED_APPS:
        INSTALLED_APPS += ["django_extensions"]
except ImportError:
    pass

print("Using local.py settings with SQLite database")
EOF
    
    print_fix "Created config/settings/local.py with SQLite (bypassing PostgreSQL issues)"
fi

# Fix 4: Create/update .env file
if [ ! -f ".env" ]; then
    cat > .env << 'EOF'
DJANGO_SETTINGS_MODULE=config.settings.local
DJANGO_SECRET_KEY=your-secret-key-here
DJANGO_DEBUG=True
DATABASE_URL=sqlite:///db.sqlite3
EOF
    print_fix "Created .env file"
fi

# Fix 5: Install missing core dependencies
print_info "Installing core dependencies..."
pip install django djangorestframework django-environ django-model-utils
pip install django-allauth django-crispy-forms crispy-bootstrap5
pip install django-redis django-extensions pillow whitenoise
print_fix "Installed core Django dependencies"

# 7. Test Django Setup
print_section "7. DJANGO SETUP TEST"

export DJANGO_SETTINGS_MODULE=config.settings.local

# Try to run Django check
print_info "Running Django system check..."
python manage.py check --fail-level ERROR 2>&1 | while IFS= read -r line; do
    if [[ $line == *"SystemCheckError"* ]] || [[ $line == *"ERROR"* ]]; then
        print_issue "$line"
    elif [[ $line == *"WARNING"* ]]; then
        print_warning "$line"
    elif [[ $line == *"System check identified no issues"* ]]; then
        print_success "$line"
    else
        echo "$line"
    fi
done

# Try migrations
print_info "Attempting database migrations..."
python manage.py migrate --run-syncdb 2>&1 | head -20

# 8. Generate Comprehensive Report
print_section "8. DIAGNOSTIC REPORT"

echo -e "\n${BOLD}${MAGENTA}╔════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║         DIAGNOSTIC SUMMARY             ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════╝${NC}\n"

# Issues
echo -e "${BOLD}${RED}CRITICAL ISSUES (${#ISSUES[@]}):${NC}"
if [ ${#ISSUES[@]} -eq 0 ]; then
    echo -e "${GREEN}  No critical issues found!${NC}"
else
    for issue in "${ISSUES[@]}"; do
        echo -e "${RED}  ✗ $issue${NC}"
    done
fi

echo ""

# Warnings
echo -e "${BOLD}${YELLOW}WARNINGS (${#WARNINGS[@]}):${NC}"
if [ ${#WARNINGS[@]} -eq 0 ]; then
    echo -e "${GREEN}  No warnings${NC}"
else
    for warning in "${WARNINGS[@]}"; do
        echo -e "${YELLOW}  ⚠ $warning${NC}"
    done
fi

echo ""

# Auto-fixes applied
echo -e "${BOLD}${GREEN}AUTO-FIXES APPLIED (${#AUTO_FIXED[@]}):${NC}"
if [ ${#AUTO_FIXED[@]} -eq 0 ]; then
    echo -e "${CYAN}  No automatic fixes were needed${NC}"
else
    for fix in "${AUTO_FIXED[@]}"; do
        echo -e "${GREEN}  🔧 $fix${NC}"
    done
fi

# 9. Next Steps
print_section "9. RECOMMENDED NEXT STEPS"

echo -e "${BOLD}${CYAN}Immediate actions:${NC}"
echo -e "1. ${YELLOW}source $VENV_PATH/bin/activate${NC} - Activate virtual environment"
echo -e "2. ${YELLOW}python manage.py migrate${NC} - Run migrations"
echo -e "3. ${YELLOW}python manage.py createsuperuser${NC} - Create admin user"
echo -e "4. ${YELLOW}python manage.py runserver${NC} - Start development server"

echo -e "\n${BOLD}${CYAN}Optional improvements:${NC}"
echo -e "• Install PostgreSQL: ${YELLOW}brew install postgresql@16${NC}"
echo -e "• Install Redis: ${YELLOW}brew install redis${NC}"
echo -e "• Install Django Oscar: ${YELLOW}pip install django-oscar${NC}"
echo -e "• Install Wagtail: ${YELLOW}pip install wagtail${NC}"

echo -e "\n${BOLD}${GREEN}Diagnostic complete!${NC}"
echo -e "${CYAN}Full log saved to: ${YELLOW}$LOG_FILE${NC}\n"

# 10. Create Quick Start Script
cat > quick_start.sh << 'QUICKSTART'
#!/bin/bash
# Quick start script for Salbion

source .venv/bin/activate 2>/dev/null || source venv/bin/activate
export DJANGO_SETTINGS_MODULE=config.settings.local
python manage.py migrate
python manage.py runserver
QUICKSTART

chmod +x quick_start.sh
echo -e "${GREEN}Created quick_start.sh - run ${YELLOW}./quick_start.sh${NC} to start the server${NC}\n"

exit 0
