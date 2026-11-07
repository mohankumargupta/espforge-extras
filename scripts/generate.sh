#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_BASE="$ROOT_DIR/espforge-examples-generated"
ESPFORGE_BIN="${ESPFORGE_BIN:-espforge}"

if ! command -v "$ESPFORGE_BIN" >/dev/null 2>&1; then
    echo "❌ Error: '$ESPFORGE_BIN' not found on PATH or via ESPFORGE_BIN." >&2
    exit 1
fi

echo "==> Using $("$ESPFORGE_BIN" --version) ($(command -v "$ESPFORGE_BIN"))"
echo "==> Target directory: $TARGET_BASE"

mkdir -p "$TARGET_BASE"
START_TIME=$(date +%s)
FAILED=0

# Helper to generate the minimal per-example README.md
generate_example_readme() {
    local ex_dir="$1"
    local ex_name="$2"
    local spec_file="$ex_dir/.espforge/source.espf.txt"
    local app_file="$ex_dir/src/app.rs"
    local readme_file="$ex_dir/README.md"

    {
        cat <<EOF
# $ex_name

This example was generated from these source files.

## \`.espf.txt\`

\`\`\`xml
EOF
        if [ -f "$spec_file" ]; then
            cat "$spec_file"
        fi
        cat <<EOF

\`\`\`

## \`src/app.rs\`

\`\`\`rust
EOF
        if [ -f "$app_file" ]; then
            cat "$app_file"
        fi
        cat <<EOF

\`\`\`
EOF
    } > "$readme_file"
}

# Stream example names directly from the CLI without switches
for example in $("$ESPFORGE_BIN" examples --list); do
    echo -n "  • Generating $example... "
    OUT_DIR="$TARGET_BASE/$example"

    rm -rf "$OUT_DIR"

    if OUTPUT=$("$ESPFORGE_BIN" gen --example "$example" --out "$OUT_DIR" 2>&1); then
        generate_example_readme "$OUT_DIR" "$example"
        echo "✓"
    else
        echo "✗ FAILED"
        echo "$OUTPUT" | sed 's/^/      /'
        FAILED=$((FAILED + 1))
    fi
done

ELAPSED=$(( $(date +%s) - START_TIME ))

if [ $FAILED -gt 0 ]; then
    echo "❌ Failed to generate $FAILED example(s) in ${ELAPSED}s" >&2
    exit 1
fi

echo "==> Successfully generated examples in ${ELAPSED}s"
