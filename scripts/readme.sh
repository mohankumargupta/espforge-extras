#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXAMPLES_DIR="$ROOT_DIR/espforge-examples-generated"
WOKWI_DIR="$ROOT_DIR/wokwi"
README_OUT="$ROOT_DIR/README.md"
REPO_RAW_BASE="https://raw.githubusercontent.com/mohankumargupta/espforge-extras/refs/heads/main"

echo "==> Generating root README.md..."

cat <<'EOF' > "$README_OUT"
# espforge-extras

Companion repository providing pre-generated `no_std` Rust projects and interactive browser simulations for [`espforge`](https://github.com/mohankumargupta/espforge).

## Examples & Live Simulations

| Example | Generated Source Code | Wokwi Simulation |
|---|---|---|
EOF

# Dynamically iterate over whatever directories exist in espforge-examples-generated/
for dir in "$EXAMPLES_DIR"/*/ ; do
    [ -d "$dir" ] || continue
    example="$(basename "$dir")"

    # Source code relative link
    SOURCE_LINK="[\`$example\`](./espforge-examples-generated/$example)"

    # Simulation link: only generated if both diagram.json and firmware.bin exist
    if [ -f "$WOKWI_DIR/$example/firmware.bin" ] && [ -f "$WOKWI_DIR/$example/diagram.json" ]; then
        RAW_DIAGRAM="${REPO_RAW_BASE}/wokwi/${example}/diagram.json"
        RAW_FIRMWARE="${REPO_RAW_BASE}/wokwi/${example}/firmware.bin"

        ENC_DIAGRAM=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$RAW_DIAGRAM")
        ENC_FIRMWARE=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$RAW_FIRMWARE")

        SIM_LINK="[▶️ Run in Wokwi](https://wokwi.com/experimental/viewer?diagram=${ENC_DIAGRAM}&firmware=${ENC_FIRMWARE})"
    else
        SIM_LINK="—"
    fi

    echo "| \`$example\` | $SOURCE_LINK | $SIM_LINK |" >> "$README_OUT"
done

cat <<'EOF' >> "$README_OUT"

