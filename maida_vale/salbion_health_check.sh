#!/bin/bash

# Salbion Project Health Check & Repair Script
# This script performs comprehensive diagnostics and fixes for the Django project

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
PROJECT_NAME="Salbion"
DJANGO_SETTINGS_MODULE="config.settings.local"
VENV_PATH="venv"
PYTHON_VERSION="3.11"
LOG_FILE="salbion_health_check_$(date +%Y%m%d_%H%M%S).log"

# Create log file
exec > >(tee -a "$LOG_FILE")
exec 2>&1

echo -e "${BOLD}${CYAN}========================================${NC}"
echo -e "${BOLD}${CYAN}  $PROJECT_NAME Health Check & Repair${NC}"
echo -e "${BOLD}${CYAN}========================================${NC}"
echo -e "${YELLOW}Log file: $LOG_FILE${NC}\n"

# Function to print section headers
print_section() {
    echo -e "\n${BOLD}${BLUE}▶ $1${NC}"
    echo -e "${BLUE}$(printf '%.0s-' {1..50})${NC}"
}

# Function to print success
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

# Function to print error
print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Function to print warning
print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# Function to print info
print_info() {
    echo -e "${CYAN}ℹ $1${NC}"
}

# Track issues and fixes
ISSUES_FOUND=()
FIXES_APPLIED=()
WARNINGS=()

# 1. Check Python Environment
print_section "Checking Python Environment"

# Check if virtual environment exists
if [ -d "$VENV_PATH" ]; then
    print_success "Virtual environment found at $VENV_PATH"
    
    # Activate virtual environment
    if [ -f "$VENV_PATH/bin/activate" ]; then
        source "$VENV_PATH/bin/activate"
        print_success "Virtual environment activated"
    else
        print_error "Virtual environment activation script not found"
        ISSUES_FOUND+=("Virtual environment activation script missing")
    fi
else
    print_warning "Virtual environment not found. Creating..."
    python$PYTHON_VERSION -m venv $VENV_PATH
    source "$VENV_PATH/bin/activate"
    FIXES_APPLIED+=("Created virtual environment")
fi

# Check Python version
CURRENT_PYTHON=$(python --version 2>&1 | grep -oE '[0-9]+\.[0-9]+')
print_info "Current Python version: $CURRENT_PYTHON"

# 2. Check and Install Dependencies
print_section "Checking Dependencies"

# Check if uv is installed
if command -v uv &> /dev/null; then
    print_success "uv package manager found"
    
    # Sync dependencies using uv
    print_info "Syncing dependencies with uv..."
    uv sync
    FIXES_APPLIED+=("Synced dependencies with uv")
else
    print_warning "uv not found, using pip"
    
    # Check if requirements files exist
    if [ -f "requirements/local.txt" ]; then
        pip install -r requirements/local.txt
    elif [ -f "requirements.txt" ]; then
        pip install -r requirements.txt
    else
        print_warning "No requirements file found"
        WARNINGS+=("No requirements file found")
    fi
fi

# 3. Check Django Settings
print_section "Checking Django Settings"

# Export Django settings module
export DJANGO_SETTINGS_MODULE=$DJANGO_SETTINGS_MODULE

# Check if settings file exists
if [ -f "config/settings/local.py" ]; then
    print_success "Local settings file found"
else
    print_error "Local settings file not found"
    ISSUES_FOUND+=("config/settings/local.py missing")
    
    # Create local settings from base if it doesn't exist
    if [ -f "config/settings/base.py" ]; then
        print_info "Creating local.py from base.py template..."
        cat > config/settings/local.py << 'EOF'
from .base import *  # noqa
from .base import INSTALLED_APPS, MIDDLEWARE

DEBUG = True
ALLOWED_HOSTS = ["localhost", "127.0.0.1", "[::1]", ".localhost", "*.localhost"]

# Database
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.sqlite3",
        "NAME": BASE_DIR / "db.sqlite3",
    }
}

# Cache
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "",
    }
}

# Email
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Django Debug Toolbar
if "debug_toolbar" not in INSTALLED_APPS:
    INSTALLED_APPS += ["debug_toolbar"]
    
if "debug_toolbar.middleware.DebugToolbarMiddleware" not in MIDDLEWARE:
    MIDDLEWARE += ["debug_toolbar.middleware.DebugToolbarMiddleware"]

INTERNAL_IPS = ["127.0.0.1", "10.0.2.2"]

# Celery
CELERY_TASK_ALWAYS_EAGER = True
CELERY_TASK_EAGER_PROPAGATES = True

# Django Extensions
if "django_extensions" not in INSTALLED_APPS:
    INSTALLED_APPS += ["django_extensions"]

# Your test runner
TEST_RUNNER = "django.test.runner.DiscoverRunner"
EOF
        FIXES_APPLIED+=("Created config/settings/local.py")
    fi
fi

# 4. Check Django Installation Issues
print_section "Checking Django Configuration"

# Check for common Django issues
python << 'PYTHON_SCRIPT'
import sys
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')

try:
    import django
    django.setup()
    print("✓ Django setup successful")
    
    from django.conf import settings
    from django.apps import apps
    
    # Check for duplicate apps
    app_counts = {}
    duplicates = []
    for app in settings.INSTALLED_APPS:
        if app in app_counts:
            duplicates.append(app)
        app_counts[app] = app_counts.get(app, 0) + 1
    
    if duplicates:
        print(f"✗ Duplicate apps found: {duplicates}")
    else:
        print("✓ No duplicate apps in INSTALLED_APPS")
    
    # Check all apps can be loaded
    failed_apps = []
    for app_config in apps.get_app_configs():
        try:
            app_config.ready()
        except Exception as e:
            failed_apps.append(f"{app_config.name}: {str(e)}")
    
    if failed_apps:
        print(f"✗ Failed to load apps: {failed_apps}")
    else:
        print("✓ All apps loaded successfully")
        
except Exception as e:
    print(f"✗ Django setup failed: {str(e)}")
    sys.exit(1)
PYTHON_SCRIPT

# 5. Database Check
print_section "Checking Database"

# Check if database exists
if [ -f "db.sqlite3" ]; then
    print_success "Database file exists"
    
    # Check migrations
    print_info "Checking for pending migrations..."
    python manage.py showmigrations --plan | tail -n 20
    
    # Make migrations if needed
    print_info "Creating migrations for all apps..."
    python manage.py makemigrations --noinput
    
    # Apply migrations
    print_info "Applying migrations..."
    python manage.py migrate --noinput
    FIXES_APPLIED+=("Applied database migrations")
else
    print_warning "Database does not exist. Creating..."
    python manage.py migrate --noinput
    FIXES_APPLIED+=("Created database and applied migrations")
fi

# 6. Check Static Files
print_section "Checking Static Files"

# Collect static files
print_info "Collecting static files..."
python manage.py collectstatic --noinput --clear
FIXES_APPLIED+=("Collected static files")

# 7. Check Celery Configuration
print_section "Checking Celery Configuration"

python << 'PYTHON_SCRIPT'
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')

try:
    from config.celery_app import app as celery_app
    print("✓ Celery app imported successfully")
    
    # Check celery configuration
    if hasattr(celery_app, 'conf'):
        print(f"✓ Celery broker: {celery_app.conf.broker_url[:20]}...")
        print(f"✓ Celery timezone: {celery_app.conf.timezone}")
except Exception as e:
    print(f"⚠ Celery configuration issue: {str(e)}")
PYTHON_SCRIPT

# 8. Check Required Directories
print_section "Checking Required Directories"

REQUIRED_DIRS=(
    "media"
    "staticfiles"
    "logs"
    "locale"
    "maida_vale/static"
    "maida_vale/templates"
)

for dir in "${REQUIRED_DIRS[@]}"; do
    if [ ! -d "$dir" ]; then
        print_warning "Creating directory: $dir"
        mkdir -p "$dir"
        FIXES_APPLIED+=("Created directory: $dir")
    else
        print_success "Directory exists: $dir"
    fi
done

# 9. Check Django Oscar Integration
print_section "Checking Django Oscar Integration"

python << 'PYTHON_SCRIPT'
import os
import sys
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')

try:
    import django
    django.setup()
    
    # Check if Oscar is installed
    try:
        import oscar
        print(f"✓ Django Oscar version: {oscar.__version__}")
        
        # Check Oscar apps
        from django.conf import settings
        oscar_apps = [app for app in settings.INSTALLED_APPS if 'oscar' in app]
        print(f"✓ Oscar apps installed: {len(oscar_apps)} apps")
        
    except ImportError:
        print("⚠ Django Oscar not installed")
        
except Exception as e:
    print(f"✗ Error checking Oscar: {str(e)}")
PYTHON_SCRIPT

# 10. Check Wagtail CMS Integration
print_section "Checking Wagtail CMS Integration"

python << 'PYTHON_SCRIPT'
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')

try:
    import django
    django.setup()
    
    # Check if Wagtail is installed
    try:
        import wagtail
        print(f"✓ Wagtail version: {wagtail.__version__}")
        
        # Check Wagtail apps
        from django.conf import settings
        wagtail_apps = [app for app in settings.INSTALLED_APPS if 'wagtail' in app]
        print(f"✓ Wagtail apps installed: {len(wagtail_apps)} apps")
        
    except ImportError:
        print("⚠ Wagtail not installed")
        
except Exception as e:
    print(f"✗ Error checking Wagtail: {str(e)}")
PYTHON_SCRIPT

# 11. Run Django System Check
print_section "Running Django System Check"

python manage.py check --deploy --fail-level WARNING 2>&1 | while IFS= read -r line; do
    if [[ $line == *"WARNINGS:"* ]] || [[ $line == *"WARNING"* ]]; then
        print_warning "$line"
    elif [[ $line == *"ERRORS:"* ]] || [[ $line == *"ERROR"* ]]; then
        print_error "$line"
    elif [[ $line == *"System check identified no issues"* ]]; then
        print_success "$line"
    else
        echo "$line"
    fi
done

# 12. Check Custom Apps
print_section "Checking Custom Apps"

# Check if NESOSA app exists
if [ -d "nesosa" ]; then
    print_success "NESOSA (Correspondence Management) app found"
else
    print_warning "NESOSA app not found"
    WARNINGS+=("NESOSA correspondence management app not found")
fi

# Check if manufacturing app exists
if [ -d "manufacturing" ]; then
    print_success "Manufacturing app found"
else
    print_warning "Manufacturing app not found"
    WARNINGS+=("Manufacturing app not found")
fi

# Check if UK compliance app exists
if [ -d "uk_compliance" ] || [ -d "compliance" ]; then
    print_success "UK Compliance app found"
else
    print_warning "UK Compliance app not found"
    WARNINGS+=("UK Compliance app not found")
fi

# 13. Check API Configuration
print_section "Checking API Configuration"

python << 'PYTHON_SCRIPT'
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')

try:
    import django
    django.setup()
    
    # Check if DRF is installed
    try:
        import rest_framework
        print(f"✓ Django REST Framework installed")
        
        from django.conf import settings
        if 'rest_framework' in settings.INSTALLED_APPS:
            print("✓ DRF in INSTALLED_APPS")
        else:
            print("⚠ DRF not in INSTALLED_APPS")
            
    except ImportError:
        print("⚠ Django REST Framework not installed")
        
    # Check if API router exists
    try:
        from config.api_router import api_router
        print("✓ API router configured")
    except ImportError:
        print("⚠ API router not configured")
        
except Exception as e:
    print(f"✗ Error checking API: {str(e)}")
PYTHON_SCRIPT

# 14. Create Superuser if Needed
print_section "Checking Admin User"

python << 'PYTHON_SCRIPT'
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')

import django
django.setup()

from django.contrib.auth import get_user_model

User = get_user_model()
if User.objects.filter(is_superuser=True).exists():
    print("✓ Superuser exists")
else:
    print("⚠ No superuser found. Create one with: python manage.py createsuperuser")
PYTHON_SCRIPT

# 15. Test Server Startup
print_section "Testing Server Startup"

print_info "Attempting to validate server configuration..."

# Test if server can be started (dry run)
timeout 5 python manage.py runserver --noreload --skip-checks 0.0.0.0:8000 > /dev/null 2>&1 &
SERVER_PID=$!

sleep 2

if ps -p $SERVER_PID > /dev/null 2>&1; then
    print_success "Server configuration valid"
    kill $SERVER_PID 2>/dev/null
else
    print_warning "Server startup test failed"
    WARNINGS+=("Server startup test failed")
fi

# 16. Generate Summary Report
print_section "Health Check Summary"

echo -e "\n${BOLD}${CYAN}=== SUMMARY REPORT ===${NC}\n"

# Issues Found
if [ ${#ISSUES_FOUND[@]} -gt 0 ]; then
    echo -e "${BOLD}${RED}Issues Found (${#ISSUES_FOUND[@]}):${NC}"
    for issue in "${ISSUES_FOUND[@]}"; do
        echo -e "  ${RED}• $issue${NC}"
    done
    echo
else
    echo -e "${GREEN}✓ No critical issues found${NC}\n"
fi

# Fixes Applied
if [ ${#FIXES_APPLIED[@]} -gt 0 ]; then
    echo -e "${BOLD}${GREEN}Fixes Applied (${#FIXES_APPLIED[@]}):${NC}"
    for fix in "${FIXES_APPLIED[@]}"; do
        echo -e "  ${GREEN}• $fix${NC}"
    done
    echo
fi

# Warnings
if [ ${#WARNINGS[@]} -gt 0 ]; then
    echo -e "${BOLD}${YELLOW}Warnings (${#WARNINGS[@]}):${NC}"
    for warning in "${WARNINGS[@]}"; do
        echo -e "  ${YELLOW}• $warning${NC}"
    done
    echo
fi

# 17. Next Steps
print_section "Recommended Next Steps"

echo -e "${CYAN}1. Review the log file: ${YELLOW}$LOG_FILE${NC}"
echo -e "${CYAN}2. Create a superuser if needed: ${YELLOW}python manage.py createsuperuser${NC}"
echo -e "${CYAN}3. Start the development server: ${YELLOW}python manage.py runserver${NC}"
echo -e "${CYAN}4. Access admin at: ${YELLOW}http://localhost:8000/admin${NC}"

if [ ${#WARNINGS[@]} -gt 0 ] || [ ${#ISSUES_FOUND[@]} -gt 0 ]; then
    echo -e "\n${YELLOW}5. Address the warnings and issues listed above${NC}"
fi

# Check if specific features need setup
echo -e "\n${BOLD}${CYAN}Feature-Specific Setup:${NC}"

if [[ " ${WARNINGS[@]} " =~ "NESOSA" ]]; then
    echo -e "${YELLOW}• Set up NESOSA correspondence management system${NC}"
fi

if [[ " ${WARNINGS[@]} " =~ "Manufacturing" ]]; then
    echo -e "${YELLOW}• Configure manufacturing module${NC}"
fi

if [[ " ${WARNINGS[@]} " =~ "UK Compliance" ]]; then
    echo -e "${YELLOW}• Set up UK compliance features${NC}"
fi

echo -e "\n${BOLD}${GREEN}Health check completed!${NC}"
echo -e "${CYAN}Full log saved to: ${YELLOW}$LOG_FILE${NC}\n"

# Exit with appropriate code
if [ ${#ISSUES_FOUND[@]} -gt 0 ]; then
    exit 1
else
    exit 0
fi
