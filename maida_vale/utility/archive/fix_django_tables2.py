#!/usr/bin/env python
from pathlib import Path

base_settings_path = Path('config/settings/base.py')

# Read the file
with open(base_settings_path, 'r') as f:
    lines = f.readlines()

# Remove line 157 which has the duplicate django_tables2
# We'll look for the specific pattern near the Oscar dependencies comment
new_lines = []
skip_next_tables2 = False

for i, line in enumerate(lines):
    # Check if we're at the Oscar dependencies section
    if '# Oscar dependencies' in line and i < len(lines) - 1:
        new_lines.append(line)
        # Check if the next line is django_tables2
        if 'django_tables2' in lines[i + 1]:
            print(f"Removing duplicate django_tables2 at line {i + 2}")
            skip_next_tables2 = True
            continue
    elif skip_next_tables2 and 'django_tables2' in line:
        skip_next_tables2 = False
        continue  # Skip this line
    else:
        new_lines.append(line)

# Write back
with open(base_settings_path, 'w') as f:
    f.writelines(new_lines)

print("✅ Fixed duplicate django_tables2")
