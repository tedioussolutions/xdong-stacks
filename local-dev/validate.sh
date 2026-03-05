#!/usr/bin/env bash
# Validate local-dev stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Required environment variables
source .env 2>/dev/null || true
[ -n "${POSTGRES_PASSWORD:-}" ]       || fail "POSTGRES_PASSWORD is not set in .env"
[ -n "${FORGEJO_DB_PASSWORD:-}" ]     || fail "FORGEJO_DB_PASSWORD is not set in .env"
[ -n "${N8N_DB_PASSWORD:-}" ]         || fail "N8N_DB_PASSWORD is not set in .env"
[ -n "${BYTEBASE_DB_PASSWORD:-}" ]    || fail "BYTEBASE_DB_PASSWORD is not set in .env"
[ -n "${ACTIVEPIECES_DB_PASSWORD:-}" ]|| fail "ACTIVEPIECES_DB_PASSWORD is not set in .env"
[ -n "${CODE_SERVER_PASSWORD:-}" ]    || fail "CODE_SERVER_PASSWORD is not set in .env"
[ -n "${MEILI_MASTER_KEY:-}" ]        || fail "MEILI_MASTER_KEY is not set in .env"
[ -n "${AP_ENCRYPTION_KEY:-}" ]       || fail "AP_ENCRYPTION_KEY is not set in .env"
[ -n "${AP_JWT_SECRET:-}" ]           || fail "AP_JWT_SECRET is not set in .env"
[ -n "${OPEN_WEBUI_SECRET_KEY:-}" ]   || fail "OPEN_WEBUI_SECRET_KEY is not set in .env"

# 3. Caddyfile exists (optional — direct port access works without it)
[ -f Caddyfile ] || warn "Caddyfile missing — subdomain routing disabled (direct ports still work)"

# 4. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 5. Port conflicts
for port in 3000 8443 3001 2222 6333 6334 7700 5678 8080 8888 8081 8082 8083 3500; do
  ss -tlnp 2>/dev/null | grep -q ":${port} " && warn "Port ${port} already in use"
done

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found"
  exit 1
fi
echo "OK: local-dev stack configuration is valid"
