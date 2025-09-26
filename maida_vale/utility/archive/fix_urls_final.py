from pathlib import Path

urls_path = Path('config/urls.py')

urls_content = '''from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from django.views import defaults as default_views

# Import Oscar application
from oscar import app as oscar_app

urlpatterns = [
    # Django Admin
    path(settings.ADMIN_URL, admin.site.urls),
    
    # User management
    path("users/", include("maida_vale.users.urls", namespace="users")),
    path("accounts/", include("allauth.urls")),
    
    # Oscar e-commerce URLs
    path("", include(oscar_app.urls)),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

if settings.DEBUG:
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
'''

with open(urls_path, 'w') as f:
    f.write(urls_content)

print("✅ Fixed URL configuration with correct Oscar 4.0 import")
