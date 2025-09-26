# Development settings
from .base import *
import os

# Try to use environ, fall back to direct env vars if not available
try:
    import environ
    env = environ.Env()
    environ.Env.read_env(str(BASE_DIR / '.env'))
    SECRET_KEY = env('SECRET_KEY', default='django-insecure-development-key-change-in-production')
except ImportError:
    SECRET_KEY = os.environ.get('SECRET_KEY', 'django-insecure-development-key-change-in-production')

DEBUG = True
ALLOWED_HOSTS = ["localhost", "0.0.0.0", "127.0.0.1"]

# Database
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'db.sqlite3',
    }
}

# Email backend
EMAIL_BACKEND = "django.core.mail.backends.console.EmailBackend"

# Cache
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
        "LOCATION": "",
    }
}

# django-debug-toolbar
INSTALLED_APPS += ["debug_toolbar"]  # noqa: F405
MIDDLEWARE += ["debug_toolbar.middleware.DebugToolbarMiddleware"]  # noqa: F405

DEBUG_TOOLBAR_CONFIG = {
    "DISABLE_PANELS": [
        "debug_toolbar.panels.redirects.RedirectsPanel",
        "debug_toolbar.panels.profiling.ProfilingPanel",
    ],
    "SHOW_TEMPLATE_CONTEXT": True,
}

INTERNAL_IPS = ["127.0.0.1", "10.0.2.2"]

# Celery
CELERY_TASK_EAGER_PROPAGATES = True
CELERY_TASK_ALWAYS_EAGER = False
CELERY_BROKER_URL = os.environ.get("REDIS_URL", "redis://localhost:6379/0")
CELERY_RESULT_BACKEND = CELERY_BROKER_URL
