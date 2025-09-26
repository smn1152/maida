from pathlib import Path

urls_path = Path('config/urls.py')

urls_content = '''from django.apps import apps
from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from django.views import defaults as default_views

# Get the Shop app config
Shop = apps.get_app_config('oscar')

urlpatterns = [
    # Django Admin
    path(settings.ADMIN_URL, admin.site.urls),
    
    # User management  
    path("users/", include("maida_vale.users.urls", namespace="users")),
    path("accounts/", include("allauth.urls")),
    
    # Oscar - using get_urls() method
    path('', Shop.get_urls()[0]),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

if settings.DEBUG:
    if "debug_toolbar" in settings.INSTALLED_APPS:
        import debug_toolbar
        urlpatterns = [path("__debug__/", include(debug_toolbar.urls))] + urlpatterns
'''

with open(urls_path, 'w') as f:
    f.write(urls_content)

print("✅ Using apps registry to get Oscar URLs")
