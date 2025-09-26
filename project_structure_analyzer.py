#!/usr/bin/env python
"""
Project Structure Analyzer
Evaluates Django project structure for efficiency, scalability, and best practices
"""

import os
import json
from pathlib import Path
from datetime import datetime
from collections import defaultdict

class ProjectStructureAnalyzer:
    def __init__(self, project_root="/Users/saman/Maida/maida_vale"):
        self.project_root = Path(project_root)
        self.issues = []
        self.strengths = []
        self.recommendations = []
        self.metrics = defaultdict(int)
        
    def analyze(self):
        print("\n" + "="*70)
        print("PROJECT STRUCTURE ANALYSIS")
        print("="*70)
        
        self.analyze_directory_structure()
        self.analyze_code_organization()
        self.analyze_cleanup_needs()
        self.analyze_scalability()
        self.analyze_best_practices()
        self.generate_report()
        
    def analyze_directory_structure(self):
        """Analyze overall directory structure"""
        print("\n📁 Analyzing Directory Structure...")
        
        # Check for standard Django/Cookiecutter directories
        standard_dirs = {
            'config': 'Configuration module',
            'maida_vale': 'Main application module',
            'docs': 'Documentation',
            'tests': 'Test suite',
            'locale': 'Internationalization',
            'utility': 'Utility scripts',
            'staticfiles': 'Collected static files',
            'media': 'User uploads',
            'logs': 'Application logs'
        }
        
        for dir_name, purpose in standard_dirs.items():
            dir_path = self.project_root / dir_name
            if dir_path.exists():
                self.strengths.append(f"✓ {dir_name}: {purpose}")
                self.metrics['standard_dirs'] += 1
            else:
                if dir_name in ['logs']:
                    self.recommendations.append(f"Create {dir_name} directory for {purpose.lower()}")
                    
    def analyze_code_organization(self):
        """Analyze code organization patterns"""
        print("\n🏗️ Analyzing Code Organization...")
        
        # Check app structure
        app_dir = self.project_root / 'maida_vale'
        apps = ['users', 'nesosa', 'manufacturing', 'uk_compliance']
        
        for app in apps:
            app_path = app_dir / app
            if app_path.exists():
                # Check for proper app structure
                expected_files = {
                    'models.py': 'Data models',
                    'views.py': 'View logic',
                    'admin.py': 'Admin interface',
                    'apps.py': 'App configuration',
                    'urls.py': 'URL routing',
                    'serializers.py': 'API serializers',
                    'forms.py': 'Form definitions',
                    'tests.py': 'Tests'
                }
                
                missing = []
                for file_name in expected_files:
                    if not (app_path / file_name).exists():
                        if file_name not in ['serializers.py', 'forms.py', 'tests.py', 'urls.py']:
                            missing.append(file_name)
                            
                if missing:
                    self.recommendations.append(f"{app}: Add {', '.join(missing)}")
                    
        # Check for API structure
        api_dir = app_dir / 'api'
        if not api_dir.exists():
            self.recommendations.append("Consider creating maida_vale/api/ for centralized API endpoints")
            
    def analyze_cleanup_needs(self):
        """Identify files that should be cleaned up"""
        print("\n🧹 Analyzing Cleanup Needs...")
        
        cleanup_patterns = {
            '*.pyc': 'Python bytecode files',
            '*.backup*': 'Backup files',
            '*.log': 'Log files in root',
            'fix_*.py': 'Temporary fix scripts',
            '*_repair*.sh': 'Repair scripts',
            '*_diagnostic*.sh': 'Diagnostic scripts'
        }
        
        files_to_clean = []
        for pattern, description in cleanup_patterns.items():
            for file_path in self.project_root.glob(pattern):
                if file_path.is_file():
                    files_to_clean.append(file_path.name)
                    
        if len(files_to_clean) > 10:
            self.issues.append(f"Found {len(files_to_clean)} temporary/backup files that should be cleaned")
            self.recommendations.append("Move diagnostic scripts to utility/diagnostics/")
            self.recommendations.append("Delete or archive old backup files")
            
        # Check __pycache__ directories
        pycache_dirs = list(self.project_root.rglob('__pycache__'))
        if len(pycache_dirs) > 5:
            self.recommendations.append(f"Clean {len(pycache_dirs)} __pycache__ directories")
            
    def analyze_scalability(self):
        """Analyze scalability aspects"""
        print("\n📈 Analyzing Scalability...")
        
        # Check for proper separation of concerns
        config_settings = self.project_root / 'config/settings'
        if config_settings.exists():
            settings_files = list(config_settings.glob('*.py'))
            if len(settings_files) >= 4:  # base, local, production, test
                self.strengths.append("✓ Environment-specific settings properly separated")
            else:
                self.issues.append("Missing environment-specific settings files")
                
        # Check for API versioning readiness
        if not (self.project_root / 'maida_vale/api/v1').exists():
            self.recommendations.append("Structure API with versioning (api/v1/) for future compatibility")
            
        # Check for modular app structure
        apps_with_submodules = 0
        for app in ['nesosa', 'manufacturing', 'uk_compliance']:
            app_path = self.project_root / f'maida_vale/{app}'
            if (app_path / 'models').exists() or (app_path / 'views').exists():
                apps_with_submodules += 1
                
        if apps_with_submodules > 0:
            self.strengths.append(f"✓ {apps_with_submodules} apps use modular structure")
            
    def analyze_best_practices(self):
        """Check Django best practices"""
        print("\n✅ Analyzing Best Practices...")
        
        # Check for requirements management
        if (self.project_root / 'pyproject.toml').exists():
            self.strengths.append("✓ Using pyproject.toml for dependency management")
        if (self.project_root / 'uv.lock').exists():
            self.strengths.append("✓ Using uv for fast dependency resolution")
            
        # Check for Docker support
        docker_files = list(self.project_root.glob('*docker*'))
        if docker_files:
            self.strengths.append("✓ Docker configuration present")
            
        # Check for CI/CD readiness
        if (self.project_root / '.github/workflows').exists():
            self.strengths.append("✓ GitHub Actions CI/CD configured")
        else:
            self.recommendations.append("Add CI/CD configuration (.github/workflows/)")
            
        # Check for documentation
        if (self.project_root / 'README.md').exists():
            self.strengths.append("✓ README documentation present")
            
    def generate_report(self):
        """Generate comprehensive report"""
        
        report = {
            'timestamp': datetime.now().isoformat(),
            'project_root': str(self.project_root),
            'metrics': dict(self.metrics),
            'strengths': self.strengths,
            'issues': self.issues,
            'recommendations': self.recommendations,
            'structure_score': self._calculate_score()
        }
        
        # Print summary
        print("\n" + "="*70)
        print("ANALYSIS SUMMARY")
        print("="*70)
        
        print("\n💪 STRENGTHS:")
        for strength in self.strengths[:5]:
            print(f"  {strength}")
            
        print("\n⚠️ ISSUES:")
        for issue in self.issues[:5]:
            print(f"  • {issue}")
            
        print("\n📋 TOP RECOMMENDATIONS:")
        
        # Prioritized recommendations
        priority_recommendations = [
            "1. CLEANUP: Archive old scripts to utility/archive/",
            "2. ORGANIZE: Create these directories:",
            "   - maida_vale/api/v1/ (API endpoints)",
            "   - maida_vale/common/ (shared utilities)",
            "   - tests/unit/ (unit tests)",
            "   - tests/integration/ (integration tests)",
            "3. MODULARIZE: Split large models.py files into models/ packages",
            "4. DOCUMENT: Add docstrings to all apps",
            "5. STANDARDIZE: Create app templates for consistency"
        ]
        
        for rec in priority_recommendations:
            print(f"  {rec}")
            
        # Structure score
        score = self._calculate_score()
        print(f"\n📊 STRUCTURE SCORE: {score}/100")
        
        if score >= 80:
            print("   Status: Excellent - Production ready")
        elif score >= 60:
            print("   Status: Good - Minor improvements needed")
        elif score >= 40:
            print("   Status: Fair - Significant improvements recommended")
        else:
            print("   Status: Needs work - Major restructuring recommended")
            
        # Save detailed report
        report_path = self.project_root / f'structure_analysis_{datetime.now().strftime("%Y%m%d_%H%M%S")}.json'
        with open(report_path, 'w') as f:
            json.dump(report, f, indent=2)
            
        print(f"\n📄 Detailed report saved to: {report_path}")
        
        # Create improvement script
        self._create_improvement_script()
        
    def _calculate_score(self):
        """Calculate structure score"""
        score = 50  # Base score
        
        # Add points for strengths
        score += len(self.strengths) * 3
        
        # Subtract for issues
        score -= len(self.issues) * 5
        
        # Cap at 0-100
        return max(0, min(100, score))
        
    def _create_improvement_script(self):
        """Create script to implement improvements"""
        
        script_path = self.project_root / 'improve_structure.sh'
        
        script_content = '''#!/bin/bash
# Auto-generated structure improvement script

echo "🚀 Implementing structure improvements..."

# Create recommended directories
mkdir -p maida_vale/api/v1
mkdir -p maida_vale/common
mkdir -p tests/unit
mkdir -p tests/integration
mkdir -p utility/archive
mkdir -p utility/diagnostics

# Move cleanup files
echo "📦 Archiving old scripts..."
mv -f fix_*.py utility/archive/ 2>/dev/null || true
mv -f *_diagnostic*.sh utility/diagnostics/ 2>/dev/null || true
mv -f *_repair*.sh utility/archive/ 2>/dev/null || true

# Clean pycache
echo "🧹 Cleaning cache..."
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true

# Create API structure
cat > maida_vale/api/v1/__init__.py << 'PY'
"""API v1 module"""
__version__ = '1.0.0'
PY

cat > maida_vale/api/v1/urls.py << 'PY'
from django.urls import path, include

app_name = 'api_v1'

urlpatterns = [
    # Add your API endpoints here
]
PY

echo "✅ Structure improvements complete!"
echo "📝 Next steps:"
echo "   1. Review and commit changes"
echo "   2. Update INSTALLED_APPS if needed"
echo "   3. Add API routing to main urls.py"
'''
        
        with open(script_path, 'w') as f:
            f.write(script_content)
            
        script_path.chmod(0o755)
        print(f"\n🔧 Improvement script created: {script_path}")
        print("   Run: ./improve_structure.sh")

if __name__ == '__main__':
    analyzer = ProjectStructureAnalyzer()
    analyzer.analyze()
