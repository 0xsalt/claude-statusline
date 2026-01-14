#!/bin/bash
# Verification script for arcana-statusline pack
# Run: bash verify.sh

set -e

CLAUDE_DIR="${PAI_DIR:-$HOME/.claude}"
if [[ ! "$CLAUDE_DIR" == *".claude" ]]; then
    CLAUDE_DIR="$CLAUDE_DIR/.claude"
fi

echo "=== Arcana Statusline Verification ==="
echo ""

PASS=0
FAIL=0

check_file() {
    if [ -f "$1" ]; then
        echo "✓ $2"
        ((PASS++))
    else
        echo "✗ $2 - NOT FOUND: $1"
        ((FAIL++))
    fi
}

echo "Checking installed files..."
check_file "$CLAUDE_DIR/statusline-command.sh" "Statusline script"
check_file "$CLAUDE_DIR/lib/usage-fetcher.ts" "Usage fetcher"

echo ""
echo "Checking script is executable..."
if [ -x "$CLAUDE_DIR/statusline-command.sh" ]; then
    echo "✓ Statusline script is executable"
    ((PASS++))
else
    echo "✗ Statusline script is not executable"
    ((FAIL++))
fi

echo ""
echo "Testing statusline syntax..."
if bash -n "$CLAUDE_DIR/statusline-command.sh" 2>/dev/null; then
    echo "✓ Statusline has valid syntax"
    ((PASS++))
else
    echo "✗ Statusline has syntax errors"
    ((FAIL++))
fi

echo ""
echo "Testing statusline execution..."
if echo '{}' | bash "$CLAUDE_DIR/statusline-command.sh" >/dev/null 2>&1; then
    echo "✓ Statusline executes without error"
    ((PASS++))
else
    echo "✗ Statusline execution failed"
    ((FAIL++))
fi

echo ""
echo "Testing usage fetcher..."
if bun run "$CLAUDE_DIR/lib/usage-fetcher.ts" 2>/dev/null | grep -q "five_hour_pct\|error"; then
    echo "✓ Usage fetcher returns valid response"
    ((PASS++))
else
    echo "✗ Usage fetcher failed"
    ((FAIL++))
fi

echo ""
echo "Checking settings.json configuration..."
if jq -e '.statusLine' "$CLAUDE_DIR/settings.json" >/dev/null 2>&1; then
    echo "✓ statusLine configured in settings.json"
    ((PASS++))
else
    echo "✗ statusLine not configured in settings.json"
    ((FAIL++))
fi

echo ""
echo "=== Results ==="
echo "Passed: $PASS"
echo "Failed: $FAIL"
echo ""

if [ $FAIL -eq 0 ]; then
    echo "✓ All checks passed!"
    exit 0
else
    echo "✗ Some checks failed"
    exit 1
fi
