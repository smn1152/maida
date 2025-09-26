#!/usr/bin/env python
import os
import re
from pathlib import Path
from datetime import datetime

def fix_oscar_configuration():
    """Fix Oscar configuration in base.py"""
    
    base_settings_path = Path('/Users/saman/Maida/maida_vale/config/settings/base.py')
    
    # Create backup
    backup_path = base_settings_path.with_suffix(f'.backup_{datetime.now().strftime("%Y%m%d_%H%M%S")}')
    import shutil
    shutil.copy(base_settings_path, backup_path)
    print(f"✅ Created backup: {backup_path}")
    
    with open(base_settings_path, 'r') as f:
        content = f.read()
    
    # First, add the import for get_core_apps at the top
    if 'from oscar import get_core_apps' not in content:
        # Find the imports section and add Oscar import
        import_lines = content.split('\n')
        for i, line in enumerate(import_lines):
            if line.startswith('import environ'):
                import_lines.insert(i + 1, 'from oscar import get_core_apps')
                break
        content = '\n'.join(import_lines)
        print("✅ Added 'from oscar import get_core_apps' import")
    
    # Now fix the INSTALLED_APPS section
    # Find where THIRD_PARTY_APPS is defined
    third_party_pattern = r'(THIRD_PARTY_APPS\s*=\s*\[)([\s\S]*?)(\])'
    
    def replace_third_party_apps(match):
        start = match.group(1)
        apps = match.group(2)
        end = match.group(3)
        
        # Remove any standalone 'oscar' entry
        apps_lines = apps.split('\n')
        filtered_lines = []
        for line in apps_lines:
            if "'oscar'" not in line and '"oscar"' not in line:
                filtered_lines.append(line)
        
        # Reconstruct and add get_core_apps()
        new_apps = '\n'.join(filtered_lines)
        
        # Add get_core_apps() at the end if not present
        if 'get_core_apps()' not in new_apps:
            # Remove trailing whitespace and comma if present
            new_apps = new_apps.rstrip().rstrip(',')
            # Add get_core_apps
            return f'{start}{new_apps}\n] + get_core_apps()  # Add all Oscar apps'
        else:
            return match.group(0)
    
    # Apply the fix
    if 'get_core_apps()' not in content:
        content = re.sub(third_party_pattern, replace_third_party_apps, content)
        print("✅ Added get_core_apps() to THIRD_PARTY_APPS")
    
    # Ensure INSTALLED_APPS combines all app lists
    if 'INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS' not in content:
        # This should already be there, but let's make sure
        installed_pattern = r'INSTALLED_APPS\s*=\s*[^\n]+'
        if re.search(installed_pattern, content):
            content = re.sub(installed_pattern, 'INSTALLED_APPS = DJANGO_APPS + THIRD_PARTY_APPS + LOCAL_APPS', content)
            print("✅ Fixed INSTALLED_APPS definition")
    
    # Make sure oscar.defaults import is present
    if 'from oscar.defaults import *' not in content:
        # Add it at the end of the file
        content += '\n# Import Oscar default settings\nfrom oscar.defaults import *\n'
        print("✅ Added Oscar defaults import")
    
    # Add essential Oscar settings if not present
    if 'OSCAR_SHOP_NAME' not in content:
        oscar_settings = '''
# Oscar-specific settings
OSCAR_SHOP_NAME = "Maida Vale"
OSCAR_SHOP_TAGLINE = "Manufacturing Excellence"
OSCAR_ALLOW_ANON_CHECKOUT = True

# Oscar Dashboard
OSCAR_DASHBOARD_NAVIGATION += [
    {
        'label': 'Manufacturing',
        'icon': 'fas fa-industry',
        'url_name': 'dashboard:index',
    },
]
'''
        content += oscar_settings
        print("✅ Added Oscar-specific settings")
    
    # Ensure SITE_ID is set (required for Oscar)
    if not re.search(r'SITE_ID\s*=\s*\d+', content):
        # Add before oscar.defaults import
        content = content.replace('from oscar.defaults import *', 'SITE_ID = 1\n\nfrom oscar.defaults import *')
        print("✅ Added SITE_ID setting")
    
    # Write the updated content back
    with open(base_settings_path, 'w') as f:
        f.write(content)
    
    print("\n✅ Configuration updated successfully!")
    return True

if __name__ == "__main__":
    print("🔧 Fixing Oscar configuration...")
    fix_oscar_configuration()
    print("\n📝 Next steps:")
    print("1. Run: python manage.py check")
    print("2. Run: python manage.py makemigrations")
    print("3. Run: python manage.py migrate")
    print("4. Run: python manage.py oscar_populate_countries --initial-only")
