#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WOKWI_DIR="$ROOT_DIR/wokwi"
ESPFORGE_BIN="${ESPFORGE_BIN:-espforge}"

# 1. Parse arguments: [example_name] [build_dir]
EXAMPLE_ARG="${1:-}"
BUILD_DIR="${2:-${BUILD_DIR:-/tmp/espforgedemo}}"

if [ "$EXAMPLE_ARG" = "-h" ] || [ "$EXAMPLE_ARG" = "--help" ]; then
    echo "Usage: $0 [example_name] [build_dir]"
    echo ""
    echo "Examples:"
    echo "  $0                  # Build all examples into /tmp/espforgedemo"
    echo "  $0 blink            # Build single example into /tmp/espforgedemo"
    echo "  $0 blink /tmp/test  # Build single example into custom directory"
    exit 0
fi

# Safety check on BUILD_DIR before cleaning
if [ -z "$BUILD_DIR" ] || [ "$BUILD_DIR" = "/" ] || [ "$BUILD_DIR" = "$ROOT_DIR" ]; then
    echo "❌ Error: Unsafe BUILD_DIR '$BUILD_DIR'." >&2
    exit 1
fi

# 2. Check prerequisites
if ! command -v "$ESPFORGE_BIN" >/dev/null 2>&1; then
    echo "❌ Error: '$ESPFORGE_BIN' not found on PATH." >&2
    exit 1
fi

if ! command -v espflash >/dev/null 2>&1 && ! command -v cargo-espflash >/dev/null 2>&1; then
    echo "❌ Error: 'espflash' is required to generate firmware.bin." >&2
    echo "   Install via: cargo install espflash --locked" >&2
    exit 1
fi

# 3. Determine list of examples to build
if [ -n "$EXAMPLE_ARG" ]; then
    EXAMPLES=("$EXAMPLE_ARG")
    echo "==> Target: single example '$EXAMPLE_ARG'"
else
    EXAMPLES=($("$ESPFORGE_BIN" examples --list))
    echo "==> Discovered ${#EXAMPLES[@]} examples from espforge"
fi

echo "==> Build cache directory: $BUILD_DIR"
echo "==> Destination directory: $WOKWI_DIR"

mkdir -p "$BUILD_DIR" "$WOKWI_DIR"

START_TOTAL=$(date +%s)
FAILED=0
SUCCESS=0

# Helper to invoke espflash.
# NOTE: `cargo espflash save-image` (cargo-espflash) accepts no input ELF positional --
# it builds the crate itself -- so it must run from the generated project directory.
save_firmware_image() {
    local elf="$1"
    local bin="$2"
    if command -v espflash >/dev/null 2>&1; then
        espflash save-image --chip esp32c3 --merge "$elf" "$bin"
    else
        ( cd "$BUILD_DIR" && cargo espflash save-image --chip esp32c3 --merge --release "$bin" )
    fi
}

# 4. Build and capture firmware
for example in "${EXAMPLES[@]}"; do
    EX_START=$(date +%s)
    echo -n "  • [$example] "
    DEST="$WOKWI_DIR/$example"

    # KEY TRICK: Delete previous crate files in BUILD_DIR while keeping target/ intact!
    # This preserves all compiled dependencies across different examples.
    find "$BUILD_DIR" -mindepth 1 -maxdepth 1 ! -name 'target' -exec rm -rf {} +

    # Generate the project directly into the reused build directory
    if ! GEN_LOG=$("$ESPFORGE_BIN" gen --example "$example" --out "$BUILD_DIR" 2>&1); then
        echo "✗ Generation failed"
        echo "$GEN_LOG" | sed 's/^/      /'
        FAILED=$((FAILED + 1))
        continue
    fi

    # Compile using the shared target cache
    if ! BUILD_LOG=$(cd "$BUILD_DIR" && cargo build --release 2>&1); then
        echo "✗ Compilation failed"
        echo "$BUILD_LOG" | sed 's/^/      /'
        FAILED=$((FAILED + 1))
        continue
    fi

    # Find the compiled ELF
    CRATE_NAME=$(grep -m1 '^name =' "$BUILD_DIR/Cargo.toml" | sed -E 's/name = "([^"]+)"/\1/')
    ELF_PATH="$BUILD_DIR/target/riscv32imc-unknown-none-elf/release/$CRATE_NAME"

    if [ ! -f "$ELF_PATH" ]; then
        echo "✗ ELF binary not found at $ELF_PATH"
        FAILED=$((FAILED + 1))
        continue
    fi

    # Capture Wokwi artifacts
    mkdir -p "$DEST"
    if ! SAVE_LOG=$(save_firmware_image "$ELF_PATH" "$DEST/firmware.bin" 2>&1); then
        echo "✗ save-image failed"
        echo "$SAVE_LOG" | sed 's/^/      /'
        FAILED=$((FAILED + 1))
        continue
    fi

    [ -f "$BUILD_DIR/diagram.json" ] && cp -f "$BUILD_DIR/diagram.json" "$DEST/diagram.json"
    [ -f "$BUILD_DIR/wokwi.toml" ]   && cp -f "$BUILD_DIR/wokwi.toml"   "$DEST/wokwi.toml"
    [ -f "$BUILD_DIR/chip.json" ]    && cp -f "$BUILD_DIR/chip.json"    "$DEST/chip.json"
    [ -f "$BUILD_DIR/chip.wasm" ]    && cp -f "$BUILD_DIR/chip.wasm"    "$DEST/chip.wasm"

    EX_ELAPSED=$(( $(date +%s) - EX_START ))
    echo "✓ firmware.bin captured (${EX_ELAPSED}s)"
    SUCCESS=$((SUCCESS + 1))
done

TOTAL_ELAPSED=$(( $(date +%s) - START_TOTAL ))
echo "==> Finished in ${TOTAL_ELAPSED}s ($SUCCESS succeeded, $FAILED failed)"

if [ "$FAILED" -gt 0 ]; then
    exit 1
fi

# 5. Automatically refresh the root README.md with the latest viewer links
"$ROOT_DIR/scripts/generate-readme.sh"
