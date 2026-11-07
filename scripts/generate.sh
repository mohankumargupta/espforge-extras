#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_BASE="$ROOT_DIR/espforge-examples-generated"
ESPFORGE_BIN="${ESPFORGE_BIN:-espforge}"

# 1. Verify binary availability
if ! command -v "$ESPFORGE_BIN" >/dev/null 2>&1; then
    echo "❌ Error: '$ESPFORGE_BIN' not found on PATH or via ESPFORGE_BIN." >&2
    exit 1
fi

echo "==> Binary: $(command -v "$ESPFORGE_BIN") ($("$ESPFORGE_BIN" --version))"
echo "==> Target: $TARGET_BASE"

# 2. Determine examples to generate
# Allows passing a specific example name for testing (e.g. `./scripts/generate.sh blink`)
if [ $# -ge 1 ] && [ -n "$1" ]; then
    EXAMPLES=("$1")
    echo "==> Target set to single example: '$1'"
else
    EXAMPLES=()
    # Use --list if available; fallback to table parsing for older CLI versions
    if "$ESPFORGE_BIN" examples --help 2>&1 | grep -E -q -- '--list|-l'; then
        while IFS= read -r name; do
            [[ -n "$name" ]] && EXAMPLES+=("$name")
        done < <("$ESPFORGE_BIN" examples --list)
    else
        while IFS= read -r name; do
            [[ -n "$name" ]] && EXAMPLES+=("$name")
        done < <("$ESPFORGE_BIN" examples | awk '/^  [a-zA-Z0-9_]+/ {print $1}')
    fi
    echo "==> Discovered ${#EXAMPLES[@]} examples"
fi

if [ ${#EXAMPLES[@]} -eq 0 ]; then
    echo "❌ Error: No examples discovered to generate." >&2
    exit 1
fi

mkdir -p "$TARGET_BASE"
START_TIME=$(date +%s)
FAILED=0

# 3. Generate each project
for example in "${EXAMPLES[@]}"; do
    echo -n "  • Generating $example... "
    OUT_DIR="$TARGET_BASE/$example"

    # Clean existing directory for this specific project only
    rm -rf "$OUT_DIR"

    # Capture output so errors are visible in CI/terminal logs on failure
    if OUTPUT=$("$ESPFORGE_BIN" gen --example "$example" --out "$OUT_DIR" 2>&1); then
        echo "✓"
    else
        echo "✗ FAILED"
        echo "$OUTPUT" | sed 's/^/      /'
        FAILED=$((FAILED + 1))
    fi
done

ELAPSED=$(( $(date +%s) - START_TIME ))

# 4. Summary report
if [ $FAILED -gt 0 ]; then
    echo "❌ Failed to generate $FAILED example(s) in ${ELAPSED}s" >&2
    exit 1
fi

echo "==> Successfully generated ${#EXAMPLES[@]} example(s) in ${ELAPSED}s"