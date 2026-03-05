#!/usr/bin/env bash
# Validate nextcloud AIO stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Load env and check required variables
if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env 2>/dev/null || true

  # NEXTCLOUD_TRUSTED_DOMAINS must be set and not the placeholder
  if [ -z "${NEXTCLOUD_TRUSTED_DOMAINS:-}" ]; then
    fail "NEXTCLOUD_TRUSTED_DOMAINS is not set — set it to your domain or IP (e.g. nextcloud.example.com)"
  elif [ "${NEXTCLOUD_TRUSTED_DOMAINS}" = "nextcloud.local" ]; then
    warn "NEXTCLOUD_TRUSTED_DOMAINS is still the default 'nextcloud.local' — update to your actual domain before going to production"
  fi

  # APACHE_PORT sanity check — must be numeric
  APACHE_PORT="${APACHE_PORT:-11000}"
  if ! [[ "${APACHE_PORT}" =~ ^[0-9]+$ ]]; then
    fail "APACHE_PORT must be a number, got: ${APACHE_PORT}"
  fi

  # NEXTCLOUD_DATADIR: if set to an absolute path, the directory must exist
  if [ -n "${NEXTCLOUD_DATADIR:-}" ] && [[ "${NEXTCLOUD_DATADIR}" == /* ]]; then
    if [ ! -d "${NEXTCLOUD_DATADIR}" ]; then
      fail "NEXTCLOUD_DATADIR path does not exist: ${NEXTCLOUD_DATADIR} — create it first or use the default Docker volume"
    fi
  fi
fi

# 3. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 4. Port conflict check for AIO dashboard port
AIO_PORT="${NEXTCLOUD_AIO_PORT:-8080}"
if ss -tlnp 2>/dev/null | grep -q ":${AIO_PORT} "; then
  warn "Port ${AIO_PORT} is already in use — change NEXTCLOUD_AIO_PORT in .env"
fi

# 5. Docker socket accessibility check
if [ ! -S /var/run/docker.sock ]; then
  fail "Docker socket not found at /var/run/docker.sock — AIO requires Docker socket access to manage sub-containers"
elif [ ! -r /var/run/docker.sock ]; then
  fail "Docker socket is not readable — add your user to the 'docker' group: sudo usermod -aG docker \$USER"
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found — fix them before deploying"
  exit 1
fi
echo "OK: nextcloud AIO stack configuration is valid"
