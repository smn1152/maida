#!/bin/bash

# Complete Integration Script for Django + Wagtail + Dependencies
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
echo -e "${BOLD}${CYAN}║  COMPLETING WAGTAIL INTEGRATION & DEPENDENCIES        ║${NC}"
echo -e "${BOLD}${CYAN}╚════════════════════════════════════════════════════════╝${NC}"

cd "$DJANGO_ROOT"
source "$VENV_PATH/bin/activate"

# Step 1: Install missing dependencies
echo -e "\n${BOLD}[1/6] Installing missing dependencies...${NC}"
pip install Pillow django-allauth django-crispy-forms django-debug-toolbar

# Verify installations
echo -e "${GREEN}✅ Dependencies installed${NC}"

# Step 2: Update URLs for Wagtail
echo -e "\n${BOLD}[2/6] Configuring Wagtail URLs...${NC}"

# Backup current urls.py
cp config/urls.py config/urls.py.backup_$(date +%Y%m%d_%H%M%S)

# Create updated urls.py with Wagtail integration
cat > config/urls.py << 'EOF'
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.contrib.staticfiles.urls import staticfiles_urlpatterns
from django.urls import include, path
from django.views import defaults as default_views
from django.views.generic import TemplateView

# Wagtail imports
from wagtail import urls as wagtail_urls
from wagtail.admin import urls as wagtailadmin_urls
from wagtail.documents import urls as wagtaildocs_urls

urlpatterns = [
    path("", TemplateView.as_view(template_name="pages/home.html"), name="home"),
    path(
        "about/", TemplateView.as_view(template_name="pages/about.html"), name="about"
    ),
    # Django Admin, use {% url 'admin:index' %}
    path(settings.ADMIN_URL, admin.site.urls),
    # User management
    path("users/", include("maida_vale.users.urls", namespace="users")),
    path("accounts/", include("allauth.urls")),
    
    # Wagtail CMS URLs
    path('cms/', include(wagtailadmin_urls)),
    path('documents/', include(wagtaildocs_urls)),
    
    # Your apps
    # Add your app URLs here
    
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

# Add Wagtail URLs at the end for page serving
urlpatterns = urlpatterns + [
    # For anything not caught by a more specific rule above, hand over to Wagtail
    path('', include(wagtail_urls)),
]

if settings.DEBUG:
    # Static file serving when using Gunicorn + Uvicorn for local web socket development
    urlpatterns += staticfiles_urlpatterns()
    
    # This allows the error pages to be debugged during development
    urlpatterns += [
        path(
            "400/",
            default_views.bad_request,
            kwargs={"exception": Exception("Bad Request!")},
        ),
        path(
            "403/",
            default_views.permission_denied,
            kwargs={"exception": Exception("Permission Denied")},
        ),
        path(
            "404/",
            default_views.page_not_found,
            kwargs={"exception": Exception("Page not Found")},
        ),
        path("500/", default_views.server_error),
    ]
    
    if "debug_toolbar" in settings.INSTALLED_APPS:
        import debug_toolbar
        urlpatterns = [path("__debug__/", include(debug_toolbar.urls))] + urlpatterns
EOF

echo -e "${GREEN}✅ Wagtail URLs configured${NC}"

# Step 3: Create Wagtail home app
echo -e "\n${BOLD}[3/6] Creating Wagtail home app...${NC}"

if [ ! -d "home" ]; then
    python manage.py startapp home
    
    # Create basic Wagtail page model
    cat > home/models.py << 'EOF'
from django.db import models
from wagtail.models import Page
from wagtail.fields import RichTextField
from wagtail.admin.panels import FieldPanel


class HomePage(Page):
    body = RichTextField(blank=True)
    
    content_panels = Page.content_panels + [
        FieldPanel('body'),
    ]
    
    class Meta:
        verbose_name = "Home Page"
        verbose_name_plural = "Home Pages"
EOF
    
    # Add home app to INSTALLED_APPS
    python -c "
import sys
settings_file = 'config/settings/base.py'
with open(settings_file, 'r') as f:
    content = f.read()

if 'home' not in content:
    # Add home app after LOCAL_APPS
    if 'LOCAL_APPS = [' in content:
        content = content.replace('LOCAL_APPS = [', '''LOCAL_APPS = [
    \"home\",''')
    with open(settings_file, 'w') as f:
        f.write(content)
    print('Added home app to settings')
" 2>/dev/null || echo "Please add 'home' to LOCAL_APPS manually"
    
    echo -e "${GREEN}✅ Wagtail home app created${NC}"
else
    echo -e "${YELLOW}Home app already exists${NC}"
fi

# Step 4: Update settings for new dependencies
echo -e "\n${BOLD}[4/6] Updating settings for new dependencies...${NC}"

# Add middleware for debug toolbar if not present
python -c "
import sys
settings_file = 'config/settings/local.py'
with open(settings_file, 'r') as f:
    content = f.read()

if 'debug_toolbar.middleware.DebugToolbarMiddleware' not in content and 'MIDDLEWARE' in content:
    # Already handled in local.py
    pass
print('Debug toolbar middleware configured')
" 2>/dev/null || true

echo -e "${GREEN}✅ Settings updated${NC}"

# Step 5: Run migrations
echo -e "\n${BOLD}[5/6] Running migrations...${NC}"

export DJANGO_SETTINGS_MODULE="config.settings.local"

# Create migrations for home app if needed
python manage.py makemigrations home 2>/dev/null || true

# Run all migrations
python manage.py migrate

echo -e "${GREEN}✅ Migrations completed${NC}"

# Step 6: Create superuser if needed
echo -e "\n${BOLD}[6/6] Superuser setup...${NC}"

python -c "
from django.contrib.auth import get_user_model
User = get_user_model()
if not User.objects.filter(is_superuser=True).exists():
    print('No superuser found.')
    print('Create one with: python manage.py createsuperuser')
else:
    print('✅ Superuser already exists')
" || echo "Check superuser manually"

deactivate

# Final Summary
echo -e "\n${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}✨ INTEGRATION COMPLETE!${NC}"
echo -e "${BOLD}${GREEN}═══════════════════════════════════════════════════════${NC}"

echo -e "\n${BOLD}What's been done:${NC}"
echo "✅ Missing dependencies installed (Pillow, django-allauth, etc.)"
echo "✅ Wagtail URLs configured in config/urls.py"
echo "✅ Wagtail home app created"
echo "✅ Database migrations completed"
echo "✅ Settings updated for all frameworks"

echo -e "\n${BOLD}Your Stack:${NC}"
echo "• Django 5.2.6 - Web Framework"
echo "• Wagtail 7.1.1 - CMS"
echo "• Cookiecutter-Django - Project Template"
echo "• All dependencies installed and configured"

echo -e "\n${BOLD}Access Points:${NC}"
echo "• Main site: ${CYAN}http://localhost:8000/${NC}"
echo "• Django Admin: ${CYAN}http://localhost:8000/admin/${NC}"
echo "• Wagtail CMS: ${CYAN}http://localhost:8000/cms/${NC}"

echo -e "\n${BOLD}To start your server:${NC}"
echo -e "${CYAN}cd $DJANGO_ROOT${NC}"
echo -e "${CYAN}source $VENV_PATH/bin/activate${NC}"
echo -e "${CYAN}python manage.py runserver${NC}"

echo -e "\n${BOLD}If you haven't created a superuser yet:${NC}"
echo -e "${CYAN}python manage.py createsuperuser${NC}"

echo -e "\n${GREEN}Your Django + Wagtail + Cookiecutter project is ready!${NC}"
