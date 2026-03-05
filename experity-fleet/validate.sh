#!/usr/bin/env bash
# Validate Experity fleet stack configuration before deploying
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

pass()  { echo -e "${GREEN}✓${NC} $1"; }
warn()  { echo -e "${YELLOW}⚠${NC} $1"; ((WARNINGS++)); }
fail()  { echo -e "${RED}✗${NC} $1"; ((ERRORS++)); }

echo "Validating Experity fleet monitoring stack..."
echo

# ── Check .env exists ────────────────────────────────────────────
if [ -f .env ]; then
    pass ".env file exists"
    # Check for placeholder passwords
    if grep -q 'changeme' .env 2>/dev/null; then
        warn ".env still has 'changeme' placeholder passwords — update before production use"
    fi
else
    fail ".env file missing — run: cp .env.example .env"
fi

# ── Check Docker ─────────────────────────────────────────────────
if command -v docker &>/dev/null; then
    pass "Docker is installed ($(docker --version | grep -oP '\d+\.\d+\.\d+'))"
else
    fail "Docker is not installed"
fi

if docker compose version &>/dev/null; then
    pass "Docker Compose v2 available"
else
    fail "Docker Compose v2 not available"
fi

# ── Validate compose syntax ──────────────────────────────────────
if docker compose config --quiet 2>/dev/null; then
    pass "docker-compose.yml syntax valid"
else
    fail "docker-compose.yml has syntax errors — run: docker compose config"
fi

# ── Check config files exist ─────────────────────────────────────
for f in \
    smokeping/Targets \
    prometheus/prometheus.yml \
    prometheus/alerts/windows-fleet-alert-rules.yml \
    prometheus/file_sd/windows-fleet.json \
    grafana/provisioning/datasources/prometheus-datasource.yml \
    grafana/provisioning/dashboards/dashboard-provisioning-config.yml; do
    if [ -f "$f" ]; then
        pass "$f exists"
    else
        fail "$f missing"
    fi
done

# ── Validate JSON ────────────────────────────────────────────────
if command -v python3 &>/dev/null; then
    if python3 -m json.tool prometheus/file_sd/windows-fleet.json >/dev/null 2>&1; then
        pass "windows-fleet.json is valid JSON"
    else
        fail "windows-fleet.json is invalid JSON"
    fi
fi

# ── Check ports available ────────────────────────────────────────
for port in 8080 8000 9090 3000; do
    if ! ss -tlnp 2>/dev/null | grep -q ":${port} " && \
       ! lsof -i ":${port}" &>/dev/null 2>&1; then
        pass "Port $port is available"
    else
        warn "Port $port may be in use — check with: ss -tlnp | grep $port"
    fi
done

# ── Summary ──────────────────────────────────────────────────────
echo
if [ "$ERRORS" -gt 0 ]; then
    echo -e "${RED}$ERRORS error(s)${NC}, ${YELLOW}$WARNINGS warning(s)${NC} — fix errors before deploying"
    exit 1
elif [ "$WARNINGS" -gt 0 ]; then
    echo -e "${GREEN}All checks passed${NC} with ${YELLOW}$WARNINGS warning(s)${NC}"
    exit 0
else
    echo -e "${GREEN}All checks passed — ready to deploy${NC}"
    echo "Run: docker compose up -d"
    exit 0
fi
