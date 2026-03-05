#!/usr/bin/env bash
# Validate ollama stack configuration before deploying.
set -euo pipefail
cd "$(dirname "$0")"

ERRORS=0
warn() { echo "WARNING: $1"; }
fail() { echo "ERROR: $1"; ERRORS=$((ERRORS + 1)); }

# 1. Check .env exists
[ -f .env ] || fail ".env file missing — run: cp .env.example .env && nano .env"

# 2. Load environment variables
# shellcheck disable=SC1091
[ -f .env ] && source .env 2>/dev/null || true

# 3. Docker Compose syntax check
docker compose config --quiet 2>/dev/null || fail "docker-compose.yml has syntax errors"

# 4. Port conflict checks
OLLAMA_PORT="${OLLAMA_PORT:-11434}"
WEBUI_PORT="${WEBUI_PORT:-3000}"

if ss -tlnp 2>/dev/null | grep -q ":${OLLAMA_PORT} "; then
  warn "Port ${OLLAMA_PORT} already in use — change OLLAMA_PORT in .env"
fi

if ss -tlnp 2>/dev/null | grep -q ":${WEBUI_PORT} "; then
  warn "Port ${WEBUI_PORT} already in use — change WEBUI_PORT in .env"
fi

# 5. NVIDIA GPU availability check (informational only)
if command -v nvidia-smi &>/dev/null; then
  echo "INFO: nvidia-smi detected — GPU passthrough is available"
  echo "      Uncomment the 'deploy' block in docker-compose.yml to enable it"
else
  echo "INFO: nvidia-smi not found — GPU passthrough will not be available (CPU-only mode)"
fi

if [ "$ERRORS" -gt 0 ]; then
  echo "FAILED: ${ERRORS} error(s) found — fix them before deploying"
  exit 1
fi
echo "OK: ollama stack configuration is valid"
