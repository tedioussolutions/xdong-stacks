#!/usr/bin/env bash
# Validate caddy stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Load env vars (all have defaults, so this is informational only)
source .env 2>/dev/null || true

# 3. Caddyfile exists
[ -f Caddyfile ] || fail "Caddyfile missing"

# 4. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 5. Port conflict check
for port in "${HTTP_PORT:-80}" "${HTTPS_PORT:-443}"; do
  ss -tlnp 2>/dev/null | grep -q ":${port} " && warn "Port ${port} already in use — update .env or free the port first"
done

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found"
  exit 1
fi
echo "OK: caddy stack configuration is valid"
