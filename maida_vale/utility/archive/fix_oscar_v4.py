#!/usr/bin/env python
import os
import re
from pathlib import Path
from datetime import datetime

def fix_oscar_v4_configuration():
    """Fix Oscar 4.0 configuration in base.py"""
    
    base_settings_path = Path('/Users/saman/Maida/maida_vale/config/settings/base.py')
    
    # Create backup
    backup_path = base_settings_path.with_suffix(f'.backup_{datetime.now().strftime("%Y%m%d_%H%M%S")}')
    import shutil
    shutil.copy(base_settings_path, backup_path)
    print(f"✅ Created backup: {backup_path}")
    
    with open(base_settings_path, 'r') as f:
        content = f.read()
    
    # Remove the old import that doesn't work with Oscar 4.0
    content = content.replace('from oscar import get_core_apps', '')
    print("✅ Removed old get_core_apps import")
    
    # Fix THIRD_PARTY_APPS to include Oscar apps directly
    # Oscar 4.0 apps need to be listed explicitly
    oscar_apps = '''
    # Oscar core apps (must be before oscar)
    "oscar.config.Shop",
    "oscar.apps.analytics.apps.AnalyticsConfig",
    "oscar.apps.checkout.apps.CheckoutConfig",
    "oscar.apps.address.apps.AddressConfig",
    "oscar.apps.shipping.apps.ShippingConfig",
    "oscar.apps.catalogue.apps.CatalogueConfig",
    "oscar.apps.catalogue.reviews.apps.CatalogueReviewsConfig",
    "oscar.apps.communication.apps.CommunicationConfig",
    "oscar.apps.partner.apps.PartnerConfig",
    "oscar.apps.basket.apps.BasketConfig",
    "oscar.apps.payment.apps.PaymentConfig",
    "oscar.apps.offer.apps.OfferConfig",
    "oscar.apps.order.apps.OrderConfig",
    "oscar.apps.customer.apps.CustomerConfig",
    "oscar.apps.search.apps.SearchConfig",
    "oscar.apps.voucher.apps.VoucherConfig",
    "oscar.apps.wishlists.apps.WishlistsConfig",
    "oscar.apps.dashboard.apps.DashboardConfig",
    "oscar.apps.dashboard.reports.apps.ReportsDashboardConfig",
    "oscar.apps.dashboard.users.apps.UsersDashboardConfig",
    "oscar.apps.dashboard.orders.apps.OrdersDashboardConfig",
    "oscar.apps.dashboard.catalogue.apps.CatalogueDashboardConfig",
    "oscar.apps.dashboard.offers.apps.OffersDashboardConfig",
    "oscar.apps.dashboard.partners.apps.PartnersDashboardConfig",
    "oscar.apps.dashboard.pages.apps.PagesDashboardConfig",
    "oscar.apps.dashboard.ranges.apps.RangesDashboardConfig",
    "oscar.apps.dashboard.reviews.apps.ReviewsDashboardConfig",
    "oscar.apps.dashboard.vouchers.apps.VouchersDashboardConfig",
    "oscar.apps.dashboard.communications.apps.CommunicationsDashboardConfig",
    "oscar.apps.dashboard.shipping.apps.ShippingDashboardConfig",
    # Oscar dependencies
    "django_tables2",
'''
    
    # Find and update THIRD_PARTY_APPS
    if '] + get_core_apps()' in content:
        # Remove the get_core_apps() call
        content = content.replace('] + get_core_apps()  # Add all Oscar apps', ']')
        content = content.replace('] + get_core_apps()', ']')
    
    # Now add Oscar apps to THIRD_PARTY_APPS
    third_party_pattern = r'(THIRD_PARTY_APPS\s*=\s*\[)([\s\S]*?)(\])'
    
    def update_third_party_apps(match):
        start = match.group(1)
        apps = match.group(2)
        end = match.group(3)
        
        # Check if Oscar apps are already added
        if 'oscar.config.Shop' not in apps:
            # Remove any standalone 'oscar' entry
            apps_lines = apps.split('\n')
            filtered_lines = []
            for line in apps_lines:
                if "'oscar'" not in line and '"oscar"' not in line:
                    filtered_lines.append(line)
            
            apps = '\n'.join(filtered_lines)
            # Add Oscar apps
            apps = apps.rstrip().rstrip(',')
            if apps.strip():
                apps += ',\n'
            apps += oscar_apps
        
        return f'{start}{apps}{end}'
    
    content = re.sub(third_party_pattern, update_third_party_apps, content)
    print("✅ Added Oscar 4.0 apps to THIRD_PARTY_APPS")
    
    # Ensure we have the required middleware for Oscar
    if 'oscar.apps.basket.middleware.BasketMiddleware' not in content:
        middleware_addition = '''
    # Oscar middleware
    "oscar.apps.basket.middleware.BasketMiddleware",'''
        
        # Add after SessionMiddleware
        content = content.replace(
            '"django.contrib.sessions.middleware.SessionMiddleware",',
            '"django.contrib.sessions.middleware.SessionMiddleware",' + middleware_addition
        )
        print("✅ Added Oscar middleware")
    
    # Ensure SITE_ID is set
    if not re.search(r'SITE_ID\s*=\s*\d+', content):
        # Add before oscar.defaults import if it exists, otherwise at the end
        if 'from oscar.defaults import *' in content:
            content = content.replace('from oscar.defaults import *', 'SITE_ID = 1\n\nfrom oscar.defaults import *')
        else:
            content += '\nSITE_ID = 1\n'
        print("✅ Added SITE_ID setting")
    
    # Write back
    with open(base_settings_path, 'w') as f:
        f.write(content)
    
    print("\n✅ Oscar 4.0 configuration complete!")
    return True

if __name__ == "__main__":
    print("🔧 Fixing Oscar 4.0 configuration...")
    fix_oscar_v4_configuration()
    print("\n📝 Next steps:")
    print("1. Run: python manage.py check")
    print("2. Run: python manage.py migrate")
    print("3. Run: python manage.py collectstatic --noinput")
