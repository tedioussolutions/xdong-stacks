#!/usr/bin/env bash
# Validate worklab stack configuration before deploying
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

echo "Validating worklab stack..."
echo

# ── Check .env exists ────────────────────────────────────────────────
if [ -f .env ]; then
    pass ".env file exists"
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

# ── Check secrets are set ────────────────────────────────────────────
if [ -f .env ]; then
    check_secret() {
        local key="$1"
        local val
        val=$(grep "^${key}=" .env 2>/dev/null | cut -d= -f2-)
        if [ -z "$val" ]; then
            fail "$key is not set in .env — generate with: openssl rand -base64 32"
        else
            pass "$key is set"
        fi
    }
    check_secret MEILI_MASTER_KEY
    check_secret KARAKEEP_NEXTAUTH_SECRET
    check_secret POSTGRES_PASSWORD
    check_secret CALENDAR_NEXTAUTH_SECRET
    check_secret CODE_SERVER_PASSWORD
    check_secret CODE_SERVER_SUDO_PASSWORD
fi

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
echo "DNS setup required — services are accessed via *.work.lab domains:"
echo
echo "  home.work.lab       →  Homepage dashboard"
echo "  code.work.lab       →  Code-Server (VS Code)"
echo "  tools.work.lab      →  IT-Tools"
echo "  netdata.work.lab    →  Netdata monitoring"
echo "  pdf.work.lab        →  Stirling-PDF"
echo "  convert.work.lab    →  ConvertX"
echo "  karakeep.work.lab   →  Karakeep bookmarks"
echo "  feeds.work.lab      →  CommafFeed RSS"
echo "  calendar.work.lab   →  Fluid-Calendar"
echo
echo "Option A (Pi-hole / AdGuard Home):"
echo "  Add wildcard CNAME: *.work.lab → your-server-ip"
echo
echo "Option B (/etc/hosts):"
echo "  echo 'YOUR_IP  home.work.lab code.work.lab tools.work.lab netdata.work.lab pdf.work.lab convert.work.lab karakeep.work.lab feeds.work.lab calendar.work.lab' | sudo tee -a /etc/hosts"
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
