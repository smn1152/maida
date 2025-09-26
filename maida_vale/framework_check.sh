#!/bin/bash

# Comprehensive Framework Check: Django + Wagtail + Cookiecutter-Django
# This script checks, installs, and configures all three frameworks

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Paths
PROJECT_ROOT="/Users/saman/Maida"
DJANGO_ROOT="$PROJECT_ROOT/maida_vale"
VENV_PATH="$PROJECT_ROOT/venv"
SETTINGS_DIR="$DJANGO_ROOT/config/settings"

# Tracking
DJANGO_STATUS="NOT CHECKED"
WAGTAIL_STATUS="NOT CHECKED"
COOKIECUTTER_STATUS="NOT CHECKED"

print_header() {
    echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BOLD}${CYAN}▶ $1${NC}"
    echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}"
}

print_status() {
    local type=$1
    local msg=$2
    case $type in
        SUCCESS) echo -e "${GREEN}✅ $msg${NC}" ;;
        ERROR) echo -e "${RED}❌ $msg${NC}" ;;
        WARNING) echo -e "${YELLOW}⚠️  $msg${NC}" ;;
        INFO) echo -e "${BLUE}ℹ️  $msg${NC}" ;;
        CHECK) echo -e "${MAGENTA}🔍 $msg${NC}" ;;
    esac
}

# Main header
echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}${MAGENTA}║  DJANGO + WAGTAIL + COOKIECUTTER STATUS CHECK         ║${NC}"
echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"

cd "$DJANGO_ROOT"
source "$VENV_PATH/bin/activate"

# ========== DJANGO CHECK ==========
print_header "1. DJANGO FRAMEWORK CHECK"

print_status "CHECK" "Checking Django installation..."

# Check if Django is installed
if python -c "import django" 2>/dev/null; then
    DJANGO_VERSION=$(python -c "import django; print(django.__version__)")
    print_status "SUCCESS" "Django installed: version $DJANGO_VERSION"
    DJANGO_STATUS="INSTALLED"
    
    # Check Django project structure
    if [ -f "manage.py" ] && [ -d "config" ]; then
        print_status "SUCCESS" "Django project structure verified"
        
        # Test Django settings
        export DJANGO_SETTINGS_MODULE="config.settings.local"
        if python -c "from django.conf import settings; print('')" 2>/dev/null; then
            print_status "SUCCESS" "Django settings load correctly"
            
            # Check installed Django apps
            python -c "
from django.conf import settings
print('Installed Django apps:')
django_apps = [app for app in settings.INSTALLED_APPS if app.startswith('django.')]
for app in django_apps[:5]:
    print(f'  - {app}')
if len(django_apps) > 5:
    print(f'  ... and {len(django_apps)-5} more')
" 2>/dev/null || true
            
            # Test Django admin
            if python -c "from django.contrib import admin" 2>/dev/null; then
                print_status "SUCCESS" "Django admin module accessible"
            fi
            
            # Check if server can start
            print_status "CHECK" "Testing Django server..."
            timeout 2 python manage.py runserver 0.0.0.0:8890 --noreload 2>&1 | grep -q "Starting development server" && \
                print_status "SUCCESS" "Django server can start" || \
                print_status "WARNING" "Django server test inconclusive"
                
        else
            print_status "ERROR" "Django settings cannot be loaded"
            DJANGO_STATUS="BROKEN"
        fi
    else
        print_status "ERROR" "Django project structure incomplete"
        DJANGO_STATUS="INCOMPLETE"
    fi
else
    print_status "ERROR" "Django not installed"
    DJANGO_STATUS="NOT INSTALLED"
    
    print_status "INFO" "Installing Django..."
    pip install django
    DJANGO_STATUS="NEWLY INSTALLED"
fi

# ========== WAGTAIL CHECK ==========
print_header "2. WAGTAIL CMS CHECK"

print_status "CHECK" "Checking Wagtail installation..."

# Check if Wagtail is installed
if python -c "import wagtail" 2>/dev/null; then
    WAGTAIL_VERSION=$(python -c "import wagtail; print(wagtail.__version__)")
    print_status "SUCCESS" "Wagtail installed: version $WAGTAIL_VERSION"
    WAGTAIL_STATUS="INSTALLED"
    
    # Check if Wagtail is in INSTALLED_APPS
    if python -c "
from django.conf import settings
import sys
wagtail_apps = [app for app in settings.INSTALLED_APPS if 'wagtail' in app]
if wagtail_apps:
    print('Wagtail apps found in settings:')
    for app in wagtail_apps:
        print(f'  - {app}')
    sys.exit(0)
else:
    sys.exit(1)
" 2>/dev/null; then
        print_status "SUCCESS" "Wagtail integrated in Django settings"
        
        # Check for Wagtail URLs
        if grep -q "wagtail" "$DJANGO_ROOT/config/urls.py" 2>/dev/null; then
            print_status "SUCCESS" "Wagtail URLs configured"
        else
            print_status "WARNING" "Wagtail URLs not found in config/urls.py"
            WAGTAIL_STATUS="NOT CONFIGURED"
        fi
        
        # Check for Wagtail home app
        if [ -d "$DJANGO_ROOT/home" ] || [ -d "$DJANGO_ROOT/maida_vale/home" ]; then
            print_status "SUCCESS" "Wagtail home app found"
        else
            print_status "INFO" "No Wagtail home app found (may need initialization)"
        fi
        
    else
        print_status "WARNING" "Wagtail not in INSTALLED_APPS"
        WAGTAIL_STATUS="NOT INTEGRATED"
        
        # Add Wagtail to INSTALLED_APPS
        print_status "INFO" "Adding Wagtail to settings..."
        
        # Create a patch for base.py
        cat > /tmp/add_wagtail.py << 'EOF'
import sys
settings_file = sys.argv[1]

with open(settings_file, 'r') as f:
    content = f.read()

# Find INSTALLED_APPS
import re
pattern = r'(INSTALLED_APPS\s*=\s*\[)'
wagtail_apps = '''
    # Wagtail CMS
    'wagtail.contrib.forms',
    'wagtail.contrib.redirects',
    'wagtail.embeds',
    'wagtail.sites',
    'wagtail.users',
    'wagtail.snippets',
    'wagtail.documents',
    'wagtail.images',
    'wagtail.search',
    'wagtail.admin',
    'wagtail',
    'modelcluster',
    'taggit','''

if 'wagtail' not in content:
    # Add after THIRD_PARTY_APPS or at the beginning of INSTALLED_APPS
    if 'THIRD_PARTY_APPS = [' in content:
        content = content.replace('THIRD_PARTY_APPS = [', f'THIRD_PARTY_APPS = [{wagtail_apps}')
    else:
        content = re.sub(pattern, r'\1' + wagtail_apps, content, count=1)
    
    with open(settings_file, 'w') as f:
        f.write(content)
    print("Wagtail apps added to settings")
else:
    print("Wagtail already in settings")
EOF
        python /tmp/add_wagtail.py "$SETTINGS_DIR/base.py" 2>/dev/null || \
            print_status "WARNING" "Could not auto-add Wagtail to settings"
    fi
    
else
    print_status "ERROR" "Wagtail not installed"
    WAGTAIL_STATUS="NOT INSTALLED"
    
    print_status "INFO" "Installing Wagtail..."
    pip install wagtail
    WAGTAIL_STATUS="NEWLY INSTALLED"
fi

# ========== COOKIECUTTER-DJANGO CHECK ==========
print_header "3. COOKIECUTTER-DJANGO ANALYSIS"

print_status "CHECK" "Analyzing if this is a Cookiecutter-Django project..."

COOKIECUTTER_INDICATORS=0

# Check for Cookiecutter-Django specific files and patterns
if [ -f "$DJANGO_ROOT/.envs/.local/.django" ] || [ -f "$DJANGO_ROOT/.envs/.production/.django" ]; then
    print_status "SUCCESS" "Found .envs directory structure (Cookiecutter pattern)"
    ((COOKIECUTTER_INDICATORS++))
else
    print_status "INFO" "No .envs directory (not typical Cookiecutter)"
fi

if [ -f "$DJANGO_ROOT/requirements/base.txt" ] || [ -f "$DJANGO_ROOT/requirements/local.txt" ]; then
    print_status "SUCCESS" "Found requirements/ directory (Cookiecutter pattern)"
    ((COOKIECUTTER_INDICATORS++))
else
    print_status "INFO" "No requirements/ directory structure"
fi

if [ -d "$DJANGO_ROOT/config/settings" ] && [ -f "$DJANGO_ROOT/config/urls.py" ]; then
    print_status "SUCCESS" "Found config/ structure (matches Cookiecutter)"
    ((COOKIECUTTER_INDICATORS++))
fi

if [ -f "$DJANGO_ROOT/compose/local/django/Dockerfile" ] || [ -f "$DJANGO_ROOT/local.yml" ]; then
    print_status "SUCCESS" "Found Docker compose files (Cookiecutter pattern)"
    ((COOKIECUTTER_INDICATORS++))
else
    print_status "INFO" "No Docker compose structure found"
fi

# Check for specific Cookiecutter imports/patterns in settings
if grep -q "environ" "$SETTINGS_DIR/base.py" 2>/dev/null; then
    print_status "SUCCESS" "Using django-environ (Cookiecutter pattern)"
    ((COOKIECUTTER_INDICATORS++))
fi

if grep -q "APPS_DIR" "$SETTINGS_DIR/base.py" 2>/dev/null; then
    print_status "SUCCESS" "Found APPS_DIR variable (Cookiecutter pattern)"
    ((COOKIECUTTER_INDICATORS++))
fi

# Determine Cookiecutter status
if [ $COOKIECUTTER_INDICATORS -ge 4 ]; then
    print_status "SUCCESS" "This appears to be a Cookiecutter-Django project!"
    COOKIECUTTER_STATUS="CONFIRMED"
elif [ $COOKIECUTTER_INDICATORS -ge 2 ]; then
    print_status "WARNING" "Partial Cookiecutter-Django patterns detected"
    COOKIECUTTER_STATUS="PARTIAL"
else
    print_status "INFO" "This doesn't appear to be a Cookiecutter-Django project"
    COOKIECUTTER_STATUS="NOT COOKIECUTTER"
fi

echo -e "\nCookiecutter indicators found: $COOKIECUTTER_INDICATORS/6"

# ========== INTEGRATION CHECK ==========
print_header "4. INTEGRATION STATUS"

print_status "CHECK" "Checking framework integration..."

# Check if all three can work together
if [ "$DJANGO_STATUS" == "INSTALLED" ] || [ "$DJANGO_STATUS" == "NEWLY INSTALLED" ]; then
    if [ "$WAGTAIL_STATUS" == "INSTALLED" ] || [ "$WAGTAIL_STATUS" == "NEWLY INSTALLED" ]; then
        print_status "SUCCESS" "Django + Wagtail are compatible and can work together"
        
        # Test basic integration
        if python -c "
from django.conf import settings
import wagtail
print('Integration test: Django', django.__version__, '+ Wagtail', wagtail.__version__)
" 2>/dev/null; then
            print_status "SUCCESS" "Integration test passed"
        fi
    fi
fi

# ========== SETUP RECOMMENDATIONS ==========
print_header "5. SETUP & CONFIGURATION"

if [ "$WAGTAIL_STATUS" == "NOT INTEGRATED" ] || [ "$WAGTAIL_STATUS" == "NEWLY INSTALLED" ]; then
    print_status "INFO" "Setting up Wagtail integration..."
    
    # Add Wagtail URLs
    if ! grep -q "wagtail" "$DJANGO_ROOT/config/urls.py" 2>/dev/null; then
        print_status "INFO" "Add these to your config/urls.py:"
        echo -e "${CYAN}
from wagtail import urls as wagtail_urls
from wagtail.admin import urls as wagtailadmin_urls
from wagtail.documents import urls as wagtaildocs_urls

urlpatterns = [
    path('cms/', include(wagtailadmin_urls)),
    path('documents/', include(wagtaildocs_urls)),
    path('', include(wagtail_urls)),
]${NC}"
    fi
    
    # Create Wagtail app if needed
    print_status "INFO" "To create a Wagtail home app, run:"
    echo -e "${CYAN}python manage.py startapp home${NC}"
fi

# ========== MISSING DEPENDENCIES ==========
print_header "6. DEPENDENCY CHECK"

print_status "CHECK" "Checking for common dependencies..."

deps=("django-environ" "Pillow" "django-allauth" "django-crispy-forms" "django-debug-toolbar")
missing_deps=()

for dep in "${deps[@]}"; do
    dep_import=$(echo "$dep" | tr '-' '_' | sed 's/django_//g')
    if ! python -c "import $dep_import" 2>/dev/null; then
        missing_deps+=("$dep")
    fi
done

if [ ${#missing_deps[@]} -gt 0 ]; then
    print_status "WARNING" "Missing common dependencies: ${missing_deps[*]}"
    print_status "INFO" "Install with: pip install ${missing_deps[*]}"
else
    print_status "SUCCESS" "All common dependencies installed"
fi

deactivate

# ========== FINAL SUMMARY ==========
print_header "FINAL SUMMARY"

echo -e "\n${BOLD}Framework Status:${NC}"
echo -e "├─ Django:          ${GREEN}$DJANGO_STATUS${NC}"
echo -e "├─ Wagtail:         ${YELLOW}$WAGTAIL_STATUS${NC}"
echo -e "└─ Cookiecutter:    ${BLUE}$COOKIECUTTER_STATUS${NC}"

echo -e "\n${BOLD}Recommended Actions:${NC}"

if [ "$DJANGO_STATUS" != "INSTALLED" ]; then
    echo "1. Fix Django installation issues first"
fi

if [ "$WAGTAIL_STATUS" == "NOT INTEGRATED" ] || [ "$WAGTAIL_STATUS" == "NEWLY INSTALLED" ]; then
    echo "2. Complete Wagtail integration:"
    echo "   - Add Wagtail apps to INSTALLED_APPS"
    echo "   - Configure Wagtail URLs"
    echo "   - Run: python manage.py migrate"
    echo "   - Create superuser: python manage.py createsuperuser"
    echo "   - Access Wagtail admin at: http://localhost:8000/cms/"
fi

if [ "$COOKIECUTTER_STATUS" == "NOT COOKIECUTTER" ]; then
    echo "3. Your project structure differs from Cookiecutter-Django"
    echo "   This is fine, but some assumptions may not apply"
fi

echo -e "\n${BOLD}${GREEN}To start your integrated Django + Wagtail server:${NC}"
echo -e "${CYAN}cd $DJANGO_ROOT${NC}"
echo -e "${CYAN}source $VENV_PATH/bin/activate${NC}"
echo -e "${CYAN}python manage.py migrate${NC}"
echo -e "${CYAN}python manage.py runserver${NC}"

echo -e "\n${BOLD}${GREEN}✨ Analysis Complete!${NC}"
