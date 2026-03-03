#!/usr/bin/env bash
# Validate local homelab stack configuration before deploying
set -euo pipefail
cd "$(dirname "$(realpath "$0")")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

pass()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }
fail()  { echo -e "${RED}✗${NC} $1"; ((ERRORS++)); }

echo "Validating local homelab stack..."
echo

# ── Check .env exists ────────────────────────────────────────────────
if [ -f .env ]; then
    pass ".env file exists"
    # Check for placeholder secrets (Arcane requires generated values)
    if grep -q 'changeme' .env 2>/dev/null; then
        fail ".env still has 'changeme' placeholders — generate Arcane secrets:"
        echo "      docker run --rm ghcr.io/getarcaneapp/arcane:latest /app/arcane generate secret"
        echo "      (run twice: once for ARCANE_ENCRYPTION_KEY, once for ARCANE_JWT_SECRET)"
    fi
else
    fail ".env file missing — run: cp .env.example .env"
fi

# ── Check Docker ─────────────────────────────────────────────────────
if command -v docker &>/dev/null; then
    pass "Docker is installed ($(docker --version | grep -oP '\d+\.\d+\.\d+' | head -1))"
else
    fail "Docker is not installed"
fi

if docker compose version &>/dev/null; then
    pass "Docker Compose v2 available"
else
    fail "Docker Compose v2 not available"
fi

# ── Validate compose syntax ──────────────────────────────────────────
if [ -f .env ]; then
    if docker compose config --quiet 2>/dev/null; then
        pass "docker-compose.yml syntax valid"
    else
        fail "docker-compose.yml has syntax errors — run: docker compose config"
    fi
fi

# ── Check required config files ──────────────────────────────────────
for f in \
    Caddyfile \
    homepage/config/docker.yaml \
    homepage/config/services.yaml \
    homepage/config/settings.yaml \
    homepage/config/bookmarks.yaml; do
    if [ -f "$f" ]; then
        pass "$f exists"
    else
        fail "$f missing"
    fi
done

# ── Check Docker socket is accessible ────────────────────────────────
if [ -S /var/run/docker.sock ]; then
    pass "/var/run/docker.sock accessible"
else
    fail "/var/run/docker.sock not found — is Docker running?"
fi

# ── Check ports available ────────────────────────────────────────────
for port in 80 443; do
    if ! ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        pass "Port $port is available"
    else
        warn "Port $port may already be in use — check with: ss -tlnp | grep $port"
    fi
done

# ── Remind about DNS setup ───────────────────────────────────────────
echo
echo "────────────────────────────────────────────────────────────────"
echo "DNS setup required — services are accessed via *.local domains:"
echo "  homepage.local  →  arcane.local  →  n8n.local"
echo
echo "Option A (Pi-hole / AdGuard Home):"
echo "  Add wildcard CNAME: *.local → your-server-ip"
echo
echo "Option B (/etc/hosts):"
echo "  echo 'YOUR_SERVER_IP  homepage.local arcane.local n8n.local' | sudo tee -a /etc/hosts"
echo "────────────────────────────────────────────────────────────────"

# ── Summary ──────────────────────────────────────────────────────────
echo
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}$ERRORS error(s)${NC}, ${YELLOW}$WARNINGS warning(s)${NC} — fix errors before deploying"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${GREEN}All checks passed${NC} with ${YELLOW}$WARNINGS warning(s)${NC}"
    echo "Run: docker compose up -d"
    exit 0
else
    echo -e "${GREEN}All checks passed — ready to deploy${NC}"
    echo "Run: docker compose up -d"
    exit 0
fi
