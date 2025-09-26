from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from django.apps import apps

# Import Wagtail URLs
from wagtail.admin import urls as wagtailadmin_urls
from wagtail import urls as wagtail_urls
from wagtail.documents import urls as wagtaildocs_urls

urlpatterns = [
    # Django Admin
    path("admin/", admin.site.urls),
    
    # Django i18n (for language switching)
    path('i18n/', include('django.conf.urls.i18n')),
    
    # API endpoints (ADD THIS LINE)
    path('api/v1/', include('maida_vale.api.v1.urls')),
    
    # Wagtail CMS
    path('cms/', include(wagtailadmin_urls)),
    path('documents/', include(wagtaildocs_urls)),
    
    # Django-allauth
    path("accounts/", include("allauth.urls")),
    
    # Oscar e-commerce - This MUST come before Wagtail's catch-all
    path('', include(apps.get_app_config('oscar').urls[0])),
    
    # Wagtail's page serving mechanism (should be last)
    path('', include(wagtail_urls)),
    
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

if settings.DEBUG:
    if "debug_toolbar" in settings.INSTALLED_APPS:
        import debug_toolbar
        urlpatterns = [path("__debug__/", include(debug_toolbar.urls))] + urlpatterns