"""
Fixed migration for sites app - SQLite compatible
"""
from django.db import migrations

def update_site_forward(apps, schema_editor):
    """Update Site name and domain for SQLite"""
    Site = apps.get_model("sites", "Site")
    
    # Use a simple approach that works with SQLite
    site, created = Site.objects.get_or_create(
        id=1,
        defaults={
            'domain': 'localhost:8000',
            'name': 'Salbion Local Development'
        }
    )
    
    if not created:
        site.domain = 'localhost:8000'
        site.name = 'Salbion Local Development'
        site.save()

def update_site_backward(apps, schema_editor):
    """Revert site settings"""
    Site = apps.get_model("sites", "Site")
    site = Site.objects.get(id=1)
    site.domain = 'example.com'
    site.name = 'example.com'
    site.save()

class Migration(migrations.Migration):
    dependencies = [
        ("sites", "0002_alter_domain_unique"),
    ]

    operations = [
        migrations.RunPython(update_site_forward, update_site_backward),
    ]
