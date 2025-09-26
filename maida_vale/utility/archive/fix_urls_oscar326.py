from pathlib import Path

urls_path = Path('config/urls.py')

# Django-Oscar 3.2.6 uses oscar.app.Shop
urls_content = '''from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from django.views import defaults as default_views

# Import Oscar's application for version 3.2.6
from oscar.app import Shop

application = Shop()

urlpatterns = [
    # Django Admin
    path(settings.ADMIN_URL, admin.site.urls),
    
    # User management  
    path("users/", include("maida_vale.users.urls", namespace="users")),
    path("accounts/", include("allauth.urls")),
    
    # Oscar e-commerce - include all Oscar URLs
    path("", application.urls),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

if settings.DEBUG:
    # Error pages for debugging
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

print("✅ Fixed URLs for Django-Oscar 3.2.6")
