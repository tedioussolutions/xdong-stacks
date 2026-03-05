#!/usr/bin/env bash
# Validate home-assistant stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Load environment variables
source .env 2>/dev/null || true

# 3. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 4. Port conflict check for Home Assistant
HA_PORT="${HA_PORT:-8123}"
ss -tlnp 2>/dev/null | grep -q ":${HA_PORT} " && warn "Port ${HA_PORT} already in use — set a different HA_PORT in .env"

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found"
  exit 1
fi
echo "OK: home-assistant stack configuration is valid"
