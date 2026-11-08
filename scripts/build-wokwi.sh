#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WOKWI_DIR="$ROOT_DIR/wokwi"
ESPFORGE_BIN="${ESPFORGE_BIN:-espforge}"
export GITHUB_REPO="${GITHUB_REPO:-mohankumargupta/espforge-extras}"
CHIP_HELPER="$ROOT_DIR/scripts/chip-version.sh"

# 1. Parse arguments: [example_name] [build_dir]
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

# The pin must be a tag that exists on origin; stale local tags would pin an old chip.
if [ "${CHIP_OFFLINE:-0}" != "1" ]; then
    "$CHIP_HELPER" fetch 2>/dev/null || echo "  ! could not fetch tags; chip pins may be stale" >&2
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

inject_chip_dependency() {
    local diagram_file="$1" repo="$2" tag="$3" key="$4"

    python3 - "$diagram_file" "$repo" "$tag" "$key" <<'PY'
import json, sys
path, repo, tag, key = sys.argv[1:5]
with open(path, encoding="utf-8") as f:
    diagram = json.load(f)
deps = diagram.get("dependencies")
if not isinstance(deps, dict):
    deps = {}
deps[key] = f"github:{repo}@{tag}"
diagram["dependencies"] = deps
with open(path, "w", encoding="utf-8") as f:
    json.dump(diagram, f, indent=2)
    f.write("\n")
PY
}

START_TOTAL=$(date +%s)
FAILED=0
SUCCESS=0

for example in "${EXAMPLES[@]}"; do
    EX_START=$(date +%s)
    echo -n "  • [$example] "
    DEST="$WOKWI_DIR/$example"

    # Resolve the chip pin before the build output replaces the checked-in diagram.
    CHIP_TAG="$("$CHIP_HELPER" latest-tag "$example" || true)"

    # Preserve build cache
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

    # Viewer payload only: diagram.json + firmware.bin.
    # chip.json / chip.wasm / wokwi.toml stay in espforge-examples-generated/<example>/.
    if [ ! -f "$BUILD_DIR/diagram.json" ]; then
        echo "✗ diagram.json missing from build output"
        FAILED=$((FAILED + 1))
        continue
    fi
    cp -f "$BUILD_DIR/diagram.json" "$DEST/diagram.json"

    if [ -f "$BUILD_DIR/chip.json" ] && [ -f "$BUILD_DIR/chip.wasm" ]; then
        if [ -n "$CHIP_TAG" ]; then
            CHIP_KEY="$("$CHIP_HELPER" name "$example")"
            inject_chip_dependency "$DEST/diagram.json" "$GITHUB_REPO" "$CHIP_TAG" "$CHIP_KEY"
            echo "    ↳ chip pinned to $CHIP_TAG"
        else
            echo "    ↳ chip example, never released: dependencies left empty"
            echo "      run 'just release-chip $example' to publish 0.0.1, then rebuild"
        fi
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

# Update README.md with the simulation links
"$ROOT_DIR/scripts/generate-readme.sh"
