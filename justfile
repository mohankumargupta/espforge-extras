# Publish chip assets (chip.json & chip.wasm) to ../espforge-wokwi, tagged by example name
publish-chip example:
    @chmod +x scripts/publish-chip.sh
    ./scripts/publish-chip.sh {{ example }}

# Publish all chip examples to ../espforge-wokwi
publish-chips:
    #!/usr/bin/env bash
    set -euo pipefail
    chmod +x scripts/publish-chip.sh
    for dir in espforge-examples-generated/*/ ; do
        [ -d "$dir" ] || continue
        [ -f "${dir}chip.json" ] && [ -f "${dir}chip.wasm" ] || continue
        example="$(basename "$dir")"
        ./scripts/publish-chip.sh "$example"
    done
