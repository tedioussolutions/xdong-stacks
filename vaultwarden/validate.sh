#!/usr/bin/env bash
# Validate vaultwarden stack configuration before deploying.
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

  # ADMIN_TOKEN must be set and not the placeholder
  if [ -z "${ADMIN_TOKEN:-}" ]; then
    fail "ADMIN_TOKEN is not set — generate one with: openssl rand -base64 48"
  elif [ "${ADMIN_TOKEN}" = "change-me-generate-with-openssl-rand-base64-48" ]; then
    fail "ADMIN_TOKEN is still the placeholder — replace it with: openssl rand -base64 48"
  fi

  # DOMAIN must be set and look like a real URL
  if [ -z "${DOMAIN:-}" ]; then
    fail "DOMAIN is not set — set it to your full HTTPS URL (e.g. https://vault.example.com)"
  elif [ "${DOMAIN}" = "https://vault.example.com" ]; then
    warn "DOMAIN is still the example value — update it to your actual domain"
  elif [[ "${DOMAIN}" != https://* ]]; then
    warn "DOMAIN does not start with https:// — Bitwarden clients require HTTPS"
  fi
fi

# 3. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 4. Port conflict check
PORT="${VAULTWARDEN_PORT:-8080}"
if ss -tlnp 2>/dev/null | grep -q ":${PORT} "; then
  warn "Port ${PORT} is already in use — change VAULTWARDEN_PORT in .env"
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found — fix them before deploying"
  exit 1
fi
echo "OK: vaultwarden stack configuration is valid"
