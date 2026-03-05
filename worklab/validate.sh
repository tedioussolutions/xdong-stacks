#!/usr/bin/env bash
# Validate worklab stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Required environment variables
source .env 2>/dev/null || true
[ -n "${MEILI_MASTER_KEY:-}" ]           || fail "MEILI_MASTER_KEY is not set in .env"
[ -n "${POSTGRES_PASSWORD:-}" ]          || fail "POSTGRES_PASSWORD is not set in .env"
[ -n "${CODE_SERVER_PASSWORD:-}" ]       || fail "CODE_SERVER_PASSWORD is not set in .env"
[ -n "${KARAKEEP_NEXTAUTH_SECRET:-}" ]   || fail "KARAKEEP_NEXTAUTH_SECRET is not set in .env"
[ -n "${CALENDAR_NEXTAUTH_SECRET:-}" ]   || fail "CALENDAR_NEXTAUTH_SECRET is not set in .env"

# 3. Caddyfile exists
[ -f Caddyfile ] || fail "Caddyfile missing"

# 4. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 5. Port conflicts
for port in "${CADDY_HTTP_PORT:-80}"; do
  ss -tlnp 2>/dev/null | grep -q ":${port} " && warn "Port ${port} already in use"
done

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found"
  exit 1
fi
echo "OK: worklab stack configuration is valid"
