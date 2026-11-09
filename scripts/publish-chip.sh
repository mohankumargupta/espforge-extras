#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET_REPO_DIR="${TARGET_REPO_DIR:-$(cd "$ROOT_DIR/../espforge-wokwi" 2>/dev/null && pwd || echo "$ROOT_DIR/../espforge-wokwi")}"
WOKWI_REPO="${WOKWI_REPO:-mohankumargupta/espforge-wokwi}"

EXAMPLE="${1:-}"

if [ -z "$EXAMPLE" ]; then
    echo "Usage: $0 <example_name>" >&2
    exit 1
fi

SOURCE_DIR="$ROOT_DIR/espforge-examples-generated/$EXAMPLE"
WOKWI_EX_DIR="$ROOT_DIR/wokwi/$EXAMPLE"
CHIP_NAME="${EXAMPLE//_/}"
CHIP_KEY="chip-${CHIP_NAME}"

if [ ! -d "$SOURCE_DIR" ]; then
    echo "❌ Error: Example directory '$SOURCE_DIR' does not exist." >&2
    exit 1
fi

if [ ! -f "$SOURCE_DIR/chip.json" ] || [ ! -f "$SOURCE_DIR/chip.wasm" ]; then
    echo "❌ Error: '$EXAMPLE' is not a chip example (missing chip.json or chip.wasm)." >&2
    exit 1
fi

if [ ! -d "$TARGET_REPO_DIR/.git" ]; then
    echo "❌ Error: Target repo '$TARGET_REPO_DIR' is not a git repository." >&2
    exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
    echo "❌ Error: 'gh' (GitHub CLI) is required to publish releases." >&2
    exit 1
fi

# Deterministic SemVer tag mapping
case "$EXAMPLE" in
    i2c_example)        TAG="v0.0.1" ;;
    i2c_example_async)  TAG="v0.0.2" ;;
    i2c_scanner)        TAG="v0.0.3" ;;
    spi_example)        TAG="v0.0.4" ;;
    spi_example_async)  TAG="v0.0.5" ;;
    uart_example)       TAG="v0.0.6" ;;
    uart_example_async) TAG="v0.0.7" ;;
    *)                  TAG="v0.0.99" ;;
esac

# Wokwi diagram.json requires normalized SemVer without the 'v'
WOKWI_VER="${TAG#v}"

echo "==> Publishing '$EXAMPLE' (Git tag: '$TAG', Wokwi pin: '$WOKWI_VER', chip key: '$CHIP_KEY') to '$TARGET_REPO_DIR'..."

# Ensure wokwi/<example>/chip.json exists with name renamed to <chip_name>
mkdir -p "$WOKWI_EX_DIR"
python3 - "$SOURCE_DIR/chip.json" "$WOKWI_EX_DIR/chip.json" "$CHIP_NAME" <<'PY'
import json, sys
src, dest, chip_name = sys.argv[1:4]
with open(src, encoding="utf-8") as f:
    data = json.load(f)
data["name"] = chip_name
with open(dest, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY

# 1. Copy files to root and dist/ of local espforge-wokwi
mkdir -p "$TARGET_REPO_DIR/dist"
cp -f "$WOKWI_EX_DIR/chip.json" "$TARGET_REPO_DIR/chip.json"
cp -f "$SOURCE_DIR/chip.wasm" "$TARGET_REPO_DIR/chip.wasm"
cp -f "$WOKWI_EX_DIR/chip.json" "$TARGET_REPO_DIR/dist/chip.json"
cp -f "$SOURCE_DIR/chip.wasm" "$TARGET_REPO_DIR/dist/chip.wasm"

# 2. Package chip.zip (required by Wokwi release loader)
ZIP_FILE="/tmp/${EXAMPLE}-chip.zip"
rm -f "$ZIP_FILE"
( cd "$WOKWI_EX_DIR" && zip -9 "$ZIP_FILE" chip.json "$SOURCE_DIR/chip.wasm" )

cd "$TARGET_REPO_DIR"

# 3. Stage and commit files to repo (root + dist/)
git add chip.json chip.wasm dist/chip.json dist/chip.wasm
if git diff --staged --quiet; then
    echo "  • No changes in chip.json/chip.wasm."
else
    git commit -m "chip($EXAMPLE): update assets ($TAG)"
fi

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "HEAD" ]; then
    echo "  • Pushing branch '$CURRENT_BRANCH' to origin..."
    git push origin "$CURRENT_BRANCH"
fi

# 4. Delete existing release and tag both locally and remotely
echo "  • Cleaning up previous release & tag '$TAG'..."
gh release delete "$TAG" --repo "$WOKWI_REPO" --yes 2>/dev/null || true
git push origin --delete "$TAG" 2>/dev/null || true
git tag -d "$TAG" 2>/dev/null || true

# 5. Create local tag and push
echo "  • Tagging '$TAG'..."
git tag "$TAG"
git push origin "$TAG"

# 6. Create GitHub Release with chip.zip asset
echo "  • Creating GitHub Release with chip.zip..."
gh release create "$TAG" "$ZIP_FILE#chip.zip" \
    --repo "$WOKWI_REPO" \
    --title "$TAG ($EXAMPLE)" \
    --notes "Wokwi custom chip for \`$EXAMPLE\`"

rm -f "$ZIP_FILE"

echo "✓ Successfully published '$TAG' to $WOKWI_REPO"

# 7. Pin the dependency in wokwi/<example>/diagram.json using clean SemVer
cd "$ROOT_DIR"
DIAGRAM="$ROOT_DIR/wokwi/$EXAMPLE/diagram.json"
if [ -f "$DIAGRAM" ]; then
    python3 - "$DIAGRAM" "$CHIP_KEY" "github:$WOKWI_REPO@$WOKWI_VER" <<'PY'
import json, sys
path, key, value = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    diagram = json.load(f)

for part in diagram.get("parts", []):
    if part.get("type", "").startswith("chip-"):
        part["type"] = key

deps = diagram.get("dependencies")
if not isinstance(deps, dict):
    deps = {}
deps.pop("chip-chip", None)
deps[key] = value
diagram["dependencies"] = deps

with open(path, "w", encoding="utf-8") as f:
    json.dump(diagram, f, indent=2)
    f.write("\n")
print(f"  • Pinned in diagram: {key} -> {value}")
PY
fi

# 8. Sync the target repo with origin so the next publish starts from a fast-forwardable state
echo "  • Syncing '$TARGET_REPO_DIR' with origin..."
if [ "$CURRENT_BRANCH" != "HEAD" ]; then
    if git -C "$TARGET_REPO_DIR" pull --ff-only --tags origin "$CURRENT_BRANCH"; then
        echo "  • Local target repo is in sync with origin/$CURRENT_BRANCH."
    else
        echo "  ⚠️  Could not fast-forward '$TARGET_REPO_DIR'; resolve it manually before the next publish." >&2
    fi
fi
