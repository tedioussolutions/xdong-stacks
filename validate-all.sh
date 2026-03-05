#!/usr/bin/env bash
# Validate all xdong-stacks in one pass.
# Usage: ./validate-all.sh [stack1 stack2 ...]
#   No args = validate every stack with a docker-compose.yml.
set -euo pipefail
cd "$(dirname "$0")"

PASS=0; FAIL=0; SKIP=0
FAILED_STACKS=()

# Collect stacks: args or auto-detect
if [ $# -gt 0 ]; then
  STACKS=("$@")
else
  STACKS=()
  for d in */; do
    [ -f "${d}docker-compose.yml" ] && STACKS+=("${d%/}")
  done
fi

echo "Validating ${#STACKS[@]} stacks..."
echo "─────────────────────────────────"

for stack in "${STACKS[@]}"; do
  if [ ! -f "$stack/docker-compose.yml" ]; then
    echo "SKIP  $stack (no docker-compose.yml)"
    SKIP=$((SKIP + 1))
    continue
  fi

  # Compose syntax check
  if docker compose -f "$stack/docker-compose.yml" config --quiet 2>/dev/null; then
    echo "OK    $stack"
    PASS=$((PASS + 1))
  else
    echo "FAIL  $stack"
    FAIL=$((FAIL + 1))
    FAILED_STACKS+=("$stack")
  fi
done

echo "─────────────────────────────────"
echo "Results: $PASS passed, $FAIL failed, $SKIP skipped (${#STACKS[@]} total)"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed stacks: ${FAILED_STACKS[*]}"
  exit 1
fi
echo "All stacks valid."
