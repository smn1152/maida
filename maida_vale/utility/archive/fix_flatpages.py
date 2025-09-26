#!/usr/bin/env python
from pathlib import Path

base_settings_path = Path('config/settings/base.py')

with open(base_settings_path, 'r') as f:
    content = f.read()

# Add flatpages to DJANGO_APPS
if 'django.contrib.flatpages' not in content:
    # Find DJANGO_APPS and add flatpages
    content = content.replace(
        '"django.contrib.admin",',
        '"django.contrib.admin",\n    "django.contrib.flatpages",'
    )
    print("✅ Added django.contrib.flatpages to DJANGO_APPS")

# Add flatpages middleware
if 'django.contrib.flatpages.middleware.FlatpageFallbackMiddleware' not in content:
    # Add at the end of MIDDLEWARE
    content = content.replace(
        '"wagtail.contrib.redirects.middleware.RedirectMiddleware",',
        '"wagtail.contrib.redirects.middleware.RedirectMiddleware",\n    "django.contrib.flatpages.middleware.FlatpageFallbackMiddleware",'
    )
    print("✅ Added FlatpageFallbackMiddleware")

with open(base_settings_path, 'w') as f:
    f.write(content)

print("✅ Flatpages configuration complete")
