set shell := ["bash", "-uc"]

default_build_dir := env("BUILD_DIR", "/tmp/espforgedemo")
default_target := "riscv32imc-unknown-none-elf"

# List available recipes
default:
    @just --list

# Generate standalone crates into espforge-examples-generated/ (all or specific example)
generate example="":
    @echo "==> [generate] Generating standalone crates..."
    ./scripts/generate.sh {{ example }}

# Build Wokwi simulation firmware and assets locally (reusing build cache)
build example="" build_dir=default_build_dir:
    @echo "==> [build-wokwi] Building Wokwi artifacts using cache at {{ build_dir }}..."
    ./scripts/build-wokwi.sh {{ example }} {{ build_dir }}

# Regenerate root README.md with direct source code and Wokwi simulation links
readme:
    @echo "==> [readme] Regenerating root README.md..."
    ./scripts/generate-readme.sh

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

# Clean the local /tmp build cache directory
clean build_dir=default_build_dir:
    @echo "==> [clean] Removing {{ build_dir }}..."
    rm -rf "{{ build_dir }}"
