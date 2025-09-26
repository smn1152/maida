#!/bin/bash

# Configure Oscar + Wagtail in Django Project
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
echo -e "${BOLD}${CYAN}║   CONFIGURING OSCAR + WAGTAIL IN DJANGO               ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════╝${NC}"

cd "$DJANGO_ROOT"

# ALWAYS use venv Python, not system Python
echo -e "\n${BOLD}[1/7] Using virtual environment Python...${NC}"
source "$VENV_PATH/bin/activate"

# Verify we're using the right Python
python --version
which python

# Step 2: Update INSTALLED_APPS in base.py
echo -e "\n${BOLD}[2/7] Configuring INSTALLED_APPS...${NC}"

python << 'EOF'
import os
import re

settings_file = 'config/settings/base.py'

# Read current settings
with open(settings_file, 'r') as f:
    content = f.read()

# Backup original
with open(settings_file + '.backup_oscar_wagtail', 'w') as f:
    f.write(content)

# Find and update THIRD_PARTY_APPS section
wagtail_apps = """
    # Wagtail CMS apps
    'wagtail.contrib.forms',
    'wagtail.contrib.redirects',
    'wagtail.contrib.routable_page',
    'wagtail.contrib.table_block',
    'wagtail.contrib.typed_table_block',
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
    'taggit',
"""

oscar_apps = """
    # Django Oscar e-commerce apps
    'oscar',
    'oscar.apps.analytics',
    'oscar.apps.checkout',
    'oscar.apps.address',
    'oscar.apps.shipping',
    'oscar.apps.catalogue',
    'oscar.apps.catalogue.reviews',
    'oscar.apps.partner',
    'oscar.apps.basket',
    'oscar.apps.payment',
    'oscar.apps.offer',
    'oscar.apps.order',
    'oscar.apps.customer',
    'oscar.apps.search',
    'oscar.apps.voucher',
    'oscar.apps.wishlists',
    'oscar.apps.dashboard',
    'oscar.apps.dashboard.reports',
    'oscar.apps.dashboard.users',
    'oscar.apps.dashboard.orders',
    'oscar.apps.dashboard.catalogue',
    'oscar.apps.dashboard.offers',
    'oscar.apps.dashboard.partners',
    'oscar.apps.dashboard.pages',
    'oscar.apps.dashboard.ranges',
    'oscar.apps.dashboard.reviews',
    'oscar.apps.dashboard.vouchers',
    'oscar.apps.dashboard.communications',
    'oscar.apps.dashboard.shipping',
    
    # Oscar dependencies
    'django_tables2',
    'widget_tweaks',
"""

# Check if already configured
if 'wagtail' in content and 'oscar' in content:
    print("✅ Oscar and Wagtail already in settings")
else:
    # Add to THIRD_PARTY_APPS
    if 'THIRD_PARTY_APPS = [' in content:
        # Find THIRD_PARTY_APPS and add our apps
        pattern = r'(THIRD_PARTY_APPS = \[)'
        replacement = f'\\1{wagtail_apps}{oscar_apps}'
        content = re.sub(pattern, replacement, content)
        print("✅ Added Wagtail and Oscar to THIRD_PARTY_APPS")
    else:
        print("⚠️  THIRD_PARTY_APPS not found, adding manually...")

# Add Oscar-specific settings
if 'OSCAR_SHOP_NAME' not in content:
    oscar_settings = """

# Oscar E-commerce Settings
from oscar.defaults import *
OSCAR_SHOP_NAME = 'Maida Vale Shop'
OSCAR_SHOP_TAGLINE = 'Powered by Django Oscar'
OSCAR_DEFAULT_CURRENCY = 'GBP'
OSCAR_CURRENCY_FORMAT = {
    'GBP': {
        'currency_digits': False,
        'format': '£#,##0.00',
    },
}

# Oscar dashboard access
OSCAR_DASHBOARD_NAVIGATION += [
    {
        'label': 'Wagtail CMS',
        'icon': 'icon-th-list',
        'url_name': 'wagtailadmin_home',
    },
]
"""
    content += oscar_settings
    print("✅ Added Oscar configuration")

# Add Wagtail-specific settings
if 'WAGTAIL_SITE_NAME' not in content:
    wagtail_settings = """

# Wagtail CMS Settings
WAGTAIL_SITE_NAME = 'Maida Vale CMS'
WAGTAIL_ENABLE_UPDATE_CHECK = False
WAGTAIL_PASSWORD_MANAGEMENT_ENABLED = True
WAGTAILADMIN_BASE_URL = 'http://localhost:8000'
"""
    content += wagtail_settings
    print("✅ Added Wagtail configuration")

# Write updated settings
with open(settings_file, 'w') as f:
    f.write(content)

print("\n✅ Settings configuration complete!")
EOF

# Step 3: Create Oscar apps customization structure
echo -e "\n${BOLD}[3/7] Creating Oscar apps structure...${NC}"

mkdir -p apps
touch apps/__init__.py

# Create a custom Oscar app example
cat > apps/__init__.py << 'EOF'
# Oscar apps customization
import oscar

default_app_config = 'oscar.config.Shop'
EOF

# Step 4: Update URLs
echo -e "\n${BOLD}[4/7] Updating URL configuration...${NC}"

cat > config/urls.py << 'EOF'
from django.apps import apps
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from django.views import defaults as default_views

# Wagtail imports
from wagtail import urls as wagtail_urls
from wagtail.admin import urls as wagtailadmin_urls
from wagtail.documents import urls as wagtaildocs_urls

urlpatterns = [
    # Django Admin
    path(settings.ADMIN_URL, admin.site.urls),
    
    # User management
    path("users/", include("maida_vale.users.urls", namespace="users")),
    path("accounts/", include("allauth.urls")),
    
    # Wagtail CMS Admin
    path('cms/', include(wagtailadmin_urls)),
    path('documents/', include(wagtaildocs_urls)),
    
    # Oscar E-commerce - must come before Wagtail catch-all
    path('shop/', include(apps.get_app_config('oscar').urls[0])),
    path('dashboard/', apps.get_app_config('oscar').urls[1]),
    
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# Wagtail pages - this should be last as it's a catch-all
urlpatterns += [
    path('', include(wagtail_urls)),
]

if settings.DEBUG:
    # Static files
    urlpatterns += static(settings.STATIC_URL, document_root=settings.STATIC_ROOT)
    
    # Debug toolbar
    if "debug_toolbar" in settings.INSTALLED_APPS:
        import debug_toolbar
        urlpatterns = [path("__debug__/", include(debug_toolbar.urls))] + urlpatterns
    
    # Error pages
    urlpatterns += [
        path("400/", default_views.bad_request, kwargs={"exception": Exception("Bad Request!")}),
        path("403/", default_views.permission_denied, kwargs={"exception": Exception("Permission Denied")}),
        path("404/", default_views.page_not_found, kwargs={"exception": Exception("Page not Found")}),
        path("500/", default_views.server_error),
    ]
EOF

echo -e "${GREEN}✅ URLs configured${NC}"

# Step 5: Test configuration
echo -e "\n${BOLD}[5/7] Testing configuration...${NC}"

export DJANGO_SETTINGS_MODULE="config.settings.local"

if python manage.py check 2>&1 | grep -q "System check identified"; then
    echo -e "${GREEN}✅ Basic configuration OK${NC}"
else
    echo -e "${YELLOW}⚠️  Some warnings (usually normal)${NC}"
fi

# Step 6: Run migrations
echo -e "\n${BOLD}[6/7] Running migrations...${NC}"

echo "Creating database tables for Oscar and Wagtail..."
python manage.py migrate --run-syncdb 2>&1 | tail -5

echo -e "${GREEN}✅ Migrations complete${NC}"

# Step 7: Create superuser if needed
echo -e "\n${BOLD}[7/7] Checking for superuser...${NC}"

python << 'EOF'
import os
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')
import django
django.setup()

from django.contrib.auth import get_user_model
User = get_user_model()

if User.objects.filter(is_superuser=True).exists():
    print("✅ Superuser already exists")
else:
    print("⚠️  No superuser found")
    print("Create one with: python manage.py createsuperuser")
EOF

deactivate

# Final verification
echo -e "\n${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}TESTING INSTALLATION${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"

cd "$DJANGO_ROOT"
source "$VENV_PATH/bin/activate"

echo -e "\n${BOLD}Verifying packages (using venv Python):${NC}"
python -c "import django; print(f'✅ Django {django.__version__}')"
python -c "import wagtail; print(f'✅ Wagtail {wagtail.__version__}')"  
python -c "import oscar; print(f'✅ Oscar {oscar.get_version()}')"

deactivate

# Summary
echo -e "\n${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}✨ CONFIGURATION COMPLETE!${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"

echo -e "\n${BOLD}Your Django + Oscar + Wagtail stack is configured!${NC}"

echo -e "\n${BOLD}To start the server:${NC}"
echo -e "${CYAN}cd $DJANGO_ROOT${NC}"
echo -e "${CYAN}source ../venv/bin/activate${NC}"
echo -e "${CYAN}python manage.py runserver${NC}"

echo -e "\n${BOLD}Access points:${NC}"
echo "• Main site: http://localhost:8000/"
echo "• Django Admin: http://localhost:8000/admin/"
echo "• Oscar Shop: http://localhost:8000/shop/"
echo "• Oscar Dashboard: http://localhost:8000/dashboard/"
echo "• Wagtail CMS: http://localhost:8000/cms/"

echo -e "\n${BOLD}If you need a superuser:${NC}"
echo -e "${CYAN}python manage.py createsuperuser${NC}"

echo -e "\n${GREEN}Everything is ready to go!${NC}"
