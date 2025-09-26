import os
import sys
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')
os.environ['DATABASE_URL'] = 'sqlite:///db.sqlite3'

django.setup()

from django.contrib.auth import get_user_model

User = get_user_model()

# Delete any existing admin users
User.objects.filter(username='admin').delete()

# Create new admin
admin = User.objects.create_superuser(
    username='admin',
    email='admin@localhost',
    password='admin123'  # Change this!
)

print("✓ Superuser created!")
print("  Username: admin")
print("  Password: admin123")
print("  URL: http://localhost:8000/admin/")
print("\n⚠ PLEASE CHANGE THE PASSWORD AFTER FIRST LOGIN!")
