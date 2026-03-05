#!/usr/bin/env bash
# Validate local-homelab stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Required environment variables (none strictly required — all have defaults)
source .env 2>/dev/null || true

# 3. Caddyfile exists
[ -f Caddyfile ] || fail "Caddyfile missing"

# 4. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 5. Port conflicts
for port in "${CADDY_HTTP_PORT:-80}" "${CADDY_HTTPS_PORT:-443}"; do
  ss -tlnp 2>/dev/null | grep -q ":${port} " && warn "Port ${port} already in use"
done

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found"
  exit 1
fi
echo "OK: local-homelab stack configuration is valid"
