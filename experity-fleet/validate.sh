#!/usr/bin/env bash
# Validate experity-fleet stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Required environment variables
source .env 2>/dev/null || true
[ -n "${LIBRENMS_DB_PASSWORD:-}" ] || fail "LIBRENMS_DB_PASSWORD is not set in .env"

# 3. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 4. Port conflicts
for port in "${SMOKEPING_PORT:-8080}" "${LIBRENMS_PORT:-8000}" "${PROMETHEUS_PORT:-9090}" "${GRAFANA_PORT:-3000}"; do
  ss -tlnp 2>/dev/null | grep -q ":${port} " && warn "Port ${port} already in use"
done

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found"
  exit 1
fi
echo "OK: experity-fleet stack configuration is valid"
