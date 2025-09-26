from pathlib import Path

urls_path = Path('config/urls.py')

# Oscar 3.2.6 uses oscar.config.Shop which is already in INSTALLED_APPS
urls_content = '''from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from django.views import defaults as default_views

# For Oscar 3.2.6, we need to include the apps individually
from oscar.apps.catalogue import urls as catalogue_urls
from oscar.apps.customer import urls as customer_urls
from oscar.apps.basket import urls as basket_urls
from oscar.apps.checkout import urls as checkout_urls
from oscar.apps.dashboard import urls as dashboard_urls
from oscar.apps.offer import urls as offer_urls
from oscar.apps.search import urls as search_urls

urlpatterns = [
    # Django Admin
    path(settings.ADMIN_URL, admin.site.urls),
    
    # User management  
    path("users/", include("maida_vale.users.urls", namespace="users")),
    path("accounts/", include("allauth.urls")),
    
    # Oscar URLs
    path("catalogue/", include(catalogue_urls)),
    path("customer/", include(customer_urls)),
    path("basket/", include(basket_urls)),
    path("checkout/", include(checkout_urls)),
    path("dashboard/", include(dashboard_urls)),
    path("offers/", include(offer_urls)),
    path("search/", include(search_urls)),
    
    # Home page should show catalogue
    path("", include(catalogue_urls)),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

if settings.DEBUG:
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

print("✅ Fixed URLs for Oscar 3.2.6 with individual app includes")
