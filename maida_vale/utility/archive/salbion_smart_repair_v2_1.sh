#!/usr/bin/env bash
# salbion_smart_repair_v2_1.sh — fixed here-docs & robust inline Python

set -Eeuo pipefail

# Colors
if [[ -t 1 ]]; then
  RED=$'\e[31m'; GREEN=$'\e[32m'; YELLOW=$'\e[33m'; BLUE=$'\e[34m'; MAG=$'\e[35m'; CYAN=$'\e[36m'; BOLD=$'\e[1m'; RESET=$'\e[0m'
else
  RED=""; GREEN=""; YELLOW=""; BLUE=""; MAG=""; CYAN=""; BOLD=""; RESET=""
fi
ts(){ date +"%Y-%m-%d %H:%M:%S"; }
log(){ printf "%s %b%s%b\n" "$(ts)" "$2" "$1" "$RESET" | tee -a "$LOG"; }
ok(){  log "$1" "$GREEN[OK] "; }
inf(){  log "$1" "$CYAN[INFO] "; }
warn(){ log "$1" "$YELLOW[WARN] "; }
err(){  log "$1" "$RED[ERR] "; }

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
    --diagnose) MODE="diagnose";;
    --repair) MODE="repair";;
    --hard-repair) MODE="hard-repair";;
    --verify) DO_VERIFY="true";;
    -h|--help)
      cat <<EOF
${BOLD}salbion_smart_repair_v2_1.sh${RESET}
Usage:
  $0 [--diagnose|--repair|--hard-repair] [--verify]
EOF
      exit 0
    ;;
  esac
done

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

  if [[ -d "$a" && ! -d "$v" ]]; then
    warn "Found '$ALT_VENV' but not '$VENV_DIR'."
    [[ "$MODE" != "diagnose" ]] && { mv "$a" "$v"; ok "Renamed '$ALT_VENV' → '$VENV_DIR'"; } || warn "Run with --repair to normalize."
  elif [[ -d "$a" && -d "$v" ]]; then
    warn "Both '$VENV_DIR' and '$ALT_VENV' exist."
    [[ "$MODE" != "diagnose" ]] && { rm -rf "$a"; ok "Removed duplicate '$ALT_VENV'"; }
  fi

  if [[ "$MODE" == "hard-repair" ]]; then
    rm -rf "$v"; inf "Creating fresh $VENV_DIR with Python ${EXPECTED_PY}"; "$PYBIN" -m venv "$v"
  elif [[ ! -d "$v" ]]; then
    inf "Creating $VENV_DIR"; "$PYBIN" -m venv "$v"
  fi

  # shellcheck disable=SC1090
  source "$v/bin/activate"
  ok "Virtualenv active at: $VIRTUAL_ENV"

  [[ "$USE_UV" == "true" ]] && inf "uv detected; targeting: $VIRTUAL_ENV/bin/python"
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

  cat > .salbion_constraints.txt <<'CONS'
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

  python -m pip -q install --upgrade pip
  if command -v uv >/dev/null 2>&1; then
    python -m pip -q install uv
    if [[ "$have_pyproj" == "true" ]]; then
      if [[ "$have_lock" == "true" ]]; then
        inf "uv sync via uv.lock (+ constraints)"
        uv pip sync --python "$VIRTUAL_ENV/bin/python" uv.lock --constraint .salbion_constraints.txt || true
      else
        inf "uv install from pyproject.toml (+ constraints)"
        uv pip install --python "$VIRTUAL_ENV/bin/python" -e ".[dev]" --constraint .salbion_constraints.txt || true
      fi
    elif [[ -f requirements.txt ]]; then
      inf "uv install from requirements.txt (+ constraints)"
      uv pip install --python "$VIRTUAL_ENV/bin/python" -r requirements.txt --constraint .salbion_constraints.txt || true
    else
      inf "uv install core set"
      uv pip install --python "$VIRTUAL_ENV/bin/python" Django 'wagtail<8' 'django-oscar<5' djangorestframework django-environ celery redis psycopg2-binary pillow || true
    fi
  else
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
  # Proper here-doc (single quotes to prevent interpolation)
  local out
  out="$(python - <<'PY'
import importlib, sys
mods = ["django", "wagtail", "oscar", "rest_framework"]
missing = []
for m in mods:
    try:
        importlib.import_module(m)
    except Exception:
        missing.append(m)
print("MISSING=" + ",".join(missing))
print("PREFIX=" + sys.prefix)
PY
)"
  local missing="${out#*MISSING=}"; missing="${missing%%$'\n'*}"
  local prefix="${out#*PREFIX=}"
  if [[ -n "$missing" ]]; then
    warn "Missing modules: $missing"
  else
    ok "Core modules importable"
  fi
  if [[ "${prefix}" != "${VIRTUAL_ENV}" ]]; then
    warn "sys.prefix != VIRTUAL_ENV (imports may come from system)."
  else
    ok "Imports resolved from venv site-packages"
  fi
}

ensure_env_and_settings(){
  local envf="$PROJECT_ROOT/.env"
  [[ -f "$envf" ]] || touch "$envf"

  if ! grep -E '^DJANGO_SECRET_KEY=' "$envf" >/dev/null 2>&1; then
    local key
    key="$(python - <<'PY'
import secrets
print("django-insecure-"+secrets.token_urlsafe(64))
PY
)"
    echo "DJANGO_SECRET_KEY=$key" >> "$envf"
    ok "Added DJANGO_SECRET_KEY to .env"
  fi

  grep -E '^DATABASE_URL=' "$envf" >/dev/null 2>&1 || { echo "DATABASE_URL=sqlite:///${PROJECT_ROOT}/db.sqlite3" >> "$envf"; ok "Added DATABASE_URL (sqlite)"; }
  grep -E '^DEBUG=' "$envf" >/dev/null 2>&1 || { echo "DEBUG=True" >> "$envf"; ok "Added DEBUG"; }
  grep -E '^ALLOWED_HOSTS=' "$envf" >/dev/null 2>&1 || { echo "ALLOWED_HOSTS=localhost,127.0.0.1" >> "$envf"; ok "Added ALLOWED_HOSTS"; }

  local base="config/settings/base.py"
  if [[ -f "$base" ]]; then
    if ! grep -E 'import\s+environ' "$base" >/dev/null 2>&1; then
      cp "$base" "$base.backup_$(date +%Y%m%d_%H%M%S)"
      awk 'BEGIN{added=0}
        NR==1{
          print "import os"
          print "import environ"
          print "env = environ.Env()"
          print "environ.Env.read_env(os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(__file__))), \".env\"))"
        }
        {print}
      ' "$base" > "$base.tmp" && mv "$base.tmp" "$base"
      ok "Inserted django-environ bootstrap into base.py"
    fi

    if ! grep -E 'SECRET_KEY\s*=\s*env\(' "$base" >/dev/null 2>&1; then
      if grep -E 'SECRET_KEY\s*=' "$base" >/dev/null 2>&1; then
        perl -0777 -pe "s/SECRET_KEY\\s*=.*$/SECRET_KEY = env('DJANGO_SECRET_KEY')/m" -i "$base" || true
      else
        printf "\nSECRET_KEY = env('DJANGO_SECRET_KEY')\n" >> "$base"
      fi
      ok "Configured SECRET_KEY via env in base.py"
    fi

    if ! grep -E 'env\.db' "$base" >/dev/null 2>&1; then
      cat >> "$base" <<'PYCONF'

# Database (env-driven)
if 'DATABASE_URL' in os.environ:
    DATABASES = {"default": env.db("DATABASE_URL")}
PYCONF
      ok "Ensured DATABASE_URL-driven database config"
    fi

    if grep -R --line-number -E "(SECRET_KEY|PASSWORD)\s*=\s*['\"][^'\"]+['\"]" config/ >/dev/null 2>&1; then
      warn "Possible hardcoded secrets detected in config/"
    fi
  else
    warn "config/settings/base.py not found"
  fi
}

django_doctor(){
  cd "$PROJECT_ROOT"
  local dsm="${DJANGO_SETTINGS_MODULE:-config.settings.local}"
  inf "DJANGO_SETTINGS_MODULE: $dsm"
  if python - <<'PY'
import django; print(django.get_version())
PY
  >/dev/null 2>&1; then
    ok "Django import OK"
  else
    err "Django not importable in venv"; return
  fi

  if python manage.py check >/dev/null 2>&1; then
    ok "Django system check passed"
  else
    warn "'manage.py check' reported issues"; python manage.py check || true
  fi

  python manage.py showmigrations >/dev/null 2>&1 && ok "Migrations visible" || warn "showmigrations failed"

  if [[ "$MODE" == "repair" || "$MODE" == "hard-repair" ]]; then
    inf "Applying migrations..."; python manage.py migrate || true
    inf "Collecting static..."; python manage.py collectstatic --noinput || true
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
python - <<'PY'
import os, django
os.environ.setdefault('DJANGO_SETTINGS_MODULE','config.settings.local')
django.setup()
from django.conf import settings
print("✓ Django setup OK")
print("✓ DEBUG =", settings.DEBUG)
print("✓ DB =", settings.DATABASES["default"]["ENGINE"])
PY
python manage.py check
python manage.py showmigrations | sed -n '1,80p'
Q
  chmod +x quick_verify.sh

  cat > quick_start.sh <<'S'
#!/usr/bin/env bash
set -e
source .venv/bin/activate
python manage.py migrate
python - <<'PY'
from django.contrib.auth import get_user_model
U = get_user_model()
if not U.objects.filter(username='admin').exists():
    U.objects.create_superuser('admin','admin@example.com','admin123')
    print('✓ Superuser created: admin/admin123')
else:
    print('✓ Superuser exists')
PY
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
  echo -e "║         Salbion Smart Repair v2.1 (Django stack)    ║"
  echo -e "╚══════════════════════════════════════════════════════╝${RESET}"
  inf "Log: $LOG"
  inf "Mode: $MODE"

  if ! find_project_root; then err "Run inside your Django project (with manage.py)."; exit 1; fi
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
  echo "  • Next: source .venv/bin/activate && ./quick_verify.sh"
  echo "          or ./quick_start.sh"
  echo ""
  ok "Completed."
}

main "$@"
