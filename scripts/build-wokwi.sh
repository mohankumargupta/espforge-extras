#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WOKWI_DIR="$ROOT_DIR/wokwi"
ESPFORGE_BIN="${ESPFORGE_BIN:-espforge}"
WOKWI_CHIP_REPO="${WOKWI_CHIP_REPO:-mohankumargupta/espforge-wokwi}"

# Parse arguments: [example_name] [build_dir]
EXAMPLE_ARG="${1:-}"
BUILD_DIR="${2:-${BUILD_DIR:-/tmp/espforgedemo}}"

if [ "$EXAMPLE_ARG" = "-h" ] || [ "$EXAMPLE_ARG" = "--help" ]; then
    echo "Usage: $0 [example_name] [build_dir]"
    exit 0
fi

if [ -z "$BUILD_DIR" ] || [ "$BUILD_DIR" = "/" ] || [ "$BUILD_DIR" = "$ROOT_DIR" ]; then
    echo "❌ Error: Unsafe BUILD_DIR '$BUILD_DIR'." >&2
    exit 1
fi

if ! command -v "$ESPFORGE_BIN" >/dev/null 2>&1; then
    echo "❌ Error: '$ESPFORGE_BIN' not found on PATH." >&2
    exit 1
fi

if ! command -v espflash >/dev/null 2>&1 && ! command -v cargo-espflash >/dev/null 2>&1; then
    echo "❌ Error: 'espflash' is required to generate firmware.bin." >&2
    exit 1
fi

if [ -n "$EXAMPLE_ARG" ]; then
    EXAMPLES=("$EXAMPLE_ARG")
else
    EXAMPLES=($("$ESPFORGE_BIN" examples --list))
fi

mkdir -p "$BUILD_DIR" "$WOKWI_DIR"

save_firmware_image() {
    local elf="$1"
    local bin="$2"
    if command -v espflash >/dev/null 2>&1; then
        espflash save-image --chip esp32c3 --merge "$elf" "$bin"
    else
        ( cd "$BUILD_DIR" && cargo espflash save-image --chip esp32c3 --merge --release "$bin" )
    fi
}

copy_and_rename_chip_json() {
    local src="$1"
    local dest="$2"
    local chip_name="$3"

    python3 - "$src" "$dest" "$chip_name" <<'PY'
import json, sys
src, dest, chip_name = sys.argv[1:4]
with open(src, encoding="utf-8") as f:
    data = json.load(f)
data["name"] = chip_name
with open(dest, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
}

inject_chip_dependency() {
    local diagram_file="$1"
    local repo="$2"
    local version="$3"
    local chip_name="$4"

    python3 - "$diagram_file" "$repo" "$version" "$chip_name" <<'PY'
import json, sys
path, repo, version, chip_name = sys.argv[1:5]
with open(path, encoding="utf-8") as f:
    diagram = json.load(f)

chip_key = f"chip-{chip_name}"

for part in diagram.get("parts", []):
    kind = part.get("type", "")
    if kind.startswith("chip-"):
        part["type"] = chip_key

deps = diagram.get("dependencies")
if not isinstance(deps, dict):
    deps = {}
deps.pop("chip-chip", None)
deps[chip_key] = f"github:{repo}@{version}"
diagram["dependencies"] = deps

with open(path, "w", encoding="utf-8") as f:
    json.dump(diagram, f, indent=2)
    f.write("\n")
print(f"    ↳ chip pinned: {chip_key} -> github:{repo}@{version}")
PY
}

example_to_clean_version() {
    case "$1" in
        i2c_example)        echo "0.0.1" ;;
        i2c_example_async)  echo "0.0.2" ;;
        i2c_scanner)        echo "0.0.3" ;;
        spi_example)        echo "0.0.4" ;;
        spi_example_async)  echo "0.0.5" ;;
        uart_example)       echo "0.0.6" ;;
        uart_example_async) echo "0.0.7" ;;
        *)                  echo "0.0.99" ;;
    esac
}

START_TOTAL=$(date +%s)
FAILED=0
SUCCESS=0

for example in "${EXAMPLES[@]}"; do
    EX_START=$(date +%s)
    echo -n "  • [$example] "
    DEST="$WOKWI_DIR/$example"

    # Preserve build cache (target/) across iterations
    find "$BUILD_DIR" -mindepth 1 -maxdepth 1 ! -name 'target' -exec rm -rf {} +

    if ! "$ESPFORGE_BIN" gen --example "$example" --out "$BUILD_DIR" >"$BUILD_DIR/.gen.log" 2>&1; then
        echo "✗ Generation failed"
        sed 's/^/      /' "$BUILD_DIR/.gen.log" | tail -n 20
        FAILED=$((FAILED + 1))
        continue
    fi

    if ! (cd "$BUILD_DIR" && cargo build --release >"$BUILD_DIR/.cargo.log" 2>&1); then
        echo "✗ Compilation failed"
        sed 's/^/      /' "$BUILD_DIR/.cargo.log" | tail -n 20
        FAILED=$((FAILED + 1))
        continue
    fi

    CRATE_NAME=$(grep -m1 '^name =' "$BUILD_DIR/Cargo.toml" | sed -E 's/name = "([^"]+)"/\1/')
    ELF_PATH="$BUILD_DIR/target/riscv32imc-unknown-none-elf/release/$CRATE_NAME"

    if [ ! -f "$ELF_PATH" ]; then
        echo "✗ ELF not found at $ELF_PATH"
        FAILED=$((FAILED + 1))
        continue
    fi

    rm -rf "$DEST"
    mkdir -p "$DEST"

    if ! save_firmware_image "$ELF_PATH" "$DEST/firmware.bin" >"$BUILD_DIR/.save.log" 2>&1; then
        echo "✗ save-image failed"
        sed 's/^/      /' "$BUILD_DIR/.save.log" | tail -n 20
        FAILED=$((FAILED + 1))
        continue
    fi

    if [ ! -f "$BUILD_DIR/diagram.json" ]; then
        echo "✗ diagram.json missing from build output"
        FAILED=$((FAILED + 1))
        continue
    fi
    cp -f "$BUILD_DIR/diagram.json" "$DEST/diagram.json"

    # Copy & rename chip.json, and inject Wokwi chip dependency pointing to espforge-wokwi@X.Y.Z
    if [ -f "$BUILD_DIR/chip.json" ] && [ -f "$BUILD_DIR/chip.wasm" ]; then
        CHIP_NAME="${example//_/}"
        copy_and_rename_chip_json "$BUILD_DIR/chip.json" "$DEST/chip.json" "$CHIP_NAME"
        CLEAN_VER="$(example_to_clean_version "$example")"
        inject_chip_dependency "$DEST/diagram.json" "$WOKWI_CHIP_REPO" "$CLEAN_VER" "$CHIP_NAME"
    fi

    EX_ELAPSED=$(( $(date +%s) - EX_START ))
    echo "✓ firmware captured (${EX_ELAPSED}s)"
    SUCCESS=$((SUCCESS + 1))
done

TOTAL_ELAPSED=$(( $(date +%s) - START_TOTAL ))
echo "==> Finished in ${TOTAL_ELAPSED}s ($SUCCESS succeeded, $FAILED failed)"

if [ "$FAILED" -gt 0 ]; then
    echo "❌ $FAILED example(s) failed; README not regenerated" >&2
    exit 1
fi

"$ROOT_DIR/scripts/generate-readme.sh"
