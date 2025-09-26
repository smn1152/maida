from pathlib import Path

base_settings_path = Path('config/settings/base.py')

with open(base_settings_path, 'r') as f:
    content = f.read()

# Update LOCAL_APPS to include all your apps
local_apps_replacement = '''LOCAL_APPS = [
    "maida_vale.users",
    "maida_vale.nesosa",
    "maida_vale.manufacturing",
    "maida_vale.uk_compliance",
]'''

import re
content = re.sub(
    r'LOCAL_APPS\s*=\s*\[.*?\]',
    local_apps_replacement,
    content,
    flags=re.DOTALL
)

with open(base_settings_path, 'w') as f:
    f.write(content)

print("✅ Updated LOCAL_APPS")
