#!/usr/bin/env python
"""
Comprehensive Django Project Diagnostic Tool
Checks for all common issues in Django + Oscar + Wagtail projects
"""

import os
import sys
import json
import re
from pathlib import Path

# Add project to path
sys.path.insert(0, '/Users/saman/Maida/maida_vale')
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')
os.environ.setdefault('DJANGO_READ_DOT_ENV_FILE', 'True')

class ProjectDiagnostic:
    def __init__(self):
        self.project_root = Path('/Users/saman/Maida/maida_vale')
        self.issues = []
        self.warnings = []
        self.fixes = []
        
    def run_all_checks(self):
        print("\n" + "="*60)
        print("COMPREHENSIVE DJANGO PROJECT DIAGNOSTIC")
        print("="*60)
        
        self.check_environment()
        self.check_dependencies()
        self.check_settings()
        self.check_urls()
        self.check_models()
        self.check_migrations()
        self.check_templates()
        self.check_static_files()
        self.generate_fixes()
        self.print_report()
        
    def check_environment(self):
        print("\n🔍 Checking Environment...")
        
        # Check Python version
        import sys
        python_version = f"{sys.version_info.major}.{sys.version_info.minor}"
        print(f"   Python Version: {python_version}")
        
        # Check .env file
        env_file = self.project_root / '.env'
        if env_file.exists():
            with open(env_file) as f:
                env_content = f.read()
                required_vars = ['DJANGO_SECRET_KEY', 'DATABASE_URL']
                for var in required_vars:
                    if var not in env_content:
                        self.issues.append(f"Missing {var} in .env")
                    elif f"{var}=your-" in env_content or f"{var}='your-" in env_content:
                        self.issues.append(f"{var} has placeholder value in .env")
        else:
            self.issues.append(".env file missing")
            
    def check_dependencies(self):
        print("\n🔍 Checking Dependencies...")
        
        try:
            import django
            print(f"   Django: {django.get_version()}")
        except ImportError:
            self.issues.append("Django not installed")
            
        try:
            import oscar
            print(f"   Oscar: installed")
        except ImportError:
            self.issues.append("Django-Oscar not installed")
            
        try:
            import wagtail
            print(f"   Wagtail: installed")
        except ImportError:
            self.issues.append("Wagtail not installed")
            
        # Check for other required packages
        required_packages = [
            'corsheaders', 'drf_spectacular', 'argon2', 
            'whitenoise', 'fido2', 'django_celery_beat'
        ]
        
        for package in required_packages:
            try:
                __import__(package)
            except ImportError:
                self.issues.append(f"Missing package: {package}")
                
    def check_settings(self):
        print("\n🔍 Checking Settings...")
        
        try:
            from django.conf import settings
            
            # Check for Oscar defaults import
            base_settings = self.project_root / 'config/settings/base.py'
            if base_settings.exists():
                with open(base_settings) as f:
                    content = f.read()
                    if 'from oscar.defaults import *' in content:
                        print("   Oscar defaults imported: ✓")
                    else:
                        self.issues.append("Oscar defaults not imported in base.py")
                        
            # Check INSTALLED_APPS for duplicates
            installed_apps = list(settings.INSTALLED_APPS)
            duplicates = set([x for x in installed_apps if installed_apps.count(x) > 1])
            if duplicates:
                self.issues.append(f"Duplicate apps in INSTALLED_APPS: {duplicates}")
                
        except Exception as e:
            self.issues.append(f"Cannot load settings: {str(e)}")
            
    def check_urls(self):
        print("\n🔍 Checking URL Configuration...")
        
        urls_file = self.project_root / 'config/urls.py'
        if urls_file.exists():
            with open(urls_file) as f:
                content = f.read()
                
                # Check for Oscar URLs
                if "apps.get_app_config('oscar')" not in content:
                    self.issues.append("Oscar URLs not included in config/urls.py")
                    self.fixes.append({
                        'file': 'config/urls.py',
                        'issue': 'Missing Oscar URLs',
                        'fix': "Add: path('', include(apps.get_app_config('oscar').urls[0])),"
                    })
                    
                # Check for Wagtail URLs
                if 'wagtailadmin_urls' not in content:
                    self.issues.append("Wagtail admin URLs not included")
                    
                if 'wagtail_urls' not in content:
                    self.issues.append("Wagtail URLs not included")
                    
                # Check imports
                if 'from django.apps import apps' not in content:
                    self.issues.append("Missing 'from django.apps import apps' import")
                    
    def check_models(self):
        print("\n🔍 Checking Models...")
        
        # Check if custom user model exists
        user_model = self.project_root / 'maida_vale/users/models.py'
        if not user_model.exists():
            self.issues.append("Custom user model file missing")
            
    def check_migrations(self):
        print("\n🔍 Checking Migrations...")
        
        try:
            import django
            django.setup()
            from django.core.management import call_command
            from io import StringIO
            
            out = StringIO()
            call_command('showmigrations', '--plan', stdout=out, verbosity=0)
            migrations_output = out.getvalue()
            
            if '[ ]' in migrations_output:
                self.warnings.append("Unapplied migrations detected")
                
        except Exception as e:
            self.warnings.append(f"Cannot check migrations: {str(e)}")
            
    def check_templates(self):
        print("\n🔍 Checking Templates...")
        
        templates_dir = self.project_root / 'maida_vale/templates'
        if not templates_dir.exists():
            self.warnings.append("Templates directory missing")
            
    def check_static_files(self):
        print("\n🔍 Checking Static Files...")
        
        static_dir = self.project_root / 'maida_vale/static'
        if not static_dir.exists():
            self.warnings.append("Static directory missing")
            
    def generate_fixes(self):
        """Generate fix script for identified issues"""
        
        if 'Oscar URLs not included in config/urls.py' in str(self.issues):
            self.fixes.append({
                'description': 'Fix URL configuration',
                'script': '''
# Fix URLs
with open('config/urls.py', 'w') as f:
    f.write("""from django.conf import settings
from django.conf.urls.static import static
from django.contrib import admin
from django.urls import include, path
from django.apps import apps

# Import Wagtail URLs
from wagtail.admin import urls as wagtailadmin_urls
from wagtail import urls as wagtail_urls
from wagtail.documents import urls as wagtaildocs_urls

urlpatterns = [
    path("admin/", admin.site.urls),
    path('cms/', include(wagtailadmin_urls)),
    path('documents/', include(wagtaildocs_urls)),
    path("accounts/", include("allauth.urls")),
    path('', include(apps.get_app_config('oscar').urls[0])),
    path('', include(wagtail_urls)),
] + static(settings.MEDIA_URL, document_root=settings.MEDIA_ROOT)

if settings.DEBUG:
    if "debug_toolbar" in settings.INSTALLED_APPS:
        import debug_toolbar
        urlpatterns = [path("__debug__/", include(debug_toolbar.urls))] + urlpatterns
""")
'''
            })
            
    def print_report(self):
        print("\n" + "="*60)
        print("DIAGNOSTIC REPORT")
        print("="*60)
        
        if self.issues:
            print("\n❌ CRITICAL ISSUES:")
            for i, issue in enumerate(self.issues, 1):
                print(f"   {i}. {issue}")
        else:
            print("\n✅ No critical issues found!")
            
        if self.warnings:
            print("\n⚠️  WARNINGS:")
            for i, warning in enumerate(self.warnings, 1):
                print(f"   {i}. {warning}")
                
        if self.fixes:
            print("\n🔧 AVAILABLE FIXES:")
            for i, fix in enumerate(self.fixes, 1):
                print(f"   {i}. {fix.get('description', fix.get('issue'))}")
                
            # Generate fix script
            self.write_fix_script()
            
    def write_fix_script(self):
        """Write a script to fix all issues"""
        
        fix_script = self.project_root / 'auto_fix.py'
        with open(fix_script, 'w') as f:
            f.write("#!/usr/bin/env python\n")
            f.write("# Auto-generated fix script\n\n")
            f.write("import os\n")
            f.write("os.chdir('/Users/saman/Maida/maida_vale')\n\n")
            
            for fix in self.fixes:
                if 'script' in fix:
                    f.write(f"# Fix: {fix.get('description', '')}\n")
                    f.write(fix['script'])
                    f.write("\n\n")
                    
            f.write("print('\\n✅ All fixes applied!')\n")
            
        print(f"\n💡 Fix script created: auto_fix.py")
        print("   Run: python auto_fix.py")

if __name__ == '__main__':
    diagnostic = ProjectDiagnostic()
    diagnostic.run_all_checks()
