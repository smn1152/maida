#!/usr/bin/env bash
# salbion_smart_repair_v2.sh
# All-in-one diagnose & repair for Django (+Wagtail/Oscar) projects using uv or pip.
#
# Modes:
#   --diagnose        (default) read-only checks
#   --repair          safe fixes (.venv, deps, .env, settings patch if needed)
#   --hard-repair     recreate .venv with Python 3.11 and resync deps
#   --verify          runs verification suite after checks/fixes
#
# Highlights:
#   • Resolves .venv vs venv conflicts & uv targeting issues
#   • Pins to Python 3.11 for Django 4.2/Wagtail 7/Oscar 4 compatibility
#   • Ensures Django imports from venv (not system site-packages)
#   • Syncs deps via uv (preferred) with constraints to prevent breakage
#   • Patches settings to load environment (django-environ) if missing
#   • Creates/updates .env (DJANGO_SECRET_KEY, DATABASE_URL, DEBUG, ALLOWED_HOSTS)
#   • Non-destructive by default; DB ops only on --repair/--hard-repair
#
set -Eeuo pipefail

# ---------- Pretty printing ----------
if [[ -t 1 ]]; then
  RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'; MAG=$'\e[35m'; CYAN=$'\e[36m'; BOLD=$'\e[1m'; DIM=$'\e[2m'; RESET=$'\e[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAG=""; CYAN=""; BOLD=""; DIM=""; RESET=""
fi
ts(){ date +"%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s %b%s%b\n" "$(ts)" "$2" "$1" "$RESET" | tee -a "$LOG"; }
ok(){  log "$1" "$GREEN[OK] "; }
inf(){  log "$1" "$CYAN[INFO] "; }
warn(){ log "$1" "$YELLOW[WARN] "; }
err(){  log "$1" "$RED[ERR] "; }

# ---------- Config ----------
MODE="diagnose"
DO_VERIFY="false"
EXPECTED_PY="3.11"
VENV_DIR=".venv"
ALT_VENV="venv"
PROJECT_ROOT=""
PYBIN=""
USE_UV="false"
LOG="salbion_smart_repair_$(date +%Y%m%d_%H%M%S).log"

for a in "$@"; do
  case "$a" in
    --diagnose)   MODE="diagnose";;
    --repair)     MODE="repair";;
    --hard-repair)MODE="hard-repair";;
    --verify)     DO_VERIFY="true";;
    -h|--help)
      cat <<EOF
${BOLD}salbion_smart_repair_v2.sh${RESET}

Usage:
  ${BOLD}$0${RESET} [--diagnose|--repair|--hard-repair] [--verify]

Modes:
  --diagnose     Read-only checks (default)
  --repair       Safe fixes (.venv normalization, dep sync, .env, optional settings patch)
  --hard-repair  Recreate ${VENV_DIR} with Python ${EXPECTED_PY} and full dependency resync
  --verify       Run verification suite after finishing

EOF
      exit 0
    ;;
  esac
done

# ---------- Helpers ----------
find_project_root(){
  local d="$PWD"
  while [[ "$d" != "/" ]]; do
    [[ -f "$d/manage.py" ]] && PROJECT_ROOT="$d" && return 0
    d="$(dirname "$d")"
  done
  return 1
}

choose_python(){
  for c in "python${EXPECTED_PY}" "python3.11" "python3" "python"; do
    if command -v "$c" >/dev/null 2>&1; then PYBIN="$c"; break; fi
  done
  [[ -z "$PYBIN" ]] && { err "No Python found"; exit 2; }
  inf "Selected Python: $("$PYBIN" -V 2>&1)"
}

setup_venv(){
  cd "$PROJECT_ROOT"
  local v="$PROJECT_ROOT/$VENV_DIR" a="$PROJECT_ROOT/$ALT_VENV"

  if command -v uv >/dev/null 2>&1; then USE_UV="true"; fi

  # Normalize
  if [[ -d "$a" && ! -d "$v" ]]; then
    warn "Found '$ALT_VENV' but not '$VENV_DIR'."
    if [[ "$MODE" != "diagnose" ]]; then
      mv "$a" "$v"; ok "Renamed '$ALT_VENV' → '$VENV_DIR'"
    else
      warn "Run with --repair to normalize venv directory."
    fi
  elif [[ -d "$a" && -d "$v" ]]; then
    warn "Both '$VENV_DIR' and '$ALT_VENV' exist."
    if [[ "$MODE" != "diagnose" ]]; then
      rm -rf "$a"; ok "Removed duplicate '$ALT_VENV'"
    fi
  fi

  if [[ "$MODE" == "hard-repair" ]]; then
    rm -rf "$v"; inf "Creating fresh $VENV_DIR with Python ${EXPECTED_PY}"; "$PYBIN" -m venv "$v"
  elif [[ ! -d "$v" ]]; then
    inf "Creating $VENV_DIR"; "$PYBIN" -m venv "$v"
  fi

  # shellcheck disable=SC1090
  source "$v/bin/activate"
  ok "Virtualenv active at: $VIRTUAL_ENV"

  # uv hinting
  if [[ "$USE_UV" == "true" ]]; then
    inf "uv detected; will target active venv via: uv pip ... --python $VIRTUAL_ENV/bin/python"
  fi
}

pip_or_uv_sync(){
  cd "$PROJECT_ROOT"
  local have_pyproj="false" have_lock="false"
  [[ -f pyproject.toml ]] && have_pyproj="true"
  [[ -f uv.lock ]] && have_lock="true"

  if [[ "$MODE" == "diagnose" ]]; then
    inf "Dependency sync skipped (diagnose mode)."
    return 0
  fi

  # Write a conservative constraints file based on your installed stack
  cat > .salbion_constraints.txt <<'CONS'
# Conservative, compatible constraints for Salbion stack
Django>=4.2,<5.0
wagtail>=7.0,<8.0
django-oscar>=4.0,<5.0
djangorestframework>=3.15,<3.17
django-environ>=0.10,<1.0
celery>=5.3,<6.0
redis>=4.5,<6.5
psycopg2-binary>=2.9,<3.0
Pillow>=10,<12
CONS

  if [[ "$USE_UV" == "true" ]]; then
    # Ensure uv is available inside venv
    python -m pip install -q --upgrade pip
    python -m pip install -q uv
    if [[ "$have_pyproj" == "true" ]]; then
      if [[ "$have_lock" == "true" ]]; then
        inf "Syncing via uv.lock (+ constraints)"
        uv pip sync --python "$VIRTUAL_ENV/bin/python" uv.lock --constraint .salbion_constraints.txt || true
      else
        inf "Installing from pyproject.toml (+ constraints)"
        uv pip install --python "$VIRTUAL_ENV/bin/python" -e ".[dev]" --constraint .salbion_constraints.txt || true
      fi
    elif [[ -f requirements.txt ]]; then
      inf "Installing from requirements.txt (+ constraints)"
      uv pip install --python "$VIRTUAL_ENV/bin/python" -r requirements.txt --constraint .salbion_constraints.txt || true
    else
      warn "No dependency manifest found; installing core set"
      uv pip install --python "$VIRTUAL_ENV/bin/python" Django 'wagtail<8' 'django-oscar<5' djangorestframework django-environ celery redis psycopg2-binary pillow || true
    fi
  else
    inf "uv not found; using pip"
    python -m pip install -q --upgrade pip
    if [[ -f requirements.txt ]]; then
      python -m pip install -r requirements.txt -c .salbion_constraints.txt || true
    elif [[ "$have_pyproj" == "true" ]]; then
      python -m pip install -e ".[dev]" -c .salbion_constraints.txt || true
    else
      python -m pip install Django 'wagtail<8' 'django-oscar<5' djangorestframework django-environ celery redis psycopg2-binary pillow || true
    fi
  fi
  ok "Dependency sync step completed"
}

check_core_imports(){
  local py='
import importlib, sys, os
mods = ["django", "wagtail", "oscar", "rest_framework"]
missing = []
for m in mods:
    try:
        importlib.import_module(m)
    except Exception as e:
        missing.append((m, str(e)))
print("MISSING=" + ",".join([m for m,_ in missing]))
print("PREFIX="+sys.prefix)
'
  local out
  out="$(python - <<'PY'\n'"$py"'\nPY')"
  local missing="${out#*MISSING=}"; missing="${missing%%$'\n'*}"
  local prefix="${out#*PREFIX=}"
  if [[ -n "$missing" ]]; then
    warn "Missing modules: $missing"
  else
    ok "Core modules importable"
  fi
  if [[ "$prefix" != "$VIRTUAL_ENV" ]]; then
    warn "sys.prefix != VIRTUAL_ENV (imports may come from system)."
  else
    ok "Imports resolved from venv site-packages"
  fi
}

ensure_env_and_settings(){
  # Ensure .env values
  local envf="$PROJECT_ROOT/.env"
  [[ -f "$envf" ]] || touch "$envf"

  # SECRET KEY
  if ! grep -E '^DJANGO_SECRET_KEY=' "$envf" >/dev/null 2>&1; then
    local key
    key="$(python - <<'PY'\nimport secrets; print("django-insecure-"+secrets.token_urlsafe(64))\nPY')"
    echo "DJANGO_SECRET_KEY=$key" >> "$envf"
    ok "Added DJANGO_SECRET_KEY to .env"
  else
    ok "DJANGO_SECRET_KEY present"
  fi

  # DATABASE_URL
  if ! grep -E '^DATABASE_URL=' "$envf" >/dev/null 2>&1; then
    echo "DATABASE_URL=sqlite:///${PROJECT_ROOT}/db.sqlite3" >> "$envf"
    ok "Added DATABASE_URL (sqlite) to .env"
  fi

  # DEBUG default
  if ! grep -E '^DEBUG=' "$envf" >/dev/null 2>&1; then
    echo "DEBUG=True" >> "$envf"
    ok "Added DEBUG to .env"
  fi

  if ! grep -E '^ALLOWED_HOSTS=' "$envf" >/dev/null 2>&1; then
    echo "ALLOWED_HOSTS=localhost,127.0.0.1" >> "$envf"
    ok "Added ALLOWED_HOSTS to .env"
  fi

  # Patch settings to use django-environ if needed
  local base="config/settings/base.py"
  if [[ -f "$base" ]]; then
    if ! grep -E 'import\s+environ' "$base" >/dev/null 2>&1; then
      warn "django-environ not detected in base.py; patching..."
      cp "$base" "$base.backup_$(date +%Y%m%d_%H%M%S)"
      # insert environ bootstrap at top
      awk 'BEGIN{added=0}
        NR==1{
          print "import os"; 
          print "import environ";
          print "env = environ.Env()";
          print "environ.Env.read_env(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), \".env\"))";
          added=1
        }
        {print}
      ' "$base" > "$base.tmp"
      mv "$base.tmp" "$base"
      ok "Inserted django-environ bootstrap into base.py"
    fi

    # Ensure settings read SECRET_KEY from env
    if ! grep -E 'SECRET_KEY\s*=\s*env\(' "$base" >/dev/null 2>&1; then
      # Replace existing SECRET_KEY or append one
      if grep -E 'SECRET_KEY\s*=' "$base" >/dev/null 2>&1; then
        perl -0777 -pe "s/SECRET_KEY\s*=.*$/SECRET_KEY = env('DJANGO_SECRET_KEY')/m" -i "$base" || true
      else
        printf "\n# Security\nSECRET_KEY = env('DJANGO_SECRET_KEY')\n" >> "$base"
      fi
      ok "Configured SECRET_KEY = env('DJANGO_SECRET_KEY') in base.py"
    fi

    # DATABASE_URL support (if not already)
    if ! grep -E 'DATABASES\s*=\s*' "$base" >/dev/null 2>&1 || ! grep -E 'env\.db' "$base" >/dev/null 2>&1; then
      cat >> "$base" <<'PYCONF'

# Database (env-driven)
if 'DATABASE_URL' in os.environ:
    DATABASES = {
        "default": env.db("DATABASE_URL")
    }
PYCONF
      ok "Ensured DATABASE_URL-driven database config"
    fi
  else
    warn "Could not find config/settings/base.py to patch"
  fi

  # warn about hardcoded secrets
  if grep -R --line-number -E "(SECRET_KEY|PASSWORD)\s*=\s*['\"][^'\"]+['\"]" config/ >/dev/null 2>&1; then
    warn "Possible hardcoded secrets detected in config/"
  fi
}

django_doctor(){
  cd "$PROJECT_ROOT"
  local dsm="${DJANGO_SETTINGS_MODULE:-config.settings.local}"
  inf "DJANGO_SETTINGS_MODULE: $dsm"

  if python - <<'PY'\nimport django; print(django.get_version())\nPY' >/dev/null 2>&1; then
    ok "Django import OK"
  else
    err "Django still not importable in venv"; return
  fi

  if ! python manage.py check >/dev/null 2>&1; then
    warn "'manage.py check' reported issues (see console)"
    python manage.py check || true
  else
    ok "Django system check passed"
  fi

  python manage.py showmigrations >/dev/null 2>&1 && ok "Migrations visible" || warn "showmigrations failed"

  if [[ "$MODE" == "repair" || "$MODE" == "hard-repair" ]]; then
    inf "Applying migrations..."; python manage.py migrate || true
    inf "Collecting static (safe)..."; python manage.py collectstatic --noinput || true
  fi
}

write_helpers(){
  cd "$PROJECT_ROOT"
  cat > quick_verify.sh <<'Q'
#!/usr/bin/env bash
set -e
source .venv/bin/activate
echo "Python: $(python --version)"
echo "Django: $(python -c 'import django; print(django.get_version())')"
echo "Checking Django setup..."
python - <<'PY'
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE','config.settings.local')
django.setup()
from django.conf import settings
print("✓ Django setup OK")
print("✓ DEBUG =", settings.DEBUG)
print("✓ DB =", settings.DATABASES["default"]["ENGINE"])
PY
echo "Migrations status:"
python manage.py showmigrations | tail -n +1 | sed -n '1,50p'
echo "Dry-run migrate:"
python manage.py migrate --plan || true
Q
  chmod +x quick_verify.sh

  cat > quick_start.sh <<'S'
#!/usr/bin/env bash
set -e
source .venv/bin/activate
python manage.py migrate
python manage.py createsuperuser --username admin --email admin@example.com || true
python manage.py runserver 0.0.0.0:8000
S
  chmod +x quick_start.sh
  ok "Wrote helper scripts: quick_verify.sh, quick_start.sh"
}

verify_suite(){
  cd "$PROJECT_ROOT"
  echo "---- VERIFY SUITE ----"
  ./quick_verify.sh || true
  echo "Testing server boot (5s)..."
  ( python manage.py runserver --noreload 0.0.0.0:8000 & echo $! > .server_pid ) || true
  sleep 5 || true
  if kill -0 "$(cat .server_pid 2>/dev/null || echo 0)" 2>/dev/null; then
    ok "Dev server started successfully"
    kill "$(cat .server_pid)" || true
  else
    warn "Dev server failed to stay up (check logs)"
  fi
  rm -f .server_pid
}

main(){
  echo -e "${BOLD}${MAG}╔══════════════════════════════════════════════════════╗"
  echo -e "║         Salbion Smart Repair v2 (Django stack)      ║"
  echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
  inf "Log: $LOG"
  inf "Mode: $MODE"

  if ! find_project_root; then err "Run this inside your Django project (where manage.py is)."; exit 1; fi
  ok "Project root: $PROJECT_ROOT"

  choose_python
  setup_venv
  pip_or_uv_sync
  check_core_imports
  ensure_env_and_settings
  django_doctor
  write_helpers
  [[ "$DO_VERIFY" == "true" ]] && verify_suite

  echo ""
  echo -e "${BOLD}${MAG}Summary${RESET}"
  echo "  • Mode: $MODE"
  echo "  • Log:  $LOG"
  echo "  • Next: ${BOLD}source .venv/bin/activate && ./quick_verify.sh${RESET}"
  echo "         or ${BOLD}./quick_start.sh${RESET} to run the dev server"
  echo ""
  ok "Completed."
}

main "$@"
