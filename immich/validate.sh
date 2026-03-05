#!/usr/bin/env bash
# Validate immich stack configuration before deploying.
set -uo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Load env and check required variables
if [ -f .env ]; then
  # Use grep/sed to extract values rather than sourcing — avoids re-executing the script
  DB_PASSWORD=$(grep -E '^DB_PASSWORD=' .env | cut -d= -f2- | tr -d '"' | tr -d "'" || true)
  UPLOAD_LOCATION=$(grep -E '^UPLOAD_LOCATION=' .env | cut -d= -f2- | tr -d '"' | tr -d "'" || true)
  IMMICH_PORT=$(grep -E '^IMMICH_PORT=' .env | cut -d= -f2- | tr -d '"' | tr -d "'" || true)

  # DB_PASSWORD is required
  if [ -z "${DB_PASSWORD:-}" ]; then
    fail "DB_PASSWORD is not set — generate one with: openssl rand -base64 32"
  elif [ "${DB_PASSWORD}" = "changeme" ]; then
    fail "DB_PASSWORD is still the placeholder — replace it before deploying"
  fi

  # Warn if UPLOAD_LOCATION is the default relative path (fine for tests, not production)
  if [ "${UPLOAD_LOCATION:-./library}" = "./library" ]; then
    warn "UPLOAD_LOCATION is set to ./library (relative path) — use an absolute path for production"
  fi
fi

# 3. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 4. Port conflict check
PORT="${IMMICH_PORT:-2283}"
if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
  warn "Port ${PORT} is already in use — change IMMICH_PORT in .env"
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found — fix them before deploying"
  exit 1
fi
echo "OK: immich stack configuration is valid"
