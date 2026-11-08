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

# Build Wokwi simulation firmware and assets locally
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
all: generate check build readme

# Clean the local build cache directory
clean build_dir=default_build_dir:
    @echo "==> [clean] Removing {{ build_dir }}..."
    rm -rf "{{ build_dir }}"

# Dispatch GitHub Action to release chip, increment version.txt, pin diagram, and update root README.md
release-chip example:
    @echo "==> Current version: $(./scripts/chip-version.sh current)"
    @echo "==> Next universal tag will be: $(./scripts/chip-version.sh next)"
    gh workflow run "Release Wokwi Custom Chip" -f example="{{ example }}"
    @echo "✓ Triggered. Monitor with: gh run list --workflow='Release Wokwi Custom Chip'"

# Dispatch releases for all chip examples sequentially
release-chips:
    #!/usr/bin/env bash
    set -euo pipefail
    ./scripts/chip-version.sh fetch
    echo "==> Releasing all chip examples..."
    FOUND=0
    for dir in espforge-examples-generated/*/ ; do
        [ -d "$dir" ] || continue
        [ -f "${dir}chip.json" ] && [ -f "${dir}chip.wasm" ] || continue
        example="$(basename "$dir")"
        echo "  • Dispatching release for $example..."
        gh workflow run "Release Wokwi Custom Chip" -f example="$example"
        FOUND=$((FOUND + 1))
        sleep 2 # slight delay between dispatches
    done
    if [ "$FOUND" -eq 0 ]; then
        echo "❌ no chip examples found in espforge-examples-generated/" >&2
        exit 1
    fi
    echo "==> Triggered $FOUND release(s). GitHub Actions will update version.txt and README.md."
