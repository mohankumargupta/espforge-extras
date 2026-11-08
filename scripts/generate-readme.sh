#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLES_DIR="$ROOT_DIR/espforge-examples-generated"
WOKWI_DIR="$ROOT_DIR/wokwi"
README_OUT="$ROOT_DIR/README.md"
REPO_RAW_BASE="https://raw.githubusercontent.com/mohankumargupta/espforge-extras/refs/heads/main"
WOKWI_CHIP_REPO="${WOKWI_CHIP_REPO:-mohankumargupta/espforge-wokwi}"

echo "==> Generating root README.md..."

cat <<'EOF' > "$README_OUT"
# espforge-extras

Companion repository providing pre-generated `no_std` Rust projects and interactive browser simulations for [`espforge`](https://github.com/mohankumargupta/espforge).

## Examples & Live Simulations

| Example | Generated Source Code | Wokwi Simulation | Chip |
|---|---|---|---|
EOF

for dir in "$EXAMPLES_DIR"/*/ ; do
    [ -d "$dir" ] || continue
    example="$(basename "$dir")"
    SOURCE_LINK="[\`$example\`](./espforge-examples-generated/$example)"

    IS_CHIP=0
    CHIP_READY=1
    DIAGRAM_FILE="$WOKWI_DIR/$example/diagram.json"

    if [ -f "$EXAMPLES_DIR/$example/chip.json" ] && [ -f "$EXAMPLES_DIR/$example/chip.wasm" ]; then
        IS_CHIP=1
        PINNED_TAG=""

        if [ -f "$DIAGRAM_FILE" ]; then
            PINNED_TAG=$(python3 - "$DIAGRAM_FILE" <<'PY' 2>/dev/null || true
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as f:
        diagram = json.load(f)
    for _, dep in diagram.get("dependencies", {}).items():
        if "espforge-wokwi@" in dep:
            print(dep.split("@", 1)[1])
            break
except Exception:
    pass
PY
)
        fi

        if [ -n "$PINNED_TAG" ]; then
            CHIP_CELL="[\`$PINNED_TAG\`](https://github.com/${WOKWI_CHIP_REPO}/tree/${PINNED_TAG})"
        else
            CHIP_CELL="not pinned"
            CHIP_READY=0
        fi
    else
        CHIP_CELL="—"
    fi

    if [ -f "$WOKWI_DIR/$example/firmware.bin" ] && [ -f "$DIAGRAM_FILE" ] && [ "$CHIP_READY" -eq 1 ]; then
        RAW_DIAGRAM="${REPO_RAW_BASE}/wokwi/${example}/diagram.json"
        RAW_FIRMWARE="${REPO_RAW_BASE}/wokwi/${example}/firmware.bin"

        ENC_DIAGRAM=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$RAW_DIAGRAM")
        ENC_FIRMWARE=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$RAW_FIRMWARE")

        SIM_LINK="[▶️ Run in Wokwi](https://wokwi.com/experimental/viewer?diagram=${ENC_DIAGRAM}&firmware=${ENC_FIRMWARE})"
    else
        SIM_LINK="—"
    fi

    echo "| \`$example\` | $SOURCE_LINK | $SIM_LINK | $CHIP_CELL |" >> "$README_OUT"
done

echo "==> Wrote $README_OUT"
