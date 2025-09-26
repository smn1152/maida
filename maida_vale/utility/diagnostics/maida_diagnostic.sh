#!/bin/bash

# Maida Vale Django Project Deep Diagnostic Script
# Author: Assistant
# Description: Comprehensive health check for Django project

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Project paths
PROJECT_ROOT="/Users/saman/Maida"
DJANGO_ROOT="$PROJECT_ROOT/maida_vale"
VENV_PATH="$PROJECT_ROOT/venv"
MANAGE_PY="$DJANGO_ROOT/manage.py"
SETTINGS_MODULE="config.settings.local"

# Log file
LOG_FILE="$DJANGO_ROOT/diagnostic_$(date +%Y%m%d_%H%M%S).log"
ERROR_COUNT=0
WARNING_COUNT=0
INFO_COUNT=0

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    local detail=${3:-""}
    
    case $status in
        "ERROR")
            echo -e "${RED}[ERROR]${NC} $message" | tee -a "$LOG_FILE"
            ((ERROR_COUNT++))
            ;;
        "WARNING")
            echo -e "${YELLOW}[WARNING]${NC} $message" | tee -a "$LOG_FILE"
            ((WARNING_COUNT++))
            ;;
        "SUCCESS")
            echo -e "${GREEN}[SUCCESS]${NC} $message" | tee -a "$LOG_FILE"
            ;;
        "INFO")
            echo -e "${BLUE}[INFO]${NC} $message" | tee -a "$LOG_FILE"
            ((INFO_COUNT++))
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

# Check if running from correct directory
check_directory() {
    print_status "SECTION" "Checking Project Directory"
    
    if [ ! -d "$PROJECT_ROOT" ]; then
        print_status "ERROR" "Project root not found: $PROJECT_ROOT"
        exit 1
    fi
    
    cd "$PROJECT_ROOT"
    print_status "SUCCESS" "Project root found: $PROJECT_ROOT"
    
    # Check for essential directories
    local dirs=("maida_vale" "venv")
    for dir in "${dirs[@]}"; do
        if [ -d "$dir" ]; then
            print_status "SUCCESS" "Directory exists: $dir"
        else
            print_status "ERROR" "Missing directory: $dir"
        fi
    done
}

# Check Python environment
check_python_env() {
    print_status "SECTION" "Checking Python Environment"
    
    # Check if virtual environment exists
    if [ -d "$VENV_PATH" ]; then
        print_status "SUCCESS" "Virtual environment found"
        
        # Check Python version in venv
        if [ -f "$VENV_PATH/bin/python" ]; then
            local python_version=$("$VENV_PATH/bin/python" --version 2>&1)
            print_status "INFO" "Python version: $python_version"
            
            # Check if it's Python 3.11 as expected
            if [[ $python_version == *"3.11"* ]]; then
                print_status "SUCCESS" "Using expected Python 3.11"
            else
                print_status "WARNING" "Not using Python 3.11: $python_version"
            fi
        else
            print_status "ERROR" "Python executable not found in venv"
        fi
    else
        print_status "ERROR" "Virtual environment not found at: $VENV_PATH"
    fi
    
    # Check for uv package manager
    if command -v uv &> /dev/null; then
        print_status "SUCCESS" "uv package manager found"
        uv --version | tee -a "$LOG_FILE"
    else
        print_status "WARNING" "uv package manager not found (using pip fallback)"
    fi
}

# Check Django structure
check_django_structure() {
    print_status "SECTION" "Checking Django Project Structure"
    
    cd "$DJANGO_ROOT"
    
    # Essential Django files
    local files=("manage.py" "pyproject.toml")
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            print_status "SUCCESS" "Found: $file"
            if [ "$file" == "manage.py" ]; then
                if [ -x "$file" ]; then
                    print_status "SUCCESS" "manage.py is executable"
                else
                    print_status "WARNING" "manage.py is not executable"
                    chmod +x "$file"
                    print_status "INFO" "Made manage.py executable"
                fi
            fi
        else
            print_status "ERROR" "Missing: $file"
        fi
    done
    
    # Check Django apps
    local apps=("config" "maida_vale/users" "maida_vale/nesosa" "maida_vale/manufacturing" "maida_vale/uk_compliance")
    for app in "${apps[@]}"; do
        if [ -d "$app" ]; then
            print_status "SUCCESS" "App directory exists: $app"
            
            # Check for __init__.py
            if [ ! -f "$app/__init__.py" ]; then
                print_status "WARNING" "Missing __init__.py in $app"
            fi
            
            # Check for migrations folder
            if [[ "$app" != "config" ]] && [ ! -d "$app/migrations" ]; then
                print_status "WARNING" "Missing migrations folder in $app"
            fi
        else
            print_status "WARNING" "App directory missing: $app"
        fi
    done
}

# Check settings files
check_settings() {
    print_status "SECTION" "Checking Django Settings"
    
    local settings_dir="$DJANGO_ROOT/config/settings"
    
    if [ -d "$settings_dir" ]; then
        print_status "SUCCESS" "Settings directory exists"
        
        local settings_files=("__init__.py" "base.py" "local.py" "production.py" "test.py")
        for file in "${settings_files[@]}"; do
            if [ -f "$settings_dir/$file" ]; then
                print_status "SUCCESS" "Settings file exists: $file"
                
                # Check for common issues in settings
                if [ "$file" == "base.py" ]; then
                    # Check for SECRET_KEY
                    if grep -q "SECRET_KEY" "$settings_dir/$file"; then
                        print_status "SUCCESS" "SECRET_KEY found in base.py"
                    else
                        print_status "WARNING" "SECRET_KEY not found in base.py"
                    fi
                    
                    # Check for INSTALLED_APPS duplicates
                    local duplicates=$(grep -o "'[^']*'" "$settings_dir/$file" | grep -E "django\.|allauth\.|rest_framework" | sort | uniq -d)
                    if [ -n "$duplicates" ]; then
                        print_status "WARNING" "Possible duplicate apps in INSTALLED_APPS:"
                        echo "$duplicates" | tee -a "$LOG_FILE"
                    fi
                fi
            else
                print_status "ERROR" "Missing settings file: $file"
            fi
        done
        
        # Check for backup files
        local backup_files=$(find "$settings_dir" -name "*.backup_*" 2>/dev/null)
        if [ -n "$backup_files" ]; then
            print_status "INFO" "Found backup settings files:"
            echo "$backup_files" | tee -a "$LOG_FILE"
        fi
    else
        print_status "ERROR" "Settings directory not found: $settings_dir"
    fi
}

# Check dependencies
check_dependencies() {
    print_status "SECTION" "Checking Dependencies"
    
    cd "$DJANGO_ROOT"
    
    # Check pyproject.toml
    if [ -f "pyproject.toml" ]; then
        print_status "SUCCESS" "pyproject.toml found"
        
        # Check for key dependencies
        local deps=("django" "django-oscar" "wagtail" "celery" "redis" "psycopg2" "pillow")
        for dep in "${deps[@]}"; do
            if grep -qi "$dep" pyproject.toml; then
                print_status "SUCCESS" "Dependency found: $dep"
            else
                print_status "WARNING" "Dependency might be missing: $dep"
            fi
        done
    else
        print_status "ERROR" "pyproject.toml not found"
    fi
    
    # Check uv.lock
    if [ -f "uv.lock" ]; then
        print_status "SUCCESS" "uv.lock found (dependencies locked)"
        local lock_age=$(( ($(date +%s) - $(stat -f%m "uv.lock" 2>/dev/null || stat -c%Y "uv.lock" 2>/dev/null)) / 86400 ))
        if [ "$lock_age" -gt 30 ]; then
            print_status "WARNING" "uv.lock is $lock_age days old, consider updating"
        fi
    else
        print_status "WARNING" "uv.lock not found (dependencies not locked)"
    fi
    
    # Check for conflicting requirement files
    if [ -f "requirements.txt" ] || [ -f "requirements-dev.txt" ]; then
        print_status "INFO" "Legacy requirements.txt files found (consider removing if using pyproject.toml)"
    fi
}

# Check database
check_database() {
    print_status "SECTION" "Checking Database"
    
    cd "$DJANGO_ROOT"
    
    # Check for SQLite database
    if [ -f "db.sqlite3" ]; then
        local db_size=$(du -h "db.sqlite3" | cut -f1)
        print_status "SUCCESS" "SQLite database found (size: $db_size)"
        
        # Check for backup
        local backup_files=$(ls db.sqlite3.backup_* 2>/dev/null | head -n 5)
        if [ -n "$backup_files" ]; then
            print_status "INFO" "Database backups found:"
            echo "$backup_files" | tee -a "$LOG_FILE"
        fi
        
        # Check database integrity
        if command -v sqlite3 &> /dev/null; then
            if sqlite3 "db.sqlite3" "PRAGMA integrity_check;" &> /dev/null; then
                print_status "SUCCESS" "Database integrity check passed"
            else
                print_status "ERROR" "Database integrity check failed"
            fi
        fi
    else
        print_status "WARNING" "SQLite database not found (might be using PostgreSQL)"
    fi
}

# Check static files
check_static_files() {
    print_status "SECTION" "Checking Static Files"
    
    cd "$DJANGO_ROOT"
    
    # Check static directories
    if [ -d "staticfiles" ]; then
        local static_count=$(find staticfiles -type f | wc -l | tr -d ' ')
        print_status "SUCCESS" "Static files collected ($static_count files)"
    else
        print_status "WARNING" "staticfiles directory not found (run collectstatic)"
    fi
    
    if [ -d "maida_vale/static" ]; then
        print_status "SUCCESS" "Source static directory exists"
    else
        print_status "WARNING" "Source static directory not found"
    fi
    
    # Check media directory
    if [ -d "media" ]; then
        print_status "SUCCESS" "Media directory exists"
    else
        print_status "INFO" "Media directory not found (will be created when needed)"
    fi
}

# Check for Python syntax errors
check_python_syntax() {
    print_status "SECTION" "Checking Python Syntax"
    
    cd "$DJANGO_ROOT"
    
    # Find all Python files and check syntax
    local error_files=""
    local total_files=0
    local checked_files=0
    
    while IFS= read -r -d '' file; do
        ((total_files++))
        if ! python3 -m py_compile "$file" 2>/dev/null; then
            error_files="$error_files\n  - $file"
        else
            ((checked_files++))
        fi
    done < <(find . -name "*.py" -type f -not -path "./venv/*" -not -path "./.venv/*" -print0)
    
    print_status "INFO" "Checked $total_files Python files"
    
    if [ -n "$error_files" ]; then
        print_status "ERROR" "Python syntax errors found in:$error_files"
    else
        print_status "SUCCESS" "All Python files have valid syntax"
    fi
}

# Check Django management commands
check_django_commands() {
    print_status "SECTION" "Checking Django Management Commands"
    
    cd "$DJANGO_ROOT"
    
    # Activate virtual environment
    if [ -f "$VENV_PATH/bin/activate" ]; then
        source "$VENV_PATH/bin/activate"
        
        # Check if Django is importable
        if python -c "import django" 2>/dev/null; then
            print_status "SUCCESS" "Django is importable"
            
            # Check Django version
            local django_version=$(python -c "import django; print(django.__version__)" 2>/dev/null)
            print_status "INFO" "Django version: $django_version"
            
            # Try to check migrations
            export DJANGO_SETTINGS_MODULE="$SETTINGS_MODULE"
            
            if python manage.py showmigrations --plan | head -n 5 &>/dev/null; then
                print_status "SUCCESS" "Django migrations are accessible"
                
                # Check for unapplied migrations
                local unapplied=$(python manage.py showmigrations --plan | grep -c "\[ \]" || true)
                if [ "$unapplied" -gt 0 ]; then
                    print_status "WARNING" "Found $unapplied unapplied migrations"
                else
                    print_status "SUCCESS" "All migrations applied"
                fi
            else
                print_status "ERROR" "Cannot access Django migrations"
            fi
            
            # Check for missing migrations
            if python manage.py makemigrations --check --dry-run &>/dev/null; then
                print_status "SUCCESS" "No missing migrations"
            else
                print_status "WARNING" "Model changes detected without migrations"
            fi
            
        else
            print_status "ERROR" "Django is not importable"
        fi
        
        deactivate
    else
        print_status "ERROR" "Cannot activate virtual environment"
    fi
}

# Check for common security issues
check_security() {
    print_status "SECTION" "Checking Security Issues"
    
    cd "$DJANGO_ROOT"
    
    # Check for hardcoded secrets
    local secret_patterns=("SECRET_KEY.*=.*['\"]" "PASSWORD.*=.*['\"]" "API_KEY.*=.*['\"]" "TOKEN.*=.*['\"]")
    
    for pattern in "${secret_patterns[@]}"; do
        local files_with_secrets=$(grep -r "$pattern" --include="*.py" --exclude-dir=venv --exclude-dir=.venv 2>/dev/null | grep -v "os.environ" | grep -v "getenv" | head -n 3)
        if [ -n "$files_with_secrets" ]; then
            print_status "WARNING" "Possible hardcoded secrets found (pattern: $pattern)"
        fi
    done
    
    # Check DEBUG setting in production
    if [ -f "config/settings/production.py" ]; then
        if grep -q "DEBUG.*=.*True" "config/settings/production.py"; then
            print_status "ERROR" "DEBUG=True in production settings!"
        else
            print_status "SUCCESS" "DEBUG is not True in production settings"
        fi
    fi
    
    # Check for .env file
    if [ -f ".env" ]; then
        print_status "SUCCESS" ".env file found"
        if [ -f ".env.example" ]; then
            print_status "SUCCESS" ".env.example found for reference"
        fi
    else
        print_status "INFO" ".env file not found (using other config method)"
    fi
}

# Check logs
check_logs() {
    print_status "SECTION" "Checking Logs"
    
    cd "$DJANGO_ROOT"
    
    if [ -d "logs" ]; then
        print_status "SUCCESS" "Logs directory exists"
        
        # Check for recent errors in log files
        local log_files=$(find logs -name "*.log" -type f 2>/dev/null | head -n 5)
        if [ -n "$log_files" ]; then
            print_status "INFO" "Found log files:"
            for log in $log_files; do
                local log_size=$(du -h "$log" | cut -f1)
                echo "  - $log (size: $log_size)" | tee -a "$LOG_FILE"
                
                # Check for recent errors
                local recent_errors=$(tail -n 100 "$log" 2>/dev/null | grep -i "error" | wc -l | tr -d ' ')
                if [ "$recent_errors" -gt 0 ]; then
                    print_status "WARNING" "Found $recent_errors error entries in recent logs of $log"
                fi
            done
        else
            print_status "INFO" "No log files found"
        fi
    else
        print_status "INFO" "Logs directory not found"
    fi
}

# Check Git repository
check_git() {
    print_status "SECTION" "Checking Git Repository"
    
    cd "$DJANGO_ROOT"
    
    if [ -d ".git" ]; then
        print_status "SUCCESS" "Git repository found"
        
        # Check for uncommitted changes
        if git diff --quiet 2>/dev/null; then
            print_status "SUCCESS" "No uncommitted changes"
        else
            local changed_files=$(git diff --name-only | wc -l | tr -d ' ')
            print_status "WARNING" "Found $changed_files files with uncommitted changes"
        fi
        
        # Check for untracked files
        local untracked=$(git ls-files --others --exclude-standard | wc -l | tr -d ' ')
        if [ "$untracked" -gt 0 ]; then
            print_status "INFO" "Found $untracked untracked files"
        fi
        
        # Check current branch
        local current_branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
        print_status "INFO" "Current branch: $current_branch"
    else
        print_status "WARNING" "Not a git repository"
    fi
}

# Check Celery and Redis
check_celery_redis() {
    print_status "SECTION" "Checking Celery and Redis"
    
    # Check if Redis is running
    if command -v redis-cli &> /dev/null; then
        if redis-cli ping &> /dev/null; then
            print_status "SUCCESS" "Redis is running"
        else
            print_status "WARNING" "Redis is not running"
        fi
    else
        print_status "INFO" "Redis CLI not found"
    fi
    
    # Check Celery configuration
    if [ -f "$DJANGO_ROOT/config/celery_app.py" ]; then
        print_status "SUCCESS" "Celery configuration found"
    else
        print_status "WARNING" "Celery configuration not found"
    fi
}

# Check for NESOSA specific files
check_nesosa() {
    print_status "SECTION" "Checking NESOSA Components"
    
    local nesosa_dir="$DJANGO_ROOT/maida_vale/nesosa"
    
    if [ -d "$nesosa_dir" ]; then
        print_status "SUCCESS" "NESOSA app directory exists"
        
        # Check for key NESOSA components
        local components=("models" "views" "forms" "templates")
        for comp in "${components[@]}"; do
            if [ -d "$nesosa_dir/$comp" ] || [ -f "$nesosa_dir/$comp.py" ]; then
                print_status "SUCCESS" "NESOSA $comp found"
            else
                print_status "WARNING" "NESOSA $comp not found"
            fi
        done
    else
        print_status "ERROR" "NESOSA directory not found"
    fi
}

# Generate summary report
generate_summary() {
    print_status "SECTION" "DIAGNOSTIC SUMMARY"
    
    echo -e "\n${BOLD}═══════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}FINAL REPORT:${NC}" | tee -a "$LOG_FILE"
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}" | tee -a "$LOG_FILE"
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo -e "${RED}❌ Errors: $ERROR_COUNT${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${GREEN}✅ No errors found${NC}" | tee -a "$LOG_FILE"
    fi
    
    if [ "$WARNING_COUNT" -gt 0 ]; then
        echo -e "${YELLOW}⚠️  Warnings: $WARNING_COUNT${NC}" | tee -a "$LOG_FILE"
    else
        echo -e "${GREEN}✅ No warnings${NC}" | tee -a "$LOG_FILE"
    fi
    
    echo -e "${BLUE}ℹ️  Info items: $INFO_COUNT${NC}" | tee -a "$LOG_FILE"
    
    echo -e "\n${BOLD}Log saved to: $LOG_FILE${NC}" | tee -a "$LOG_FILE"
    
    # Provide recommendations
    echo -e "\n${BOLD}${CYAN}RECOMMENDATIONS:${NC}" | tee -a "$LOG_FILE"
    
    if [ "$ERROR_COUNT" -gt 0 ]; then
        echo "1. Fix critical errors first (see ERROR entries above)" | tee -a "$LOG_FILE"
    fi
    
    if [ "$WARNING_COUNT" -gt 0 ]; then
        echo "2. Address warnings to improve stability" | tee -a "$LOG_FILE"
    fi
    
    echo "3. Run 'python manage.py migrate' if migrations are pending" | tee -a "$LOG_FILE"
    echo "4. Run 'python manage.py collectstatic' if static files are missing" | tee -a "$LOG_FILE"
    echo "5. Consider setting up automated backups for the database" | tee -a "$LOG_FILE"
    
    # Exit with appropriate code
    if [ "$ERROR_COUNT" -gt 0 ]; then
        exit 1
    else
        exit 0
    fi
}

# Main execution
main() {
    echo -e "${BOLD}${MAGENTA}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BOLD}${MAGENTA}║     MAIDA VALE DJANGO PROJECT DIAGNOSTIC TOOL         ║${NC}"
    echo -e "${BOLD}${MAGENTA}║                 $(date +"%Y-%m-%d %H:%M:%S")                  ║${NC}"
    echo -e "${BOLD}${MAGENTA}╚════════════════════════════════════════════════════════╝${NC}"
    
    # Run all checks
    check_directory
    check_python_env
    check_django_structure
    check_settings
    check_dependencies
    check_database
    check_static_files
    check_python_syntax
    check_django_commands
    check_security
    check_logs
    check_git
    check_celery_redis
    check_nesosa
    
    # Generate final summary
    generate_summary
}

# Run the diagnostic
main
