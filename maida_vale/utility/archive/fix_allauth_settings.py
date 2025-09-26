from pathlib import Path

base_settings_path = Path('config/settings/base.py')

with open(base_settings_path, 'r') as f:
    content = f.read()

# Replace deprecated settings with new format
old_settings = '''ACCOUNT_AUTHENTICATION_METHOD = "username"
ACCOUNT_USERNAME_REQUIRED = True
ACCOUNT_EMAIL_REQUIRED = True
ACCOUNT_SIGNUP_PASSWORD_ENTER_TWICE = True'''

new_settings = '''ACCOUNT_LOGIN_METHODS = {"username"}
ACCOUNT_SIGNUP_FIELDS = ['email*', 'username*', 'password1*', 'password2*']'''

content = content.replace(old_settings, new_settings)

with open(base_settings_path, 'w') as f:
    f.write(content)

print("✅ Updated allauth settings to new format")
