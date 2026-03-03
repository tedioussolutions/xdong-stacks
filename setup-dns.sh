#!/usr/bin/env bash
# Setup /etc/hosts entries for an xdong-stacks stack.
# Parses the Caddyfile to discover all subdomain blocks automatically.
#
# Usage:
#   sudo bash setup-dns.sh <stack-dir> [ip]
#
# Examples:
#   sudo bash setup-dns.sh worklab              # defaults to 127.0.0.1
#   sudo bash setup-dns.sh worklab 192.168.1.50
#   sudo bash setup-dns.sh local-homelab 10.0.0.5
#   bash setup-dns.sh worklab --dry-run         # preview without changes
set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

usage() {
    echo "Usage: sudo bash $0 <stack-dir> [ip] [--dry-run]"
    echo
    echo "  stack-dir  Stack directory name (e.g., worklab, local-homelab)"
    echo "  ip         Target IP address (default: 127.0.0.1)"
    echo "  --dry-run  Preview changes without modifying /etc/hosts"
    exit 1
}

# ── Parse arguments ─────────────────────────────────────────────────
STACK_DIR=""
TARGET_IP="127.0.0.1"
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --help|-h) usage ;;
        *)
            if [ -z "$STACK_DIR" ]; then
                STACK_DIR="$arg"
            else
                TARGET_IP="$arg"
            fi
            ;;
    esac
done

[ -z "$STACK_DIR" ] && usage

# ── Locate Caddyfile ────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$(realpath "$0")")" && pwd)"
CADDYFILE="${SCRIPT_DIR}/${STACK_DIR}/Caddyfile"

if [ ! -f "$CADDYFILE" ]; then
    echo -e "${RED}Error:${NC} Caddyfile not found at $CADDYFILE"
    exit 1
fi

# ── Extract domains from Caddyfile ──────────────────────────────────
# Matches lines like "home.work.lab {" — domain blocks at the start of a line
DOMAINS=$(grep -oP '^\S+(?=\s*\{)' "$CADDYFILE" | grep '\.' | sort)

if [ -z "$DOMAINS" ]; then
    echo -e "${RED}Error:${NC} No domain blocks found in $CADDYFILE"
    exit 1
fi

DOMAIN_COUNT=$(echo "$DOMAINS" | wc -l)
DOMAIN_LINE=$(echo $DOMAINS)  # flatten to single line

echo "Stack:   ${STACK_DIR}"
echo "IP:      ${TARGET_IP}"
echo "Domains: ${DOMAIN_COUNT} found"
echo

# ── Build hosts entry ───────────────────────────────────────────────
MARKER="# xdong-stacks/${STACK_DIR}"
HOSTS_LINE="${TARGET_IP}  ${DOMAIN_LINE}  ${MARKER}"

echo "Hosts entry:"
echo -e "  ${GREEN}${HOSTS_LINE}${NC}"
echo

# ── Check for existing entries ──────────────────────────────────────
if grep -qF "$MARKER" /etc/hosts 2>/dev/null; then
    EXISTING=$(grep -F "$MARKER" /etc/hosts)
    echo -e "${YELLOW}Existing entry found:${NC}"
    echo "  $EXISTING"
    echo

    if [ "$EXISTING" = "$HOSTS_LINE" ]; then
        echo -e "${GREEN}Already up to date — no changes needed.${NC}"
        exit 0
    fi

    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} Would replace existing entry"
        exit 0
    fi

    # Remove old entry and add new one
    grep -vF "$MARKER" /etc/hosts > /tmp/hosts.tmp
    echo "$HOSTS_LINE" >> /tmp/hosts.tmp
    mv /tmp/hosts.tmp /etc/hosts
    echo -e "${GREEN}Updated /etc/hosts${NC} (replaced old entry)"
else
    if $DRY_RUN; then
        echo -e "${YELLOW}[dry-run]${NC} Would append to /etc/hosts"
        exit 0
    fi

    if [ "$(id -u)" -ne 0 ]; then
        echo -e "${RED}Error:${NC} Must run as root to modify /etc/hosts"
        echo "  sudo bash $0 $*"
        exit 1
    fi

    echo "$HOSTS_LINE" >> /etc/hosts
    echo -e "${GREEN}Added to /etc/hosts${NC}"
fi

# ── Verify ──────────────────────────────────────────────────────────
echo
echo "Verify:"
FIRST_DOMAIN=$(echo "$DOMAINS" | head -1)
echo "  ping -c1 ${FIRST_DOMAIN}"
echo "  curl -s -o /dev/null -w '%{http_code}' http://${FIRST_DOMAIN}"
