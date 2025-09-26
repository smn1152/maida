#!/bin/bash

# Maida Vale Django Project Smart Repair Script
# This script analyzes root causes and fixes identified issues

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'
BOLD='\033[1m'

# Project paths
PROJECT_ROOT="/Users/saman/Maida"
DJANGO_ROOT="$PROJECT_ROOT/maida_vale"
VENV_PATH="$PROJECT_ROOT/venv"
MANAGE_PY="$DJANGO_ROOT/manage.py"

# Log file
LOG_FILE="$DJANGO_ROOT/repair_$(date +%Y%m%d_%H%M%S).log"
FIXED_COUNT=0
ANALYZED_COUNT=0

# Backup before making changes
BACKUP_DIR="$DJANGO_ROOT/.backups/$(date +%Y%m%d_%H%M%S)"

print_status() {
    local status=$1
    local message=$2
    local detail=${3:-""}
    
    case $status in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
            ((FIXED_COUNT++))
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "ANALYZE")
            echo -e "${MAGENTA}[ANALYZE]${NC} $message" | tee -a "$LOG_FILE"
            ((ANALYZED_COUNT++))
            ;;
        "SECTION")
            echo -e "\n${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
            echo -e "${BOLD}${CYAN}▶ $message${NC}" | tee -a "$LOG_FILE"
            echo -e "${BOLD}${CYAN}═══════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
            ;;
    esac
    
    if [ -n "$detail" ]; then
        echo "  └─> $detail" | tee -a "$LOG_FILE"
    fi
}

# Create backup
create_backup() {
    print_status "SECTION" "Creating Backup"
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup critical files
    if [ -f "$DJANGO_ROOT/pyproject.toml" ]; then
        cp "$DJANGO_ROOT/pyproject.toml" "$BACKUP_DIR/" 2>/dev/null || true
        print_status "INFO" "Backed up pyproject.toml"
    fi
    
    if [ -f "$DJANGO_ROOT/db.sqlite3" ]; then
        cp "$DJANGO_ROOT/db.sqlite3" "$BACKUP_DIR/" 2>/dev/null || true
        print_status "INFO" "Backed up database"
    fi
    
    if [ -d "$DJANGO_ROOT/config/settings" ]; then
        cp -r "$DJANGO_ROOT/config/settings" "$BACKUP_DIR/" 2>/dev/null || true
        print_status "INFO" "Backed up settings"
    fi
    
    print_status "INFO" "Backup created at: $BACKUP_DIR"
}

# FIX 1: Django Import Error - Root Cause Analysis and Fix
fix_django_import() {
    print_status "SECTION" "Fixing Django Import Error (CRITICAL)"
    
    cd "$PROJECT_ROOT"
    
    # Analyze why Django can't be imported
    print_status "ANALYZE" "Checking virtual environment activation"
    
    if [ ! -f "$VENV_PATH/bin/activate" ]; then
        print_status "ERROR" "Virtual environment activation script missing"
        return 1
    fi
    
    # Check if Django is installed in venv
    print_status "ANALYZE" "Checking if Django is installed in venv"
    
    if [ -f "$VENV_PATH/bin/python" ]; then
        # Try to import Django directly
        if ! "$VENV_PATH/bin/python" -c "import django" 2>/dev/null; then
            print_status "WARNING" "Django not installed in virtual environment"
            
            # Install dependencies using uv or pip
            if command -v uv &> /dev/null && [ -f "$DJANGO_ROOT/pyproject.toml" ]; then
                print_status "INFO" "Installing dependencies with uv..."
                cd "$DJANGO_ROOT"
                uv sync --frozen 2>&1 | tee -a "$LOG_FILE"
                
                if "$VENV_PATH/bin/python" -c "import django" 2>/dev/null; then
                    print_status "SUCCESS" "Django successfully installed with uv"
                else
                    print_status "WARNING" "uv sync failed, trying pip..."
                    "$VENV_PATH/bin/pip" install django 2>&1 | tee -a "$LOG_FILE"
                fi
            else
                print_status "INFO" "Installing Django with pip..."
                "$VENV_PATH/bin/pip" install django 2>&1 | tee -a "$LOG_FILE"
            fi
        else
            print_status "INFO" "Django is installed, checking for import issues..."
            
            # Check for path issues
            print_status "ANALYZE" "Checking Python path configuration"
            "$VENV_PATH/bin/python" -c "import sys; print('Python paths:', sys.path)" 2>&1 | tee -a "$LOG_FILE"
            
            # Check Django version
            local django_version=$("$VENV_PATH/bin/python" -c "import django; print(django.__version__)" 2>/dev/null)
            print_status "INFO" "Django version: $django_version"
        fi
    fi
    
    # Verify fix
    if "$VENV_PATH/bin/python" -c "import django" 2>/dev/null; then
        print_status "SUCCESS" "Django import issue resolved"
    else
        print_status "ERROR" "Django import still failing - manual intervention needed"
    fi
}

# FIX 2: Missing __init__.py files
fix_missing_init_files() {
    print_status "SECTION" "Fixing Missing __init__.py Files"
    
    cd "$DJANGO_ROOT"
    
    local dirs_needing_init=(
        "maida_vale/nesosa"
        "maida_vale/manufacturing"
        "maida_vale/uk_compliance"
    )
    
    for dir in "${dirs_needing_init[@]}"; do
        if [ -d "$dir" ] && [ ! -f "$dir/__init__.py" ]; then
            print_status "INFO" "Creating __init__.py in $dir"
            touch "$dir/__init__.py"
            print_status "SUCCESS" "Created __init__.py in $dir"
        fi
    done
}

# FIX 3: Missing migrations folders
fix_missing_migrations() {
    print_status "SECTION" "Fixing Missing Migration Folders"
    
    cd "$DJANGO_ROOT"
    
    local apps_needing_migrations=(
        "maida_vale/manufacturing"
        "maida_vale/uk_compliance"
    )
    
    for app in "${apps_needing_migrations[@]}"; do
        if [ -d "$app" ] && [ ! -d "$app/migrations" ]; then
            print_status "INFO" "Creating migrations folder in $app"
            mkdir -p "$app/migrations"
            touch "$app/migrations/__init__.py"
            print_status "SUCCESS" "Created migrations folder in $app"
            
            # Try to create initial migration
            if [ -f "$VENV_PATH/bin/python" ]; then
                app_name=$(basename "$app")
                print_status "INFO" "Attempting to create initial migration for $app_name"
                
                cd "$DJANGO_ROOT"
                export DJANGO_SETTINGS_MODULE="config.settings.local"
                "$VENV_PATH/bin/python" manage.py makemigrations "$app_name" --empty --name initial 2>&1 | tee -a "$LOG_FILE" || true
            fi
        fi
    done
}

# FIX 4: SECRET_KEY Configuration
fix_secret_key() {
    print_status "SECTION" "Fixing SECRET_KEY Configuration"
    
    cd "$DJANGO_ROOT"
    
    # Check if SECRET_KEY is in environment or .env
    if [ -f ".env" ]; then
        if grep -q "SECRET_KEY" .env; then
            print_status "INFO" "SECRET_KEY found in .env file"
        else
            print_status "WARNING" "SECRET_KEY not in .env, generating one..."
            
            # Generate a secure SECRET_KEY
            if [ -f "$VENV_PATH/bin/python" ]; then
                SECRET_KEY=$("$VENV_PATH/bin/python" -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())" 2>/dev/null || \
                             "$VENV_PATH/bin/python" -c "import secrets; print(secrets.token_urlsafe(50))" 2>/dev/null || \
                             openssl rand -base64 50)
                
                echo "SECRET_KEY='$SECRET_KEY'" >> .env
                print_status "SUCCESS" "Added SECRET_KEY to .env file"
            fi
        fi
    else
        print_status "WARNING" ".env file doesn't exist, creating one..."
        touch .env
        if [ -f "$VENV_PATH/bin/python" ]; then
            SECRET_KEY=$("$VENV_PATH/bin/python" -c "from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())" 2>/dev/null || \
                         openssl rand -base64 50)
            echo "SECRET_KEY='$SECRET_KEY'" > .env
            print_status "SUCCESS" "Created .env with SECRET_KEY"
        fi
    fi
    
    # Check base.py for proper SECRET_KEY configuration
    if [ -f "config/settings/base.py" ]; then
        print_status "ANALYZE" "Checking base.py for SECRET_KEY configuration"
        
        # Check if it's using environ
        if grep -q "environ" "config/settings/base.py"; then
            print_status "INFO" "base.py appears to use environ for configuration"
        else
            print_status "WARNING" "base.py might not be using environment variables"
            echo "Consider updating base.py to use:" | tee -a "$LOG_FILE"
            echo "  import environ" | tee -a "$LOG_FILE"
            echo "  env = environ.Env()" | tee -a "$LOG_FILE"
            echo "  SECRET_KEY = env('SECRET_KEY')" | tee -a "$LOG_FILE"
        fi
    fi
}

# FIX 5: Install Missing Dependencies
fix_missing_dependencies() {
    print_status "SECTION" "Installing Missing Dependencies"
    
    cd "$DJANGO_ROOT"
    
    local missing_deps=("django-oscar" "wagtail" "psycopg2-binary")
    
    if [ -f "$VENV_PATH/bin/pip" ]; then
        source "$VENV_PATH/bin/activate"
        
        for dep in "${missing_deps[@]}"; do
            print_status "INFO" "Checking/Installing $dep..."
            
            # Check if already installed
            if "$VENV_PATH/bin/pip" show "${dep%-binary}" &>/dev/null; then
                print_status "INFO" "$dep already installed"
            else
                # Try to install
                if "$VENV_PATH/bin/pip" install "$dep" 2>&1 | tee -a "$LOG_FILE"; then
                    print_status "SUCCESS" "Installed $dep"
                    
                    # Add to pyproject.toml if using uv
                    if command -v uv &> /dev/null && [ -f "pyproject.toml" ]; then
                        print_status "INFO" "Adding $dep to pyproject.toml..."
                        uv add "$dep" 2>&1 | tee -a "$LOG_FILE" || true
                    fi
                else
                    print_status "WARNING" "Failed to install $dep"
                fi
            fi
        done
        
        deactivate
    else
        print_status "ERROR" "pip not found in virtual environment"
    fi
}

# FIX 6: Initialize Git Repository
fix_git_repository() {
    print_status "SECTION" "Initializing Git Repository"
    
    cd "$DJANGO_ROOT"
    
    if [ ! -d ".git" ]; then
        print_status "INFO" "Initializing git repository..."
        git init
        
        # Create .gitignore if it doesn't exist
        if [ ! -f ".gitignore" ]; then
            print_status "INFO" "Creating .gitignore..."
            cat > .gitignore << 'EOF'
# Python
*.py[cod]
__pycache__/
*.so
.Python
env/
venv/
.venv/
pip-log.txt
pip-delete-this-directory.txt
.tox/
.coverage
.coverage.*
.cache
coverage.xml
*.cover
.hypothesis/

# Django
*.log
db.sqlite3
db.sqlite3-journal
media/
staticfiles/
local_settings.py

# Environment
.env
.env.*

# IDE
.vscode/
.idea/
*.swp
*.swo
*~
.DS_Store

# Project specific
logs/
*.backup_*
.backups/

# Celery
celerybeat-schedule
celerybeat.pid

# Testing
.pytest_cache/
htmlcov/
EOF
            print_status "SUCCESS" "Created .gitignore"
        fi
        
        # Make initial commit
        git add .gitignore
        git commit -m "Initial commit - Django project setup" 2>&1 | tee -a "$LOG_FILE" || true
        print_status "SUCCESS" "Git repository initialized"
    else
        print_status "INFO" "Git repository already exists"
    fi
}

# FIX 7: Remove hardcoded secrets
check_and_fix_hardcoded_secrets() {
    print_status "SECTION" "Analyzing Hardcoded Secrets"
    
    cd "$DJANGO_ROOT"
    
    print_status "ANALYZE" "Searching for hardcoded secrets in Python files..."
    
    # Find files with potential hardcoded secrets
    local files_with_secrets=$(grep -r "SECRET_KEY\|PASSWORD" --include="*.py" --exclude-dir=venv --exclude-dir=.venv . 2>/dev/null | \
                               grep -v "os.environ\|getenv\|env(" | \
                               cut -d: -f1 | sort -u)
    
    if [ -n "$files_with_secrets" ]; then
        print_status "WARNING" "Files with potential hardcoded secrets:"
        echo "$files_with_secrets" | while read -r file; do
            echo "  - $file" | tee -a "$LOG_FILE"
            
            # Show the problematic lines
            print_status "ANALYZE" "Problematic lines in $file:"
            grep -n "SECRET_KEY\|PASSWORD" "$file" | grep -v "os.environ\|getenv\|env(" | head -3 | tee -a "$LOG_FILE" || true
        done
        
        print_status "INFO" "Recommendation: Move these to environment variables"
        echo "Example fix:" | tee -a "$LOG_FILE"
        echo "  Replace: SECRET_KEY = 'hardcoded-key'" | tee -a "$LOG_FILE"
        echo "  With: SECRET_KEY = os.environ.get('SECRET_KEY')" | tee -a "$LOG_FILE"
    else
        print_status "SUCCESS" "No obvious hardcoded secrets found"
    fi
}

# Run Django checks
run_django_checks() {
    print_status "SECTION" "Running Django System Checks"
    
    cd "$DJANGO_ROOT"
    
    if [ -f "$VENV_PATH/bin/python" ]; then
        source "$VENV_PATH/bin/activate"
        
        export DJANGO_SETTINGS_MODULE="config.settings.local"
        
        # Run Django check
        print_status "INFO" "Running Django system check..."
        if python manage.py check 2>&1 | tee -a "$LOG_FILE"; then
            print_status "SUCCESS" "Django check passed"
        else
            print_status "WARNING" "Django check found issues"
        fi
        
        # Check migrations
        print_status "INFO" "Checking migration status..."
        if python manage.py showmigrations --plan | head -20 2>&1 | tee -a "$LOG_FILE"; then
            print_status "INFO" "Migration check completed"
            
            # Apply migrations if needed
            local unapplied=$(python manage.py showmigrations --plan 2>/dev/null | grep -c "\[ \]" || echo "0")
            if [ "$unapplied" -gt 0 ]; then
                print_status "WARNING" "Found $unapplied unapplied migrations"
                read -p "Apply migrations now? (y/n): " -n 1 -r
                echo
                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    python manage.py migrate 2>&1 | tee -a "$LOG_FILE"
                    print_status "SUCCESS" "Migrations applied"
                fi
            fi
        else
            print_status "WARNING" "Could not check migrations"
        fi
        
        deactivate
    fi
}

# Deep dependency analysis
analyze_dependencies() {
    print_status "SECTION" "Deep Dependency Analysis"
    
    cd "$DJANGO_ROOT"
    
    if [ -f "$VENV_PATH/bin/pip" ]; then
        source "$VENV_PATH/bin/activate"
        
        print_status "ANALYZE" "Checking for dependency conflicts..."
        pip check 2>&1 | tee -a "$LOG_FILE" || true
        
        print_status "ANALYZE" "Listing installed packages..."
        pip list | head -20 | tee -a "$LOG_FILE"
        
        # Check for outdated packages
        print_status "ANALYZE" "Checking for outdated packages..."
        pip list --outdated 2>&1 | head -10 | tee -a "$LOG_FILE" || true
        
        deactivate
    fi
}

# Generate summary report
generate_report() {
    print_status "SECTION" "REPAIR SUMMARY"
    
    echo -e "\n${BOLD}═══════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}REPAIR REPORT:${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    
    echo -e "${GREEN}✅ Fixed items: $FIXED_COUNT${NC}" | tee -a "$LOG_FILE"
    echo -e "${MAGENTA}🔍 Analyzed items: $ANALYZED_COUNT${NC}" | tee -a "$LOG_FILE"
    
    echo -e "\n${BOLD}${CYAN}NEXT STEPS:${NC}" | tee -a "$LOG_FILE"
    echo "1. Review the log file: $LOG_FILE" | tee -a "$LOG_FILE"
    echo "2. Test the application: python manage.py runserver" | tee -a "$LOG_FILE"
    echo "3. Run the diagnostic script again to verify fixes" | tee -a "$LOG_FILE"
    echo "4. Commit changes to git if everything works" | tee -a "$LOG_FILE"
    
    if [ -d "$BACKUP_DIR" ]; then
        echo -e "\n${BOLD}Backup location: $BACKUP_DIR${NC}" | tee -a "$LOG_FILE"
    fi
}

# Main execution
main() {
    echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║     MAIDA VALE SMART REPAIR & ANALYSIS TOOL           ║${NC}"
    echo -e "${BOLD}${MAGENTA}║                 $(date +"%Y-%m-%d %H:%M:%S")                  ║${NC}"
    echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
    
    # Create backup first
    create_backup
    
    # Fix critical error first
    fix_django_import
    
    # Fix structural issues
    fix_missing_init_files
    fix_missing_migrations
    
    # Fix configuration issues
    fix_secret_key
    
    # Fix dependencies
    fix_missing_dependencies
    
    # Fix repository
    fix_git_repository
    
    # Analyze security
    check_and_fix_hardcoded_secrets
    
    # Deep analysis
    analyze_dependencies
    
    # Run Django checks
    run_django_checks
    
    # Generate report
    generate_report
}

# Confirmation prompt
echo -e "${YELLOW}This script will attempt to fix issues in your Django project.${NC}"
echo -e "${YELLOW}A backup will be created before any changes.${NC}"
read -p "Do you want to proceed? (y/n): " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    main
else
    echo "Repair cancelled."
    exit 0
fi
