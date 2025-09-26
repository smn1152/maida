#!/usr/bin/env python
"""
Comprehensive Project Validation Script
Validates Django + Wagtail + Cookiecutter-Django Integration
"""

import os
import sys
import json
import subprocess
from pathlib import Path
from datetime import datetime

# Setup environment
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings.local')
os.environ.setdefault('DJANGO_READ_DOT_ENV_FILE', 'True')
sys.path.insert(0, '/Users/saman/Maida/maida_vale')

class ProjectValidator:
    def __init__(self):
        self.project_root = Path('/Users/saman/Maida/maida_vale')
        self.venv_python = self.project_root / '.venv/bin/python'
        self.results = {
            'timestamp': datetime.now().isoformat(),
            'framework_checks': {},
            'structure_checks': {},
            'feature_checks': {},
            'issues': [],
            'warnings': [],
            'fixes_applied': []
        }
        
    def run_validation(self):
        print("\n" + "="*70)
        print("COMPREHENSIVE PROJECT VALIDATION")
        print("="*70)
        
        # Framework checks
        self.check_django_setup()
        self.check_wagtail_setup()
        self.check_cookiecutter_structure()
        self.check_oscar_setup()
        
        # Structure checks
        self.check_project_structure()
        self.check_app_structure()
        self.check_settings_structure()
        
        # Feature checks
        self.check_authentication()
        self.check_api_setup()
        self.check_celery_setup()
        self.check_static_media()
        self.check_templates()
        self.check_database()
        
        # Attempt fixes
        self.apply_automatic_fixes()
        
        # Generate report
        self.generate_report()
        
    def check_django_setup(self):
        """Check Django installation and configuration"""
        print("\n📦 Checking Django Setup...")
        
        try:
            import django
            django.setup()
            from django.conf import settings
            
            self.results['framework_checks']['django'] = {
                'installed': True,
                'version': django.get_version(),
                'debug': settings.DEBUG,
                'allowed_hosts': settings.ALLOWED_HOSTS,
                'installed_apps_count': len(settings.INSTALLED_APPS)
            }
            print(f"   ✓ Django {django.get_version()} installed")
            
            # Check for duplicates in INSTALLED_APPS
            apps = list(settings.INSTALLED_APPS)
            duplicates = set([x for x in apps if apps.count(x) > 1])
            if duplicates:
                self.results['issues'].append(f"Duplicate apps: {duplicates}")
                
        except Exception as e:
            self.results['framework_checks']['django'] = {'installed': False, 'error': str(e)}
            self.results['issues'].append(f"Django setup failed: {str(e)}")
            
    def check_wagtail_setup(self):
        """Check Wagtail CMS installation"""
        print("\n📦 Checking Wagtail Setup...")
        
        try:
            import wagtail
            from wagtail.models import Page
            
            self.results['framework_checks']['wagtail'] = {
                'installed': True,
                'version': wagtail.__version__,
                'pages_count': Page.objects.count() if Page.objects.exists() else 0
            }
            print(f"   ✓ Wagtail {wagtail.__version__} installed")
            
        except Exception as e:
            self.results['framework_checks']['wagtail'] = {'installed': False, 'error': str(e)}
            self.results['warnings'].append(f"Wagtail not fully configured: {str(e)}")
            
    def check_oscar_setup(self):
        """Check Oscar e-commerce installation"""
        print("\n📦 Checking Oscar Setup...")
        
        try:
            import oscar
            from django.apps import apps
            
            oscar_apps = [app for app in apps.get_app_configs() if 'oscar' in app.name]
            
            self.results['framework_checks']['oscar'] = {
                'installed': True,
                'version': oscar.__version__,
                'apps_count': len(oscar_apps)
            }
            print(f"   ✓ Oscar {oscar.__version__} installed with {len(oscar_apps)} apps")
            
        except Exception as e:
            self.results['framework_checks']['oscar'] = {'installed': False, 'error': str(e)}
            self.results['warnings'].append(f"Oscar not configured: {str(e)}")
            
    def check_cookiecutter_structure(self):
        """Check Cookiecutter-Django structure"""
        print("\n📦 Checking Cookiecutter-Django Structure...")
        
        cookiecutter_dirs = [
            'config/settings',
            'maida_vale/users',
            'maida_vale/static',
            'maida_vale/templates',
            'utility',
            'docs',
            'locale',
            'media',
            'staticfiles',
            'logs'
        ]
        
        cookiecutter_files = [
            'config/urls.py',
            'config/wsgi.py',
            'config/asgi.py',
            'manage.py',
            '.env',
            'pyproject.toml'
        ]
        
        structure_valid = True
        for dir_path in cookiecutter_dirs:
            full_path = self.project_root / dir_path
            if not full_path.exists():
                self.results['warnings'].append(f"Missing directory: {dir_path}")
                structure_valid = False
                
        for file_path in cookiecutter_files:
            full_path = self.project_root / file_path
            if not full_path.exists():
                self.results['issues'].append(f"Missing file: {file_path}")
                structure_valid = False
                
        self.results['framework_checks']['cookiecutter'] = {
            'structure_valid': structure_valid,
            'using_custom_user': (self.project_root / 'maida_vale/users/models.py').exists()
        }
        
        if structure_valid:
            print("   ✓ Cookiecutter structure intact")
        else:
            print("   ⚠ Some Cookiecutter components missing")
            
    def check_project_structure(self):
        """Validate overall project structure"""
        print("\n🏗️ Checking Project Structure...")
        
        self.results['structure_checks']['apps'] = []
        
        # Check custom apps
        custom_apps = ['users', 'nesosa', 'manufacturing', 'uk_compliance']
        for app in custom_apps:
            app_path = self.project_root / f'maida_vale/{app}'
            if app_path.exists():
                has_models = (app_path / 'models.py').exists()
                has_views = (app_path / 'views.py').exists()
                has_init = (app_path / '__init__.py').exists()
                
                self.results['structure_checks']['apps'].append({
                    'name': app,
                    'exists': True,
                    'has_models': has_models,
                    'has_views': has_views
                })
                
                if not all([has_models, has_views, has_init]):
                    self.results['warnings'].append(f"App {app} missing components")
            else:
                self.results['structure_checks']['apps'].append({
                    'name': app,
                    'exists': False
                })
                self.results['issues'].append(f"App {app} not found")
                
    def check_app_structure(self):
        """Check individual app structures"""
        print("\n🏗️ Checking App Structures...")
        
        # Ensure apps are properly registered
        try:
            from django.apps import apps
            registered_apps = [app.name for app in apps.get_app_configs()]
            
            required_apps = [
                'maida_vale.users',
                'maida_vale.nesosa',
                'maida_vale.manufacturing',
                'maida_vale.uk_compliance'
            ]
            
            for app in required_apps:
                if app not in registered_apps:
                    self.results['issues'].append(f"App {app} not registered in INSTALLED_APPS")
                    
        except Exception as e:
            self.results['issues'].append(f"Cannot check registered apps: {str(e)}")
            
    def check_settings_structure(self):
        """Check settings configuration"""
        print("\n⚙️ Checking Settings Structure...")
        
        settings_files = ['base.py', 'local.py', 'production.py', 'test.py']
        settings_path = self.project_root / 'config/settings'
        
        for file in settings_files:
            file_path = settings_path / file
            if file_path.exists():
                with open(file_path) as f:
                    content = f.read()
                    
                    # Check for critical imports
                    if file == 'base.py':
                        checks = {
                            'oscar_defaults': 'from oscar.defaults import *' in content,
                            'environ': 'import environ' in content,
                            'auth_user_model': 'AUTH_USER_MODEL' in content
                        }
                        
                        for check, result in checks.items():
                            if not result:
                                self.results['issues'].append(f"Missing in base.py: {check}")
                                
    def check_authentication(self):
        """Check authentication setup"""
        print("\n🔐 Checking Authentication...")
        
        try:
            from django.contrib.auth import get_user_model
            User = get_user_model()
            
            self.results['feature_checks']['authentication'] = {
                'custom_user_model': str(User),
                'superuser_exists': User.objects.filter(is_superuser=True).exists()
            }
            
            # Check allauth
            from django.conf import settings
            if 'allauth' in settings.INSTALLED_APPS:
                self.results['feature_checks']['authentication']['allauth'] = True
                print("   ✓ Django-allauth configured")
                
        except Exception as e:
            self.results['issues'].append(f"Authentication check failed: {str(e)}")
            
    def check_api_setup(self):
        """Check API configuration"""
        print("\n🔌 Checking API Setup...")
        
        try:
            from django.conf import settings
            
            api_configured = 'rest_framework' in settings.INSTALLED_APPS
            spectacular_configured = 'drf_spectacular' in settings.INSTALLED_APPS
            
            self.results['feature_checks']['api'] = {
                'rest_framework': api_configured,
                'drf_spectacular': spectacular_configured
            }
            
            if api_configured:
                print("   ✓ Django REST Framework configured")
                
        except Exception as e:
            self.results['warnings'].append(f"API check failed: {str(e)}")
            
    def check_celery_setup(self):
        """Check Celery configuration"""
        print("\n⚡ Checking Celery Setup...")
        
        celery_file = self.project_root / 'config/celery_app.py'
        
        self.results['feature_checks']['celery'] = {
            'config_exists': celery_file.exists(),
            'redis_configured': False
        }
        
        try:
            from django.conf import settings
            if hasattr(settings, 'CELERY_BROKER_URL'):
                self.results['feature_checks']['celery']['redis_configured'] = True
                print("   ✓ Celery configured with Redis")
        except:
            pass
            
    def check_static_media(self):
        """Check static and media configuration"""
        print("\n📁 Checking Static/Media Setup...")
        
        try:
            from django.conf import settings
            
            self.results['feature_checks']['static_media'] = {
                'static_url': settings.STATIC_URL,
                'static_root': str(settings.STATIC_ROOT),
                'media_url': settings.MEDIA_URL,
                'media_root': str(settings.MEDIA_ROOT),
                'staticfiles_dirs': len(settings.STATICFILES_DIRS) if hasattr(settings, 'STATICFILES_DIRS') else 0
            }
            
            # Check if directories exist
            if not Path(settings.STATIC_ROOT).exists():
                self.results['warnings'].append("STATIC_ROOT directory doesn't exist")
                
            if not Path(settings.MEDIA_ROOT).exists():
                self.results['warnings'].append("MEDIA_ROOT directory doesn't exist")
                
        except Exception as e:
            self.results['issues'].append(f"Static/Media check failed: {str(e)}")
            
    def check_templates(self):
        """Check template configuration"""
        print("\n📄 Checking Templates...")
        
        templates_dir = self.project_root / 'maida_vale/templates'
        
        self.results['feature_checks']['templates'] = {
            'directory_exists': templates_dir.exists(),
            'base_template': (templates_dir / 'base.html').exists() if templates_dir.exists() else False
        }
        
    def check_database(self):
        """Check database configuration"""
        print("\n💾 Checking Database...")
        
        try:
            from django.db import connection
            
            with connection.cursor() as cursor:
                cursor.execute("SELECT 1")
                
            self.results['feature_checks']['database'] = {
                'connected': True,
                'engine': connection.settings_dict['ENGINE']
            }
            print("   ✓ Database connection successful")
            
        except Exception as e:
            self.results['issues'].append(f"Database connection failed: {str(e)}")
            
    def apply_automatic_fixes(self):
        """Apply automatic fixes for common issues"""
        print("\n🔧 Applying Automatic Fixes...")
        
        # Fix missing directories
        required_dirs = ['logs', 'media', 'staticfiles', 'maida_vale/static', 'maida_vale/templates']
        for dir_name in required_dirs:
            dir_path = self.project_root / dir_name
            if not dir_path.exists():
                dir_path.mkdir(parents=True, exist_ok=True)
                self.results['fixes_applied'].append(f"Created directory: {dir_name}")
                
    def generate_report(self):
        """Generate comprehensive report"""
        print("\n" + "="*70)
        print("VALIDATION REPORT")
        print("="*70)
        
        # Framework Status
        print("\n📦 FRAMEWORK STATUS:")
        for framework, status in self.results['framework_checks'].items():
            if isinstance(status, dict) and status.get('installed'):
                print(f"   ✓ {framework.capitalize()}: {status.get('version', 'OK')}")
            else:
                print(f"   ✗ {framework.capitalize()}: Not configured")
                
        # Feature Status
        print("\n⚙️ FEATURE STATUS:")
        for feature, status in self.results['feature_checks'].items():
            if isinstance(status, dict):
                print(f"   • {feature.replace('_', ' ').title()}:")
                for key, value in status.items():
                    print(f"     - {key}: {value}")
                    
        # Issues
        if self.results['issues']:
            print("\n❌ CRITICAL ISSUES:")
            for issue in self.results['issues']:
                print(f"   • {issue}")
                
        # Warnings
        if self.results['warnings']:
            print("\n⚠️ WARNINGS:")
            for warning in self.results['warnings']:
                print(f"   • {warning}")
                
        # Fixes Applied
        if self.results['fixes_applied']:
            print("\n✅ FIXES APPLIED:")
            for fix in self.results['fixes_applied']:
                print(f"   • {fix}")
                
        # Save detailed report
        report_file = self.project_root / f'validation_report_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
        with open(report_file, 'w') as f:
            json.dump(self.results, f, indent=2, default=str)
        print(f"\n📊 Detailed report saved to: {report_file}")
        
        # Overall Status
        print("\n" + "="*70)
        if not self.results['issues']:
            print("✅ PROJECT VALIDATION SUCCESSFUL - All checks passed!")
        else:
            print("⚠️ PROJECT NEEDS ATTENTION - Please review issues above")
            
        print("="*70)

if __name__ == '__main__':
    validator = ProjectValidator()
    validator.run_validation()
