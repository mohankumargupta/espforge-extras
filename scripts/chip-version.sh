#!/usr/bin/env bash
# scripts/chip-version.sh — single source of truth for universal chip versioning.
# Tracks global version in version.txt and increments patch on each release (v0.0.1, v0.0.2, ...).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION_FILE="$ROOT_DIR/version.txt"
CHIP_KEY_MODE="${CHIP_KEY_MODE:-part-type}"

die() { printf 'chip-version: %s\n' "$*" >&2; exit 1; }

validate_example() {
    case "${1:-}" in
        '' | *[!a-z0-9_]*) die "invalid example name '${1:-}'" ;;
    esac
}

diagram_path() {
    local ex="$1"
    if [ -f "$ROOT_DIR/wokwi/$ex/diagram.json" ]; then
        printf '%s\n' "$ROOT_DIR/wokwi/$ex/diagram.json"
    elif [ -f "$ROOT_DIR/espforge-examples-generated/$ex/diagram.json" ]; then
        printf '%s\n' "$ROOT_DIR/espforge-examples-generated/$ex/diagram.json"
    else
        die "no diagram.json for '$ex' in wokwi/ or espforge-examples-generated/"
    fi
}

part_type() {
    python3 - "$1" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    diagram = json.load(f)
for part in diagram.get("parts", []):
    kind = part.get("type", "")
    if kind.startswith("chip-"):
        print(kind)
        break
PY
}

chip_key() {
    local kind="$1"
    if [ "$CHIP_KEY_MODE" = "name" ]; then
        printf '%s\n' "${kind#chip-}"
    else
        printf '%s\n' "$kind"
    fi
}

cmd_fetch() {
    git -C "$ROOT_DIR" fetch --tags --force --quiet 2>/dev/null || true
}

cmd_current() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE" | tr -d '[:space:]'
    else
        printf 'v0.0.0\n'
    fi
}

cmd_set() {
    local new_ver="${1:-}"
    [ -n "$new_ver" ] || die "missing version argument for set"
    echo "$new_ver" > "$VERSION_FILE"
}

# Computes the next universal semver (e.g. v0.0.0 -> v0.0.1)
# Also validates against existing git tags to prevent collisions.
cmd_next() {
    local cur
    cur="$(cmd_current)"
    cur="${cur#v}" # strip leading 'v'

    local major minor patch
    IFS=. read -r major minor patch <<< "$cur"
    major="${major:-0}"
    minor="${minor:-0}"
    patch="${patch:-0}"

    local next_patch=$((patch + 1))
    local candidate="v${major}.${minor}.${next_patch}"

    # If the candidate tag already exists in git, keep incrementing
    while git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/${candidate}" >/dev/null 2>&1; do
        next_patch=$((next_patch + 1))
        candidate="v${major}.${minor}.${next_patch}"
    done

    printf '%s\n' "$candidate"
}

cmd_name() {
    local ex="${1:-}"
    validate_example "$ex"
    local kind
    kind="$(part_type "$(diagram_path "$ex")")"
    [ -n "$kind" ] || die "'$ex' has no chip-* part in diagram.json"
    chip_key "$kind"
}

cmd_exists() {
    git -C "$ROOT_DIR" rev-parse -q --verify "refs/tags/${1:-}" >/dev/null 2>&1
}

cmd_pinned() {
    local ex="${1:-}" key
    validate_example "$ex"
    key="$(cmd_name "$ex")"
    python3 - "$(diagram_path "$ex")" "$key" <<'PY'
import json, sys
with open(sys.argv[1], encoding="utf-8") as f:
    deps = json.load(f).get("dependencies") or {}
value = deps.get(sys.argv[2], "") if isinstance(deps, dict) else ""
print(value.split("@", 1)[1] if "@" in value else "")
PY
}

cmd="${1:-}"
shift || true
case "$cmd" in
    fetch)      cmd_fetch ;;
    current)    cmd_current ;;
    set)        cmd_set "$@" ;;
    next)       cmd_next ;;
    name)       cmd_name "$@" ;;
    pinned)     cmd_pinned "$@" ;;
    exists)     cmd_exists "$@" ;;
    *)
        cat >&2 <<'USAGE'
usage: scripts/chip-version.sh <command> [args]

  fetch         fetch tags from origin
  current       print current version from version.txt
  next          compute next universal version (e.g. v0.0.1)
  set <ver>     write version to version.txt
  name <ex>     dependency key for the example's chip part
  pinned <ex>   tag currently pinned in the example's diagram.json
  exists <tag>  exit 0 if git tag exists
USAGE
        exit 2
        ;;
esac
