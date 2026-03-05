#!/usr/bin/env bash
# =============================================================================
# local-dev Stack — Pre-Deployment Validation Script
# =============================================================================
# Run this script before `docker compose up -d` to catch common issues.
# Usage: bash validate-stack-config.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

PASS=0
WARN=0
FAIL=0

green()  { echo -e "\033[0;32m✓ $*\033[0m"; }
yellow() { echo -e "\033[0;33m⚠ $*\033[0m"; }
red()    { echo -e "\033[0;31m✗ $*\033[0m"; }

pass()   { green "$*";  ((PASS++));  }
warn()   { yellow "$*"; ((WARN++)); }
fail()   { red "$*";    ((FAIL++));  }

echo "======================================================================"
echo " local-dev Stack: Pre-Deployment Validation"
echo "======================================================================"
echo ""

# ── 1. Prerequisites ─────────────────────────────────────────────────────────
echo "── Prerequisites ────────────────────────────────────────────────────"

if command -v docker &>/dev/null; then
  pass "Docker installed ($(docker --version | head -1))"
else
  fail "Docker not found — install Docker: https://docs.docker.com/get-docker/"
fi

if docker info &>/dev/null; then
  pass "Docker daemon is running"
else
  fail "Docker daemon is not running — start Docker and retry"
fi

if docker compose version &>/dev/null; then
  pass "Docker Compose plugin available ($(docker compose version --short))"
elif docker-compose version &>/dev/null; then
  warn "Found legacy 'docker-compose' — upgrade to the Compose plugin ('docker compose')"
else
  fail "Docker Compose not found"
fi
echo ""

# ── 2. Environment file ──────────────────────────────────────────────────────
echo "── Environment File ─────────────────────────────────────────────────"

if [[ -f ".env" ]]; then
  pass ".env file exists"
else
  fail ".env file not found — run: cp .env.example .env && nano .env"
fi

# Source .env (silently) to check values
if [[ -f ".env" ]]; then
  set +u
  # shellcheck disable=SC1091
  source .env 2>/dev/null || true
  set -u

  # Check for placeholder values in required secrets
  check_secret() {
    local var_name="$1"
    local var_value="${!var_name:-}"
    if [[ -z "$var_value" ]]; then
      fail "$var_name is empty — set a value in .env"
    elif [[ "$var_value" == change-me-* ]] || [[ "$var_value" == "change-me" ]]; then
      fail "$var_name still has placeholder value '$var_value' — update .env"
    else
      pass "$var_name is set"
    fi
  }

  check_secret POSTGRES_PASSWORD
  check_secret FORGEJO_DB_PASSWORD
  check_secret N8N_DB_PASSWORD
  check_secret BYTEBASE_DB_PASSWORD
  check_secret ACTIVEPIECES_DB_PASSWORD
  check_secret CODE_SERVER_PASSWORD
  check_secret MEILI_MASTER_KEY
  check_secret OPEN_WEBUI_SECRET_KEY
  check_secret AP_ENCRYPTION_KEY
  check_secret AP_JWT_SECRET
  check_secret ANYTHINGLLM_JWT_SECRET
  check_secret ANYTHINGLLM_PASSWORD

  # Validate key lengths for Activepieces
  AP_ENC="${AP_ENCRYPTION_KEY:-}"
  AP_JWT="${AP_JWT_SECRET:-}"
  if [[ ${#AP_ENC} -eq 32 ]]; then
    pass "AP_ENCRYPTION_KEY is 32 characters (correct)"
  elif [[ ${#AP_ENC} -gt 0 ]]; then
    fail "AP_ENCRYPTION_KEY must be exactly 32 hex chars (got ${#AP_ENC}) — run: openssl rand -hex 16"
  fi
  if [[ ${#AP_JWT} -eq 32 ]]; then
    pass "AP_JWT_SECRET is 32 characters (correct)"
  elif [[ ${#AP_JWT} -gt 0 ]]; then
    fail "AP_JWT_SECRET must be exactly 32 hex chars (got ${#AP_JWT}) — run: openssl rand -hex 16"
  fi
fi
echo ""

# ── 3. Required files ────────────────────────────────────────────────────────
echo "── Required Files ───────────────────────────────────────────────────"

required_files=(
  "docker-compose.yml"
  "postgres/init/01-create-databases.sql"
  "homepage/config/settings.yaml"
  "homepage/config/docker.yaml"
  "homepage/config/services.yaml"
  "homepage/config/bookmarks.yaml"
)

for f in "${required_files[@]}"; do
  if [[ -f "$f" ]]; then
    pass "$f"
  else
    fail "$f — file missing"
  fi
done
echo ""

# ── 4. Compose syntax validation ─────────────────────────────────────────────
echo "── Compose Syntax ───────────────────────────────────────────────────"

if [[ -f ".env" ]]; then
  if docker compose config --quiet 2>/dev/null; then
    pass "docker-compose.yml syntax is valid"
  else
    fail "docker-compose.yml has syntax errors — run: docker compose config"
  fi
else
  warn "Skipping compose validation — .env not found"
fi
echo ""

# ── 5. Port availability ─────────────────────────────────────────────────────
echo "── Port Availability ────────────────────────────────────────────────"

check_port() {
  local port="$1"
  local service="$2"
  if ss -tlnp "sport = :$port" 2>/dev/null | grep -q LISTEN; then
    fail "Port $port ($service) is already in use — change the host port in docker-compose.yml"
  else
    pass "Port $port ($service) is available"
  fi
}

check_port 3000 "Homepage"
check_port 3001 "Forgejo HTTP"
check_port 2222 "Forgejo SSH"
check_port 3500 "AnythingLLM"
check_port 5678 "n8n"
check_port 6333 "Qdrant REST"
check_port 6334 "Qdrant gRPC"
check_port 7700 "Meilisearch"
check_port 8000 "(reserved — not used by this stack)"
check_port 8080 "Dozzle"
check_port 8081 "Open WebUI"
check_port 8082 "Activepieces"
check_port 8083 "CyberChef"
check_port 8443 "Code-Server"
check_port 8888 "Bytebase"
echo ""

# ── 6. Docker socket ─────────────────────────────────────────────────────────
echo "── Docker Socket ────────────────────────────────────────────────────"

if [[ -S "/var/run/docker.sock" ]]; then
  pass "/var/run/docker.sock exists (required by Homepage and Dozzle)"
else
  warn "/var/run/docker.sock not found — Homepage Docker integration will not work"
fi
echo ""

# ── Summary ───────────────────────────────────────────────────────────────────
echo "======================================================================"
echo " Results: ${PASS} passed · ${WARN} warnings · ${FAIL} failed"
echo "======================================================================"

if [[ $FAIL -gt 0 ]]; then
  echo ""
  echo "❌ Fix the failed checks above before running: docker compose up -d"
  exit 1
elif [[ $WARN -gt 0 ]]; then
  echo ""
  echo "⚠️  Warnings found — review them, then run: docker compose up -d"
  exit 0
else
  echo ""
  echo "✅ All checks passed — ready to deploy:"
  echo "   docker compose up -d"
  exit 0
fi
