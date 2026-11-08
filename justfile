set shell := ["bash", "-uc"]

default_build_dir := env("BUILD_DIR", "/tmp/espforgedemo")
default_target := "riscv32imc-unknown-none-elf"

default:
    @just --list

# Regenerate root README.md locally
readme:
    @echo "==> [readme] Regenerating root README.md..."
    ./scripts/generate-readme.sh

# Generate standalone crates into espforge-examples-generated/
generate example="":
    @echo "==> [generate] Generating standalone crates..."
    ./scripts/generate.sh {{ example }}

# Build Wokwi simulation firmware and assets locally (also refreshes README.md)
build example="" build_dir=default_build_dir:
    @echo "==> [build-wokwi] Building Wokwi artifacts using cache at {{ build_dir }}..."
    ./scripts/build-wokwi.sh {{ example }} {{ build_dir }}

# Run cargo check across all generated crates
check target=default_target:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "==> [check] Verifying crates targeting {{ target }}..."
    for dir in espforge-examples-generated/*/ ; do
        if [ -f "${dir}Cargo.toml" ]; then
            echo -n "  • $(basename "$dir")... "
            (cd "$dir" && cargo check --target {{ target }} >/dev/null 2>&1)
            echo "✓"
        fi
    done
    echo "==> All checked crates compiled successfully!"

# Full pipeline: generate crates, check compilation, build Wokwi assets, and refresh README
all: generate check build

# Clean the local build cache directory
clean build_dir=default_build_dir:
    @echo "==> [clean] Removing {{ build_dir }}..."
    rm -rf "{{ build_dir }}"

# Publish a single chip to ../espforge-wokwi, re-tag, rebuild firmware, and update README
publish-chip example:
    @chmod +x scripts/publish-chip.sh scripts/build-wokwi.sh
    @echo "==> [1/2] Publishing chip to ../espforge-wokwi..."
    ./scripts/publish-chip.sh {{ example }}
    @echo "==> [2/2] Rebuilding simulation firmware & refreshing README..."
    ./scripts/build-wokwi.sh {{ example }}

# Publish all chip examples to ../espforge-wokwi, re-tag all, rebuild firmware, and update README
publish-chips:
    #!/usr/bin/env bash
    set -euo pipefail
    chmod +x scripts/publish-chip.sh scripts/build-wokwi.sh
    echo "==> [1/2] Publishing all chips to ../espforge-wokwi..."
    FOUND=0
    for dir in espforge-examples-generated/*/ ; do
        [ -d "$dir" ] || continue
        [ -f "${dir}chip.json" ] && [ -f "${dir}chip.wasm" ] || continue
        example="$(basename "$dir")"
        echo "  • Publishing $example..."
        ./scripts/publish-chip.sh "$example"
        FOUND=$((FOUND + 1))
    done

    if [ "$FOUND" -eq 0 ]; then
        echo "❌ No chip examples found in espforge-examples-generated/" >&2
        exit 1
    fi

    echo "==> [2/2] Rebuilding all simulation firmware & refreshing README..."
    ./scripts/build-wokwi.sh
