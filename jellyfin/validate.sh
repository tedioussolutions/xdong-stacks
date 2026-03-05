#!/usr/bin/env bash
# Validate jellyfin stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Load environment variables
source .env 2>/dev/null || true

# 3. Check MEDIA_PATH exists and is readable
MEDIA_PATH="${MEDIA_PATH:-/srv/media}"
if [ ! -d "$MEDIA_PATH" ]; then
  fail "MEDIA_PATH directory does not exist: $MEDIA_PATH"
elif [ ! -r "$MEDIA_PATH" ]; then
  fail "MEDIA_PATH is not readable by current user: $MEDIA_PATH"
fi

# 4. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 5. Port conflict check
JELLYFIN_PORT="${JELLYFIN_PORT:-8096}"
ss -tlnp 2>/dev/null | grep -q ":${JELLYFIN_PORT} " && warn "Port ${JELLYFIN_PORT} already in use — change JELLYFIN_PORT in .env"

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found"
  exit 1
fi
echo "OK: jellyfin stack configuration is valid"
