#!/usr/bin/env bash
set -euo pipefail

# ────────────────────────────────────────────────────────────────────────────────
# SALBION / NESOSA – Full Stack Doctor for Django + Wagtail + Cookiecutter-Django
# Safe audit: no changes unless --fix is provided.
# Output: maida_vale/logs/stack_doctor_REPORT_<timestamp>.md
# Usage:  bash stack_doctor.sh [--project maida_vale] [--python 3.11] [--fix]
# ────────────────────────────────────────────────────────────────────────────────

PROJECT_NAME="maida_vale"
PY_REQ="3.11"
DO_FIX=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --project) PROJECT_NAME="$2"; shift 2 ;;
    --python)  PY_REQ="$2"; shift 2 ;;
    --fix)     DO_FIX=1; shift ;;
    *) echo "Unknown arg: $1"; exit 2 ;;
  esac
done

ROOT_DIR="$(pwd)"
PROJ_DIR="${ROOT_DIR}/${PROJECT_NAME}"
LOG_DIR="${PROJ_DIR}/logs"
mkdir -p "$LOG_DIR"

ts() { date +"%Y-%m-%d %H:%M:%S"; }
STAMP="$(date +"%Y%m%d_%H%M%S")"
REPORT="${LOG_DIR}/stack_doctor_REPORT_${STAMP}.md"
TMPPY="$(mktemp -t stack_doctor_py_XXXXXX.py)"

cecho(){ printf "%b\n" "$1"; }

# Pretty marks
OK="✅"
WARN="⚠️"
ERR="❌"
INFO="ℹ️"

# Detect virtualenv
detect_venv() {
  if [[ -d "${ROOT_DIR}/.venv" ]]; then
    VENV="${ROOT_DIR}/.venv"
  elif [[ -d "${ROOT_DIR}/venv" ]]; then
    VENV="${ROOT_DIR}/venv"
  else
    VENV=""
  fi
}

activate_venv() {
  detect_venv
  if [[ -n "${VENV}" && -f "${VENV}/bin/activate" ]]; then
    # shellcheck disable=SC1090
    source "${VENV}/bin/activate"
    PYBIN="$(command -v python)"
  else
    PYBIN="$(command -v python)"
  fi
}

must() {
  if ! "$@"; then
    cecho "${ERR} Command failed: $*"
    exit 1
  fi
}

mkpy() {
  cat > "${TMPPY}" <<'PY'
import json, os, sys, importlib, pathlib, traceback
from datetime import datetime

def safe_import(m):
    try:
        mod = importlib.import_module(m)
        return {"ok": True, "version": getattr(mod, "__version__", getattr(mod, "get_version", lambda: None)())}
    except Exception as e:
        return {"ok": False, "error": repr(e)}

def dj_info():
    out = {"django": None, "wagtail": None, "settings_module": None, "checks": {}, "cookiecutter_django": {}}
    try:
        import django
        out["django"] = {"ok": True, "version": django.get_version()}
        import os
        # Try to infer settings via manage.py location
        # We will attempt to set DJANGO_SETTINGS_MODULE if not present
        if "DJANGO_SETTINGS_MODULE" not in os.environ:
            # Best effort defaults
            for candidate in ["config.settings.local", "config.settings.base", "config.settings.dev"]:
                os.environ["DJANGO_SETTINGS_MODULE"] = candidate
                try:
                    import django
                    django.setup()
                    out["settings_module"] = candidate
                    break
                except Exception:
                    pass
        if "settings_module" not in out or out["settings_module"] is None:
            # Try again if already set by environment
            if "DJANGO_SETTINGS_MODULE" in os.environ:
                try:
                    django.setup()
                    out["settings_module"] = os.environ["DJANGO_SETTINGS_MODULE"]
                except Exception as e:
                    out["settings_error"] = repr(e)

        from django.conf import settings
        out["settings"] = {
            "DEBUG": getattr(settings, "DEBUG", None),
            "DATABASES": {k: v.get("ENGINE","") for k,v in getattr(settings, "DATABASES", {}).items()},
            "STATIC_URL": getattr(settings, "STATIC_URL", None),
            "STATIC_ROOT": getattr(settings, "STATIC_ROOT", None),
            "MEDIA_URL": getattr(settings, "MEDIA_URL", None),
            "MEDIA_ROOT": getattr(settings, "MEDIA_ROOT", None),
            "ALLOWED_HOSTS": getattr(settings, "ALLOWED_HOSTS", None),
            "INSTALLED_APPS_sample": [a for a in getattr(settings,"INSTALLED_APPS", []) if any(x in a for x in ["wagtail","django.contrib","oscar","rest_framework"])][:30],
            "MIDDLEWARE_count": len(getattr(settings, "MIDDLEWARE", [])),
        }
        # Wagtail core presence (6.x: "wagtail")
        try:
            import wagtail
            out["wagtail"] = {"ok": True, "version": getattr(wagtail, "VERSION", getattr(wagtail, "__version__", None))}
        except Exception as e:
            out["wagtail"] = {"ok": False, "error": repr(e)}

        # Cookiecutter-Django conventions
        proj_root = pathlib.Path(__file__).resolve().parent.parent
        cc = {
            "has_config_settings": (proj_root / "config" / "settings").is_dir(),
            "has_base": (proj_root / "config" / "settings" / "base.py").is_file(),
            "has_local": any((proj_root / "config" / "settings" / x).is_file() for x in ["local.py","development.py","dev.py"]),
            "has_production": any((proj_root / "config" / "settings" / x).is_file() for x in ["production.py","prod.py"]),
            "has_env_example": any((proj_root / x).is_file() for x in [".env",".env.example",".env.local"]),
            "has_celery": (proj_root / "config" / "celery_app.py").is_file() or (proj_root / "config" / "celery.py").is_file(),
            "has_docker_compose": any((proj_root / x).is_file() for x in ["docker-compose.yml","compose.yaml","local.yml"]),
        }
        out["cookiecutter_django"] = cc

        # Quick static dirs and templates check
        static_dirs = getattr(settings, "STATICFILES_DIRS", [])
        templates_dirs = []
        for t in getattr(settings, "TEMPLATES", []):
            for d in t.get("DIRS", []):
                templates_dirs.append(d)
        out["paths"] = {"STATICFILES_DIRS": static_dirs, "TEMPLATE_DIRS": templates_dirs}
    except Exception as e:
        out["error"] = repr(e)
        out["traceback"] = traceback.format_exc()
    return out

def main():
    out = {"timestamp": datetime.utcnow().isoformat()+"Z"}
    out["python"] = {"version": sys.version}
    out["imports"] = {
        "django": safe_import("django"),
        "wagtail": safe_import("wagtail"),
        "cookiecutter": safe_import("cookiecutter"),
        "uv": safe_import("uv"),
    }
    out["django_info"] = dj_info()
    print(json.dumps(out, indent=2, default=str))

if __name__ == "__main__":
    main()
PY
}

# Ensure we’re in the monorepo root and project exists
if [[ ! -d "${PROJ_DIR}" || ! -f "${PROJ_DIR}/manage.py" ]]; then
  cecho "${ERR} Could not find project at ${PROJ_DIR} (manage.py missing)."
  exit 1
fi

activate_venv

# Version checks (Python)
SYS_PY_VER="$(${PYBIN} -c 'import sys;print(".".join(map(str,sys.version_info[:3])))')"
if ! "${PYBIN}" -c "import sys; exit(0) if sys.version_info[:2] >= tuple(map(int,'${PY_REQ}'.split('.'))) else exit(1)"; then
  PYNOTE="${WARN} Python ${SYS_PY_VER} detected. Recommended >= ${PY_REQ}. Using: ${PYBIN}"
else
  PYNOTE="${OK} Python ${SYS_PY_VER} (${PYBIN})"
fi

# Core package presence
has_pkg(){ "${PYBIN}" - <<'PY' 2>/dev/null | grep -q '^OK$' ; }
import importlib, sys
m=sys.argv[1] if len(sys.argv)>1 else None
try:
    importlib.import_module(m); print("OK")
except Exception: print("NO")
PY
}

DJOK=""; WGOK=""
if has_pkg django; then DJOK="${OK} django installed"; else DJOK="${ERR} django NOT installed"; fi
if has_pkg wagtail; then WGOK="${OK} wagtail installed"; else WGOK="${WARN} wagtail NOT installed"; fi

# Optionally fix missing essentials
if [[ "${DO_FIX}" -eq 1 ]]; then
  cecho "${INFO} --fix provided: installing missing core packages if needed…"
  if ! has_pkg django; then must "${PYBIN}" -m pip install "Django>=5.0,<5.2"; fi
  if ! has_pkg wagtail; then must "${PYBIN}" -m pip install "wagtail>=6.2,<6.4"; fi
fi

# Run the embedded Python probe from inside the project dir
pushd "${PROJ_DIR}" >/dev/null
mkpy
PYJSON="$(${PYBIN} "${TMPPY}" 2>&1 || true)"
popd >/dev/null

# Commands that require manage.py (safe)
pushd "${PROJ_DIR}" >/dev/null
M_CHECK="$(${PYBIN} manage.py check 2>&1 || true)"
M_CHECK_DEPLOY="$(${PYBIN} manage.py check --deploy 2>&1 || true)"
M_MAKEMIG="$(${PYBIN} manage.py makemigrations --check --dry-run 2>&1 || true)"
M_SHOWMIG="$(${PYBIN} manage.py showmigrations --plan 2>&1 || true)"
# collectstatic dry-run is supported; will not write if STATIC_ROOT missing
M_STATIC="$(${PYBIN} manage.py collectstatic --noinput --dry-run 2>&1 || true)"
popd >/dev/null

# Simple structure checks
STRUCT=()
[[ -d "${PROJ_DIR}/maida_vale" ]] && STRUCT+=("${OK} app package: maida_vale/")
[[ -d "${PROJ_DIR}/templates" || -d "${PROJ_DIR}/maida_vale/templates" ]] && STRUCT+=("${OK} templates dir present")
[[ -d "${PROJ_DIR}/static" || -d "${PROJ_DIR}/maida_vale/static" || -d "${PROJ_DIR}/staticfiles" ]] && STRUCT+=("${OK} static dir present")
[[ -f "${PROJ_DIR}/config/settings/base.py" ]] && STRUCT+=("${OK} config/settings/base.py")
[[ -f "${PROJ_DIR}/config/settings/local.py" || -f "${PROJ_DIR}/config/settings/development.py" ]] && STRUCT+=("${OK} local/dev settings present")
[[ -f "${PROJ_DIR}/config/settings/production.py" ]] && STRUCT+=("${OK} production settings present")
[[ -f "${PROJ_DIR}/config/celery_app.py" || -f "${PROJ_DIR}/config/celery.py" ]] && STRUCT+=("${OK} Celery config present")
[[ -f "${PROJ_DIR}/pyproject.toml" || -f "${PROJ_DIR}/requirements-dev.txt" ]] && STRUCT+=("${OK} dependency manifest present")

# Parse JSON from probe
get_jq_val() {
  python - "$@" <<'PY'
import json,sys
data=json.loads(sys.stdin.read())
path=sys.argv[1].split(".")
cur=data
for p in path:
    cur=cur.get(p, {})
print(cur if isinstance(cur, str) else json.dumps(cur))
PY
}

DJ_VERSION="$(printf "%s" "$PYJSON" | get_jq_val "imports.django.version" 2>/dev/null || echo "")"
WG_VERSION="$(printf "%s" "$PYJSON" | get_jq_val "django_info.wagtail.version" 2>/dev/null || echo "")"
SETTINGS_MOD="$(printf "%s" "$PYJSON" | get_jq_val "django_info.settings_module" 2>/dev/null || echo "")"
DB_ENGINES="$(printf "%s" "$PYJSON" | get_jq_val "django_info.settings.DATABASES" 2>/dev/null || echo "")"
STATIC_URL="$(printf "%s" "$PYJSON" | get_jq_val "django_info.settings.STATIC_URL" 2>/dev/null || echo "")"
STATIC_ROOT="$(printf "%s" "$PYJSON" | get_jq_val "django_info.settings.STATIC_ROOT" 2>/dev/null || echo "")"
ALLOWED_HOSTS="$(printf "%s" "$PYJSON" | get_jq_val "django_info.settings.ALLOWED_HOSTS" 2>/dev/null || echo "")"
APPS_SAMPLE="$(printf "%s" "$PYJSON" | get_jq_val "django_info.settings.INSTALLED_APPS_sample" 2>/dev/null || echo "[]")"
CC_INFO="$(printf "%s" "$PYJSON" | get_jq_val "django_info.cookiecutter_django" 2>/dev/null || echo "{}")"

# Build report
{
  echo "# Stack Doctor Report – ${PROJECT_NAME}"
  echo "_Generated: $(ts)_"
  echo
  echo "## Summary"
  echo "- ${PYNOTE}"
  echo "- ${DJOK}${DJ_VERSION:+ (version: ${DJ_VERSION})}"
  echo "- ${WGOK}${WG_VERSION:+ (version: ${WG_VERSION})}"
  echo
  echo "## Project Paths"
  echo "- Root: \`${ROOT_DIR}\`"
  echo "- Project: \`${PROJ_DIR}\`"
  echo "- Virtualenv: \`${VENV:-system}\`"
  echo
  echo "## Structure Checks"
  for s in "${STRUCT[@]:-}"; do echo "- ${s}"; done
  echo
  echo "## Django Settings Snapshot"
  echo "- Settings module (best guess): \`${SETTINGS_MOD:-unknown}\`"
  echo "- DB Engines: \`${DB_ENGINES}\`"
  echo "- STATIC_URL: \`${STATIC_URL}\`"
  echo "- STATIC_ROOT: \`${STATIC_ROOT}\`"
  echo "- ALLOWED_HOSTS: \`${ALLOWED_HOSTS}\`"
  echo
  echo "### Installed Apps (sample)"
  echo "\`\`\`"
  echo "${APPS_SAMPLE}"
  echo "\`\`\`"
  echo
  echo "## Cookiecutter-Django Conventions"
  echo "\`\`\`json"
  echo "${CC_INFO}"
  echo "\`\`\`"
  echo
  echo "## Django System Checks"
  echo "### manage.py check"
  echo "\`\`\`"
  echo "${M_CHECK}"
  echo "\`\`\`"
  echo
  echo "### manage.py check --deploy"
  echo "\`\`\`"
  echo "${M_CHECK_DEPLOY}"
  echo "\`\`\`"
  echo
  echo "## Migrations"
  echo "### makemigrations --check --dry-run"
  echo "\`\`\`"
  echo "${M_MAKEMIG}"
  echo "\`\`\`"
  echo
  echo "### showmigrations --plan"
  echo "\`\`\`"
  echo "${M_SHOWMIG}"
  echo "\`\`\`"
  echo
  echo "## Static Files (dry-run collectstatic)"
  echo "\`\`\`"
  echo "${M_STATIC}"
  echo "\`\`\`"
  echo
  echo "## Recommendations"
  echo "- If any **unapplied migrations** appear above, run: \`python manage.py migrate\`"
  echo "- If **collectstatic** shows errors, set \`STATIC_ROOT\` in your settings and rerun."
  echo "- For production, ensure \`ALLOWED_HOSTS\` is set and pass \`--deploy\` checks."
  echo "- Verify Wagtail core apps present: \`wagtail, wagtail.admin, wagtail.images, wagtail.documents, wagtail.users, wagtail.snippets\`."
  echo "- Cookiecutter-Django structure: keep \`config/settings/base.py\`, plus \`local.py\` and \`production.py\`."
} > "${REPORT}"

rm -f "${TMPPY}"

cecho ""
cecho "${OK} Audit complete."
cecho "${INFO} Report saved at: ${REPORT}"
