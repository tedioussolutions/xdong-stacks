#!/usr/bin/env bash
# Validate adguard stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Load env vars (all have defaults, so this is informational only)
if [ -f .env ]; then
  # shellcheck disable=SC1091
  source .env 2>/dev/null || true
fi

# 3. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 4. Port conflict checks
WEB_PORT="${ADGUARD_WEB_PORT:-3000}"
DNS_PORT="${ADGUARD_DNS_PORT:-53}"
HTTPS_PORT="${ADGUARD_HTTPS_PORT:-443}"
TLS_PORT="${ADGUARD_DNS_QUIC_PORT:-853}"

# Web UI port
if ss -tlnp 2>/dev/null | grep -q ":${WEB_PORT} "; then
  warn "Port ${WEB_PORT} (web UI) is already in use — change ADGUARD_WEB_PORT in .env"
fi

# HTTPS/DoH port
if ss -tlnp 2>/dev/null | grep -q ":${HTTPS_PORT} "; then
  warn "Port ${HTTPS_PORT} (DNS-over-HTTPS) is already in use — change ADGUARD_HTTPS_PORT in .env"
fi

# DoT port
if ss -tlnp 2>/dev/null | grep -q ":${TLS_PORT} "; then
  warn "Port ${TLS_PORT} (DNS-over-TLS) is already in use — change ADGUARD_DNS_QUIC_PORT in .env"
fi

# 5. Port 53 — special handling: systemd-resolved conflict is the #1 deploy failure
if ss -tlnp 2>/dev/null | grep -q ":${DNS_PORT} "; then
  # Check if systemd-resolved is the culprit
  if ss -tlnp 2>/dev/null | grep ":${DNS_PORT} " | grep -q "systemd-resolve"; then
    fail "Port ${DNS_PORT} is held by systemd-resolved — AdGuard cannot start until this is resolved.

  Fix (Ubuntu/Debian):
    1. Edit /etc/systemd/resolved.conf and set: DNSStubListener=no
    2. Run: sudo systemctl restart systemd-resolved
    3. Run: sudo ln -sf /run/systemd/resolve/resolv.conf /etc/resolv.conf
    4. Re-run this script to confirm port 53 is free.

  See README.md → 'Port 53 Conflict' for full instructions."
  else
    fail "Port ${DNS_PORT} (DNS) is already in use by another process — change ADGUARD_DNS_PORT in .env or free the port"
  fi
fi

# Also check UDP port 53 (DNS uses both TCP and UDP)
if ss -ulnp 2>/dev/null | grep -q ":${DNS_PORT} "; then
  if ss -ulnp 2>/dev/null | grep ":${DNS_PORT} " | grep -q "systemd-resolve"; then
    warn "UDP port ${DNS_PORT} is held by systemd-resolved — follow the fix in step 5 above"
  else
    warn "UDP port ${DNS_PORT} is already in use — DNS queries may fail"
  fi
fi

if [ "$ERRORS" -gt 0 ]; then
  echo ""
  echo "FAILED: ${ERRORS} error(s) found — fix them before deploying"
  exit 1
fi
echo "OK: adguard stack configuration is valid"
