#!/usr/bin/env python
from pathlib import Path
import re

base_settings_path = Path('config/settings/base.py')

with open(base_settings_path, 'r') as f:
    content = f.read()

# Count occurrences
occurrences = content.count('"django_tables2"')
print(f"Found {occurrences} occurrences of django_tables2")

if occurrences > 1:
    # Remove the django_tables2 that was added with Oscar apps
    # Keep the first occurrence, remove from the Oscar section
    lines = content.split('\n')
    found_first = False
    new_lines = []
    
    for line in lines:
        if 'django_tables2' in line:
            if not found_first:
                found_first = True
                new_lines.append(line)
                print(f"Keeping first occurrence: {line.strip()}")
            else:
                print(f"Removing duplicate: {line.strip()}")
                # Skip this line
                continue
        else:
            new_lines.append(line)
    
    content = '\n'.join(new_lines)
    
    with open(base_settings_path, 'w') as f:
        f.write(content)
    
    print("✅ Removed duplicate django_tables2")
else:
    print("No duplicates found")
