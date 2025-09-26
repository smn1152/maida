from pathlib import Path

base_settings_path = Path('config/settings/base.py')

with open(base_settings_path, 'r') as f:
    lines = f.readlines()

new_lines = []
found_basket_middleware = False
basket_middleware_line = '    "oscar.apps.basket.middleware.BasketMiddleware",\n'

for line in lines:
    # Skip the BasketMiddleware line where it currently is (too early)
    if 'oscar.apps.basket.middleware.BasketMiddleware' in line:
        found_basket_middleware = True
        continue  # Skip this line, we'll add it later
    
    # Add the line normally
    new_lines.append(line)
    
    # After AuthenticationMiddleware, add BasketMiddleware
    if 'django.contrib.auth.middleware.AuthenticationMiddleware' in line and found_basket_middleware:
        new_lines.append(basket_middleware_line)

with open(base_settings_path, 'w') as f:
    f.writelines(new_lines)

print("✅ Fixed middleware order - BasketMiddleware now comes AFTER AuthenticationMiddleware")
