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

TAG="$EXAMPLE"

echo "==> Publishing chip for '$EXAMPLE' to '$TARGET_REPO_DIR'..."

# 1. Copy chip.json and chip.wasm to root of target repo
cp -f "$SOURCE_DIR/chip.json" "$TARGET_REPO_DIR/chip.json"
cp -f "$SOURCE_DIR/chip.wasm" "$TARGET_REPO_DIR/chip.wasm"

cd "$TARGET_REPO_DIR"

# 2. Stage and commit
git add chip.json chip.wasm

if git diff --staged --quiet; then
    echo "  • No changes in chip.json or chip.wasm (already at latest commit)."
else
    git commit -m "chip($EXAMPLE): update chip assets"
fi

# Push current branch
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
if [ "$CURRENT_BRANCH" != "HEAD" ]; then
    echo "  • Pushing branch '$CURRENT_BRANCH' to origin..."
    git push origin "$CURRENT_BRANCH"
fi

# 3. Delete previous tag if it exists (both remotely and locally)
if git ls-remote --tags origin "refs/tags/$TAG" | grep -q "refs/tags/$TAG"; then
    echo "  • Deleting remote tag '$TAG' from origin..."
    git push origin --delete "$TAG" || git push origin ":refs/tags/$TAG"
fi

if git rev-parse -q --verify "refs/tags/$TAG" >/dev/null 2>&1; then
    echo "  • Deleting local tag '$TAG'..."
    git tag -d "$TAG"
fi

# 4. Re-add tag locally and push to origin
echo "  • Creating local tag '$TAG'..."
git tag "$TAG"

echo "  • Pushing tag '$TAG' to origin..."
git push origin "$TAG"

echo "✓ Published tag '$TAG' on $WOKWI_REPO"

# 5. Pin the dependency in wokwi/<example>/diagram.json
cd "$ROOT_DIR"
DIAGRAM="$ROOT_DIR/wokwi/$EXAMPLE/diagram.json"
if [ -f "$DIAGRAM" ]; then
    KEY=$(python3 - "$DIAGRAM" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    diagram = json.load(f)
for part in diagram.get("parts", []):
    kind = part.get("type", "")
    if kind.startswith("chip-"):
        print(kind)
        break
PY
)
    if [ -n "$KEY" ]; then
        python3 - "$DIAGRAM" "$KEY" "github:$WOKWI_REPO@$TAG" <<'PY'
import json, sys
path, key, value = sys.argv[1:4]
with open(path, encoding="utf-8") as f:
    diagram = json.load(f)
deps = diagram.get("dependencies")
if not isinstance(deps, dict):
    deps = {}
deps[key] = value
diagram["dependencies"] = deps
with open(path, "w", encoding="utf-8") as f:
    json.dump(diagram, f, indent=2)
    f.write("\n")
print(f"  • Pinned in diagram: {key} -> {value}")
PY
    fi
fi
